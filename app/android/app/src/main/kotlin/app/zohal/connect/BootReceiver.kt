package app.zohal.connect

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.util.Log
import androidx.core.content.ContextCompat

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.i("BootReceiver", "Boot completed received")
            // Only auto-connect when consent already exists (prepare()==null)
            // and the user enabled boot auto-connect (default false).
            if (VpnService.prepare(context) == null) {
                val prefs = context.getSharedPreferences(
                    ZohalVpnService.SETTINGS_PREFS, Context.MODE_PRIVATE)
                val autoConnect = prefs.getBoolean("auto_connect_on_boot", false)
                if (autoConnect) {
                    val serviceIntent = Intent(context, ZohalVpnService::class.java).apply {
                        action = ZohalVpnService.ACTION_CONNECT
                    }
                    try {
                        ContextCompat.startForegroundService(context, serviceIntent)
                        Log.i("BootReceiver", "Auto-starting Zohal VPN on boot")
                    } catch (e: Exception) {
                        Log.w("BootReceiver", "boot auto-start failed: ${e.message}")
                    }
                }
            }
        }
    }
}
