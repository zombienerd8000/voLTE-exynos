@echo off
REM ============================================
REM Audio Mode Fix + PhhIms VoLTE - One-Click Installer
REM Samsung Exynos + LineageOS
REM ============================================
REM Requirements:
REM   - JDK 17 (JAVA_HOME set)
REM   - Android SDK (ANDROID_HOME set or standard location)
REM   - ADB in PATH or platform-tools in PATH
REM   - Phone with USB debugging + root (APatch/Magisk)
REM ============================================

setlocal
cd /d "%~dp0"

echo.
echo  ==========================================
echo   Audio Mode Fix + PhhIms VoLTE Installer
echo   Samsung Exynos / LineageOS
echo  ==========================================
echo.

REM ---- Find Android SDK ----
set ANDROID_SDK=%ANDROID_HOME%
if "%ANDROID_SDK%"=="" if exist "%LOCALAPPDATA%\Android\Sdk\platforms\android-34\android.jar" set ANDROID_SDK=%LOCALAPPDATA%\Android\Sdk
if "%ANDROID_SDK%"=="" if exist "%USERPROFILE%\Android\Sdk\platforms\android-34\android.jar" set ANDROID_SDK=%USERPROFILE%\Android\Sdk
if "%ANDROID_SDK%"=="" (
    echo ERROR: Android SDK not found.
    echo Set ANDROID_HOME or install SDK to default location.
    echo.
    pause
    exit /b 1
)

set ANDROID_JAR=%ANDROID_SDK%\platforms\android-34\android.jar
set D8=%ANDROID_SDK%\build-tools\34.0.0\d8.bat
set JAVAC=%JAVA_HOME%\bin\javac.exe
if "%JAVAC%"=="" set JAVAC=javac

REM ---- Find ADB ----
where adb >nul 2>&1
if errorlevel 1 (
    if exist "%USERPROFILE%\AppData\Local\Android\Sdk\platform-tools\adb.exe" (
        set ADB=%USERPROFILE%\AppData\Local\Android\Sdk\platform-tools\adb.exe
    ) else if exist "%ANDROID_SDK%\platform-tools\adb.exe" (
        set ADB=%ANDROID_SDK%\platform-tools\adb.exe
    ) else (
        echo ERROR: ADB not found. Install Android SDK platform-tools.
        echo.
        pause
        exit /b 1
    )
) else (
    set ADB=adb
)

REM ============================================
REM PHASE 1: BUILD
REM ============================================
echo [1/4] Compiling Java source...
if not exist "module\system\bin" mkdir "module\system\bin"
"%JAVAC%" -source 17 -target 17 -classpath "%ANDROID_JAR%" -d "module\system\bin" "src\AudioModeHelper.java"
if errorlevel 1 (
    echo ERROR: Java compilation failed.
    echo.
    pause
    exit /b 1
)

echo [2/4] Converting to DEX...
"%D8%" --lib "%ANDROID_JAR%" --output "module\system\bin" "module\system\bin\AudioModeHelper.class"
if errorlevel 1 (
    echo ERROR: D8 conversion failed.
    echo.
    pause
    exit /b 1
)
del "module\system\bin\AudioModeHelper.class"

echo        Build complete!
echo.

REM ============================================
REM PHASE 2: CHECK DEVICE
REM ============================================
echo [3/4] Checking device...
%ADB% get-state >nul 2>&1
if errorlevel 1 (
    echo ERROR: No device found.
    echo.
    echo  1. Enable USB debugging on your phone
    echo  2. Connect via USB
    echo  3. Accept the RSA key prompt on your phone
    echo.
    pause
    exit /b 1
)

%ADB% shell su -c "id" >nul 2>&1
if errorlevel 1 (
    echo ERROR: No root access. Install APatch or Magisk first.
    echo.
    pause
    exit /b 1
)

echo        Device connected and rooted!
echo.

REM ============================================
REM PHASE 3: INSTALL
REM ============================================
echo [4/4] Installing module on device...
echo.

REM Create module directory structure
%ADB% shell su -c "mkdir -p /data/adb/modules/audio_mode_fix/system/bin"
%ADB% shell su -c "mkdir -p /data/adb/modules/audio_mode_fix/system/etc/permissions"
%ADB% shell su -c "mkdir -p /data/adb/modules/audio_mode_fix/system/priv-app/PhhIms"
%ADB% shell su -c "mkdir -p /data/adb/modules/audio_mode_fix/system/product/overlay"

REM Push all files
echo        Pushing files...
%ADB% push module\module.prop /data/local/tmp/ >nul 2>&1
%ADB% push module\service.sh /data/local/tmp/ >nul 2>&1
%ADB% push module\post-fs-data.sh /data/local/tmp/ >nul 2>&1
%ADB% push module\system\bin\classes.dex /data/local/tmp/ >nul 2>&1
%ADB% push module\system\etc\permissions\android.hardware.telephony.ims.xml /data/local/tmp/ >nul 2>&1
%ADB% push module\system\etc\permissions\privapp-permissions-phh.xml /data/local/tmp/ >nul 2>&1
%ADB% push module\system\priv-app\PhhIms\PhhIms.apk /data/local/tmp/ >nul 2>&1
%ADB% push module\system\product\overlay\PhhImsOverlay.apk /data/local/tmp/ >nul 2>&1

REM Copy to module directory and set permissions
echo        Setting up module...
%ADB% shell su -c "MOD=/data/adb/modules/audio_mode_fix; cp /data/local/tmp/module.prop $MOD/; cp /data/local/tmp/service.sh $MOD/; cp /data/local/tmp/post-fs-data.sh $MOD/; cp /data/local/tmp/classes.dex $MOD/system/bin/; cp /data/local/tmp/android.hardware.telephony.ims.xml $MOD/system/etc/permissions/; cp /data/local/tmp/privapp-permissions-phh.xml $MOD/system/etc/permissions/; cp /data/local/tmp/PhhIms.apk $MOD/system/priv-app/PhhIms/; cp /data/local/tmp/PhhImsOverlay.apk $MOD/system/product/overlay/; chmod 755 $MOD/service.sh; chmod 755 $MOD/post-fs-data.sh; chmod 644 $MOD/system/bin/classes.dex; chmod 644 $MOD/system/etc/permissions/*; chmod 644 $MOD/system/priv-app/PhhIms/PhhIms.apk; chmod 644 $MOD/system/product/overlay/PhhImsOverlay.apk" >nul 2>&1

if errorlevel 1 (
    echo ERROR: Failed to install module files.
    echo.
    pause
    exit /b 1
)

echo        Cleaning up temp files...
%ADB% shell "rm -f /data/local/tmp/module.prop /data/local/tmp/service.sh /data/local/tmp/post-fs-data.sh /data/local/tmp/classes.dex /data/local/tmp/android.hardware.telephony.ims.xml /data/local/tmp/privapp-permissions-phh.xml /data/local/tmp/PhhIms.apk /data/local/tmp/PhhImsOverlay.apk" >nul 2>&1

echo.
echo  ==========================================
echo   INSTALLATION COMPLETE
echo  ==========================================
echo.
echo  Rebooting your phone now...
echo.
echo  After reboot:
echo    - PhhIms will be installed as system priv-app
echo    - IMS feature will be declared
echo    - Mic routing will be fixed
echo    - VoLTE should work
echo.
echo  To verify after reboot:
echo    adb shell su -c 'cat /data/local/tmp/audiomodefix.log'
echo.

%ADB% reboot

echo  Phone is rebooting. Done!
echo.
timeout /t 3 >nul

endlocal
