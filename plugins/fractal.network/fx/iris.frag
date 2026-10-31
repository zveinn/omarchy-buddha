#version 440
// Lotus iris (fractal theme): an opaque indigo veil over a card that opens
// like a lotus from just above its top centre. The opening edge is scalloped
// into eight soft petals that sway slightly, with a saffron -> lotus-pink rim
// glow on the veil side and a faint warm halo inside. prog 0 = fully veiled,
// prog 1 = fully revealed (nothing drawn).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;     // seconds, wrapped by QML
    float prog;     // 0 veiled .. 1 open
    vec2 res;       // item size in px
    vec4 cover;     // veil colour
    vec4 rimA;      // rim colour (saffron)
    vec4 rimB;      // rim colour (lotus)
};
const float PI = 3.14159265359;

void main() {
    vec2 px = qt_TexCoord0 * res;
    vec2 o = vec2(res.x * 0.5, -res.y * 0.06);
    vec2 d = px - o;
    float r = length(d);
    float th = atan(d.x, d.y);                       // 0 straight down
    float maxD = length(vec2(res.x * 0.5, res.y * 1.06));
    float rim = clamp(min(res.x, res.y) * 0.06, 8.0, 26.0);
    float env = sin(PI * clamp(prog, 0.0, 1.0));     // 0 at both ends
    float amp = rim * 0.9 * env;
    // eight petals across the opening fan, swaying gently
    float sc = amp * (0.5 + 0.5 * cos(8.0 * th + 0.6 * sin(time * 1.3)));
    float R = mix(-rim * 2.0, maxD + rim * 3.0, prog);
    float e = r - (R - sc);                          // >0 still veiled
    float veil = smoothstep(-1.2, 1.2, e);

    float hue = 0.5 + 0.5 * sin(th * 2.0 + time * 0.9);
    vec3 rc = mix(rimA.rgb, rimB.rgb, hue);
    float glowOut = exp(-max(e, 0.0) / (rim * 0.55)) * env;   // on the veil
    float glowIn = exp(-max(-e, 0.0) / (rim * 0.35)) * env;   // inside the opening
    float line = smoothstep(2.4, 0.0, abs(e)) * env;

    // the veil itself: indigo with a faint radial deepening and the rim light
    vec3 vc = cover.rgb * (0.92 + 0.10 * smoothstep(maxD, 0.0, r));
    vc = mix(vc, rc, clamp(glowOut * 0.55 + line * 0.6, 0.0, 1.0));

    float aIn = clamp(glowIn * 0.32 + line * 0.5, 0.0, 1.0);
    vec3 c = mix(rc * aIn, vc, veil);
    float a = mix(aIn, 1.0, veil);
    fragColor = vec4(c, a) * qt_Opacity;
}
