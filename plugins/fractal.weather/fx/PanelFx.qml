import QtQuick

// Fractal open/close for any KeyboardPanel-based panel. Place it as the
// last child of the panel's keyCatcher.
//   open:  an opaque indigo veil over the whole card parts like a lotus from
//          the bar side (LotusIris.qml, 260 ms), eight petal scallops with a
//          saffron / lotus-pink rim of light, while a mantra-mala of beads
//          pours round the card from the guru bead (PanelRing/MalaRing).
//   close: the petals fold back over the card (220 ms) and the beads run
//          back into the guru bead, then the panel hides.
// Plain Items, never take input. Nothing ticks while idle.
Item {
  id: fx

  property var panel: null          // the Panel root (has controller, opened, bar)
  property bool active: false       // fxOn of the host
  property color color: "#e6b35a"
  property color hotColor: "#ffe3a3"
  property color coverColor: "#15122b"
  property real columnWidth: 18     // kept for API compatibility
  property real glyphSize: 15       // kept for API compatibility
  property int maxDecode: 3

  property bool closing: false
  property var card: null
  property var hideFn: null

  anchors.fill: parent
  z: 50

  // The veil is reparented onto the card itself so it covers the border
  // and padding as well as the content.
  function attach() {
    var c = fx.parent
    for (var i = 0; i < 6 && c; i++) {
      if (c.contentTopInset !== undefined) break
      c = c.parent
    }
    if (!c || c.contentTopInset === undefined) return false
    fx.card = c
    if (dec.parent !== c) dec.parent = c
    dec.target = c
    dec.cloak = fx.parent
    return true
  }

  function detach() {}

  function reset() {
    fx.closing = false
    fx.hideFn = null
    dec.reset()
    ringHost.reset()
  }

  function playOpen() {
    reset()
    if (!fx.active) return
    if (attach()) { dec.playIn(); ringHost.playOpen(fx.card) }
  }

  // Wraps the panel's own open. showFn() must show the controller.
  function open(showFn) {
    var resumed = fx.closing
    if (resumed) { fx.closing = false; fx.hideFn = null }
    var wasOpen = panel && panel.opened && !resumed
    showFn()
    if (!wasOpen) {
      if (fx.active) playOpen()
      else reset()
    } else if (resumed) {
      dec.reset()
      ringHost.resume()
    }
  }

  // Wraps the panel's own close. hideFn() must hide the controller.
  function close(hideFn) {
    if (fx.closing) return
    if (fx.active && panel && panel.opened && !panel.popoutSwitchClosing && attach()) {
      fx.closing = true
      fx.hideFn = hideFn
      dec.playOut(fx.finishClose)
      ringHost.playClose()
      return
    }
    dec.reset()
    ringHost.reset()
    hideFn()
  }

  function finishClose() {
    if (!fx.closing) return
    fx.closing = false
    var f = fx.hideFn
    fx.hideFn = null
    if (f) f()
    // The veil stays over the card while hidden on purpose (a layer
    // surface re-presents its last frame on remap); the next open() resets it.
  }

  // A soft breath on the clicked icon (dims and returns, ~240 ms).
  function flicker(item) {
    if (!fx.active || !item) return
    flick.stop()
    flick.target = item
    flick.start()
  }

  SequentialAnimation {
    id: flick
    property var target: null
    NumberAnimation { target: flick.target; property: "opacity"; to: 0.4; duration: 90; easing.type: Easing.OutSine }
    NumberAnimation { target: flick.target; property: "opacity"; to: 1; duration: 150; easing.type: Easing.InOutSine }
  }

  LotusIris { id: dec; coverColor: fx.coverColor; rimA: fx.color; rimB: "#e7a1c4" }

  // Mantra-mala border around the card (fx/PanelRing.qml + MalaRing.qml),
  // in step with the lotus iris.
  PanelRing { id: ringHost; active: fx.active }

  // ---- Label decode (no longer used on open; kept for callers): the biggest
  //      single-line labels get a BreathText overlay over a cover patch.
  function collectTexts(item, out, depth) {
    if (!item || depth > 40 || item === fx) return
    if (item.visible === false || item.opacity === 0) return
    var kids = item.children || []
    for (var i = 0; i < kids.length; i++) {
      var k = kids[i]
      if (!k || k === fx || k.visible === false) continue
      if (k.font !== undefined && k.text !== undefined && k.contentWidth !== undefined && k.lineCount !== undefined) {
        var t = String(k.text)
        if (t.length >= 2 && t.length <= 40 && t.indexOf("\n") === -1 && /[A-Za-z0-9]/.test(t)
            && k.lineCount === 1 && !k.truncated && k.font.pixelSize > 0 && k.textFormat !== Text.RichText) {
          var p = k.mapToItem(fx, 0, 0)
          if (p.y >= 0 && p.y < fx.height - 4 && p.x >= 0 && p.x < fx.width)
            out.push({ item: k, x: p.x, y: p.y })
        }
      }
      collectTexts(k, out, depth + 1)
    }
  }

  function decodeLabels() {
    if (!fx.active || !fx.parent) return
    var found = []
    collectTexts(fx.parent, found, 0)
    found.sort(function(a, b) { return b.item.font.pixelSize - a.item.font.pixelSize || a.y - b.y })
    for (var i = 0; i < Math.min(fx.maxDecode, found.length); i++) {
      var f = found[i], t = f.item
      var off = 0
      if (t.horizontalAlignment === Text.AlignHCenter) off = (t.width - t.contentWidth) / 2
      else if (t.horizontalAlignment === Text.AlignRight) off = t.width - t.contentWidth
      var o = decodeComp.createObject(fx, {
        x: f.x + off, y: f.y + (t.height - t.contentHeight) / 2,
        coverW: t.contentWidth, coverH: t.contentHeight
      })
      if (!o) continue
      o.sText.text = t.text
      o.sText.fontFamily = t.font.family
      o.sText.pixelSize = t.font.pixelSize
      o.sText.bold = t.font.bold
      o.sText.color = t.color
      o.sText.hotColor = fx.hotColor
      o.sText.renderType = t.renderType
      o.sText.play("full", i === 0 ? 440 : 400)
      if (!o.sText.running) o.destroy()
    }
  }

  Component {
    id: decodeComp
    Item {
      id: dItem
      property real coverW: 0
      property real coverH: 0
      property alias sText: st
      Rectangle {
        width: dItem.coverW; height: dItem.coverH
        y: (st.height - height) / 2
        color: fx.coverColor
        visible: st.running
      }
      BreathText {
        id: st
        onFinished: dItem.destroy()
      }
    }
  }
}
