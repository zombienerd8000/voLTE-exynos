# Samsung Exynos Audio HAL Mic Routing Fix for PhhIms VoLTE on LineageOS

## Problem Statement

On Samsung Exynos devices running LineageOS (particularly Android 16), the Samsung audio HAL forces `AudioManager.MODE_IN_CALL` (mode 2) whenever any phone call starts. This routes microphone audio through the modem path:

```
DEMUX3 → VSS Adapter → TXSE → VPCMIN_DAI3 → Modem Uplink
```

This prevents PhhIms (or any VoIP-based IMS implementation) from capturing microphone audio through the normal Android recording path:

```
DEMUX0 → VPCMIN_DAI0 → AudioFlinger → AudioRecord → PhhIms
```

The result: PhhIms successfully establishes VoLTE calls (SIP registration, RTP downlink works, you can hear the other party), but the other party cannot hear you because the mic audio is being routed to the modem's circuit-switched voice path instead of the application processor's audio recording path.

## Root Cause

The Samsung audio HAL intercepts `AudioManager.setMode()` calls in `system_server`. When Telecom/InCallService initiates a call, the HAL overrides whatever mode PhhIms sets (typically `MODE_IN_COMMUNICATION`, mode 3) back to `MODE_IN_CALL` (mode 2). The ABOX firmware then exclusively owns the mic and sends it to the modem.

PhhIms uses `AudioManager.MODE_IN_COMMUNICATION` because it's a VoIP-style IMS implementation that captures audio via `AudioRecord` rather than the telephony audio path. The HAL's override to `MODE_IN_CALL` makes this impossible.

## Solution

A Magisk/APatch module that runs a persistent Java watcher process at boot. The watcher:

1. Monitors `AudioManager.getMode()` every 50ms via in-process API calls (no JVM restart overhead)
2. When it detects `MODE_IN_CALL` (2), immediately forces `MODE_IN_COMMUNICATION` (3)
3. Also forces speaker output via `AudioManager.setSpeakerphoneOn(true)`

This prevents the Samsung HAL from completing the modem mic routing, because by the time the ABOX firmware would re-route, the mode has already been corrected.

## Why This Works

The fix works because of a timing race condition:

1. Samsung HAL sets `MODE_IN_CALL` → Audio policy begins routing mic to modem
2. Our watcher (50ms poll, in-process API) detects `IN_CALL` and forces `IN_COMMUNICATION`
3. Audio policy re-routes mic back to AudioFlinger before ABOX firmware completes the switch
4. The persistent watcher keeps re-applying every 50ms, preventing the HAL from winning

The key insight: using a persistent `app_process` Java process (not spawning a new JVM per detection) makes the response fast enough to beat the HAL's override cycle.

## Device Compatibility

- **Tested on:** Samsung Galaxy S20 Ultra (SM-G988B), Exynos 990
- **ROM:** LineageOS 23.2 (Android 16)
- **Root:** APatch + KernelPatch
- **Likely works on:** All Samsung Exynos devices running LineageOS with the same audio HAL behavior

## Module Structure

```
audio_mode_fix/
├── META-INF/
│   └── com/
│       └── google/
│           └── android/
│               ├── update-binary
│               └── updater-script
├── module.prop
├── service.sh
└── system/
    └── bin/
        └── classes.dex
```

### module.prop
```
id=audio_mode_fix
name=Audio Mode Fix (VoLTE Mic)
version=1.0
versionCode=1
author=komori
description=Forces MODE_IN_COMMUNICATION when system tries MODE_IN_CALL. Fixes PhhIms mic routing on Samsung.
```

### service.sh
The service script launches the persistent Java watcher and restarts it if it dies:

```sh
#!/system/bin/sh
MODDIR="${0%/*}"
LOGFILE="/data/local/tmp/audiomodefix.log"
HELPER="$MODDIR/system/bin/classes.dex"

# Wait for boot
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 1
done
sleep 3

# Launch persistent watcher
CLASSPATH="$HELPER" app_process /system/bin AudioModeHelper watch >> "$LOGFILE" 2>&1 &
WATCHER_PID=$!

# Restart if killed
while true; do
    if ! kill -0 $WATCHER_PID 2>/dev/null; then
        CLASSPATH="$HELPER" app_process /system/bin AudioModeHelper watch >> "$LOGFILE" 2>&1 &
        WATCHER_PID=$!
    fi
    sleep 5
done
```

### AudioModeHelper.java (compiled to classes.dex)
The Java helper runs as a persistent process via `app_process`:

```java
import android.content.Context;
import android.media.AudioManager;
import android.os.Looper;

public class AudioModeHelper {
    public static void main(String[] args) throws Exception {
        Looper.prepareMainLooper();
        
        Class<?> atClass = Class.forName("android.app.ActivityThread");
        Object at = atClass.getMethod("systemMain").invoke(null);
        Context ctx = (Context) atClass.getMethod("getSystemContext").invoke(at);
        AudioManager am = (AudioManager) ctx.getSystemService(Context.AUDIO_SERVICE);

        // Persistent watcher: 50ms poll, no JVM restart
        while (true) {
            int mode = am.getMode();
            if (mode == 2) { // MODE_IN_CALL
                am.setMode(3); // MODE_IN_COMMUNICATION
                am.setSpeakerphoneOn(true);
            }
            Thread.sleep(50);
        }
    }
}
```

## Building the Module

### Prerequisites
- JDK 17 (Eclipse Adoptium recommended)
- Android SDK with:
  - `platforms;android-34`
  - `build-tools;34.0.0`
- ADB with root access

### Compilation Steps

