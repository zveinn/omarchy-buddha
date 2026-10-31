import QtQuick

// Mantra-mala border for shell cards (launcher, bar panels): the same
// prayer-bead string as the fractal theme's window rings (mala.frag, copied
// here so the plugin stays self-contained), drawn in a band just OUTSIDE the
// card's visual edge (follows the open/close scale and every resize), never
// over the card and never taking input.
//   open : the beads pour out of the saffron guru bead at the top centre,
//          both ways round, and meet at the bottom; lotus flowers then bloom
//          at the four corners (openDuration, OutCubic).
//   close: the beads run back into the guru bead (closeDuration).
// A soft light travels the string like a counted mantra while it is shown.
// Same API as the matrix theme's GlyphRing.
Item {
  id: ring

  property Item target: null
  property real scaleX: 1
  property real scaleY: 1
  property int band: 10
  property color tint: "#e6b35a"      // kept for API compatibility
  property real bright: 1.0           // kept for API compatibility
  property real prog: 0
  property real fade: 0
  property real time: 0
  property real boost: 0
  property int openDuration: 300
  property int closeDuration: 220

  enabled: false
  visible: !!target && prog > 0 && fade < 1

  readonly property real vw: target ? target.width * scaleX : 0
  readonly property real vh: target ? target.height * scaleY : 0
  x: target ? target.x + (target.width - vw) / 2 - band : 0
  y: target ? target.y + (target.height - vh) / 2 - band : 0
  width: vw + 2 * band
  height: vh + 2 * band

  function playOpen() {
    closeAnim.stop()
    fade = 0
    prog = 0
    introAnim.restart()
  }

  function playClose() {
    introAnim.stop()
    if (prog <= 0) return
    closeAnim.restart()
  }

  // Re-summoned mid-close: snap back to fully shown.
  function resume() {
    closeAnim.stop()
    fade = 0
    if (prog <= 0) playOpen()
  }

  function reset() {
    introAnim.stop()
    closeAnim.stop()
    prog = 0
    fade = 0
  }

  NumberAnimation { id: introAnim; target: ring; property: "prog"; from: 0; to: 1; duration: ring.openDuration; easing.type: Easing.OutCubic }
  NumberAnimation { id: closeAnim; target: ring; property: "fade"; from: 0; to: 1; duration: ring.closeDuration; easing.type: Easing.InOutSine }

  // the travelling light needs ~24 fps, only while the ring is shown
  Timer { interval: 42; repeat: true; running: ring.visible; onTriggered: ring.time = (ring.time + 0.042) % 240 }

  ShaderEffect {
    anchors.fill: parent
    property real time: ring.time
    property real prog: ring.prog
    property real fade: ring.fade
    property real lit: 1
    property real band: ring.band
    property real radius: ring.target && ring.target.radius !== undefined ? Number(ring.target.radius) || 0 : 0
    property real seed: 0.13
    property vector2d res: Qt.vector2d(width, height)
    property vector4d m0: Qt.vector4d(0, 0, 0, 0)
    property vector4d m1: Qt.vector4d(0, 0, 0, 0)
    property vector4d m2: Qt.vector4d(0, 0, 0, 0)
    property vector4d m3: Qt.vector4d(0, 0, 0, 0)
    fragmentShader: Qt.resolvedUrl("mala.frag.qsb")
  }
}
