// ✿ FRACTAL ✿ living wallpaper, mantra-mala window rings and lotus transitions.
// One quickshell process (managed by ./fractal-aura):
//   * Aura   - the seated Buddha on an opaque Bottom layer, with a breathing
//              fractal mandala behind him (aura.frag, 30 fps, half resolution,
//              paused while a window covers the screen or the screensaver runs)
//   * Mala   - prayer-bead rings around every window (mala.frag)
//   * Bloom  - soft edge rings on window open/close, and on workspace switch
//              a lotus ring around each arriving window in turn (bloom.frag)
// Driven by the theme's hyprland.lua over $XDG_RUNTIME_DIR/fractal-fx.
// Everything is hidden (and the timers stop) unless the active theme is fractal.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
  id: shell
  property string themeName: "fractal"
  readonly property bool themeActive: themeName.trim() === "fractal"
  property var covered: ({})          // monitor name -> bool
  property bool saver: false          // screensaver is up: pause the aura

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: shell.themeName = text()
  }

  signal ringList(string list)
  // fx..fh: where the window comes from (toggle); equal to x..h otherwise
  signal transCmd(string cmd, int a, int x, int y, int w, int h, int fx, int fy, int fw, int fh)
  // workspace switch: rects = [x, y, w, h, ...] of its ringed windows, in order
  signal wsCmd(int id, int dir, string mon, var rects)

  // hyprland.lua (and the screensaver) append lines to this file:
  //   ring list <addr x y w h floating active [masks..]>;...
  //   trans open|close x y w h             trans workspace <id> <dir> <monitor> [x y w h ...]
  //   trans toggle x y w h [from-x from-y from-w from-h]
  //   cover <monitor> 0|1                  saver 0|1
  FileView {
    id: fxFeed
    property int done: -1
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/fractal-fx"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      const lines = text().split("\n")
      const n = lines.length - 1
      if (done < 0 || n < done) done = (done < 0 ? n : 0)
      for (let i = done; i < n; i++) {
        const line = lines[i].trim()
        const p = line.split(/\s+/)
        if (p[0] === "ring" && p[1] === "list") shell.ringList(line.slice(9).trim())
        else if (p[0] === "trans") {
          const v = p.slice(2).map(Number)
          if (p[1] === "workspace") shell.wsCmd(v[0], v[1] || 1, p[4] || "-", p.slice(5).map(Number))
          else if (v.length >= 8) shell.transCmd(p[1], 0, v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7])
          else shell.transCmd(p[1], 0, v[0], v[1], v[2], v[3], v[0], v[1], v[2], v[3])
        } else if (p[0] === "cover" && p.length >= 3) {
          const c = Object.assign({}, shell.covered); c[p[1]] = p[2] === "1"; shell.covered = c
        } else if (p[0] === "saver") shell.saver = p[1] === "1"
      }
      done = n
    }
  }
  IpcHandler {
    target: "fractal"
    function workspace(id: int): void { shell.wsCmd(id, 1, "-", []) }
    function open(x: int, y: int, w: int, h: int): void { shell.transCmd("open", 0, x, y, w, h, x, y, w, h) }
    function close(x: int, y: int, w: int, h: int): void { shell.transCmd("close", 0, x, y, w, h, x, y, w, h) }
    function saver(on: bool): void { shell.saver = on }
  }

  // ── the Buddha and his aura ─────────────────────────────────────────────
  Variants {
    model: Quickshell.screens
    Aura {
      visible: shell.themeActive
      paused: shell.saver || shell.covered[modelData.name] === true
    }
  }

  // ── lotus transitions (Overlay, click-through) ──────────────────────────
  Variants {
    model: Quickshell.screens
    Bloom {
      id: bloom
      visible: shell.themeActive
      Connections {
        target: shell
        function onTransCmd(cmd, a, x, y, w, h, fx, fy, fw, fh) {
          bloom.windowFx(cmd === "close" ? 1 : (cmd === "toggle" ? 2 : 0), x, y, w, h, fx, fy, fw, fh)
        }
        function onWsCmd(id, dir, mon, rects) { bloom.workspace(id, dir, mon, rects) }
      }
    }
  }

  // ── mantra-mala rings: tiled windows on Bottom, floating on Overlay ─────
  Variants {
    model: Quickshell.screens
    Mala {
      id: malaT
      floatLayer: false
      visible: shell.themeActive
      Connections {
        target: shell
        function onRingList(list) { malaT.setList(list) }
        function onWsCmd(id, dir, mon, rects) { malaT.arrive(dir, mon) }
      }
    }
  }
  Variants {
    model: Quickshell.screens
    Mala {
      id: malaF
      floatLayer: true
      visible: shell.themeActive
      Connections {
        target: shell
        function onRingList(list) { malaF.setList(list) }
        function onWsCmd(id, dir, mon, rects) { malaF.arrive(dir, mon) }
      }
    }
  }
}
