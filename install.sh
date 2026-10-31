#!/usr/bin/env bash
# omarchy-fractal installer: theme, bar/launcher plugins, hooks, fonts, helper, configs.
#
#   ./install.sh                 install (or update) and activate the fractal theme
#   ./install.sh --no-activate   install files only; don't switch theme / restart anything
#   ./install.sh --dry-run       print what would happen, change nothing
#   ./install.sh --no-looknfeel  leave ~/.config/hypr/looknfeel.lua alone
#   ./install.sh --no-autohide   keep the top bar always visible (bar.autoHide=false)
#   ./install.sh --uninstall     undo the most recent install from its backup
#
# Everything is written under $HOME only (never /usr/share/omarchy, never sudo).
# Each install that changes something records a backup + manifest in
# ~/.cache/omarchy-fractal-backup/<timestamp>/ so --uninstall can put things back.
# Re-running is safe: files that are already identical are skipped.
# GTK css, branding and the screensaver override are NOT installed here: the
# fractal-shell hook switches them on with the theme and restores them on any
# other theme, from its own record in ~/.local/state/omarchy/fractal/.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="$HOME/.cache/omarchy-fractal-backup"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BACKUP_ROOT/$STAMP"
MANIFEST="$BACKUP/manifest"
THEME_FILE="$HOME/.local/state/omarchy/current/theme.name"
STATE="$HOME/.local/state/omarchy/fractal"
SHELL_HOOK="$HOME/.config/omarchy/hooks/theme-set.d/fractal-shell"
AURA="$HOME/.config/omarchy/themes/fractal/aura/fractal-aura"

DRY=0 ACTIVATE=1 LOOKNFEEL=1 AUTOHIDE=1 MODE=install
for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) DRY=1 ;;
    --no-activate) ACTIVATE=0 ;;
    --no-looknfeel) LOOKNFEEL=0 ;;
    --no-autohide) AUTOHIDE=0 ;;
    --uninstall) MODE=uninstall ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg (see --help)" >&2; exit 2 ;;
  esac
done

if [[ -t 1 ]]; then G=$'\e[32m' Y=$'\e[33m' R=$'\e[31m' N=$'\e[0m'; else G='' Y='' R='' N=''; fi
say()  { printf '%s==>%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s!!%s  %s\n' "$Y" "$N" "$*" >&2; }
die()  { printf '%sxx%s  %s\n' "$R" "$N" "$*" >&2; exit 1; }
run()  { if ((DRY)); then printf '    [dry-run] %s\n' "$*"; else "$@"; fi; }

[[ $EUID -ne 0 ]] || die "run as your normal user, not root"
[[ -n ${HOME:-} && -d $HOME ]] || die "\$HOME is not set"

