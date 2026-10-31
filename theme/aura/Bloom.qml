// Lotus transitions for the fractal theme, on an Overlay layer (click-through):
//   windowFx(mode, x, y, w, h)  mode 0 open, 1 close, 2 float/fullscreen toggle
//   workspace(id, dir)          singing-bowl ripple from the centre of the screen
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
  id: fx
  required property var modelData
  screen: modelData
  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "fractal-bloom"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}

  property int serial: 0
  ListModel { id: wins }

  function onScreen(x, y, w, h) {
    const s = fx.modelData
    return w > 0 && h > 0 && x < s.x + s.width && y < s.y + s.height && x + w > s.x && y + h > s.y
  }
  function windowFx(mode, x, y, w, h) {
    if (!fx.visible || !onScreen(x, y, w, h)) return
    if (wins.count >= 8) wins.remove(0)
    serial = (serial + 1) % 100000
    wins.append({ key: serial, mode: mode, wx: x - fx.modelData.x, wy: y - fx.modelData.y, ww: w, wh: h,
                  seed: Math.random() })
  }
  function drop(key) {
    for (let i = 0; i < wins.count; i++) if (wins.get(i).key === key) { wins.remove(i); return }
  }
  function workspace(id, dir) {
    if (!fx.visible) return
    ripple.dir = dir < 0 ? -1 : 1
    ripple.seed = (id * 0.137) % 1
    rippleAnim.restart()
  }

  ShaderEffect {
    id: ripple
    anchors.fill: parent
    visible: rippleAnim.running
    property real prog: 0
    property real dir: 1
    property real seed: 0
    property vector2d res: Qt.vector2d(width, height)
    fragmentShader: Qt.resolvedUrl("ripple.frag.qsb")
    NumberAnimation on prog { id: rippleAnim; running: false; from: 0; to: 1; duration: 320; easing.type: Easing.OutQuad }
  }

  Repeater {
    model: wins
    ShaderEffect {
      id: b
      required property int key
      required property int mode
      required property real wx; required property real wy
      required property real ww; required property real wh
      required property real seed
      // the bloom spills a little past the window edge
      readonly property real pad: Math.min(ww, wh) * 0.08
      x: wx - pad; y: wy - pad; width: ww + 2 * pad; height: wh + 2 * pad
      property real prog: 0
      property vector2d res: Qt.vector2d(width, height)
      fragmentShader: Qt.resolvedUrl("bloom.frag.qsb")
      SequentialAnimation {
        running: true
        NumberAnimation { target: b; property: "prog"; from: 0; to: 1; duration: b.mode === 1 ? 240 : (b.mode === 2 ? 220 : 280); easing.type: b.mode === 1 ? Easing.InOutQuad : Easing.OutCubic }
        ScriptAction { script: fx.drop(b.key) }
      }
    }
  }
}
