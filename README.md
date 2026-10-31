# Omarchy · Fractal ✿

A calm, meditative desktop for [Omarchy](https://omarchy.org) (Hyprland 0.56 with the Lua config, and the Quickshell-based omarchy-shell). A weathered stone Buddha sits on a lotus in the middle of a slowly breathing fractal mandala. Windows wear strings of prayer beads, open like lotus flowers, and the bar, panels and launcher are glass in indigo night.

`theme/preview.png` and `theme/preview-unlock.png` are the previews shown in Omarchy's theme picker.

## Palette

| | | |
|---|---|---|
| indigo night | `#15122b` | backgrounds, glass |
| lotus pink | `#e7a1c4` | active / accent |
| saffron | `#e6b35a` | what is chosen, the guru bead, the nimbus |
| teal | `#72c6c4` | cool accents |
| candle white | `#e9dfcc` | text |

Soft and warm, never neon, and every text colour stays readable on the glass.

## Features

**The Buddha**
- A seated Buddha carved from weathered sandstone: warm grey stone with grain, mottling, fine hairline cracks (none across the face), small eroded pits and slightly chipped edges. The aura's saffron, lotus-pink and teal light catches the stone edges.
- He sits centred on the original painted lotus: pink petals on a gilded seat, untouched; only the figure is stone.

**Breathing fractal aura (live wallpaper)**
- A GPU-shader mandala behind him: a scalloped 16-petal lotus ring, 8 large petals turning the other way, a 12-fold kaleidoscopic fractal filigree that folds with the breath, a flower-of-life garland, soft rays, outer ripples and a golden nimbus behind his head.
- Everything breathes on one 5 s in/out cycle, and the hue drifts slowly through saffron, lotus, violet and teal. There is no flicker.
- It runs at 30 fps at half resolution and pauses while a window covers the screen or the screensaver is running.
- Two static fallbacks are in `theme/backgrounds/`: `1-buddha-aura.jpg` (inhale) and `2-buddha-exhale.jpg`.

**Mala window borders**
- Hyprland's own border is hidden. Every window gets a string of prayer beads on a silk thread in the gap outside it, never over content.
- On the focused window, a light travels the string like a counted mantra (one turn every 6 s), a larger saffron guru bead sits top centre, and small lotus flowers bloom at the corners. On focus, the beads pour out from the guru bead both ways and meet at the bottom.
- Inactive windows get dim violet beads that only breathe.

**Lotus transitions (about 200–300 ms)**
- Window open: three rings of petals unfold and dissolve outward as the window arrives. Close: the petals fold back into a saffron spark. Float or fullscreen toggle: a soft ring of petals hugs the window edge and travels with it from the old rect to the new one. The petals use the same bezier curves and timing as Hyprland's window animations (open 280 ms, close 240 ms, move 260 ms), run per rendered frame from a warm, pre-created pool, and fade in and out with antialiased lines.
- Workspace switch: a lotus mark opens at the centre of the screen and three ripples run outward like a struck singing bowl.
- Hyprland's own animations use soft ease-out/ease-in curves at 220–280 ms.

**Bar, panels and launcher**
- Restyled `fractal.*` versions of the omarchy-shell bar, clock, workspaces, tray, audio, network, bluetooth, power, monitor, weather, agents and the app launcher (`fractal.menu`). They use indigo glass, candle-white text, saffron selection and a saffron → lotus → violet → teal border gradient.
- Headings (the clock hero, launcher header, panel titles) are set in **Marcellus** (OFL, bundled). The terminal and body text keep Hurmit.
- The bar auto-hides (500 ms delay) as before. Use `--no-autohide` to keep it pinned.

**Screensaver**
- The same Buddha and breathing aura with no text, fading in over 1.2 s. The statue swells very slightly with each breath. Any key, click, scroll or real mouse move ends it.

**Branding and apps**
- `about.txt` / `screensaver.txt` lotus art, the unlock emblem, and indigo GTK 3/4 css.
- The terminal, btop, keyboard RGB and icon theme all follow the palette. Neovim ships stock **tokyonight-night**.

## Install

```bash
git clone <this repo> ~/code/omarchy-fractal
cd ~/code/omarchy-fractal
./install.sh            # install + activate
```

| flag | |
|---|---|
| `--dry-run` | print everything it would do and change nothing |
| `--no-activate` | copy files only; don't switch theme or restart anything |
| `--no-looknfeel` | leave `~/.config/hypr/looknfeel.lua` alone (it is replaced by default, and a symlink there becomes a real file; the original is backed up) |
| `--no-autohide` | `bar.autoHide = false` |
| `--uninstall` | undo every install, newest first, back to the state before the first one |

Everything goes under `$HOME` only. The installer never uses sudo and never touches `/usr/share/omarchy`.

| repo | installed to |
|---|---|
| `theme/` | `~/.config/omarchy/themes/fractal` |
| `plugins/fractal.*` | `~/.config/omarchy/plugins/` |
| `hooks/theme-set.d/fractal-{aura,shell}`, `hooks/post-boot.d/fractal-aura` | `~/.config/omarchy/hooks/` |
| `bin/fractal-aura-toggle` | `~/.local/bin/` |
| `fonts/` (Marcellus + OFL) | `~/.local/share/fonts/fractal` |
| `config/omarchy/shell.json` | merged into your `~/.config/omarchy/shell.json` (bar auto-hide, and `fractal.*` listed as disabled, which is the state every other theme sees) |
| `config/hypr/looknfeel.lua` | `~/.config/hypr/looknfeel.lua` (gaps) |

Every file the installer replaces is first moved to `~/.cache/omarchy-fractal-backup/<timestamp>/`, together with a manifest. It also records every directory it creates. Re-running is safe: identical files are skipped.

## How the layers switch

Only while the theme is `fractal`, the `fractal-shell` hook:
- records what is there now in `~/.local/state/omarchy/fractal/`
- switches `shell.json` to the fractal bar, widgets and launcher
- links the GTK css and branding
- points `~/.local/bin/omarchy-launch-screensaver` at the Buddha screensaver

The `fractal-aura` hooks start the wallpaper process. On **any other theme**, both hooks put back exactly what was recorded and stop every fractal process. The fractal hooks and processes do nothing unless the active theme is `fractal`.

`fractal-aura-toggle [on|off]` turns the live aura off, leaving the static stone Buddha, or back on. The choice survives reboots.

## Uninstall

```bash
./install.sh --uninstall
```

This switches the fractal layers off, restores every backed-up file in reverse order, removes what the installer added and the directories it created, then runs `fc-cache`, restarts the shell and reloads Hyprland. If fractal is still the active theme name, it tells you to pick another one with `omarchy-theme-set <name>`. If no backup exists (files placed by hand), it removes only the paths this repo owns and drops `fractal.*` from `disabledPlugins`.

## Rebuilding the art

`theme/src/` holds the source painting and the pipeline (Python 3 with Pillow and NumPy). Run it from `theme/src`:

```bash
python3 mask.py           # cut the figure out of buddha-src.jpg  -> buddha-figure-gold.png
python3 stone.py          # stone figure + cracks, original lotus -> buddha-figure.png
python3 render_assets.py  # backgrounds, previews, unlock emblem, aura/buddha.png
```

`stone.py` is seeded, so it produces the same result every time, and it keeps the exact silhouette, so the aura stays aligned.

## Known issues

- Plugins hot-reloaded while the shell is running can leave stale panel instances, with old styling and no Marcellus. `omarchy-restart-shell` fixes this, and the installer runs it on activate.
- `quickshell log` shows the same harmless warnings as stock omarchy-shell (qmlscanner "outside of the config folder", the portal, a duplicate `omarchy.bar` IpcHandler).
- Uninstalling restores the shell.json you had before the first install. Any shell.json edits made while fractal was installed are lost; they are kept in the backup directory.
- The live aura costs a little GPU on integrated graphics. Turn it off with `fractal-aura-toggle off` if needed.
