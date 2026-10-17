pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// NymVPN status card, opened from BarWidget.qml: state, gateways and route, read from
// the widget (hostWidget), which polls scripts/nym-status. When polkit already allows
// nym-vpnc, the card also connects, disconnects and picks mode and gateways through
// scripts/nym-ctl; otherwise it stays read-only and offers "Enable controls".
Panel {
  id: root
  moduleName: "io.github.phil71x.nymvpn"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property var info: hostWidget ? hostWidget.info : ({})
  readonly property string status: Model.shownStatus(info)
  readonly property bool connected: status === "up"
  // Last known state up: the gateways stay listed, as the last known route, and the switch
  // stays on, so it disconnects, while the state is unknown.
  readonly property bool lastUp: info.status === "up"
  readonly property bool knownState: !!info.status && info.status !== "unknown"
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  // Theme text color, as the built-in panels use. Not barForeground: on a transparent bar it
  // follows the wallpaper and turns unreadable on a dark popup.
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  property real now: Date.now()   // ticks every second while the card shows a duration

  // "unknown" until checked on open, then Model.controlsState(): authorized,
  // not-authorized or unavailable.
  property string controls: "unknown"
  property var config: null      // `nym-ctl config`: mode, entry, exit, countries
  property var previousConfig: null   // restored if an action fails
  property bool reloadPending: false  // an action started during a config read: read again
  property bool acting: false
  property string actionError: ""
  property string configError: ""   // the last config read failed; cleared by the next good one
  readonly property bool controlsOn: controls === "authorized"
  readonly property string ctl: hostWidget ? hostWidget.scriptDir + "/nym-ctl" : ""

  onOpenedChanged: if (opened) checkControls()

  function checkControls() {
    if (ctl && !authProc.running) authProc.running = true
  }

  // nym-vpnc takes ~6 s per call: config loads in the background, the last one stays shown.
  function loadConfig() {
    if (!configProc.running) configProc.running = true
  }

  // Shows `choice` (a config from Model.withChoice) at once; actionProc rolls it back on failure
  // and never retries, since a failed nym-vpnc call may still have changed the daemon.
  function act(args, choice) {
    if (acting || !ctl) return
    actionError = ""
    acting = true
    previousConfig = config
    if (choice) config = choice
    if (configProc.running) reloadPending = true
    actionProc.command = ["bash", ctl].concat(args)
    actionProc.running = true
  }

  function setGateway(side, value) {
    if (value === "server" || !config || value === Model.gatewayValue(config[side])) return
    act([side, value], Model.withChoice(config, side, value))
  }

  // SearchableDropdown assigns its own value on selection, which breaks the binding to config.
  function rebindGateway(dropdown, side) {
    dropdown.value = Qt.binding(function() { return root.config ? Model.gatewayValue(root.config[side]) : "" })
  }

  function runInTerminal(script) {
    root.close()
    root.controls = "unknown"
    if (hostWidget) hostWidget.runInTerminal(script)
  }

  function open() {
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        PanelHero {
          iconComponent: Component {
            Smiley {
              size: 40
              featureColor: root.connected && root.hostWidget ? root.hostWidget.connectedColor : Color.popups.background
              discColor: root.foreground
              rimColor: root.foreground
            }
          }
          title: "NymVPN"
          meta: Model.statusLabel(root.status)
          foreground: root.foreground
          fontFamily: root.fontFamily
          // No switch before any known state: on or off would be a guess.
          trailingControl: root.controlsOn && root.knownState ? powerSwitch : null
        }

        Component {
          id: powerSwitch
          ToggleSwitch {
            checked: root.lastUp
            busy: root.acting || root.status === "busy"
            foreground: root.foreground
            onToggled: root.act([root.lastUp ? "disconnect" : "connect"])
          }
        }

        Item {
          width: parent.width
          implicitHeight: timeColumn.implicitHeight

          Grid {
            id: timeColumn
            columns: 2
            columnSpacing: Style.space(8)
            rowSpacing: Style.spacing.labelGap

            InfoText { text: "Since"; opacity: 0.6 }
            InfoText { text: root.info.since || "—" }
            InfoText { visible: root.connected; text: "Duration"; opacity: 0.6 }
            InfoText {
              visible: root.connected
              text: Model.duration(root.info.sinceEpoch, root.now)
            }
          }

          Column {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            InfoText {
              anchors.right: parent.right
              text: Model.protectionLabel(root.status)
              font.pixelSize: Style.font.heading
              font.bold: true
              color: root.connected && root.hostWidget ? root.hostWidget.connectedColor
                   : root.status === "paused" || root.status === "unknown" ? root.foreground
                   : Color.urgent
            }

            Row {
              anchors.right: parent.right
              visible: root.connected && modeText.text !== ""
              spacing: Style.space(4)

              InfoText {
                anchors.verticalCenter: parent.verticalCenter
                text: Model.modeIcon(root.info.mode)
                font.pixelSize: Style.font.heading
                color: root.hostWidget ? root.hostWidget.connectedColor : root.foreground
              }

              InfoText {
                id: modeText
                anchors.verticalCenter: parent.verticalCenter
                text: Model.modeLabel(root.info.mode)
                font.pixelSize: Style.font.caption
                font.bold: true
                color: root.hostWidget ? root.hostWidget.connectedColor : root.foreground
              }
            }
          }
        }

        InfoText {
          visible: root.status === "unknown"
          width: parent.width
          text: (root.info.reason || "Tunnel state unknown")
            + (root.info.stale ? ". Showing the last known details." : ".")
          wrapMode: Text.Wrap
          opacity: 0.6
        }

        PanelSeparator {
          visible: root.lastUp
          foreground: root.foreground
        }

        Column {
          visible: root.lastUp
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "GATEWAYS"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Column {
            width: parent.width
            spacing: Style.spacing.labelGap
            GatewayRow { header: true; ip: "IP"; load: "Load"; uptime: "Uptime" }
            GatewayRow {
              label: "Entry"; cc: root.info.entryCc || "—"; ip: root.info.entryIp || "—"; ipv6: root.info.entryIpv6 || ""
              node: root.info.entryName || ""
              load: root.info.entryLoad || "—"; uptime: root.info.entryUptime || "—"
            }
            GatewayRow {
              label: "Exit"; cc: root.info.exitCc || "—"; ip: root.info.exitIp || "—"; ipv6: root.info.exitIpv6 || ""
              node: root.info.exitName || ""
              load: root.info.exitLoad || "—"; uptime: root.info.exitUptime || "—"
            }
          }
        }

        PanelSeparator {
          visible: root.controlsOn
          foreground: root.foreground
        }

        Column {
          visible: root.controlsOn
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "TUNNEL"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          InfoText {
            visible: (!root.config || !root.config.countries) && !root.configError
            text: "Loading the gateway lists…"
            opacity: 0.6
          }

          Item {
            visible: !!root.config
            width: parent.width
            implicitHeight: modeGroup.implicitHeight

            InfoText {
              anchors.verticalCenter: parent.verticalCenter
              text: "Mode"
              opacity: 0.6
            }

            ButtonGroup {
              id: modeGroup
              anchors.right: parent.right
              options: [
                { value: "dvpn", label: "dVPN", icon: Model.modeIcon("dvpn") },
                { value: "mixnet", label: "Mixnet", icon: Model.modeIcon("mixnet") }
              ]
              value: root.config ? root.config.mode : ""
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              onChanged: function(value) {
                if (root.config && value !== root.config.mode)
                  root.act(["mode", value], Model.withChoice(root.config, "mode", value))
              }
            }
          }

          SearchableDropdown {
            id: entryDropdown
            visible: !!root.config && !!root.config.countries
            width: parent.width
            label: "Entry"
            placeholderText: "Search countries…"
            value: root.config ? Model.gatewayValue(root.config.entry) : ""
            options: root.config && root.config.countries ? Model.gatewayOptions(root.config.countries.entry, root.config.entry) : []
            fontFamily: root.fontFamily
            onChanged: function(value) {
              root.setGateway("entry", value)
              root.rebindGateway(entryDropdown, "entry")
            }
          }

          SearchableDropdown {
            id: exitDropdown
            visible: !!root.config && !!root.config.countries
            width: parent.width
            label: "Exit"
            placeholderText: "Search countries…"
            value: root.config ? Model.gatewayValue(root.config.exit) : ""
            options: root.config && root.config.countries ? Model.gatewayOptions(root.config.countries.exit, root.config.exit) : []
            fontFamily: root.fontFamily
            onChanged: function(value) {
              root.setGateway("exit", value)
              root.rebindGateway(exitDropdown, "exit")
            }
          }

          InfoText {
            visible: text !== ""
            width: parent.width
            text: root.actionError || root.configError
            color: Color.urgent
            wrapMode: Text.Wrap
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(8)

          Button {
            width: secondButton.visible ? (parent.width - parent.spacing) / 2 : parent.width
            text: "Open App"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            onClicked: {
              root.close()
              if (root.hostWidget) root.hostWidget.openApp()
            }
          }

          Button {
            id: secondButton
            visible: root.controls === "authorized" || root.controls === "not-authorized"
            width: (parent.width - parent.spacing) / 2
            text: root.controlsOn ? "Disable controls" : "Enable controls"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            onClicked: root.runInTerminal(root.controlsOn ? "disable-controls" : "enable-controls")
          }
        }
      }
    }
  }

  Timer {
    interval: 1000
    running: root.opened && root.connected
    repeat: true
    triggeredOnStart: true
    onTriggered: root.now = Date.now()
  }

  Process {
    id: authProc
    command: ["bash", root.ctl, "authorized"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.controls = Model.controlsState(text)
        if (root.controlsOn) root.loadConfig()
      }
    }
  }

  Process {
    id: configProc
    command: ["bash", root.ctl, "config"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        // A read that started before or during an action may predate it: wait for the next one.
        if (root.acting || root.reloadPending) return
        try {
          var config = JSON.parse(text)
          if (config.mode) {
            root.config = config
            root.configError = ""
          }
          else if (config.error === "not-authorized") root.controls = "not-authorized"
        } catch (e) {}
      }
    }
    stderr: StdioCollector { id: configErr; waitForEnd: true }
    onExited: function(exitCode) {
      // A failed read whose result would have been discarded says nothing about the current config.
      if (exitCode !== 0 && !root.acting && !root.reloadPending && configErr.text.trim() !== "")
        root.configError = configErr.text.trim().split("\n")[0]
      if (!root.reloadPending) return
      root.reloadPending = false
      root.loadConfig()
    }
  }

  // Gateway lists differ between dVPN and Mixnet, so any change reloads the config.
  Process {
    id: actionProc
    stderr: StdioCollector { id: actionErr; waitForEnd: true }
    onExited: function(exitCode) {
      root.acting = false
      if (exitCode !== 0) {
        root.config = root.previousConfig
        root.actionError = (actionErr.text.trim().split("\n")[0]) || "nym-vpnc failed"
      }
      root.loadConfig()
    }
  }


  // One "label … value" line of the card.
  component InfoPair: Item {
    id: pair
    property string label: ""
    property string value: ""

    width: parent.width
    implicitHeight: Math.max(labelText.implicitHeight, valueText.implicitHeight)

    InfoText { id: labelText; text: pair.label; opacity: 0.6 }
    InfoText { id: valueText; anchors.right: parent.right; text: pair.value }
  }

  // One line of the gateways table: side, country, IP, server load (low is better), uptime.
  // Hovering the country shows the node name, hovering the IP its IPv6 ("None" if it has none);
  // both come from nym-ctl's gateway cache, so they are unknown without controls.
  component GatewayRow: Row {
    id: gw
    property bool header: false
    property string label: ""
    property string cc: ""
    property string ip: ""
    property string ipv6: ""
    property string node: ""
    property string load: ""
    property string uptime: ""
    readonly property real unit: width / 20

    width: parent.width

    InfoText { width: gw.unit * 3; text: gw.label; opacity: 0.6 }
    InfoText {
      width: gw.unit * 2.75
      text: gw.cc

      MouseArea {
        id: ccMouse
        anchors.fill: parent
        enabled: !gw.header
        hoverEnabled: true
      }

      PanelToolTip {
        visible: ccMouse.containsMouse
        text: gw.node || "Node name unknown"
        fontFamily: root.fontFamily
      }
    }
    InfoText {
      width: gw.unit * 7.25
      text: gw.ip
      opacity: gw.header ? 0.6 : 1

      MouseArea {
        id: ipMouse
        anchors.fill: parent
        enabled: !gw.header
        hoverEnabled: true
      }

      PanelToolTip {
        visible: ipMouse.containsMouse
        text: "IPv6: " + (gw.ipv6 || "unknown")
        fontFamily: root.fontFamily
      }
    }
    InfoText { width: gw.unit * 3; text: gw.load; opacity: gw.header ? 0.6 : 1; horizontalAlignment: Text.AlignRight }
    InfoText { width: gw.unit * 4; text: gw.uptime; opacity: gw.header ? 0.6 : 1; horizontalAlignment: Text.AlignRight }
  }

  component InfoText: Text {
    textFormat: Text.PlainText
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
