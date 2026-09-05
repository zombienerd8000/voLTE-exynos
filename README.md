# Audio Mode Fix + PhhIms VoLTE for Samsung Exynos

One-click Magisk/APatch module that gets VoLTE working on Samsung Exynos devices running LineageOS.

## What It Does

1. **Installs PhhIms** — open-source IMS implementation for VoLTE on custom ROMs
2. **Fixes mic routing** — Samsung audio HAL forces `MODE_IN_CALL` which routes mic through modem. This module forces `MODE_IN_COMMUNICATION` so mic goes through AudioFlinger → PhhIms
3. **Sets up permissions** — IMS feature declaration, privapp permissions, overlay, debug properties

## Requirements

- Samsung Exynos device (tested on SM-G988B / Galaxy S20 Ultra, Exynos 990)
- LineageOS 23.2 (Android 16)
- Root: APatch + KernelPatch or Magisk

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
# Push all module files
adb shell su -c 'mkdir -p /data/adb/modules/audio_mode_fix/system/bin'
adb shell su -c 'mkdir -p /data/adb/modules/audio_mode_fix/system/etc/permissions'
adb shell su -c 'mkdir -p /data/adb/modules/audio_mode_fix/system/priv-app/PhhIms'
adb shell su -c 'mkdir -p /data/adb/modules/audio_mode_fix/system/product/overlay'

adb push module/module.prop /data/local/tmp/
adb push module/service.sh /data/local/tmp/
adb push module/post-fs-data.sh /data/local/tmp/
adb push module/system/bin/classes.dex /data/local/tmp/
adb push module/system/etc/permissions/android.hardware.telephony.ims.xml /data/local/tmp/
adb push module/system/etc/permissions/privapp-permissions-phh.xml /data/local/tmp/
adb push module/system/priv-app/PhhIms/PhhIms.apk /data/local/tmp/
adb push module/system/product/overlay/PhhImsOverlay.apk /data/local/tmp/

adb shell su -c '
  MOD=/data/adb/modules/audio_mode_fix
  cp /data/local/tmp/module.prop $MOD/
  cp /data/local/tmp/service.sh $MOD/
  cp /data/local/tmp/post-fs-data.sh $MOD/
  cp /data/local/tmp/classes.dex $MOD/system/bin/
  cp /data/local/tmp/android.hardware.telephony.ims.xml $MOD/system/etc/permissions/
  cp /data/local/tmp/privapp-permissions-phh.xml $MOD/system/etc/permissions/
  cp /data/local/tmp/PhhIms.apk $MOD/system/priv-app/PhhIms/
  cp /data/local/tmp/PhhImsOverlay.apk $MOD/system/product/overlay/
  chmod 755 $MOD/service.sh
  chmod 755 $MOD/post-fs-data.sh
  chmod 644 $MOD/system/bin/classes.dex
  chmod 644 $MOD/system/etc/permissions/*
  chmod 644 $MOD/system/priv-app/PhhIms/PhhIms.apk
  chmod 644 $MOD/system/product/overlay/PhhImsOverlay.apk
'
adb reboot
```

## How It Works

### Audio Fix (service.sh + classes.dex)

Samsung audio HAL forces `MODE_IN_CALL` when a call starts, routing mic through modem:

```
Mic → TDM_DEMUX3 → VSS_TXADAPTER → MCD_TXSE1 → VSSIF_TX → Modem
```

A persistent Java watcher (via `app_process`) polls `AudioManager.getMode()` every 50ms. When it detects `MODE_IN_CALL`, it immediately forces `MODE_IN_COMMUNICATION` and enables speaker:

```
Mic → TDM_DEMUX3 → VSS_TXADAPTER → MCD_DNN → MCD_TXSE2 → CHMATCHER → VPCMIN_DAI0 → AudioFlinger → PhhIms
```

### PhhIms Installation (post-fs-data.sh)

Copies PhhIms as a system priv-app and installs:
- `android.hardware.telephony.ims.xml` — makes ImsResolver create itself
- `privapp-permissions-phh.xml` — allows PhhIms to use privileged APIs
- `PhhImsOverlay.apk` — maps `config_ims_mmtel_package` to `me.phh.ims`
- Debug properties for VoLTE enablement

## Verification

After reboot and during a call:

```bash
# Check the audio fix log
adb shell su -c 'cat /data/local/tmp/audiomodefix.log'

# Check audio mode
adb shell dumpsys audio | grep "Requested mode"
# Should show: MODE_IN_COMMUNICATION

# Check PhhIms is bound
adb shell dumpsys telephony.registry | grep -i "ims"
```

## What's Included

| File | Purpose |
|------|---------|
| `src/AudioModeHelper.java` | Java watcher source |
| `module/service.sh` | Boot service (launches audio watcher) |
| `module/post-fs-data.sh` | Installs PhhIms + permissions at boot |
| `module/module.prop` | Magisk module metadata |
| `module/system/bin/classes.dex` | Compiled audio watcher |
| `module/system/etc/permissions/android.hardware.telephony.ims.xml` | IMS feature declaration |
| `module/system/etc/permissions/privapp-permissions-phh.xml` | Privileged permissions |
| `module/system/priv-app/PhhIms/PhhIms.apk` | Patched PhhIms (Android 16 compatible) |
| `module/system/product/overlay/PhhImsOverlay.apk` | Framework overlay for MmTel provider |

## Credits

- komori (myself) — discovery, testing, and implementation
- phhusson — PhhIms project
- JingMatrix — Vector/LSPosed fork (investigated but not used)

## License

MIT
