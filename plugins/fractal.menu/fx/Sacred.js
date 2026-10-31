.pragma library

// Fractal symbol pool (replaces the matrix theme's Glyphs.js, same API):
// soft sacred marks - lotus, sparkles, beads and circles. Characters in
// text are never replaced by noise: decode() shows the unrevealed part as a
// string of mala beads that brighten one by one.
var SET = "✦✧❀✿❁✾❋✺·∘◦○◌"
var BEADS = "·∘·•"

function hash(n) {
  var x = Math.sin(n * 12.9898 + 78.233) * 43758.5453
  return x - Math.floor(x)
}

// Deterministic symbol for a seed, so bindings stay stable between frames.
function at(n) {
  return SET.charAt(Math.floor(hash(n) * SET.length))
}

function random() {
  return SET.charAt(Math.floor(Math.random() * SET.length))
}

// Kept for API compatibility: no symbol needs a special font.
function isKata(c) {
  return false
}

// Mala decode: the first `reveal` fraction of `text` is real, the rest is a
// row of beads that shimmer softly with `tick`.
function decode(text, reveal, tick) {
  var t = String(text || "")
  if (reveal >= 1) return t
  var n = Math.max(0, Math.floor(t.length * reveal))
  var out = t.substring(0, n)
  for (var i = n; i < t.length; i++) {
    var c = t.charAt(i)
    out += (c === " ") ? " " : BEADS.charAt((i + (tick || 0)) % BEADS.length)
  }
  return out
}
