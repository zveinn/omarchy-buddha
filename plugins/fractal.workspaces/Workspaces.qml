import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "fx"

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  // ---- Fractal FX. Switching workspace: a saffron guru bead glides from
  //      the old button to the new one with two lotus-pink beads trailing it
  //      like a mala being told; the new label blooms open (scale + fade)
  //      while a ripple ring spreads from it. Hover: one soft breath.
  //      "fractalFx" setting: theme (default) | always | off.
  readonly property string fxMode: String(setting("fractalFx", "theme"))
  readonly property bool fxOn: fxMode === "always" || (fxMode === "theme" && fxGate.active)
  readonly property color fxColor: root.bar ? root.bar.barForeground : Commons.Color.foreground
  readonly property color fxHot: Qt.tint(root.fxColor, Qt.rgba(1, 1, 1, 0.78))
  property int fxLastId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1

  FractalGate { id: fxGate }

  function fxButtonFor(id) {
    var ids = root.workspaceIds()
    var i = ids.indexOf(id)
    return i < 0 ? null : wsRepeater.itemAt(i)
  }

  Connections {
    target: Hyprland
    function onFocusedWorkspaceChanged() {
      var next = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
      var prev = root.fxLastId
      root.fxLastId = next
      if (!root.fxOn || next === prev) return
      var to = root.fxButtonFor(next)
      if (!to) return
      to.fxDecode(300, true)
      var from = root.fxButtonFor(prev)
      if (from && !root.vertical) {
        streak.fromX = from.x + grid.x + from.width / 2
        streak.toX = to.x + grid.x + to.width / 2
        streak.y = to.y + grid.y + to.height - streak.height - Style.space(2)
        streakAnim.restart()
      }
    }
  }

  // Streak: a guru bead with two trailing beads on a faint thread, along
  // the bottom of the row.
  Item {
    id: streak
    property real fromX: 0
    property real toX: 0
    property real t: 0
    readonly property real dir: toX >= fromX ? 1 : -1
    readonly property real span: Math.abs(toX - fromX)
    readonly property real headX: fromX + (toX - fromX) * t
    readonly property real bead: Math.max(3, Style.space(4))
    z: 10
    width: 0
    height: bead
    visible: streakAnim.running

    // faint silk thread behind the beads
    Rectangle {
      x: Math.min(streak.headX, streak.headX - streak.dir * streak.span * 0.5 * (1 - streak.t))
      width: Math.max(2, streak.span * 0.5 * (1 - streak.t))
      y: (streak.height - height) / 2
      height: 1
      color: "#e7a1c4"
      opacity: 0.55 * (1 - streak.t)
    }

    Repeater {
      model: streak.visible ? 3 : 0
      Rectangle {
        required property int index
        readonly property real lag: index * 0.16
        readonly property real tt: Math.max(0, Math.min(1, (streak.t - lag) / (1 - lag)))
        width: streak.bead * (index === 0 ? 1 : 0.8 - index * 0.1)
        height: width
        radius: width / 2
        x: streak.fromX + (streak.toX - streak.fromX) * tt - width / 2
        y: (streak.height - height) / 2
        color: index === 0 ? root.fxHot : "#e7a1c4"
        opacity: index === 0 ? 1 : (0.75 - index * 0.2) * (1 - streak.t * 0.5)
      }
    }

    NumberAnimation {
      id: streakAnim
      target: streak
      property: "t"
      from: 0
      to: 1
      duration: 260
      easing.type: Easing.InOutSine
    }
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      id: wsRepeater
      model: root.workspaceIds()

      WidgetButton {
        id: wsButton
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

        bar: root.bar
        text: focused ? "\uDB85\uDCFB" : (modelData === 10 ? "0" : String(modelData))
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }
        labelVisible: !wsButton.fxRunning

        // ---- Fractal FX: label bloom + ripple ring (fixed-width cell, so no
        //      layout shift). Nothing animates unless a bloom is playing.
        property bool fxRunning: bloomAnim.running
        property real fxBloom: 1
        property bool fxDrop: false

        function fxDecode(duration, drop) {
          wsButton.fxDrop = drop === true
          bloomAnim.duration = Math.max(120, duration)
          bloomAnim.from = wsButton.fxDrop ? 0 : 0.55
          bloomAnim.restart()
          if (wsButton.fxDrop) rippleAnim.restart()
        }

        NumberAnimation {
          id: bloomAnim
          target: wsButton
          property: "fxBloom"
          to: 1
          easing.type: Easing.OutBack
          easing.overshoot: 1.4
        }

        Text {
          visible: wsButton.fxRunning
          anchors.centerIn: parent
          text: wsButton.text
          color: wsButton.fxBloom < 0.9 ? root.fxHot : wsButton.foreground
          font.family: wsButton.fontFamily
          font.pixelSize: wsButton.fontSize
          scale: 0.45 + 0.55 * wsButton.fxBloom
          opacity: Math.min(1, 0.15 + wsButton.fxBloom)
          Behavior on color { ColorAnimation { duration: 120 } }
        }

        Item {
          anchors.fill: parent
          clip: true
          visible: rippleAnim.running

          Rectangle {
            id: ripple
            property real p: 0
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * (0.3 + 0.9 * p)
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1.5
            border.color: "#e7a1c4"
            opacity: 0.8 * (1 - p)
          }

          NumberAnimation {
            id: rippleAnim
            target: ripple
            property: "p"
            from: 0
            to: 1
            duration: 420
            easing.type: Easing.OutCubic
          }
        }

        HoverHandler {
          enabled: root.fxOn
          onHoveredChanged: if (hovered && !wsButton.fxRunning) wsButton.fxDecode(130, false)
        }
      }
    }
  }
}
