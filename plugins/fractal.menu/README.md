# fractal.menu

Cloned from omarchy.menu (the launcher; `omarchy.menu` is disabled and calls
are routed here via `omarchy.clonedFrom`).

## Fractal FX

- Open: a dim scrim fades in, then an indigo veil over the card parts like a
  lotus from the top centre (fx/MenuFx.qml + LotusIris.qml) while a
  mantra-mala of beads pours round the card (fx/MalaRing.qml).
- The header (prompt / typed filter) is set in Marcellus.
- Typing: the new character breathes in (fx/MenuBreath.qml).
- Selection: a soft shimmer on the row that gains the cursor.
- Close: the petals fold back and the beads run home.

Everything is visual only; keys are live at once. Setting `fractalFx`:
"theme" (default), "always", or "off".
