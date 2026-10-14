// Pure display logic for the NymVPN widget and card, testable with Node (tests/model-test.sh).
// Input is the JSON line printed by scripts/nym-status.

function parseStatus(text) {
  try {
    var info = JSON.parse(text)
    if (info && typeof info.status === "string") return info
  } catch (e) {}
  return { status: "", tooltip: "NymVPN: unreadable status" }
}

function statusLabel(status) {
  return ({
    up: "Connected",
    busy: "Connecting…",
    paused: "Offline · will reconnect",
    down: "Disconnected"
  })[status] || ""
}

function modeLabel(mode) {
  return ({ wg: "WireGuard", mixnet: "Mixnet" })[mode] || ""
}

// Traffic line for states other than connected; empty while the tunnel is being set up.
function trafficLabel(status) {
  return ({ down: "Not protected", paused: "No network" })[status] || ""
}

// "12 min", "2 h 5 min", or "—" when the start is unknown or in the future.
function duration(sinceEpoch, nowMs) {
  var since = Number(sinceEpoch)
  if (!sinceEpoch || isNaN(since)) return "—"
  var minutes = Math.floor((nowMs / 1000 - since) / 60)
  if (minutes < 0) return "—"
  if (minutes < 60) return minutes + " min"
  return Math.floor(minutes / 60) + " h " + (minutes % 60) + " min"
}

// "CH · 99%", "CH", or "—".
function gateway(cc, perf) {
  if (!cc) return "—"
  return perf ? cc + " · " + perf : cc
}

if (typeof module !== "undefined") {
  module.exports = { parseStatus, statusLabel, modeLabel, trafficLabel, duration, gateway }
}
