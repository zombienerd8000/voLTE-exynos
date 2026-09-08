#!/system/bin/sh
# Audio Mode Fix - Magisk/APatch service script
# Launches persistent Java watcher to fix Samsung Exynos mic routing
MODDIR="${0%/*}"
LOGFILE="/data/local/tmp/audiomodefix.log"
HELPER="$MODDIR/system/bin/classes.dex"

log() {
    echo "[$(date '+%H:%M:%S.%N' | cut -c1-12)] $1" >> "$LOGFILE"
}

log "=== Audio Mode Fix started ==="

while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 1
done
sleep 3

log "Boot completed, launching persistent watcher"

CLASSPATH="$HELPER" app_process /system/bin AudioModeHelper watch >> "$LOGFILE" 2>&1 &
WATCHER_PID=$!
log "Watcher PID: $WATCHER_PID"

while true; do
    if ! kill -0 $WATCHER_PID 2>/dev/null; then
        log "Watcher died, restarting..."
        CLASSPATH="$HELPER" app_process /system/bin AudioModeHelper watch >> "$LOGFILE" 2>&1 &
        WATCHER_PID=$!
        log "New watcher PID: $WATCHER_PID"
    fi
    sleep 5
done