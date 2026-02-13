#!/usr/bin/env python3
"""
Generate NEON SYNTHWAVE / CYBERPUNK art assets for the 2D co-op shooter.
All sprites are created programmatically with PIL.
Theme: Tron, Hotline Miami, neon lights on dark backgrounds, retrowave aesthetics.
"""

import math
import random
import os
from PIL import Image, ImageDraw, ImageFilter

# ── Output paths ──────────────────────────────────────────────────────────────
GAME_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "game")
SPRITES_DIR = os.path.join(GAME_DIR, "assets", "sprites")
ENEMIES_DIR = os.path.join(SPRITES_DIR, "enemies")
BG_DIR = os.path.join(GAME_DIR, "assets", "backgrounds")
TILES_DIR = os.path.join(GAME_DIR, "assets", "tiles")

os.makedirs(SPRITES_DIR, exist_ok=True)
os.makedirs(ENEMIES_DIR, exist_ok=True)
os.makedirs(BG_DIR, exist_ok=True)
os.makedirs(TILES_DIR, exist_ok=True)

# ── Color palette ─────────────────────────────────────────────────────────────
HOT_PINK = (255, 20, 147)
ELECTRIC_CYAN = (0, 255, 255)
LASER_GREEN = (57, 255, 20)
NEON_PURPLE = (180, 0, 255)
NEON_RED = (255, 30, 60)
NEON_ORANGE = (255, 140, 0)
NEON_WHITE = (230, 230, 255)
DEEP_PURPLE = (20, 5, 40)
DARK_BG = (8, 2, 18)
NEON_YELLOW = (255, 255, 0)


def make_neon_glow(img, radius=3):
    """Create a neon glow effect by compositing a blurred copy underneath."""
    glow = img.copy()
    glow = glow.filter(ImageFilter.GaussianBlur(radius=radius))
    # Boost glow brightness
    from PIL import ImageEnhance
    enhancer = ImageEnhance.Brightness(glow)
    glow = enhancer.enhance(1.5)
    return Image.alpha_composite(glow, img)


def draw_neon_rect(draw, bbox, color, width=2):
    """Draw a neon rectangle outline."""
    x0, y0, x1, y1 = bbox
    for i in range(width):
        draw.rectangle([x0+i, y0+i, x1-i, y1-i], outline=color + (255,))


def draw_neon_line(draw, start, end, color, width=2):
    """Draw a neon line."""
    draw.line([start, end], fill=color + (255,), width=width)


# ═════════════════════════════════════════════════════════════════════════════
# PLAYER SPRITES (32x64)
# ═════════════════════════════════════════════════════════════════════════════

def generate_player_striker():
    """Striker: hot pink/magenta neon outlines, aggressive angular shape."""
    w, h = 32, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Dark body fill
    body_pts = [(4, 8), (16, 2), (28, 8), (30, 24), (28, 58), (20, 62), (12, 62), (4, 58), (2, 24)]
    draw.polygon(body_pts, fill=(10, 2, 20, 220))

    # Neon outline - hot pink
    color = HOT_PINK + (255,)
    for i in range(len(body_pts)):
        p1 = body_pts[i]
        p2 = body_pts[(i + 1) % len(body_pts)]
        draw.line([p1, p2], fill=color, width=2)

    # Inner detail lines - visor
    draw.line([(8, 16), (24, 16)], fill=color, width=2)
    draw.line([(8, 18), (24, 18)], fill=(255, 100, 180, 200), width=1)

    # Shoulder accents
    draw.line([(2, 24), (8, 20)], fill=color, width=2)
    draw.line([(30, 24), (24, 20)], fill=color, width=2)

    # Chest angular detail
    draw.line([(10, 28), (16, 34)], fill=color, width=1)
    draw.line([(22, 28), (16, 34)], fill=color, width=1)

    # Belt line
    draw.line([(6, 40), (26, 40)], fill=HOT_PINK + (180,), width=1)

    # Leg separation
    draw.line([(16, 42), (16, 60)], fill=(30, 5, 50, 150), width=1)

    # Boot accents
    draw.line([(6, 56), (14, 56)], fill=color, width=1)
    draw.line([(18, 56), (26, 56)], fill=color, width=1)

    # Apply glow
    img = make_neon_glow(img, radius=2)

    img.save(os.path.join(SPRITES_DIR, "player_striker.png"))
    print("  -> player_striker.png")