guard() {
  case "$1" in
    "$HOME"/*) ;;
    *) die "refusing to write outside \$HOME: $1" ;;
  esac
  case "$1" in /usr/share/omarchy*) die "refusing to write to $1" ;; esac
}

rel() { printf '%s' "${1#"$HOME"/}"; }
current_theme() { cat "$THEME_FILE" 2>/dev/null || true; }

STARTED=0
start_backup() {
  ((STARTED)) && return 0
  STARTED=1
  ((DRY)) && return 0
  mkdir -p "$BACKUP"
  printf '# omarchy-fractal install %s from %s\n' "$STAMP" "$HERE" > "$MANIFEST"
}

# same <src> <dest>: true when dest already matches src (content + symlinks).
same() {
  [[ -e $2 || -L $2 ]] || return 1
  if [[ -L $2 && ! -L $1 && -f $1 ]]; then cmp -s "$1" "$2"; return; fi
  [[ -L $2 && ! -L $1 ]] && return 1
  diff -rq --no-dereference -x '*.bak*' -x '.bak-*' -x '*.canvas' -x '*-pre-*' "$1" "$2" >/dev/null 2>&1
}

# put <src> <dest>: back up whatever is at dest, then copy src there.
put() {
  local src="$1" dest="$2"
  guard "$dest"
  [[ -e $src || -L $src ]] || die "missing in repo: $src"
  if same "$src" "$dest"; then printf '    = %s\n' "$(rel "$dest")"; return 0; fi
  start_backup
  if [[ -e $dest || -L $dest ]]; then
    printf '    ~ %s%s\n' "$(rel "$dest")" "$([[ -L $dest ]] && echo " (was a symlink -> $(readlink "$dest"); replaced by a real file)")"
    if ((!DRY)); then
      mkdir -p "$BACKUP/files/$(dirname "$(rel "$dest")")"
      mv "$dest" "$BACKUP/files/$(rel "$dest")"
      printf 'R\t%s\n' "$(rel "$dest")" >> "$MANIFEST"
    fi
  else
    printf '    + %s\n' "$(rel "$dest")"
    mkparent "$dest"
    ((DRY)) || printf 'N\t%s\n' "$(rel "$dest")" >> "$MANIFEST"
  fi
  run cp -a "$src" "$dest"
}

# mkparent <dest>: create dest's parent dir, recording the top-most directory
# we had to create (D) so --uninstall can remove it again if left empty.
mkparent() {
  local dir top=""
  dir="$(dirname "$1")"
  while [[ ! -e $dir && $dir == "$HOME"/* ]]; do top="$dir"; dir="$(dirname "$dir")"; done
  [[ -z $top ]] && return 0
  ((DRY)) || printf 'D\t%s\n' "$(rel "$top")" >> "$MANIFEST"
  run mkdir -p "$(dirname "$1")"
}

# Put the desktop back to its pre-fractal state (shell.json switch, GTK css,
# branding, screensaver override) and stop the living wallpaper. Uses the
# hook's own record, so it is exact; harmless when nothing is recorded.
layers_off() {
  if [[ -x $SHELL_HOOK && -f $STATE/active ]]; then
    printf '    restoring the pre-fractal desktop layers from %s\n' "$(rel "$STATE")"
    run "$SHELL_HOOK" none
  fi
  if [[ -x $AURA ]]; then run "$AURA" stop >/dev/null 2>&1 || true; fi
}

# ---------------------------------------------------------------- uninstall
# Files this repo owns, removed by the fallback uninstall when there is no
# backup manifest (e.g. the files were put in place by hand).
owned_paths() {
  printf '%s\n' ".config/omarchy/themes/fractal"
  local p d h b
  for p in "$HERE"/plugins/*/; do p="${p%/}"; printf '.config/omarchy/plugins/%s\n' "$(basename "$p")"; done
  for d in "$HERE"/hooks/*/; do d="${d%/}"; for h in "$d"/*; do printf '.config/omarchy/hooks/%s/%s\n' "$(basename "$d")" "$(basename "$h")"; done; done
  for b in "$HERE"/bin/*; do printf '.local/bin/%s\n' "$(basename "$b")"; done
  printf '%s\n' ".local/share/fonts/fractal"
}

# Undo one install from its manifest (newest entry first).
restore_backup() {
  local dir="$1" kind path
  say "Restoring from $dir"
  tac "$dir/manifest" | while IFS=$'\t' read -r kind path; do
    [[ $kind == R || $kind == N || $kind == D ]] || continue
    [[ -n $path && $path != /* && $path != *..* ]] || { warn "skipping odd manifest entry: $path"; continue; }
    guard "$HOME/$path"
    if [[ $kind == D ]]; then
      # only directories we created, and only once they are empty again
      if ((!DRY)) && [[ -d $HOME/$path ]]; then find "$HOME/$path" -depth -type d -empty -exec rmdir {} \; 2>/dev/null; fi
      [[ -d $HOME/$path ]] || printf '    - %s/\n' "$path"
      continue
    fi
    run rm -rf "$HOME/$path"
    if [[ $kind == R ]]; then
      printf '    < %s\n' "$path"
      run mkdir -p "$(dirname "$HOME/$path")"
      run cp -a "$dir/files/$path" "$HOME/$path"
    else
      printf '    - %s\n' "$path"
    fi
  done
  ((DRY)) || mv "$dir" "$dir.uninstalled"
}

uninstall() {
  # every install that is not yet undone, newest first, so repeated installs
  # unwind back to the state before the very first one
  local cand backups=()
  for cand in "$BACKUP_ROOT"/*/; do
    cand="${cand%/}"
    [[ $cand == *.uninstalled || ! -f $cand/manifest ]] && continue
    backups=("$cand" "${backups[@]}")
  done
  say "Switching the fractal desktop layers off"
  layers_off
  local path
  if ((${#backups[@]})); then
    for cand in "${backups[@]}"; do restore_backup "$cand"; done
  else
    warn "no install backup in $BACKUP_ROOT: removing only the files this repo owns"
    while IFS= read -r path; do
      [[ -e $HOME/$path || -L $HOME/$path ]] || continue
      guard "$HOME/$path"
      printf '    - %s\n' "$path"
      run rm -rf "$HOME/$path"
    done < <(owned_paths)
    local cfg="$HOME/.config/omarchy/shell.json"
    if [[ -f $cfg ]] && command -v jq >/dev/null 2>&1; then
      printf '    ~ %s (fractal.* dropped from disabledPlugins)\n' "$(rel "$cfg")"
      if ((!DRY)); then
        local tmp; tmp="$(mktemp)"
        jq 'if (.disabledPlugins|type) == "array" then .disabledPlugins |= map(select(startswith("fractal.") | not)) else . end' "$cfg" > "$tmp" \
          && { if [[ -L $cfg ]]; then cat "$tmp" > "$cfg"; rm -f "$tmp"; else mv -f "$tmp" "$cfg"; fi; } || rm -f "$tmp"
      fi
    fi
  fi
  command -v fc-cache >/dev/null && run fc-cache -f >/dev/null 2>&1 || true
  if ((ACTIVATE)); then
    if [[ $(current_theme) == fractal ]]; then
      warn "fractal is still the active theme name; pick another with: omarchy-theme-set <name>"
    fi
    command -v omarchy-restart-shell >/dev/null && run omarchy-restart-shell || true
    command -v hyprctl >/dev/null && run hyprctl reload || true
  fi
  say "Uninstalled."
}

# ---------------------------------------------------------------- deps
check_deps() {
  local missing=0 c
  for c in hyprctl quickshell omarchy-shell omarchy-theme-set omarchy-restart-shell; do
    command -v "$c" >/dev/null 2>&1 || { warn "required command not found: $c"; missing=1; }
  done
  if ((missing)); then
    if ((ACTIVATE)) && ((!DRY)); then die "this needs an Omarchy install (Hyprland + omarchy-shell/Quickshell); use --no-activate to only copy files"; fi
    warn "continuing without activation checks"
  fi
  [[ -f $HOME/.config/hypr/hyprland.lua ]] || warn "$HOME/.config/hypr/hyprland.lua not found: the theme targets Omarchy's Lua Hyprland config (Hyprland >= 0.56)"
  command -v jq >/dev/null 2>&1 || warn "jq not found: shell.json can't be merged and the bar/launcher won't switch"
  command -v fc-cache >/dev/null 2>&1 || warn "fc-cache not found: run it yourself after install so Marcellus is picked up"
  return 0
}

# shell.json: keep the user's file; add the bar auto-hide settings and list the
# fractal.* plugins as disabled (the base state every other theme sees). The
# fractal-shell hook flips them on only while the theme is fractal.
install_shell_json() {
  local src="$HERE/config/omarchy/shell.json" dest="$HOME/.config/omarchy/shell.json"
  if ! command -v jq >/dev/null 2>&1; then
    warn "jq not found: add the entries of config/omarchy/shell.json to $dest yourself"
    return 0
  fi
  if [[ -f $dest ]] && ! jq -e . "$dest" >/dev/null 2>&1; then
    warn "$dest is not valid JSON: left alone"
    return 0
  fi
  local tmp; tmp="$(mktemp)"
  if [[ -f $dest ]]; then
    jq -s --argjson ah "$AUTOHIDE" '
      .[0] as $u | .[1] as $m
      | $u
      | .bar = (($u.bar // {}) * $m.bar)
      | .bar.autoHide = ($ah == 1)
      | .disabledPlugins = ((($u.disabledPlugins // []) + $m.disabledPlugins) | unique)
    ' "$dest" "$src" > "$tmp"
  else
    jq --argjson ah "$AUTOHIDE" '.bar.autoHide = ($ah == 1)' "$src" > "$tmp"
  fi
  ((AUTOHIDE)) || printf '    (--no-autohide: bar.autoHide = false)\n'
  if [[ -f $dest ]] && cmp -s "$tmp" "$dest"; then
    printf '    = %s\n' "$(rel "$dest")"
  else
    printf '    (merged bar auto-hide + fractal.* disabledPlugins into your shell.json)\n'
    put "$tmp" "$dest"
  fi
  rm -f "$tmp"
}

install_all() {
  check_deps
  ((DRY)) && say "Dry run: nothing will be changed"

  # If fractal is live, put the desktop layers back first so shell.json is
  # merged and backed up in its plain (non-fractal) state; re-applied below.
  local was=""
  [[ $(current_theme) == fractal ]] && was=fractal
  if [[ -f $STATE/active ]]; then say "Pausing the live fractal layers"; layers_off; fi

  say "Theme -> ~/.config/omarchy/themes/fractal"
  put "$HERE/theme" "$HOME/.config/omarchy/themes/fractal"

  say "Bar widgets + launcher plugins -> ~/.config/omarchy/plugins"
  local p
  for p in "$HERE"/plugins/*/; do p="${p%/}"; put "$p" "$HOME/.config/omarchy/plugins/$(basename "$p")"; done

  say "Hooks -> ~/.config/omarchy/hooks"
  local h d
  for d in "$HERE"/hooks/*/; do
    d="${d%/}"
    for h in "$d"/*; do put "$h" "$HOME/.config/omarchy/hooks/$(basename "$d")/$(basename "$h")"; done
  done

  say "Helper -> ~/.local/bin"
  local b
  for b in "$HERE"/bin/*; do
    put "$b" "$HOME/.local/bin/$(basename "$b")"
    run chmod +x "$HOME/.local/bin/$(basename "$b")"
  done
  case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) warn "$HOME/.local/bin is not on PATH; the fractal screensaver override won't be used" ;; esac

  say "Shell config (bar auto-hide, fractal.* plugins off by default)"
  install_shell_json

  if ((LOOKNFEEL)); then
    say "Hyprland look'n'feel (gaps) -> ~/.config/hypr/looknfeel.lua"
    put "$HERE/config/hypr/looknfeel.lua" "$HOME/.config/hypr/looknfeel.lua"
  fi

  say "Heading font (Marcellus, OFL) -> ~/.local/share/fonts/fractal"
  put "$HERE/fonts" "$HOME/.local/share/fonts/fractal"
  if command -v fc-cache >/dev/null 2>&1; then run fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || warn "fc-cache failed"; fi

  if ((STARTED)) && ((!DRY)); then say "Backup of replaced files: $BACKUP"; fi
  ((STARTED)) || say "Everything already up to date."

  if ((ACTIVATE)); then
    say "Activating"
    run omarchy-theme-set fractal
    run omarchy-restart-shell || warn "omarchy-restart-shell failed"
    run hyprctl reload || warn "hyprctl reload failed"
  elif [[ $was == fractal ]]; then
    say "fractal was live: re-applying its layers"
    [[ -x $SHELL_HOOK ]] && run "$SHELL_HOOK" fractal
    [[ -x $AURA ]] && run "$AURA" start
  else
    say "Not activated. Run: omarchy-theme-set fractal && omarchy-restart-shell"
  fi
}

if [[ $MODE == uninstall ]]; then uninstall; else install_all; fi
