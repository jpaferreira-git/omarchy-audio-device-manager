import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Ui
import qs.Commons

// Settings-style panel (not the quick-access omarchy.audio popup) for
// renaming and enabling/disabling audio input/output devices. Backed by
// the omarchy-audio-device-manager script bundled next to this file, which
// persists overrides as WirePlumber monitor.alsa.rules / monitor.bluez.rules
// and reloads wireplumber.service to apply them. Mouse-first: no custom
// keyboard cursor grid, unlike the built-in panels this borrows chrome from.
Panel {
  id: root
  moduleName: "jferreira.audio-device-manager"
  ipcTarget: "jferreira.audio-device-manager"

  // Run through bash so it works even if the executable bit was lost.
  readonly property string backend: decodeURIComponent(
    Qt.resolvedUrl("omarchy-audio-device-manager").toString().replace(/^file:\/\//, ""))

  property var devices: []
  property string editingNode: ""
  property string editingText: ""

  readonly property var outputs: devices.filter(function(d) { return d.kind === "sink" })
  readonly property var inputs: devices.filter(function(d) { return d.kind === "source" })

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color hoverFill: bar ? Style.hoverFillFor(bar.foreground, Color.accent) : "transparent"

  function refresh() {
    listProc.running = true
  }

  function runAction(cmd) {
    actionProc.command = cmd
    actionProc.running = true
  }

  function startRename(node, currentName) {
    editingNode = node
    editingText = currentName
  }

  function cancelRename() {
    editingNode = ""
  }

  function commitRename(node, kind) {
    if (editingNode !== node) return
    var name = editingText.trim()
    editingNode = ""
    runAction(["bash", root.backend, "set-name", node, kind, name])
  }

  function toggleDisabled(node, kind, nextDisabled) {
    runAction(["bash", root.backend, "set-disabled", node, kind, nextDisabled ? "true" : "false"])
  }

  function resetDevice(node) {
    runAction(["bash", root.backend, "reset", node])
  }

  onOpenedChanged: if (opened) refresh()

  Process {
    id: listProc
    command: ["bash", root.backend, "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.devices = JSON.parse(text) } catch (e) { root.devices = [] }
      }
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.devices = JSON.parse(text) } catch (e) { }
      }
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰴸"
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Column {
          id: panelColumn
          width: scrollArea.availableWidth
          spacing: Style.space(14)

          Text {
            textFormat: Text.PlainText
            text: "Dispositivos de Áudio"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            width: parent.width
            elide: Text.ElideRight
          }

          PanelSeparator {
            foreground: root.foreground
          }

          Column {
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              text: "SAÍDA"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.outputs
              DeviceRow {
                required property var modelData
                width: panelColumn.width
                device: modelData
              }
            }

            Text {
              visible: root.outputs.length === 0
              width: parent.width
              text: "Nenhum dispositivo de saída"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          PanelSeparator {
            foreground: root.foreground
          }

          Column {
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              text: "ENTRADA"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.inputs
              DeviceRow {
                required property var modelData
                width: panelColumn.width
                device: modelData
              }
            }

            Text {
              visible: root.inputs.length === 0
              width: parent.width
              text: "Nenhum dispositivo de entrada"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }
      }
    }
  }

  component DeviceRow: CursorSurface {
    id: row
    required property var device
    foreground: root.foreground
    fill: root.hoverFill
    implicitHeight: inner.implicitHeight + Style.spacing.xl

    readonly property bool editing: root.editingNode === device.node_name
    readonly property bool isDisabled: device.disabled === true
    readonly property bool hasOverride: device.custom_name !== null

    Row {
      id: inner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: row.device.kind === "sink" ? "󰓃" : "󰍬"
        color: row.isDisabled ? root.dim : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
        width: Style.space(22)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Loader {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - Style.space(22) - (resetBtn.visible ? resetBtn.width + Style.space(8) : 0) - toggleSwitch.width - Style.space(24)
        sourceComponent: row.editing ? editComponent : labelComponent

        Component {
          id: labelComponent
          Text {
            textFormat: Text.PlainText
            text: row.device.display_name + (row.device.live ? "" : "  (desconectado)")
            color: row.isDisabled ? root.dim : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
            width: parent ? parent.width : implicitWidth

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.IBeamCursor
              onClicked: root.startRename(row.device.node_name, row.device.display_name)
            }
          }
        }

        Component {
          id: editComponent
          TextField {
            width: parent ? parent.width : implicitWidth
            foreground: root.foreground
            verticalPadding: Style.space(2)
            text: root.editingText
            onTextChanged: root.editingText = text
            Component.onCompleted: { forceActiveFocus(); selectAll() }
            onAccepted: root.commitRename(row.device.node_name, row.device.kind)
            Keys.onEscapePressed: root.cancelRename()
            onActiveFocusChanged: if (!activeFocus) root.commitRename(row.device.node_name, row.device.kind)
          }
        }
      }

      PanelActionButton {
        id: resetBtn
        visible: row.hasOverride && !row.editing
        iconText: "󰑙"
        tooltipText: "Restaurar padrão"
        foreground: root.foreground
        fontFamily: root.fontFamily
        anchors.verticalCenter: parent.verticalCenter
        onClicked: root.resetDevice(row.device.node_name)
      }

      ToggleSwitch {
        id: toggleSwitch
        checked: !row.isDisabled
        foreground: root.foreground
        anchors.verticalCenter: parent.verticalCenter
        onToggled: root.toggleDisabled(row.device.node_name, row.device.kind, checked)

        PanelToolTip {
          visible: toggleSwitch.containsMouse
          text: row.isDisabled ? "Ativar" : "Desativar"
          fontFamily: root.fontFamily
        }
      }
    }
  }
}
