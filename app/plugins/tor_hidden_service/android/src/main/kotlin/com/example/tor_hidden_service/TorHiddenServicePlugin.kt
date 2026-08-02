package com.example.tor_hidden_service

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.FileOutputStream
import java.util.concurrent.Executors
import java.util.zip.ZipFile

class TorHiddenServicePlugin: FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var channel : MethodChannel
    private lateinit var eventChannel : EventChannel
    private lateinit var context : Context

    // Sink to send logs to Flutter
    private var eventSink: EventChannel.EventSink? = null

    private var torProcess: Process? = null
    private var serviceDirs: List<String> = emptyList()
    private val executor = Executors.newSingleThreadExecutor()
    private val uiHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "tor_hidden_service")
        channel.setMethodCallHandler(this)

        // Setup the Event Channel for logging
        eventChannel = EventChannel(binding.binaryMessenger, "tor_hidden_service/logs")
        eventChannel.setStreamHandler(this)

        context = binding.applicationContext
    }

    // --- Event Channel Methods ---
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    // --- Method Channel Methods ---
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "startTor" -> executor.submit { startTor(call, result) }
            "stopTor" -> {
                torProcess?.destroy()
                result.success("Stopped")
            }
            "getHostname" -> getHostname(result)
            "getHostnames" -> getHostnames(result)
            "getTorVersion" -> executor.submit { getTorVersion(result) }
            "readTorLog" -> readTorLog(result)
            else -> result.notImplemented()
        }
    }

    private fun startTor(call: MethodCall, result: Result) {
        try {
            logToFlutter("Checking for Tor binary...")

            // Initial assumption: It's in the native library directory
            var torBinary = File(context.applicationInfo.nativeLibraryDir, "libtor.so")

            if (!torBinary.exists()) {
                logToFlutter("Binary not found in native libs. Attempting manual extraction...")

                val extracted = extractFileFromApk("libtor.so")
                if (extracted != null) {
                    torBinary = extracted
                } else {
                    uiThread(result) { error("BINARY_MISSING", "Could not locate or extract libtor.so", null) }
                    return
                }
            }

            // Double check it exists and is executable
            if (!torBinary.exists()) {
                 uiThread(result) { error("BINARY_MISSING", "Tor binary file does not exist", null) }
                 return
            }

            torBinary.setExecutable(true, true)

            // Setup Data Dirs
            val torDir = context.getDir("tor_data", Context.MODE_PRIVATE)
            if (!torDir.exists()) torDir.mkdirs()

            // Hidden services to host. Each gets its own stable directory (roomId)
            // Tor will generate keys on first run and reuse them on subsequent runs
            // because the directory is stable (chat.js style).
            val services = call.argument<List<Map<String, Any>>>("services")
                ?: emptyList()
            logToFlutter("startTor called with ${services.size} services: ${services.map { it["roomId"] }}")

            // Write Config
            val torrcFile = File(torDir, "torrc")
            val socksPort = call.argument<Int>("socksPort") ?: 9050
            val controlPort = call.argument<Int>("controlPort") ?: 9051
            val useBridges = call.argument<Boolean>("useBridges") ?: false
            val bridges = call.argument<String>("bridges") ?: ""
            val torrc = StringBuilder()
            torrc.append("DataDirectory ${torDir.absolutePath}\n")

            val newServiceDirs = ArrayList<String>()

            if (services.isNotEmpty()) {
                for ((i, svc) in services.withIndex()) {
                    // Use roomId as stable directory name
                    val roomId = svc["roomId"] as? String ?: "room$i"
                    val hsDir = File(torDir, roomId.replace("/", "_").replace("\\", "_"))
                    // Do NOT delete directory - keep it stable so Tor reuses its generated keys
                    if (!hsDir.exists()) hsDir.mkdirs()
                    
                    val port = (svc["port"] as? Number)?.toInt() ?: (8080 + i)
                    
                    // Read deterministic keys from namecode+password (passed by Dart)
                    val sk = svc["secretKey"] as? String
                    val pk = svc["publicKey"] as? String
                    
                    if (sk != null && pk != null) {
                        // Write keys in Tor's expected base64 format with header
                        logToFlutter("DEBUG sk len=${sk.length} pk len=${pk.length}")
                        val secretBytes = try {
                            android.util.Base64.decode(sk, android.util.Base64.NO_WRAP)
                        } catch (e: IllegalArgumentException) {
                            logToFlutter("Error: invalid secret key for $roomId: ${e.message}")
                            uiThread(result) { error("BAD_KEY", "Invalid secret key", null) }
                            return
                        }
                        val publicBytes = try {
                            android.util.Base64.decode(pk, android.util.Base64.NO_WRAP)
                        } catch (e: IllegalArgumentException) {
                            logToFlutter("Error: invalid public key for $roomId: ${e.message}")
                            uiThread(result) { error("BAD_KEY", "Invalid public key", null) }
                            return
                        }
                        logToFlutter("DEBUG decoded secretBytes=${secretBytes.size} publicBytes=${publicBytes.size}")
                        if (secretBytes.size == 64 && publicBytes.size == 32) {
                            val secretB64 = android.util.Base64.encodeToString(secretBytes, android.util.Base64.NO_WRAP)
                            val publicB64 = android.util.Base64.encodeToString(publicBytes, android.util.Base64.NO_WRAP)
                            logToFlutter("DEBUG re-encoded secretB64 len=${secretB64.length} publicB64 len=${publicB64.length}")
                            logToFlutter("DEBUG secretB64=$secretB64")
                            logToFlutter("DEBUG publicB64=$publicB64")
                            val secretContent = "== ed25519v1-secret: type0 ==\n$secretB64\n"
                            val publicContent = "== ed25519v1-public: type0 ==\n$publicB64\n"
                            logToFlutter("DEBUG secretContent len=${secretContent.length} publicContent len=${publicContent.length}")
                            val secretBytesUtf8 = secretContent.toByteArray(java.nio.charset.StandardCharsets.UTF_8)
                            val publicBytesUtf8 = publicContent.toByteArray(java.nio.charset.StandardCharsets.UTF_8)
                            logToFlutter("DEBUG secretBytesUtf8 len=${secretBytesUtf8.size} publicBytesUtf8 len=${publicBytesUtf8.size}")
                            File(hsDir, "hs_ed25519_secret_key").writeBytes(secretBytesUtf8)
                            File(hsDir, "hs_ed25519_public_key").writeBytes(publicBytesUtf8)
                            // Force sync
                            File(hsDir, "hs_ed25519_secret_key").absoluteFile.setWritable(true)
                            File(hsDir, "hs_ed25519_public_key").absoluteFile.setWritable(true)
                            val verifySecret = File(hsDir, "hs_ed25519_secret_key").readText(java.nio.charset.StandardCharsets.UTF_8)
                            val verifyPublic = File(hsDir, "hs_ed25519_public_key").readText(java.nio.charset.StandardCharsets.UTF_8)
                            logToFlutter("VERIFY secret len=${verifySecret.length}: $verifySecret")
                            logToFlutter("VERIFY public len=${verifyPublic.length}: $verifyPublic")
                            logToFlutter("Wrote deterministic keys for $roomId")
                        } else {
                            logToFlutter("Error: bad key sizes for $roomId (${secretBytes.size}, ${publicBytes.size})")
                            uiThread(result) { error("BAD_KEY", "Invalid key sizes", null) }
                            return
                        }
                    } else {
                        logToFlutter("No keys provided for $roomId - will let Tor generate and then dump format")
                    }
                    
                    torrc.append("HiddenServiceDir ${hsDir.absolutePath}\n")
                    torrc.append("HiddenServicePort 80 127.0.0.1:$port\n")
                    torrc.append("HiddenServiceVersion 3\n")
                    newServiceDirs.add(hsDir.absolutePath)
                    logToFlutter("Hidden service for $roomId on port $port at ${hsDir.absolutePath}")
                }
            }
            serviceDirs = newServiceDirs

            torrc.append("SOCKSPort $socksPort\n")
            torrc.append("ControlPort $controlPort\n")
            torrc.append("HTTPTunnelPort 9080\n")
            torrc.append("Log notice file ${torDir.absolutePath}/tor.log\n")
            torrc.append("Log notice stdout\n")
            if (useBridges) {
                torrc.append("UseBridges 1\n")
                for (line in bridges.split("\n")) {
                    val b = line.trim()
                    if (b.isNotEmpty()) torrc.append("Bridge $b\n")
                }
            }
            torrcFile.writeText(torrc.toString())

            // Small delay to ensure key files are fully written to disk before Tor starts
            Thread.sleep(100)

            // Fresh log file for each run (readable from the Tor logs screen).
            val logFile = File(torDir, "tor.log")
            if (logFile.exists()) logFile.delete()

            // A previous attempt may have left a Tor process running and still
            // holding the SOCKS/control ports. Kill it before starting again,
            // otherwise the new process dies with "Address already in use".
            torProcess?.let { old ->
                try { old.destroy() } catch (e: Exception) {}
                torProcess = null
            }

            logToFlutter("Starting Tor process...")

            val pb = ProcessBuilder(torBinary.absolutePath, "-f", torrcFile.absolutePath)
            pb.directory(torDir)
            val env = pb.environment()
            env["LD_LIBRARY_PATH"] = context.applicationInfo.nativeLibraryDir

            torProcess = pb.start()

            // Monitor Logs
            val reader = BufferedReader(InputStreamReader(torProcess!!.inputStream))
            var line: String?
            var bootstrapped = false

            val startTime = System.currentTimeMillis()

            // Loop looking for bootstrap completion. Tor logs go to stdout (for
            // the live Flutter stream) and to tor.log; we check both in case
            // stdout is block-buffered in the pipe.
            while (true) {
                if (reader.ready()) {
                    line = reader.readLine()
                    if (line == null) break
                    logToFlutter(line)
                    if (line.contains("Bootstrapped 100%")) {
                        bootstrapped = true
                        break
                    }
                } else if (logFile.exists()) {
                    try {
                        if (logFile.readText().contains("Bootstrapped 100%")) {
                            bootstrapped = true
                            break
                        }
                    } catch (e: Exception) {}
                }

                // Allow up to 5 minutes: a fresh Tor data directory (e.g. after
                // a reinstall) can be slow to fetch descriptors.
                if (System.currentTimeMillis() - startTime > 300000) { // 300s timeout
                    logToFlutter("Error: Timeout waiting for bootstrap")
                    break
                }
                Thread.sleep(100)
            }

            if (bootstrapped) {
                // Read all .onion hostnames and return them
                val hostnames = ArrayList<String>()
                for (dir in serviceDirs) {
                    val hostnameFile = File(dir, "hostname")
                    if (hostnameFile.exists()) {
                        hostnames.add(hostnameFile.readText().trim())
                    } else {
                        hostnames.add("")
                    }
                }
                uiThread(result) { success(hostnames) }
            } else {
                if (torProcess?.isAlive == false) {
                    logToFlutter("Error: Tor process exited during bootstrap")
                    uiThread(result) { error("EXIT", "Tor process exited before bootstrap", null) }
                } else {
                    uiThread(result) { error("TIMEOUT", "Tor did not bootstrap in time", null) }
                }
            }

        } catch (e: Exception) {
            logToFlutter("Exception: ${e.message}")
            uiThread(result) { error("EXCEPTION", e.message, null) }
        }
    }

    private fun logToFlutter(message: String) {
        // Events must be sent on Main Thread
        uiHandler.post {
            eventSink?.success(message)
        }
        // Also log to Android logcat for debugging
        android.util.Log.d("TorHiddenService", message)
    }
    private fun extractFileFromApk(filename: String): File? {
        try {
            val apkFile = File(context.applicationInfo.sourceDir)
            val zip = ZipFile(apkFile)
            val targetFile = File(context.cacheDir, filename)

            val abis = Build.SUPPORTED_ABIS
            var foundEntry: java.util.zip.ZipEntry? = null

            for (abi in abis) {
                val entryPath = "lib/$abi/$filename"
                val entry = zip.getEntry(entryPath)
                if (entry != null) {
                    foundEntry = entry
                    break
                }
            }

            if (foundEntry == null) return null

            zip.getInputStream(foundEntry).use { input ->
                FileOutputStream(targetFile).use { output ->
                    input.copyTo(output)
                }
            }
            return targetFile
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }

    private fun getHostname(result: Result) {
        val torDir = context.getDir("tor_data", Context.MODE_PRIVATE)
        val hostnameFile = File(torDir, "hs/hostname")
        if (hostnameFile.exists()) {
            result.success(hostnameFile.readText().trim())
        } else {
            result.error("NOT_READY", "Hostname file not created yet", null)
        }
    }

    private fun getHostnames(result: Result) {
        val torDir = context.getDir("tor_data", Context.MODE_PRIVATE)
        val hostnames = ArrayList<String>()
        for (dir in serviceDirs) {
            val hostnameFile = File(dir, "hostname")
            if (hostnameFile.exists()) {
                hostnames.add(hostnameFile.readText().trim())
            } else {
                hostnames.add("")
            }
        }
        // Legacy single-service fallback.
        if (hostnames.isEmpty()) {
            val legacy = File(torDir, "hs/hostname")
            if (legacy.exists()) hostnames.add(legacy.readText().trim())
        }
        result.success(hostnames)
    }

    private fun getTorVersion(result: Result) {
        try {
            val torBinary = File(context.applicationInfo.nativeLibraryDir, "libtor.so")
            if (!torBinary.exists()) {
                result.error("NOT_FOUND", "Tor binary not found", null)
                return
            }
            val pb = ProcessBuilder(torBinary.absolutePath, "--version")
            val env = pb.environment()
            env["LD_LIBRARY_PATH"] = context.applicationInfo.nativeLibraryDir
            val process = pb.start()
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val firstLine = reader.readLine()
            process.waitFor()
            result.success(firstLine?.trim() ?: "unknown")
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }

    private fun readTorLog(result: Result) {
        try {
            val torDir = context.getDir("tor_data", Context.MODE_PRIVATE)
            val logFile = File(torDir, "tor.log")
            if (logFile.exists()) {
                result.success(logFile.readText())
            } else {
                result.error("NO_LOG", "No Tor log yet (start Tor first)", null)
            }
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }

    private fun uiThread(result: Result, block: Result.() -> Unit) {
        uiHandler.post { block(result) }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        torProcess?.destroy()
    }
}