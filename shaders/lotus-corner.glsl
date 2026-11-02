// Lotus corner ornament (fractal theme) -- the ONE source for every mala ring
// corner: windows (theme/aura/mala.frag) and the bar panels, tray popups and
// launcher (plugins/*/fx/mala.frag). shaders/build.sh splices this block into
// each of them and recompiles the .qsb files; edit it here, never in place.
//
// A side-view lotus that opens outward from the corner of the bead line:
// two layers of petals (deep rose/saffron behind, lotus pink in front, each
// shading from saffron gold at the root to pink with a candle-white blush at the
// tip), every petal traced by a fine gold outline, a soft inner glow, and a
// teal jewel (bindu) in a gold bezel at its heart. Gold filigree tendrils braid
// out of its base along the bead line, crossing at tiny pearls, and taper into
// the beads. Everything is evaluated in device pixels (pxs = px per device
// pixel), so edges stay crisp at any scale.
// Life: the petals slowly unfurl and the glow breathes (5 s); the outline has a
// slow gold shimmer. Focused rings (lit = 1) are fully open and bright; idle
// rings are calmer, a little closed and veiled in violet.
const vec3 LC_SAFFRON = vec3(0.902, 0.702, 0.353);
const vec3 LC_LOTUS   = vec3(0.906, 0.631, 0.769);
const vec3 LC_DEEP    = vec3(0.740, 0.420, 0.620);
const vec3 LC_CANDLE  = vec3(0.914, 0.875, 0.800);
const vec3 LC_GOLD    = vec3(0.985, 0.840, 0.530);
const vec3 LC_TEAL    = vec3(0.447, 0.776, 0.769);
const vec3 LC_IDLE    = vec3(0.420, 0.370, 0.680);

// petal along angle `ang`: x = signed distance (px, ~euclidean across it),
// y = 0 root .. 1 tip, z = -1..1 across the petal
vec3 lcPetal(vec2 q, float ang, float len, float wid) {
    float cs = cos(ang), sn = sin(ang);
    vec2 l = vec2(cs * q.x + sn * q.y, -sn * q.x + cs * q.y);
    float tc = clamp(l.x / len, 0.0, 1.0);
    float h = wid * len * pow(max(sin(3.14159265 * pow(tc, 0.85)), 0.0), 0.75) * (1.0 - 0.15 * tc);
    float sd = max(abs(l.y) - h, max(-l.x, l.x - len));
    return vec3(sd, tc, clamp(l.y / max(h, 1e-3), -1.0, 1.0));
}

// premultiplied "over": a petal with a ~1 px gold outline just inside its edge
void lcLayer(inout vec3 oc, inout float oa, vec3 P, vec3 fill, vec3 gold, float pxs) {
    float cover = clamp(0.5 - P.x / pxs, 0.0, 1.0);
    float line = clamp(1.0 - abs(P.x / pxs + 0.55) / 0.75, 0.0, 1.0);
    vec3 col = mix(fill, gold, line);
    oc = col * cover + oc * (1.0 - cover);
    oa = cover + oa * (1.0 - cover);
}

