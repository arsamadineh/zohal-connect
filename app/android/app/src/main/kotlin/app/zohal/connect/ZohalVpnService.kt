package app.zohal.connect

import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.File
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.ServerSocket
import java.util.concurrent.atomic.AtomicBoolean
import javax.net.ssl.HttpsURLConnection

class ZohalVpnService : VpnService() {
    companion object {
        const val TAG = "ZohalVpnService"
        const val ACTION_CONNECT = "app.zohal.connect.ACTION_CONNECT"
        const val ACTION_DISCONNECT = "app.zohal.connect.ACTION_DISCONNECT"
        const val ACTION_QUERY = "app.zohal.connect.ACTION_QUERY"
        const val BROADCAST_STATE = "app.zohal.connect.VPN_STATE"
        const val PREFS = "zohal_vpn_state"
        const val SETTINGS_PREFS = "zohal_settings"
        const val MTU = 1280
    }

    private var worker: Thread? = null
    private var ticker: Thread? = null
    private val stopRequested = AtomicBoolean(false)
    private var vpnInterface: ParcelFileDescriptor? = null
    private var aetherProcess: Process? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var lastProbeOk = true
    private var netDebounce: Thread? = null
    private var currentPhase = "idle"
    private var currentStage = "none"
    private var currentError: String? = null
    private var currentSession: Session? = null

    override fun onCreate() {
        super.onCreate()
        Notifications.createNotificationChannel(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_DISCONNECT -> {
                stopRequested.set(true)
                stopAll("idle")
                stopSelf()
            }
            ACTION_QUERY -> {
                val session = currentSession
                if (session != null && currentPhase == "connected") {
                    broadcastConnected(session)
                } else {
                    broadcast(currentPhase, currentStage, currentError)
                }
                if (worker?.isAlive != true) stopSelf()
            }
            ACTION_CONNECT -> {
                if (worker?.isAlive == true) return START_STICKY
                stopRequested.set(false)
                persistConfig(intent)
                worker = Thread({ runConnectLoop() }, "zohal-connect")
                worker?.start()
            }
        }
        return START_STICKY
    }

    private fun persistConfig(intent: Intent) {
        val prefs = getSharedPreferences(SETTINGS_PREFS, MODE_PRIVATE)
        val ed = prefs.edit()
        intent.getStringExtra("mode")?.let { ed.putString("mode", it) }
        intent.getStringArrayExtra("dns")?.let {
            ed.putString("dns", it.joinToString(","))
        }
        if (intent.hasExtra("fragment")) {
            ed.putBoolean("fragment", intent.getBooleanExtra("fragment", false))
        }
        if (intent.hasExtra("ech")) {
            ed.putBoolean("ech", intent.getBooleanExtra("ech", false))
        }
        intent.getStringExtra("splitMode")?.let { ed.putString("splitMode", it) }
        intent.getStringArrayExtra("splitPackages")?.let {
            ed.putStringSet("splitPackages", it.toSet())
        }
        ed.apply()
    }

    private fun readConfig(): ConnectConfig {
        val prefs = getSharedPreferences(SETTINGS_PREFS, MODE_PRIVATE)
        return ConnectConfig(
            mode = prefs.getString("mode", "auto") ?: "auto",
            dns = (prefs.getString("dns", null)
                ?: "1.1.1.1,1.0.0.1,2606:4700:4700::1111,2606:4700:4700::1001")
                .split(",").map { it.trim() }.filter { it.isNotEmpty() },
            fragment = prefs.getBoolean("fragment", false),
            ech = prefs.getBoolean("ech", false),
            splitMode = prefs.getString("splitMode", "all") ?: "all",
            splitPackages = prefs.getStringSet("splitPackages", emptySet())
                ?.toList() ?: emptyList(),
        )
    }

    private fun runConnectLoop() {
        val config = readConfig()
        val configDir = File(filesDir, "aether").apply { mkdirs() }
        val aetherBin = File(applicationInfo.nativeLibraryDir, "libaether.so")

        broadcast("preparing", "prepare", null)
        startForegroundWith("در حال اتصال")

        if (!aetherBin.exists()) {
            Log.e(TAG, "libaether.so missing in ${applicationInfo.nativeLibraryDir}")
            fail("E400")
            return
        }

        registerNetworkCallback()

        while (!stopRequested.get()) {
            broadcast("connecting", "findGateway", null)
            val result = runLadder(config, configDir, aetherBin)
            if (result == null) {
                if (!stopRequested.get()) fail("E120")
                return
            }
            // Connected session: monitor until loss or stop.
            if (!monitorSession(result)) {
                if (stopRequested.get()) return
                // Reconnecting: keep TUN up, restart ladder.
                broadcast("reconnecting", "findGateway", null)
                tearDownDataPath()
                try {
                    Thread.sleep(1000)
                } catch (_: InterruptedException) {
                    return
                }
            } else {
                return
            }
        }
    }

