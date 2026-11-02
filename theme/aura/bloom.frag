#version 440
// Window transitions (fractal theme): one family of soft edge rings that hug
// the window and follow its own animation.
// mode 0 open : a quiet scalloped line of light just inside the edge breathes
//               a few px outward and fades as the window settles in.
// mode 1 close: the reverse, the line settles inward onto the edge and fades.
// mode 2 float/fullscreen toggle: one soft ring of petals that hugs the window
//               edge while it travels, breathing outward and fading.
// prog follows the window's own bezier (set in Bloom.qml), life is linear time
// for the fade envelope; every line is at least ~1.1 px wide (antialiased).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float prog;     // 0..1 eased
    float life;     // 0..1 linear
    float mode;
    float seed;
    float pad;      // px between the item edge and the window edge
    vec2 res;
};
const float TAU = 6.28318530718;
vec3 pal(float h) {
    h = fract(h) * 4.0;
    vec3 S = vec3(0.93, 0.71, 0.38), P = vec3(0.92, 0.60, 0.76);
    vec3 V = vec3(0.64, 0.54, 0.94), T = vec3(0.42, 0.80, 0.80);
    if (h < 1.0) return mix(S, P, smoothstep(0.0, 1.0, h));
    if (h < 2.0) return mix(P, V, smoothstep(0.0, 1.0, h - 1.0));
    if (h < 3.0) return mix(V, T, smoothstep(0.0, 1.0, h - 2.0));
    return mix(T, S, smoothstep(0.0, 1.0, h - 3.0));
}
// soft line: gaussian core + faint halo; ww never thinner than a pixel
float softLine(float d, float ww) {
    return exp(-(d * d) / (ww * ww)) + 0.3 * exp(-abs(d) / (2.5 * ww));
}
float sdRoundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
void main() {
    vec2 px = qt_TexCoord0 * res;
    vec3 c = vec3(0.0);
    float v = 0.0;
    float env;
    if (mode > 1.5) {
        // ── toggle: petals along the window edge ──
        env = smoothstep(0.0, 0.22, life) * (1.0 - smoothstep(0.5, 1.0, life));
        vec2 q = px - res * 0.5;
        vec2 hs = max(res * 0.5 - vec2(pad), vec2(4.0));
        float d = sdRoundBox(q, hs, min(10.0, min(hs.x, hs.y)));     // px, 0 on the window edge
        float a = atan(q.y / hs.y, q.x / hs.x);                       // squarish angle
        float n = 2.0 * max(6.0, floor((hs.x + hs.y) / 70.0));        // petals, ~1 per 140 px
        float sc = pow(abs(cos(0.5 * n * a + seed * TAU)), 1.5);
        float edge = mix(-4.0, pad * 0.45, prog) + sc * (4.0 + 8.0 * prog);
        float ww = 1.3 + 1.4 * (1.0 - prog);
        float k = softLine(d - edge, ww) * 0.75
                + smoothstep(edge + ww, edge - ww, d) * smoothstep(-18.0, 0.0, d) * 0.10;
        c = mix(pal(0.25 + seed * 0.5), pal(0.0 + seed * 0.5), 0.5 + 0.5 * sin(a * 2.0 + seed * TAU)) * k;
        v = k;
    } else {
        // ── open / close: the toggle's soft edge ring, quieter ──
        // open : a thin scalloped line of light rises just inside the window
        //        edge and breathes a few px outward as it fades, following the
        //        window's popin 96% -> 100% (same curve, same clock).
        // close: the reverse, the line sits just outside the edge and settles
        //        inward onto the window as it shrinks to 97% and fades.
        bool closing = mode > 0.5;
        env = closing ? smoothstep(0.0, 0.18, life) * (1.0 - smoothstep(0.35, 1.0, life))
                      : smoothstep(0.0, 0.25, life) * (1.0 - smoothstep(0.45, 1.0, life));
        float sc0 = closing ? mix(1.0, 0.97, prog) : mix(0.96, 1.0, prog);   // Hyprland popin
        vec2 q = px - res * 0.5;
        vec2 hs = max(res * 0.5 - vec2(pad), vec2(4.0)) * sc0;
        float d = sdRoundBox(q, hs, min(10.0, min(hs.x, hs.y)));
        float a = atan(q.y / hs.y, q.x / hs.x);
        float n = 2.0 * max(6.0, floor((hs.x + hs.y) / 70.0));
        float sc = pow(abs(cos(0.5 * n * a + seed * TAU)), 1.5);
        float br = closing ? 1.0 - prog : prog;     // 0 at the edge .. 1 breathed out
        float edge = closing ? mix(pad * 0.28, -2.0, prog) + sc * (2.0 + 4.0 * br)
                             : mix(-3.0, pad * 0.35, prog) + sc * (2.0 + 4.0 * br);
        float ww = 1.1 + 0.6 * (1.0 - br);
        float k = softLine(d - edge, ww) * 0.55
                + smoothstep(edge + ww, edge - ww, d) * smoothstep(-12.0, 0.0, d) * 0.05;
        c = mix(pal(0.25 + seed * 0.5), pal(0.0 + seed * 0.5), 0.5 + 0.5 * sin(a * 2.0 + seed * TAU)) * k;
        v = k;
        env *= closing ? 0.5 : 0.6;                    // dimmer than the toggle
    }
    // feather to nothing at the item border: petals that reach past it fade
    // out instead of being clipped flat
    float dEdge = min(min(px.x, px.y), min(res.x - px.x, res.y - px.y));
    float feather = smoothstep(0.0, 6.0, dEdge);
    float a = clamp(v * env * 0.85 * feather, 0.0, 1.0);
    vec3 col = c * env * 0.85 * feather;
    fragColor = vec4(min(col, vec3(a)), a) * qt_Opacity;
}
