package app.zohal.connect

import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat

@RequiresApi(Build.VERSION_CODES.N)
class ZohalTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        updateTileState()
    }

    override fun onClick() {
        super.onClick()
        if (VpnService.prepare(this) != null) {
            // Consent not granted; open the app so the user can grant it.
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivityAndCollapse(intent)
            return
        }

        val connected = isVpnConnected()
        val intent = Intent(this, ZohalVpnService::class.java).apply {
            action = if (connected) {
                ZohalVpnService.ACTION_DISCONNECT
            } else {
                ZohalVpnService.ACTION_CONNECT
            }
        }
        try {
            if (connected) {
                startService(intent)
            } else {
                ContextCompat.startForegroundService(this, intent)
            }
        } catch (_: Exception) {
            val open = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivityAndCollapse(open)
            return
        }
        updateTileState()
    }

    private fun isVpnConnected(): Boolean {
        return try {
            val prefs = getSharedPreferences(
                ZohalVpnService.PREFS, Context.MODE_PRIVATE)
            when (prefs.getString("phase", "idle")) {
                "connected", "connecting", "preparing", "reconnecting" -> true
                else -> false
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun updateTileState() {
        val tile = qsTile ?: return
        tile.state = if (isVpnConnected()) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = "زحل"
        tile.updateTile()
    }
}
