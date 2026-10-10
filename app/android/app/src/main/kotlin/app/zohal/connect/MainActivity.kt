package app.zohal.connect

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.VpnService
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val METHOD_CHANNEL = "app.zohal.connect/vpn"
        const val EVENT_CHANNEL = "app.zohal.connect/vpn_state"
        const val EVENT_CHANNEL_STATS = "app.zohal.connect/vpn_stats"
        const val REQUEST_VPN_PREPARE = 4101
    }

    private var prepareResult: MethodChannel.Result? = null
    private var eventSink: EventChannel.EventSink? = null
    private var stateReceiver: BroadcastReceiver? = null
    private var statsSink: EventChannel.EventSink? = null
    private var statsReceiver: BroadcastReceiver? = null

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_VPN_PREPARE) {
            val granted = resultCode == RESULT_OK
            try {
                getSharedPreferences("zohal_settings", MODE_PRIVATE)
                    .edit().putBoolean("vpn_consent", granted).apply()
            } catch (_: Exception) {
            }
            prepareResult?.success(granted)
            prepareResult = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "prepareVpn" -> {
                    val existing = VpnService.prepare(this)
                    if (existing == null) {
                        result.success(true)
                    } else {
                        try {
                            prepareResult = result
                            @Suppress("DEPRECATION")
                            startActivityForResult(existing, REQUEST_VPN_PREPARE)
                        } catch (e: Exception) {
                            Log.e("MainActivity", "prepare launch failed: ${e.message}")
                            prepareResult = null
                            result.success(false)
                        }
                    }
                }
                "startVpn" -> {
                    try {
                        val intent = Intent(this, ZohalVpnService::class.java).apply {
                            action = ZohalVpnService.ACTION_CONNECT
                            call.argument<String>("mode")?.let {
                                putExtra("mode", it)
                            }
                            (call.argument<List<String>>("dns"))?.toTypedArray()?.let {
                                putExtra("dns", it)
                            }
                            if (call.hasArgument("fragment")) {
                                putExtra("fragment",
                                    call.argument<Boolean>("fragment") == true)
                            }
                            if (call.hasArgument("ech")) {
                                putExtra("ech",
                                    call.argument<Boolean>("ech") == true)
                            }
                            call.argument<String>("splitMode")?.let {
                                putExtra("splitMode", it)
                            }
                            (call.argument<List<String>>("splitPackages"))?.toTypedArray()?.let {
                                putExtra("splitPackages", it)
                            }
                        }
                        ContextCompat.startForegroundService(this, intent)
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "startVpn failed: ${e.message}")
                        result.error("START_FAILED", e.message, null)
                    }
                }
                "stopVpn" -> {
                    try {
                        val intent = Intent(this, ZohalVpnService::class.java).apply {
                            action = ZohalVpnService.ACTION_DISCONNECT
                        }
                        startService(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("STOP_FAILED", e.message, null)
                    }
                }
                "vpnState" -> {
                    try {
                        val prefs = getSharedPreferences(
                            ZohalVpnService.PREFS, MODE_PRIVATE)
                        result.success(
                            prefs.getString("phase", "idle") ?: "idle")
                    } catch (_: Exception) {
                        result.success("idle")
                    }
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                val filter = IntentFilter(ZohalVpnService.BROADCAST_STATE)
                val receiver = object : BroadcastReceiver() {
                    override fun onReceive(context: Context?, intent: Intent?) {
                        if (intent == null) return
                        val map = HashMap<String, Any?>()
                        map["phase"] = intent.getStringExtra("phase") ?: "idle"
                        map["stage"] = intent.getStringExtra("stage") ?: "none"
                        intent.getStringExtra("error")?.let { map["error"] = it }
                        intent.getStringExtra("exitIp")?.let { map["exitIp"] = it }
                        intent.getStringExtra("exitLoc")?.let { map["exitLoc"] = it }
                        if (intent.hasExtra("sinceUnix")) {
                            map["sinceUnix"] = intent.getLongExtra("sinceUnix", 0)
                        }
                        try {
                            eventSink?.success(map)
                        } catch (_: Exception) {
                        }
                    }
                }
                stateReceiver = receiver
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    registerReceiver(receiver, filter, RECEIVER_NOT_EXPORTED)
                } else {
                    registerReceiver(receiver, filter)
                }
                // Ask the :vpn process to re-emit its live state, so a
                // reopened UI converges even if prefs are stale.
                try {
                    startService(
                        Intent(this@MainActivity, ZohalVpnService::class.java).apply {
                            action = ZohalVpnService.ACTION_QUERY
                        }
                    )
                } catch (_: Exception) {
                }
            }

            override fun onCancel(arguments: Any?) {
                try {
                    stateReceiver?.let { unregisterReceiver(it) }
                } catch (_: Exception) {
                }
                stateReceiver = null
                eventSink = null
            }
        })

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL_STATS
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                statsSink = events
                val filter = IntentFilter(ZohalVpnService.BROADCAST_STATS)
                val receiver = object : BroadcastReceiver() {
                    override fun onReceive(context: Context?, intent: Intent?) {
                        if (intent == null) return
                        val map = HashMap<String, Any>()
                        map["rxBps"] = intent.getLongExtra("rxBps", 0)
                        map["txBps"] = intent.getLongExtra("txBps", 0)
                        map["rxTotal"] = intent.getLongExtra("rxTotal", 0)
                        map["txTotal"] = intent.getLongExtra("txTotal", 0)
                        try {
                            statsSink?.success(map)
                        } catch (_: Exception) {
                        }
                    }
                }
                statsReceiver = receiver
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    registerReceiver(receiver, filter, RECEIVER_NOT_EXPORTED)
                } else {
                    registerReceiver(receiver, filter)
                }
            }

            override fun onCancel(arguments: Any?) {
                try {
                    statsReceiver?.let { unregisterReceiver(it) }
                } catch (_: Exception) {
                }
                statsReceiver = null
                statsSink = null
            }
        })
    }
}
