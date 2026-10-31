#version 440
// Window transition (fractal theme): a lotus bloom over the window rect.
// mode 0 open : three rings of petals unfold from the centre, rotating
//               against each other, and dissolve outward as the window arrives.
// mode 1 close: the petals fold back inward into a single saffron spark.
// mode 2 float/fullscreen toggle: one soft ring of petals that hugs the window
//               edge while it travels, breathing outward and fading.
// prog follows the window's own bezier (set in Bloom.qml), life is linear time
// for the fade envelope; every line is at least ~1.3 px wide (antialiased).
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
float rose(vec2 p, float n, float R, float rot, float w, float aa) {
    float a = atan(p.y, p.x) + rot;
    float r = length(p);
    float edge = R * (0.55 + 0.45 * abs(cos(0.5 * n * a)));
    float ww = max(w, aa);
    return softLine(r - edge, ww) + smoothstep(edge + ww, edge - ww, r) * 0.16;
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
        // ── open / close: the lotus ──
        float m = 0.5 * min(res.x, res.y);
        vec2 p = (px - res * 0.5) / m;           // -1..1 on the short side
        float aa = 1.3 / m;                      // ~1.3 px in p units
        bool closing = mode > 0.5;
        float t = closing ? 1.0 - prog : prog;   // close runs backwards
        env = closing ? smoothstep(0.0, 0.15, life) * (1.0 - smoothstep(0.7, 1.0, life))
                      : smoothstep(0.0, 0.18, life) * (1.0 - smoothstep(0.5, 1.0, life));
        float w = 0.010 + 0.008 * (1.0 - t);
        float R = 0.15 + 1.05 * t;
        float rot = (1.0 - t) * 1.2 + seed;
        float k1 = rose(p, 6.0, R * 0.55, rot, w, aa);
        float k2 = rose(p, 8.0, R * 0.80, -rot * 1.3, w, aa);
        float k3 = rose(p, 12.0, R * 1.05, rot * 0.7, w, aa);
        c = pal(seed) * k1 + pal(seed + 0.25) * k2 + pal(seed + 0.5) * k3;
        v = k1 + k2 + k3;
        // a whisper of indigo veil that clears as the bloom opens / gathers as it closes
        float veil = (closing ? t : 1.0 - t) * 0.20 * smoothstep(1.4, 0.2, length(p));
        c += vec3(0.07, 0.05, 0.15) * veil; v += veil;
        c *= env; v *= env;
        // the spark at the centre when closing, with its own soft envelope
        if (closing) {
            float se = smoothstep(0.35, 0.8, life) * (1.0 - smoothstep(0.85, 1.0, life));
            float sp = exp(-length(p) / max(0.03 + 0.05 * (1.0 - life), aa)) * se;
            c += vec3(0.98, 0.82, 0.50) * sp * 1.5; v += sp;
        }
        env = 1.0;
    }
    // feather to nothing at the item border: petals that reach past it fade
    // out instead of being clipped flat
    float dEdge = min(min(px.x, px.y), min(res.x - px.x, res.y - px.y));
    float feather = smoothstep(0.0, mode > 1.5 ? 6.0 : max(pad, 8.0), dEdge);
    float a = clamp(v * env * 0.85 * feather, 0.0, 1.0);
    vec3 col = c * env * 0.85 * feather;
    fragColor = vec4(min(col, vec3(a)), a) * qt_Opacity;
}
