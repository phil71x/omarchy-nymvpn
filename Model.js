// Pure display logic for the NymVPN widget and card, testable with Node (tests/model-test.sh).
// Input is the JSON line printed by scripts/nym-status.

function parseStatus(text) {
  try {
    var info = JSON.parse(text)
    if (info && typeof info.status === "string") return info
  } catch (e) {}
  return { status: "unknown", tooltip: "NymVPN: unreadable status" }
}

// Status after a new reading: an unknown reading keeps the last known details (gateways, since),
// marked stale with the new reason and tooltip, so a log hiccup does not blank the card.
function mergeStatus(prev, next) {
  if (next.status !== "unknown" || !prev || !prev.status || prev.status === "unknown") return next
  return Object.assign({}, prev, { stale: true, reason: next.reason, tooltip: next.tooltip })
}

// Status the smiley and labels show: never the stale one, so the widget never claims a
// protection it cannot see.
function shownStatus(info) {
  return info.stale ? "unknown" : (info.status || "")
}

function statusLabel(status) {
  return ({
    up: "Connected",
    busy: "Connecting…",
    paused: "Offline · will reconnect",
    down: "Disconnected",
    unknown: "Status unknown"
  })[status] || ""
}

function modeLabel(mode) {
  return ({ wg: "dVPN mode", mix: "Mixnet mode" })[mode] || ""
}

// Nerd Font glyphs matching the NymVPN app: a lightning bolt for dVPN, a crossed-out eye for Mixnet.
function modeIcon(mode) {
  if (mode === "wg" || mode === "dvpn") return String.fromCodePoint(0xF140B)   // nf-md-lightning_bolt
  if (mode === "mix" || mode === "mixnet") return String.fromCodePoint(0xF0209)                   // nf-md-eye_off
  return ""
}

// Whether traffic goes through the tunnel; offline means there is no traffic to protect.
function protectionLabel(status) {
  if (status === "up") return "Protected"
  if (status === "paused") return "No network"
  if (status === "unknown") return "Unknown"
  return "Unprotected"
}

// "45 s", "12 min", "2 h 5 min", or "—" when the start is unknown or in the future.
function duration(sinceEpoch, nowMs) {
  var since = Number(sinceEpoch)
  if (!sinceEpoch || isNaN(since)) return "—"
  var seconds = Math.floor(nowMs / 1000 - since)
  if (seconds < 0) return "—"
  if (seconds < 60) return seconds + " s"
  var minutes = Math.floor(seconds / 60)
  if (minutes < 60) return minutes + " min"
  return Math.floor(minutes / 60) + " h " + (minutes % 60) + " min"
}

// Power switch, from the last known status: on while the daemon holds or seeks the tunnel
// (nym-status's holding: up, paused, connecting, or disconnecting to reconnect), so a click
// disconnects and stops it. It waits only while the tunnel really goes down, and never on a
// stale reading, which may never be followed by the end of that disconnect.
function switchOn(info) {
  return info.holding === true
}

function switchSettling(info) {
  return info.status === "busy" && !info.stale && !switchOn(info)
}

// Card controls from `nym-ctl authorized`: "authorized", "not-authorized" (polkit would ask
// for a password: offer "Enable controls"), or "unavailable" (nym-vpnc missing, bad output).
function controlsState(text) {
  try {
    var r = JSON.parse(text)
    if (r && r.authorized === true) return "authorized"
    if (r && r.error === "not-authorized") return "not-authorized"
  } catch (e) {}
  return "unavailable"
}

// Dropdown value for a gateway constraint from `nym-ctl config` ({kind, value, name}).
function gatewayValue(point) {
  if (!point) return "auto"
  if (point.kind === "country") return point.value
  if (point.kind === "server" || point.kind === "random" || point.kind === "other") return point.kind
  return "auto"
}

// Dropdown options: Auto, Random, then one entry per country with its server count.
// A specific server, or a constraint the card does not know (a region, say), is set in the NymVPN
// app and listed first when it is the current choice.
function gatewayOptions(countries, point) {
  var options = [
    { value: "auto", label: "Auto", description: "Fastest gateway" },
    { value: "random", label: "Random", description: "Any gateway" }
  ]
  if (point && point.kind === "server") {
    options.unshift({ value: "server", label: point.name || "Specific server", description: "Set in the NymVPN app" })
  }
  if (point && point.kind === "other") {
    options.unshift({ value: "other", label: point.name || "Other", description: "Set in the NymVPN app" })
  }
  for (var i = 0; i < (countries || []).length; i++) {
    var c = countries[i]
    options.push({ value: c.code, label: c.name, description: c.count + (c.count === 1 ? " server" : " servers") })
  }
  return options
}

// Config showing a choice before nym-vpnc confirms it: "mode" (dvpn | mixnet), or "entry" /
// "exit" (auto | random | CC). The card rolls back to the previous config if the action fails.
// A mode change drops the country lists, which belong to the old mode, until config reloads.
function withChoice(config, kind, value) {
  var next = Object.assign({}, config)
  if (kind === "mode") {
    next.mode = value
    next.countries = null
  }
  else if (value === "auto" || value === "random") next[kind] = { kind: value, value: "", name: "" }
  else next[kind] = { kind: "country", value: value, name: "" }
  return next
}

if (typeof module !== "undefined") {
  module.exports = { controlsState, parseStatus, mergeStatus, shownStatus, withChoice, statusLabel, modeLabel, modeIcon, protectionLabel, duration, gatewayValue, gatewayOptions, switchOn, switchSettling }
}
