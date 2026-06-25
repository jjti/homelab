#!/usr/bin/env bash
# netproof.sh — long-lived connectivity proof for an ISP dispute (Verizon FiOS).
#
# Every WINDOW seconds it pings three targets in parallel over the same window and
# records loss% + avg latency for each, then classifies the minute:
#
#   LOCAL         loss to YOUR OWN router  -> your LAN / wifi / router, NOT the ISP
#   ISP/UPSTREAM  both public anchors lossy while router is fine -> upstream (Verizon)
#   DEST?         only ONE public anchor lossy -> that destination/peering, not your link
#   SLOW          no loss, but internet latency is high
#   ok            healthy
#
# Two independent public anchors (Cloudflare + Google) are used on purpose: if BOTH
# degrade at the same instant while your router stays clean, the problem is almost
# certainly your upstream link, not any one service. That is the evidence Verizon
# can't wave away.
#
# When mtr is installed it also captures hop-by-hop reports (periodically, and on
# every outage) so you can point at the exact hop where loss begins — typically the
# first Verizon hop, hop 2, right after your router at hop 1.
#
# Uses raw ICMP only (numeric IPs, no DNS) so your self-hosted Pi-hole/dnscrypt can't
# muddy the picture — this measures the link, not name resolution.

set -u

# ---------------- config (override via env, e.g. WINDOW=30 bash netproof.sh) -----
ROUTER="${ROUTER:-$(ip route 2>/dev/null | awk '/^default/{print $3; exit}')}"
[ -z "$ROUTER" ] && ROUTER="192.168.0.1"   # your FiOS router (the local path)
ANCHOR1="${ANCHOR1:-1.1.1.1}"              # Cloudflare  (public anchor A)
ANCHOR2="${ANCHOR2:-8.8.8.8}"              # Google      (public anchor B)
WINDOW="${WINDOW:-60}"                      # seconds per sample window (= packets, 1/s)
LOSS_BAD="${LOSS_BAD:-5}"                   # loss% at/above this counts as bad
RTT_BAD="${RTT_BAD:-150}"                   # avg ms at/above this on the internet = slow
MTR_EVERY="${MTR_EVERY:-5}"                 # also run a periodic mtr every N windows
MTR_TARGET="${MTR_TARGET:-$ANCHOR2}"        # trace the path toward this anchor

OUTDIR="${OUTDIR:-$HOME/netproof}"
mkdir -p "$OUTDIR"
STAMP="$(date +%Y%m%d_%H%M%S)"
CSV="$OUTDIR/netproof_${STAMP}.csv"
MTRLOG="$OUTDIR/netproof_${STAMP}_mtr.log"

have_mtr=0; command -v mtr >/dev/null 2>&1 && have_mtr=1

echo "ts,router_loss%,router_ms,cf_loss%,cf_ms,goog_loss%,goog_ms,verdict" > "$CSV"

echo "netproof running  (Ctrl-C to stop)"
echo "  router (local) : $ROUTER"
echo "  public anchors : $ANCHOR1 (Cloudflare) + $ANCHOR2 (Google)"
echo "  window         : ${WINDOW}s   bad>=${LOSS_BAD}% loss / ${RTT_BAD}ms"
echo "  csv log        : $CSV"
if [ "$have_mtr" = 1 ]; then
  echo "  mtr reports    : $MTRLOG  (every ${MTR_EVERY} windows + on every outage)"
else
  echo "  mtr reports    : OFF — 'mtr' not installed."
  echo "                   Install on Bazzite: rpm-ostree install mtr   (then reboot)"
  echo "                   The CSV proof below works fine without it."
fi
echo

# ping a target for WINDOW seconds; echo "loss avg"
probe() {
  local host="$1" out loss avg
  out="$(ping -n -c "$WINDOW" -i 1 -W 1 "$host" 2>/dev/null)"
  loss="$(printf '%s\n' "$out" | sed -n 's/.* \([0-9.]*\)% packet loss.*/\1/p')"
  avg="$( printf '%s\n' "$out" | sed -n 's@.*= [0-9.]*/\([0-9.]*\)/.*@\1@p')"
  [ -z "$loss" ] && loss=100
  [ -z "$avg"  ] && avg="-"
  printf '%s %s\n' "$loss" "$avg"
}

ge() { awk "BEGIN{exit !($1>=$2)}"; }   # numeric >= test

run_mtr() {
  [ "$have_mtr" = 1 ] || return 0
  { echo "===== $(date '+%Y-%m-%d %H:%M:%S')  mtr -> $MTR_TARGET  ($1) ====="
    mtr -n -4 --report --report-cycles 30 -i 1 "$MTR_TARGET" 2>&1
    echo
  } >> "$MTRLOG"
}

trap 'echo; echo "stopped. logs:"; echo "  $CSV"; [ "$have_mtr" = 1 ] && echo "  $MTRLOG"; exit 0' INT TERM

i=0
while true; do
  i=$((i+1))
  ts="$(date "+%Y-%m-%d %H:%M:%S")"
  start=$SECONDS

  rt="$(mktemp)"; at="$(mktemp)"; bt="$(mktemp)"
  probe "$ROUTER"  > "$rt" &
  probe "$ANCHOR1" > "$at" &
  probe "$ANCHOR2" > "$bt" &
  wait
  read -r rL rR < "$rt"; read -r aL aR < "$at"; read -r bL bR < "$bt"
  rm -f "$rt" "$at" "$bt"

  router_bad=0; ge "$rL" "$LOSS_BAD" && router_bad=1
  cf_bad=0;     ge "$aL" "$LOSS_BAD" && cf_bad=1
  goog_bad=0;   ge "$bL" "$LOSS_BAD" && goog_bad=1

  if [ "$router_bad" = 1 ]; then
    verdict="LOCAL"
  elif [ "$cf_bad" = 1 ] && [ "$goog_bad" = 1 ]; then
    verdict="ISP/UPSTREAM"
  elif [ "$cf_bad" = 1 ] || [ "$goog_bad" = 1 ]; then
    verdict="DEST?"
  elif ge "$aR" "$RTT_BAD" || ge "$bR" "$RTT_BAD"; then
    verdict="SLOW"
  else
    verdict="ok"
  fi

  echo "$ts,$rL,$rR,$aL,$aR,$bL,$bR,$verdict" >> "$CSV"

  if [ "$verdict" = "ok" ]; then
    printf '%s  ok    rtr %sms  cf %sms  goog %sms\n' "$ts" "$rR" "$aR" "$bR"
  else
    printf '%s  *** %-12s rtr %s%%/%sms  cf %s%%/%sms  goog %s%%/%sms\n' \
      "$ts" "$verdict" "$rL" "$rR" "$aL" "$aR" "$bL" "$bR"
  fi

  # hop-by-hop detail: on every real outage, plus a periodic baseline
  if [ "$verdict" = "ISP/UPSTREAM" ] || [ "$verdict" = "DEST?" ] || [ "$verdict" = "LOCAL" ]; then
    run_mtr "$verdict"
  elif [ $((i % MTR_EVERY)) -eq 0 ]; then
    run_mtr "periodic"
  fi

  # pacing floor: if probes returned fast (route gone), don't tight-loop
  elapsed=$((SECONDS - start))
  [ "$elapsed" -lt "$WINDOW" ] && sleep $((WINDOW - elapsed))
done
