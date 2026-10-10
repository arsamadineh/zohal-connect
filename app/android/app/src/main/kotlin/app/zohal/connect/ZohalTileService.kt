package app.zohal.connect

import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.N)
class ZohalTileService : TileService() {
    private var isConnected = false

    override fun onStartListening() {
        super.onStartListening()
        updateTileState()
    }

    override fun onClick() {
        super.onClick()
        val prepareIntent = VpnService.prepare(this)
        if (prepareIntent != null) {
            // Consent not granted; launch app
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivityAndCollapse(intent)
            return
        }

        if (isConnected) {
            val intent = Intent(this, ZohalVpnService::class.java).apply {
                action = ZohalVpnService.ACTION_DISCONNECT
            }
            startService(intent)
            isConnected = false
        } else {
            val intent = Intent(this, ZohalVpnService::class.java).apply {
                action = ZohalVpnService.ACTION_CONNECT
            }
            startService(intent)
            isConnected = true
        }
        updateTileState()
    }

    private fun updateTileState() {
        val tile = qsTile ?: return
        tile.state = if (isConnected) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = "زحل"
        tile.updateTile()
    }
}
