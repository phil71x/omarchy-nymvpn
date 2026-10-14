#!/usr/bin/env bash

set -euo pipefail

# shellcheck source-path=SCRIPTDIR source=base-test.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

# State classification. Expected classes follow the design table of the widget this
# plugin replaces; "Offline" without auto-connect is down by decision (October 2026):
#   Connected → up · Connecting, Disconnecting → busy · Offline, auto-connect → paused
#   Disconnected, Offline, Error → down · nym-vpnd inactive → down
for case in connected:up connecting:busy disconnecting:busy offline-auto:paused \
            offline:down disconnected:down error:down; do
  use_log "${case%%:*}"
  check "status ${case%%:*}" "${case##*:}" "$(status | jq -r .status)"
done

use_log connected
out=$(status)
check "route fields from the Connected and gateway lines" "wg 192.0.2.10 198.51.100.20 BE 97% CH 99%" \
  "$(jq -r '[.mode, .entryIp, .exitIp, .entryCc, .entryPerf, .exitCc, .exitPerf] | join(" ")' <<<"$out")"
check "since epoch from the UTC log timestamp" "$(date -d 2026-10-13T19:25:32Z +%s)" "$(jq -r .sinceEpoch <<<"$out")"
check "tooltip route without gateway ids" "192.0.2.10:51822 → 198.51.100.20:51822" "$(jq -r '.tooltip | split("\n")[1]' <<<"$out")"

use_log disconnected
check "no route when down" "" "$(status | jq -r '.mode + .entryIp + .entryCc')"

use_log no-state connected
check "falls back to the rotated log" up "$(status | jq -r .status)"

rm -f "$TMP/logs/"*
check "no log at all is down" down "$(status | jq -r .status)"

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
