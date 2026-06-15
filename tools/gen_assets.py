#!/usr/bin/env python3
"""
Procedural pixel-art generator for "The Last Morning".
Produces the oblique (2.5D) house assets, the Stage 1 side-view kitchen,
memory props and FX. Run from the project root:  python3 tools/gen_assets.py
All art is authored at small base resolution and scaled up in-engine with
nearest-neighbour filtering, so it stays crisp pixel art.
"""
import os, math, numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def outdir(*p):
    d = os.path.join(ROOT, "assets", "art", *p)
    os.makedirs(d, exist_ok=True)
    return d

# ----------------------------------------------------------------------------
# tiny drawing helpers (numpy RGBA canvas)
# ----------------------------------------------------------------------------
def canvas(w, h):
    return np.zeros((h, w, 4), np.uint8)

def rgba(c):
    return (c[0], c[1], c[2], c[3] if len(c) > 3 else 255)

def px(a, x, y, c):
    h, w = a.shape[:2]
    if 0 <= x < w and 0 <= y < h:
        a[int(y), int(x)] = rgba(c)

def rect(a, x, y, w, h, c):
    H, W = a.shape[:2]
    c = rgba(c)
    x0, y0 = max(0, int(x)), max(0, int(y))
    x1, y1 = min(W, int(x + w)), min(H, int(y + h))
    if x1 > x0 and y1 > y0:
        a[y0:y1, x0:x1] = c

def outline_rect(a, x, y, w, h, c):
    rect(a, x, y, w, 1, c); rect(a, x, y + h - 1, w, 1, c)
    rect(a, x, y, 1, h, c); rect(a, x + w - 1, y, 1, h, c)

def ellipse_shadow(a, cx, cy, rx, ry, alpha=70):
    H, W = a.shape[:2]
    for y in range(int(cy - ry), int(cy + ry + 1)):
        for x in range(int(cx - rx), int(cx + rx + 1)):
            if 0 <= x < W and 0 <= y < H:
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    if a[y, x, 3] == 0:
                        a[y, x] = (8, 8, 14, alpha)

def save(a, *path):
    Image.fromarray(a, "RGBA").save(os.path.join(*path))

