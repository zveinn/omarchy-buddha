# stone.py: turn the gilded Buddha (buddha-figure-gold.png) into a carved,
# weathered stone statue with subtle hairline cracks, keeping the exact same
# silhouette/alpha so the aura and layout do not move. Deterministic (seeded).
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
rng = np.random.default_rng(108)
src = Image.open('buddha-figure-gold.png').convert('RGBA')
W, H = src.size
a = np.asarray(src).astype(np.float32) / 255
rgb, al = a[..., :3], a[..., 3]

def blur(x, r):
    im = Image.fromarray(np.clip(x * 255, 0, 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.GaussianBlur(r))).astype(np.float32) / 255

def fbm(oct=6, base=4, seed=0):
    r = np.random.default_rng(seed); out = np.zeros((H, W), np.float32); amp = 1; tot = 0
    for o in range(oct):
        n = base * 2 ** o
        g = r.random((n * H // W + 2, n + 2)).astype(np.float32)
        im = Image.fromarray((g * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)
        out += amp * np.asarray(im).astype(np.float32) / 255; tot += amp; amp *= 0.55
    return out / tot

# carving shading from the original luminance (gold is bright: flatten a bit)
L = rgb @ np.array([0.30, 0.55, 0.15], np.float32)
L = (L - 0.08) / 0.78
L = np.clip(L, 0, 1) ** 0.95
# ambient occlusion: deepen folds/crevices like dust-filled stone
ao = np.clip(L - blur(L, 6) + 0.5, 0, 1)
shade = np.clip(0.18 + 0.82 * L, 0, 1) * (0.78 + 0.44 * ao)

# stone albedo: warm grey sandstone, cool indigo in shadow, faint rose in lotus
lotus = np.clip((rgb[..., 2] - rgb[..., 1]) * 6, 0, 1)        # pink petals have B>G
lotus = blur(lotus, 2)
light = np.array([0.82, 0.77, 0.67], np.float32)
dark = np.array([0.20, 0.18, 0.24], np.float32)
rose = np.array([0.80, 0.68, 0.70], np.float32)
hi = (1 - lotus[..., None]) * light + lotus[..., None] * rose
s = shade[..., None]
col = dark * (1 - s) + hi * s

# texture: mottling, weathering stains, granite grain
yy0 = np.linspace(0, 1, H, dtype=np.float32)[:, None]
mott = fbm(6, 3, 1); stain = fbm(4, 2, 2); fine = fbm(3, 64, 3)
col *= (0.90 + 0.20 * mott)[..., None]
col *= (1 - 0.10 * np.clip((stain - 0.55) * 4, 0, 1))[..., None]
col += np.array([0.02, 0.015, -0.01]) * (stain[..., None] - 0.5)
grain = rng.normal(0, 1, (H, W)).astype(np.float32)
grain = 0.6 * grain + 0.4 * (blur((grain * 0.15 + 0.5), 0.8) - 0.5) / 0.15
col *= (1 + 0.035 * grain + 0.05 * (fine - 0.5))[..., None]
# weathering: grime gathers toward the base
col *= (1 - 0.10 * np.clip((yy0 - 0.45) * 1.8, 0, 1) * (0.6 + 0.8 * stain))[..., None]
# pits: tiny dark erosion spots
pits = (rng.random((H, W)) > 0.9980).astype(np.float32)
pits = blur(pits, 0.9) * 2.2
col *= (1 - 0.45 * np.clip(pits, 0, 1))[..., None]

# hairline cracks: branching random walks, drawn 3x and downsampled
S = 3
crack = Image.new('L', (W * S, H * S), 0); cd = ImageDraw.Draw(crack)
lit = Image.new('L', (W * S, H * S), 0); ld = ImageDraw.Draw(lit)
solid = al > 0.98
face = (330, 120, 530, 330)  # keep the face serene: no cracks start there
def ok(x, y):
    xi, yi = int(x), int(y)
    if not (0 <= xi < W and 0 <= yi < H) or not solid[yi, xi]: return False
    return not (face[0] < xi < face[2] and face[1] < yi < face[3])
def walk(x, y, ang, n, wdt, depth):
    pts = [(x, y)]
    for i in range(n):
        ang += rng.normal(0, 0.35)
        st = rng.uniform(2.5, 5.5)
        nx, ny = x + np.cos(ang) * st, y + np.sin(ang) * st
        if not ok(nx, ny): break
        x, y = nx, ny; pts.append((x, y))
        if depth < 2 and rng.random() < 0.06:
            walk(x, y, ang + rng.choice([-1, 1]) * rng.uniform(0.5, 1.1), int(n * 0.45), wdt * 0.7, depth + 1)
    if len(pts) > 2:
        P = [(px * S, py * S) for px, py in pts]
        cd.line(P, fill=int(255 * min(1, wdt)), width=max(1, round(wdt * S * 0.9)), joint='curve')
        ld.line([(px + S * 0.9, py + S * 0.9) for px, py in P], fill=90, width=max(1, round(wdt * S * 0.6)))
starts = 0; tries = 0
while starts < 16 and tries < 5000:
    tries += 1
    x, y = rng.uniform(0, W), rng.uniform(0, H)
    if not ok(x, y): continue
    walk(x, y, rng.uniform(0, 2 * np.pi), int(rng.uniform(25, 70)), rng.uniform(0.7, 1.15), 0)
    starts += 1
cr = np.asarray(crack.resize((W, H), Image.LANCZOS)).astype(np.float32) / 255
lt = np.asarray(lit.resize((W, H), Image.LANCZOS)).astype(np.float32) / 255
cr = np.clip(cr, 0, 1) * (0.55 + 0.45 * mott)      # cracks fade in and out
col = col * (1 - 0.55 * cr[..., None]) + 0.10 * lt[..., None] * (1 - cr[..., None])

# soft aura light catching the stone edges: saffron from above, lotus pink + teal
edge = np.clip(al - blur(al, 7), 0, 1) * 2.2
yy = np.linspace(0, 1, H, dtype=np.float32)[:, None]
xx = np.linspace(-1, 1, W, dtype=np.float32)[None, :]
saff = np.array([0.90, 0.70, 0.35]); pink = np.array([0.91, 0.63, 0.77]); teal = np.array([0.45, 0.78, 0.77])
tint = saff * (1 - yy)[..., None] + (pink * np.clip(-xx, 0, 1)[..., None] + teal * np.clip(xx, 0, 1)[..., None]) * yy[..., None]
col += 0.22 * (edge[..., None] * tint)
col += 0.05 * np.clip(1 - yy * 1.6, 0, 1)[..., None] * saff * s   # faint warm top light

# erosion: slightly chipped silhouette (tiny alpha bites only at the edge)
chip = fbm(3, 48, 5)
edge_zone = (al > 0.02) & (al < 0.999) | (blur(al, 1.5) < 0.97)
al2 = np.where(edge_zone, al * np.clip(1.6 - 1.4 * chip, 0.45, 1), al)

out = np.dstack([np.clip(col, 0, 1), np.clip(al2, 0, 1)])
Image.fromarray((out * 255 + 0.5).astype(np.uint8), 'RGBA').save('buddha-figure.png', optimize=True)
