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
check "duration under a minute" "45 s" "$(model 'M.duration("1791885600", (1791885600 + 45) * 1000)')"
check "duration under an hour" "12 min" "$(model 'M.duration("1791885600", (1791885600 + 12 * 60 + 59) * 1000)')"
check "duration over an hour" "2 h 5 min" "$(model 'M.duration("1791885600", (1791885600 + 125 * 60) * 1000)')"
check "duration exactly one hour" "1 h 0 min" "$(model 'M.duration("1791885600", (1791885600 + 3600) * 1000)')"
check "duration unknown start" "—" "$(model 'M.duration("", Date.now())')"
check "duration in the future" "—" "$(model 'M.duration("1791885600", (1791885600 - 120) * 1000)')"


check "status labels" "Connected|Connecting…|Offline · will reconnect|Disconnected|" \
  "$(model '["up", "busy", "paused", "down", "other"].map(M.statusLabel).join("|")')"
check "mode labels" "dVPN mode|Mixnet mode|" "$(model '["wg", "mix", ""].map(M.modeLabel).join("|")')"
check "mode icons (Nerd Font code points)" "f140b|f140b|f0209|f0209|" \
  "$(model '["wg", "dvpn", "mix", "mixnet", ""].map(m => M.modeIcon(m) ? M.modeIcon(m).codePointAt(0).toString(16) : "").join("|")')"
check "protection labels" "Protected|No network|Unprotected|Unprotected|Unprotected" \
  "$(model '["up", "paused", "busy", "down", ""].map(M.protectionLabel).join("|")')"

check "parse valid status" "down" "$(model 'M.parseStatus(JSON.stringify({status: "down"})).status')"
check "parse garbage" "|NymVPN: unreadable status" "$(model '(s => s.status + "|" + s.tooltip)(M.parseStatus("not json"))')"
check "parse JSON without status" "" "$(model 'M.parseStatus("{}").status')"

# Gateway dropdowns (entry and exit) from `nym-ctl config`.
check "gateway value per kind" "CH|server|random|auto|auto" \
  "$(model '[{kind: "country", value: "CH"}, {kind: "server", value: "Gw1"}, {kind: "random"}, {kind: "auto"}, null].map(M.gatewayValue).join("|")')"
check "gateway options for a country choice" "auto:Auto|random:Random|BE:Belgium:1 server|CH:Switzerland:2 servers" \
  "$(model 'M.gatewayOptions([{code: "BE", name: "Belgium", count: 1}, {code: "CH", name: "Switzerland", count: 2}], {kind: "country", value: "CH"}).map(o => o.description && o.value.length == 2 ? o.value + ":" + o.label + ":" + o.description : o.value + ":" + o.label).join("|")')"
check "gateway options list the current server first" "server:Plain Gateway BE|auto|random" \
  "$(model '(o => o[0].value + ":" + o[0].label + "|" + o.slice(1).map(x => x.value).join("|"))(M.gatewayOptions([], {kind: "server", value: "Gw1", name: "Plain Gateway BE"}))')"

check "controls state" "authorized|not-authorized|unavailable|unavailable" \
  "$(model '[JSON.stringify({authorized: true}), JSON.stringify({error: "not-authorized"}), JSON.stringify({error: "nym-vpnc-missing"}), "garbage"].map(M.controlsState).join("|")')"
