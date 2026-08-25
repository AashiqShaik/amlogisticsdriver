package `in`.amlogistics.driver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val methodChannelName = "com.example.amlogisticsdriver/location_service"
    private val eventChannelName = "com.example.amlogisticsdriver/location_updates"
    // Deep-link channel: forwards incoming App Link URIs to Flutter
    private val deepLinkChannelName = "in.amlogistics.driver/deep_link"

    private var eventSink: EventChannel.EventSink? = null
    private var locationReceiver: BroadcastReceiver? = null

    // Holds the URI from the intent that launched the activity (cold start)
    private var initialUri: String? = null
    // MethodChannel reference so onNewIntent can push warm-start URIs to Flutter
    private var deepLinkChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Capture the cold-start URI before Flutter is ready
        initialUri = intent?.data?.toString()

        // ── Deep-link channel ─────────────────────────────────────────────────
        deepLinkChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deepLinkChannelName
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    // Flutter calls this once on startup to get the launch URI
                    "getInitialLink" -> result.success(initialUri)
                    else -> result.notImplemented()
                }
            }
        }

        // ── Method channel: start / stop service + Play Store ─────────────────
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
                "openPlayStore" -> {
                    val url = call.argument<String>("url")
                        ?: "https://play.google.com/store/apps/details?id=in.amlogistics.driver"
                    try {
                        val marketUri = Uri.parse(url.replace("https://play.google.com/store/", "market://"))
                        val marketIntent = Intent(Intent.ACTION_VIEW, marketUri).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(marketIntent)
                    } catch (_: Exception) {
                        val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(browserIntent)
                    }
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

    /**
     * Called when the activity is already running (warm start / singleTop) and
     * a new intent arrives — e.g. the user taps an App Link while the app is
     * in the foreground or background.
     *
     * We forward the URI to Flutter via the deep-link MethodChannel so the
     * router can navigate to the correct screen without restarting the app.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val uri = intent.data?.toString()
        if (!uri.isNullOrEmpty()) {
            deepLinkChannel?.invokeMethod("onNewLink", uri)
        }
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
