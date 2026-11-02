// Soft edge-ring transitions for the fractal theme, on an Overlay layer (click-through):
//   windowFx(mode, x, y, w, h, fx, fy, fw, fh)
//       mode 0 open, 1 close, 2 float/fullscreen toggle (from fx..fh to x..h)
//       all three are one quiet ring of light hugging the window edge: open
//       breathes outward as the window surfaces, close settles inward as it
//       sinks, toggle travels with the window
//   workspace(id, dir, mon, rects)
//       a lotus ring breathes around each window of the arriving workspace in
//       turn (rects come nearest-the-cursor first, 35 ms apart), riding the
//       workspace's own slide; with no rects, a quiet singing-bowl ripple
//
// Smoothness notes:
// - the layer and a small pool of ShaderEffects are created once and kept warm;
//   an event only restarts a slot (no item or pipeline creation per event)
// - every animation runs on the render loop (vsync) with the very same curves
//   hyprland.lua gives the windows and workspaces (beziers and the
//   critically damped lotusSpring), so the light stays on the window edge
// - a toggle carries the old and the new rect, and the petals travel with the
//   window along Hyprland's windowsMove curve instead of waiting at the end
// - the shader fades in and out (zero-slope envelope), antialiases its lines
//   and returns early away from the ring, so a big window costs little
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
  readonly property var curveOpen: [0.25, 0.8, 0.35, 1.0]     // lotusOpen: the ring's breath on open
  readonly property var curveClose: [0.35, 0.0, 0.65, 1.0]    // lotusClose: the ring's breath on close
  readonly property var curveMove: [0.45, 0.0, 0.25, 1.0]     // breath (windowsMove 260 ms)
  readonly property var curveRise: [0.05, 0.92, 0.15, 1.0]    // lotusRise (windowsIn 280 ms, slide bottom)
  readonly property var curveSink: [0.85, 0.0, 0.95, 0.08]    // lotusSink (windowsOut 240 ms, slide bottom)
  // lotusSpring (workspaces): mass 1, stiffness 484, damping 44 -> critical, w = 22/s
  readonly property real springW: 22
  readonly property real wsSlide: 0.16                        // slidefadevert 16%

  property int nextSlot: 0
  // Hyprland's windowsMove: speed 2.6 = 260 ms. The toggle reaches us a frame or
  // two after Hyprland starts moving the window (16 ms poll + file watch +
  // render), so the petals run that much ahead to stay on the window edge.
  readonly property real moveMs: 260
  readonly property real moveLeadMs: 24
  // open/close: the window's own slide, and how far behind it the event reaches
  // us (open waits 10 ms in hyprland.lua for the final size)
  readonly property real riseMs: 280
  readonly property real openLeadMs: 30
  readonly property real sinkMs: 240
  readonly property real closeLeadMs: 16
  // the open ring waits until the window has surfaced (~120 ms in, ~45 px and
  // 35% opacity to go) so it blooms as the window settles, not under the veil
  readonly property real openRingAt: 120
  readonly property real openRingMs: 260
  // workspace rings
  readonly property real wsStagger: 35
  readonly property real wsRingMs: 420
  readonly property real wsLeadMs: 20

  // cubic-bezier(x1, y1, x2, y2) at x, like Hyprland's curves (bisection: safe
  // for the steep lotusRise/lotusSink too)
  function bezier(c, x) {
    if (x <= 0) return 0
    if (x >= 1) return 1
    let lo = 0, hi = 1, t = x
    for (let i = 0; i < 18; i++) {
      t = 0.5 * (lo + hi)
      const u = 1 - t
      if (3 * u * u * t * c[0] + 3 * u * t * t * c[2] + t * t * t < x) lo = t; else hi = t
    }
    const u = 1 - t
    return 3 * u * u * t * c[1] + 3 * u * t * t * c[3] + t * t * t
  }
  // the critically damped spring from rest, ms since it started
  function spring(ms) {
    if (ms <= 0) return 0
    const wt = fx.springW * ms / 1000
    return Math.min(1, 1 - Math.exp(-wt) * (1 + wt))
  }

  function onScreen(x, y, w, h) {
    const s = fx.modelData
    return w > 0 && h > 0 && x < s.x + s.width && y < s.y + s.height && x + w > s.x && y + h > s.y
  }
  function freeSlot() {
    for (let i = 0; i < pool.count; i++) {
      const s = pool.itemAt(i)
      if (s && !s.busy) return s
    }
    const s = pool.itemAt(nextSlot)
    nextSlot = (nextSlot + 1) % pool.count
    return s
  }
  function windowFx(mode, x, y, w, h, fx0, fy0, fw0, fh0) {
    if (!fx.visible) return
    if (!(fw0 > 0 && fh0 > 0)) { fx0 = x; fy0 = y; fw0 = w; fh0 = h }
    if (!onScreen(x, y, w, h) && !onScreen(fx0, fy0, fw0, fh0)) return
    const slot = freeSlot()
    if (!slot) return
    const ox = fx.modelData.x, oy = fx.modelData.y
    slot.play(mode, fx0 - ox, fy0 - oy, fw0, fh0, x - ox, y - oy, w, h, 0)
  }

  // the arriving workspace's slide offset (px) and clock, shared by its rings
  property real wsT: 0
  property real wsDir: 1
  property real wsOff: 0
  FrameAnimation {
    id: wsClock
    running: false
    onTriggered: {
      fx.wsT += frameTime * 1000
      fx.wsOff = fx.wsDir * fx.height * fx.wsSlide * (1 - fx.spring(fx.wsT + fx.wsLeadMs))
      if (fx.wsT > 500) { fx.wsOff = 0; stop() }
    }
  }
  function workspace(id, dir, mon, rects) {
    if (!fx.visible) return
    if (mon && mon !== "-" && mon !== fx.modelData.name) return
    dir = dir < 0 ? -1 : 1
    const ox = fx.modelData.x, oy = fx.modelData.y
    let n = 0
    for (let i = 0; i + 3 < rects.length && n < pool.count; i += 4) {
      const x = rects[i], y = rects[i + 1], w = rects[i + 2], h = rects[i + 3]
      if (!onScreen(x, y, w, h)) continue
      if (n === 0) {
        fx.wsDir = dir; fx.wsT = 0
        fx.wsOff = dir * fx.height * fx.wsSlide * (1 - fx.spring(fx.wsLeadMs))
        wsClock.restart()
      }
      const slot = freeSlot()
      if (!slot) break
      slot.play(3, x - ox, y - oy, w, h, x - ox, y - oy, w, h, n * fx.wsStagger, (id * 0.137 + n * 0.29) % 1, dir)
      n++
    }
    if (n > 0) return
    // nothing ringed there (empty, fullscreen or a lone window): a quiet ripple
    ripple.dir = dir
    ripple.seed = (id * 0.137) % 1
    rippleAnim.restart()
  }

  ShaderEffect {
    id: ripple
    anchors.fill: parent
    visible: rippleAnim.running
    opacity: 0.55            // toned down: only the fallback now
    property real prog: 0
    property real dir: 1
    property real seed: 0
    property vector2d res: Qt.vector2d(width, height)
    fragmentShader: Qt.resolvedUrl("ripple.frag.qsb")
    NumberAnimation on prog { id: rippleAnim; running: false; from: 0; to: 1; duration: 320; easing.type: Easing.OutQuad }
  }

  Repeater {
    id: pool
    model: 8
    ShaderEffect {
      id: b
      visible: busy && t >= 0
      property bool busy: false
      property real mode: 0
      property real seed: 0
      property real dir: 1
      property real fromX: 0; property real fromY: 0; property real fromW: 1; property real fromH: 1
      property real toX: 0; property real toY: 0; property real toW: 1; property real toH: 1
      property real mv: 1       // 0..1 along Hyprland's windowsMove curve
      property real moveT: 0    // ms since the toggle
      property real t: 0        // ms since the ring started (negative: still waiting)
      property real delay: 0    // ms the ring waits after the event
      property int dur: 300
      property real slideDist: 0  // open/close: px from the window to the screen bottom
      property var curve: fx.curveOpen
      // 0..1 linear, drives the fade envelope
      readonly property real life: Math.max(0, Math.min(1, t / dur))
      // 0..1 eased: the ring's breath
      readonly property real prog: busy ? fx.bezier(curve, life) : 0
      // where the window is along its own slide (open/close), in px below its rect
      readonly property real slideY: !busy ? 0
        : mode === 0 ? (1 - fx.bezier(fx.curveRise, (t + delay + fx.openLeadMs) / fx.riseMs)) * slideDist
        : mode === 1 ? fx.bezier(fx.curveSink, (t + fx.closeLeadMs) / fx.sinkMs) * slideDist
        : mode === 3 ? fx.wsOff : 0
      // the window rect this frame
      readonly property real wx: fromX + (toX - fromX) * mv
      readonly property real wy: fromY + (toY - fromY) * mv + slideY
      readonly property real ww: Math.max(1, fromW + (toW - fromW) * mv)
      readonly property real wh: Math.max(1, fromH + (toH - fromH) * mv)
      // the ring stays close to the window edge
      property real pad: mode > 1.5 ? 30 : 22
      x: wx - pad; y: wy - pad; width: ww + 2 * pad; height: wh + 2 * pad
      property vector2d res: Qt.vector2d(width, height)
      fragmentShader: Qt.resolvedUrl("bloom.frag.qsb")

      function play(m, ax, ay, aw, ah, bx, by, bw, bh, wait, sd, d) {
        anim.stop()
        mode = m
        seed = sd === undefined ? Math.random() : sd
        dir = d === undefined ? 1 : d
        fromX = ax; fromY = ay; fromW = aw; fromH = ah
        toX = bx; toY = by; toW = bw; toH = bh
        slideDist = Math.max(0, fx.height - by)
        curve = m === 1 ? fx.curveClose : (m === 2 ? fx.curveMove : fx.curveOpen)
        // open: bloom once the window has surfaced; close: on the event, as
        // long as the window's own fade; toggle: its 300 ms breath
        delay = m === 0 ? Math.max(0, fx.openRingAt - fx.openLeadMs) : (wait || 0)
        dur = m === 0 ? fx.openRingMs
            : m === 1 ? Math.max(120, fx.sinkMs - fx.closeLeadMs + 10)
            : m === 3 ? fx.wsRingMs : 300
        const moving = m === 2 && (ax !== bx || ay !== by || aw !== bw || ah !== bh)
        moveT = 0
        mv = moving ? fx.bezier(fx.curveMove, fx.moveLeadMs / fx.moveMs) : 1
        t = -delay
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
      NumberAnimation {
        id: anim
        target: b; property: "t"; from: -b.delay; to: b.dur; duration: b.delay + b.dur
        onFinished: b.busy = false
      }
    }
  }

  // compile the bloom pipeline once at startup (one invisible frame), so the
  // first real window doesn't pay for it
  Timer {
    interval: 400; running: fx.visible; repeat: false
    onTriggered: { const s = pool.itemAt(0); if (s && !s.busy) s.play(2, -64, -64, 8, 8, -64, -64, 8, 8, 0) }
  }
}
