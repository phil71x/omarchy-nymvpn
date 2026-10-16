#!/usr/bin/env bash

set -euo pipefail

# shellcheck source-path=SCRIPTDIR source=base-test.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

# Polkit guard: nym-vpnc only runs when pkcheck (without -u, so never prompting) allows it.
reset_calls
FAKE_PKCHECK=2
code=0; out=$(ctl config) || code=$?
check "not authorized: error" not-authorized "$(jq -r .error <<<"$out")"
check "not authorized: exit code" 3 "$code"
check "not authorized: nym-vpnc never called" "" "$(vpnc_calls)"
check "pkcheck runs without -u" "pkcheck -a com.nymvpn.vpnd.unix-access -p" "$(cut -d' ' -f1-4 "$CALLS")"
FAKE_PKCHECK=0

# nym-vpnc missing: a PATH holding only jq, timeout and the fake pkcheck.
reset_calls
mkdir -p "$TMP/minbin"
ln -s "$(command -v jq)" "$TMP/minbin/jq"
ln -s "$TMP/bin/pkcheck" "$TMP/minbin/pkcheck"
ln -s "$(command -v timeout)" "$TMP/minbin/timeout"
code=0; out=$(PATH="$TMP/minbin" "$BASH" "$ROOT/scripts/nym-ctl" config) || code=$?
check "nym-vpnc missing: error" nym-vpnc-missing "$(jq -r .error <<<"$out")"
check "nym-vpnc missing: exit code" 3 "$code"
check "nym-vpnc missing: pkcheck not called" "" "$(calls)"

# authorized: the polkit guard alone, so the card can choose read-only or controls instantly.
reset_calls
check "authorized" '{"authorized":true}' "$(ctl authorized)"
check "authorized: nym-vpnc never called" "" "$(vpnc_calls)"
FAKE_PKCHECK=2
code=0; out=$(ctl authorized) || code=$?
check "authorized when polkit refuses" "not-authorized 3" "$(jq -r .error <<<"$out") $code"
FAKE_PKCHECK=0

reset_calls
code=0; ctl bogus 2>/dev/null || code=$?
check "unknown command: usage exit code" 2 "$code"
check "unknown command: nothing called" "" "$(calls)"
check "usage lists the whole header" "{\"error\": \"not-authorized\" | \"nym-vpnc-missing\", \"message\": …} and exits 3." "$(ctl bogus 2>&1 | tail -1)"

# Gateway list parsing. Server names may contain "|"; country names come from ISO 3166.
out=$(ctl countries)
check "dVPN entry countries" "BE:Belgium:1 XK:Kosovo:1 CH:Switzerland:2" \
  "$(jq -r '[.entry[] | "\(.code):\(.name):\(.count)"] | join(" ")' <<<"$out")"
check "server names containing |" "t-lab | CH|💥Petroff Staking |CH#8💥|Pierrot Gateway | Kosovo" \
  "$(jq -r '[.servers[]] | .[1:] | join("|")' "$CACHE_DIR/wg.json")"
check "server loads from the performance column" "Low Low High Medium" \
  "$(jq -r '[.loads[]] | join(" ")' "$CACHE_DIR/wg.json")"
check "exit IPv6 only for gateways that have one" "2001:db8::10 2001:db8::20 2001:db8::21" \
  "$(jq -r '[.ipv6[]] | join(" ")' "$CACHE_DIR/wg.json")"

reset_calls
out=$(ctl config)
check "config" '{"mode":"dvpn","entry":{"kind":"server","value":"EntryGwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","name":"Plain Gateway BE"},"exit":{"kind":"country","value":"CH","name":""}}' \
  "$(jq -c 'del(.countries)' <<<"$out")"
check "config includes the countries of each side" "BE XK CH|BE XK CH" \
  "$(jq -r '[.countries.entry, .countries.exit] | map([.[].code] | join(" ")) | join("|")' <<<"$out")"
check "config reads the fresh cache" "" "$(grep 'gateway list' "$CALLS" || true)"

# Cache lifetime: 1 h, since server load changes.
reset_calls
touch -d '61 minutes ago' "$CACHE_DIR/wg.json"
ctl countries >/dev/null
check "stale cache is refetched" 1 "$(grep -c 'gateway list wg' "$CALLS")"
touch -d '59 minutes ago' "$CACHE_DIR/wg.json"
ctl countries >/dev/null
check "cache younger than 1 h is reused" 1 "$(grep -c 'gateway list wg' "$CALLS")"

