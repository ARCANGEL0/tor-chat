package com.onionchat.onionchat_mobile

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    private val TOR_CHANNEL = "com.onionchat.onionchat_mobile/tor_background"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register plugins
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        
        // Register StickerPlugin with v2 embedding
        StickerPlugin.registerWith(flutterEngine)
        
        // Tor background service channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TOR_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startBackgroundService" -> {
                    val intent = Intent(this, TorForegroundService::class.java)
                    intent.action = TorForegroundService.ACTION_START
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stopBackgroundService" -> {
                    val intent = Intent(this, TorForegroundService::class.java)
                    intent.action = TorForegroundService.ACTION_STOP
                    startService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        try {
            super.onActivityResult(requestCode, resultCode, data)
        } catch (e: IllegalStateException) {
            // image_picker/image_cropper can deliver an activity result twice on
            // some devices (known Flutter issue: "Reply already submitted").
            // The Dart side already received the first result, so the second
            // delivery is benign; swallow it to avoid crashing the process.
        }
    }
}
