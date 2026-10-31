import QtQuick

// A lotus opening from a point: eight petals unfold outward and fade, with a
// soft singing-bowl ripple behind them. Position the item's centre on the
// origin (it has zero size) and call play(). Same API as the matrix
// GlyphBurst.
Item {
  id: root

  property color color: "#e7a1c4"
  property color hotColor: "#ffe3a3"
  property string glyphFamily: ""      // kept for API compatibility
  property int count: 8
  property real radius: 34
  property real glyphSize: 11          // petal length scale
  property real progress: 0
  property int seed: 0
  readonly property bool running: anim.running

  width: 0
  height: 0
  visible: anim.running

  function play() {
    root.seed = Math.floor(Math.random() * 1000)
    anim.restart()
  }

  NumberAnimation {
    id: anim
    target: root
    property: "progress"
    from: 0
    to: 1
    duration: 420
    easing.type: Easing.OutCubic
  }

  Loader {
    active: root.visible
    sourceComponent: Item {
      // ripple
      Rectangle {
        readonly property real d: root.radius * 2 * (0.25 + 0.9 * root.progress)
        x: -d / 2; y: -d / 2; width: d; height: d; radius: d / 2
        color: "transparent"
        border.width: Math.max(1, 2.5 * (1 - root.progress))
        border.color: root.hotColor
        opacity: 0.55 * (1 - root.progress)
      }
      // petals
      Repeater {
        model: Math.max(3, root.count)
        Rectangle {
          required property int index
          readonly property real ang: (index / Math.max(3, root.count)) * 360 + (root.seed % 45)
          readonly property real len: root.glyphSize * (0.9 + 0.5 * root.progress)
          readonly property real dist: root.radius * 0.15 + root.radius * 0.55 * root.progress
          width: len * 0.5
          height: len
          radius: width / 2
          x: -width / 2
          y: -height - dist
          antialiasing: true
          color: index % 2 === 0 ? root.color : root.hotColor
          opacity: 0.85 * (1 - root.progress * root.progress)
          transform: Rotation { origin.x: width / 2; origin.y: height + dist; angle: ang }
        }
      }
      // heart
      Rectangle {
        readonly property real d: root.glyphSize * 0.7 * (1 - root.progress)
        x: -d / 2; y: -d / 2; width: d; height: d; radius: d / 2
        color: root.hotColor
        opacity: 1 - root.progress
      }
    }
  }
}