```bash
# 1. Compile Java to class files
javac -source 17 -target 17 \
  -classpath $ANDROID_SDK/platforms/android-34/android.jar \
  -d . \
  AudioModeHelper.java

# 2. Convert class to DEX
$ANDROID_SDK/build-tools/34.0.0/d8 \
  --lib $ANDROID_SDK/platforms/android-34/android.jar \
  --output . \
  AudioModeHelper.class

# 3. Package as Magisk module zip
# (use forward slashes, not backslashes - Windows zip breaks extraction)
```

### Important Note on Compilation
`d8` only accepts `.class` or `.jar` files, not `.java` directly. You must compile with `javac` first.

The hidden API `AudioManager.setMode(int, IBinder)` may be blocked on Android 16 by hidden API restrictions. The public `setMode(int)` API works as a fallback and is sufficient for this use case.

## Installation

### Via APatch
```bash
# Push module files directly (avoids Windows zip path issues)
adb shell su -c 'mkdir -p /data/adb/modules/audio_mode_fix/system/bin'
adb push module.prop /data/local/tmp/
adb push service.sh /data/local/tmp/
adb push classes.dex /data/local/tmp/
adb shell su -c '
  cp /data/local/tmp/module.prop /data/adb/modules/audio_mode_fix/
  cp /data/local/tmp/service.sh /data/adb/modules/audio_mode_fix/
  cp /data/local/tmp/classes.dex /data/adb/modules/audio_mode_fix/system/bin/
  chmod 755 /data/adb/modules/audio_mode_fix/service.sh
  chmod 644 /data/adb/modules/audio_mode_fix/system/bin/classes.dex
'
adb reboot
```

### Via Magisk
Same as above, or flash a properly packaged zip (ensure forward-slash paths in the archive).

## Verification

After reboot and during a call:

```bash
# Check the fix log
adb shell su -c 'cat /data/local/tmp/audiomodefix.log'

# Expected output:
# [HH:MM:SS.mmm] === Audio Mode Fix v6 started ===
# [HH:MM:SS.mmm] Boot completed, launching persistent watcher
# [HH:MM:SS.mmm] Watcher PID: XXXX
# FIXED:IN_CALL->IN_COMMUNICATION+speaker
```

Check audio mode during call:
```bash
adb shell dumpsys audio | grep "Requested mode"
# Should show: Requested mode = MODE_IN_COMMUNICATION
```

## Drawbacks and Limitations

### 1. Speaker Toggle Behavior
The speaker is forced on by default during calls. While `setSpeakerphoneOn(true)` is called, the Samsung dialer's speaker toggle may not reflect the actual state correctly. The speaker IS active, but the UI button might not toggle as expected. This is a cosmetic issue — audio does route through the speaker.

### 2. Race Condition
There is an inherent race condition: the watcher detects the mode change AFTER it happens, not before. However, because the watcher polls every 50ms using in-process API calls (no JVM restart), it corrects the mode faster than the ABOX firmware can complete the mic re-route. In practice, this is reliable.

### 3. No Native Hook
This is a reactive fix (detect and correct), not a proactive one (intercept before it happens). A native Xposed/VirtualXposed hook on `AudioManager.setMode()` would be cleaner, but LSPosed/Vector doesn't work on this device with APatch's Zygisk implementation.

### 4. Continuous Polling
The watcher runs a 50ms polling loop indefinitely. The CPU overhead is negligible (a single `getMode()` call every 50ms), but it is technically always running.

### 5. HAL May Update
Samsung could change the audio HAL behavior in future firmware updates, which might require re-analysis of the tinymix routing and mode override behavior.

## Technical Details: ABOX Audio Routing

### IN_CALL Mode (Samsung Default)
```
Mic → TDM_DEMUX3 → VSS_TXADAPTER → MCD_TXSE1 → MCD_TXSE2 → VSSIF_TX → Modem
                                                    ↓
                                              VPCMIN_DAI3 (modem input)
```
- Speaker: Works (routed through MCD_RXSE → VPCMOUT_DAI0)
- Mic: Goes to modem, not AudioFlinger

### IN_COMMUNICATION Mode (Our Fix)
```
Mic → TDM_DEMUX3 → VSS_TXADAPTER → MCD_DNN → MCD_TXSE2 → CHMATCHER → VPCMIN_DAI0 → AudioFlinger
```
- Speaker: Forced via `setSpeakerphoneOn(true)`
- Mic: Goes to AudioFlinger → AudioRecord → PhhIms

### Key tinymix Controls
| Control | IN_CALL | IN_COMMUNICATION |
|---------|---------|-----------------|
| VPCMIN_DAI0_A | None | CHMATCHER |
| VPCMIN_DAI3_A | MCD_TXSE1 | None |
| CHMATCHER_A | None | MCD_TXSE2 |
| MCD_DNN_A | None | VSS_TXADAPTER |
| VSSIF_TX_A | MCD_TXSE2 | None |

## Related PhhIms Fixes

This audio fix is part of a larger effort to get PhhIms VoLTE working on Samsung Exynos. The other required fixes include:

1. **ImsResolver feature declaration:** Add `android.hardware.telephony.ims` to device permissions
2. **PhhIms APK modifications:** Remove `sharedUserId`, add `CONNECTIVITY_USE_RESTRICTED_NETWORKS` and `INTERNET` permissions
3. **Privapp permissions:** Grant `BIND_IMS_SERVICE` to PhhIms

## License

This fix is provided as-is for the LineageOS/Samsung Exynos community. Use at your own risk.

## Credits

- komori (myself) — discovery, testing, and implementation
- phhusson — PhhIms project
- JingMatrix — Vector/LSPosed fork (investigated but not used for final solution)
