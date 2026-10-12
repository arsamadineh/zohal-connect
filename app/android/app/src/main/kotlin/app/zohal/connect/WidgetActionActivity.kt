package app.zohal.connect

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Bundle
import androidx.core.content.ContextCompat

class WidgetActionActivity : Activity() {

    companion object {
        const val ACTION_TOGGLE = "app.zohal.connect.ACTION_WIDGET_TOGGLE"
        const val ACTION_CYCLE_MODE = "app.zohal.connect.ACTION_WIDGET_CYCLE_MODE"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        when (intent?.action) {
            ACTION_TOGGLE -> handleToggle()
            ACTION_CYCLE_MODE -> handleCycleMode()
            else -> {
                // Default: open main app
                val open = Intent(this, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                startActivity(open)
            }
        }

        // Finish immediately without animation so user remains on home screen
        overridePendingTransition(0, 0)
        finish()
    }

    private fun handleToggle() {
        // If VPN permission not yet granted by user, must open MainActivity for OS dialog
        if (VpnService.prepare(this) != null) {
            val open = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            startActivity(open)
            return
        }

        val prefs = getSharedPreferences(ZohalVpnService.PREFS, Context.MODE_PRIVATE)
        val phase = prefs.getString("phase", "idle") ?: "idle"
        val isUp = phase == "connected" || phase == "connecting" || phase == "preparing" || phase == "reconnecting"

        val serviceIntent = Intent(this, ZohalVpnService::class.java).apply {
            action = if (isUp) ZohalVpnService.ACTION_DISCONNECT else ZohalVpnService.ACTION_CONNECT
        }

        try {
            if (isUp) {
                startService(serviceIntent)
            } else {
                ContextCompat.startForegroundService(this, serviceIntent)
            }
        } catch (_: Exception) {
            val open = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            startActivity(open)
        }

        ZohalWidgetProvider.updateAllWidgets(this)
    }

    private fun handleCycleMode() {
        val settingsPrefs = getSharedPreferences(ZohalVpnService.SETTINGS_PREFS, Context.MODE_PRIVATE)
        val current = settingsPrefs.getString("mode", "auto") ?: "auto"
        val next = when (current.lowercase()) {
            "auto" -> "masque3"
            "masque3" -> "masque2"
            "masque2" -> "wireguard"
            "wireguard" -> "gool"
            else -> "auto"
        }
        settingsPrefs.edit().putString("mode", next).apply()

        // If connected, trigger reconnect so new mode takes effect
        val prefs = getSharedPreferences(ZohalVpnService.PREFS, Context.MODE_PRIVATE)
        val phase = prefs.getString("phase", "idle") ?: "idle"
        if (phase == "connected" || phase == "connecting" || phase == "preparing") {
            try {
                val serviceIntent = Intent(this, ZohalVpnService::class.java).apply {
                    action = ZohalVpnService.ACTION_CONNECT
                    putExtra("mode", next)
                }
                ContextCompat.startForegroundService(this, serviceIntent)
            } catch (_: Exception) {}
        }

        ZohalWidgetProvider.updateAllWidgets(this)
    }
}