    private data class ConnectConfig(
        val mode: String,
        val dns: List<String>,
        val fragment: Boolean,
        val ech: Boolean,
        val splitMode: String,
        val splitPackages: List<String>,
    )

    private data class Session(
        val socksPort: Int,
        val exitIp: String,
        val exitLoc: String,
        val sinceUnix: Long,
    )

    private data class Rung(
        val args: List<String>,
        val deadlineSecs: Long,
        val stage: String = "findGateway",
    )

    private fun buildLadder(mode: String, useCache: Boolean): List<Rung> {
        val h3cache = listOf("--masque", "--h3", "--scan", "turbo",
            "--noize", "firewall") + if (useCache) listOf("--quick-reconnect") else emptyList()
        val h2cache = listOf("--masque", "--h2", "--scan", "turbo",
            "--noize", "firewall") + if (useCache) listOf("--quick-reconnect") else emptyList()
        val auto = listOf(
            Rung(h3cache, 4),
            Rung(h2cache, 5),
            Rung(listOf("--masque", "--h3", "--scan", "balanced", "--noize", "gfw"), 8),
            Rung(listOf("--masque", "--h2", "--fragment", "--scan", "balanced", "--noize", "gfw"), 8),
            Rung(listOf("--wg", "--scan", "balanced", "--noize", "balanced"), 8),
            Rung(listOf("--gool", "--scan", "thorough", "--noize", "aggressive"), 12),
        )
        return when (mode) {
            "masque3" -> listOf(
                Rung(h3cache, 4),
                Rung(listOf("--masque", "--h3", "--scan", "balanced", "--noize", "gfw"), 8),
                Rung(listOf("--masque", "--h3", "--scan", "thorough", "--noize", "gfw"), 12),
            )
            "masque2" -> listOf(
                Rung(h2cache, 5),
                Rung(listOf("--masque", "--h2", "--scan", "balanced", "--noize", "gfw"), 8),
                Rung(listOf("--masque", "--h2", "--fragment", "--scan", "balanced", "--noize", "gfw"), 12),
            )
            "wireguard" -> listOf(
                Rung(listOf("--wg", "--scan", "balanced", "--noize", "balanced"), 8),
                Rung(listOf("--wg", "--scan", "thorough", "--noize", "aggressive"), 12),
            )
            "gool" -> listOf(
                Rung(listOf("--gool", "--scan", "thorough", "--noize", "aggressive"), 12),
                Rung(listOf("--gool-classic", "--scan", "thorough", "--noize", "aggressive"), 12),
            )
            else -> auto
        }
    }

    private fun runLadder(config: ConnectConfig, configDir: File, aetherBin: File): Session? {
        for (rung in buildLadder(config.mode, true)) {
            if (stopRequested.get()) return null
            val session = tryRung(rung, config, configDir, aetherBin)
            if (session != null) return session
        }
        return null
    }

    private fun freePort(): Int {
        ServerSocket(0).use { return it.localPort }
    }

