# shellcheck shell=bash disable=SC2034  # the variables are used by the scripts that source this file
# Sourced by nym-ctl, enable-controls and disable-controls: the names and paths they share.

ID=io.github.phil71x.nymvpn
RULE_DST="/etc/polkit-1/rules.d/50-$ID.rules"
GROUP=nym-vpn
ACTION=com.nymvpn.vpnd.unix-access
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/$ID"
# Set by enable-controls when it adds the user to GROUP, so disable-controls removes only what it added.
MARKER="$STATE_DIR/added-to-group"

# From the group database, so it is current without a new login; no pipe, so no pipefail race.
in_group() { [[ " $(id -nG "$USER") " == *" $GROUP "* ]]; }