# Failed fetch: no partial or empty cache; a stale cache is still served.
FAKE_LIST_FAIL=1
cp "$CACHE_DIR/wg.json" "$TMP/wg.json.before"
touch -d '61 minutes ago' "$CACHE_DIR/wg.json"
code=0; out=$(ctl countries) || code=$?
check "failed fetch serves the stale cache" "0 BE XK CH" "$code $(jq -r '[.entry[].code] | join(" ")' <<<"$out")"
check "failed fetch keeps the stale cache intact" same "$(cmp -s "$TMP/wg.json.before" "$CACHE_DIR/wg.json" && echo same)"
rm -rf "$CACHE_DIR"
code=0; ctl countries >/dev/null 2>&1 || code=$?
check "failed fetch without cache fails" 1 "$code"
check "failed fetch leaves no file behind" "" "$(ls -A "$CACHE_DIR")"
FAKE_LIST_FAIL=0

# Mixnet mode lists entry and exit gateways separately.
reset_calls
FAKE_MODE=mixnet
out=$(ctl countries)
check "mixnet entry and exit countries" "BE XK|CH" "$(jq -r '[.entry[].code] | join(" ")' <<<"$out")|$(jq -r '[.exit[].code] | join(" ")' <<<"$out")"
check "mixnet lists fetched" "mixnet-entry mixnet-exit" "$(grep -o 'gateway list .*' "$CALLS" | cut -d' ' -f3 | paste -sd' ')"
check "mixnet config mode" mixnet "$(ctl config | jq -r .mode)"
FAKE_MODE=dvpn

# Actions, with nym-vpnc arguments as documented by `nym-vpnc gateway set --help`.
B="nym-vpnc --table-style blank"
reset_calls
use_log connected
ctl exit CH >/dev/null
check "exit country reconnects when connected" "$B gateway set --exit-country CH|$B reconnect" "$(vpnc_calls)"

reset_calls
use_log disconnected
ctl mode mixnet >/dev/null
check "mode change without reconnect when down" "$B tunnel set --two-hop off" "$(vpnc_calls)"

reset_calls
ctl entry auto >/dev/null
check "entry auto" "$B gateway set --entry-auto-exclude-jurisdiction off" "$(vpnc_calls)"

reset_calls
ctl entry random >/dev/null
check "entry random" "$B gateway set --entry-random" "$(vpnc_calls)"

reset_calls
code=0; ctl entry XYZ 2>/dev/null || code=$?
check "invalid entry: usage exit code" 2 "$code"
check "invalid entry: nym-vpnc not called" "" "$(vpnc_calls)"

# A run still going after NYMVPN_TIMEOUT seconds is stopped, nym-vpnc and its children included,
# so the card's controls come back.
reset_calls
FAKE_HANG=connect
start=$SECONDS
code=0; err=$(NYMVPN_TIMEOUT=1 ctl connect 2>&1 >/dev/null) || code=$?
check "hung nym-vpnc: exit code" 124 "$code"
check "hung nym-vpnc: message" "NymVPN did not answer within 1 s" "$err"
check "hung nym-vpnc: stopped before it ends" yes "$( (( SECONDS - start < 5 )) && echo yes)"
check "hung nym-vpnc: no process left" "" "$(pgrep -fx 'sleep 9.5' || true)"

# One that ignores SIGTERM is killed as soon as the run is stopped.
FAKE_HANG_TERM=ignore
start=$SECONDS
code=0; err=$(NYMVPN_TIMEOUT=1 ctl connect 2>&1 >/dev/null) || code=$?
check "nym-vpnc ignoring SIGTERM: run stopped" "124|NymVPN did not answer within 1 s" "$code|$err"
check "nym-vpnc ignoring SIGTERM: stopped before it ends" yes "$( (( SECONDS - start < 5 )) && echo yes)"
check "nym-vpnc ignoring SIGTERM: no process left" "" "$(pgrep -fx 'sleep 9.5' || true)"
FAKE_HANG_TERM=

# nym-vpnc killed by something else (out of memory) is not reported as a timeout.
FAKE_KILLED=1
code=0; err=$(NYMVPN_TIMEOUT=30 ctl connect 2>&1 >/dev/null) || code=$?
check "nym-vpnc killed before the deadline: no timeout message" "137|" "$code|$(grep -o 'did not answer' <<<"$err" || true)"
FAKE_KILLED=0

# A gateway list stopped mid-fetch leaves no temporary cache file.
rm -rf "$CACHE_DIR"
FAKE_HANG="gateway list"
NYMVPN_TIMEOUT=1 ctl countries >/dev/null 2>&1 || true
check "stopped fetch: no temporary cache file" "" "$(ls -A "$CACHE_DIR" 2>/dev/null)"
FAKE_HANG=