# Snap an asset to a chunkier pixel grid: downscale by f (nearest) so the
# smallest visible feature becomes ~f real pixels. Keeps it crisp + retro.
def pixelate(a, f):
    if f <= 1:
        return a
    H, W = a.shape[:2]
    img = Image.fromarray(a, "RGBA").resize((max(1, W // f), max(1, H // f)), Image.NEAREST)
    return np.array(img, np.uint8)

def grain(a, amt=10, seed=1, only_opaque=True):
    rng = np.random.default_rng(seed)
    H, W = a.shape[:2]
    n = rng.integers(-amt, amt + 1, (H, W))
    for ch in range(3):
        v = a[:, :, ch].astype(int) + n
        a[:, :, ch] = np.clip(v, 0, 255)
    if only_opaque:
        pass
    return a

def shade(c, f):
    return (max(0, min(255, int(c[0] * f))),
            max(0, min(255, int(c[1] * f))),
            max(0, min(255, int(c[2] * f))), c[3] if len(c) > 3 else 255)

# A generic oblique block: top face + front face + outline + base shadow.
# Returns a sprite whose visual "footprint" bottom sits near the canvas bottom.
def oblique_block(w, top_h, face_h, top_col, face_col, pad=3):
    a = canvas(w + pad * 2, top_h + face_h + pad * 2)
    ox = pad
    oy = pad
    ol = shade(top_col, 0.35)
    ellipse_shadow(a, a.shape[1] / 2, oy + top_h + face_h + 1, w / 2 + 1, 3)
    rect(a, ox, oy, w, top_h, top_col)                 # top surface
    rect(a, ox, oy + top_h, w, face_h, face_col)        # front face
    # subtle vertical light streak on top
    rect(a, ox + 1, oy + 1, max(1, w // 6), top_h - 2, shade(top_col, 1.15))
    outline_rect(a, ox, oy, w, top_h + face_h, ol)
    rect(a, ox, oy + top_h, w, 1, ol)                  # seam line
    return grain(a, 7, seed=w)

# ----------------------------------------------------------------------------
# FLOORS (tileable 32x32)
# ----------------------------------------------------------------------------
def floor_wood():
    a = canvas(32, 32)
    base = (122, 86, 56)
    rect(a, 0, 0, 32, 32, base)
    for i, y in enumerate([0, 8, 16, 24]):
        rect(a, 0, y, 32, 1, shade(base, 0.7))            # plank seam
        for x in range(0, 32, 2):                          # grain speckle
            if (x * 7 + y * 13) % 5 == 0:
                px(a, x, y + 3 + (i % 3), shade(base, 0.85))
        off = 16 if i % 2 else 0                            # staggered board ends
        rect(a, off, y, 1, 8, shade(base, 0.6))
    return grain(a, 10, seed=21)

def floor_tile():
    a = canvas(32, 32)
    c1, c2 = (206, 202, 190), (170, 166, 156)
    for ty in range(2):
        for tx in range(2):
            col = c1 if (tx + ty) % 2 == 0 else c2
            rect(a, tx * 16, ty * 16, 16, 16, col)
            outline_rect(a, tx * 16, ty * 16, 16, 16, shade(col, 0.8))
    return a

def floor_carpet():
    a = canvas(32, 32)
    base = (96, 84, 104)
    rect(a, 0, 0, 32, 32, base)
    for y in range(0, 32):
        for x in range(0, 32):
            if (x + y) % 4 == 0:
                px(a, x, y, shade(base, 1.08))
    return a

def rug_living():
    a = canvas(96, 64)
    base = (150, 70, 64)
    rect(a, 0, 0, 96, 64, base)
    outline_rect(a, 0, 0, 96, 64, shade(base, 0.6))
    outline_rect(a, 5, 5, 86, 54, (210, 190, 150))
    outline_rect(a, 9, 9, 78, 46, shade(base, 0.7))
    for x in range(14, 82, 8):
        rect(a, x, 26, 4, 12, (210, 190, 150))
    return a

# ----------------------------------------------------------------------------
# WALLS (oblique: a face you can see + a thin top cap)
# ----------------------------------------------------------------------------
def wall_face():
    # 32 wide, 48 tall. Top 4px = cap, then wallpaper, then baseboard.
    a = canvas(32, 48)
    cap = (60, 54, 60)
    paper = (120, 120, 132)
    rect(a, 0, 0, 32, 48, paper)
    rect(a, 0, 0, 32, 4, cap)                       # top cap
    rect(a, 0, 3, 32, 1, shade(cap, 0.6))
    for x in range(2, 32, 8):                        # chunky wallpaper stripes
        rect(a, x, 5, 2, 35, shade(paper, 1.1))
        rect(a, x + 4, 5, 2, 35, shade(paper, 0.9))
    a = grain(a, 9, seed=11)
    rect(a, 0, 40, 32, 8, (92, 80, 70))             # wood baseboard
    rect(a, 0, 40, 32, 1, shade((92, 80, 70), 1.2))
    rect(a, 0, 47, 32, 1, shade((92, 80, 70), 0.6))
    return a

def wall_window():
    a = canvas(48, 48)
    frame = (92, 80, 70)
    glass = (96, 116, 138)
    rect(a, 0, 0, 48, 48, frame)
    rect(a, 5, 5, 38, 30, glass)
    # rainy sky gradient
    for y in range(5, 35):
        f = 1.0 - (y - 5) / 40.0
        rect(a, 5, y, 38, 1, shade(glass, 0.8 + 0.35 * f))
    rect(a, 23, 5, 2, 30, frame)                    # mullion
    rect(a, 5, 19, 38, 2, frame)
    # rain streaks
    for x in range(8, 42, 5):
        rect(a, x, 7, 1, 26, shade(glass, 1.25))
    rect(a, 3, 35, 42, 6, shade(frame, 1.1))        # sill
    outline_rect(a, 0, 0, 48, 48, shade(frame, 0.6))
    return a

# ----------------------------------------------------------------------------
# FURNITURE (oblique)
# ----------------------------------------------------------------------------
def bed():
    a = canvas(64, 86)
    ellipse_shadow(a, 32, 82, 30, 4)
    frame = (110, 78, 52)
    rect(a, 4, 8, 56, 74, frame)
    outline_rect(a, 4, 8, 56, 74, shade(frame, 0.55))
    # pillow
    rect(a, 10, 12, 44, 16, (224, 220, 210))
    outline_rect(a, 10, 12, 44, 16, (180, 176, 168))
    # blanket
    quilt = (150, 96, 96)
    rect(a, 10, 30, 44, 48, quilt)
    outline_rect(a, 10, 30, 44, 48, shade(quilt, 0.6))
    for y in range(36, 78, 8):
        rect(a, 10, y, 44, 1, shade(quilt, 0.8))
    for x in range(18, 54, 10):
        rect(a, x, 30, 1, 48, shade(quilt, 0.8))
    return grain(a, 7, seed=99)

def couch():
    a = oblique_block(92, 14, 26, (110, 96, 120), (88, 76, 98))
    # cushions + arms drawn on top
    rect(a, 3 + 6, 3 + 2, 80, 8, (132, 116, 142))
    for x in range(3 + 6, 3 + 86, 26):
        rect(a, x, 3 + 2, 1, 10, shade((110, 96, 120), 0.7))
    rect(a, 3, 3, 8, 40, (96, 84, 108))             # left arm
    rect(a, 3 + 84, 3, 8, 40, (96, 84, 108))        # right arm
    outline_rect(a, 3, 3, 8, 40, shade((96, 84, 108), 0.6))
    outline_rect(a, 3 + 84, 3, 8, 40, shade((96, 84, 108), 0.6))
    return a

def armchair():
    a = oblique_block(40, 12, 22, (120, 104, 92), (96, 82, 72))
    rect(a, 3, 3, 7, 34, (104, 90, 80))             # arms
    rect(a, 3 + 33, 3, 7, 34, (104, 90, 80))
    rect(a, 3 + 8, 3 + 1, 24, 9, (140, 122, 110))   # seat back cushion
    return a

def coffee_table():
    return oblique_block(56, 8, 12, (140, 100, 64), (104, 72, 44))

def dining_table():
    a = oblique_block(80, 12, 16, (150, 104, 62), (112, 76, 44))
    rect(a, 3 + 4, 3 + 2, 72, 8, shade((150, 104, 62), 1.12))
    return a

def chair():
    a = canvas(24, 34)
    ellipse_shadow(a, 12, 31, 9, 2)
    wood = (138, 96, 58)
    rect(a, 5, 4, 14, 4, wood)                       # back top rail
    rect(a, 5, 4, 3, 16, wood); rect(a, 16, 4, 3, 16, wood)  # back posts
    rect(a, 4, 18, 16, 8, shade(wood, 1.05))         # seat (top)
    rect(a, 4, 26, 16, 4, shade(wood, 0.7))          # seat front face
    rect(a, 5, 30, 3, 4, shade(wood, 0.8)); rect(a, 16, 30, 3, 4, shade(wood, 0.8))  # front legs
    outline_rect(a, 4, 18, 16, 8, shade(wood, 0.5))
    return a

def stove():  # red oven from the user's reference
    a = canvas(48, 58)
    ellipse_shadow(a, 24, 55, 20, 3)
    body = (170, 30, 24)
    steel = (150, 150, 158)
    brown = (120, 84, 56)
    rect(a, 4, 4, 40, 50, body)
    outline_rect(a, 4, 4, 40, 50, (20, 16, 16))
    rect(a, 4, 4, 40, 8, brown)                      # back top trim
    rect(a, 6, 12, 36, 5, steel)                     # control strip
    rect(a, 8, 13, 5, 3, (40, 40, 46))               # knobs
    rect(a, 16, 13, 5, 3, (40, 40, 46))
    rect(a, 8, 20, 32, 28, shade(body, 0.78))        # oven door
    outline_rect(a, 8, 20, 32, 28, (20, 16, 16))
    rect(a, 12, 24, 24, 3, (40, 40, 46))             # handle
    rect(a, 6, 49, 36, 5, brown)                      # bottom trim
    return a

def fridge():
    a = canvas(36, 60)
    ellipse_shadow(a, 18, 57, 15, 3)
    body = (210, 208, 202)
    rect(a, 3, 3, 30, 52, body)
    outline_rect(a, 3, 3, 30, 52, shade(body, 0.6))
    rect(a, 3, 22, 30, 1, shade(body, 0.6))          # door split
    rect(a, 26, 8, 3, 10, shade(body, 0.55))         # handle upper
    rect(a, 26, 26, 3, 10, shade(body, 0.55))        # handle lower
    return a

def counter():
    a = oblique_block(72, 12, 18, (196, 192, 182), (120, 92, 64))
    rect(a, 3 + 2, 3 + 2, 68, 8, shade((196, 192, 182), 1.06))  # countertop
    for x in range(3 + 8, 3 + 64, 18):               # cabinet doors
        outline_rect(a, x, 3 + 13, 14, 14, shade((120, 92, 64), 0.7))
    return a

def sink_counter():
    a = counter()
    rect(a, 3 + 26, 3 + 2, 20, 8, (150, 150, 158))   # sink basin
    outline_rect(a, 3 + 26, 3 + 2, 20, 8, shade((150, 150, 158), 0.6))
    px(a, 3 + 36, 3, (120, 120, 128))
    return a

def nightstand():
    a = oblique_block(26, 8, 16, (140, 100, 64), (104, 72, 44))
    outline_rect(a, 3 + 4, 3 + 11, 18, 6, shade((104, 72, 44), 0.7))
    return a

def wardrobe():
    a = oblique_block(40, 8, 44, (118, 84, 56), (96, 66, 42))
    rect(a, 3 + 19, 3 + 10, 2, 38, shade((96, 66, 42), 0.6))   # door split
    rect(a, 3 + 14, 3 + 26, 3, 6, (60, 48, 36))                # handles
    rect(a, 3 + 23, 3 + 26, 3, 6, (60, 48, 36))
    return a

def bookshelf():
    a = oblique_block(40, 8, 50, (110, 78, 52), (88, 62, 42))
    cols = [(150, 70, 64), (90, 120, 110), (190, 160, 90), (110, 110, 150), (150, 120, 90)]
    for r in range(3):
        y = 3 + 12 + r * 13
        rect(a, 3 + 3, y + 9, 34, 2, shade((88, 62, 42), 0.7))  # shelf
        x = 3 + 4
        i = 0
        while x < 3 + 36:
            bw = 3 + (i % 3)
            rect(a, x, y, bw, 9, cols[(r + i) % len(cols)])
            x += bw + 1; i += 1
    return a

def record_player():
    a = oblique_block(38, 10, 12, (90, 72, 56), (70, 56, 44))
    rect(a, 3 + 6, 3 + 1, 26, 7, (40, 38, 44))       # platter
    px(a, 3 + 19, 3 + 4, (200, 180, 120))            # spindle
    rect(a, 3 + 28, 3 + 2, 6, 4, (150, 150, 158))    # tonearm base
    return a

def tv_stand():
    a = oblique_block(56, 10, 16, (96, 70, 50), (74, 54, 40))
    rect(a, 3 + 10, 3 - 14, 36, 22, (30, 30, 38))    # TV
    outline_rect(a, 3 + 10, 3 - 14, 36, 22, (12, 12, 16))
    rect(a, 3 + 13, 3 - 11, 30, 16, (60, 70, 86))
    return a

def plant():
    a = canvas(24, 36)
    ellipse_shadow(a, 12, 33, 8, 2)
    pot = (150, 92, 60)
    rect(a, 6, 24, 12, 9, pot)
    outline_rect(a, 6, 24, 12, 9, shade(pot, 0.6))
    leaf = (78, 120, 78)
    for (lx, ly, lh) in [(11, 6, 18), (7, 12, 12), (15, 12, 12), (4, 16, 8), (18, 16, 8)]:
        rect(a, lx, ly, 2, lh, leaf)
    rect(a, 9, 4, 6, 6, shade(leaf, 1.1))
    return a

# ----------------------------------------------------------------------------
# MEMORY PROPS  (small; each also gets a *_glow halo variant baked separately)
# ----------------------------------------------------------------------------
def prop_photo():
    a = canvas(22, 18)
    ellipse_shadow(a, 11, 16, 8, 2)
    rect(a, 2, 1, 18, 14, (224, 218, 204))           # frame
    outline_rect(a, 2, 1, 18, 14, (120, 100, 78))
    rect(a, 5, 4, 12, 9, (120, 140, 150))            # photo (two figures)
    rect(a, 8, 7, 2, 5, (60, 60, 70))
    rect(a, 12, 7, 2, 5, (60, 60, 70))
    return a

def prop_mug():
    a = canvas(18, 18)
    ellipse_shadow(a, 9, 16, 7, 2)
    c = (210, 205, 196)
    rect(a, 4, 5, 9, 10, c)
    outline_rect(a, 4, 5, 9, 10, shade(c, 0.6))
    rect(a, 13, 7, 3, 5, c); px(a, 15, 8, shade(c, 0.6))
    rect(a, 5, 6, 7, 2, (90, 64, 44))                # coffee ring
    return a

def prop_coat():
    a = canvas(22, 30)
    ellipse_shadow(a, 11, 28, 8, 2)
    c = (86, 96, 110)
    rect(a, 8, 2, 6, 3, (60, 48, 40))                # hook bar
    rect(a, 5, 5, 12, 20, c)                          # body
    rect(a, 2, 6, 4, 12, shade(c, 0.85))             # sleeves
    rect(a, 16, 6, 4, 12, shade(c, 0.85))
    outline_rect(a, 5, 5, 12, 20, shade(c, 0.6))
    rect(a, 10, 7, 2, 16, shade(c, 0.7))             # zipper
    return a

def prop_record():
    a = canvas(20, 20)
    ellipse_shadow(a, 10, 18, 8, 2)
    rect(a, 2, 2, 16, 16, (40, 38, 44))              # sleeve
    outline_rect(a, 2, 2, 16, 16, (20, 18, 22))
    for r, col in [(7, (30, 28, 34)), (4, (120, 90, 60)), (1, (200, 180, 120))]:
        for ang in range(0, 360, 12):
            x = 10 + r * math.cos(math.radians(ang))
            y = 10 + r * math.sin(math.radians(ang))
            px(a, x, y, col)
    return a

def prop_book():
    a = canvas(22, 16)
    ellipse_shadow(a, 11, 14, 8, 2)
    c = (150, 70, 64)
    rect(a, 2, 3, 18, 10, c)
    outline_rect(a, 2, 3, 18, 10, shade(c, 0.6))
    rect(a, 10, 3, 2, 10, shade(c, 0.7))             # spine
    rect(a, 3, 5, 6, 1, (210, 190, 150))             # title lines
    rect(a, 3, 7, 5, 1, (210, 190, 150))
    return a

def make_glow(size, col):
    a = canvas(size, size)
    cx = cy = size / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - cx, y - cy) / (size / 2)
            if d < 1:
                al = int(180 * (1 - d) ** 2)
                a[y, x] = (col[0], col[1], col[2], al)
    return a

# ----------------------------------------------------------------------------
# STAGE 1  side-view kitchen (a single elevation background + loose props)
# ----------------------------------------------------------------------------
def kitchen_sideview():
    # Authored at a deliberately small/chunky base (160x90), upscaled in-engine.
    W, H = 160, 90
    a = canvas(W, H)
    top = (190, 150, 108); bot = (150, 114, 82)
    for y in range(0, 60):
        f = y / 60
        col = tuple(int(top[i] * (1 - f) + bot[i] * f) for i in range(3)) + (255,)
        rect(a, 0, y, W, 1, col)
    # chunky wallpaper stripes (3px wide, 6px gap)
    for x in range(0, W, 6):
        rect(a, x, 0, 2, 60, (204, 168, 122, 70))
    # window
    rect(a, 18, 12, 34, 28, (118, 90, 62))
    rect(a, 21, 15, 28, 22, (170, 192, 192))
    for y in range(15, 37):
        rect(a, 21, y, 28, 1, shade((170, 192, 192), 1.08 - 0.012 * (y - 15)))
    rect(a, 34, 15, 2, 22, (118, 90, 62)); rect(a, 21, 25, 28, 2, (118, 90, 62))
    for x in range(23, 49, 4): rect(a, x, 16, 1, 20, (208, 220, 220))  # rain
    # floor
    floorY = 60
    rect(a, 0, floorY, W, H - floorY, (150, 104, 62))
    for x in range(0, W, 8): rect(a, x, floorY, 1, H - floorY, shade((150, 104, 62), 0.78))
    rect(a, 0, floorY, W, 2, shade((150, 104, 62), 0.55))
    # counter run on the right
    rect(a, 100, 40, 58, 4, (200, 196, 186))
    rect(a, 100, 44, 58, 16, (140, 100, 64)); outline_rect(a, 100, 44, 58, 16, shade((140, 100, 64), 0.6))
    for x in range(104, 154, 10): outline_rect(a, x, 47, 8, 11, shade((140, 100, 64), 0.7))
    # red stove
    rect(a, 136, 40, 18, 20, (170, 30, 24)); outline_rect(a, 136, 40, 18, 20, (22, 16, 16))
    rect(a, 139, 43, 12, 3, (150, 150, 158)); rect(a, 139, 48, 12, 10, shade((170, 30, 24), 0.78))
    a = grain(a, 8, seed=3)
    return a

# ----------------------------------------------------------------------------
# FX
# ----------------------------------------------------------------------------
def vignette():
    W, H = 256, 144
    a = canvas(W, H)
    cx, cy = W / 2, H / 2
    md = math.hypot(cx, cy)
    for y in range(H):
        for x in range(W):
            d = math.hypot(x - cx, y - cy) / md
            al = int(max(0, (d - 0.55)) / 0.45 * 235)
            a[y, x] = (4, 4, 10, min(235, al))
    return a

def rain_overlay():
    W, H = 256, 256
    a = canvas(W, H)
    rng = np.random.default_rng(7)
    for _ in range(140):
        x = rng.integers(0, W); y = rng.integers(0, H); L = rng.integers(6, 14)
        for i in range(L):
            px(a, x + i // 3, y + i, (200, 215, 230, 70))
    return a

def title_underline():
    a = canvas(160, 6)
    rect(a, 0, 2, 160, 2, (210, 190, 150, 200))
    return a

# ----------------------------------------------------------------------------
# BUILD
# ----------------------------------------------------------------------------
def main():
    h = outdir("house"); s1 = outdir("stage1"); fx = outdir("fx"); pr = outdir("props")
    save(floor_wood(), h, "floor_wood.png")
    save(floor_tile(), h, "floor_tile.png")
    save(floor_carpet(), h, "floor_carpet.png")
    save(rug_living(), h, "rug.png")
    save(wall_face(), h, "wall_face.png")
    save(wall_window(), h, "wall_window.png")
    for name, fn in {
        "bed": bed, "couch": couch, "armchair": armchair, "coffee_table": coffee_table,
        "dining_table": dining_table, "chair": chair, "stove": stove, "fridge": fridge,
        "counter": counter, "sink_counter": sink_counter, "nightstand": nightstand,
        "wardrobe": wardrobe, "bookshelf": bookshelf, "record_player": record_player,
        "tv_stand": tv_stand, "plant": plant,
    }.items():
        save(fn(), h, name + ".png")
    # props + glows
    props = {"photo": (prop_photo, (255, 214, 150)), "mug": (prop_mug, (255, 214, 150)),
             "coat": (prop_coat, (150, 200, 255)), "record": (prop_record, (255, 214, 150)),
             "book": (prop_book, (255, 214, 150))}
    for name, (fn, gcol) in props.items():
        save(fn(), pr, name + ".png")
    save(make_glow(64, (255, 220, 150)), fx, "glow_warm.png")
    save(make_glow(64, (150, 200, 255)), fx, "glow_cool.png")
    # stage 1
    save(kitchen_sideview(), s1, "kitchen_bg.png")
    save(chair(), s1, "chair.png")
    save(prop_mug(), s1, "cup.png")
    # plate
    pa = canvas(20, 8); ellipse_shadow(pa, 10, 7, 9, 2)
    rect(pa, 2, 2, 16, 4, (220, 216, 206)); outline_rect(pa, 2, 2, 16, 4, (170, 166, 156))
    save(pa, s1, "plate.png")
    # fx
    save(vignette(), fx, "vignette.png")
    save(rain_overlay(), fx, "rain.png")
    save(title_underline(), fx, "title_underline.png")
    print("Assets generated.")

if __name__ == "__main__":
    main()
