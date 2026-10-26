#!/bin/zsh
# Print the AirportItlwm event log (ioreg "ItlwmEventLog", diag builds only) with local times,
# and save a copy. No sudo needed. The driver keeps the last 400 events since boot (joins,
# state changes, scans, WCL commands, firmware errors).
#   zsh itlwm-log.sh            print and save
#   zsh itlwm-log.sh -n 40      print only the last 40 events
# Copies are saved in $ITLWM_LOG_DIR, or ~/Library/Logs/itlwm by default.
N=0
[ "$1" = "-n" ] && N=$2
DIR=${ITLWM_LOG_DIR:-$HOME/Library/Logs/itlwm}
mkdir -p "$DIR" || exit 1
OUT="$DIR/itlwm-eventlog-$(date +%Y%m%d-%H%M%S).txt"
ioreg -a -l -w0 -r -k ItlwmEventLog | /usr/bin/python3 -I -c '
import plistlib, sys, time
def find(o):
    if isinstance(o, dict):
        if "ItlwmEventLog" in o:
            return o["ItlwmEventLog"]
        for v in o.values():
            r = find(v)
            if r: return r
    if isinstance(o, list):
        for v in o:
            r = find(v)
            if r: return r
    return None
data = sys.stdin.buffer.read()
log = find(plistlib.loads(data)) if data.strip() else None
if not log:
    print("No ItlwmEventLog in ioreg (not a diag build, or no events yet).")
    sys.exit(1)
n = int(sys.argv[1])
for line in (log[-n:] if n else log):
    t, _, msg = line.partition(" ")
    try:
        sec = float(t)
        stamp = time.strftime("%H:%M:%S", time.localtime(sec)) + ".%03d" % round((sec % 1) * 1000)
    except ValueError:
        stamp = t
    print(stamp, msg)
' $N | tee "$OUT"
echo "(saved to $OUT)"
