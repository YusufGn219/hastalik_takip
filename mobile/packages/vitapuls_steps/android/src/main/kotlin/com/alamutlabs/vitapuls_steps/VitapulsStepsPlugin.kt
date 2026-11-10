package com.alamutlabs.vitapuls_steps

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Telefonun adım sayacını (TYPE_STEP_COUNTER) bir kez okur. Sayaç, son
 * yeniden başlatmadan beri toplam adımdır. Uygulama arayüzü olmadan (arka plan
 * görevinin Flutter motorunda) da çalışır; bu yüzden Activity'ye bağlı değildir
 * ve izni İSTEMEZ, yalnızca verilip verilmediğine bakar.
 */
class VitapulsStepsPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val handler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "vitapuls/steps")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "read" -> read((call.argument<Number>("timeoutMs") ?: 8000).toLong(), result)
            else -> result.notImplemented()
        }
    }

    private fun status(result: Result, status: String) = result.success(mapOf("status" to status))

    private fun read(timeoutMs: Long, result: Result) {
        // Android 10 (API 29) öncesinde izin gerekmez.
        if (Build.VERSION.SDK_INT >= 29 &&
            context.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION)
            != PackageManager.PERMISSION_GRANTED
        ) {
            status(result, "noPermission")
            return
        }
        val manager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        val sensor = manager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (manager == null || sensor == null) {
            status(result, "noSensor")
            return
        }

        // Cevap en çok bir kez verilir: ilk değer ya da zaman aşımı hangisi önce gelirse.
        var done = false
        lateinit var listener: SensorEventListener
        val timeout = Runnable {
            if (done) return@Runnable
            done = true
            manager.unregisterListener(listener)
            status(result, "timeout")
        }
        listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                if (done) return
                done = true
                manager.unregisterListener(this)
                handler.removeCallbacks(timeout)
                val bootCount = try {
                    Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT)
                } catch (e: Exception) {
                    null
                }
                result.success(
                    mapOf(
                        "status" to "ok",
                        "counter" to event.values[0].toLong(),
                        "bootCount" to bootCount,
                        "uptimeMs" to SystemClock.elapsedRealtime(),
                    )
                )
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }

        val registered = try {
            manager.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_NORMAL, handler)
        } catch (e: Exception) {
            false
        }
        if (!registered) {
            done = true
            status(result, "error")
            return
        }
        handler.postDelayed(timeout, timeoutMs)
    }
}
