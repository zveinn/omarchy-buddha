#version 440
// Mantra-mala window ring (fractal theme). Drawn only in the band OUTSIDE the
// window: a string of prayer beads on a silk thread. A light travels the
// string like a counted mantra (one turn per 6 s); the beads take their
// colour from an iridescent saffron -> lotus -> violet -> teal drift; a larger
// saffron "guru bead" sits at the top centre; small lotus flowers bloom at the
// corners of the focused window. On focus the beads pour out from the guru
// bead both ways and meet at the bottom (prog 0 -> 1).
// Inactive rings (lit = 0): dim violet beads that only breathe, no light.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;     // seconds, wrapped % 240 by QML
    float prog;     // intro 0..1
    float lit;      // 1 focused, 0 idle
    float band;     // ring thickness in px
    float radius;   // window corner rounding in px
    float seed;     // per-window phase
    vec2 res;       // item size (window + 2*band)
    vec4 m0; vec4 m1; vec4 m2; vec4 m3;   // windows stacked above (cut out)
};
const float TAU = 6.28318530718;
const float QT = 1.57079632679;

vec3 pal(float h) {
    h = fract(h) * 4.0;
    vec3 S = vec3(0.93, 0.71, 0.38), P = vec3(0.92, 0.60, 0.76);
    vec3 V = vec3(0.64, 0.54, 0.94), T = vec3(0.42, 0.80, 0.80);
    if (h < 1.0) return mix(S, P, smoothstep(0.0, 1.0, h));
    if (h < 2.0) return mix(P, V, smoothstep(0.0, 1.0, h - 1.0));
    if (h < 3.0) return mix(V, T, smoothstep(0.0, 1.0, h - 2.0));
    return mix(T, S, smoothstep(0.0, 1.0, h - 3.0));
}
bool inR(vec2 p, vec4 r) { return r.z > 0.0 && p.x >= r.x && p.y >= r.y && p.x < r.x + r.z && p.y < r.y + r.w; }

