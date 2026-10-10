package app.zohal.connect

object TunBridge {
    var loaded: Boolean = false
        private set

    init {
        try {
            System.loadLibrary("zohal_tun")
            loaded = true
        } catch (e: UnsatisfiedLinkError) {
            android.util.Log.e("TunBridge", "libzohal_tun.so missing: ${e.message}")
            loaded = false
        }
    }

    external fun startTun(fd: Int, socksPort: Int, mtu: Int): Int
    external fun stopTun()
}
