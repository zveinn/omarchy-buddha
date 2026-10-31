#version 440
// Window transition (fractal theme): a lotus bloom over the window rect.
// mode 0 open : three rings of petals unfold from the centre, rotating
//               against each other, and dissolve outward as the window arrives.
// mode 1 close: the petals fold back inward into a single saffron spark.
// mode 2 float/fullscreen toggle: one soft ripple of petals.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float prog;     // 0..1
    float mode;
    float seed;
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
float rose(vec2 p, float n, float R, float rot, float w) {
    float a = atan(p.y, p.x) + rot;
    float r = length(p);
    float edge = R * (0.55 + 0.45 * abs(cos(0.5 * n * a)));
    float line = exp(-abs(r - edge) / w);
    float fill = smoothstep(edge + w, edge - w, r) * 0.18;
    return line + fill;
}
void main() {
    vec2 px = qt_TexCoord0 * res;
    float m = 0.5 * min(res.x, res.y);
    vec2 p = (px - res * 0.5) / m;           // -1..1 on the short side
    float t = (mode > 0.5 && mode < 1.5) ? 1.0 - prog : prog;   // close runs backwards
    float env = sin(3.14159 * clamp(prog, 0.0, 1.0));
    float w = 0.012 + 0.01 * (1.0 - t);
    float R = 0.15 + 1.05 * t;
    float rot = (1.0 - t) * 1.2 + seed;
    float v = 0.0;
    vec3 c = vec3(0.0);
    if (mode > 1.5) {
        float k = rose(p, 8.0, R, rot, w);
        c = pal(0.25 + seed) * k; v = k;
    } else {
        float k1 = rose(p, 6.0, R * 0.55, rot, w);
        float k2 = rose(p, 8.0, R * 0.80, -rot * 1.3, w);
        float k3 = rose(p, 12.0, R * 1.05, rot * 0.7, w);
        c = pal(seed) * k1 + pal(seed + 0.25) * k2 + pal(seed + 0.5) * k3;
        v = k1 + k2 + k3;
    }
    // the spark at the centre when closing
    if (mode > 0.5 && mode < 1.5) {
        float sp = exp(-length(p) / (0.03 + 0.05 * (1.0 - prog))) * smoothstep(0.4, 0.9, prog);
        c += vec3(0.98, 0.82, 0.50) * sp * 1.6; v += sp;
    }
    // a whisper of indigo veil that clears as the bloom opens
    float veil = (mode < 0.5 ? (1.0 - prog) : (mode < 1.5 ? prog : 0.0)) * 0.22 * smoothstep(1.4, 0.2, length(p));
    float a = clamp(v * env * 0.85 + veil * env, 0.0, 1.0);
    vec3 col = c * env * 0.85 + vec3(0.07, 0.05, 0.15) * veil * env;
    fragColor = vec4(min(col, vec3(a)), a) * qt_Opacity;
}
