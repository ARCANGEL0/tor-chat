package com.onionchat.onionchat_mobile

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
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
