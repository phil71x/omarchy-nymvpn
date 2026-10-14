#!/usr/bin/env bash

set -euo pipefail

# shellcheck source-path=SCRIPTDIR source=base-test.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

if ! command -v node >/dev/null; then
  skip "Model.js tests need node"
  exit 0
fi

# model <expression>: evaluate a JavaScript expression against Model.js and print the result.
model() {
  node -e 'const M = require(process.argv[1]); console.log(eval(process.argv[2]))' "$ROOT/Model.js" "$1"
}

# 2026-10-13 10:00:00 UTC is 1791885600 (date -u -d '2026-10-13 10:00' +%s).
check "duration under an hour" "12 min" "$(model 'M.duration("1791885600", (1791885600 + 12 * 60 + 59) * 1000)')"
check "duration over an hour" "2 h 5 min" "$(model 'M.duration("1791885600", (1791885600 + 125 * 60) * 1000)')"
check "duration exactly one hour" "1 h 0 min" "$(model 'M.duration("1791885600", (1791885600 + 3600) * 1000)')"
check "duration unknown start" "—" "$(model 'M.duration("", Date.now())')"
check "duration in the future" "—" "$(model 'M.duration("1791885600", (1791885600 - 120) * 1000)')"

check "gateway with performance" "CH · 99%" "$(model 'M.gateway("CH", "99%")')"
check "gateway without performance" "CH" "$(model 'M.gateway("CH", "")')"
check "gateway unknown" "—" "$(model 'M.gateway("", "99%")')"

check "status labels" "Connected|Connecting…|Offline · will reconnect|Disconnected|" \
  "$(model '["up", "busy", "paused", "down", "other"].map(M.statusLabel).join("|")')"
check "mode labels" "WireGuard|Mixnet|" "$(model '["wg", "mixnet", ""].map(M.modeLabel).join("|")')"
check "traffic labels" "Not protected|No network||" "$(model '["down", "paused", "busy", "up"].map(M.trafficLabel).join("|")')"

check "parse valid status" "down" "$(model 'M.parseStatus(JSON.stringify({status: "down"})).status')"
check "parse garbage" "|NymVPN: unreadable status" "$(model '(s => s.status + "|" + s.tooltip)(M.parseStatus("not json"))')"
check "parse JSON without status" "" "$(model 'M.parseStatus("{}").status')"