def generate_player_engineer():
    """Engineer: electric cyan/blue neon outlines, tech/boxy shape."""
    w, h = 32, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Dark body fill - more rectangular/boxy
    body_pts = [(4, 6), (28, 6), (30, 12), (30, 56), (26, 62), (6, 62), (2, 56), (2, 12)]
    draw.polygon(body_pts, fill=(2, 10, 20, 220))

    # Neon outline - cyan
    color = ELECTRIC_CYAN + (255,)
    for i in range(len(body_pts)):
        p1 = body_pts[i]
        p2 = body_pts[(i + 1) % len(body_pts)]
        draw.line([p1, p2], fill=color, width=2)

    # Visor - wider, more tech-like
    draw.rectangle([6, 14, 26, 20], outline=color)
    draw.rectangle([8, 15, 24, 19], fill=(0, 180, 220, 150))

    # Chest panel / circuit board pattern
    draw.rectangle([8, 26, 24, 38], outline=ELECTRIC_CYAN + (180,))
    draw.line([(12, 26), (12, 38)], fill=ELECTRIC_CYAN + (120,), width=1)
    draw.line([(20, 26), (20, 38)], fill=ELECTRIC_CYAN + (120,), width=1)
    draw.line([(8, 32), (24, 32)], fill=ELECTRIC_CYAN + (120,), width=1)

    # Small dots like circuit nodes
    for pos in [(12, 29), (20, 29), (12, 35), (20, 35), (16, 32)]:
        draw.ellipse([pos[0]-1, pos[1]-1, pos[0]+1, pos[1]+1], fill=ELECTRIC_CYAN + (255,))

    # Belt with tech detail
    draw.line([(4, 42), (28, 42)], fill=color, width=2)

    # Leg separation
    draw.line([(16, 44), (16, 60)], fill=(5, 20, 30, 150), width=1)

    # Boot circuits
    draw.line([(6, 54), (14, 54)], fill=ELECTRIC_CYAN + (160,), width=1)
    draw.line([(18, 54), (26, 54)], fill=ELECTRIC_CYAN + (160,), width=1)

    img = make_neon_glow(img, radius=2)
    img.save(os.path.join(SPRITES_DIR, "player_engineer.png"))
    print("  -> player_engineer.png")


def generate_player_default():
    """Default player: blue neon outlines (before role assigned)."""
    w, h = 32, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    blue = (50, 100, 255)
    body_pts = [(6, 6), (26, 6), (28, 12), (28, 56), (24, 62), (8, 62), (4, 56), (4, 12)]
    draw.polygon(body_pts, fill=(5, 8, 25, 220))
    color = blue + (255,)
    for i in range(len(body_pts)):
        p1 = body_pts[i]
        p2 = body_pts[(i + 1) % len(body_pts)]
        draw.line([p1, p2], fill=color, width=2)

    # Simple visor
    draw.rectangle([8, 14, 24, 20], outline=color)
    draw.rectangle([10, 15, 22, 19], fill=(30, 60, 200, 150))

    # Minimal body lines
    draw.line([(8, 30), (24, 30)], fill=blue + (140,), width=1)
    draw.line([(8, 42), (24, 42)], fill=blue + (140,), width=1)
    draw.line([(16, 44), (16, 60)], fill=(10, 15, 40, 120), width=1)

    img = make_neon_glow(img, radius=2)
    img.save(os.path.join(SPRITES_DIR, "player_default.png"))
    print("  -> player_default.png")


