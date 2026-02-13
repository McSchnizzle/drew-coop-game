#!/usr/bin/env python3
"""Generate all military/tactical shooter art assets using Pillow.

Produces:
  - Player sprites (32x64): default, striker, engineer
  - Enemy sprites (48x48): basic, merge_conflict, hallucination, context_rot, dependency_hell
  - Projectile sprites: player bullet (12x6), enemy bullet (12x12)
  - Turret sprite (24x24)
  - Parallax backgrounds (1920x600): far, mid, near
  - Platform tiles: floor (1200x32), walls (32x700), ceiling (1200x32)
"""

import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

# Paths
BASE = Path(__file__).parent / "game" / "assets"
SPRITES = BASE / "sprites"
ENEMIES = BASE / "enemies"
BACKGROUNDS = BASE / "backgrounds"
EFFECTS = BASE / "effects"
TILES = BASE / "tiles"

# Ensure dirs exist
for d in (SPRITES, ENEMIES, BACKGROUNDS, EFFECTS, TILES):
    d.mkdir(parents=True, exist_ok=True)

random.seed(42)  # Reproducible art


# ─── Helpers ────────────────────────────────────────────────────────────────

def outline_rect(draw, box, color, width=1):
    """Draw a rectangle outline."""
    x0, y0, x1, y1 = box
    for i in range(width):
        draw.rectangle([x0 + i, y0 + i, x1 - i, y1 - i], outline=color)


def draw_rivet(draw, cx, cy, size=2):
    """Draw a small rivet dot."""
    draw.ellipse([cx - size, cy - size, cx + size, cy + size], fill=(90, 90, 90))
    draw.ellipse([cx - size + 1, cy - size, cx + size - 1, cy + size - 1], fill=(120, 120, 120))


def add_noise(img, intensity=15):
    """Add subtle noise to an image for gritty texture."""
    pixels = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            n = random.randint(-intensity, intensity)
            pixels[x, y] = (
                max(0, min(255, r + n)),
                max(0, min(255, g + n)),
                max(0, min(255, b + n)),
                a,
            )
    return img


# ─── Player Sprites (32x64) ────────────────────────────────────────────────

