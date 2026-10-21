# Design Document: Chromecast with Google TV 4K Debloat & Apple TV 4K Launcher

**Date:** 2026-10-21  
**Target Device:** Chromecast with Google TV 4K (Android TV / Google TV)  
**Status:** In Review  

---

## 1. Intent & The "Why"
Google TV on the Chromecast with Google TV 4K consumes significant memory and CPU cycles displaying sponsored carousel banners, auto-playing trailers, and personalized recommendation feeds. The user wants an ad-free, minimal, and responsive home screen modeled after the Apple TV 4K (tvOS) interface that directly displays their applications, runs cleanly on the device's ~1-2 GB RAM, and keeps full hardware functionality (remote control, HDMI-CEC, Wi-Fi, casting).

---

## 2. Goals, Non-Goals & Anti-Goals

### Goals
- Establish secure, stable ADB communication with the Chromecast on port 5555 (with automated fallback to Wireless debugging or Python `adb-shell` if necessary).
- Complete a full snapshot backup of installed packages, disabled packages, system properties (`getprop`), and settings prior to any system modifications, with automated `restore.sh` / `restore.ps1` generation.
- Safely debloat telemetry, ad services, and unneeded background apps using `pm disable-user --user 0` in small batches, prompting the user with checklist questions for streaming apps, voice assistant, Chromecast, and updates.
- Build and install the native Java/AndroidX Leanback launcher (`com.gathin.tvhome`) in Apple TV 4K style:
  - Pitch-black background (`#000000`).
  - Top status bar: Greeting, thin clock, date in open-license font (Outfit), and translucent pills for Inputs, active Wi-Fi SSID, and Settings.
  - 4-app bottom dock with fluid glass highlight and ambient glow sampled from the focused app's banner color.
  - **Option A (Unified Grid)**: A 4-column grid showing all installed applications that smoothly scrolls up when pressing Down.
  - Deterministic D-pad navigation with focus memory.
- Safely disable the stock launcher (`launcherx`) and setup wizard (`setupwraith`) without breaking saved Wi-Fi connections or causing boot-loops.
- Remap remote buttons (e.g. YouTube button sending keycode 190 / `BUTTON_3`, Settings) via the launcher's `InputKeyService`.
- Verify every milestone visually via screenshots captured directly from the TV.
- Deliver comprehensive documentation (README, restore scripts, build-and-install scripts).

### Non-Goals
- Rooting the device or modifying the bootloader.
- Uninstalling system packages (only reversible `pm disable-user --user 0` is permitted).
- Installing third-party paid or closed-source commercial launchers.
- Replacing hardware/firmware drivers.

### Anti-Goals
- Never launch factory or production test activities (`*factory*`, `*fac*`, `*test*`) which can trip hardware flags and permanently disable Netflix or HDMI inputs.
- Never disable packages required for device operation: input services, Bluetooth/remote pairing, Gboard on-screen keyboard, Google Play Services, Play Store.
- Never leave network ADB open unmonitored; ensure the user knows to close network debugging when finished.
- Never disable `setupwraith` without verifying that the active Wi-Fi profile does not belong to it (`dumpsys wifi | grep -o 'cname=[^ ]*'`).

---

## 3. Architecture & Execution Strategy

### Phase 1: Discovery & ADB Connection
1. Scan local network ARP table (`ip neigh`) or query user for TV IP address.
2. Probe port 5555. If closed, guide user through Developer options > Wireless debugging > Pairing code (`adb pair`, `adb connect`, `adb tcpip 5555`).
3. Notify the user immediately when the "Allow USB debugging?" dialog appears on screen.
4. Warn user regarding any USB-powered peripherals that might lose power during USB debugging.

### Phase 2: Complete Baseline Backup
1. Capture state to `backup/`:
   - `packages-all.txt`: `pm list packages -f`
   - `packages-disabled.txt`: `pm list packages -d`
   - `getprop.txt`: `getprop`
   - `settings-system.txt`, `settings-secure.txt`, `settings-global.txt`: `settings list ...`
2. Automatically generate `tools/restore.sh` and `tools/restore.ps1` configured to reverse all disabled packages.

### Phase 3: Incremental Debloat
1. Categorize all packages into:
   - Manufacturer telemetry / analytics (`com.google.android.feedback`, `com.android.tv.feedbackconsent`, `com.google.android.tv.remotecontrol.logging`, adservices).
   - Content recommendations & ads.
   - Background services & preloaded apps.
   - User-facing streaming apps.
