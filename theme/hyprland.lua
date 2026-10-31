-- ✿ FRACTAL ✿
-- Soft-cornered windows floating over a meditating Buddha whose fractal aura
-- breathes behind them. Hyprland draws no border: every window wears a
-- MANTRA MALA, a string of prayer beads in the gap around it, drawn by the
-- fractal-aura quickshell process (aura/Mala.qml). The focused window's beads
-- shimmer, a light travels them like a counted mantra and lotus flowers bloom
-- at its corners; the other windows' beads are dim violet and only breathe.
-- Windows bloom open out of unfolding lotus petals and fold back into a spark
-- when they close; switching workspace rings out like a singing bowl.

local HIDDEN = "rgba(00000000)"

hl.config({
  general = {
    border_size = 1,
    col = {
      active_border = HIDDEN,   -- the mala ring replaces it
      inactive_border = HIDDEN,
    },
  },

  group = {
    col = {
      border_active = HIDDEN,
      border_inactive = HIDDEN,
    },
    groupbar = {
      font_family = "Marcellus",
      text_color = "rgb(f2d58f)",
      text_color_inactive = "rgba(9188b5cc)",
      col = {
        active = "rgba(3a3163dd)",
        inactive = "rgba(15122bbb)",
      },
    },
  },

  decoration = {
    rounding = 10,
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    fullscreen_opacity = 1.0,

    blur = {
      enabled = true,
      size = 4,
      passes = 2,
      vibrancy = 0.25,
      noise = 0.01,
    },

    shadow = {
      enabled = true,
      range = 18,
      render_power = 3,
      color = "rgba(07051288)",
      color_inactive = "rgba(07051255)",
    },
  },
})

-- Curves: unhurried, like a breath. Nothing snaps, nothing bounces.
hl.curve("lotusOpen", { type = "bezier", points = { { 0.22, 1.0 }, { 0.36, 1.0 } } })   -- soft ease-out
hl.curve("lotusClose", { type = "bezier", points = { { 0.55, 0.0 }, { 0.75, 0.4 } } })  -- gentle ease-in
hl.curve("breath", { type = "bezier", points = { { 0.45, 0.0 }, { 0.25, 1.0 } } })      -- in-out
hl.curve("still", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })

-- Motion: ~200-300 ms everywhere (speed is in 100 ms units).
hl.animation({ leaf = "windows", enabled = true, speed = 2.6, bezier = "lotusOpen" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.8, bezier = "lotusOpen", style = "popin 88%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.4, bezier = "lotusClose", style = "popin 92%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.6, bezier = "breath" })
hl.animation({ leaf = "border", enabled = true, speed = 2, bezier = "still" })
hl.animation({ leaf = "borderangle", enabled = false })
hl.animation({ leaf = "fade", enabled = true, speed = 2.6, bezier = "breath" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 2.6, bezier = "lotusOpen" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 2.2, bezier = "lotusClose" })
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 2.6, bezier = "breath" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 3, bezier = "breath" })
hl.animation({ leaf = "layers", enabled = true, speed = 2.6, bezier = "lotusOpen" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 2.6, bezier = "lotusOpen", style = "popin 94%" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2.0, bezier = "lotusClose", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 2.4, bezier = "lotusOpen" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2.0, bezier = "lotusClose" })
-- Workspaces drift up through each other like incense smoke while the
-- singing-bowl ripple (aura/Bloom.qml) rings out from the centre.
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.8, bezier = "breath", style = "slidefadevert 6%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.6, bezier = "lotusOpen", style = "slidefadevert 10%" })

-- ─── SMART GAPS ─────────────────────────────────────────────────────────────
-- A lone tiled window, or a fullscreen one, fills the screen edge to edge with
-- no gaps (and wears no mala). Everything else gets padding (looknfeel.lua).
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0 })
hl.window_rule({ match = { float = false, workspace = "w[tv1]" }, border_size = 0, rounding = 0 })
hl.window_rule({ match = { float = false, workspace = "f[1]" }, border_size = 0, rounding = 0 })
hl.window_rule({ match = { fullscreen = true }, border_size = 0, rounding = 0 })

-- Solid windows: cancel Omarchy's default 0.985/0.96 opacity rule.
hl.window_rule({ match = { class = ".*" }, opacity = "1.0 override 1.0 override 1.0 override" })

-- ─── FX FEED ────────────────────────────────────────────────────────────────
-- Effects are signalled by appending a line to a file the fractal-aura process
-- watches (inotify): no process spawn per event. The file is truncated every
-- 400 lines.
local FX_FILE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/fractal-fx"
local fx_writes = 0
do local f = io.open(FX_FILE, "w"); if f then f:close() end end
function fractal_fx_send(line)
  fx_writes = fx_writes + 1
  local f = io.open(FX_FILE, fx_writes > 400 and "w" or "a")
  if fx_writes > 400 then fx_writes = 1 end
  if f then f:write(line, "\n"); f:close() end
end

