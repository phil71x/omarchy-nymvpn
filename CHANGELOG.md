# Changelog

*Created: October 16, 2026 -- Updated: October 17, 2026*

All notable changes to the NymVPN Omarchy plugin. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-10-17

### Fixed

- No more false "NymVPN disconnected" alert when the `nym-vpnd` log is missing, unreadable or reworded by a NymVPN update. The widget now shows "Unknown", never "Protected", explains why in the card, keeps the last known gateways, and sends one normal "NymVPN status unknown" toast.
- Tunnel changes show up within a second: the widget reads the status as soon as the `nym-vpnd` log changes, instead of up to 5 s later.
- Mode and gateway choices show at once and roll back with an error when NymVPN refuses them; the gateway menus no longer keep a choice that is not active, or offer the previous mode's countries.
- A NymVPN daemon that stops answering no longer locks the card: every control action and config read stops after 60 s with an error, and leaves no `nym-vpnc` process behind.
- The power switch is hidden until the tunnel state is known, and stays usable to disconnect while the state is unknown.

### Changed

- The `refreshIntervalSec` setting, shown as "Fallback check", now only catches what the log does not show, such as a stopped or crashed daemon (default still 5 s).

## [1.0.0] - 2026-10-16

### Added

- Bar widget: Nym smiley (eyes and smile traced from the Nym docs) colored by the NymVPN tunnel state, read from the `nym-vpnd` log without calling `nym-vpnc`; tooltip with state and route; right click opens the NymVPN app.
- Status card: state, since, duration, protection, dVPN or Mixnet mode, entry and exit gateways (country, IP, load, uptime, IPv6 and node name on hover).
- Toasts on connect and on a real disconnect; the disconnect toast is critical, shows through Do Not Disturb, and appears once across monitors.
- Opt-in controls: connect and disconnect, mode, entry and exit gateway (Auto, Random, country), enabled and disabled from the card through a visible terminal, a group and a scoped polkit rule.
- Settings `connectedColor`, `notifications`, `refreshIntervalSec`.

[1.0.1]: https://github.com/phil71x/omarchy-nymvpn/releases/tag/v1.0.1
[1.0.0]: https://github.com/phil71x/omarchy-nymvpn/releases/tag/v1.0.0
