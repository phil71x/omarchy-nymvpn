# Security Policy

*Created: October 16, 2026 -- Updated: October 17, 2026*

## Reporting a vulnerability in the NymVPN plugin

Report vulnerabilities in this plugin privately through GitHub: the repository's **Security** tab, **Report a vulnerability**. Do not open a public issue.

Vulnerabilities in NymVPN itself (the daemon, the app, `nym-vpnc`) belong to Nym: report them through [nymtech/nym-vpn-client](https://github.com/nymtech/nym-vpn-client) or [Nym support](https://support.nym.com).

Only the latest release is supported.

## Privilege boundary of the NymVPN plugin

- **Default** — the plugin runs as your user, reads the world-readable `/var/log/nym-vpnd/nym-vpnd.log`, and never calls `nym-vpnc`.
- **Controls** — every `nym-vpnc` call is preceded by `pkcheck -a com.nymvpn.vpnd.unix-access` without `-u`, so the plugin never triggers a password prompt; when polkit would ask, the call is not made.
- **Enable controls** — the only privileged step. It runs in a visible terminal, explains itself and asks before `sudo`; it adds your user to group `nym-vpn` (unless already a member) and installs [`polkit/50-io.github.phil71x.nymvpn.rules`](polkit/50-io.github.phil71x.nymvpn.rules), which grants `com.nymvpn.vpnd.unix-access` to that group in local, active sessions. Any program running as your user can then control the NymVPN daemon. **Disable controls** removes the rule, and the group membership if **Enable controls** added it.
- **Commands** — the status and control scripts run as argument arrays; the app and terminal launchers receive only fixed text and the plugin's own script path. Text from logs and `nym-vpnc` is rendered as plain text.
