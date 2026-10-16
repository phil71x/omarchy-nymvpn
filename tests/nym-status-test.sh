#!/usr/bin/env bash

set -euo pipefail

# shellcheck source-path=SCRIPTDIR source=base-test.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

# State classification. Expected classes follow the design table of the widget this
# plugin replaces; "Offline" without auto-connect is down by decision (October 2026):
#   Connected → up · Connecting, Disconnecting → busy · Offline, auto-connect → paused
#   Disconnected, Offline, Error → down · nym-vpnd inactive → down
#   no state line or an unlisted state → unknown (v1.0.1: was down, a false critical toast)
for case in connected:up connected-mixnet:up connecting:busy disconnecting:busy offline-auto:paused \
            offline:down disconnected:down error:down; do
  use_log "${case%%:*}"
  check "status ${case%%:*}" "${case##*:}" "$(status | jq -r .status)"
done

use_log connected
out=$(status)
check "route fields from the Connected and gateway lines" "wg 192.0.2.10 198.51.100.20 BE 97% CH 99%" \
  "$(jq -r '[.mode, .entryIp, .exitIp, .entryCc, .entryUptime, .exitCc, .exitUptime] | join(" ")' <<<"$out")"
check "no load or IPv6 without nym-ctl's gateway cache" "||" "$(jq -r '.entryLoad + "|" + .exitLoad + "|" + .entryIpv6' <<<"$out")"

# Loads come from nym-ctl's gateway cache, matched on the gateway ids of the Connected line.
mkdir -p "$CACHE_DIR"
jq -n '{servers: {EntryGwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA: "Entry", ExitGwBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB: "Exit"},
         loads: {EntryGwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA: "Medium", ExitGwBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB: "High"},
         ipv6: {EntryGwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA: "2001:db8::10"}}' > "$CACHE_DIR/wg.json"
out=$(status)
check "loads from the gateway cache" "Medium|High" "$(jq -r '.entryLoad + "|" + .exitLoad' <<<"$out")"
check "IPv6 from the gateway cache, None when the gateway has none" "2001:db8::10|None" "$(jq -r '.entryIpv6 + "|" + .exitIpv6' <<<"$out")"
check "node names from the gateway cache" "Entry|Exit" "$(jq -r '.entryName + "|" + .exitName' <<<"$out")"
touch -d '61 minutes ago' "$CACHE_DIR/wg.json"
check "stale cache: no load, names and IPv6 kept" "||Entry|2001:db8::10" \
  "$(status | jq -r '.entryLoad + "|" + .exitLoad + "|" + .entryName + "|" + .entryIpv6')"
rm -rf "$CACHE_DIR"
check "since epoch from the UTC log timestamp" "$(date -d 2026-10-13T19:25:32Z +%s)" "$(jq -r .sinceEpoch <<<"$out")"
check "tooltip route without gateway ids" "192.0.2.10:51822 → 198.51.100.20:51822" "$(jq -r '.tooltip | split("\n")[1]' <<<"$out")"

use_log connected-mixnet
out=$(status)
check "Mixnet route (mode mix, no ports)" "up mix 192.0.2.30 198.51.100.40 FR 99% BE 77%" \
  "$(jq -r '[.status, .mode, .entryIp, .exitIp, .entryCc, .entryUptime, .exitCc, .exitUptime] | join(" ")' <<<"$out")"
check "Mixnet tooltip route" "192.0.2.30 → 198.51.100.40" "$(jq -r '.tooltip | split("\n")[1]' <<<"$out")"

use_log disconnected
check "no route when down" "" "$(status | jq -r '.mode + .entryIp + .entryCc')"

use_log no-state connected
check "falls back to the rotated log" up "$(status | jq -r .status)"

rm -f "$TMP/logs/"*
check "no log at all is unknown, no made-up since" "unknown|Cannot read the NymVPN log||" \
  "$(status | jq -r '[.status, .reason, .since, .sinceEpoch] | join("|")')"
