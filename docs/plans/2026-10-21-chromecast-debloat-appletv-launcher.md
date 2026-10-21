# Chromecast with Google TV 4K Debloat & Apple TV 4K Launcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Safely debloat Chromecast with Google TV 4K, replace the stock ad-heavy launcher with a custom native Apple TV 4K style launcher (`com.gathin.tvhome`), preserve all hardware remote keys and Google Cast, verify step-by-step with real device screenshots, and close network ADB when finished.

**Architecture:** A lightweight native Android TV launcher (Java, AndroidX, RecyclerView) with pitch-black Apple TV aesthetic, 5-app dock, frosted status pills, and 5-column scrollable app grid. Telemetry, bloat, and ad services are disabled via `pm disable-user --user 0` in reversible batches backed up to disk, while `InputKeyService` remaps physical remote keys for YouTube (keycode 190) and Netflix (keycode 191).

**Tech Stack:** Android (Java/AndroidX, minSdk 28, targetSdk 34), Gradle, Python 3 (`adb-shell`), ADB shell, Zsh.

**Spec:** `docs/specs/2026-10-21-chromecast-debloat-appletv-launcher-design.md`

## Global Constraints
- Target device: Chromecast with Google TV 4K (Sabrina / Android 12/14).
- Never uninstall system packages; only use `pm disable-user --user 0`.
- Never disable essential OS services: TV app, input services, Bluetooth/remote pairing, Gboard on-screen keyboard, Google Play Services, Play Store.
- Preserve Google Cast (`com.google.android.apps.mediashell`) functionality.
- Never run factory or test menus (`*fac*`, `*factory*`).
- Run `pm` commands one per shell call (or single atomic batch).
- Step-by-step verification on the real device with screenshots saved to `docs/screenshots/`.
- Close network ADB and verify port 5555 is closed upon completion using `tools/adb-closed.py`.
- Git commit convention: Follow `opencode-commit` rules, commit trailer `Assisted-by: Gemini 3.8 Flash`.

## Review Focus
1. **Wi-Fi Ownership by Setupwraith:** If the active Wi-Fi connection was provisioned by `setupwraith`, disabling it drops the TV off Wi-Fi and breaks ADB. (Handled and tested in Task 3 Step 1).
2. **Setupwraith Cast Credential Eviction:** Disabling `setupwraith` can strip the volatile factory private key for Google Cast, causing casting to fail with "Untrusted device". (Handled and tested in Task 7 Step 1).
3. **App Keycode Package Mismatch:** Remote keycodes 190 (YouTube) or 191 (Netflix) failing to open apps if the installed package name differs from standard (`com.google.android.youtube.tv`, `com.netflix.ninja`). (Handled and tested in Task 6 Step 1).
4. **Android 14 ADB Install Hang:** Streaming `adb install` can hang waiting for confirmation; installation must push APK to `/data/local/tmp/` and execute `pm install -r`. (Handled and tested in Task 5 Step 1).
5. **Home Activity Vacuum:** Disabling the stock launcher before the new launcher has registered its HOME capability causes a black screen or setup wizard crash loop. (Handled and tested in Task 5 Step 3).

---

### Task 1: Environment Discovery, Network ADB Connection & Preflight Baseline

**Files:**
- Create: `backup/preflight-report.json`
- Test: `tools/tv.py --probe`
- Screenshot: `docs/screenshots/00-baseline-stock.png`

**Interfaces:**
- Consumes: Target device on network (`192.168.1.37` or dynamic IP) on port 5555.
- Produces: Verified ADB TCP connection and baseline screenshot of current stock interface.

- [ ] **Step 1: Check local network neighbors and confirm TV IP**
  Run: `ip neigh | grep -E '192.168.1.'`
  Verify IP address of the Chromecast. Prompt user if confirmation is required.

- [ ] **Step 2: Connect over ADB and probe device properties**
  Run: `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py --probe`
  Expected output:
  `ro.product.model = Chromecast`
  `ro.product.device = sabrina`
  `ro.build.version.release = 12` (or 14)

- [ ] **Step 3: Query user regarding connected USB peripherals**
  Ask user: "Do you have any USB drives, tuners, or ethernet hubs plugged into the Chromecast's USB-C port?"
  Record answer in `backup/preflight-report.json`.

- [ ] **Step 4: Capture baseline stock home screen screenshot**
  Run:
  `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py 'screencap -p /data/local/tmp/00-baseline.png'`
  `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py --pull /data/local/tmp/00-baseline.png docs/screenshots/00-baseline-stock.png`
  `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py 'rm -f /data/local/tmp/00-baseline.png'`
  Verify image file exists and is valid PNG.

- [ ] **Step 5: Commit baseline artifact**
  ```bash
  git add backup/preflight-report.json docs/screenshots/00-baseline-stock.png
  git commit -m "chore: record baseline environment and stock screenshot"
  ```

