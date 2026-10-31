# fractal.power

## Fractal FX

Cloned from omarchy.power and patched with the shared fractal panel effect:

- Icon press: a soft breath on the bar icon (opacity dips and returns).
- Open: an opaque indigo veil over the card parts like a lotus - an iris with
  eight swaying petal scallops and a saffron-to-pink rim opens from the bar
  side (fx/LotusIris.qml, 260 ms). At the same time a mantra-mala of beads
  pours round the card edge from a saffron guru bead (fx/PanelRing.qml +
  MalaRing.qml, the launcher's ring). The biggest labels breathe in letter by
  letter (fx/BreathText.qml).
- Close: the petals fold back over the card (220 ms) and the beads run home,
  then it hides.
- Live values render in candle white; static labels stay soft lavender.
- Shared code is in fx/ (FractalGate, LotusIris + iris.frag, MalaRing +
  mala.frag, PanelRing, PanelFx, BreathText, PetalBurst, Sacred.js).

Setting `fractalFx` in this widget's shell.json settings: "theme" (default,
only while the `fractal` theme is active), "always", or "off". On any other
theme the plugin behaves exactly like omarchy.power.
