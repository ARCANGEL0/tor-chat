package com.onionchat.onionchat_mobile

import android.content.Context
import android.util.Base64
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import java.io.File

/** Sticker plugin for WhatsApp sticker import */
class StickerPlugin : MethodCallHandler {

    private var context: Context? = null

    private constructor(context: Context) {
        this.context = context
    }

    companion object {
        fun registerWith(registrar: Registrar) {
            val plugin = StickerPlugin(registrar.context())
            val channel = MethodChannel(registrar.messenger(), "com.onionchat.onionchat_mobile/stickers")
            channel.setMethodCallHandler(plugin)
            Log.d("StickerPlugin", "Registered with Registrar, context: ${registrar.context()}")
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        Log.d("StickerPlugin", "onMethodCall: ${call.method}")
        when (call.method) {
            "getWhatsAppStickerPacks" -> {
                try {
                    val packs = getWhatsAppStickerPacks()
                    Log.d("StickerPlugin", "Found ${packs.size} WhatsApp sticker packs")
                    result.success(packs)
                } catch (e: Exception) {
                    Log.e("StickerPlugin", "Failed to get WhatsApp sticker packs", e)
                    result.error("IMPORT_FAILED", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun getWhatsAppStickerPacks(): List<Map<String, Any?>> {
        val packs = mutableListOf<Map<String, Any?>>()

        if (context == null) {
            Log.w("StickerPlugin", "Context is null!")
            return packs
        }

        // WhatsApp sticker directory paths (varies by WhatsApp version)
        val whatsappDirs = listOf(
            File(context!!.getExternalFilesDir(null)?.parentFile?.parentFile, "WhatsApp/Media/WhatsApp Stickers"),
            File("/storage/emulated/0/WhatsApp/Media/WhatsApp Stickers"),
            File(context!!.getExternalFilesDir(null)?.parentFile?.parentFile, "WhatsApp Business/Media/WhatsApp Stickers"),
            File("/storage/emulated/0/WhatsApp Business/Media/WhatsApp Stickers"),
        )

        var packCounter = 0

        for (baseDir in whatsappDirs) {
            if (!baseDir.exists() || !baseDir.isDirectory) {
                Log.d("StickerPlugin", "Dir not found or not directory: ${baseDir.path}")
                continue
            }
            Log.d("StickerPlugin", "Scanning dir: ${baseDir.path}")

            // Look for .webp files in subdirectories (each subdir = a pack)
            val packDirs = baseDir.listFiles()?.filter { it.isDirectory } ?: continue

            for (packDir in packDirs) {
                val packId = "whatsapp_${packDir.name.hashCode().toString()}_$packCounter"
                packCounter++

                val stickerFiles = packDir.listFiles()?.filter { it.name.endsWith(".webp") } ?: continue
                if (stickerFiles.isEmpty()) continue

                // Look for tray icon
                val trayIconFile = packDir.listFiles()?.firstOrNull { it.name == "tray.webp" || it.name == "tray.png" }
                val trayIconBase64 = trayIconFile?.let { fileToBase64(it) }

                val stickers = mutableListOf<Map<String, Any?>>()
                var stickerCounter = 0

                for (stickerFile in stickerFiles) {
                    if (stickerFile.name == "tray.webp" || stickerFile.name == "tray.png") continue

                    val stickerId = "${packId}_sticker_$stickerCounter"
                    stickerCounter++

                    val base64 = fileToBase64(stickerFile)
                    if (base64 != null) {
                        stickers.add(mapOf(
                            "id" to stickerId,
                            "path" to base64, // Store as base64 for easy transport
                            "name" to stickerFile.nameWithoutExtension
                        ))
                    }
                }

                if (stickers.isNotEmpty()) {
                    packs.add(mapOf(
                        "id" to packId,
                        "name" to packDir.name,
                        "trayIcon" to trayIconBase64,
                        "stickers" to stickers
                    ))
                }
            }
        }

        return packs
    }

    private fun fileToBase64(file: File): String? {
        return try {
            val bytes = file.readBytes()
            Base64.encodeToString(bytes, Base64.NO_WRAP)
        } catch (e: Exception) {
            Log.w("StickerPlugin", "Failed to read sticker file: ${file.path}", e)
            null
        }
    }
}