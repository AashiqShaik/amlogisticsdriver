package com.example.amlogisticsdriver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val methodChannelName = "com.example.amlogisticsdriver/location_service"
    private val eventChannelName = "com.example.amlogisticsdriver/location_updates"

    private var eventSink: EventChannel.EventSink? = null
    private var locationReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Method channel: start / stop service ──────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            methodChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startLocationService" -> {
                    val intent = Intent(this, LocationForegroundService::class.java).apply {
                        action = LocationForegroundService.ACTION_START
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "stopLocationService" -> {
                    val intent = Intent(this, LocationForegroundService::class.java).apply {
                        action = LocationForegroundService.ACTION_STOP
                    }
                    startService(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // ── Event channel: stream GPS fixes to Flutter ────────────────────────
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            eventChannelName
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                eventSink = sink
                registerLocationReceiver()
            }

            override fun onCancel(arguments: Any?) {
                unregisterLocationReceiver()
                eventSink = null
            }
        })
    }

    private fun registerLocationReceiver() {
        locationReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != LocationForegroundService.BROADCAST_LOCATION_UPDATE) return
                val data = mapOf(
                    "latitude"  to intent.getDoubleExtra(LocationForegroundService.EXTRA_LATITUDE, 0.0),
                    "longitude" to intent.getDoubleExtra(LocationForegroundService.EXTRA_LONGITUDE, 0.0),
                    "accuracy"  to intent.getFloatExtra(LocationForegroundService.EXTRA_ACCURACY, 0f).toDouble(),
                    "timestamp" to intent.getLongExtra(LocationForegroundService.EXTRA_TIMESTAMP, System.currentTimeMillis())
                )
                eventSink?.success(data)
            }
        }

        val filter = IntentFilter(LocationForegroundService.BROADCAST_LOCATION_UPDATE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(locationReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(locationReceiver, filter)
        }
    }

    private fun unregisterLocationReceiver() {
        locationReceiver?.let {
            try { unregisterReceiver(it) } catch (_: Exception) {}
        }
        locationReceiver = null
    }

    override fun onDestroy() {
        unregisterLocationReceiver()
        super.onDestroy()
    }
}
