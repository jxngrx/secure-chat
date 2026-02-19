package com.jxngrx.nightspirits

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.TelephonyManager
import android.view.WindowManager
import android.os.Bundle
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.securechat.device_info/imei"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            or WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getImei") {
                val imei = getImei()
                if (imei != null) {
                    result.success(imei)
                } else {
                    result.error("UNAVAILABLE", "IMEI not available", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getImei(): String? {
        return try {
            val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager

            // Check permission
            if (ActivityCompat.checkSelfPermission(
                    this,
                    Manifest.permission.READ_PHONE_STATE
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                return null
            }

            // Get IMEI based on Android version
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Android 10+ - IMEI access is restricted
                // Try to get IMEI, but it may return null
                telephonyManager.imei
            } else {
                // Android 9 and below
                @Suppress("DEPRECATION")
                telephonyManager.deviceId
            }
        } catch (e: Exception) {
            null
        }
    }
}
