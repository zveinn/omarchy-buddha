// ✿ FRACTAL ✿ screensaver: the same living scene as the wallpaper (the seated
// Buddha in his breathing fractal aura, aura.frag + buddha.png), fullscreen on
// every monitor on the Overlay layer above all windows and the bar. No text.
// Any key, click, wheel or mouse movement quits (armed after 600 ms so the
// pointer-enter fired as the layer maps is ignored).
// Launched by ~/.local/bin/omarchy-launch-screensaver via ./fractal-screensaver.
import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
  id: root
  property bool armed: false
  function dismiss() { Qt.quit() }
  Timer { interval: 600; running: true; onTriggered: root.armed = true }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData
      screen: modelData
      color: "#0d0b1d"
      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "org.omarchy.screensaver"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

      readonly property real k: Math.max(width / 2560, height / 1440)
      readonly property real ox: (width - 2560 * k) / 2
      readonly property real oy: (height - 1440 * k) / 2
      property real t0: Date.now()

      FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(e) { e.accepted = true; root.dismiss() }

        Item {
          id: scene
          anchors.fill: parent
          opacity: 0
          NumberAnimation on opacity { from: 0; to: 1; duration: 1200; easing.type: Easing.InOutSine }

          ShaderEffect {
            id: aura
            anchors.fill: parent
            property real time: 2.5
            property real unit: 1440 * win.k
            property real glow: 1.0
            property vector2d res: Qt.vector2d(width, height)
            property vector2d center: Qt.vector2d(win.ox + 1278 * win.k, win.oy + 650 * win.k)
            property vector2d head: Qt.vector2d(win.ox + 1276 * win.k, win.oy + 357 * win.k)
            fragmentShader: Qt.resolvedUrl("aura.frag.qsb")
            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(Math.ceil(width / 2), Math.ceil(height / 2))
          }

          // the Buddha breathes too: a very slow, slight swell in step with the aura
          Image {
            source: Qt.resolvedUrl("buddha.png")
            x: win.ox + 846 * win.k
            y: win.oy + 117 * win.k
            width: 862 * win.k
            height: 1147 * win.k
            smooth: true
            mipmap: true
            asynchronous: true
            transformOrigin: Item.Bottom
            scale: 1.0 + 0.008 * Math.sin(aura.time * 2 * Math.PI / 5.0)
          }
        }

        Timer {
          interval: 33
          repeat: true
          running: true
          onTriggered: aura.time = ((Date.now() - win.t0) / 1000 + 2.5) % 240
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.AllButtons
          cursorShape: Qt.BlankCursor
          property point p0: Qt.point(-1, -1)
          onPressed: root.dismiss()
          onWheel: root.dismiss()
          onPositionChanged: function(m) {
            if (!root.armed || p0.x < 0) { p0 = Qt.point(m.x, m.y); return }
            if (Math.abs(m.x - p0.x) + Math.abs(m.y - p0.y) > 6) root.dismiss()
          }
        }
      }
    }
  }
}
