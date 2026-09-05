#!/bin/bash
# ============================================
# Audio Mode Fix + PhhIms VoLTE - One-Click Installer
# Samsung Exynos / LineageOS
# ============================================
# Requirements:
#   - JDK 17 (JAVA_HOME set)
#   - Android SDK (ANDROID_HOME set or standard location)
#   - ADB in PATH
#   - Phone with USB debugging + root (APatch/Magisk)
# ============================================

set -e

echo ""
echo "  =========================================="
echo "   Audio Mode Fix + PhhIms VoLTE Installer"
echo "   Samsung Exynos / LineageOS"
echo "  =========================================="
echo ""

# ---- Find Android SDK ----
ANDROID_SDK="${ANDROID_HOME:-$HOME/Android/Sdk}"
if [ ! -f "$ANDROID_SDK/platforms/android-34/android.jar" ]; then
    ANDROID_SDK="${LOCALAPPDATA:-/opt}/Android/Sdk"
fi
if [ ! -f "$ANDROID_SDK/platforms/android-34/android.jar" ]; then
    echo "ERROR: Android SDK not found."
    echo "Set ANDROID_HOME or install SDK to standard location."
    exit 1
fi

ANDROID_JAR="$ANDROID_SDK/platforms/android-34/android.jar"
D8="$ANDROID_SDK/build-tools/34.0.0/d8"

# ---- Find ADB ----
if ! command -v adb &> /dev/null; then
    if [ -f "$ANDROID_SDK/platform-tools/adb" ]; then
        ADB="$ANDROID_SDK/platform-tools/adb"
    else
        echo "ERROR: ADB not found. Install Android SDK platform-tools."
        exit 1
    fi
else
    ADB=adb
fi

# ============================================
# PHASE 1: BUILD
# ============================================
echo "[1/4] Compiling Java source..."
mkdir -p module/system/bin
javac -source 17 -target 17 -classpath "$ANDROID_JAR" -d module/system/bin src/AudioModeHelper.java

echo "[2/4] Converting to DEX..."
"$D8" --lib "$ANDROID_JAR" --output module/system/bin module/system/bin/AudioModeHelper.class
rm -f module/system/bin/AudioModeHelper.class

echo "       Build complete!"
echo ""

# ============================================
# PHASE 2: CHECK DEVICE
# ============================================
echo "[3/4] Checking device..."
if ! $ADB get-state &> /dev/null; then
    echo "ERROR: No device found."
    echo ""
    echo " 1. Enable USB debugging on your phone"
    echo " 2. Connect via USB"
    echo " 3. Accept the RSA key prompt on your phone"
    exit 1
fi

if ! $ADB shell su -c "id" &> /dev/null; then
    echo "ERROR: No root access. Install APatch or Magisk first."
    exit 1
fi

echo "       Device connected and rooted!"
echo ""

# ============================================
# PHASE 3: INSTALL
# ============================================
echo "[4/4] Installing module on device..."
echo ""

# Create module directory structure
$ADB shell su -c "mkdir -p /data/adb/modules/audio_mode_fix/system/bin"
$ADB shell su -c "mkdir -p /data/adb/modules/audio_mode_fix/system/etc/permissions"
$ADB shell su -c "mkdir -p /data/adb/modules/audio_mode_fix/system/priv-app/PhhIms"
$ADB shell su -c "mkdir -p /data/adb/modules/audio_mode_fix/system/product/overlay"
$ADB shell su -c "mkdir -p /data/adb/modules/audio_mode_fix/product/overlay"

# Push all files
echo "       Pushing files..."
$ADB push module/module.prop /data/local/tmp/ > /dev/null 2>&1
$ADB push module/service.sh /data/local/tmp/ > /dev/null 2>&1
$ADB push module/post-fs-data.sh /data/local/tmp/ > /dev/null 2>&1
$ADB push module/system/bin/classes.dex /data/local/tmp/ > /dev/null 2>&1
$ADB push module/system/etc/permissions/android.hardware.telephony.ims.xml /data/local/tmp/ > /dev/null 2>&1
$ADB push module/system/etc/permissions/privapp-permissions-phh.xml /data/local/tmp/ > /dev/null 2>&1
$ADB push module/system/priv-app/PhhIms/PhhIms.apk /data/local/tmp/ > /dev/null 2>&1
$ADB push module/product/overlay/PhhImsOverlay.apk /data/local/tmp/ > /dev/null 2>&1

# Copy to module directory and set permissions
echo "       Setting up module..."
$ADB shell su -c '
MOD=/data/adb/modules/audio_mode_fix
cp /data/local/tmp/module.prop $MOD/
cp /data/local/tmp/service.sh $MOD/
cp /data/local/tmp/post-fs-data.sh $MOD/
cp /data/local/tmp/classes.dex $MOD/system/bin/
cp /data/local/tmp/android.hardware.telephony.ims.xml $MOD/system/etc/permissions/
cp /data/local/tmp/privapp-permissions-phh.xml $MOD/system/etc/permissions/
cp /data/local/tmp/PhhIms.apk $MOD/system/priv-app/PhhIms/
cp /data/local/tmp/PhhImsOverlay.apk $MOD/system/product/overlay/
cp /data/local/tmp/PhhImsOverlay.apk $MOD/product/overlay/
chmod 755 $MOD/service.sh
chmod 755 $MOD/post-fs-data.sh
chmod 644 $MOD/system/bin/classes.dex
chmod 644 $MOD/system/etc/permissions/*
chmod 644 $MOD/system/priv-app/PhhIms/PhhIms.apk
chmod 644 $MOD/system/product/overlay/PhhImsOverlay.apk
chmod 644 $MOD/product/overlay/PhhImsOverlay.apk
' > /dev/null 2>&1

echo "       Cleaning up temp files..."
$ADB shell "rm -f /data/local/tmp/module.prop /data/local/tmp/service.sh /data/local/tmp/post-fs-data.sh /data/local/tmp/classes.dex /data/local/tmp/android.hardware.telephony.ims.xml /data/local/tmp/privapp-permissions-phh.xml /data/local/tmp/PhhIms.apk /data/local/tmp/PhhImsOverlay.apk" > /dev/null 2>&1

echo ""
echo "  =========================================="
echo "   INSTALLATION COMPLETE"
echo "  =========================================="
echo ""
echo "  Rebooting your phone now..."
echo ""
echo "  After reboot:"
echo "    - PhhIms will be installed as system priv-app"
echo "    - IMS feature will be declared"
echo "    - Mic routing will be fixed"
echo "    - VoLTE should work"
echo ""
echo "  To verify after reboot:"
echo "    adb shell su -c 'cat /data/local/tmp/audiomodefix.log'"
echo ""

$ADB reboot

echo "  Phone is rebooting. Done!"
echo ""