def generate_player_downed():
    """Downed player: dim gray with flickering red outlines."""
    w, h = 32, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    gray = (80, 80, 90)
    body_pts = [(6, 6), (26, 6), (28, 12), (28, 56), (24, 62), (8, 62), (4, 56), (4, 12)]
    draw.polygon(body_pts, fill=(15, 15, 20, 180))
    color = gray + (200,)
    for i in range(len(body_pts)):
        p1 = body_pts[i]
        p2 = body_pts[(i + 1) % len(body_pts)]
        draw.line([p1, p2], fill=color, width=2)

    # Dim red X across the body
    draw.line([(8, 10), (24, 54)], fill=(180, 30, 30, 160), width=2)
    draw.line([(24, 10), (8, 54)], fill=(180, 30, 30, 160), width=2)

    img = make_neon_glow(img, radius=2)
    img.save(os.path.join(SPRITES_DIR, "player_downed.png"))
    print("  -> player_downed.png")


# ═════════════════════════════════════════════════════════════════════════════
# ENEMY SPRITES
# ═════════════════════════════════════════════════════════════════════════════

def generate_enemy_basic():
    """Basic enemy: neon red wireframe geometric shape, 48x48."""
    w, h = 48, 48
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Dark fill
    draw.rectangle([4, 4, 44, 44], fill=(20, 2, 5, 200))

    color = NEON_RED + (255,)
    # Outer wireframe
    draw.rectangle([3, 3, 45, 45], outline=color)
    draw.rectangle([5, 5, 43, 43], outline=NEON_RED + (160,))

    # Inner wireframe diamond
    cx, cy = 24, 24
    diamond = [(cx, 8), (40, cy), (cx, 40), (8, cy)]
    draw.polygon(diamond, outline=color)

    # Cross hairs
    draw.line([(24, 8), (24, 40)], fill=NEON_RED + (100,), width=1)
    draw.line([(8, 24), (40, 24)], fill=NEON_RED + (100,), width=1)

    # Corner accents
    for cx, cy in [(8, 8), (40, 8), (8, 40), (40, 40)]:
        draw.ellipse([cx-2, cy-2, cx+2, cy+2], fill=NEON_RED + (200,))

    # Center eye
    draw.ellipse([20, 20, 28, 28], outline=color, width=1)
    draw.ellipse([22, 22, 26, 26], fill=(255, 80, 80, 200))

    img = make_neon_glow(img, radius=3)
    img.save(os.path.join(ENEMIES_DIR, "enemy_basic.png"))
    print("  -> enemies/enemy_basic.png")


