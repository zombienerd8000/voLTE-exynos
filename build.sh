#!/bin/bash
# Build script for Audio Mode Fix (Linux/macOS)
# Requires: JDK 17, Android SDK with build-tools and platforms

set -e

ANDROID_SDK="${ANDROID_HOME:-$HOME/Android/Sdk}"
if [ ! -f "$ANDROID_SDK/platforms/android-34/android.jar" ]; then
    ANDROID_SDK="${LOCALAPPDATA:-/opt}/Android/Sdk"
fi
if [ ! -f "$ANDROID_SDK/platforms/android-34/android.jar" ]; then
    echo "ERROR: Android SDK not found. Set ANDROID_HOME or install SDK to standard location."
    exit 1
fi
ANDROID_JAR="$ANDROID_SDK/platforms/android-34/android.jar"
D8="$ANDROID_SDK/build-tools/34.0.0/d8"
SRC_DIR="src"
MODULE_DIR="module"
OUT_DIR="$MODULE_DIR/system/bin"

echo "[1/3] Compiling Java source..."
mkdir -p "$OUT_DIR"
javac -source 17 -target 17 -classpath "$ANDROID_JAR" -d "$OUT_DIR" "$SRC_DIR/AudioModeHelper.java"

echo "[2/3] Converting to DEX..."
"$D8" --lib "$ANDROID_JAR" --output "$OUT_DIR" "$OUT_DIR/AudioModeHelper.class"
rm -f "$OUT_DIR/AudioModeHelper.class"

echo "[3/3] Building module zip..."
mkdir -p build
cd module
zip -r ../build/audio_mode_fix.zip .
cd ..

echo ""
echo "Done! Module zip: build/audio_mode_fix.zip"
echo ""
echo "Install with:"
echo "  adb push build/audio_mode_fix.zip /data/local/tmp/"
echo "  adb shell su -c 'apd module install /data/local/tmp/audio_mode_fix.zip'"
echo "  adb reboot"
