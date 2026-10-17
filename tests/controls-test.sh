#!/usr/bin/env bash

set -euo pipefail

# shellcheck source-path=SCRIPTDIR source=base-test.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

# enable-controls and disable-controls: group membership. Fake sudo logs and runs nothing,
# fake gum answers from GUM_ANSWERS (one yes/no per prompt), fake id prints FAKE_GROUPS.
export GUM_ANSWERS="$TMP/gum-answers" FAKE_GROUPS USER=alice
MARKER="$XDG_STATE_HOME/io.github.phil71x.nymvpn/added-to-group"

cat > "$TMP/bin/sudo" <<'EOF'
#!/usr/bin/env bash
echo "sudo $*" >> "$CALLS"
EOF
cat > "$TMP/bin/gum" <<'EOF'
#!/usr/bin/env bash
echo "gum $*" >> "$CALLS"
answer=$(head -n1 "$GUM_ANSWERS"); sed -i 1d "$GUM_ANSWERS"
[[ $answer == yes ]]
EOF
cat > "$TMP/bin/id" <<'EOF'
#!/usr/bin/env bash
echo "$FAKE_GROUPS"
EOF
cat > "$TMP/bin/getent" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP/bin/"*

# run <script> <gum answers…>: runs a controls script, prints its sudo and gum calls joined by "|".
run() {
  local script=$1; shift
  rm -f "$CALLS"
  printf '%s\n' "$@" > "$GUM_ANSWERS"
  bash "$ROOT/scripts/$script" >/dev/null 2>&1 || true
  { grep -E '^(sudo|gum) ' "$CALLS" || true; } | sed -E 's/^(gum confirm).*/\1/; s/^sudo (\S+ \S+).*/sudo \1/' | paste -sd'|'
}

FAKE_GROUPS="alice wheel"
check "enable adds you to nym-vpn and records it" "gum confirm|sudo gpasswd -a|sudo install -m|added" \
  "$(run enable-controls yes)|$([[ -e $MARKER ]] && echo added)"
FAKE_GROUPS="alice wheel nym-vpn"
check "enable again keeps the record" "gum confirm|sudo install -m|added" \
  "$(run enable-controls yes)|$([[ -e $MARKER ]] && echo added)"
check "disable removes the membership it added, without asking" "gum confirm|sudo rm -f|sudo gpasswd -d|gone" \
  "$(run disable-controls yes)|$([[ -e $MARKER ]] || echo gone)"

FAKE_GROUPS="alice nym-vpn"
check "enable while already a member: no group change, no record" "gum confirm|sudo install -m|none" \
  "$(run enable-controls yes)|$([[ -e $MARKER ]] || echo none)"
check "disable without a record asks, and keeps the membership by default" "gum confirm|sudo rm -f|gum confirm" \
  "$(run disable-controls yes no)"
check "disable without a record removes the membership if you say so" "gum confirm|sudo rm -f|gum confirm|sudo gpasswd -d" \
  "$(run disable-controls yes yes)"

check "nothing changes when you decline" "gum confirm" "$(run disable-controls no)"
