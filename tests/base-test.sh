#!/usr/bin/env bash
# Shared setup for the plugin's tests, modeled on Omarchy's test/shell.d/base-test.sh:
# TAP-style pass/skip/fail (the first failure ends the file), fixtures, and fake
# systemctl, notify-send, pkcheck and nym-vpnc on PATH, so tests never touch the real daemon.

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  echo "source tests/base-test.sh from a test file; do not run it directly" >&2
  exit 1
fi

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
FIX="$ROOT/tests/fixtures"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

pass() {
  printf 'ok - %s\n' "$1"
}

skip() {
  printf 'ok - %s # SKIP\n' "$1"
}

fail() {
  [[ -n ${2:-} ]] && printf '%s\n' "$2" >&2
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

# check <description> <expected> <actual>
check() {
  if [[ $2 == "$3" ]]; then pass "$1"; else fail "$1" "expected [$2], got [$3]"; fi
}

mkdir -p "$TMP/bin" "$TMP/logs"
export PATH="$TMP/bin:$PATH" XDG_RUNTIME_DIR="$TMP/run" XDG_CACHE_HOME="$TMP/cache" XDG_STATE_HOME="$TMP/state"
export NYMVPN_LOG_DIR="$TMP/logs" CALLS="$TMP/calls" FIX
export FAKE_DAEMON=active FAKE_PKCHECK=0 FAKE_MODE=dvpn FAKE_LIST_FAIL=0 FAKE_LIST_EMPTY=0 FAKE_HANG='' FAKE_HANG_TERM='' FAKE_KILLED=0 FAKE_STOPPED_AT='' FAKE_GATEWAY=''
export CACHE_DIR="$XDG_CACHE_HOME/io.github.phil71x.nymvpn"

cat > "$TMP/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
# show: the stop time as "@<epoch>" (FAKE_STOPPED_AT); is-active: FAKE_DAEMON.
[[ "$*" == "show -P InactiveEnterTimestamp --timestamp=unix nym-vpnd" ]] && { echo "$FAKE_STOPPED_AT"; exit 0; }
[[ $FAKE_DAEMON == active ]]
EOF
cat > "$TMP/bin/notify-send" <<'EOF'
#!/usr/bin/env bash
echo "notify-send $*" >> "$CALLS"
EOF
cat > "$TMP/bin/pkcheck" <<'EOF'
#!/usr/bin/env bash
echo "pkcheck $*" >> "$CALLS"
exit "$FAKE_PKCHECK"
EOF
cat > "$TMP/bin/nym-vpnc" <<'EOF'
#!/usr/bin/env bash
echo "nym-vpnc $*" >> "$CALLS"
# FAKE_HANG: hang on calls whose arguments contain it; FAKE_HANG_TERM=ignore also ignores SIGTERM.
# FAKE_KILLED=1: die from SIGKILL at once, as an out-of-memory kill would.
(( FAKE_KILLED )) && kill -KILL $$
if [[ -n $FAKE_HANG && "$*" == *"$FAKE_HANG"* ]]; then
  [[ $FAKE_HANG_TERM == ignore ]] && trap '' TERM
  sleep 9.5
fi
case "$*" in
  *"tunnel get")     cat "$FIX/nym-vpnc/tunnel-get-$FAKE_MODE.txt" ;;
  # FAKE_GATEWAY=auto|auto-bare|auto-entry-point|empty|unknown: gateway-get-<name>.txt instead of gateway-get.txt.
  *"gateway get")    cat "$FIX/nym-vpnc/gateway-get${FAKE_GATEWAY:+-$FAKE_GATEWAY}.txt" ;;
  # FAKE_LIST_EMPTY=1: the table header alone, as an empty list or a changed format would give.
  *"gateway list "*) (( FAKE_LIST_FAIL )) && exit 1
                     if (( FAKE_LIST_EMPTY )); then head -n2 "$FIX/nym-vpnc/gateway-list-${!#}.md"
                     else cat "$FIX/nym-vpnc/gateway-list-${!#}.md"; fi ;;
esac
EOF
chmod +x "$TMP/bin/"*

# use_log <fixture> [rotated-fixture]: install fixtures as the current (and rotated) nym-vpnd log.
use_log() {
  rm -f "$TMP/logs/"*
  cp "$FIX/logs/$1.log" "$TMP/logs/nym-vpnd.log"
  if [[ -n ${2:-} ]]; then cp "$FIX/logs/$2.log" "$TMP/logs/nym-vpnd.old.log"; fi
}

status() { bash "$ROOT/scripts/nym-status"; }
ctl() { bash "$ROOT/scripts/nym-ctl" "$@"; }

reset_calls() { rm -f "$CALLS" "$XDG_RUNTIME_DIR/io.github.phil71x.nymvpn/"{last-status,unknown-notified}; }
calls() { cat "$CALLS" 2>/dev/null || true; }
# nym-vpnc calls so far, joined with "|"
vpnc_calls() { { grep '^nym-vpnc' "$CALLS" 2>/dev/null || true; } | paste -sd'|'; }
