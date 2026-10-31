import QtQuick

// A label that breathes into place: the real characters rise a little and
// fade in one after another, left to right, each touched by a saffron glow
// as it lands (no stand-in glyphs, the text stays readable throughout). Laid
// out per character on the real font's advances, so the settled frame sits
// exactly where the real label is drawn. Only visible (and only ticking)
// while an animation is playing. Same API as the matrix ScrambleText.
Item {
  id: root

  property string text: ""
  property string fontFamily: "monospace"
  property real pixelSize: 12
  property bool bold: false
  property color color: "#e9dfcc"
  property color hotColor: "#ffe3a3"
  property string glyphFamily: ""          // kept for API compatibility
  property int renderType: Text.NativeRendering

  property var chars: []
  property var widths: []
  property var resolveAt: []
  property int frame: 0
  property int frames: 12
  readonly property bool running: ticker.running

  signal finished()

  implicitWidth: row.implicitWidth
  implicitHeight: metrics.height
  width: implicitWidth
  height: implicitHeight
  visible: running

  FontMetrics {
    id: metrics
    font.family: root.fontFamily
    font.pixelSize: Math.max(1, root.pixelSize)
    font.bold: root.bold
  }

  // mode: "full"   every character breathes in, left to right
  //       "glitch" two or three characters dip and breathe back (a shimmer)
  function play(mode, duration) {
    var t = String(root.text)
    if (t.length === 0 || t.indexOf("\n") !== -1) return
    root.frames = Math.max(4, Math.round((duration || 360) / ticker.interval))
    var w = [], r = []
    var picks = {}
    if (mode === "glitch") {
      var n = Math.min(3, Math.max(1, Math.floor(t.length / 4)))
      for (var p = 0; p < n * 3 && Object.keys(picks).length < n; p++) {
        var k = Math.floor(Math.random() * t.length)
        if (t.charAt(k) !== " ") picks[k] = true
      }
    }
    for (var i = 0; i < t.length; i++) {
      w.push(metrics.advanceWidth(t.charAt(i)))
      if (mode === "glitch") {
        r.push(picks[i] ? Math.round(root.frames * (0.45 + Math.random() * 0.4)) : 0)
      } else {
        r.push(Math.min(root.frames - 2, Math.round(root.frames * 0.1 + (i / Math.max(1, t.length)) * root.frames * 0.7)))
      }
    }
    root.widths = w
    root.resolveAt = r
    root.frame = 0
    root.step()
    ticker.restart()
  }

  function stop() {
    ticker.stop()
  }

  // c: char, s: still waiting (faint, lowered), h: just landed (glowing)
  function step() {
    var t = String(root.text)
    var out = []
    for (var i = 0; i < root.widths.length; i++) {
      var real = t.charAt(i)
      var at = root.resolveAt[i] || 0
      if (real === " " || root.frame >= at) out.push({ c: real, s: false, h: at > 0 && root.frame - at < 3 })
      else out.push({ c: real, s: true, h: false })
    }
    root.chars = out
  }

  Timer {
    id: ticker
    interval: 33
    repeat: true
    onTriggered: {
      root.frame++
      if (root.frame > root.frames + 4) {
        ticker.stop()
        root.finished()
        return
      }
      root.step()
    }
  }

  Row {
    id: row
    anchors.centerIn: parent

    Repeater {
      model: root.running ? root.widths.length : 0

      Item {
        id: cellItem
        required property int index
        readonly property var cell: root.chars[index] || ({ c: "", s: false, h: false })
        width: root.widths[index] || 0
        height: metrics.height

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          y: cellItem.cell.s ? root.pixelSize * 0.35 : 0
          textFormat: Text.PlainText
          text: cellItem.cell.c
          font.family: root.fontFamily
          font.pixelSize: Math.max(1, root.pixelSize)
          font.bold: root.bold
          color: cellItem.cell.h ? root.hotColor : root.color
          opacity: cellItem.cell.s ? 0.08 : 1
          renderType: root.renderType
          Behavior on y { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
          Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutSine } }
          Behavior on color { ColorAnimation { duration: 160 } }
        }
      }
    }
  }
}
