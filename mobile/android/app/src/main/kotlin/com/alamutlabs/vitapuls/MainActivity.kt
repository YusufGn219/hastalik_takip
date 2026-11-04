package com.alamutlabs.vitapuls

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Biyometrik doğrulama (local_auth) FlutterFragmentActivity ister.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Uygulama kilidi kuruluyken ekran görüntüsünü ve son uygulamalar önizlemesini
        // engeller (FLAG_SECURE). Kanal adı Dart'taki MethodChannelScreenSecurity ile aynı olmalı.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vitapuls/screen_security")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        val secure = call.arguments as? Boolean ?: false
                        runOnUiThread {
                            if (secure) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