    private fun tryRung(rung: Rung, config: ConnectConfig, configDir: File, aetherBin: File): Session? {
        val socksPort = freePort()
        val cmd = mutableListOf(aetherBin.absolutePath)
        cmd.addAll(rung.args)
        cmd.addAll(listOf("--bind", "127.0.0.1:$socksPort"))
        cmd.addAll(listOf("--config", File(configDir, "aether.toml").absolutePath))
        cmd.addAll(listOf("--masque-config", File(configDir, "aether-masque.toml").absolutePath))
        cmd.addAll(listOf("--wg-config", File(configDir, "aether-wg.toml").absolutePath))
        cmd.addAll(listOf("--dns", config.dns.joinToString(",")))
        if (config.fragment) cmd.add("--fragment")
        if (config.ech) cmd.addAll(listOf("--ech", "auto"))
        Log.i(TAG, "spawning aether rung ${rung.args.take(3)} on $socksPort")

        val process = try {
            ProcessBuilder(cmd)
                .redirectInput(File("/dev/null"))
                .redirectErrorStream(true)
                .apply {
                    environment()["HOME"] = configDir.absolutePath
                    environment()["AETHER_LOG_LEVEL"] = "info"
                    environment()["AETHER_PERF_PROFILE"] = "medium"
                }
                .start()
        } catch (e: Exception) {
            Log.e(TAG, "spawn failed: ${e.message}")
            return null
        }
        aetherProcess = process
        val logRing = ArrayDeque<String>()
        val drain = Thread({
            try {
                process.inputStream.bufferedReader().forEachLine { line ->
                    synchronized(logRing) {
                        logRing.addLast(line)
                        if (logRing.size > 50) logRing.removeFirst()
                    }
                }
            } catch (_: Exception) {
            }
        }, "zohal-logdrain")
        drain.isDaemon = true
        drain.start()

        // Wait for SOCKS readiness: Aether opens it only after data-plane validation.
        val deadline = System.currentTimeMillis() + rung.deadlineSecs * 1000
        var ready = false
        while (System.currentTimeMillis() < deadline && !stopRequested.get()) {
            try {
                java.net.Socket().use { s ->
                    s.connect(InetSocketAddress("127.0.0.1", socksPort), 200)
                }
                ready = true
                break
            } catch (_: Exception) {
                try {
                    Thread.sleep(100)
                } catch (_: InterruptedException) {
                    break
                }
            }
        }
        if (!ready) {
            Log.w(TAG, "rung timed out waiting for SOCKS on $socksPort")
            killProcess(process)
            return null
        }

        // Verify path through the candidate.
        val trace = verifyThroughSocks(socksPort)
        if (trace == null) {
            Log.w(TAG, "rung verify failed on $socksPort")
            killProcess(process)
            return null
        }

        // Build the TUN data path.
        broadcast("connecting", "buildTunnel", null)
        if (!establishTun(config)) {
            killProcess(process)
            return null
        }
        if (!TunBridge.loaded) {
            Log.e(TAG, "libzohal_tun.so not loaded; cannot forward packets")
            tearDownDataPath()
            killProcess(process)
            return null
        }
        val fd = vpnInterface?.fd ?: -1
        if (fd < 0 || TunBridge.startTun(fd, socksPort, MTU) != 0) {
            Log.e(TAG, "startTun failed on fd=$fd")
            tearDownDataPath()
            killProcess(process)
            return null
        }

        broadcast("connecting", "verifyPath", null)
        val session = Session(socksPort, trace.first, trace.second,
            System.currentTimeMillis() / 1000)
        broadcastConnected(session)
        startForegroundWith("متصل است")
        startTicker(session)
        Log.i(TAG, "connected via socks=$socksPort exit=${trace.first}")
        return session
    }

    private fun verifyThroughSocks(socksPort: Int): Pair<String, String>? {
        return try {
            val proxy = Proxy(Proxy.Type.SOCKS,
                InetSocketAddress("127.0.0.1", socksPort))
            val url = java.net.URL("https://1.1.1.1/cdn-cgi/trace")
            val conn = (url.openConnection(proxy) as HttpsURLConnection).apply {
                connectTimeout = 3000
                readTimeout = 3000
                instanceFollowRedirects = false
            }
            if (conn.responseCode != 200) {
                conn.disconnect()
                return null
            }
            val body = conn.inputStream.bufferedReader().readText()
            conn.disconnect()
            if (!body.contains("warp=on") && !body.contains("warp=plus")) return null
            var ip = "unknown"
            var loc = "unknown"
            for (line in body.lines()) {
                val kv = line.split("=", limit = 2)
                if (kv.size == 2) {
                    when (kv[0].trim()) {
                        "ip" -> ip = kv[1].trim()
                        "loc" -> loc = kv[1].trim()
                    }
                }
            }
            Pair(ip, loc)
        } catch (e: Exception) {
            Log.w(TAG, "verify probe failed: ${e.message}")
            null
        }
    }