// p: px from the item centre; d: px outside the window; dc: px from the bead
// line; C: centre of the corner arcs; R: bead-line corner radius; r: window
// rounding; s/L/Lx/Ly/A: arc length along the bead line and its pieces;
// pxs: px per device pixel; guruR: guru-bead radius (tendrils stop short).
// Returns premultiplied rgba; gap (0..1) = how much beads/thread make way.
vec4 lotusCorner(vec2 p, vec2 px, vec2 res, float dc, vec2 C, float R, float band, float r,
                 float s, float L, float Lx, float Ly, float A, float pxs,
                 float lit, float bloom, float breath, float time, float pulse, float guruR,
                 out float gap) {
    gap = 0.0;
    if (bloom <= 0.001) return vec4(0.0);
    const float TAU_ = 6.28318530718;
    vec2 sp = vec2(p.x < 0.0 ? -1.0 : 1.0, p.y < 0.0 ? -1.0 : 1.0);
    vec2 n = sp * 0.70710678;
    vec2 B = sp * C + n * R;                        // corner of the bead line
    float ex = band + r - R * 0.70710678;           // room from B to the item edge
    float Lo = max(4.0, min(band * 1.15, ex * 1.25));
    vec2 lp = p - B;
    float u = dot(lp, n), v = dot(lp, vec2(-n.y, n.x));

    // arc length from this quadrant's corner (clockwise TR, BR, BL, TL)
    int k = sp.y < 0.0 ? (sp.x > 0.0 ? 0 : 3) : (sp.x > 0.0 ? 1 : 2);
    float sk = (k == 0) ? Lx + 0.5 * A
             : (k == 1) ? Lx + Ly + 1.5 * A
             : (k == 2) ? 2.0 * Lx + Ly + 2.5 * A
             :            2.0 * Lx + 2.0 * Ly + 3.5 * A;
    float ds = mod(s - sk + 0.5 * L, L) - 0.5 * L;
    float ads = abs(ds);
    bool horiz = (ds < 0.0) == (k == 0 || k == 2);
    float halfSeg = horiz ? 0.5 * (A + Lx) - (k == 0 || k == 3 ? guruR + 3.0 : 0.0) : 0.5 * (A + Ly);

    float lift = mix(0.55, 1.0, lit);
    float shimmer = 0.86 + 0.14 * sin(TAU_ * time / 7.0 + (u + ads) * 0.18);
    vec3 gold = LC_GOLD * mix(0.78, 1.0, lit) * shimmer + LC_CANDLE * 0.3 * pulse * lit;
    vec3 oc = vec3(0.0);
    float oa = 0.0;

    // filigree: two gold strands braiding out of the lotus along the bead line,
    // crossing at tiny pearls, tapering into the beads
    float s0 = Lo * 0.55;
    float s1 = min(s0 + band * 1.9 * bloom, halfSeg - band * 0.45);
    if (s1 > s0 + band * 0.6) {
        float span = s1 - s0;
        float t = (ads - s0) / span;
        if (t > -0.05 && t < 1.08) {
            float tt = clamp(t, 0.0, 1.0);
            float lam = span * 0.8;                  // a turn and a quarter
            float env = smoothstep(0.0, 0.18, tt) * pow(1.0 - tt, 0.8);
            float amp = band * 0.20 * env * (0.86 + 0.14 * breath);
            float ph = TAU_ * (ads - s0) / lam;
            float y = amp * sin(ph);
            float g = inversesqrt(1.0 + pow(amp * TAU_ / lam * cos(ph), 2.0));
            float w = mix(0.62, 0.32, tt);
            float inT = step(0.0, t) * step(t, 1.0);
            float fil = inT * max(clamp((w + 0.5 * pxs - abs(dc - y) * g) / pxs, 0.0, 1.0),
                                  clamp((w + 0.5 * pxs - abs(dc + y) * g) / pxs, 0.0, 1.0));
            float node = floor((ads - s0) / (lam * 0.5) + 0.5) * lam * 0.5;
            float prr = mix(0.8, 0.5, clamp(node / span, 0.0, 1.0));
            float pearl = (node > 0.5 && node < span + 0.5)
                ? clamp((prr + 0.5 * pxs - length(vec2(ads - s0 - node, dc))) / pxs, 0.0, 1.0) : 0.0;
            float fa = max(fil * 0.85, pearl * 0.9);
            vec3 pc = mix(gold, LC_CANDLE, 0.35 * pearl);
            oc = pc * fa;
            oa = fa;
        }
        gap = smoothstep(s1 + band * 0.9, s1 + band * 0.25, ads);
    } else {
        gap = smoothstep(Lo * 0.9 + 4.0, Lo * 0.6, ads);
    }

    float rho = length(lp);
    if (rho < Lo * 1.2 + 8.0) {
        float spread = mix(0.28, 1.0, bloom) * mix(0.86 + 0.03 * breath, 0.92 + 0.08 * breath, lit);
        float Ls = Lo * mix(0.55, 1.0, bloom) * (0.97 + 0.03 * breath);
        vec2 q = vec2(u + Ls * 0.15, v);            // roots just inside the bead line
        float sdU = 1e3;
        vec3 P;
        // back layer: outer and middle petals, deep rose over saffron
        for (int i = 0; i < 4; i++) {
            float sg = (i == 0 || i == 2) ? 1.0 : -1.0;
            bool outer = i < 2;
            P = lcPetal(q, sg * (outer ? 0.95 : 0.55) * spread, Ls * (outer ? 0.58 : 0.80), outer ? 0.30 : 0.29);
            vec3 f = mix(LC_SAFFRON * 0.86, LC_DEEP, smoothstep(0.0, 0.65, P.y));
            f *= 0.80 + 0.14 * (1.0 - abs(P.z));
            lcLayer(oc, oa, P, f, gold * 0.92, pxs);
            sdU = min(sdU, P.x);
        }
        // front layer: two side petals, then the tall centre petal
        for (int i = 0; i < 3; i++) {
            float ang = (i == 0 ? 0.30 : (i == 1 ? -0.30 : 0.0)) * spread;
            P = lcPetal(q, ang, Ls * (i == 2 ? 1.0 : 0.66), i == 2 ? 0.27 : 0.28);
            vec3 f = mix(LC_SAFFRON, LC_LOTUS, smoothstep(0.05, 0.7, P.y));
            f = mix(f, LC_CANDLE, 0.32 * smoothstep(0.72, 1.0, P.y));
            f *= 0.86 + 0.16 * (1.0 - abs(P.z));
            f += LC_CANDLE * 0.24 * (1.0 - P.y) * (1.0 - P.y) * (0.6 + 0.4 * breath) * lift;
            lcLayer(oc, oa, P, f, gold, pxs);
            sdU = min(sdU, P.x);
        }
        // bindu: a teal jewel in a gold bezel at the heart of the flower
        float jr = max(1.8, Ls * 0.15);
        vec2 jp = p - (B + n * (Ls * 0.10));
        float jd = length(jp);
        float jcov = clamp((jr + 0.5 * pxs - jd) / pxs, 0.0, 1.0);
        float bez = clamp(1.0 - abs(jd - (jr - 0.6)) / 0.7, 0.0, 1.0);
        vec3 gem = mix(LC_TEAL * 1.18, LC_TEAL * 0.42 + vec3(0.05, 0.03, 0.12),
                       smoothstep(0.0, jr * 1.2, length(jp + vec2(0.3) * jr)));
        gem *= 0.9 + 0.25 * breath * lift;
        float spec = clamp((max(0.55, 0.3 * jr) + 0.5 * pxs - length(jp + vec2(0.38) * jr)) / pxs, 0.0, 1.0);
        gem = mix(gem, vec3(1.0, 0.98, 0.94), 0.85 * spec);
        gem = mix(gem, gold, bez);
        oc = gem * jcov + oc * (1.0 - jcov);
        oa = jcov + oa * (1.0 - jcov);
        // breathing glow beneath the flower and around the jewel
        float glow = (exp(-max(sdU, 0.0) / 1.3) * (0.10 + 0.12 * breath) + exp(-jd / 2.0) * 0.12 * breath)
                   * mix(0.35, 1.0, lit) * bloom;
        vec3 gc = mix(LC_SAFFRON, LC_LOTUS, 0.4);
        oc += gc * glow * (1.0 - oa);
        oa += glow * (1.0 - oa);
    }

    // idle rings: calmer, veiled in violet
    oc = mix(oc, LC_IDLE * oa, 0.35 * (1.0 - lit));
    float k2 = mix(0.6, 1.0, lit) * clamp(min(min(px.x, px.y), min(res.x - px.x, res.y - px.y)) / 3.0, 0.0, 1.0);
    return vec4(oc, oa) * k2;
}