def make_player(filename, body_color, highlight_color, variant="default"):
    """Create a military soldier sprite."""
    img = Image.new("RGBA", (32, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Helmet (top)
    helmet_color = (60, 70, 50)  # dark olive
    draw.rounded_rectangle([8, 0, 24, 12], radius=4, fill=helmet_color)
    # Helmet visor
    draw.rectangle([10, 7, 22, 10], fill=(30, 35, 25))

    # Head/face
    face_color = (160, 130, 100)
    draw.rectangle([11, 10, 21, 16], fill=face_color)

    # Neck
    draw.rectangle([13, 16, 19, 19], fill=face_color)

    # Body / torso (main body_color)
    draw.rectangle([6, 19, 26, 44], fill=body_color)

    # Body armor plate
    armor_color = tuple(max(0, c - 25) for c in body_color)
    draw.rectangle([9, 22, 23, 38], fill=armor_color)

    # Belt
    draw.rectangle([6, 44, 26, 47], fill=(50, 40, 30))
    # Belt buckle
    draw.rectangle([14, 44, 18, 47], fill=(140, 130, 90))

    # Arms
    arm_color = body_color
    draw.rectangle([2, 20, 6, 40], fill=arm_color)   # left arm
    draw.rectangle([26, 20, 30, 40], fill=arm_color)  # right arm

    # Gloves
    draw.rectangle([2, 38, 6, 42], fill=(40, 35, 30))
    draw.rectangle([26, 38, 30, 42], fill=(40, 35, 30))

    # Legs
    leg_color = tuple(max(0, c - 15) for c in body_color)
    draw.rectangle([8, 47, 14, 58], fill=leg_color)   # left leg
    draw.rectangle([18, 47, 24, 58], fill=leg_color)  # right leg

    # Boots
    boot_color = (35, 30, 25)
    draw.rectangle([7, 58, 15, 64], fill=boot_color)
    draw.rectangle([17, 58, 25, 64], fill=boot_color)

    # Highlight accents per variant
    if variant == "striker":
        # Orange shoulder pads
        draw.rectangle([2, 19, 7, 24], fill=highlight_color)
        draw.rectangle([25, 19, 30, 24], fill=highlight_color)
        # Wider build - extra armor chunks
        draw.rectangle([4, 24, 7, 32], fill=highlight_color)
        draw.rectangle([25, 24, 28, 32], fill=highlight_color)
    elif variant == "engineer":
        # Blue tool belt pouches
        draw.rectangle([6, 42, 11, 47], fill=highlight_color)
        draw.rectangle([21, 42, 26, 47], fill=highlight_color)
        # Blue shoulder tabs
        draw.rectangle([3, 19, 6, 22], fill=highlight_color)
        draw.rectangle([26, 19, 29, 22], fill=highlight_color)
        # Wrench on back
        draw.line([13, 28, 13, 38], fill=(150, 150, 160), width=1)

    # Strong dark outline
    # We'll draw the outline by expanding and using the alpha channel
    outline_color = (20, 20, 15, 255)
    # Simple approach: draw border lines around key shapes
    draw.rectangle([6, 19, 26, 44], outline=(20, 20, 15))
    draw.rounded_rectangle([8, 0, 24, 12], radius=4, outline=(20, 20, 15))
    draw.rectangle([8, 47, 14, 58], outline=(20, 20, 15))
    draw.rectangle([18, 47, 24, 58], outline=(20, 20, 15))

    img = add_noise(img, 8)
    img.save(str(SPRITES / filename))
    print(f"  Created {filename}")


# Default player (olive/khaki)
make_player("player.png", (80, 95, 55), (80, 95, 55), "default")
# Striker (olive body, orange highlights)
make_player("player_striker.png", (80, 95, 55), (220, 130, 40), "striker")
# Engineer (olive body, blue highlights)
make_player("player_engineer.png", (80, 95, 55), (60, 120, 200), "engineer")


# ─── Enemy: Basic (48x48) ──────────────────────────────────────────────────

def make_enemy_basic():
    """Hostile robot/drone - dark gray metal with red eye."""
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Main body - angular robot shape
    body_color = (65, 65, 75)
    draw.rectangle([8, 10, 40, 40], fill=body_color)

    # Head/dome
    draw.rounded_rectangle([12, 2, 36, 16], radius=5, fill=(75, 75, 85))

    # Red eye (menacing single eye)
    draw.ellipse([20, 5, 30, 13], fill=(200, 20, 20))
    # Eye glow center
    draw.ellipse([23, 7, 27, 11], fill=(255, 60, 60))
    # Eye highlight
    draw.point((24, 8), fill=(255, 180, 180))

    # Armor plates on body
    draw.rectangle([10, 18, 22, 30], fill=(55, 55, 65))
    draw.rectangle([26, 18, 38, 30], fill=(55, 55, 65))

    # Rivets
    for rx, ry in [(12, 20), (20, 20), (28, 20), (36, 20), (12, 28), (36, 28)]:
        draw_rivet(draw, rx, ry, 1)

    # Legs / treads
    draw.rectangle([10, 38, 20, 46], fill=(45, 45, 50))
    draw.rectangle([28, 38, 38, 46], fill=(45, 45, 50))

    # Tread lines
    for ty in range(39, 46, 2):
        draw.line([10, ty, 20, ty], fill=(35, 35, 40))
        draw.line([28, ty, 38, ty], fill=(35, 35, 40))

    # Arms / gun barrels
    draw.rectangle([2, 18, 8, 26], fill=(50, 50, 55))
    draw.rectangle([40, 18, 46, 26], fill=(50, 50, 55))

    # Outline
    draw.rectangle([8, 10, 40, 40], outline=(20, 20, 25))
    draw.rounded_rectangle([12, 2, 36, 16], radius=5, outline=(20, 20, 25))

    img = add_noise(img, 10)
    img.save(str(ENEMIES / "enemy_basic.png"))
    print("  Created enemy_basic.png")


make_enemy_basic()


# ─── Enemy: Merge Conflict (48x48) ─────────────────────────────────────────

def make_enemy_merge_conflict():
    """Twin-bodied creature, purple with glitch effect."""
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Two overlapping bodies (the "twin" / merge conflict)
    # Body 1 (left, slightly offset)
    purple1 = (100, 40, 130)
    draw.rounded_rectangle([2, 6, 24, 42], radius=3, fill=purple1)
    # Body 2 (right, slightly offset)
    purple2 = (130, 50, 160)
    draw.rounded_rectangle([22, 4, 46, 40], radius=3, fill=purple2)

    # Overlap zone (conflict) - glitchy
    glitch_color = (200, 80, 220)
    draw.rectangle([22, 6, 24, 40], fill=glitch_color)

    # Eyes on left body
    draw.ellipse([7, 14, 13, 20], fill=(255, 100, 255))
    draw.ellipse([14, 14, 20, 20], fill=(255, 100, 255))
    # Eyes on right body
    draw.ellipse([28, 12, 34, 18], fill=(255, 100, 255))
    draw.ellipse([35, 12, 41, 18], fill=(255, 100, 255))

    # Glitch scanlines
    for gy in range(0, 48, 4):
        offset = random.randint(-2, 2)
        draw.line([max(0, 2 + offset), gy, min(47, 46 + offset), gy],
                  fill=(200, 100, 255, 80))

    # Conflict symbol: <<<< / >>>>
    draw.line([18, 24, 30, 24], fill=(255, 200, 255), width=2)
    draw.line([18, 28, 30, 28], fill=(255, 200, 255), width=2)

    # Legs
    draw.rectangle([6, 40, 12, 47], fill=(80, 30, 110))
    draw.rectangle([15, 40, 21, 47], fill=(80, 30, 110))
    draw.rectangle([27, 38, 33, 47], fill=(110, 40, 140))
    draw.rectangle([36, 38, 42, 47], fill=(110, 40, 140))

    # Outlines
    draw.rounded_rectangle([2, 6, 24, 42], radius=3, outline=(40, 15, 55))
    draw.rounded_rectangle([22, 4, 46, 40], radius=3, outline=(40, 15, 55))

    img = add_noise(img, 12)
    img.save(str(ENEMIES / "enemy_merge_conflict.png"))
    print("  Created enemy_merge_conflict.png")


make_enemy_merge_conflict()


# ─── Enemy: Hallucination (48x48) ──────────────────────────────────────────

def make_enemy_hallucination():
    """Ghost soldier, semi-transparent blue-white."""
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Ghostly soldier body - semi-transparent
    ghost_body = (180, 200, 240, 120)
    ghost_light = (220, 230, 255, 100)
    ghost_dark = (120, 140, 180, 100)

    # Wispy body shape
    draw.ellipse([10, 2, 38, 20], fill=ghost_body)   # head
    draw.rectangle([12, 18, 36, 38], fill=ghost_body)  # torso

    # Tattered bottom edge (ghostly)
    for x in range(12, 36, 3):
        length = random.randint(4, 10)
        draw.rectangle([x, 36, x + 2, 36 + length], fill=(180, 200, 240, 60 + random.randint(0, 40)))

    # Helmet outline (faint)
    draw.arc([10, 1, 38, 18], 180, 0, fill=(200, 220, 255, 150), width=2)

    # Hollow eyes - dark voids
    draw.ellipse([16, 7, 22, 14], fill=(40, 50, 80, 200))
    draw.ellipse([26, 7, 32, 14], fill=(40, 50, 80, 200))

    # Faint blue glow in eyes
    draw.point((19, 10), fill=(150, 180, 255, 200))
    draw.point((29, 10), fill=(150, 180, 255, 200))

    # Arms (fading)
    draw.rectangle([6, 20, 12, 32], fill=(180, 200, 240, 80))
    draw.rectangle([36, 20, 42, 32], fill=(180, 200, 240, 80))

    # Ghostly weapon silhouette (faint rifle)
    draw.line([38, 22, 46, 22], fill=(160, 180, 220, 90), width=2)

    img = add_noise(img, 6)
    img.save(str(ENEMIES / "enemy_hallucination.png"))
    print("  Created enemy_hallucination.png")


make_enemy_hallucination()


# ─── Enemy: Context Rot (48x48) ────────────────────────────────────────────

def make_enemy_context_rot():
    """Corroded/rusted mechanical thing, toxic green dripping."""
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Rusted body
    rust_main = (120, 75, 40)
    rust_dark = (85, 50, 25)
    toxic_green = (80, 200, 50)

    # Main body - irregular corroded shape
    draw.rounded_rectangle([6, 6, 42, 38], radius=4, fill=rust_main)

    # Corrosion patches
    for _ in range(8):
        cx = random.randint(8, 40)
        cy = random.randint(8, 36)
        cr = random.randint(2, 5)
        draw.ellipse([cx - cr, cy - cr, cx + cr, cy + cr], fill=rust_dark)

    # Toxic green ooze dripping down
    drip_positions = [10, 18, 26, 34, 40]
    for dx in drip_positions:
        drip_len = random.randint(6, 14)
        for dy in range(0, drip_len):
            alpha = max(0, 255 - dy * 20)
            y_pos = 36 + dy
            if y_pos < 48:
                draw.rectangle([dx - 1, y_pos, dx + 1, y_pos + 1],
                               fill=(80, 200, 50, alpha))

    # Ooze pools on body
    draw.ellipse([12, 14, 22, 22], fill=(70, 180, 40, 180))
    draw.ellipse([28, 18, 38, 26], fill=(90, 210, 60, 160))

    # Exposed gears/mechanism (corrupted)
    draw.ellipse([18, 20, 30, 32], fill=(60, 60, 60))
    draw.ellipse([20, 22, 28, 30], fill=(80, 80, 80))
    # Gear teeth
    for angle in range(0, 360, 45):
        rad = math.radians(angle)
        gx = 24 + int(7 * math.cos(rad))
        gy = 26 + int(7 * math.sin(rad))
        draw.rectangle([gx - 1, gy - 1, gx + 1, gy + 1], fill=(50, 50, 50))

    # Toxic eye
    draw.ellipse([18, 8, 30, 18], fill=(60, 180, 30))
    draw.ellipse([22, 10, 26, 16], fill=(40, 140, 20))

    # Legs (stumpy, corroded)
    draw.rectangle([10, 36, 18, 46], fill=rust_dark)
    draw.rectangle([30, 36, 38, 46], fill=rust_dark)

    # Outline
    draw.rounded_rectangle([6, 6, 42, 38], radius=4, outline=(40, 25, 10))

    img = add_noise(img, 12)
    img.save(str(ENEMIES / "enemy_context_rot.png"))
    print("  Created enemy_context_rot.png")


make_enemy_context_rot()


# ─── Enemy: Dependency Hell (48x48) ────────────────────────────────────────

def make_enemy_dependency_hell():
    """Chained mechanical spider, dark red with chain links."""
    img = Image.new("RGBA", (56, 56), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    dark_red = (140, 30, 30)
    darker_red = (100, 20, 20)
    chain_color = (130, 130, 140)

    # Spider body (central)
    draw.ellipse([16, 14, 40, 38], fill=dark_red)
    # Head
    draw.ellipse([20, 8, 36, 20], fill=darker_red)

    # Multiple eyes (spider)
    eye_positions = [(23, 11), (27, 10), (31, 11), (25, 14), (29, 14)]
    for ex, ey in eye_positions:
        draw.ellipse([ex - 1, ey - 1, ex + 2, ey + 2], fill=(255, 50, 50))
        draw.point((ex, ey), fill=(255, 200, 200))

    # Spider legs (8 legs)
    leg_color = (110, 25, 25)
    # Left legs
    legs_left = [
        [(16, 18), (6, 8)],
        [(16, 24), (2, 22)],
        [(16, 30), (2, 36)],
        [(16, 34), (6, 46)],
    ]
    # Right legs
    legs_right = [
        [(40, 18), (50, 8)],
        [(40, 24), (54, 22)],
        [(40, 30), (54, 36)],
        [(40, 34), (50, 46)],
    ]

    for start, end in legs_left + legs_right:
        draw.line([start, end], fill=leg_color, width=2)
        # Joint dots
        mid = ((start[0] + end[0]) // 2, (start[1] + end[1]) // 2)
        draw.ellipse([mid[0] - 1, mid[1] - 1, mid[0] + 1, mid[1] + 1], fill=(90, 15, 15))

    # Chain links wrapped around body
    for angle in range(0, 360, 30):
        rad = math.radians(angle)
        cx = 28 + int(14 * math.cos(rad))
        cy = 26 + int(14 * math.sin(rad))
        draw.rectangle([cx - 1, cy - 1, cx + 2, cy + 2], fill=chain_color)
        draw.rectangle([cx, cy, cx + 1, cy + 1], fill=(160, 160, 170))

    # Dangling chains
    for chain_x in [12, 22, 34, 44]:
        for cy in range(38, 54, 3):
            draw.rectangle([chain_x, cy, chain_x + 2, cy + 2], fill=chain_color)
            draw.point((chain_x + 1, cy + 1), fill=(100, 100, 110))

    # Outline body
    draw.ellipse([16, 14, 40, 38], outline=(60, 10, 10))
    draw.ellipse([20, 8, 36, 20], outline=(60, 10, 10))

    # Resize to 48x48 (scene expects this, but collision is 56x56)
    # Actually, keep at 56x56 since that matches the collision shape
    img = add_noise(img, 10)
    # Save at native 56x56 - collision shape matches
    img.save(str(ENEMIES / "enemy_dependency_hell.png"))
    print("  Created enemy_dependency_hell.png")


make_enemy_dependency_hell()


# ─── Projectile: Player Bullet (12x6) ──────────────────────────────────────

def make_projectile():
    """Bright yellow-orange bullet tracer."""
    img = Image.new("RGBA", (12, 6), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Bullet body - bright tracer
    draw.rounded_rectangle([0, 1, 11, 5], radius=2, fill=(255, 200, 50))
    # Hot center
    draw.rectangle([2, 2, 8, 4], fill=(255, 240, 150))
    # Bright tip
    draw.rectangle([9, 2, 11, 4], fill=(255, 255, 200))
    # Trail
    draw.rectangle([0, 2, 2, 4], fill=(255, 150, 30, 180))

    img.save(str(EFFECTS / "projectile.png"))
    print("  Created projectile.png")


make_projectile()


# ─── Projectile: Enemy Bullet (12x12) ──────────────────────────────────────

def make_enemy_projectile():
    """Red-orange enemy projectile."""
    img = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Plasma ball
    draw.ellipse([1, 1, 11, 11], fill=(220, 60, 30))
    draw.ellipse([3, 3, 9, 9], fill=(255, 100, 50))
    draw.ellipse([4, 4, 8, 8], fill=(255, 180, 100))

    img.save(str(EFFECTS / "projectile_enemy.png"))
    print("  Created projectile_enemy.png")


make_enemy_projectile()


# ─── Turret Sprite (24x24) ─────────────────────────────────────────────────

def make_turret():
    """Automated turret - military green with barrel."""
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Base
    draw.rectangle([4, 16, 20, 23], fill=(60, 75, 50))
    # Body
    draw.rounded_rectangle([2, 8, 22, 18], radius=3, fill=(70, 85, 55))
    # Barrel
    draw.rectangle([18, 10, 24, 14], fill=(50, 55, 45))
    # Sensor eye
    draw.ellipse([8, 10, 14, 16], fill=(0, 200, 200))
    draw.ellipse([9, 11, 13, 15], fill=(0, 255, 255))
    # Outline
    draw.rounded_rectangle([2, 8, 22, 18], radius=3, outline=(30, 40, 25))

    img = add_noise(img, 6)
    img.save(str(SPRITES / "turret.png"))
    print("  Created turret.png")


make_turret()


# ─── Parallax Background Layer 1: Far (dark city skyline) ──────────────────

def make_bg_far():
    """Dark city skyline silhouette against smoky red-orange sky."""
    W, H = 1920, 600
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    draw = ImageDraw.Draw(img)

    # Sky gradient: dark red-orange at top fading to dark at bottom
    for y in range(H):
        t = y / H
        if t < 0.4:
            # Upper sky - smoky red-orange
            r = int(80 - t * 100)
            g = int(30 - t * 40)
            b = int(20 - t * 30)
        elif t < 0.7:
            # Mid sky - dark purple-red
            mid_t = (t - 0.4) / 0.3
            r = int(40 - mid_t * 20)
            g = int(14 - mid_t * 8)
            b = int(8 + mid_t * 10)
        else:
            # Lower - very dark
            low_t = (t - 0.7) / 0.3
            r = int(20 - low_t * 15)
            g = int(6 - low_t * 4)
            b = int(18 - low_t * 12)
        draw.line([(0, y), (W, y)], fill=(max(0, r), max(0, g), max(0, b)))

    # City skyline silhouette
    skyline_y = 350  # where buildings start
    building_defs = []
    x = 0
    while x < W:
        bw = random.randint(40, 120)
        bh = random.randint(80, 250)
        building_defs.append((x, skyline_y - bh, bw, bh))
        x += bw + random.randint(5, 30)

    # Draw buildings as black silhouettes
    for bx, by, bw, bh in building_defs:
        draw.rectangle([bx, by, bx + bw, skyline_y + 200], fill=(8, 6, 10))
        # Some tiny lit windows
        for wy in range(by + 5, skyline_y, 12):
            for wx in range(bx + 4, bx + bw - 4, 10):
                if random.random() < 0.3:
                    wc = random.choice([(60, 50, 30), (50, 40, 20), (70, 55, 25)])
                    draw.rectangle([wx, wy, wx + 3, wy + 3], fill=wc)

    # Antenna/spire details on some buildings
    for bx, by, bw, bh in building_defs:
        if random.random() < 0.3:
            ax = bx + bw // 2
            draw.line([ax, by, ax, by - 20], fill=(8, 6, 10), width=2)
            # Red light on top
            draw.ellipse([ax - 1, by - 22, ax + 1, by - 20], fill=(200, 30, 30))

    # Fill bottom with solid dark (ground)
    draw.rectangle([0, skyline_y + 50, W, H], fill=(5, 4, 6))

    img.save(str(BACKGROUNDS / "bg_far.png"))
    print("  Created bg_far.png")


make_bg_far()


# ─── Parallax Background Layer 2: Mid (industrial buildings) ────────────────

def make_bg_mid():
    """Industrial buildings, smokestacks, pipes."""
    W, H = 1920, 600
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    base_y = 420  # where structures sit
    struct_color = (35, 32, 40)
    pipe_color = (50, 48, 55)
    smoke_color = (60, 55, 65)

    # Industrial structures
    x = 0
    while x < W:
        stype = random.choice(["building", "smokestack", "tank", "crane"])
        if stype == "building":
            bw = random.randint(80, 180)
            bh = random.randint(100, 200)
            draw.rectangle([x, base_y - bh, x + bw, H], fill=struct_color)
            # Windows (dark industrial)
            for wy in range(base_y - bh + 10, base_y, 20):
                for wx in range(x + 8, x + bw - 8, 16):
                    draw.rectangle([wx, wy, wx + 8, wy + 10], fill=(20, 18, 25))
            # Pipes on side
            if random.random() < 0.5:
                for py in range(base_y - bh, base_y, 30):
                    draw.rectangle([x + bw, py, x + bw + 6, py + 4], fill=pipe_color)
            x += bw + random.randint(20, 60)

        elif stype == "smokestack":
            sw = random.randint(20, 35)
            sh = random.randint(150, 280)
            draw.rectangle([x, base_y - sh, x + sw, H], fill=(40, 38, 45))
            # Bands
            for by in range(base_y - sh, base_y, 30):
                draw.rectangle([x - 2, by, x + sw + 2, by + 3], fill=(55, 52, 60))
            # Smoke wisps at top
            for _ in range(3):
                sx = x + sw // 2 + random.randint(-10, 10)
                sy = base_y - sh - random.randint(5, 40)
                sr = random.randint(8, 20)
                draw.ellipse([sx - sr, sy - sr, sx + sr, sy + sr],
                             fill=(50, 45, 55, 60))
            x += sw + random.randint(30, 80)

        elif stype == "tank":
            tw = random.randint(50, 80)
            th = random.randint(40, 70)
            draw.rounded_rectangle([x, base_y - th, x + tw, base_y + 10],
                                   radius=tw // 4, fill=(42, 40, 48))
            # Tank supports
            draw.rectangle([x + 5, base_y, x + 12, H], fill=(30, 28, 35))
            draw.rectangle([x + tw - 12, base_y, x + tw - 5, H], fill=(30, 28, 35))
            x += tw + random.randint(40, 80)

        elif stype == "crane":
            # Crane arm
            draw.rectangle([x, base_y - 200, x + 8, base_y], fill=(45, 42, 50))
            draw.line([x + 4, base_y - 200, x + 80, base_y - 190], fill=(45, 42, 50), width=3)
            # Cable
            draw.line([x + 70, base_y - 188, x + 70, base_y - 140], fill=(60, 58, 65))
            x += 100 + random.randint(20, 60)

    # Horizontal pipe runs at various heights
    for _ in range(4):
        py = random.randint(base_y - 180, base_y - 20)
        px_start = random.randint(0, W // 2)
        px_end = px_start + random.randint(200, 600)
        draw.rectangle([px_start, py, px_end, py + 5], fill=pipe_color)
        # Pipe joints
        for jx in range(px_start, px_end, 80):
            draw.rectangle([jx, py - 2, jx + 8, py + 7], fill=(60, 58, 65))

    img.save(str(BACKGROUNDS / "bg_mid.png"))
    print("  Created bg_mid.png")


make_bg_mid()


# ─── Parallax Background Layer 3: Near (destroyed walls, debris) ────────────

def make_bg_near():
    """Destroyed walls, debris, barbed wire."""
    W, H = 1920, 600
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    ground_y = 550  # Just above floor
    wall_color = (55, 50, 48)
    rubble_color = (45, 40, 38)

    # Broken wall segments on left and right edges
    wall_segments = [
        (0, 200, 60, H),
        (30, 300, 80, H),
        (W - 70, 180, W, H),
        (W - 90, 280, W - 30, H),
    ]
    for x0, y0, x1, y1 in wall_segments:
        draw.rectangle([x0, y0, x1, y1], fill=wall_color)
        # Damage marks
        for _ in range(5):
            dx = random.randint(x0, max(x0 + 1, x1 - 5))
            dy = random.randint(y0, max(y0 + 1, y1 - 5))
            draw.rectangle([dx, dy, dx + random.randint(2, 8), dy + random.randint(2, 6)],
                           fill=(35, 30, 28))

    # Rubble piles
    for rx in range(0, W, random.randint(250, 400)):
        pile_w = random.randint(30, 60)
        pile_h = random.randint(10, 25)
        py = ground_y - pile_h
        # Draw as rough triangle of blocks
        for _ in range(8):
            bx = rx + random.randint(0, pile_w)
            by = py + random.randint(0, pile_h)
            bs = random.randint(3, 10)
            draw.rectangle([bx, by, bx + bs, by + bs], fill=rubble_color)

    # Barbed wire - horizontal runs at various heights
    wire_y_positions = [ground_y - 30, ground_y - 60]
    for wire_y in wire_y_positions:
        for wx in range(100, W - 100, 4):
            # Wavy wire
            wy = wire_y + int(3 * math.sin(wx * 0.1))
            draw.point((wx, wy), fill=(80, 78, 75, 180))
            # Barbs every ~20 pixels
            if wx % 20 < 4:
                draw.line([wx, wy - 3, wx + 2, wy + 3], fill=(80, 78, 75, 200))
                draw.line([wx, wy + 3, wx + 2, wy - 3], fill=(80, 78, 75, 200))

    # Scattered debris in foreground
    for _ in range(20):
        dx = random.randint(100, W - 100)
        dy = random.randint(ground_y - 15, ground_y)
        ds = random.randint(2, 6)
        c = random.choice([rubble_color, wall_color, (60, 55, 50)])
        draw.rectangle([dx, dy, dx + ds, dy + ds], fill=(*c, 150))

    img.save(str(BACKGROUNDS / "bg_near.png"))
    print("  Created bg_near.png")


make_bg_near()


# ─── Floor Tile (1200x32) ──────────────────────────────────────────────────

def make_floor():
    """Industrial metal grating/plates, dark gray with rivets."""
    W, H = 1200, 32
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Base plate
    plate_color = (60, 60, 65)
    draw.rectangle([0, 0, W, H], fill=plate_color)

    # Plate segments with seams
    plate_width = 80
    for px in range(0, W, plate_width):
        # Slight color variation per plate
        offset = random.randint(-5, 5)
        c = tuple(max(0, min(255, plate_color[i] + offset)) for i in range(3))
        draw.rectangle([px + 1, 1, px + plate_width - 1, H - 1], fill=c)
        # Seam line
        draw.line([px, 0, px, H], fill=(40, 40, 45), width=1)

    # Rivets along top and bottom edges
    for rx in range(10, W, 40):
        draw_rivet(draw, rx, 5, 2)
        draw_rivet(draw, rx, H - 6, 2)

    # Diamond plate pattern (subtle)
    for dy in range(8, H - 8, 8):
        for dx in range(5 + (dy % 16) // 2, W, 16):
            draw.polygon([(dx, dy - 2), (dx + 2, dy), (dx, dy + 2), (dx - 2, dy)],
                         fill=(70, 70, 75))

    # Top edge highlight
    draw.line([0, 0, W, 0], fill=(80, 80, 85))
    # Bottom edge shadow
    draw.line([0, H - 1, W, H - 1], fill=(35, 35, 40))

    img = add_noise(img, 5)
    img.save(str(TILES / "floor.png"))
    print("  Created floor.png")


make_floor()


# ─── Wall Tile (32x700) ────────────────────────────────────────────────────

def make_wall():
    """Concrete wall with damage marks."""
    W, H = 32, 700
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Base concrete
    concrete = (72, 68, 65)
    draw.rectangle([0, 0, W, H], fill=concrete)

    # Concrete block pattern
    block_h = 40
    for by in range(0, H, block_h):
        # Mortar line
        draw.line([0, by, W, by], fill=(55, 52, 50))
        # Block color variation
        offset = random.randint(-6, 6)
        c = tuple(max(0, min(255, concrete[i] + offset)) for i in range(3))
        draw.rectangle([1, by + 1, W - 1, by + block_h - 1], fill=c)

    # Damage marks / bullet holes
    for _ in range(15):
        dx = random.randint(4, W - 4)
        dy = random.randint(10, H - 10)
        dr = random.randint(1, 3)
        draw.ellipse([dx - dr, dy - dr, dx + dr, dy + dr], fill=(45, 42, 40))
        # Lighter ring around (chipped concrete)
        if dr > 1:
            draw.ellipse([dx - dr - 1, dy - dr - 1, dx + dr + 1, dy + dr + 1],
                         outline=(85, 82, 78))

    # Cracks
    for _ in range(3):
        start_y = random.randint(50, H - 50)
        cy = start_y
        for _ in range(random.randint(5, 15)):
            cx = random.randint(2, W - 2)
            ny = cy + random.randint(3, 12)
            draw.line([cx, cy, cx + random.randint(-3, 3), ny], fill=(50, 48, 45))
            cy = ny

    # Edge shadow (inner)
    draw.line([0, 0, 0, H], fill=(55, 52, 50))
    draw.line([W - 1, 0, W - 1, H], fill=(55, 52, 50))

    img = add_noise(img, 5)
    img.save(str(TILES / "wall.png"))
    print("  Created wall.png")


make_wall()


# ─── Ceiling Tile (1200x32) ────────────────────────────────────────────────

def make_ceiling():
    """Concrete ceiling with exposed pipes."""
    W, H = 1200, 32
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Base concrete
    draw.rectangle([0, 0, W, H], fill=(58, 55, 52))

    # Concrete panel seams
    for sx in range(0, W, 100):
        draw.line([sx, 0, sx, H], fill=(45, 42, 40))

    # Exposed pipes running along ceiling
    pipe_y = 10
    draw.rectangle([0, pipe_y, W, pipe_y + 6], fill=(70, 68, 60))
    draw.line([0, pipe_y, W, pipe_y], fill=(80, 78, 72))  # highlight
    draw.line([0, pipe_y + 6, W, pipe_y + 6], fill=(50, 48, 42))  # shadow

    # Second pipe
    pipe_y2 = 22
    draw.rectangle([0, pipe_y2, W, pipe_y2 + 4], fill=(65, 60, 55))
    draw.line([0, pipe_y2, W, pipe_y2], fill=(75, 70, 65))

    # Pipe supports/brackets every ~150px
    for bx in range(30, W, 150):
        draw.rectangle([bx, pipe_y - 2, bx + 4, pipe_y + 8], fill=(50, 48, 45))

    # Bottom edge (shadow)
    draw.line([0, H - 1, W, H - 1], fill=(40, 38, 35))
    # Top edge
    draw.line([0, 0, W, 0], fill=(65, 62, 58))

    img = add_noise(img, 4)
    img.save(str(TILES / "ceiling.png"))
    print("  Created ceiling.png")


make_ceiling()

print("\nAll art assets generated successfully!")
print(f"  Sprites: {list(SPRITES.glob('*.png'))}")
print(f"  Enemies: {list(ENEMIES.glob('*.png'))}")
print(f"  Backgrounds: {list(BACKGROUNDS.glob('*.png'))}")
print(f"  Effects: {list(EFFECTS.glob('*.png'))}")
print(f"  Tiles: {list(TILES.glob('*.png'))}")