    private fun establishTun(config: ConnectConfig): Boolean {
        return try {
            vpnInterface?.close()
            val builder = Builder()
                .setSession("Zohal")
                .setMtu(MTU)
                .addAddress("198.18.0.1", 30)
                .addRoute("0.0.0.0", 0)
                .addAddress("fd7a:6f68:616c::1", 126)
                .addRoute("::", 0)
                .setBlocking(false)
                .setMetered(false)
                .addDisallowedApplication(packageName)
            for (dns in config.dns) {
                try {
                    builder.addDnsServer(dns)
                } catch (_: Exception) {
                }
            }
            when (config.splitMode) {
                "only" -> for (pkg in config.splitPackages) {
                    try {
                        builder.addAllowedApplication(pkg)
                    } catch (_: Exception) {
                    }
                }
                "except" -> for (pkg in config.splitPackages) {
                    try {
                        builder.addDisallowedApplication(pkg)
                    } catch (_: Exception) {
                    }
                }
            }
            val active = getActiveNetwork()
            if (active != null) builder.setUnderlyingNetworks(arrayOf(active))
            vpnInterface = builder.establish()
            if (vpnInterface == null) {
                Log.e(TAG, "establish() returned null")
                false
            } else {
                true
            }
        } catch (e: Exception) {
            Log.e(TAG, "establishTun failed: ${e.message}")
            false
        }
    }

    private fun getActiveNetwork(): Network? {
        return try {
            val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
            cm.activeNetwork
        } catch (_: Exception) {
            null
        }
    }

    // Returns true when the session ended by user stop, false on tunnel loss.
    private fun monitorSession(session: Session): Boolean {
        var failures = 0
        while (!stopRequested.get()) {
            try {
                Thread.sleep(15000)
            } catch (_: InterruptedException) {
                break
            }
            if (stopRequested.get()) break
            if (aetherProcess?.isAlive == false) {
                Log.w(TAG, "aether exited; reconnecting")
                return false
            }
            val ok = verifyThroughSocks(session.socksPort) != null
            if (ok) {
                failures = 0
            } else {
                failures++
                if (failures >= 2) {
                    Log.w(TAG, "tunnel lost; reconnecting")
                    return false
                }
            }
        }
        return true
    }

    private fun tearDownDataPath() {
        try {
            TunBridge.stopTun()
        } catch (_: Exception) {
        }
        try {
            vpnInterface?.close()
        } catch (_: Exception) {
        }
        vpnInterface = null
        aetherProcess?.let { killProcess(it) }
        aetherProcess = null
    }

    private fun killProcess(process: Process) {
        try {
            process.destroy()
            var exited = false
            val deadline = System.currentTimeMillis() + 300
            while (System.currentTimeMillis() < deadline) {
                try {
                    process.exitValue()
                    exited = true
                    break
                } catch (_: IllegalThreadStateException) {
                    try {
                        Thread.sleep(50)
                    } catch (_: InterruptedException) {
                        break
                    }
                }
            }
            if (!exited) {
                try {
                    process.destroyForcibly()
                } catch (_: Exception) {
                }
            }
        } catch (_: Exception) {
        }
    }

    private fun fail(code: String) {
        broadcast("failed", "none", code)
        startForegroundWith(errorTitle(code))
        stopTicker()
        tearDownDataPath()
        unregisterNetworkCallback()
        stopSelf()
    }

