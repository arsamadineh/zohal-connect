package app.zohal.connect

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.widget.RemoteViews
import androidx.core.content.ContextCompat

class ZohalWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_TOGGLE = "app.zohal.connect.ACTION_WIDGET_TOGGLE"

        fun updateAllWidgets(context: Context) {
            try {
                val appWidgetManager = AppWidgetManager.getInstance(context) ?: return
                val thisWidget = ComponentName(context, ZohalWidgetProvider::class.java)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget) ?: return
                for (widgetId in appWidgetIds) {
                    updateWidget(context, appWidgetManager, widgetId)
                }
            } catch (_: Exception) {}
        }

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(
                ZohalVpnService.PREFS, Context.MODE_PRIVATE
            )
            val phase = prefs.getString("phase", "idle") ?: "idle"
            val isConnected = phase == "connected"
            val isConnecting = phase == "connecting" || phase == "preparing" || phase == "reconnecting"

            val views = RemoteViews(context.packageName, R.layout.widget_zohal)

            val statusText = when (phase) {
                "connected" -> "متصل است"
                "connecting", "preparing" -> "در حال اتصال"
                "reconnecting" -> "اتصال مجدد"
                "disconnecting" -> "در حال قطع"
                "failed" -> "خطا در اتصال"
                else -> "قطع است"
            }
            views.setTextViewText(R.id.widget_status, statusText)

            val buttonText = if (isConnected) "قطع اتصال" else if (isConnecting) "لغو" else "اتصال"
            views.setTextViewText(R.id.widget_button, buttonText)

            // Open app on widget background/title click
            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val openPendingIntent = PendingIntent.getActivity(
                context,
                0,
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, openPendingIntent)

            // Toggle connect on button click
            val toggleIntent = Intent(context, ZohalWidgetProvider::class.java).apply {
                action = ACTION_TOGGLE
            }
            val togglePendingIntent = PendingIntent.getBroadcast(
                context,
                appWidgetId,
                toggleIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_button, togglePendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_TOGGLE) {
            if (VpnService.prepare(context) != null) {
                // VPN permission not granted yet: launch app so user can approve
                val open = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(open)
                return
            }

            val prefs = context.getSharedPreferences(
                ZohalVpnService.PREFS, Context.MODE_PRIVATE
            )
            val phase = prefs.getString("phase", "idle") ?: "idle"
            val isUp = phase == "connected" || phase == "connecting" || phase == "preparing" || phase == "reconnecting"

            val serviceIntent = Intent(context, ZohalVpnService::class.java).apply {
                action = if (isUp) ZohalVpnService.ACTION_DISCONNECT else ZohalVpnService.ACTION_CONNECT
            }
            try {
                if (isUp) {
                    context.startService(serviceIntent)
                } else {
                    ContextCompat.startForegroundService(context, serviceIntent)
                }
            } catch (_: Exception) {
                val open = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(open)
            }
            updateAllWidgets(context)
        } else if (intent.action == ZohalVpnService.BROADCAST_STATE) {
            updateAllWidgets(context)
        }
    }
}