void main() {
    vec2 px = qt_TexCoord0 * res;
    if (inR(px, m0) || inR(px, m1) || inR(px, m2) || inR(px, m3)) { fragColor = vec4(0.0); return; }
    vec2 hs = res * 0.5 - band;                 // window half size
    vec2 p = px - res * 0.5;
    float r = clamp(radius, 0.0, min(hs.x, hs.y));
    vec2 q = abs(p) - hs + r;
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;   // >0 outside the window
    if (d < 0.0) { fragColor = vec4(0.0); return; }

    float mid = band * 0.5;
    float R = r + mid;
    vec2 C = hs - r;
    float Lx = 2.0 * C.x, Ly = 2.0 * C.y, A = R * QT, L = 2.0 * Lx + 2.0 * Ly + 4.0 * A;
    // arc length along the bead line, clockwise from the top-left
    float s;
    if (abs(p.x) <= C.x) s = p.y < 0.0 ? p.x + C.x : Lx + 2.0 * A + Ly + (C.x - p.x);
    else if (abs(p.y) <= C.y) s = p.x > 0.0 ? Lx + A + p.y + C.y : 2.0 * Lx + 3.0 * A + Ly + (C.y - p.y);
    else {
        vec2 o = p - sign(p) * C;
        float ang = atan(o.y, o.x);
        if (p.x > 0.0 && p.y < 0.0) s = Lx + A * (ang + QT) / QT;
        else if (p.x > 0.0)         s = Lx + A + Ly + A * ang / QT;
        else if (p.y > 0.0)         s = 2.0 * Lx + 2.0 * A + Ly + A * (ang - QT) / QT;
        else                        s = 2.0 * Lx + 3.0 * A + 2.0 * Ly + A * (ang + TAU * 0.5) / QT;
    }
    float sn = s / L;
    float dc = d - mid;                          // distance from the bead line

    float breath = 0.5 - 0.5 * cos(TAU * time / 5.0);
    // reveal: beads pour from the guru bead (top centre) both ways
    float g = (Lx * 0.5) / L;
    float sg = abs(fract(sn - g + 0.5) - 0.5);   // 0 at guru bead .. 0.5 at the bottom
    float vis = smoothstep(prog * 0.52 + 0.004, prog * 0.52 - 0.03, sg);

    // beads: count rounded to a multiple of 9 (a mala has 108)
    float spacing = mix(14.0, 12.0, lit);
    float N = max(18.0, floor(L / spacing / 9.0 + 0.5) * 9.0);
    float u = sn * N;
    float k = floor(u);
    float da = (fract(u) - 0.5) * L / N;
    bool marker = mod(k, 9.0) == 0.0;
    float br = (mix(1.7, 2.3, lit) + (marker ? 0.5 : 0.0)) * (0.9 + 0.12 * breath);
    float bd = length(vec2(da, dc));
    float bead = smoothstep(br + 0.8, br - 0.5, bd);
    float bshade = 0.75 + 0.45 * clamp(-(da + dc) / max(br, 0.1), -1.0, 1.0);   // tiny highlight

    // guru bead
    float gd = length(vec2(abs(fract(sn - g + 0.5) - 0.5) * L, dc));
    float gr = mix(2.6, 3.6, lit) * (0.92 + 0.1 * breath);
    float guru = smoothstep(gr + 0.8, gr - 0.5, gd);

    // silk thread
    float thread = smoothstep(0.9, 0.0, abs(dc)) * (1.0 - bead);

    // the counted mantra: a light travelling clockwise with a soft tail
    float pos = fract(time / 6.0 + seed);
    float behind = fract(pos - sn) * L;          // px behind the light
    float pulse = lit * (exp(-behind / 70.0) + 0.6 * exp(-abs(fract(sn - pos + 0.5) - 0.5) * L / 8.0));

    float hue = sn + time / 40.0 + seed;
    vec3 iri = pal(hue);
    vec3 idle = mix(vec3(0.38, 0.33, 0.64), iri, 0.22);
    vec3 col = mix(idle, iri, lit);

    float a = 0.0;
    vec3 c = vec3(0.0);
    // thread
    a += thread * mix(0.16, 0.26, lit);
    c += col * thread * mix(0.16, 0.26, lit);
    // beads
    float ba = bead * mix(0.42 + 0.14 * breath, 0.70 + 0.55 * pulse, lit);
    c += col * bshade * ba * (1.0 + 0.6 * pulse);
    a += ba;
    // guru bead in saffron
    float ga = guru * mix(0.55, 0.95, lit);
    c = mix(c, vec3(0.96, 0.76, 0.42) * (1.0 + 0.3 * lit * breath), ga);
    a = max(a, ga);
    // soft halo hugging the window when focused
    float halo = lit * exp(-d / 3.0) * (0.10 + 0.10 * breath + 0.20 * pulse);
    c += iri * halo;
    a += halo;

    // lotus flowers at the four corners of the focused window
    if (lit > 0.5) {
        float bloom = smoothstep(0.55, 1.0, prog);
        vec2 sp = sign(p);
        vec2 cc = sp * (C + vec2(R * 0.7071));   // corner of the bead line
        vec2 lp = ((p - cc) * sp) * mat2(0.7071, 0.7071, -0.7071, 0.7071);
        float rho = length(lp), th = atan(lp.y, lp.x);
        float Lp = band * 0.85 * bloom * (0.92 + 0.08 * breath);
        float petal = Lp * pow(abs(cos(th * 2.5)), 0.7) * step(abs(th), 2.2);
        float lotus = smoothstep(petal + 0.7, petal - 0.5, rho) * step(0.01, bloom);
        float core = smoothstep(1.9, 0.9, rho) * bloom;
        vec3 lc = mix(vec3(0.93, 0.62, 0.78), vec3(0.98, 0.86, 0.66), 1.0 - rho / max(Lp, 0.5));
        c = mix(c, lc, lotus * 0.9);
        c = mix(c, vec3(0.98, 0.84, 0.50), core);
        a = max(a, max(lotus * 0.9, core));
    }

    a = clamp(a * vis, 0.0, 1.0);
    c *= vis;
    fragColor = vec4(c, a) * qt_Opacity;
}