-- ─── MANTRA MALA RINGS ──────────────────────────────────────────────────────
-- Every window on a visible workspace gets a ring, except on workspaces with a
-- fullscreen window; a lone tiled window gets none. One "ring list" line
-- carries them all, bottom-to-top in z-order:
--   addr x y w h floating active [mx my mw mh ...]   (entries split by ";")
-- the m-rects are floating windows stacked above a floating one (cut out).
-- Alongside: "cover <monitor> 0|1" pauses the aura shader while a window
-- covers (almost) the whole monitor, so nobody pays for an unseen wallpaper.
local last_key = nil
local last_cover = {}
local last_float = {}
local on_float_toggle = nil
local B = 12
local function update()
  local aw = hl.get_active_window()
  local aaddr = nil
  pcall(function()
    aaddr = tostring(aw.address)
    local fl = aw.floating and true or false
    local prev = last_float[aaddr]
    last_float[aaddr] = fl
    if prev ~= nil and prev ~= fl and on_float_toggle then on_float_toggle(aw) end
  end)
  local covers = {}
  local ok, line = pcall(function()
    local vis, mons = {}, {}
    for _, m in ipairs(hl.get_monitors()) do
      if m.active_workspace then
        vis[m.active_workspace.id] = true
        mons[#mons + 1] = { name = m.name, ws = m.active_workspace.id, x = m.x, y = m.y, w = m.width, h = m.height }
      end
      if m.special_workspace then vis[m.special_workspace.id] = true end
    end
    local wins, tiled, fs = {}, {}, {}
    for _, x in ipairs(hl.get_windows()) do
      if x.workspace and vis[x.workspace.id] and x.mapped ~= false and not x.hidden then
        local id = x.workspace.id
        wins[#wins + 1] = x
        if x.fullscreen and x.fullscreen ~= 0 then fs[id] = true end
        if not x.floating then tiled[id] = (tiled[id] or 0) + 1 end
      end
    end
    -- is each monitor's wallpaper hidden?
    for _, m in ipairs(mons) do
      local c = fs[m.ws] or tiled[m.ws] == 1
      if not c then
        for _, x in ipairs(wins) do
          if x.workspace.id == m.ws then
            local ix = math.max(0, math.min(x.at.x + x.size.x, m.x + m.w) - math.max(x.at.x, m.x))
            local iy = math.max(0, math.min(x.at.y + x.size.y, m.y + m.h) - math.max(x.at.y, m.y))
            if ix * iy >= 0.95 * m.w * m.h then c = true; break end
          end
        end
      end
      covers[m.name] = c and 1 or 0
    end
    local parts = {}
    for i, x in ipairs(wins) do
      local id = x.workspace.id
      if not fs[id] and (x.floating or (tiled[id] or 0) > 1) then
        local ad = tostring(x.address)
        local X, Y, W, H = x.at.x, x.at.y, x.size.x, x.size.y
        local e = string.format("%s %d %d %d %d %d %d", ad, X, Y, W, H, x.floating and 1 or 0, ad == aaddr and 1 or 0)
        if x.floating then
          local n = 0
          for j = i + 1, #wins do
            local o = wins[j]
            if n < 4 and o.floating and o.workspace.id == id then
              local ax, ay, ow, oh = o.at.x, o.at.y, o.size.x, o.size.y
              if ax < X + W + B and ax + ow > X - B and ay < Y + H + B and ay + oh > Y - B then
                e = e .. string.format(" %d %d %d %d", ax, ay, ow, oh); n = n + 1
              end
            end
          end
        end
        parts[#parts + 1] = e
      end
    end
    return table.concat(parts, ";")
  end)
  if not ok then line = "" end
  for name, c in pairs(covers) do
    if last_cover[name] ~= c then
      last_cover[name] = c
      fractal_fx_send(string.format("cover %s %d", name, c))
    end
  end
  if line == last_key then return end
  last_key = line
  fractal_fx_send("ring list " .. line)
end

-- Hyprland's own border stays invisible, also per window.
local function hide_border(w)
  -- build the dispatcher INSIDE the pcall: an expired window object throws
  -- while the selector argument is built
  pcall(function()
    hl.dispatch(hl.dsp.window.set_prop({ prop = "active_border_color", value = HIDDEN, window = w }))
  end)
end
for _, w in ipairs(hl.get_windows()) do hide_border(w) end

hl.on("window.active", function(w)
  -- on an empty workspace this fires with an expired window (or nil): only
  -- touch a border when there really is a live active window
  local aw = w and hl.get_active_window()
  if aw then hide_border(aw) end
  update()
end)
-- the fractal-aura process calls this on startup so rings and covers are resent
fractal_ring_resync = function() last_key = nil; last_cover = {} end
-- cheap in-compositor poll: only writes the feed when something changed
hl.timer(function() update() end, { timeout = 16, type = "repeat" })

-- ─── LOTUS TRANSITIONS ──────────────────────────────────────────────────────
-- Drawn by aura/Bloom.qml:
--   window open:      three rings of lotus petals unfold over the window
--   window close:     the petals fold back inward into a saffron spark
--   float/fullscreen: one soft ring of petals at the new geometry
--   workspace switch: a lotus mark and singing-bowl ripples from the centre
local function tfx(args) fractal_fx_send("trans " .. args) end
local function geo(w)
  local ok, g = pcall(function() return string.format("%d %d %d %d", w.at.x, w.at.y, w.size.x, w.size.y) end)
  return ok and g or nil
end

local last_ws = nil
hl.on("workspace.active", function(ws)
  local ok, id = pcall(function() return ws.id end)
  if not ok or type(id) ~= "number" or id <= 0 or id == last_ws then return end
  local prev = last_ws
  last_ws = id
  if prev == nil then return end
  tfx(string.format("workspace %d %d", id, id > prev and 1 or -1))
end)

hl.on("window.open", function(w)
  if not w then return end
  local ok, addr = pcall(function() return w.address end)
  if not ok then return end
  -- wait a beat so the window has its final size, then bloom it open
  hl.timer(function()
    for _, x in ipairs(hl.get_windows()) do
      if x.address == addr then
        local g = geo(x)
        if g then tfx("open " .. g) end
        return
      end
    end
  end, { timeout = 10, type = "oneshot" })
end)

local function rebloom(w)
  local g = geo(w)
  if g then tfx("toggle " .. g) end
end
hl.on("window.fullscreen", function(w) if w then rebloom(w) end end)
on_float_toggle = rebloom

hl.on("window.close", function(w)
  if not w then return end
  local g = geo(w)
  if g then tfx("close " .. g) end
end)
