package app.zohal.connect

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.i("BootReceiver", "Boot completed received")
            // Check if VPN consent exists
            val prepareIntent = VpnService.prepare(context)
            if (prepareIntent == null) {
                // Read auto_connect_on_boot preference (default false)
                val prefs = context.getSharedPreferences("zohal_settings", Context.MODE_PRIVATE)
                val autoConnect = prefs.getBoolean("auto_connect_on_boot", false)
                if (autoConnect) {
                    val serviceIntent = Intent(context, ZohalVpnService::class.java).apply {
                        action = ZohalVpnService.ACTION_CONNECT
                    }
                    context.startService(serviceIntent)
                    Log.i("BootReceiver", "Auto-starting Zohal VPN on boot")
                }
            }
        }
    }
}
