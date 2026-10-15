# Changelog

*Created: October 16, 2026*

All notable changes to the NymVPN Omarchy plugin. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-10-16

### Added

- Bar widget: Nym smiley (eyes and smile traced from the Nym docs) colored by the NymVPN tunnel state, read from the `nym-vpnd` log without calling `nym-vpnc`; tooltip with state and route; right click opens the NymVPN app.
- Status card: state, since, duration, protection, dVPN or Mixnet mode, entry and exit gateways (country, IP, load, uptime, IPv6 and node name on hover).
- Toasts on connect and on a real disconnect; the disconnect toast is critical, shows through Do Not Disturb, and appears once across monitors.
- Opt-in controls: connect and disconnect, mode, entry and exit gateway (Auto, Random, country), enabled and disabled from the card through a visible terminal, a group and a scoped polkit rule.
- Settings `connectedColor`, `notifications`, `refreshIntervalSec`.

[1.0.0]: https://github.com/phil71x/omarchy-nymvpn/releases/tag/v1.0.0
