import QtQuick

// Fractal open/close for the Omarchy launcher card. Purely visual: the
// window maps, takes focus and accepts typing on its first frame.
//   open : an opaque indigo veil over the card parts like a lotus from its
//          top centre (LotusIris.qml, 260 ms) with a saffron / lotus-pink
//          rim of light; the scrim fades in (180 ms).
//   close: the petals fold back over the card (220 ms) with the scrim
//          fading out alongside, then hide.
// Plain Items, never take input; nothing ticks while idle.
Item {
  id: fx

  property Item card: null
  property bool active: false
  property color color: "#e6b35a"
  property color hotColor: "#ffe3a3"
  property color coverColor: "#15122b"
  property real columnWidth: 16
  property real glyphSize: 14
  property bool closing: false
  property real scrimOpacity: 1
  // the card's visual scale (for the mala ring); the veil never scales
  readonly property real scaleX: 1
  readonly property real scaleY: 1

  signal closeFinished()

  z: 50

  // The veil is reparented onto the card so it covers the
  // border too.
  function attach() {
    if (!fx.card) return false
    if (dec.parent !== fx.card) dec.parent = fx.card
    dec.target = fx.card
    return true
  }

  function detach() {}

  function reset() {
    scrimAnim.stop()
    dec.reset()
    fx.closing = false
    fx.scrimOpacity = 1
  }

  function playOpen() {
    reset()
    if (!fx.active || !attach()) return
    fx.scrimOpacity = 0
    scrimAnim.to = 1
    scrimAnim.duration = 180
    scrimAnim.start()
    dec.playIn()
  }

  // Returns false when there is nothing to animate (caller hides at once).
  function playClose() {
    if (!fx.active || !attach()) return false
    fx.closing = true
    scrimAnim.stop()
    scrimAnim.to = 0
    scrimAnim.duration = 220
    scrimAnim.start()
    dec.playOut(fx.finishClose)
    return true
  }

  function finishClose() {
    if (!fx.closing) return
    // Hide first, then drop `closing`, so focus/input never flick back on
    // a still-mapped surface. The veil stays over the card while
    // hidden (no stale full frame on remap); the next playOpen()/reset()
    // clears it.
    fx.closeFinished()
    fx.closing = false
  }

  NumberAnimation { id: scrimAnim; target: fx; property: "scrimOpacity" }

  LotusIris { id: dec; coverColor: fx.coverColor; rimA: fx.color; rimB: "#e7a1c4" }
}