    private fun stopAll(finalPhase: String) {
        stopTicker()
        tearDownDataPath()
        unregisterNetworkCallback()
        broadcast(finalPhase, "none", null)
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    private fun startTicker(session: Session) {
        stopTicker()
        ticker = Thread({
            while (!stopRequested.get() && !Thread.currentThread().isInterrupted) {
                try {
                    Thread.sleep(10000)
                } catch (_: InterruptedException) {
                    break
                }
                val secs = System.currentTimeMillis() / 1000 - session.sinceUnix
                startForegroundWith("متصل است · ${formatDuration(secs)}")
            }
        }, "zohal-ticker")
        ticker?.isDaemon = true
        ticker?.start()
    }

    private fun stopTicker() {
        ticker?.interrupt()
        ticker = null
    }

    private fun startForegroundWith(text: String) {
        try {
            val notification = Notifications.buildStatusNotification(this, text)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    Notifications.NOTIFICATION_ID,
                    notification,
                )
            } else {
                startForeground(Notifications.NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed: ${e.message}")
        }
    }

    private fun registerNetworkCallback() {
        try {
            val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
            val request = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()
            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    debounceProbe()
                }

                override fun onLost(network: Network) {
                    debounceProbe()
                }
            }
            networkCallback = callback
            cm.registerNetworkCallback(request, callback)
        } catch (e: Exception) {
            Log.w(TAG, "network callback unavailable: ${e.message}")
        }
    }

    private fun debounceProbe() {
        netDebounce?.interrupt()
        netDebounce = Thread({
            try {
                Thread.sleep(800)
            } catch (_: InterruptedException) {
                return@Thread
            }
            if (stopRequested.get()) return@Thread
            val port = aetherProcess?.let { lastSocksPort() } ?: return@Thread
            if (verifyThroughSocks(port) == null) {
                if (!lastProbeOk) {
                    Log.w(TAG, "network changed and probe failed; cycling")
                    aetherProcess?.let { killProcess(it) }
                }
                lastProbeOk = false
            } else {
                lastProbeOk = true
            }
        }, "zohal-netdebounce")
        netDebounce?.isDaemon = true
        netDebounce?.start()
    }

    @Volatile
    private var currentSocksPort: Int = -1

    private fun lastSocksPort(): Int = currentSocksPort

    private fun unregisterNetworkCallback() {
        try {
            val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
            networkCallback?.let { cm.unregisterNetworkCallback(it) }
        } catch (_: Exception) {
        }
        networkCallback = null
    }

    private fun broadcast(phase: String, stage: String, error: String?) {
        currentPhase = phase
        currentStage = stage
        currentError = error
        if (phase == "idle" || phase == "failed") currentSession = null
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        prefs.edit()
            .putString("phase", phase)
            .putString("stage", stage)
            .putString("error", error)
            .apply()
        val intent = Intent(BROADCAST_STATE).apply {
            setPackage(packageName)
            putExtra("phase", phase)
            putExtra("stage", stage)
            putExtra("error", error)
        }
        try {
            sendBroadcast(intent)
        } catch (e: Exception) {
            Log.w(TAG, "broadcast failed: ${e.message}")
        }
    }

    private fun broadcastConnected(session: Session) {
        currentSocksPort = session.socksPort
        currentSession = session
        currentPhase = "connected"
        currentStage = "none"
        currentError = null
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        prefs.edit()
            .putString("phase", "connected")
            .putString("stage", "none")
            .putString("error", null)
            .putString("exitIp", session.exitIp)
            .putString("exitLoc", session.exitLoc)
            .putLong("sinceUnix", session.sinceUnix)
            .apply()
        val intent = Intent(BROADCAST_STATE).apply {
            setPackage(packageName)
            putExtra("phase", "connected")
            putExtra("stage", "none")
            putExtra("exitIp", session.exitIp)
            putExtra("exitLoc", session.exitLoc)
            putExtra("sinceUnix", session.sinceUnix)
        }
        try {
            sendBroadcast(intent)
        } catch (e: Exception) {
            Log.w(TAG, "broadcast failed: ${e.message}")
        }
    }

    private fun errorTitle(code: String): String {
        return when (code) {
            "E100" -> "اینترنت در دسترس نیست"
            "E110" -> "ساعت دستگاه نادرست است"
            "E120" -> "هیچ روشی موفق نبود"
            "E130" -> "حساب دستگاه تازهسازی شد"
            "E140" -> "ثبت دستگاه ممکن نشد"
            "E220" -> "مجوز لازم داده نشد"
            "E230" -> "اتصال توسط برنامه دیگری قطع شد"
            else -> "اتصال برقرار نشد"
        }
    }

    private fun formatDuration(totalSecs: Long): String {
        val h = totalSecs / 3600
        val m = (totalSecs % 3600) / 60
        val s = totalSecs % 60
        val raw = "%02d:%02d:%02d".format(h, m, s)
        return faDigits(raw)
    }

    private fun faDigits(input: String): String {
        val fa = charArrayOf('۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹')
        val sb = StringBuilder(input.length)
        for (c in input) {
            sb.append(if (c in '0'..'9') fa[c - '0'] else c)
        }
        return sb.toString()
    }

    override fun onRevoke() {
        Log.w(TAG, "VPN revoked by system or another app (E230)")
        broadcast("failed", "none", "E230")
        stopRequested.set(true)
        stopAll("failed")
        super.onRevoke()
        stopSelf()
    }

    override fun onDestroy() {
        stopRequested.set(true)
        stopAll("idle")
        super.onDestroy()
    }
}
