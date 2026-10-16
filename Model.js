// Pure display logic for the NymVPN widget and card, testable with Node (tests/model-test.sh).
// Input is the JSON line printed by scripts/nym-status.

function parseStatus(text) {
  try {
    var info = JSON.parse(text)
    if (info && typeof info.status === "string") return info
  } catch (e) {}
  return { status: "unknown", tooltip: "NymVPN: unreadable status" }
}

// Status to show after a new reading: an unknown reading keeps the last good one, marked
// stale with the new tooltip, so a log hiccup neither alarms nor blanks the card.
function mergeStatus(prev, next) {
  if (next.status !== "unknown" || !prev || !prev.status || prev.status === "unknown") return next
  return Object.assign({}, prev, { stale: true, tooltip: next.tooltip })
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
  if (point.kind === "server" || point.kind === "random") return point.kind
  return "auto"
}

// Dropdown options: Auto, Random, then one entry per country with its server count.
// A specific server (only selectable in the NymVPN app) is listed first when it is the current choice.
function gatewayOptions(countries, point) {
  var options = [
    { value: "auto", label: "Auto", description: "Fastest gateway" },
    { value: "random", label: "Random", description: "Any gateway" }
  ]
  if (point && point.kind === "server") {
    options.unshift({ value: "server", label: point.name || "Specific server", description: "Set in the NymVPN app" })
  }
  for (var i = 0; i < (countries || []).length; i++) {
    var c = countries[i]
    options.push({ value: c.code, label: c.name, description: c.count + (c.count === 1 ? " server" : " servers") })
  }
  return options
}

// Config showing a choice before nym-vpnc confirms it: "mode" (dvpn | mixnet), or "entry" /
// "exit" (auto | random | CC). The card rolls back to the previous config if the action fails.
function withChoice(config, kind, value) {
  var next = Object.assign({}, config)
  if (kind === "mode") next.mode = value
  else if (value === "auto" || value === "random") next[kind] = { kind: value, value: "", name: "" }
  else next[kind] = { kind: "country", value: value, name: "" }
  return next
}

if (typeof module !== "undefined") {
  module.exports = { controlsState, parseStatus, mergeStatus, withChoice, statusLabel, modeLabel, modeIcon, protectionLabel, duration, gatewayValue, gatewayOptions }
}