---

### Task 2: Full Device State Backup & Automated Restore Script Generation

**Files:**
- Create: `backup/packages-all.txt`
- Create: `backup/packages-disabled.txt`
- Create: `backup/getprop.txt`
- Create: `backup/settings-system.txt`
- Create: `backup/settings-secure.txt`
- Create: `backup/settings-global.txt`
- Create: `restore.sh`
- Create: `restore.ps1`
- Test: Syntax check on `restore.sh` and `restore.ps1`

**Interfaces:**
- Consumes: Live ADB connection from Task 1.
- Produces: Complete device configuration backup and self-contained restore scripts.

- [ ] **Step 1: Dump package lists, properties, and settings**
  Run:
  `mkdir -p backup`
  `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py "pm list packages -f" > backup/packages-all.txt`
  `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py "pm list packages -d" > backup/packages-disabled.txt`
  `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py "getprop" > backup/getprop.txt`
  `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py "settings list system" > backup/settings-system.txt`
  `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py "settings list secure" > backup/settings-secure.txt`
  `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py "settings list global" > backup/settings-global.txt`
  Verify files are non-empty.

- [ ] **Step 2: Generate executable `restore.sh`**
  Write `restore.sh` at repository root that reads any debloat list and runs `pm enable --user 0 <pkg>` for every disabled package, re-enables stock launcher (`com.google.android.apps.tv.launcherx`), and restores default home activity.

- [ ] **Step 3: Generate matching `restore.ps1` for Windows compatibility**
  Write `restore.ps1` with equivalent logic.

- [ ] **Step 4: Verify syntax and permissions**
  Run: `bash -n restore.sh && chmod +x restore.sh`
  Expected: Returncode 0.

- [ ] **Step 5: Commit backup files and restore scripts**
  ```bash
  git add backup/ restore.sh restore.ps1
  git commit -m "feat: add device backup snapshot and automated restore scripts"
  ```

---

### Task 3: Debloat Execution in Phased Batches with Wi-Fi & Safety Guards

**Files:**
- Create: `examples/chromecast-google-tv-4k/debloat.txt`
- Modify: `backup/packages-disabled-after-debloat.txt`
- Screenshot: `docs/screenshots/01-debloat-telemetry.png`
- Screenshot: `docs/screenshots/02-debloat-ads.png`
- Screenshot: `docs/screenshots/03-debloat-optional.png`

**Interfaces:**
- Consumes: Package list from Task 2.
- Produces: Debloated Chromecast system with bloat packages disabled.

- [ ] **Step 1: Check Wi-Fi ownership guard**
  Run: `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py "dumpsys wifi" | grep -o 'cname=[^ ]*'`
  Verify that the active Wi-Fi connection does NOT belong to `com.google.android.tungsten.setupwraith`. If it does, pause and instruct user to forget and reconnect Wi-Fi in Android Settings.

- [ ] **Step 2: Ask user checklist for optional components**
  Use checklist to ask user about:
  - Google Assistant (`com.google.android.katniss`)
  - Streaming apps they do NOT use (e.g. YouTube Kids, Prime Video, Disney+, etc.)
  - Firmware update notifications
  Generate `examples/chromecast-google-tv-4k/debloat.txt` with appropriate categorization.

- [ ] **Step 3: Apply Batch 1: Telemetry and Analytics**
  Run disable commands for telemetry packages:
  `pm disable-user --user 0 com.google.android.feedback`
  `pm disable-user --user 0 com.google.android.partnersetup`
  `pm disable-user --user 0 com.google.android.videos`
  Capture screenshot `docs/screenshots/01-debloat-telemetry.png`.

- [ ] **Step 4: Apply Batch 2: Content Recommendations & Ads Services**
  Run disable commands for recommendation services (keeping stock launcher enabled until new launcher is installed).
  Capture screenshot `docs/screenshots/02-debloat-ads.png`.

- [ ] **Step 5: Apply Batch 3: Unused Streaming / Optional Apps**
  Run disable commands for apps user unchecked in Step 2.
  Capture screenshot `docs/screenshots/03-debloat-optional.png`.

- [ ] **Step 6: Reboot device to test reboot persistence**
  Run: `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py "reboot"`
  Wait 45 seconds for device boot.
  Run: `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py "pm list packages -d" > backup/packages-disabled-after-debloat.txt`
  Verify all disabled packages remain disabled.

- [ ] **Step 7: Commit debloat list and verification screenshots**
  ```bash
  git add examples/chromecast-google-tv-4k/debloat.txt docs/screenshots/01-*.png docs/screenshots/02-*.png docs/screenshots/03-*.png backup/packages-disabled-after-debloat.txt
  git commit -m "feat: apply safe debloat batches and verify reboot persistence"
  ```

---

