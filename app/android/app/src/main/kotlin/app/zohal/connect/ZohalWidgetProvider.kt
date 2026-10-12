package app.zohal.connect

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class ZohalWidgetProvider : AppWidgetProvider() {

    companion object {
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
            val settingsPrefs = context.getSharedPreferences(
                ZohalVpnService.SETTINGS_PREFS, Context.MODE_PRIVATE
            )
            val phase = prefs.getString("phase", "idle") ?: "idle"
            val isConnected = phase == "connected"
            val isConnecting = phase == "connecting" || phase == "preparing" || phase == "reconnecting"

            val views = RemoteViews(context.packageName, R.layout.widget_zohal)

            // Status Text and Indicator
            val statusText: String
            val indicatorRes: Int
            val statusColor: Int

            when (phase) {
                "connected" -> {
                    statusText = "متصل است"
                    indicatorRes = R.drawable.widget_indicator_connected
                    statusColor = 0xFF10B981.toInt() // Emerald
                }
                "connecting", "preparing" -> {
                    statusText = "در حال اتصال..."
                    indicatorRes = R.drawable.widget_indicator_connecting
                    statusColor = 0xFFF59E0B.toInt() // Amber
                }
                "reconnecting" -> {
                    statusText = "اتصال مجدد..."
                    indicatorRes = R.drawable.widget_indicator_connecting
                    statusColor = 0xFFF59E0B.toInt()
                }
                "disconnecting" -> {
                    statusText = "در حال قطع..."
                    indicatorRes = R.drawable.widget_indicator_connecting
                    statusColor = 0xFFF59E0B.toInt()
                }
                "failed" -> {
                    statusText = "خطا در اتصال"
                    indicatorRes = R.drawable.widget_indicator_connecting
                    statusColor = 0xFFE0735F.toInt()
                }
                else -> {
                    statusText = "قطع است"
                    indicatorRes = R.drawable.widget_indicator_idle
                    statusColor = 0xFF9A9DA1.toInt()
                }
            }

            views.setTextViewText(R.id.widget_status, statusText)
            views.setTextColor(R.id.widget_status, statusColor)
            views.setImageViewResource(R.id.widget_indicator, indicatorRes)

            // Connection Mode Display
            val mode = settingsPrefs.getString("mode", "auto") ?: "auto"
            val modeFa = when (mode.lowercase()) {
                "masque3", "masque-h3" -> "مسک ۳ ▾"
                "masque2", "masque-h2" -> "مسک ۲ ▾"
                "wireguard" -> "وایرگارد ▾"
                "gool" -> "گول ▾"
                else -> "هوشمند ▾"
            }
            views.setTextViewText(R.id.widget_mode, modeFa)

            // Optional Stats (Duration or exit info when connected)
            if (isConnected) {
                val sinceUnix = prefs.getLong("sinceUnix", 0L)
                if (sinceUnix > 0) {
                    val durationSec = (System.currentTimeMillis() / 1000) - sinceUnix
                    val formatted = formatDuration(durationSec)
                    views.setTextViewText(R.id.widget_stats, "· $formatted")
                } else {
                    val exitLoc = prefs.getString("exitLoc", null)
                    if (!exitLoc.isNullOrEmpty()) {
                        views.setTextViewText(R.id.widget_stats, "· $exitLoc")
                    } else {
                        views.setTextViewText(R.id.widget_stats, "")
                    }
                }
            } else {
                views.setTextViewText(R.id.widget_stats, "")
            }

            // Action Button
            val buttonText = if (isConnected) "قطع اتصال" else if (isConnecting) "لغو" else "اتصال"
            views.setTextViewText(R.id.widget_button, buttonText)

            val bgRes = if (isConnected) {
                R.drawable.widget_button_bg_connected
            } else if (isConnecting) {
                R.drawable.widget_button_bg_connecting
            } else {
                R.drawable.widget_button_bg
            }
            views.setInt(R.id.widget_button, "setBackgroundResource", bgRes)

            // 1. Tapping App Icon or Title opens MainActivity
            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val openPendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId * 10,
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_icon, openPendingIntent)
            views.setOnClickPendingIntent(R.id.widget_title, openPendingIntent)

            // 2. Interactive Toggle Button triggers WidgetActionActivity.ACTION_TOGGLE
            val toggleIntent = Intent(context, WidgetActionActivity::class.java).apply {
                action = WidgetActionActivity.ACTION_TOGGLE
            }
            val togglePendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId * 10 + 1,
                toggleIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_button, togglePendingIntent)

            // 3. Interactive Mode Chip triggers WidgetActionActivity.ACTION_CYCLE_MODE
            val modeIntent = Intent(context, WidgetActionActivity::class.java).apply {
                action = WidgetActionActivity.ACTION_CYCLE_MODE
            }
            val modePendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId * 10 + 2,
                modeIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_mode_container, modePendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun formatDuration(seconds: Long): String {
            val s = if (seconds < 0) 0 else seconds
            val h = s / 3600
            val m = (s % 3600) / 60
            val sec = s % 60
            val raw = if (h > 0) {
                String.format("%02d:%02d:%02d", h, m, sec)
            } else {
                String.format("%02d:%02d", m, sec)
            }
            return toPersianDigits(raw)
        }

        private fun toPersianDigits(input: String): String {
            val sb = java.lang.StringBuilder()
            for (ch in input) {
                if (ch in '0'..'9') {
                    sb.append((ch.code - '0'.code + 0x06F0).toChar())
                } else {
                    sb.append(ch)
                }
            }
            return sb.toString()
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
        if (intent.action == ZohalVpnService.BROADCAST_STATE || intent.action == ZohalVpnService.BROADCAST_STATS) {
            updateAllWidgets(context)
        }
    }
}
