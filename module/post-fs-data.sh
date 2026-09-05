#!/system/bin/sh
# Audio Mode Fix + PhhIms VoLTE - post-fs-data installer
# Sets properties and ensures overlay is in the right place
MODDIR="${0%/*}"
LOGFILE="/data/local/tmp/audiomodefix.log"

log() {
    echo "[$(date '+%H:%M:%S.%N' | cut -c1-12)] $1" >> "$LOGFILE"
}

log "=== post-fs-data: configuring PhhIms ==="

# 1. Copy overlay to /product/overlay if not already there (some devices need this)
if [ ! -f /product/overlay/PhhImsOverlay.apk ]; then
    mkdir -p /product/overlay 2>/dev/null
    mount -o rw,remount /product 2>/dev/null
    cp -f "$MODDIR/product/overlay/PhhImsOverlay.apk" /product/overlay/PhhImsOverlay.apk 2>/dev/null
    chmod 644 /product/overlay/PhhImsOverlay.apk 2>/dev/null
    mount -o ro,remount /product 2>/dev/null
    log "Overlay copied to /product/overlay/"
fi

# Also try /system/product/overlay
if [ ! -f /system/product/overlay/PhhImsOverlay.apk ]; then
    mkdir -p /system/product/overlay 2>/dev/null
    mount -o rw,remount / 2>/dev/null
    mount -o rw,remount /system 2>/dev/null
    cp -f "$MODDIR/product/overlay/PhhImsOverlay.apk" /system/product/overlay/PhhImsOverlay.apk 2>/dev/null
    chmod 644 /system/product/overlay/PhhImsOverlay.apk 2>/dev/null
    mount -o ro,remount / 2>/dev/null
    mount -o ro,remount /system 2>/dev/null
    log "Overlay copied to /system/product/overlay/"
fi

# 2. Set debug properties for VoLTE
resetprop persist.dbg.volte_avail_ovr 1 2>/dev/null
resetprop persist.dbg.wfc_avail_ovr 1 2>/dev/null
resetprop persist.dbg.allow_ims_off 1 2>/dev/null
resetprop persist.radio.calls.on.ims 1 2>/dev/null
log "Debug properties set"

# 3. Enable enhanced 4G mode (VoLTE)
settings put global enhanced_4g_mode_enabled 1 2>/dev/null
log "Enhanced 4G mode enabled"

log "=== post-fs-data: configuration complete ==="
