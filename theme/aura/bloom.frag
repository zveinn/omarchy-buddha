#version 440
// Window transitions (fractal theme): one family of soft edge rings that hug
// the window and follow its own animation.
// mode 0 open : a quiet scalloped line of light just inside the edge breathes
//               a few px outward and fades as the window surfaces and settles.
// mode 1 close: the reverse, the line settles inward onto the edge and fades
//               as the window sinks away.
// mode 3 workspace: the same scalloped line around each arriving window, with
//               a soft glow sweeping once around it, breathing out and fading.
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
    float dir;      // workspace: +1 forward, -1 back (sweep direction)
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
    // every ring lives within ~20 px of the window edge: skip the inside
    {
        vec2 h0 = max(res * 0.5 - vec2(pad), vec2(4.0));
        if (sdRoundBox(px - res * 0.5, h0, min(10.0, min(h0.x, h0.y))) < -24.0) {
            fragColor = vec4(0.0);
            return;
        }
    }
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
    } else if (mode > 2.5) {
        // ── workspace: a lotus ring breathes around the arriving window ──
        env = smoothstep(0.0, 0.28, life) * (1.0 - smoothstep(0.5, 1.0, life));
        vec2 q = px - res * 0.5;
        vec2 hs = max(res * 0.5 - vec2(pad), vec2(4.0));
        float d = sdRoundBox(q, hs, min(10.0, min(hs.x, hs.y)));
        float a = atan(q.y / hs.y, q.x / hs.x);
        float n = 2.0 * max(6.0, floor((hs.x + hs.y) / 70.0));
        float sc = pow(abs(cos(0.5 * n * a + seed * TAU)), 1.5);
        float edge = mix(-3.0, pad * 0.4, prog) + sc * (2.0 + 5.0 * prog);
        float ww = 1.2 + 0.8 * (1.0 - prog);
        // a glow sweeping once around the ring
        float sw = seed * TAU + dir * prog * TAU * 0.75;
        float da = mod(a - sw + 3.14159265, TAU) - 3.14159265;
        float glow = 0.45 + 0.55 * exp(-da * da / 0.9);
        float k = (softLine(d - edge, ww) * 0.6
                + smoothstep(edge + ww, edge - ww, d) * smoothstep(-12.0, 0.0, d) * 0.05) * glow;
        c = mix(pal(0.25 + seed * 0.5), pal(0.0 + seed * 0.5), 0.5 + 0.5 * sin(a * 2.0 + seed * TAU)) * k;
        v = k;
        env *= 0.6;
    } else {
        // ── open / close: the toggle's soft edge ring, quieter ──
        // open : a thin scalloped line of light rises just inside the window
        //        edge and breathes a few px outward as it fades (Bloom.qml
        //        moves the item with the window's slide).
        // close: the reverse, the line sits just outside the edge and settles
        //        inward onto the window as it sinks and fades.
        bool closing = mode > 0.5;
        env = closing ? smoothstep(0.0, 0.18, life) * (1.0 - smoothstep(0.35, 1.0, life))
                      : smoothstep(0.0, 0.25, life) * (1.0 - smoothstep(0.45, 1.0, life));
        vec2 q = px - res * 0.5;
        vec2 hs = max(res * 0.5 - vec2(pad), vec2(4.0));
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