### Task 4: Launcher Configuration & Build with Apple TV 4K Style

**Files:**
- Modify: `launcher/app/src/main/res/values/config.xml`
- Modify: `launcher/app/src/main/java/com/gathin/tvhome/AppAdapter.java` (if needed for all-apps grid)
- Test: `./gradlew assembleDebug`
- Artifact: `launcher/app/build/outputs/apk/debug/app-debug.apk`

**Interfaces:**
- Consumes: User style preferences (Option A all-apps grid, 5-app dock, Outfit font, key remapping 190:YouTube and 191:Netflix).
- Produces: Compiled debug launcher APK.

- [ ] **Step 1: Check installed package names for YouTube and Netflix on the TV**
  Run: `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py "pm list packages | grep -E 'youtube|netflix'"`
  Verify packages: `com.google.android.youtube.tv` and `com.netflix.ninja`.

- [ ] **Step 2: Configure `launcher/app/src/main/res/values/config.xml`**
  Update `config.xml`:
  - `columns`: 5
  - `dock_row`: true
  - `dock_title`: true
  - `rows_below_dock`: 0 (full scrollable grid below dock)
  - `app_keys`:
    ```xml
    <item>190:com.google.android.youtube.tv</item>
    <item>191:com.netflix.ninja</item>
    ```
  - Ask user which apps they prefer pinned in the dock (user selected 5 apps: YouTube, Netflix, Prime Video, Disney+, Max), and set `dock_apps`.

- [ ] **Step 3: Ensure Option A (all apps in grid) in `AppAdapter.java`**
  Verify that `AppAdapter.java` populates the scrollable grid with all non-hidden installed applications below the pinned dock row.

- [ ] **Step 4: Build launcher APK**
  Run: `cd launcher && ./gradlew assembleDebug`
  Expected: `BUILD SUCCESSFUL` and valid APK at `launcher/app/build/outputs/apk/debug/app-debug.apk`.

- [ ] **Step 5: Commit launcher configuration**
  ```bash
  git add launcher/app/src/main/res/values/config.xml launcher/app/src/main/java/com/gathin/tvhome/AppAdapter.java
  git commit -m "feat: configure Apple TV 4K style launcher with 5-app dock and remote key mappings"
  ```

---

### Task 5: Launcher Installation, Home Handover & Setupwraith Cleanup

**Files:**
- Modify: `launcher/build-and-install.sh`
- Test: `dumpsys activity activities | grep mFocusedApp`
- Screenshot: `docs/screenshots/04-launcher-installed.png`

**Interfaces:**
- Consumes: Built APK from Task 4.
- Produces: `com.gathin.tvhome` running as primary HOME launcher on TV.

- [ ] **Step 1: Push APK and install via shell**
  Run:
  `TV_HOST=<tv_ip> tools/venv/bin/python tools/b64push.py launcher/app/build/outputs/apk/debug/app-debug.apk /data/local/tmp/tvhome.apk`
  `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py 'pm install -r /data/local/tmp/tvhome.apk && rm -f /data/local/tmp/tvhome.apk'`
  Expected output contains `Success`.

- [ ] **Step 2: Grant permissions and compile launcher**
  Run:
  `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py 'pm grant com.gathin.tvhome android.permission.ACCESS_FINE_LOCATION'`
  `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py 'cmd package compile -m speed -f com.gathin.tvhome'`

- [ ] **Step 3: Start launcher and verify it displays properly**
  Run: `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py 'am start -W -n com.gathin.tvhome/.MainActivity'`
  Expected output contains `Status: ok`.

- [ ] **Step 4: Set default home and disable stock launcher**
  Run:
  `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py 'cmd package set-home-activity --user 0 com.gathin.tvhome/.MainActivity'`
  `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py 'pm disable-user --user 0 com.google.android.apps.tv.launcherx'`
  `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py 'pm disable-user --user 0 com.google.android.tungsten.setupwraith'`

- [ ] **Step 5: Verify Home resolution and capture screenshot**
  Run: `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME'`
  Expected output ends with `com.gathin.tvhome/.MainActivity`.
  Capture screenshot `docs/screenshots/04-launcher-installed.png`.

- [ ] **Step 6: Commit installation milestone and screenshot**
  ```bash
  git add docs/screenshots/04-launcher-installed.png
  git commit -m "feat: install tvhome launcher and switch default Home activity"
  ```

---

### Task 6: Remote Control Key Remapping & Accessibility Service Verification

**Files:**
- Modify: Device secure settings
- Screenshot: `docs/screenshots/05-remote-button-test.png`

**Interfaces:**
- Consumes: Running `com.gathin.tvhome`.
- Produces: Functional YouTube and Netflix buttons on physical remote.

- [ ] **Step 1: Enable `InputKeyService` accessibility service**
  Run:
  `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py 'settings put secure enabled_accessibility_services com.gathin.tvhome/.InputKeyService'`
  `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py 'settings put secure accessibility_enabled 1'`

