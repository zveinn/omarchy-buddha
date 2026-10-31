import QtQuick

// Lotus iris in/out for a card (the fractal theme's panel and launcher
// open/close). An opaque indigo veil covers `target`; on open it parts like
// a lotus from just above the top centre with eight swaying petal scallops
// and a saffron / lotus-pink rim of light.
//   playIn()         : veil -> content (`duration`, OutSine).
//   playOut(fn, lead): the reverse (the petals close back over the card),
//                      then fn(); the veil is held while hidden so a remap
//                      never flashes stale content. `lead` ms calls fn that
//                      much earlier (for hosts that fade).
//   cloak            : optional content item made transparent while the
//                      veil is held; restored on reset()/playIn().
// Same API as the matrix theme's GlyphDecode. Never takes input; nothing
// ticks while idle.
Item {
  id: gd

  property Item target: null
  property int duration: 260
  property int outDuration: 220
  property real prog: 1
  property real time: 0
  property bool held: false
  property bool outgoing: false
  property var doneFn: null
  property Item cloak: null
  property color coverColor: "#15122b"
  property color rimA: "#e6b35a"
  property color rimB: "#e7a1c4"
  readonly property bool running: anim.running

  enabled: false
  visible: anim.running || held
  z: 100
  width: target ? target.width : (parent ? parent.width : 0)
  height: target ? target.height : (parent ? parent.height : 0)

  function place() {
    if (gd.target && gd.parent && gd.target !== gd.parent) {
      var p = gd.parent.mapFromItem(gd.target, 0, 0)
      gd.x = p.x
      gd.y = p.y
    } else {
      gd.x = 0
      gd.y = 0
    }
  }

  function reset() {
    anim.stop()
    lead.stop()
    gd.doneFn = null
    gd.outgoing = false
    gd.held = false
    gd.prog = 1
    if (gd.cloak && gd.cloak.opacity === 0) gd.cloak.opacity = 1
  }

  function playIn() {
    reset()
    place()
    gd.prog = 0
    anim.from = 0
    anim.to = 1
    anim.easing.type = Easing.OutSine
    anim.duration = gd.duration
    anim.start()
  }

  function playOut(fn, leadMs) {
    var from = (anim.running && !gd.outgoing) ? gd.prog : 1
    anim.stop()
    lead.stop()
    place()
    gd.held = false
    gd.outgoing = true
    gd.doneFn = fn || null
    gd.prog = from
    anim.from = from
    anim.to = 0
    anim.easing.type = Easing.InOutSine
    anim.duration = Math.max(1, Math.round(gd.outDuration * from))
    anim.start()
    if (leadMs > 0 && anim.duration > leadMs) {
      lead.interval = anim.duration - leadMs
      lead.start()
    }
  }

  function fire() {
    var f = gd.doneFn
    gd.doneFn = null
    if (f) f()
  }

  NumberAnimation {
    id: anim
    target: gd
    property: "prog"
    onFinished: {
      if (gd.outgoing) {
        gd.held = true
        if (gd.cloak) gd.cloak.opacity = 0
        gd.fire()
      } else {
        gd.held = false
      }
    }
  }
  Timer { id: lead; onTriggered: gd.fire() }

  FrameAnimation { running: anim.running; onTriggered: gd.time = (gd.time + frameTime) % 240 }

  ShaderEffect {
    anchors.fill: parent
    property real time: gd.time
    property real prog: gd.prog
    property vector2d res: Qt.vector2d(width, height)
    property color cover: gd.coverColor
    property color rimA: gd.rimA
    property color rimB: gd.rimB
    fragmentShader: Qt.resolvedUrl("iris.frag.qsb")
  }
}
