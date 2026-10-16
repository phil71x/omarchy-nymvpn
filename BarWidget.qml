import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// NymVPN status in the bar, drawn as Nym's smiley in the tunnel's color. Left click
// opens the status card (Panel.qml); right click opens the NymVPN app. State comes
// from scripts/nym-status, which reads the nym-vpnd log and sends the toasts.
BarWidget {
  id: root
  moduleName: "io.github.phil71x.nymvpn"

  property var info: ({})
  property real now: Date.now()

  readonly property string status: info.status || ""
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property color connectedColor: setting("connectedColor", "#4CBB7F")
  // A disc in the bar's icon color, like the other widgets; eyes and smile in the
  // connected color while the tunnel is up, otherwise cut out in the bar color.
  readonly property color discColor: foreground
  readonly property color rimColor: foreground
  readonly property color faceColor: status === "up" ? connectedColor : Color.bar.background
  readonly property string scriptDir: decodeURIComponent(
    Qt.resolvedUrl("scripts").toString().replace(/^file:\/\//, ""))

  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  function openApp() {
    if (bar) bar.run("uwsm-app -- nym-vpn.desktop")
  }

  // Runs enable-controls or disable-controls where sudo can ask for the password.
  function runInTerminal(script) {
    if (bar) bar.run("omarchy-launch-floating-terminal-with-presentation bash " + scriptDir + "/" + script)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "N"   // hidden; WidgetButton hides itself when text is empty
    labelVisible: false
    fixedWidth: 18 + scaledHorizontalMargin * 2
    tooltipText: root.opened ? "" : (root.info.tooltip || "NymVPN")
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.openApp()
      else root.toggle()
    }

    Smiley {
      anchors.centerIn: parent
      size: 18
      featureColor: root.faceColor
      discColor: root.discColor
      rimColor: root.rimColor
    }
  }

  Process {
    id: proc
    command: ["bash", root.scriptDir + "/nym-status"].concat(root.setting("notifications", true) ? [] : ["--no-notify"])
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.info = Model.mergeStatus(root.info, Model.parseStatus(text))
        root.now = Date.now()
      }
    }
  }

  Timer {
    interval: Math.max(2, Number(root.setting("refreshIntervalSec", 5))) * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!proc.running) proc.running = true
  }
}
