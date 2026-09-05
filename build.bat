@echo off
REM Build script for Audio Mode Fix (Windows)
REM Requires: JDK 17, Android SDK with platforms;android-34 and build-tools;34.0.0

setlocal
cd /d "%~dp0"

REM Find Android SDK
set ANDROID_SDK=%ANDROID_HOME%
if "%ANDROID_SDK%"=="" if exist "%LOCALAPPDATA%\Android\Sdk\platforms\android-34\android.jar" set ANDROID_SDK=%LOCALAPPDATA%\Android\Sdk
if "%ANDROID_SDK%"=="" if exist "%USERPROFILE%\Android\Sdk\platforms\android-34\android.jar" set ANDROID_SDK=%USERPROFILE%\Android\Sdk
if "%ANDROID_SDK%"=="" (echo ERROR: Android SDK not found. Set ANDROID_HOME or install SDK. & exit /b 1)

set ANDROID_JAR=%ANDROID_SDK%\platforms\android-34\android.jar
set D8=%ANDROID_SDK%\build-tools\34.0.0\d8.bat
set JAVAC=%JAVA_HOME%\bin\javac.exe
if "%JAVAC%"=="" set JAVAC=javac

echo [1/3] Compiling Java source...
if not exist "module\system\bin" mkdir "module\system\bin"
"%JAVAC%" -source 17 -target 17 -classpath "%ANDROID_JAR%" -d "module\system\bin" "src\AudioModeHelper.java"
if errorlevel 1 (echo FAILED & exit /b 1)

echo [2/3] Converting to DEX...
"%D8%" --lib "%ANDROID_JAR%" --output "module\system\bin" "module\system\bin\AudioModeHelper.class"
if errorlevel 1 (echo FAILED & exit /b 1)
del "module\system\bin\AudioModeHelper.class"

echo [3/3] Done!
echo.
echo Module files ready in module/
echo.
echo Install with:
echo   adb push module\module.prop /data/local/tmp/
echo   adb push module\service.sh /data/local/tmp/
echo   adb push module\system\bin\classes.dex /data/local/tmp/
echo   adb shell su -c "mkdir -p /data/adb/modules/audio_mode_fix/system/bin"
echo   adb shell su -c "cp /data/local/tmp/module.prop /data/adb/modules/audio_mode_fix/"
echo   adb shell su -c "cp /data/local/tmp/service.sh /data/adb/modules/audio_mode_fix/"
echo   adb shell su -c "cp /data/local/tmp/classes.dex /data/adb/modules/audio_mode_fix/system/bin/"
echo   adb shell su -c "chmod 755 /data/adb/modules/audio_mode_fix/service.sh"
echo   adb shell su -c "chmod 644 /data/adb/modules/audio_mode_fix/system/bin/classes.dex"
echo   adb reboot

endlocal
