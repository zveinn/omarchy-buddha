import QtQuick

// Mala-ring host for a bar popup card. Creates one MalaRing as a
// SIBLING of the card (child of the popup window's content item, so it is
// not clipped by the card and sits just outside its edge), hides the card's
// stock border while the ring is active (same as the launcher: the ring
// replaces the border, widths kept so the layout does not move), and drives
// the ring in step with the panel's lotus iris in/out. Nothing ticks while
// the panel is closed (the ring's timer only runs while it is visible).
Item {
  id: host

  property bool active: false
  property Item card: null
  property bool hideBorder: true
  property int openDuration: 300
  property int closeDuration: 220
  property var ring: null
  property var cardWidths: null

  visible: false
  width: 0
  height: 0

  function bind(c) {
    if (c && host.card !== c) { host.card = c; host.cardWidths = null }
    if (host.card && host.cardWidths === null && host.card.borderSpec)
      host.cardWidths = host.card.borderSpec.widths
    return ensure()
  }

  function ensure() {
    if (!host.active || !host.card || !host.card.parent) { drop(); return null }
    if (host.ring && host.ring.parent !== host.card.parent) drop()
    if (!host.ring)
      host.ring = ringComp.createObject(host.card.parent, {
        target: host.card, band: 9, openDuration: host.openDuration, closeDuration: host.closeDuration
      })
    return host.ring
  }

  function drop() {
    if (host.ring) { host.ring.destroy(); host.ring = null }
  }

  function playOpen(c) { var r = bind(c); if (r) r.playOpen() }
  function playClose() { if (host.ring) host.ring.playClose() }
  function resume() { if (host.ring) host.ring.resume() }
  function reset() { if (host.ring) host.ring.reset() }

  onActiveChanged: if (!active) drop()
  Component.onDestruction: drop()

  Component { id: ringComp; MalaRing {} }

  Binding {
    target: host.card
    property: "borderSpec"
    when: host.active && host.hideBorder && !!host.card && !!host.cardWidths
    value: ({ color: "transparent", widths: host.cardWidths, gradient: { colors: [], angle: 0, enabled: false } })
    restoreMode: Binding.RestoreBindingOrValue
  }
}
