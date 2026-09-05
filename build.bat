@echo off
REM Build script for Audio Mode Fix (Windows)
REM Requires: JDK 17, Android SDK with build-tools and platforms

setlocal

set ANDROID_SDK=%ANDROID_HOME%
if "%ANDROID_SDK%"=="" set ANDROID_SDK=%LOCALAPPDATA%\Android\Sdk
set ANDROID_JAR=%ANDROID_SDK%\platforms\android-34\android.jar
set D8=%ANDROID_SDK%\build-tools\34.0.0\d8.bat
set JAVAC=%JAVA_HOME%\bin\javac.exe
if "%JAVAC%"=="" set JAVAC=javac

set SRC_DIR=src
set MODULE_DIR=module
set BUILD_DIR=build
set OUT_DIR=%MODULE_DIR%\system\bin

echo [1/3] Compiling Java source...
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"
"%JAVAC%" -source 17 -target 17 -classpath "%ANDROID_JAR%" -d "%OUT_DIR%" "%SRC_DIR%\AudioModeHelper.java"
if errorlevel 1 (echo FAILED: javac & exit /b 1)

echo [2/3] Converting to DEX...
"%D8%" --lib "%ANDROID_JAR%" --output "%OUT_DIR%" "%OUT_DIR%\AudioModeHelper.class"
if errorlevel 1 (echo FAILED: d8 & exit /b 1)
del "%OUT_DIR%\AudioModeHelper.class"

echo [3/3] Building module zip...
cd module
powershell -Command "Compress-Archive -Path '*' -DestinationPath '..\build\audio_mode_fix.zip' -Force"
cd ..
echo.
echo Done! Module zip: build\audio_mode_fix.zip
echo.
echo Install with:
echo   adb push build\audio_mode_fix.zip /data/local/tmp/
echo   adb shell su -c 'apd module install /data/local/tmp/audio_mode_fix.zip'
echo   adb reboot
echo.
echo Or push files directly (avoids zip path issues on Windows):
echo   adb shell su -c 'mkdir -p /data/adb/modules/audio_mode_fix/system/bin'
echo   adb push module/module.prop /data/local/tmp/
echo   adb push module/service.sh /data/local/tmp/
echo   adb push module/system/bin/classes.dex /data/local/tmp/
echo   adb shell su -c "cp /data/local/tmp/module.prop /data/adb/modules/audio_mode_fix/; cp /data/local/tmp/service.sh /data/adb/modules/audio_mode_fix/; cp /data/local/tmp/classes.dex /data/adb/modules/audio_mode_fix/system/bin/; chmod 755 /data/adb/modules/audio_mode_fix/service.sh; chmod 644 /data/adb/modules/audio_mode_fix/system/bin/classes.dex"
echo   adb reboot

endlocal
