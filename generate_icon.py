#!/usr/bin/env python3
"""Generate Sebastian app icon PNGs (light, dark, tinted) using only stdlib."""

import math, struct, zlib, os

W = H = 1024

# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

def clamp(v, lo, hi):
    return max(lo, min(hi, v))

def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + t * (c2[i] - c1[i])) for i in range(3))

# ------------------------------------------------------------------
# Gradient background
# ------------------------------------------------------------------

def make_gradient(c1, c2):
    """Diagonal gradient, returns bytearray (RGB, row-major)."""
    buf = bytearray(W * H * 3)
    for y in range(H):
        for x in range(W):
            t = clamp((x / (W - 1) + y / (H - 1)) / 2.0, 0.0, 1.0)
            r, g, b = lerp_color(c1, c2, t)
            idx = (y * W + x) * 3
            buf[idx] = r; buf[idx + 1] = g; buf[idx + 2] = b
    return buf

# ------------------------------------------------------------------
# S-shape SDF
# ------------------------------------------------------------------

# Centerline path for a capital "S" in a 1024x1024 canvas
S_PATH = [
    (665, 238),
    (600, 172),
    (512, 152),
    (425, 170),
    (360, 222),
    (332, 298),
    (348, 372),
    (408, 428),
    (512, 470),
    (615, 510),
    (676, 564),
    (694, 648),
    (665, 736),
    (598, 792),
    (512, 812),
    (422, 793),
    (360, 741),
    (345, 672),
]

S_RADIUS    = 62   # stroke half-width (thick & readable at all sizes)
AA_FEATHER  = 2.0  # antialiasing width in pixels


def _dist_sq_to_segment(px, py, ax, ay, bx, by):
    """Squared distance from (px, py) to segment (ax,ay)→(bx,by)."""
    dx = bx - ax; dy = by - ay
    len_sq = dx * dx + dy * dy
    if len_sq == 0:
        return (px - ax) ** 2 + (py - ay) ** 2
    t = clamp(((px - ax) * dx + (py - ay) * dy) / len_sq, 0.0, 1.0)
    nx = ax + t * dx; ny = ay + t * dy
    return (px - nx) ** 2 + (py - ny) ** 2


def dist_to_s(px, py):
    """Distance from (px,py) to the S path center-line."""
    min_d_sq = float('inf')
    for i in range(len(S_PATH) - 1):
        ax, ay = S_PATH[i]
        bx, by = S_PATH[i + 1]
        d_sq = _dist_sq_to_segment(px, py, ax, ay, bx, by)
        if d_sq < min_d_sq:
            min_d_sq = d_sq
    return math.sqrt(min_d_sq)


def draw_s(buf, color):
    """Paint the S stroke onto buf (RGB bytearray) with antialiasing."""
    r, g, b = color
    outer = S_RADIUS + AA_FEATHER
    outer_sq = outer * outer

    # Compute tight bounding box of S_PATH + radius to skip most pixels
    min_x = max(0, int(min(p[0] for p in S_PATH)) - int(outer) - 1)
    max_x = min(W, int(max(p[0] for p in S_PATH)) + int(outer) + 2)
    min_y = max(0, int(min(p[1] for p in S_PATH)) - int(outer) - 1)
    max_y = min(H, int(max(p[1] for p in S_PATH)) + int(outer) + 2)

    for y in range(min_y, max_y):
        for x in range(min_x, max_x):
            d = dist_to_s(x, y)
            if d >= outer:
                continue
            alpha = clamp(1.0 - (d - S_RADIUS) / AA_FEATHER, 0.0, 1.0)
            idx = (y * W + x) * 3
            if alpha >= 1.0:
                buf[idx] = r; buf[idx + 1] = g; buf[idx + 2] = b
            else:
                buf[idx]     = int(buf[idx]     * (1 - alpha) + r * alpha)
                buf[idx + 1] = int(buf[idx + 1] * (1 - alpha) + g * alpha)
                buf[idx + 2] = int(buf[idx + 2] * (1 - alpha) + b * alpha)

# ------------------------------------------------------------------
# PNG writer
# ------------------------------------------------------------------

def _chunk(name, data):
    crc = zlib.crc32(name + data) & 0xFFFFFFFF
    return struct.pack('>I', len(data)) + name + data + struct.pack('>I', crc)


def save_png(path, buf):
    ihdr = _chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0))
    raw = bytearray()
    row = W * 3
    for y in range(H):
        raw += b'\x00'
        raw += buf[y * row:(y + 1) * row]
    idat = _chunk(b'IDAT', zlib.compress(bytes(raw), 6))
    iend = _chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n' + ihdr + idat + iend)
    kb = os.path.getsize(path) // 1024
    print(f'  {os.path.basename(path)}  ({kb} KB)')

# ------------------------------------------------------------------
# Generate all three variants
# ------------------------------------------------------------------

OUT = 'Sebastianthebutler/Assets.xcassets/AppIcon.appiconset'

VARIANTS = [
    # (filename, bg_start, bg_end, letter_color)
    ('AppIcon.png',        '#3730A3', '#7E22CE', '#FFFFFF'),  # light: indigo→purple, white S
    ('AppIcon~dark.png',   '#1E1B4B', '#3B0764', '#FFFFFF'),  # dark:  deep navy→deep purple
    ('AppIcon~tinted.png', '#1F2937', '#374151', '#D1D5DB'),  # tinted: gray scale
]

print('Generating icons…')
for filename, c1_hex, c2_hex, letter_hex in VARIANTS:
    c1 = hex_to_rgb(c1_hex)
    c2 = hex_to_rgb(c2_hex)
    lc = hex_to_rgb(letter_hex)
    buf = make_gradient(c1, c2)
    draw_s(buf, lc)
    save_png(os.path.join(OUT, filename), buf)

print('Done!')
