// Mantra-mala rings for the fractal theme. Driven by hyprland.lua over the
// fractal-fx feed: every window on a visible workspace gets a string of prayer
// beads in the band just OUTSIDE it (never over its content).
//   focused  - iridescent beads, a light travelling the string like a counted
//              mantra, lotus flowers blooming at the corners; on focus the
//              beads pour out from the guru bead both ways
//   inactive - dim violet beads that only breathe
// Two instances per screen: floatLayer false = tiled windows' rings on the
// Bottom layer (above the aura, under every window); floatLayer true =
// floating windows' rings on Overlay, with floating windows above cut out.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
  id: fx
  required property var modelData
  property bool floatLayer: false
  screen: modelData
  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  // the Bottom instance starts parked on Overlay and drops to Bottom once the
  // aura is mapped, so it always lands above the wallpaper
  property bool armed: false
  WlrLayershell.layer: (fx.floatLayer || !fx.armed) ? WlrLayer.Overlay : WlrLayer.Bottom
  WlrLayershell.namespace: fx.floatLayer ? "fractal-mala-float" : "fractal-mala"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}
  onVisibleChanged: { armed = false; if (visible) armTimer.restart() }
  Timer { id: armTimer; interval: 700; running: true; onTriggered: fx.armed = true }

  readonly property int band: 12
  readonly property real radius: 10
  property real activeTime: 0
  property real idleTime: 0

  ListModel { id: rings }

  // list: "addr x y w h floating active [mx my mw mh ...];..."
  function setList(list) {
    const want = []
    for (const e of list.split(";")) {
      const p = e.trim().split(/\s+/)
      if (p.length < 7) continue
      if ((p[5] === "1") !== fx.floatLayer) continue
      const n = p.slice(1).map(Number)
      want.push({ addr: p[0], gx: n[0], gy: n[1], gw: n[2], gh: n[3], act: n[5] === 1, masks: p.slice(7).join(" ") })
    }
    const keep = {}
    for (const w of want) keep[w.addr] = true
    for (let i = rings.count - 1; i >= 0; i--) if (!keep[rings.get(i).addr]) rings.remove(i)
    want.forEach((w, k) => {
      let i = -1
      for (let j = 0; j < rings.count; j++) if (rings.get(j).addr === w.addr) { i = j; break }
      if (i < 0) { rings.insert(Math.min(k, rings.count), w); return }
      if (i !== k && k < rings.count) { rings.move(i, k, 1); i = k }
      for (const key of ["gx", "gy", "gw", "gh", "act", "masks"])
        if (rings.get(i)[key] !== w[key]) rings.setProperty(i, key, w[key])
    })
  }

  Repeater {
    model: rings
    ShaderEffect {
      id: ring
      required property string addr
      required property real gx; required property real gy
      required property real gw; required property real gh
      required property bool act
      required property string masks
      required property int index
      x: gx - fx.modelData.x - fx.band; y: gy - fx.modelData.y - fx.band
      width: gw + 2 * fx.band; height: gh + 2 * fx.band
      // a stable per-window phase from the address
      readonly property real seed: (parseInt(addr.slice(-5), 16) % 997) / 997
      property real time: (act ? fx.activeTime : fx.idleTime) % 240
      property real prog: 1
      property real lit: act ? 1 : 0
      property real band: fx.band
      property real radius: fx.radius
      property vector2d res: Qt.vector2d(width, height)
      property vector4d m0: mrect(0)
      property vector4d m1: mrect(1)
      property vector4d m2: mrect(2)
      property vector4d m3: mrect(3)
      function mrect(k) {
        const v = masks.length ? masks.split(" ").map(Number) : []
        if (v.length < k * 4 + 4) return Qt.vector4d(0, 0, 0, 0)
        return Qt.vector4d(v[k * 4] - gx + fx.band, v[k * 4 + 1] - gy + fx.band, v[k * 4 + 2], v[k * 4 + 3])
      }
      fragmentShader: Qt.resolvedUrl("mala.frag.qsb")
      Component.onCompleted: if (act) intro.restart()
      onActChanged: if (act) intro.restart(); else { intro.stop(); prog = 1 }
      NumberAnimation { id: intro; target: ring; property: "prog"; from: 0; to: 1; duration: 520; easing.type: Easing.OutCubic }
    }
  }

  // the focused ring needs ~24 fps for its travelling light; idle rings only breathe
  Timer { interval: 42;  repeat: true; running: fx.visible && rings.count > 0; onTriggered: fx.activeTime = (fx.activeTime + 0.042) % 240 }
  Timer { interval: 250; repeat: true; running: fx.visible && rings.count > 0; onTriggered: fx.idleTime = (fx.idleTime + 0.25) % 240 }

  // ask hyprland.lua to resend the ring list after this process (re)starts
  Process {
    running: true
    command: ["hyprctl", "repl", "if fractal_ring_resync then fractal_ring_resync() end"]
  }
}
