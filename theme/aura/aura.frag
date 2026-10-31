#version 440
// Fractal aura behind the Buddha: a breathing mandala of sacred geometry.
//   - a scalloped 16-petal lotus ring
//   - 8 large petal outlines turning the other way
//   - a kaleidoscopic (KIFS) fractal filigree, 12-fold, folding with the breath
//   - a flower-of-life garland of 12 overlapping circles
//   - soft rays, two outer ripples and a golden nimbus behind the head
// Everything breathes on one 5 s in/out cycle; hue drifts slowly through
// saffron -> lotus pink -> violet -> teal. No flicker: every term is smooth in
// time. `time` arrives wrapped to [0, 240) s, and every period divides 240, so
// the wrap is seamless.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float unit;     // px per figure-canvas height
    float glow;     // overall aura strength (1 = normal)
    vec2 res;
    vec2 center;    // mandala centre, px
    vec2 head;      // nimbus centre, px
};

const float TAU = 6.2831853;
const vec3 SAFF = vec3(0.93, 0.71, 0.38);
const vec3 PINK = vec3(0.92, 0.60, 0.76);
const vec3 VIOL = vec3(0.60, 0.50, 0.92);
const vec3 TEAL = vec3(0.38, 0.80, 0.80);

vec3 pal(float x) {
    x = fract(x) * 4.0;
    float f = fract(x); f = f * f * (3.0 - 2.0 * f);
    if (x < 1.0) return mix(SAFF, PINK, f);
    if (x < 2.0) return mix(PINK, VIOL, f);
    if (x < 3.0) return mix(VIOL, TEAL, f);
    return mix(TEAL, SAFF, f);
}
mat2 rot(float a) { float c = cos(a), s = sin(a); return mat2(c, s, -s, c); }

void main() {
    vec2 px = qt_TexCoord0 * res;
    vec2 p = (px - center) / unit;
    float r = length(p);
    float a = atan(p.y, p.x);
    float t = time;
    float b = 0.5 - 0.5 * cos(TAU * t / 5.0);       // breath 0..1
    float s = 1.0 + 0.045 * b;
    float rs = r / s;
    float rot1 = TAU * t / 240.0;

    // night sky: deep indigo, a violet bloom around the figure
    float vg = length(vec2((px.x - res.x * 0.5) / res.y, (px.y - res.y * 0.5) / res.y));
    float vs = smoothstep(0.0, 0.95, vg);
    vec3 col = mix(vec3(0.071, 0.058, 0.150), vec3(0.030, 0.026, 0.070), vs);
    col += vec3(0.10, 0.06, 0.16) * exp(-r / 0.38) * (0.35 + 0.25 * b);

    // 1 scalloped lotus ring
    float d1 = abs(rs - 0.40 * (0.93 + 0.07 * abs(cos(8.0 * (a + rot1)))));
    float g1 = exp(-d1 * 160.0) * 0.9;

    // 2 big petals, counter-rotating
    float pet = pow(abs(cos(4.0 * (a - rot1 * 2.0))), 0.6);
    float g2 = exp(-abs(rs - 0.50 * (0.62 + 0.38 * pet)) * 190.0) * 0.55 * smoothstep(0.25, 0.33, rs);

    // 3 kaleidoscopic fractal filigree
    float sec = TAU / 12.0;
    float fa = abs(mod(a + rot1 * 0.5, sec) - 0.5 * sec);
    vec2 q = vec2(cos(fa), sin(fa)) * rs * 2.4;
    float acc = 0.0, sc = 1.0;
    mat2 R = rot(0.58 + 0.06 * sin(TAU * t / 60.0));
    for (int i = 0; i < 5; i++) {
        q = abs(q) - vec2(0.62, 0.20 + 0.03 * b);
        q = R * q;
        q *= 1.42; sc *= 1.42;
        acc += exp(-abs(q.y) / sc * 260.0) * 0.35;
    }
    float env = smoothstep(0.30, 0.40, rs) * (1.0 - smoothstep(0.52, 0.66, rs));
    float g3 = acc * env * 0.75;

    // 3b flower-of-life garland
    float fa2 = mod(a - rot1 * 1.5, sec) - 0.5 * sec;
    vec2 q2 = vec2(cos(fa2), sin(fa2)) * r;
    float RF = 0.64 * s;
    float gf = 0.0;
    for (int k = -1; k <= 1; k++) {
        float ck = float(k) * sec;
        float dd = abs(length(q2 - RF * vec2(cos(ck), sin(ck))) - 0.22);
        gf = max(gf, exp(-dd * 220.0));
    }
    g3 += gf * 0.45 * (0.75 + 0.25 * b);

    // 4 soft rays
    float g4 = pow(0.5 + 0.5 * cos(24.0 * a - rot1 * 3.0), 10.0) * exp(-rs * 2.2) * 0.18 * smoothstep(0.12, 0.3, rs);

    // 5 outer ripples
    float g5 = (exp(-abs(rs - 0.84) * 150.0) * 0.30 + exp(-abs(rs - 0.98) * 160.0) * 0.18) * (0.6 + 0.4 * b);

    // 6 nimbus behind the head
    float hd = length((px - head) / unit);
    float g6 = exp(-max(hd - 0.06, 0.0) / 0.05) * 0.45 * (0.7 + 0.3 * b) + exp(-abs(hd - 0.10 * s) * 200.0) * 0.35;

    float hue = rs * 0.9 - t / 80.0 + 0.05 * sin(a * 6.0 + TAU * t / 40.0);
    float inten = (0.55 + 0.45 * b) * glow;
    col += pal(hue) * g1 * inten * 0.75;
    col += pal(hue + 0.25) * g2 * inten * 0.7;
    col += pal(hue + 0.5) * g3 * inten * 0.6;
    col += pal(hue + 0.1) * g4 * glow;
    col += pal(hue + 0.6) * g5 * 0.7 * glow;
    col += SAFF * g6 * inten * 0.8;
    col = 1.0 - exp(-col * 1.4);                    // soft shoulder, never clips
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
