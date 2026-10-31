#version 440
// Workspace switch (fractal theme): a lotus mark opens at the centre of the
// screen and three concentric ripples run outward like a struck singing bowl.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float prog;     // 0..1
    float dir;      // +1 forward, -1 back: ripple twist direction
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
void main() {
    vec2 px = qt_TexCoord0 * res;
    vec2 p = (px - res * 0.5) / res.y;
    float r = length(p), a = atan(p.y, p.x);
    float env = sin(3.14159 * prog);
    vec3 c = vec3(0.0);
    float v = 0.0;
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float rr = (prog * 1.1 - fi * 0.12) * 0.75;
        if (rr <= 0.0) continue;
        float wob = 0.006 * sin(8.0 * a + dir * prog * 6.0 + fi);
        float k = exp(-abs(r - rr - wob) / (0.004 + 0.006 * prog)) * (1.0 - fi * 0.25);
        c += pal(seed + fi * 0.22 + r) * k; v += k;
    }
    // lotus mark: eight petals that open then fade
    float th = a + dir * (1.0 - prog) * 0.8;
    float Lp = 0.07 * smoothstep(0.0, 0.5, prog);
    float pet = Lp * pow(abs(cos(th * 4.0)), 0.8);
    float lotus = exp(-abs(r - pet) / 0.0035) + smoothstep(pet, pet * 0.4, r) * 0.25;
    float core = exp(-r / 0.008);
    c += vec3(0.92, 0.62, 0.78) * lotus + vec3(0.98, 0.84, 0.52) * core;
    v += lotus + core;
    float al = clamp(v * env * 0.8, 0.0, 0.9);
    fragColor = vec4(min(c * env * 0.8, vec3(al)), al) * qt_Opacity;
}