- [ ] **Step 2: Verify service is bound and running**
  Run: `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py 'dumpsys accessibility | grep com.gathin.tvhome/.InputKeyService'`
  Expected: Service is listed and bound.

- [ ] **Step 3: Test keycode injection over ADB**
  Run: `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py 'input keyevent 190'` (YouTube button)
  Check active app: `dumpsys activity activities | grep mFocusedApp` -> `com.google.android.youtube.tv`
  Run: `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py 'input keyevent 3'` (Home button)
  Run: `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py 'input keyevent 191'` (Netflix button)
  Check active app: `dumpsys activity activities | grep mFocusedApp` -> `com.netflix.ninja`
  Run: `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py 'input keyevent 3'` (Home button)

- [ ] **Step 4: Request user verification of physical remote buttons**
  Ask user to press physical YouTube and Netflix buttons on their remote and verify both launch immediately.
  Capture screenshot `docs/screenshots/05-remote-button-test.png`.

- [ ] **Step 5: Commit key remapping milestone**
  ```bash
  git add docs/screenshots/05-remote-button-test.png
  git commit -m "feat: enable InputKeyService and verify YouTube and Netflix remote keys"
  ```

---

### Task 7: Google Cast Verification, Credential Ritual & DNS Ad-blocking

**Files:**
- Create: `tools/cast-fix.sh`
- Screenshot: `docs/screenshots/06-cast-verified.png`

**Interfaces:**
- Consumes: Chromecast Cast receiver (`com.google.android.apps.mediashell`).
- Produces: Operational casting from phone/laptop and optional ad-blocking private DNS.

- [ ] **Step 1: Check Cast receiver status**
  Run: `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py 'pm list packages -e | grep mediashell'`
  Expected: `package:com.google.android.apps.mediashell` is enabled.

- [ ] **Step 2: Create reusable `tools/cast-fix.sh` ritual script**
  Write `tools/cast-fix.sh` that temporarily enables `setupwraith`, restarts `mediashell` to reload factory keys, waits 30 seconds, and disables `setupwraith` again.

- [ ] **Step 3: User verification of phone/laptop casting**
  Ask user to open YouTube or Spotify on their phone/laptop and start casting to the Chromecast. Confirm smooth playback.

- [ ] **Step 4: Optional Private DNS ad-blocking offer**
  Ask user: "Would you like to enable AdGuard Private DNS (`dns.adguard-dns.com`) for system-wide ad-blocking across apps?"
  If yes:
  `settings put global private_dns_mode hostname`
  `settings put global private_dns_specifier dns.adguard-dns.com`

- [ ] **Step 5: Capture Cast and settings screenshot**
  Capture `docs/screenshots/06-cast-verified.png`.

- [ ] **Step 6: Commit Cast verification and tools**
  ```bash
  git add tools/cast-fix.sh docs/screenshots/06-cast-verified.png
  git commit -m "feat: verify Google Cast operation and add credential fix tool"
  ```

---

### Task 8: Visual Verification, Network ADB Closure & Delivery

**Files:**
- Create: `docs/screenshots/07-final-home-screen.png`
- Modify: `README.md`
- Test: `tools/adb-closed.py <tv_ip>`

**Interfaces:**
- Consumes: Fully configured TV.
- Produces: Final verified screenshots, closed network ADB port, updated README documentation.

- [ ] **Step 1: Capture final high-resolution home screen screenshot**
  Run:
  `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py 'screencap -p /data/local/tmp/07-final.png'`
  `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py --pull /data/local/tmp/07-final.png docs/screenshots/07-final-home-screen.png`
  `TV_HOST=<tv_ip> tools/venv/bin/python tools/tv.py 'rm -f /data/local/tmp/07-final.png'`
  Verify visual aesthetics: pitch black background, Outfit font clock, frosted pills, 5-app dock, clean app grid.

- [ ] **Step 2: Update `README.md` with Chromecast with Google TV 4K guide**
  Document the setup, debloat list, restore instructions, and Cast fix script.

- [ ] **Step 3: Instruct user to disable Developer Options / USB Debugging**
  Provide clear instructions:
  1. Open Settings -> System -> Developer options.
  2. Toggle "USB debugging" to OFF.
  3. Toggle "Developer options" to OFF.
  4. Reboot the Chromecast.

- [ ] **Step 4: Run `tools/adb-closed.py` to verify port 5555 is closed**
  Run: `python3 tools/adb-closed.py <tv_ip>`
  Expected output: Port 5555 is closed / connection refused.

- [ ] **Step 5: Final commit**
  ```bash
  git add docs/screenshots/07-final-home-screen.png README.md
  git commit -m "docs: finalize Chromecast 4K debloat documentation and close verification"
  ```
