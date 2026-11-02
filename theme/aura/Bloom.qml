// Soft edge-ring transitions for the fractal theme, on an Overlay layer (click-through):
//   windowFx(mode, x, y, w, h, fx, fy, fw, fh)
//       mode 0 open, 1 close, 2 float/fullscreen toggle (from fx..fh to x..h)
//       all three are one quiet ring of light hugging the window edge: open
//       breathes outward, close settles inward, toggle travels with the window
//   workspace(id, dir)   singing-bowl ripple from the centre of the screen
//
// Smoothness notes:
// - the layer and a small pool of ShaderEffects are created once and kept warm;
//   an event only restarts a slot (no item or pipeline creation per event)
// - every animation runs on the render loop (vsync, ~60 fps) with the very same
//   bezier curves hyprland.lua gives the windows, and lasts as long as the
//   window's own animation (plus a frame or two of event latency)
// - a toggle carries the old and the new rect, and the petals travel with the
//   window along Hyprland's windowsMove curve instead of waiting at the end
// - the shader fades in and out (zero-slope envelope) and antialiases its lines
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

  // control points shared with hyprland.lua (hl.curve ...)
  readonly property var curveOpen: [0.25, 0.8, 0.35, 1.0, 1, 1]     // lotusOpen  (windowsIn 260 ms, popin 96%)
  readonly property var curveClose: [0.35, 0.0, 0.65, 1.0, 1, 1]    // lotusClose (windowsOut 240 ms, popin 97%)
  readonly property var curveMove: [0.45, 0.0, 0.25, 1.0, 1, 1]     // breath     (windowsMove 260 ms)

  property int nextSlot: 0
  // Hyprland's windowsMove: speed 2.6 = 260 ms. The toggle reaches us a frame or
  // two after Hyprland starts moving the window (16 ms poll + file watch +
  // render), so the petals run that much ahead to stay on the window edge.
  readonly property real moveMs: 260
  readonly property real moveLeadMs: 24
  // open/close: the window's own in/out animation, and how far behind it the
  // event reaches us (open waits 10 ms in hyprland.lua for the final size)
  readonly property real openMs: 260
  readonly property real openLeadMs: 30
  readonly property real closeMs: 240
  readonly property real closeLeadMs: 16

  // cubic-bezier(x1, y1, x2, y2) at x, like Hyprland's curves
  function bezier(c, x) {
    if (x <= 0) return 0
    if (x >= 1) return 1
    let t = x
    for (let i = 0; i < 8; i++) {
      const u = 1 - t
      const X = 3 * u * u * t * c[0] + 3 * u * t * t * c[2] + t * t * t - x
      const dX = 3 * u * u * c[0] + 6 * u * t * (c[2] - c[0]) + 3 * t * t * (1 - c[2])
      if (Math.abs(X) < 1e-4 || dX < 1e-6) break
      t = Math.min(1, Math.max(0, t - X / dX))
    }
    const u = 1 - t
    return 3 * u * u * t * c[1] + 3 * u * t * t * c[3] + t * t * t
  }

  function onScreen(x, y, w, h) {
    const s = fx.modelData
    return w > 0 && h > 0 && x < s.x + s.width && y < s.y + s.height && x + w > s.x && y + h > s.y
  }
  function windowFx(mode, x, y, w, h, fx0, fy0, fw0, fh0) {
    if (!fx.visible) return
    if (!(fw0 > 0 && fh0 > 0)) { fx0 = x; fy0 = y; fw0 = w; fh0 = h }
    if (!onScreen(x, y, w, h) && !onScreen(fx0, fy0, fw0, fh0)) return
    let slot = null
    for (let i = 0; i < pool.count; i++) {
      const s = pool.itemAt(i)
      if (s && !s.busy) { slot = s; break }
    }
    if (!slot) { slot = pool.itemAt(nextSlot); nextSlot = (nextSlot + 1) % pool.count }
    if (!slot) return
    const ox = fx.modelData.x, oy = fx.modelData.y
    slot.play(mode, fx0 - ox, fy0 - oy, fw0, fh0, x - ox, y - oy, w, h)
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
    id: pool
    model: 6
    ShaderEffect {
      id: b
      visible: busy
      property bool busy: false
      property real mode: 0
      property real seed: 0
      property real fromX: 0; property real fromY: 0; property real fromW: 1; property real fromH: 1
      property real toX: 0; property real toY: 0; property real toW: 1; property real toH: 1
      property real mv: 1       // 0..1 along Hyprland's windowsMove curve
      property real moveT: 0    // ms since the toggle
      property real t: 0        // ms since the event
      property real lead: 0     // ms the window's animation is ahead of us
      property real winMs: 300  // the window's own animation length
      property int dur: 300
      property var curve: fx.curveOpen
      // 0..1 along the window's own in/out curve, on the window's clock
      readonly property real prog: busy ? fx.bezier(curve, (t + lead) / winMs) : 0
      // 0..1 linear, drives the fade envelope
      readonly property real life: Math.min(1, t / dur)
      // the window rect this frame
      readonly property real wx: fromX + (toX - fromX) * mv
      readonly property real wy: fromY + (toY - fromY) * mv
      readonly property real ww: Math.max(1, fromW + (toW - fromW) * mv)
      readonly property real wh: Math.max(1, fromH + (toH - fromH) * mv)
      // the bloom spills a little past the window edge
      // the ring stays close to the window edge
      property real pad: mode > 1.5 ? 30 : 22
      x: wx - pad; y: wy - pad; width: ww + 2 * pad; height: wh + 2 * pad
      property vector2d res: Qt.vector2d(width, height)
      fragmentShader: Qt.resolvedUrl("bloom.frag.qsb")

      function play(m, ax, ay, aw, ah, bx, by, bw, bh) {
        anim.stop()
        mode = m; seed = Math.random()
        fromX = ax; fromY = ay; fromW = aw; fromH = ah
        toX = bx; toY = by; toW = bw; toH = bh
        // durations: the window's own animation, minus the event latency
        // already spent (open/close); the toggle keeps its 300 ms breath
        curve = m === 1 ? fx.curveClose : (m === 2 ? fx.curveMove : fx.curveOpen)
        winMs = m === 1 ? fx.closeMs : (m === 2 ? 300 : fx.openMs)
        lead = m === 1 ? fx.closeLeadMs : (m === 2 ? 0 : fx.openLeadMs)
        dur = m === 2 ? 300 : Math.max(120, winMs - lead + 10)
        const moving = m === 2 && (ax !== bx || ay !== by || aw !== bw || ah !== bh)
        moveT = 0
        mv = moving ? fx.bezier(fx.curveMove, fx.moveLeadMs / fx.moveMs) : 1
        t = 0
        busy = true
        anim.start()
      }

      // the rect follows the window per rendered frame (vsync), by elapsed time
      FrameAnimation {
        running: b.busy && b.mv < 1
        onTriggered: {
          b.moveT += frameTime * 1000
          b.mv = fx.bezier(fx.curveMove, (b.moveT + fx.moveLeadMs) / fx.moveMs)
        }
      }
      ParallelAnimation {
        id: anim
        NumberAnimation { target: b; property: "t"; from: 0; to: b.dur; duration: b.dur }
        onFinished: b.busy = false
      }
    }
  }

  // compile the bloom pipeline once at startup (one invisible frame), so the
  // first real window doesn't pay for it
  Timer {
    interval: 400; running: fx.visible; repeat: false
    onTriggered: { const s = pool.itemAt(0); if (s && !s.busy) s.play(2, -64, -64, 8, 8, -64, -64, 8, 8) }
  }
}
