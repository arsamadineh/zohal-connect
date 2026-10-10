# QA_MANUAL.md - Manual Verification Guide for Zohal Connect

This manual provides test procedures for validating Zohal Connect on real physical hardware across Linux, Windows, and Android.

---

## 1. Linux Physical Testing

### 1.1 Service Installation & Hardening
1. Build and install Debian package:
   ```bash
   sudo dpkg -i dist/linux/zohal_1.0.0_amd64.deb
   ```
2. Verify service is active and sandboxed:
   ```bash
   systemctl status zohald.service
   systemd-analyze security zohald.service
   ```
   *Expected*: Service state is `active (running)`.

### 1.2 TUN Connection & Routing Verification
1. Launch UI: `/opt/zohal/zohal`.
2. Click connect control.
3. Observe stages: «آمادهسازی»، «یافتن دروازه»، «ساخت تونل»، «بررسی مسیر».
4. Verify interface and policy routing:
   ```bash
   ip link show zohal0
   ip rule show
   ip route show table 100
   ```
5. Verify path through Cloudflare WARP:
   ```bash
   curl -s https://1.1.1.1/cdn-cgi/trace | grep warp
   ```
   *Expected*: Body contains `warp=on` or `warp=plus`.

### 1.3 Crash Recovery & Kill -9 Test
1. While connected, forcefully terminate `zohald`:
   ```bash
   sudo pkill -9 zohald
   ```
2. Check routes and rules:
   ```bash
   ip rule show
   ```
3. Restart `zohald`:
   ```bash
   sudo systemctl restart zohald
   ```
   *Expected*: Lingering state is completely unwound by journal playback.

---

## 2. Windows Physical Testing

### 2.1 Installer & Service Registration
1. Run `Zohal-Setup-1.0.0.exe` as Administrator.
2. Confirm RTL Persian wizard shows: «به زحل خوش آمدید».
3. Open Windows Services (`services.msc`) and verify `ZohalEngine` is running.

### 2.2 Wintun & DNS Leak Guard
1. Connect via Zohal UI.
2. Open PowerShell as Administrator and run:
   ```powershell
   Get-NetIPInterface -InterfaceAlias "Zohal"
   Get-NetFirewallRule -Name "ZohalDnsGuard*"
   ```
   *Expected*: Adapter is active and firewall rule blocks outbound port 53 on all other adapters.
3. Verify DNS leak test:
   ```powershell
   nslookup 1.1.1.1
   ```
4. Verify trace:
   ```powershell
   curl.exe https://1.1.1.1/cdn-cgi/trace
   ```

### 2.3 Uninstallation
1. Uninstall Zohal via Windows Settings -> Apps.
2. Verify adapter `Zohal` is removed and firewall rules are deleted.

---

## 3. Android Physical Testing

### 3.1 VPN Consent & First Connect
1. Install APK:
   ```bash
   adb install -r app-arm64-v8a-release.apk
   ```
2. Launch app and complete 4-step onboarding.
3. Confirm system VPN consent prompt appears (`VpnService.prepare`).
4. Once connected, verify persistent notification with duration and action "قطع".

### 3.2 Quick Settings Tile
1. Pull down Android notification shade and add "زحل" tile.
2. Tap tile to toggle connection.
3. Confirm tile state reflects active/inactive.

### 3.3 Network Switching
1. While connected, disconnect Wi-Fi to trigger mobile data failover.
2. Observe reconnecting and successful recovery without user interaction.

### 3.4 Connect Flow After Repair (Phase 7)
1. Fresh install, launch, tap the connect square on the main screen.
2. Expected: control reacts within one frame (preparing animation + stage ticks); on first run the system VPN consent dialog appears.
3. Deny consent: state shows failed with the permission error; tap the VPN row in onboarding step 1 to re-request.
4. Grant consent: stages progress (find gateway, build tunnel, verify path); connected shows duration in Persian digits and the exit address row.
5. While connecting, tap once: inline "cancel" hint appears for 3 s; tap again: returns to idle.
6. Disconnect from the app, from the notification action "قطع", and from the tile; each returns state to idle with no leftover notification.
7. Browse to `https://1.1.1.1/cdn-cgi/trace` in a browser: body contains `warp=on`.
8. Enable airplane mode for 10 s, disable: tunnel reconnects by itself (reconnecting stage, no tap needed).

### 3.5 Revoke and Boot
1. While connected, connect another VPN app: Zohal shows the revoked error, no crash.
2. Enable boot auto-connect in settings, reboot: service reconnects only (no duplicate prompts).

## 4. Linux AppImage
1. Download `Zohal-<ver>-x86_64.AppImage`, `chmod +x`, run with no install.
2. Tap connect: app connects in user scope (system proxy on GNOME/KDE); verify proxy keys are set and restored after disconnect:
   ```bash
   gsettings get org.gnome.system.proxy mode   # manual while connected, previous value after
   ```
3. Disconnect, then `diff` check: no `zohal0` device, no `5100-5102` ip rules remain.
4. Confirm TUN scope message: AppImage uses proxy scope; install the `.deb` + service for full TUN.