2. Run checklist questions for optional services (voice assistant, cast receiver, firmware updates, specific streaming apps).
3. Disable in small batches (one `pm` command per shell execution) with screenshot checks between batches.
4. Offer AdGuard Private DNS (`dns.adguard-dns.com`) as an optional feature.

### Phase 4: Apple TV 4K Launcher Implementation & Configuration
1. Launcher codebase: `com.gathin.tvhome` in `launcher/`.
2. Configure `launcher/app/src/main/res/values/config.xml`:
   - `dock_apps`: 4 selected user apps.
   - `columns`: 4.
   - `rows_below_dock`: 0 (dock parked at bottom, grid scrolls up).
   - `dock_title`: true.
   - `dock_row`: true.
   - `app_keys`: Remap YouTube keycode 190 (`190:com.google.android.youtube.tv`).
   - Option A implementation: Verify `AppAdapter.java` displays all installed applications in the scrollable grid below the dock.
3. Build debug APK using `./gradlew assembleDebug`.
4. Install via ADB shell (`pm install -r` if `adb install` prompts on-screen).
5. Verify `cmd package query-activities` and take over HOME.
6. Guard check: Run `dumpsys wifi | grep -o 'cname=[^ ]*'`. If Wi-Fi belongs to setupwraith, instruct user to rejoin in Settings before disabling setupwraith.
7. Disable stock `com.google.android.apps.tv.launcherx` and `com.google.android.tungsten.setupwraith`.
8. Verify `dumpsys activity activities | grep mFocusedApp` points to `com.gathin.tvhome/.MainActivity`.

### Phase 5: Remote Control & Accessibility Remapping
1. Configure `app_keys` in `config.xml`:
   - `190:com.google.android.youtube.tv` (YouTube)
   - `191:com.netflix.ninja` (Netflix)
2. Enable `InputKeyService` accessibility service:
   - `settings put secure enabled_accessibility_services com.gathin.tvhome/.InputKeyService`
   - `settings put secure accessibility_enabled 1`
3. Ask user to test physical remote buttons (YouTube, Netflix) and verify both launch their respective apps.

### Phase 6: Verification & Cleanup
1. Inject test keys (`input keyevent KEYCODE_HOME`, `KEYCODE_DPAD_DOWN`, etc.) and take screenshots from the TV.
2. Inspect screenshot images to ensure correct scaling, font rendering, and zero graphical glitches.
3. Verify Cast functionality. If Cast credentials need restoration due to setupwraith disablement, execute the documented enable/wait/disable ritual.
4. Verify `tools/adb-closed.py <tv ip>` after instructing the user to disable USB debugging.
5. Provide updated README, restore scripts, and maintenance documentation.

---

## 4. What's Decided vs What's Left to the Builder

### Decided by User
- TV Model: Chromecast with Google TV 4K.
- Style: Apple TV 4K (pitch black, top bar pills, 4-app dock with ambient glow, 4-column grid).
- App Grid Mode: Option A (all installed apps listed in the grid).
- Working Method: Step-by-step on real device, verified with screenshots, checklist questions for personal preferences.
- Google Cast: User actively casts video/music from phone/laptop. Cast receiver (`com.google.android.apps.mediashell`) must remain enabled and operational. The setupwraith credential loading ritual will be verified and documented.
- Remote Buttons: YouTube and Netflix buttons MUST continue opening their respective apps.
- Remote Settings Button: No physical remote button mapping required for Settings; the top status bar frosted Settings pill is sufficient.

### Builder Decisions & Calls
- Remote Key Mapping: `InputKeyService` will be enabled with `app_keys` configured for both YouTube (keycode 190 / `BUTTON_3` -> `com.google.android.youtube.tv`) and Netflix (keycode 191 / `BUTTON_4` -> `com.netflix.ninja`). User will test both physical buttons after launcher setup. `HomeKeyService` is omitted since no physical settings key remapping is needed.
- Google Cast Credential Strategy: After disabling `setupwraith`, execute the documented 30-second credential initialization ritual so the Cast receiver singleton retains device auth in memory, and document the automated command in the README/tools.
- Screenshots: Stored in `docs/screenshots/` with descriptive milestone filenames for verification before/after each change.