use_log no-state
check "readable log without a state line is unknown, reason says so" "unknown|No tunnel state in the NymVPN log" \
  "$(status | jq -r '.status + "|" + .reason')"
echo "2026-10-13T19:25:32.000000Z  INFO nym_vpnd::tunnel_state_machine: New tunnel state: Hibernating" > "$TMP/logs/nym-vpnd.log"
check "unlisted state is unknown, reason names it" "unknown|Hibernating|Unknown NymVPN state: Hibernating" \
  "$(status | jq -r '[.status, .state, .reason] | join("|")')"
chmod 000 "$TMP/logs/nym-vpnd.log"
if [[ -r $TMP/logs/nym-vpnd.log ]]; then skip "unreadable log is unknown (running as root)"
else check "unreadable log is unknown, reason says so" "unknown|Cannot read the NymVPN log" "$(status | jq -r '.status + "|" + .reason')"; fi
chmod 644 "$TMP/logs/nym-vpnd.log"

use_log connected
FAKE_DAEMON=inactive
check "daemon stopped is down" "down|nym-vpnd stopped" "$(status | jq -r '.status + "|" + .state')"
FAKE_DAEMON=active

# Toasts: only on a change between stable statuses, never on the first run.
reset_calls
use_log connected; status >/dev/null
check "no toast on first run" "" "$(calls)"
use_log connecting; status >/dev/null
use_log connected; status >/dev/null
check "no toast after a busy blip" "" "$(calls)"
use_log disconnected; status >/dev/null
check "critical toast on disconnect" "notify-send -u critical NymVPN disconnected" "$(cut -d' ' -f1-5 "$CALLS")"
use_log disconnected; status >/dev/null
check "no repeated toast" 1 "$(wc -l < "$CALLS")"
use_log connected; status >/dev/null
check "toast on reconnect" "notify-send NymVPN connected" "$(tail -1 "$CALLS" | cut -d' ' -f1-3)"

# Unknown sends one normal (not critical) toast per spell and keeps the recorded status.
reset_calls
use_log connected; status >/dev/null
rm -f "$TMP/logs/"*; status >/dev/null; status >/dev/null
check "one normal toast when the log disappears" "notify-send NymVPN status unknown Cannot read the NymVPN log." "$(calls | cut -d' ' -f1-9)"
check "unknown toast sent once per spell" 1 "$(wc -l < "$CALLS")"
use_log connected; status >/dev/null
check "no toast when the log comes back unchanged" 1 "$(wc -l < "$CALLS")"
rm -f "$TMP/logs/"*; status >/dev/null
check "a new unknown spell toasts again" 2 "$(wc -l < "$CALLS")"
reset_calls
rm -f "$TMP/logs/"*; status >/dev/null
check "no unknown toast without a known status first" "" "$(calls)"
reset_calls
use_log connected; status >/dev/null
rm -f "$TMP/logs/"*; bash "$ROOT/scripts/nym-status" --no-notify >/dev/null; status >/dev/null
check "no unknown toast with --no-notify, nor stale afterwards" "" "$(calls)"
reset_calls
use_log connected; status >/dev/null
rm -f "$TMP/logs/"*; status >/dev/null
use_log disconnected; status >/dev/null
check "toast on a real change across an unknown spell" "notify-send -u critical NymVPN disconnected" "$(grep critical "$CALLS" | cut -d' ' -f1-5)"

# --no-notify (setting "notifications" off) still records the status.
reset_calls
use_log connected; status >/dev/null
use_log disconnected; bash "$ROOT/scripts/nym-status" --no-notify >/dev/null
check "no toast with --no-notify" "" "$(calls)"
use_log disconnected; status >/dev/null
check "no stale toast after --no-notify" "" "$(calls)"

# Two bar instances (two monitors) polling the same change toast once.
reset_calls
use_log connected; status >/dev/null
use_log disconnected
for _ in 1 2 3 4; do status >/dev/null & done
wait
check "one toast across concurrent instances" 1 "$(grep -c '^notify-send' "$CALLS")"
