# VoLTE for Samsung Exynos — Custom ROM Calling Fix

**Enables phone calls on Samsung Exynos devices running LineageOS and other custom ROMs.**

When carriers shut down 2G/3G, Exynos devices on custom ROMs couldn't make calls. This fixes that. One click to install — PhhIms IMS, mic routing fix, permissions, overlay, all configured automatically.

## The Problem

Samsung Exynos devices running LineageOS have two critical issues:

1. **No IMS** — ImsResolver never creates itself because the device tree is missing the `android.hardware.telephony.ims` feature declaration
2. **Mic routing broken** — Samsung audio HAL forces `MODE_IN_CALL`, routing the mic through the modem instead of AudioFlinger. PhhIms captures audio via `AudioRecord`, which needs `MODE_IN_COMMUNICATION`. Result: you can hear the other party, they can't hear you.

Without 2G/3G fallback, these phones literally cannot make calls.

## What This Does

| Component | What It Fixes |
|-----------|---------------|
| **PhhIms APK** | Open-source IMS implementation — enables VoLTE registration and call setup |
| **IMS feature declaration** | Makes ImsResolver create itself at boot |
| **Privapp permissions** | Grants PhhIms privileged APIs (BIND_IMS_SERVICE, etc.) |
| **PhhImsOverlay** | Maps `config_ims_mmtel_package` to `me.phh.ims` |
| **Audio mode fix** | Forces `MODE_IN_COMMUNICATION` when Samsung HAL tries `MODE_IN_CALL` — mic routes through AudioFlinger → PhhIms |
| **Debug properties** | Enables VoLTE, WFC, and IMS on carrier config |
| **Enhanced 4G mode** | Enables VoLTE in system settings |

## Quick Start

1. Enable USB debugging on your phone
2. Connect via USB
3. Run `build.bat` (Windows) or `./build.sh` (Linux/macOS)

That's it. The script builds everything from source, pushes to your phone, and reboots.

**Requirements:** JDK 17, Android SDK, ADB, rooted Samsung Exynos phone (APatch or Magisk), LineageOS 23.2.

## How It Works

### Audio Fix

Samsung audio HAL forces `MODE_IN_CALL` when a call starts, routing mic through modem:

```
Mic → TDM_DEMUX3 → VSS_TXADAPTER → MCD_TXSE1 → VSSIF_TX → Modem (silence to PhhIms)
```

A persistent Java watcher polls `AudioManager.getMode()` every 50ms via `app_process`. When it detects `MODE_IN_CALL`, it immediately forces `MODE_IN_COMMUNICATION` and enables speaker:

```
Mic → TDM_DEMUX3 → VSS_TXADAPTER → MCD_DNN → MCD_TXSE2 → CHMATCHER → VPCMIN_DAI0 → AudioFlinger → PhhIms
```

### PhhIms Installation

Post-fs-data script installs PhhIms as system priv-app with IMS feature declaration, permissions, and overlay. Framework binds to PhhIms as MmTel provider.

## Verification

```bash
# Check the audio fix log
adb shell su -c 'cat /data/local/tmp/audiomodefix.log'

# Check audio mode during call
adb shell dumpsys audio | grep "Requested mode"
# Should show: MODE_IN_COMMUNICATION

# Check PhhIms is bound
adb shell dumpsys telephony.registry | grep -i "ims"
```

## Compatibility

- **Devices:** Samsung Galaxy S20/S21/S22 series (Exynos), A-series, M-series
- **ROMs:** LineageOS 23.2 (Android 16), likely works on other AOSP-based ROMs
- **Root:** APatch + KernelPatch or Magisk
- **Tested on:** SM-G988B (Galaxy S20 Ultra), Exynos 990, Telia Norway

## What's Included

| File | Purpose |
|------|---------|
| `src/AudioModeHelper.java` | Java watcher — forces MODE_IN_COMMUNICATION + speaker |
| `module/service.sh` | Boot service — launches audio watcher, restarts if killed |
| `module/post-fs-data.sh` | Installs PhhIms + permissions + overlay + properties |
| `module/system/priv-app/PhhIms/PhhIms.apk` | PhhIms (BIND_IMS_SERVICE on service, no sharedUserId) |
| `module/system/etc/permissions/android.hardware.telephony.ims.xml` | IMS feature declaration |
| `module/system/etc/permissions/privapp-permissions-phh.xml` | Privileged permissions for PhhIms |
| `module/product/overlay/PhhImsOverlay.apk` | Framework overlay for MmTel provider (MUST be in product/ for Magisk mount) |
| `module/system/product/overlay/PhhImsOverlay.apk` | Same overlay (system path fallback) |
| `build.bat` / `build.sh` | One-click build + install |

## Windows / CRLF Warning

`*.sh` files in this repo are LF. If you edit or re-clone on Windows with
`core.autocrlf=true`, git may write CRLF line endings into `service.sh` /
`post-fs-data.sh`, which makes `sh` throw `syntax error: unmatched if` on the
device and the watcher will never start. The `.gitattributes` file forces LF on
checkout, but if you are packaging your own zip:

- After cloning, verify with: `git config core.autocrlf false` (or just don't
  re-touch the `.sh` files).
- Check before flashing: the `service.sh` inside your zip must contain no CR
  bytes:
  ```powershell
  # in PowerShell, after extracting service.sh:
  ([System.IO.File]::ReadAllBytes('service.sh') | Where-Object { $_ -eq 13 }).Count   # must be 0
  ```
- Build zips with forward-slash paths (PowerShell `Compress-Archive` uses
  backslashes, which Magisk rejects). The provided `build.bat` uses a
  stdlib zip routine with forward slashes.

## Credits

- **komori (myself)** — discovery, testing, and implementation
- **phhusson** — PhhIms project
- **JingMatrix** — Vector/LSPosed fork (investigated but not used)

## License

MIT
