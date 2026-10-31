// The wallpaper: indigo night, a breathing fractal mandala (aura.frag) and the
// seated Buddha on top. Opaque, WlrLayer.Bottom, click-through.
// Cost control: rendered into a half-resolution layer, ticked by a 30 fps
// Timer (not every vsync), and fully paused while `paused` is set.
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
  id: win
  required property var modelData
  property bool paused: false
  screen: modelData
  color: "#0d0b1d"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.namespace: "fractal-aura"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}

  // the artwork is composed on a 2560x1440 canvas; cover-crop it to the screen
  readonly property real k: Math.max(width / 2560, height / 1440)
  readonly property real ox: (width - 2560 * k) / 2
  readonly property real oy: (height - 1440 * k) / 2

  // epoch-based clock so a lagging timer never changes the tempo
  property real t0: Date.now()
  property real pausedAt: 0

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

  Image {
    id: buddha
    source: Qt.resolvedUrl("buddha.png")
    x: win.ox + 846 * win.k
    y: win.oy + 117 * win.k
    width: 862 * win.k
    height: 1147 * win.k
    smooth: true
    mipmap: true
    asynchronous: true
  }

  Timer {
    interval: 33
    repeat: true
    running: win.visible && !win.paused
    onRunningChanged: if (running && win.pausedAt > 0) { win.t0 += Date.now() - win.pausedAt; win.pausedAt = 0 }
                      else if (!running) win.pausedAt = Date.now()
    onTriggered: aura.time = ((Date.now() - win.t0) / 1000 + 2.5) % 240
  }
}
