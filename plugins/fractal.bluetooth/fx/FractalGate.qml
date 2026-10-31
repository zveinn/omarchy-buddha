import QtQuick
import Quickshell
import Quickshell.Io

// True while the active Omarchy theme is "fractal". Reads
// ~/.local/state/omarchy/current/theme.name once and re-reads it whenever
// omarchy-theme-set rewrites it. No polling.
Item {
  id: gate
  visible: false

  property string themeName: ""
  readonly property bool active: themeName === "fractal"

  function refresh() { file.reload() }

  FileView {
    id: file
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: gate.themeName = String(file.text()).trim()
    onLoadFailed: gate.themeName = ""
  }
}
