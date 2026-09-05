#!/system/bin/sh
# Audio Mode Fix + PhhIms VoLTE - post-fs-data installer
# Installs PhhIms as system priv-app with all required permissions and overlays
MODDIR="${0%/*}"
LOGFILE="/data/local/tmp/audiomodefix.log"

log() {
    echo "[$(date '+%H:%M:%S.%N' | cut -c1-12)] $1" >> "$LOGFILE"
}

log "=== post-fs-data: installing PhhIms + permissions ==="

# Mount system as rw
mount -o rw,remount / 2>/dev/null
mount -o rw,remount /system 2>/dev/null
mount -o rw,remount /product 2>/dev/null

# 1. Install PhhIms as system priv-app
mkdir -p /system/priv-app/PhhIms
cp -f "$MODDIR/system/priv-app/PhhIms/PhhIms.apk" /system/priv-app/PhhIms/PhhIms.apk
chmod 644 /system/priv-app/PhhIms/PhhIms.apk
chown root:root /system/priv-app/PhhIms/PhhIms.apk
log "PhhIms APK installed to /system/priv-app/PhhIms/"

# 2. Install IMS feature declaration (makes ImsResolver create itself)
cp -f "$MODDIR/system/etc/permissions/android.hardware.telephony.ims.xml" /system/etc/permissions/android.hardware.telephony.ims.xml
chmod 644 /system/etc/permissions/android.hardware.telephony.ims.xml
log "IMS feature declaration installed"

# 3. Install privapp permissions
cp -f "$MODDIR/system/etc/permissions/privapp-permissions-phh.xml" /system/etc/permissions/privapp-permissions-phh.xml
chmod 644 /system/etc/permissions/privapp-permissions-phh.xml
log "Privapp permissions installed"

# 4. Install PhhImsOverlay (maps config_ims_mmtel_package to me.phh.ims)
mkdir -p /system/product/overlay
cp -f "$MODDIR/system/product/overlay/PhhImsOverlay.apk" /system/product/overlay/PhhImsOverlay.apk
chmod 644 /system/product/overlay/PhhImsOverlay.apk
log "PhhImsOverlay installed"

# 5. Set debug properties for VoLTE
resetprop persist.dbg.volte_avail_ovr 1 2>/dev/null
resetprop persist.dbg.wfc_avail_ovr 1 2>/dev/null
resetprop persist.dbg.allow_ims_off 1 2>/dev/null
resetprop persist.radio.calls.on.ims 1 2>/dev/null
log "Debug properties set"

# 6. Enable enhanced 4G mode (VoLTE)
settings put global enhanced_4g_mode_enabled 1 2>/dev/null
log "Enhanced 4G mode enabled"

# Remount system as ro
mount -o ro,remount / 2>/dev/null
mount -o ro,remount /system 2>/dev/null
mount -o ro,remount /product 2>/dev/null

log "=== post-fs-data: installation complete ==="