def generate_enemy_merge_conflict():
    """Merge Conflict: glitching neon purple shape with double outline, 3 tiers."""
    sizes = [(48, 48), (32, 32), (20, 20)]
    names = ["enemy_merge_conflict_t0.png", "enemy_merge_conflict_t1.png", "enemy_merge_conflict_t2.png"]
    colors = [
        NEON_RED,        # T0 - red
        (255, 80, 120),  # T1 - lighter red/pink
        (255, 140, 160), # T2 - light pink
    ]

    for idx, ((w, h), name, base_color) in enumerate(zip(sizes, names, colors)):
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        m = max(2, w // 12)  # Margin scales with size

        # Dark fill
        draw.rectangle([m, m, w-m-1, h-m-1], fill=(25, 5, 30, 200))

        color = base_color + (255,)
        purple_shift = NEON_PURPLE + (180,)

        # Double outline with offset (glitch effect)
        draw.rectangle([m, m, w-m-1, h-m-1], outline=color)
        # Offset copy to create "merge conflict" double vision
        offset = max(1, w // 16)
        draw.rectangle([m+offset, m+offset, w-m-1+offset, h-m-1+offset], outline=purple_shift)

        # Diagonal glitch lines
        step = max(4, w // 6)
        for i in range(0, w, step):
            y_off = random.randint(-1, 1)
            draw.line([(i, h//2 + y_off - 1), (min(i+step-1, w-1), h//2 + y_off - 1)],
                     fill=base_color + (100,), width=1)

        # Center merge symbol (two overlapping arrows)
        cx, cy = w//2, h//2
        s = max(3, w//6)
        draw.line([(cx-s, cy-s), (cx, cy)], fill=color, width=max(1, w//16))
        draw.line([(cx+s, cy-s), (cx, cy)], fill=purple_shift, width=max(1, w//16))
        draw.line([(cx, cy), (cx, cy+s)], fill=color, width=max(1, w//16))

        img = make_neon_glow(img, radius=max(2, w//16))
        img.save(os.path.join(ENEMIES_DIR, name))
        print(f"  -> enemies/{name}")


def generate_enemy_hallucination():
    """Hallucination: two sprites - disguised (green health pickup) and revealed (purple ghost)."""
    # Disguised form: 24x24, looks like a health pickup
    w, h = 24, 24
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    green = LASER_GREEN
    # Health cross shape
    draw.rectangle([2, 2, 22, 22], fill=(5, 20, 5, 180))
    draw.rectangle([2, 2, 22, 22], outline=green + (255,))
    # Cross
    draw.rectangle([9, 5, 15, 19], fill=green + (200,))
    draw.rectangle([5, 9, 19, 15], fill=green + (200,))

    img = make_neon_glow(img, radius=2)
    img.save(os.path.join(ENEMIES_DIR, "enemy_hallucination_disguised.png"))
    print("  -> enemies/enemy_hallucination_disguised.png")

    # Revealed form: 40x40, spooky purple ghost
    w, h = 40, 40
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    purple = NEON_PURPLE
    # Ghost body - rounded top, wavy bottom
    ghost_pts = [
        (6, 36), (6, 16), (8, 10), (12, 6), (18, 4), (22, 4), (28, 6),
        (32, 10), (34, 16), (34, 36), (30, 32), (26, 36), (22, 32),
        (18, 36), (14, 32), (10, 36)
    ]
    draw.polygon(ghost_pts, fill=(30, 0, 50, 180))
    color = purple + (255,)
    for i in range(len(ghost_pts)):
        p1 = ghost_pts[i]
        p2 = ghost_pts[(i + 1) % len(ghost_pts)]
        draw.line([p1, p2], fill=color, width=2)

    # Glowing eyes
    draw.ellipse([12, 14, 18, 22], fill=(255, 255, 255, 240))
    draw.ellipse([22, 14, 28, 22], fill=(255, 255, 255, 240))
    draw.ellipse([14, 16, 17, 20], fill=purple + (255,))
    draw.ellipse([24, 16, 27, 20], fill=purple + (255,))

    # Ghost trails / afterimage lines
    for y_off in [2, 4]:
        draw.line([(10, 36 + y_off), (30, 36 + y_off)], fill=purple + (60,), width=1)

    img = make_neon_glow(img, radius=3)
    img.save(os.path.join(ENEMIES_DIR, "enemy_hallucination_revealed.png"))
    print("  -> enemies/enemy_hallucination_revealed.png")


def generate_enemy_context_rot():
    """Context Rot: corrupted neon green, static/noise texture, 40x40."""
    w, h = 40, 40
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    green = LASER_GREEN

    # Fill with noisy/static pattern
    draw.rectangle([3, 3, 37, 37], fill=(5, 15, 5, 200))

    # Random static noise pixels
    random.seed(42)
    for _ in range(120):
        x = random.randint(4, 36)
        y = random.randint(4, 36)
        intensity = random.randint(20, 80)
        g = random.randint(100, 255)
        img.putpixel((x, y), (intensity, g, intensity, random.randint(100, 200)))

    draw = ImageDraw.Draw(img)

    # Neon green wireframe with corruption
    color = green + (255,)
    draw.rectangle([3, 3, 37, 37], outline=color)

    # Horizontal scan lines (CRT corruption effect)
    for y in range(5, 36, 3):
        x_shift = random.randint(-2, 2)
        draw.line([(4 + x_shift, y), (36 + x_shift, y)], fill=green + (40,), width=1)

    # Corrupted symbol in center - broken brackets
    draw.line([(12, 12), (8, 20), (12, 28)], fill=color, width=2)
    draw.line([(28, 12), (32, 20), (28, 28)], fill=color, width=2)
    # Corrupted dots between brackets
    for x in [16, 20, 24]:
        draw.ellipse([x-1, 19, x+1, 21], fill=green + (220,))

    # Glitch offset section
    draw.rectangle([3, 18, 37, 22], outline=green + (80,))

    img = make_neon_glow(img, radius=2)
    img.save(os.path.join(ENEMIES_DIR, "enemy_context_rot.png"))
    print("  -> enemies/enemy_context_rot.png")


def generate_enemy_dependency_hell():
    """Dependency Hell: neon orange with chain-link pattern, 56x56."""
    w, h = 56, 56
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    orange = NEON_ORANGE
    color = orange + (255,)

    # Dark fill
    draw.rectangle([4, 4, 52, 52], fill=(25, 12, 2, 200))

    # Outer frame
    draw.rectangle([3, 3, 53, 53], outline=color, width=2)

    # Chain-link pattern around the edge
    chain_color = orange + (160,)
    for i in range(8, 48, 8):
        # Top chain links
        draw.ellipse([i-3, 2, i+3, 8], outline=chain_color)
        # Bottom chain links
        draw.ellipse([i-3, 48, i+3, 54], outline=chain_color)
        # Left chain links
        draw.ellipse([2, i-3, 8, i+3], outline=chain_color)
        # Right chain links
        draw.ellipse([48, i-3, 54, i+3], outline=chain_color)

    # Inner aura circle (represents the ability-disabling aura)
    for r in [18, 20, 22]:
        alpha = 60 if r == 20 else 30
        draw.ellipse([28-r, 28-r, 28+r, 28+r], outline=orange + (alpha,))

    # Center symbol - interlocked rings
    draw.ellipse([18, 18, 32, 32], outline=color, width=2)
    draw.ellipse([24, 24, 38, 38], outline=color, width=2)

    # Lock symbol in center
    draw.rectangle([24, 26, 32, 34], outline=color)
    draw.arc([25, 22, 31, 28], 0, 180, fill=color, width=2)

    img = make_neon_glow(img, radius=3)
    img.save(os.path.join(ENEMIES_DIR, "enemy_dependency_hell.png"))
    print("  -> enemies/enemy_dependency_hell.png")


# ═════════════════════════════════════════════════════════════════════════════
# PROJECTILE SPRITES
# ═════════════════════════════════════════════════════════════════════════════

def generate_projectile_player():
    """Player projectile: bright laser beam - hot pink with white core, 12x6."""
    w, h = 12, 6
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Outer glow
    draw.rectangle([0, 0, 11, 5], fill=HOT_PINK + (120,))
    # Middle
    draw.rectangle([1, 1, 10, 4], fill=HOT_PINK + (220,))
    # White core
    draw.rectangle([2, 2, 9, 3], fill=(255, 255, 255, 255))

    img = make_neon_glow(img, radius=2)
    img.save(os.path.join(SPRITES_DIR, "projectile_player.png"))
    print("  -> projectile_player.png")


def generate_projectile_enemy():
    """Enemy projectile: neon red/orange bolt, 12x12."""
    w, h = 12, 12
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Diamond shape
    pts = [(6, 0), (12, 6), (6, 12), (0, 6)]
    draw.polygon(pts, fill=(200, 30, 10, 200))
    color = NEON_RED + (255,)
    for i in range(len(pts)):
        draw.line([pts[i], pts[(i+1)%len(pts)]], fill=color, width=1)

    # White core
    draw.ellipse([4, 4, 8, 8], fill=(255, 200, 180, 255))

    img = make_neon_glow(img, radius=2)
    img.save(os.path.join(SPRITES_DIR, "projectile_enemy.png"))
    print("  -> projectile_enemy.png")


# ═════════════════════════════════════════════════════════════════════════════
# TURRET SPRITE
# ═════════════════════════════════════════════════════════════════════════════

def generate_turret():
    """Turret: cyan neon tech box, 24x24."""
    w, h = 24, 24
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    color = ELECTRIC_CYAN + (255,)

    # Base
    draw.rectangle([2, 10, 22, 22], fill=(2, 15, 20, 220))
    draw.rectangle([2, 10, 22, 22], outline=color)

    # Barrel
    draw.rectangle([18, 6, 22, 14], fill=(2, 15, 20, 220))
    draw.rectangle([18, 6, 22, 14], outline=color)

    # Details
    draw.line([(6, 14), (16, 14)], fill=ELECTRIC_CYAN + (140,), width=1)
    draw.line([(6, 18), (16, 18)], fill=ELECTRIC_CYAN + (140,), width=1)

    # Barrel tip glow
    draw.rectangle([22, 8, 24, 12], fill=(0, 255, 255, 255))

    # Center LED
    draw.ellipse([10, 14, 14, 18], fill=ELECTRIC_CYAN + (255,))

    img = make_neon_glow(img, radius=2)
    img.save(os.path.join(SPRITES_DIR, "turret.png"))
    print("  -> turret.png")


# ═════════════════════════════════════════════════════════════════════════════
# PARALLAX BACKGROUNDS (1920x600)
# ═════════════════════════════════════════════════════════════════════════════

def generate_bg_far():
    """Layer 1 (far): Deep purple to black gradient, neon grid perspective, stars."""
    w, h = 1920, 600
    img = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    draw = ImageDraw.Draw(img)

    # Vertical gradient: deep purple at top -> black at bottom
    for y in range(h):
        t = y / h
        r = int(25 * (1 - t))
        g = int(5 * (1 - t))
        b = int(50 * (1 - t))
        draw.line([(0, y), (w, y)], fill=(r, g, b, 255))

    # Stars / dots
    random.seed(1337)
    for _ in range(200):
        x = random.randint(0, w-1)
        y = random.randint(0, int(h * 0.7))
        brightness = random.randint(100, 255)
        size = random.choice([0, 0, 0, 1])
        if size == 0:
            img.putpixel((x, y), (brightness, brightness, brightness + 20, brightness))
        else:
            draw.ellipse([x-1, y-1, x+1, y+1], fill=(brightness, brightness, brightness + 20, min(255, brightness)))

    # Neon grid perspective - vanishing point at center-top
    vx, vy = w // 2, int(h * 0.35)  # Vanishing point
    grid_color = HOT_PINK + (40,)
    grid_color_h = NEON_PURPLE + (30,)

    # Horizontal grid lines (closer together near vanishing point, wider apart below)
    grid_bottom = h
    for i in range(1, 20):
        t = (i / 20.0) ** 1.8  # Non-linear spacing
        y = int(vy + (grid_bottom - vy) * t)
        if y < h:
            # Horizontal lines with slight curve/perspective
            alpha = min(80, int(20 + t * 60))
            line_color = (HOT_PINK[0], HOT_PINK[1], HOT_PINK[2], alpha)
            draw.line([(0, y), (w, y)], fill=line_color, width=1)

    # Vertical perspective lines radiating from vanishing point
    num_vlines = 24
    for i in range(num_vlines + 1):
        # Spread across bottom
        bx = int((i / num_vlines) * w)
        alpha = 25 + int(15 * abs(i / num_vlines - 0.5) * 2)
        line_color = (NEON_PURPLE[0], NEON_PURPLE[1], NEON_PURPLE[2], alpha)
        draw.line([(vx, vy), (bx, h)], fill=line_color, width=1)

    # Horizon glow line
    for thickness in range(8, 0, -1):
        alpha = int(20 + (8 - thickness) * 8)
        glow_color = (HOT_PINK[0], HOT_PINK[1], HOT_PINK[2], alpha)
        draw.line([(0, vy + thickness), (w, vy + thickness)], fill=glow_color, width=1)
        draw.line([(0, vy - thickness), (w, vy - thickness)], fill=glow_color, width=1)
    draw.line([(0, vy), (w, vy)], fill=HOT_PINK + (100,), width=1)

    # Sun/moon at vanishing point
    sun_r = 40
    for r in range(sun_r + 15, sun_r, -1):
        alpha = int(15 * (sun_r + 15 - r))
        draw.ellipse([vx-r, vy-r-20, vx+r, vy+r-20],
                     outline=(HOT_PINK[0], HOT_PINK[1] + 40, HOT_PINK[2], min(255, alpha)))

    draw.ellipse([vx-sun_r, vy-sun_r-20, vx+sun_r, vy+sun_r-20],
                 fill=(255, 80, 180, 60))

    # Horizontal bands through the sun (retrowave style)
    for sy in range(vy - sun_r - 20 + 10, vy + sun_r - 20, 8):
        draw.line([(vx - sun_r, sy), (vx + sun_r, sy)], fill=(0, 0, 0, 120), width=3)

    img.save(os.path.join(BG_DIR, "bg_far.png"))
    print("  -> backgrounds/bg_far.png")


def generate_bg_mid():
    """Layer 2 (mid): Neon city skyline silhouettes with neon outline edges."""
    w, h = 1920, 600
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Buildings as dark silhouettes with neon edges
    random.seed(99)
    building_colors = [HOT_PINK, ELECTRIC_CYAN, NEON_PURPLE, (100, 80, 255)]

    x = 0
    while x < w:
        bw = random.randint(40, 120)
        bh = random.randint(100, 350)
        by = h - bh

        # Dark fill
        draw.rectangle([x, by, x + bw, h], fill=(8, 4, 15, 200))

        # Neon outline on top and sides
        outline_color = random.choice(building_colors)
        oc = outline_color + (180,)
        draw.line([(x, by), (x + bw, by)], fill=oc, width=2)
        draw.line([(x, by), (x, h)], fill=oc, width=1)
        draw.line([(x + bw, by), (x + bw, h)], fill=oc, width=1)

        # Window lights - small glowing dots
        win_color = outline_color + (120,)
        for wy in range(by + 10, h - 10, 16):
            for wx in range(x + 8, x + bw - 4, 12):
                if random.random() < 0.4:
                    draw.rectangle([wx, wy, wx + 4, wy + 6], fill=win_color)

        # Occasional antenna / spire
        if random.random() < 0.3:
            ax = x + bw // 2
            ah = random.randint(20, 50)
            draw.line([(ax, by), (ax, by - ah)], fill=oc, width=1)
            draw.ellipse([ax-2, by-ah-2, ax+2, by-ah+2], fill=NEON_RED + (200,))

        x += bw + random.randint(5, 30)

    img.save(os.path.join(BG_DIR, "bg_mid.png"))
    print("  -> backgrounds/bg_mid.png")


def generate_bg_near():
    """Layer 3 (near): Digital rain / matrix-style lines and neon pipes."""
    w, h = 1920, 600
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Digital rain columns
    random.seed(777)
    for x in range(0, w, 24):
        if random.random() < 0.35:
            col_len = random.randint(80, 400)
            start_y = random.randint(0, h - col_len)
            for y in range(start_y, start_y + col_len, 8):
                alpha = int(40 + 60 * ((y - start_y) / col_len))
                # Brighter at the leading edge
                if y > start_y + col_len - 20:
                    alpha = min(255, alpha + 80)
                green = LASER_GREEN
                draw.rectangle([x, y, x+3, y+5], fill=(green[0], green[1], green[2], alpha))

    # Neon pipe segments along the bottom
    pipe_y = h - 40
    pipe_color = ELECTRIC_CYAN + (60,)
    draw.line([(0, pipe_y), (w, pipe_y)], fill=pipe_color, width=3)
    draw.line([(0, pipe_y + 20), (w, pipe_y + 20)], fill=HOT_PINK + (40,), width=2)

    # Vertical pipe segments
    for x in range(0, w, 300):
        x_off = random.randint(-50, 50)
        draw.line([(x + x_off, pipe_y - 60), (x + x_off, pipe_y)], fill=pipe_color, width=2)
        # Joint
        draw.ellipse([x+x_off-4, pipe_y-4, x+x_off+4, pipe_y+4], outline=ELECTRIC_CYAN + (80,))

    img.save(os.path.join(BG_DIR, "bg_near.png"))
    print("  -> backgrounds/bg_near.png")


# ═════════════════════════════════════════════════════════════════════════════
# PLATFORM TILES
# ═════════════════════════════════════════════════════════════════════════════

def generate_floor_tile():
    """Floor: dark surface with neon grid lines (cyan), 64x32 tile."""
    w, h = 64, 32
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Dark fill
    draw.rectangle([0, 0, w-1, h-1], fill=(12, 8, 20, 240))

    # Grid lines
    grid_color = ELECTRIC_CYAN + (80,)
    # Horizontal
    for y in [0, 8, 16, 24, 31]:
        draw.line([(0, y), (w-1, y)], fill=grid_color, width=1)
    # Vertical
    for x in range(0, w, 8):
        draw.line([(x, 0), (x, h-1)], fill=grid_color, width=1)

    # Top edge glow (the surface you walk on)
    draw.line([(0, 0), (w-1, 0)], fill=ELECTRIC_CYAN + (200,), width=2)
    draw.line([(0, 2), (w-1, 2)], fill=ELECTRIC_CYAN + (100,), width=1)

    img.save(os.path.join(TILES_DIR, "floor_tile.png"))
    print("  -> tiles/floor_tile.png")


def generate_wall_tile():
    """Wall: dark with vertical neon accent stripes, 32x64 tile."""
    w, h = 32, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Dark fill
    draw.rectangle([0, 0, w-1, h-1], fill=(12, 8, 20, 240))

    # Vertical neon stripes
    draw.line([(2, 0), (2, h-1)], fill=HOT_PINK + (160,), width=2)
    draw.line([(w-3, 0), (w-3, h-1)], fill=HOT_PINK + (160,), width=2)

    # Horizontal accent lines
    for y in range(0, h, 16):
        draw.line([(0, y), (w-1, y)], fill=HOT_PINK + (60,), width=1)

    # Inner faint grid
    for x in range(8, w, 8):
        draw.line([(x, 0), (x, h-1)], fill=NEON_PURPLE + (30,), width=1)

    img.save(os.path.join(TILES_DIR, "wall_tile.png"))
    print("  -> tiles/wall_tile.png")


def generate_ceiling_tile():
    """Ceiling: dark with bottom-edge glow, 64x32 tile."""
    w, h = 64, 32
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Dark fill
    draw.rectangle([0, 0, w-1, h-1], fill=(12, 8, 20, 240))

    # Grid
    grid_color = NEON_PURPLE + (50,)
    for y in range(0, h, 8):
        draw.line([(0, y), (w-1, y)], fill=grid_color, width=1)
    for x in range(0, w, 8):
        draw.line([(x, 0), (x, h-1)], fill=grid_color, width=1)

    # Bottom edge glow
    draw.line([(0, h-1), (w-1, h-1)], fill=NEON_PURPLE + (200,), width=2)
    draw.line([(0, h-3), (w-1, h-3)], fill=NEON_PURPLE + (100,), width=1)

    img.save(os.path.join(TILES_DIR, "ceiling_tile.png"))
    print("  -> tiles/ceiling_tile.png")


# ═════════════════════════════════════════════════════════════════════════════
# MAIN
# ═════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    print("Generating NEON SYNTHWAVE art assets...")
    print()

    print("Player sprites:")
    generate_player_striker()
    generate_player_engineer()
    generate_player_default()
    generate_player_downed()
    print()

    print("Enemy sprites:")
    generate_enemy_basic()
    generate_enemy_merge_conflict()
    generate_enemy_hallucination()
    generate_enemy_context_rot()
    generate_enemy_dependency_hell()
    print()

    print("Projectile sprites:")
    generate_projectile_player()
    generate_projectile_enemy()
    print()

    print("Turret:")
    generate_turret()
    print()

    print("Parallax backgrounds:")
    generate_bg_far()
    generate_bg_mid()
    generate_bg_near()
    print()

    print("Platform tiles:")
    generate_floor_tile()
    generate_wall_tile()
    generate_ceiling_tile()
    print()

    print("All assets generated!")
