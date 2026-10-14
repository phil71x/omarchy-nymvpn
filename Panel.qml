pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// NymVPN status card, opened from BarWidget.qml: state, gateways and route.
// Reads everything from the widget (hostWidget), which polls scripts/nym-status.
Panel {
  id: root
  moduleName: "io.github.phil71x.nymvpn"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property var info: hostWidget ? hostWidget.info : ({})
  readonly property string status: info.status || ""
  readonly property bool connected: status === "up"
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

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
              featureColor: root.hostWidget ? root.hostWidget.faceColor : Color.bar.background
              discColor: root.hostWidget ? root.hostWidget.discColor : root.barForeground
              rimColor: root.hostWidget ? root.hostWidget.rimColor : root.barForeground
            }
          }
          title: "NymVPN"
          meta: Model.statusLabel(root.status)
          detail: Model.modeLabel(root.info.mode)
          foreground: root.barForeground
          fontFamily: root.fontFamily
        }

        Row {
          visible: root.connected
          width: parent.width
          spacing: Style.space(20)

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.labelGap
            InfoPair { label: "Entry"; value: Model.gateway(root.info.entryCc, root.info.entryPerf) }
            InfoPair { label: "Exit"; value: Model.gateway(root.info.exitCc, root.info.exitPerf) }
          }

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.labelGap
            InfoPair { label: "Since"; value: root.info.since || "—" }
            InfoPair {
              label: "Duration"
              value: Model.duration(root.info.sinceEpoch, root.hostWidget ? root.hostWidget.now : Date.now())
            }
          }
        }

        Column {
          visible: !root.connected
          width: parent.width
          spacing: Style.spacing.labelGap
          InfoPair { label: "Since"; value: root.info.since || "—" }
          InfoPair {
            visible: value !== ""
            label: "Traffic"
            value: Model.trafficLabel(root.status)
          }
        }

        PanelSeparator {
          visible: root.connected
          foreground: root.barForeground
        }

        Column {
          visible: root.connected
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "ROUTE"
            foreground: root.barForeground
            fontFamily: root.fontFamily
          }

          Column {
            width: parent.width
            spacing: Style.spacing.labelGap
            InfoPair { label: "Entry IP"; value: root.info.entryIp || "—" }
            InfoPair { label: "Exit IP"; value: root.info.exitIp || "—" }
          }
        }

        Button {
          width: parent.width
          text: "Open NymVPN"
          bordered: true
          foreground: root.barForeground
          fontFamily: root.fontFamily
          fontSize: Style.font.bodySmall
          onClicked: {
            root.close()
            if (root.hostWidget) root.hostWidget.openApp()
          }
        }
      }
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

  component InfoText: Text {
    textFormat: Text.PlainText
    color: root.barForeground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
