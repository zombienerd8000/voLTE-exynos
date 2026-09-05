# Audio Mode Fix for Samsung Exynos VoLTE Mic Routing

A Magisk/APatch module that fixes microphone routing on Samsung Exynos devices running LineageOS, allowing PhhIms (or any VoIP IMS) to capture mic audio during VoLTE calls.

## The Problem

Samsung's audio HAL forces `MODE_IN_CALL` when a call starts, routing the mic through the modem path instead of AudioFlinger. This breaks PhhIms because it captures audio via `AudioRecord` (which needs `MODE_IN_COMMUNICATION`).

## The Fix

A persistent Java watcher process (via `app_process`) monitors the audio mode every 50ms. When it detects `MODE_IN_CALL`, it immediately forces `MODE_IN_COMMUNICATION` and enables speaker output.

## Quick Start

### Build

```bash
# Linux/macOS
chmod +x build.sh
./build.sh

# Windows
build.bat
```

Requires JDK 17 and Android SDK (platforms;android-34, build-tools;34.0.0).

### Install

```bash
# Option 1: Flash zip (may have path issues on Windows)
adb push build/audio_mode_fix.zip /data/local/tmp/
adb shell su -c 'apd module install /data/local/tmp/audio_mode_fix.zip'
adb reboot

# Option 2: Push files directly (recommended)
adb shell su -c 'mkdir -p /data/adb/modules/audio_mode_fix/system/bin'
adb push module/module.prop /data/local/tmp/
adb push module/service.sh /data/local/tmp/
adb push module/system/bin/classes.dex /data/local/tmp/
adb shell su -c '
  cp /data/local/tmp/module.prop /data/adb/modules/audio_mode_fix/
  cp /data/local/tmp/service.sh /data/adb/modules/audio_mode_fix/
  cp /data/local/tmp/classes.dex /data/adb/modules/audio_mode_fix/system/bin/
  chmod 755 /data/adb/modules/audio_mode_fix/service.sh
  chmod 644 /data/adb/modules/audio_mode_fix/system/bin/classes.dex
'
adb reboot
```

### Verify

```bash
# Check the log during a call
adb shell su -c 'cat /data/local/tmp/audiomodefix.log'

# Check audio mode
adb shell dumpsys audio | grep "Requested mode"
# Should show: MODE_IN_COMMUNICATION
```

## How It Works

```
Samsung HAL sets MODE_IN_CALL
        ↓
Mic routed to modem: DEMUX3 → VSS_TXADAPTER → MCD_TXSE1 → VSSIF_TX → Modem
        ↓
Watcher detects IN_CALL (50ms poll, in-process API)
        ↓
Forces MODE_IN_COMMUNICATION + setSpeakerphoneOn(true)
        ↓
Mic rerouted to AudioFlinger: VSS_TXADAPTER → MCD_DNN → CHMATCHER → VPCMIN_DAI0 → AudioFlinger
        ↓
PhhIms captures mic via AudioRecord
```

## Project Structure

```
audio_mode_fix/
├── src/
│   └── AudioModeHelper.java     # Java watcher source
├── module/
│   ├── module.prop              # Magisk module metadata
│   ├── service.sh               # Boot service (launches watcher)
│   ├── system/
│   │   └── bin/
│   │       └── classes.dex      # Compiled watcher (generated)
│   └── META-INF/
│       └── com/google/android/
│           ├── update-binary    # Magisk installer
│           └── updater-script
├── build.sh                     # Build script (Linux/macOS)
├── build.bat                    # Build script (Windows)
└── README.md
```

## Compatibility

- **Tested on:** Samsung Galaxy S20 Ultra (SM-G988B), Exynos 990
- **ROM:** LineageOS 23.2 (Android 16)
- **Root:** APatch + KernelPatch
- **Likely works on:** All Samsung Exynos devices with the same ABOX audio HAL

## Drawbacks

- **Speaker forced on:** `setSpeakerphoneOn(true)` is called on every detection. Speaker toggle in the dialer may not reflect state correctly, but audio routes through speaker.
- **Reactive, not proactive:** Detects the mode change after it happens and corrects it. Works in practice because the 50ms in-process poll is faster than the HAL's override cycle.
- **Continuous polling:** Runs a 50ms loop indefinitely. CPU overhead is negligible.

## Why Not Xposed/LSPosed?

LSPosed v1.9.2 doesn't support Android 16. The JingMatrix/Vector fork (v2.2) supports Android 16 but requires a Zygisk implementation that APatch's built-in Zygisk doesn't provide. The daemon crashes with "No response from bridge" on APatch.

This Magisk module approach works without any Xposed framework.

## License

MIT
