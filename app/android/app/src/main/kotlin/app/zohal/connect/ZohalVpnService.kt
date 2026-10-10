package app.zohal.connect

import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log

class ZohalVpnService : VpnService() {
    companion object {
        const val TAG = "ZohalVpnService"
        const val ACTION_CONNECT = "app.zohal.connect.ACTION_CONNECT"
        const val ACTION_DISCONNECT = "app.zohal.connect.ACTION_DISCONNECT"
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var isConnected = false

    override fun onCreate() {
        super.onCreate()
        Notifications.createNotificationChannel(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_DISCONNECT -> {
                stopVpn()
                stopSelf()
            }
            ACTION_CONNECT -> {
                startVpn()
            }
        }
        return START_STICKY
    }

    private fun startVpn() {
        if (isConnected) return

        try {
            val builder = Builder()
                .setSession("Zohal")
                .setMtu(1280)
                .addAddress("198.18.0.1", 30)
                .addRoute("0.0.0.0", 0)
                .addAddress("fd7a:6f68:616c::1", 126)
                .addRoute("::", 0)
                .addDnsServer("1.1.1.1")
                .addDnsServer("1.0.0.1")
                .setBlocking(false)
                .setMetered(false)
                .addDisallowedApplication(packageName)

            vpnInterface?.close()
            vpnInterface = builder.establish()

            if (vpnInterface != null) {
                isConnected = true
                val notification = Notifications.buildStatusNotification(this, "متصل است")
                startForeground(Notifications.NOTIFICATION_ID, notification)
                Log.i(TAG, "Zohal VPN interface established successfully")
            } else {
                Log.e(TAG, "Failed to establish VPN interface")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception starting VPN: ${e.message}")
            stopSelf()
        }
    }

    private fun stopVpn() {
        isConnected = false
        try {
            vpnInterface?.close()
            vpnInterface = null
        } catch (e: Exception) {
            Log.e(TAG, "Exception closing interface: ${e.message}")
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
        Log.i(TAG, "Zohal VPN stopped")
    }

    override fun onRevoke() {
        Log.w(TAG, "VPN permission revoked by another VPN or system (E230)")
        stopVpn()
        super.onRevoke()
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }
}
