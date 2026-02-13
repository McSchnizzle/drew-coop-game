#!/usr/bin/env python3
"""Generate all fantasy/medieval pixel art assets for the game.

Creates:
  - Player sprites (warrior/striker, wizard/engineer, downed)
  - Enemy sprites (goblin, slime, ghost, skeleton, spider)
  - Projectile sprites (magic bolt, enemy rot bolt)
  - Turret sprite (arcane crystal turret)
  - Platform tiles (stone floor, castle walls, ceiling)
  - 3-layer parallax backgrounds (twilight sky, enchanted forest, foreground)
"""
import os
import math
import random
from PIL import Image, ImageDraw

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SPRITES_DIR = os.path.join(SCRIPT_DIR, "sprites")
BG_DIR = os.path.join(SCRIPT_DIR, "backgrounds")
TILES_DIR = os.path.join(SCRIPT_DIR, "tiles")

os.makedirs(SPRITES_DIR, exist_ok=True)
os.makedirs(BG_DIR, exist_ok=True)
os.makedirs(TILES_DIR, exist_ok=True)

# Seed for reproducibility
random.seed(42)

# ─── Fantasy Color Palette ────────────────────────────────────────────────────

# Deep purples, forest greens, magical blues, gold accents
DEEP_PURPLE = (60, 20, 90)
ROYAL_PURPLE = (100, 40, 140)
MIDNIGHT_BLUE = (20, 15, 50)
ENCHANTED_BLUE = (40, 60, 140)
FOREST_GREEN = (30, 80, 40)
DARK_FOREST = (15, 45, 20)
MOSS_GREEN = (60, 110, 50)
GOLD = (220, 180, 50)
BRIGHT_GOLD = (255, 215, 60)
STONE_GRAY = (80, 85, 78)
STONE_DARK = (55, 58, 52)
STONE_LIGHT = (110, 115, 105)
MOSS_ACCENT = (50, 90, 40)


def pixel_set(img, x, y, color):
    """Safe pixel set with bounds checking."""
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), color)


def draw_outlined_rect(draw, x0, y0, x1, y1, fill, outline, width=1):
    """Draw a filled rectangle with an outline."""
    draw.rectangle([x0, y0, x1, y1], fill=fill)
    draw.rectangle([x0, y0, x1, y1], outline=outline, width=width)


# ═══════════════════════════════════════════════════════════════════════════════
# PLAYER SPRITES (32x64)
# ═══════════════════════════════════════════════════════════════════════════════

def make_player_striker():
    """Red/orange armored knight with sword silhouette."""
    img = Image.new("RGBA", (32, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Colors
    armor_main = (180, 70, 30)
    armor_dark = (130, 45, 20)
    armor_light = (220, 120, 50)
    skin = (210, 170, 130)
    helm_metal = (160, 150, 140)
    helm_dark = (100, 95, 88)
    sword_blade = (200, 200, 210)
    sword_hilt = (140, 100, 40)
    gold_trim = (220, 180, 50)
    visor_slit = (30, 20, 15)
    cape = (140, 25, 25)
    cape_dark = (100, 15, 15)
    boots = (70, 45, 30)
    boots_dark = (50, 30, 20)

    # Helmet (rows 2-12)
    # Top of helmet
    for x in range(11, 21):
        pixel_set(img, x, 2, helm_dark)
    for x in range(10, 22):
        pixel_set(img, x, 3, helm_metal)
    for y in range(4, 11):
        for x in range(9, 23):
            pixel_set(img, x, y, helm_metal)
    # Helmet details - dark edges
    for y in range(4, 11):
        pixel_set(img, 9, y, helm_dark)
        pixel_set(img, 22, y, helm_dark)
    # Visor slit
    for x in range(12, 20):
        pixel_set(img, x, 7, visor_slit)
        pixel_set(img, x, 8, visor_slit)
    # Gold trim on helmet
    for x in range(10, 22):
        pixel_set(img, x, 11, gold_trim)
    # Helmet crest (small spike on top)
    for y in range(0, 3):
        pixel_set(img, 15, y, gold_trim)
        pixel_set(img, 16, y, gold_trim)

    # Neck
    for x in range(13, 19):
        pixel_set(img, x, 12, skin)

    # Shoulders and torso (rows 13-32)
    # Shoulder pads
    for y in range(13, 18):
        for x in range(5, 12):
            pixel_set(img, x, y, armor_dark)
        for x in range(20, 27):
            pixel_set(img, x, y, armor_dark)
    # Shoulder pad highlights
    for x in range(6, 11):
        pixel_set(img, x, 14, armor_light)
    for x in range(21, 26):
        pixel_set(img, x, 14, armor_light)
    # Gold shoulder rivets
    pixel_set(img, 8, 15, gold_trim)
    pixel_set(img, 23, 15, gold_trim)

    # Torso armor
    for y in range(13, 34):
        for x in range(10, 22):
            pixel_set(img, x, y, armor_main)
    # Armor center line
    for y in range(15, 32):
        pixel_set(img, 15, y, armor_dark)
        pixel_set(img, 16, y, armor_dark)
    # Gold belt
    for x in range(10, 22):
        pixel_set(img, x, 32, gold_trim)
        pixel_set(img, x, 33, gold_trim)
    # Belt buckle
    pixel_set(img, 15, 32, BRIGHT_GOLD)
    pixel_set(img, 16, 32, BRIGHT_GOLD)
    pixel_set(img, 15, 33, BRIGHT_GOLD)
    pixel_set(img, 16, 33, BRIGHT_GOLD)

    # Armor highlights (chest plate)
    for y in range(16, 24):
        pixel_set(img, 11, y, armor_light)
        pixel_set(img, 12, y, armor_light)

    # Cape (behind, visible on sides)
    for y in range(14, 40):
        pixel_set(img, 8, y, cape)
        pixel_set(img, 9, y, cape)
        pixel_set(img, 22, y, cape)
        pixel_set(img, 23, y, cape)
    for y in range(30, 45):
        pixel_set(img, 7, y, cape_dark)
        pixel_set(img, 24, y, cape_dark)

    # Arms
    for y in range(18, 32):
        for x in range(6, 10):
            pixel_set(img, x, y, armor_main)
        for x in range(22, 26):
            pixel_set(img, x, y, armor_main)
    # Gauntlets (hands)
    for y in range(30, 34):
        for x in range(5, 10):
            pixel_set(img, x, y, armor_dark)
        for x in range(22, 27):
            pixel_set(img, x, y, armor_dark)

    # Sword in right hand
    # Hilt
    for y in range(28, 33):
        pixel_set(img, 26, y, sword_hilt)
        pixel_set(img, 27, y, sword_hilt)
    # Cross guard
    for x in range(24, 30):
        pixel_set(img, x, 28, gold_trim)
    # Blade going up
    for y in range(6, 28):
        pixel_set(img, 26, y, sword_blade)
        pixel_set(img, 27, y, sword_blade)
    # Blade edge highlight
    for y in range(8, 26):
        pixel_set(img, 27, y, (230, 230, 240))
    # Sword tip
    pixel_set(img, 26, 5, sword_blade)

    # Legs (rows 34-52)
    for y in range(34, 52):
        for x in range(11, 16):
            pixel_set(img, x, y, armor_dark)
        for x in range(16, 21):
            pixel_set(img, x, y, armor_dark)
    # Leg armor highlights
    for y in range(36, 48):
        pixel_set(img, 12, y, armor_main)
        pixel_set(img, 18, y, armor_main)
    # Knee guards
    for x in range(11, 16):
        pixel_set(img, x, 42, gold_trim)
    for x in range(16, 21):
        pixel_set(img, x, 42, gold_trim)

    # Boots (rows 52-62)
    for y in range(52, 62):
        for x in range(10, 16):
            pixel_set(img, x, y, boots)
        for x in range(16, 22):
            pixel_set(img, x, y, boots)
    # Boot soles
    for x in range(9, 17):
        pixel_set(img, x, 62, boots_dark)
        pixel_set(img, x, 63, boots_dark)
    for x in range(15, 23):
        pixel_set(img, x, 62, boots_dark)
        pixel_set(img, x, 63, boots_dark)
    # Boot top trim
    for x in range(10, 16):
        pixel_set(img, x, 52, armor_main)
    for x in range(16, 22):
        pixel_set(img, x, 52, armor_main)

    img.save(os.path.join(SPRITES_DIR, "player_striker.png"))
    print("  -> player_striker.png")


def make_player_engineer():
    """Blue/purple wizard with staff silhouette."""
    img = Image.new("RGBA", (32, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Colors
    robe_main = (50, 40, 120)
    robe_dark = (30, 25, 80)
    robe_light = (80, 65, 160)
    hat_main = (45, 35, 110)
    hat_dark = (30, 22, 75)
    hat_band = (220, 180, 50)
    skin = (210, 170, 130)
    staff_wood = (110, 70, 35)
    staff_dark = (80, 50, 25)
    crystal = (120, 200, 255)
    crystal_glow = (180, 230, 255)
    crystal_core = (220, 240, 255)
    belt = (160, 130, 40)
    boots = (60, 40, 25)
    rune_glow = (150, 120, 255)

    # Wizard hat (rows 0-14, pointed)
    # Hat tip
    pixel_set(img, 15, 0, hat_dark)
    pixel_set(img, 16, 0, hat_dark)
    for y in range(1, 4):
        for x in range(14, 18):
            pixel_set(img, x, y, hat_main)
    for y in range(4, 7):
        for x in range(12, 20):
            pixel_set(img, x, y, hat_main)
    for y in range(7, 10):
        for x in range(10, 22):
            pixel_set(img, x, y, hat_main)
    for y in range(10, 13):
        for x in range(9, 23):
            pixel_set(img, x, y, hat_main)
    # Hat brim
    for x in range(7, 25):
        pixel_set(img, x, 13, hat_dark)
        pixel_set(img, x, 14, hat_dark)
    # Hat band (gold)
    for x in range(9, 23):
        pixel_set(img, x, 11, hat_band)
    # Hat star emblem
    pixel_set(img, 15, 8, crystal_glow)
    pixel_set(img, 16, 8, crystal_glow)
    pixel_set(img, 14, 9, crystal_glow)
    pixel_set(img, 17, 9, crystal_glow)
    pixel_set(img, 15, 10, crystal_glow)
    pixel_set(img, 16, 10, crystal_glow)

    # Face (rows 15-20)
    for y in range(15, 21):
        for x in range(12, 20):
            pixel_set(img, x, y, skin)
    # Eyes
    pixel_set(img, 13, 17, (40, 40, 80))
    pixel_set(img, 18, 17, (40, 40, 80))
    # Beard
    for y in range(19, 24):
        for x in range(13, 19):
            pixel_set(img, x, y, (180, 175, 170))
    pixel_set(img, 14, 24, (180, 175, 170))
    pixel_set(img, 15, 24, (180, 175, 170))
    pixel_set(img, 16, 24, (180, 175, 170))
    pixel_set(img, 17, 24, (180, 175, 170))

    # Robe body (rows 21-56)
    for y in range(21, 56):
        # Robe gets wider toward bottom
        width_offset = min((y - 21) // 5, 4)
        for x in range(10 - width_offset, 22 + width_offset):
            pixel_set(img, x, y, robe_main)
    # Robe center line (darker fold)
    for y in range(25, 56):
        pixel_set(img, 15, y, robe_dark)
        pixel_set(img, 16, y, robe_dark)
    # Robe light side
    for y in range(25, 50):
        pixel_set(img, 11, y, robe_light)
        pixel_set(img, 12, y, robe_light)
    # Rune symbols on robe (glowing purple)
    for glyph_y in [30, 38, 46]:
        pixel_set(img, 13, glyph_y, rune_glow)
        pixel_set(img, 14, glyph_y, rune_glow)
        pixel_set(img, 13, glyph_y + 1, rune_glow)
        pixel_set(img, 18, glyph_y, rune_glow)
        pixel_set(img, 19, glyph_y, rune_glow)
        pixel_set(img, 19, glyph_y + 1, rune_glow)

    # Belt
    for x in range(9, 23):
        pixel_set(img, x, 34, belt)
        pixel_set(img, x, 35, belt)
    # Belt buckle (crystal)
    pixel_set(img, 15, 34, crystal)
    pixel_set(img, 16, 34, crystal)
    pixel_set(img, 15, 35, crystal)
    pixel_set(img, 16, 35, crystal)

    # Sleeves / arms
    for y in range(22, 34):
        for x in range(6, 11):
            pixel_set(img, x, y, robe_main)
        for x in range(21, 26):
            pixel_set(img, x, y, robe_main)
    # Hands
    for y in range(32, 36):
        for x in range(5, 9):
            pixel_set(img, x, y, skin)
        for x in range(23, 27):
            pixel_set(img, x, y, skin)

    # Staff in right hand
    # Staff shaft (long vertical)
    for y in range(2, 58):
        pixel_set(img, 27, y, staff_wood)
        pixel_set(img, 28, y, staff_dark)
    # Crystal on top of staff
    for y in range(0, 5):
        for x in range(26, 30):
            pixel_set(img, x, y, crystal)
    pixel_set(img, 27, 1, crystal_core)
    pixel_set(img, 28, 1, crystal_core)
    pixel_set(img, 27, 2, crystal_glow)
    pixel_set(img, 28, 2, crystal_glow)
    # Staff bottom
    pixel_set(img, 27, 58, staff_dark)
    pixel_set(img, 28, 58, staff_dark)

    # Boots peeking from robe bottom
    for y in range(56, 63):
        for x in range(10, 16):
            pixel_set(img, x, y, boots)
        for x in range(16, 22):
            pixel_set(img, x, y, boots)
    # Boot soles
    for x in range(9, 17):
        pixel_set(img, x, 63, (40, 25, 15))
    for x in range(15, 23):
        pixel_set(img, x, 63, (40, 25, 15))

    img.save(os.path.join(SPRITES_DIR, "player_engineer.png"))
    print("  -> player_engineer.png")


def make_player_downed():
    """Downed player -- gray ghostly version."""
    img = Image.new("RGBA", (32, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Fallen character -- simplified gray silhouette
    gray = (120, 120, 130)
    dark_gray = (80, 80, 88)
    light_gray = (160, 160, 168)

    # Collapsed body shape (lying-ish but still vertical for gameplay)
    # Head drooped
    for y in range(8, 16):
        for x in range(10, 22):
            pixel_set(img, x, y, gray)
    # X eyes
    pixel_set(img, 13, 11, dark_gray)
    pixel_set(img, 15, 11, dark_gray)
    pixel_set(img, 14, 12, dark_gray)
    pixel_set(img, 18, 11, dark_gray)
    pixel_set(img, 20, 11, dark_gray)
    pixel_set(img, 19, 12, dark_gray)

    # Body slumped
    for y in range(16, 48):
        for x in range(9, 23):
            pixel_set(img, x, y, dark_gray)
    # Some lighter patches
    for y in range(20, 40):
        pixel_set(img, 11, y, gray)
        pixel_set(img, 20, y, gray)

    # Legs
    for y in range(48, 62):
        for x in range(10, 16):
            pixel_set(img, x, y, dark_gray)
        for x in range(16, 22):
            pixel_set(img, x, y, dark_gray)

    # Ghost wisps rising
    for wisp_x in [12, 16, 20]:
        for wy in range(2, 8):
            alpha = max(0, 180 - wy * 25)
            pixel_set(img, wisp_x, wy, (180, 180, 200, alpha))
            pixel_set(img, wisp_x + 1, wy, (180, 180, 200, alpha))

    img.save(os.path.join(SPRITES_DIR, "player_downed.png"))
    print("  -> player_downed.png")


# ═══════════════════════════════════════════════════════════════════════════════
# ENEMY SPRITES
# ═══════════════════════════════════════════════════════════════════════════════

def make_enemy_basic():
    """Green goblin/imp (48x48)."""
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))

    # Colors
    skin = (60, 140, 50)
    skin_dark = (40, 100, 35)
    skin_light = (90, 170, 70)
    eye_white = (240, 240, 220)
    eye_pupil = (200, 40, 30)
    ear_inner = (100, 60, 50)
    mouth = (50, 20, 20)
    loincloth = (120, 90, 50)
    feet = (50, 110, 40)

    # Body (rounded goblin shape)
    # Head (rows 2-18, wider)
    for y in range(4, 18):
        head_half = 10 - abs(y - 10) // 2
        for x in range(24 - head_half, 24 + head_half):
            pixel_set(img, x, y, skin)

    # Ears (pointy, sticking out)
    # Left ear
    for y in range(6, 12):
        ear_x = 14 - (y - 6)
        pixel_set(img, ear_x, y, skin)
        pixel_set(img, ear_x + 1, y, skin)
        pixel_set(img, ear_x + 2, y, ear_inner)
    # Right ear
    for y in range(6, 12):
        ear_x = 33 + (y - 6)
        pixel_set(img, ear_x, y, skin)
        pixel_set(img, ear_x - 1, y, skin)
        pixel_set(img, ear_x - 2, y, ear_inner)

    # Big eyes
    for y in range(8, 13):
        for x in range(17, 22):
            pixel_set(img, x, y, eye_white)
        for x in range(26, 31):
            pixel_set(img, x, y, eye_white)
    # Pupils (angry looking)
    for y in range(9, 12):
        pixel_set(img, 19, y, eye_pupil)
        pixel_set(img, 20, y, eye_pupil)
        pixel_set(img, 28, y, eye_pupil)
        pixel_set(img, 29, y, eye_pupil)
    # Angry eyebrows
    for x in range(17, 22):
        pixel_set(img, x, 7, skin_dark)
    for x in range(26, 31):
        pixel_set(img, x, 7, skin_dark)

    # Nose
    pixel_set(img, 23, 12, skin_dark)
    pixel_set(img, 24, 12, skin_dark)
    pixel_set(img, 23, 13, skin_dark)
    pixel_set(img, 24, 13, skin_dark)

    # Mouth (toothy grin)
    for x in range(19, 29):
        pixel_set(img, x, 15, mouth)
    # Fangs
    pixel_set(img, 20, 16, (230, 230, 220))
    pixel_set(img, 27, 16, (230, 230, 220))

    # Torso (rows 18-32)
    for y in range(18, 32):
        body_half = 8 + (y - 18) // 4
        for x in range(24 - body_half, 24 + body_half):
            pixel_set(img, x, y, skin)
    # Belly lighter
    for y in range(22, 30):
        for x in range(20, 28):
            pixel_set(img, x, y, skin_light)

    # Arms
    for y in range(19, 30):
        for x in range(10, 16):
            pixel_set(img, x, y, skin)
        for x in range(32, 38):
            pixel_set(img, x, y, skin)
    # Claws
    for x in [10, 11, 12]:
        pixel_set(img, x, 30, (80, 70, 50))
        pixel_set(img, x, 31, (80, 70, 50))
    for x in [35, 36, 37]:
        pixel_set(img, x, 30, (80, 70, 50))
        pixel_set(img, x, 31, (80, 70, 50))

    # Loincloth
    for y in range(30, 35):
        for x in range(18, 30):
            pixel_set(img, x, y, loincloth)

    # Legs
    for y in range(35, 44):
        for x in range(18, 23):
            pixel_set(img, x, y, skin)
        for x in range(25, 30):
            pixel_set(img, x, y, skin)

    # Feet
    for y in range(44, 47):
        for x in range(16, 24):
            pixel_set(img, x, y, feet)
        for x in range(24, 32):
            pixel_set(img, x, y, feet)

    img.save(os.path.join(SPRITES_DIR, "enemy_basic.png"))
    print("  -> enemy_basic.png")


def make_enemy_merge_conflict():
    """Slime creature (48x48) - purple-blue, looks divisible."""
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))

    # Colors
    slime_main = (100, 50, 160)
    slime_dark = (70, 30, 120)
    slime_light = (140, 90, 200)
    slime_highlight = (180, 140, 230)
    eye_white = (230, 230, 240)
    eye_dark = (40, 20, 60)
    split_line = (60, 25, 100)

    # Main blob shape (round with jelly wobble)
    cx, cy = 24, 26
    for y in range(8, 46):
        for x in range(4, 44):
            dx = x - cx
            dy = y - cy
            # Elliptical shape, wider than tall
            dist = (dx * dx) / (18 * 18) + (dy * dy) / (16 * 16)
            if dist < 1.0:
                if dist > 0.85:
                    pixel_set(img, x, y, slime_dark)
                elif dist > 0.6:
                    pixel_set(img, x, y, slime_main)
                else:
                    pixel_set(img, x, y, slime_light)

    # Split line down the middle (showing it can divide)
    for y in range(10, 44):
        pixel_set(img, 23, y, split_line)
        pixel_set(img, 24, y, split_line)

    # Highlight blobs (gel-like reflections)
    for y in range(12, 18):
        for x in range(14, 20):
            dist = (x - 17) ** 2 + (y - 15) ** 2
            if dist < 8:
                pixel_set(img, x, y, slime_highlight)
    for y in range(14, 19):
        for x in range(28, 34):
            dist = (x - 31) ** 2 + (y - 16) ** 2
            if dist < 7:
                pixel_set(img, x, y, slime_highlight)

    # Two pairs of eyes (one on each side of split)
    # Left eyes
    for y in range(20, 26):
        for x in range(14, 20):
            pixel_set(img, x, y, eye_white)
    pixel_set(img, 16, 22, eye_dark)
    pixel_set(img, 17, 22, eye_dark)
    pixel_set(img, 16, 23, eye_dark)
    pixel_set(img, 17, 23, eye_dark)

    # Right eyes
    for y in range(20, 26):
        for x in range(28, 34):
            pixel_set(img, x, y, eye_white)
    pixel_set(img, 30, 22, eye_dark)
    pixel_set(img, 31, 22, eye_dark)
    pixel_set(img, 30, 23, eye_dark)
    pixel_set(img, 31, 23, eye_dark)

    # Small drip at bottom
    for y in range(44, 48):
        pixel_set(img, 20, y, slime_main)
        pixel_set(img, 28, y, slime_main)
    pixel_set(img, 20, 47, slime_dark)
    pixel_set(img, 28, 47, slime_dark)

    img.save(os.path.join(SPRITES_DIR, "enemy_merge_conflict.png"))
    print("  -> enemy_merge_conflict.png")


def make_enemy_hallucination():
    """Wispy ghost/wraith (48x48), pale white-blue with transparency."""
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))

    # Colors with alpha for transparency
    ghost_body = (200, 210, 240, 140)
    ghost_light = (230, 235, 255, 160)
    ghost_dark = (150, 160, 200, 120)
    ghost_core = (240, 245, 255, 180)
    eye_glow = (100, 200, 255, 220)
    eye_core = (180, 230, 255, 240)
    wisp = (180, 200, 240, 80)

    cx, cy = 24, 20

    # Main ghostly body (fading toward bottom)
    for y in range(4, 44):
        fade = max(0, 1.0 - (y - 4) / 40.0 * 0.6)
        for x in range(6, 42):
            dx = x - cx
            dy = y - cy
            # Wavy shape
            wave = math.sin(y * 0.5) * 3
            adjusted_x = dx - wave
            dist = (adjusted_x * adjusted_x) / (15 * 15) + (dy * dy) / (18 * 18)
            if dist < 1.0:
                alpha = int(140 * fade * (1.0 - dist * 0.5))
                if dist < 0.3:
                    pixel_set(img, x, y, (240, 245, 255, min(255, alpha + 60)))
                elif dist < 0.6:
                    pixel_set(img, x, y, (220, 225, 245, alpha))
                else:
                    pixel_set(img, x, y, (190, 200, 230, max(0, alpha - 30)))

    # Eyes (glowing blue)
    for y in range(16, 22):
        for x in range(17, 22):
            pixel_set(img, x, y, eye_glow)
        for x in range(26, 31):
            pixel_set(img, x, y, eye_glow)
    # Eye cores (brighter)
    pixel_set(img, 19, 18, eye_core)
    pixel_set(img, 19, 19, eye_core)
    pixel_set(img, 28, 18, eye_core)
    pixel_set(img, 28, 19, eye_core)

    # Mouth (dark opening)
    for y in range(24, 28):
        for x in range(20, 28):
            pixel_set(img, x, y, (80, 90, 140, 200))

    # Trailing wisps at bottom
    for trail_x in [16, 22, 26, 32]:
        for y in range(38, 48):
            alpha = max(0, 120 - (y - 38) * 12)
            wave_x = int(math.sin(y * 0.8 + trail_x * 0.3) * 2)
            pixel_set(img, trail_x + wave_x, y, (200, 210, 240, alpha))
            pixel_set(img, trail_x + wave_x + 1, y, (200, 210, 240, alpha))

    img.save(os.path.join(SPRITES_DIR, "enemy_hallucination.png"))
    print("  -> enemy_hallucination.png")


def make_enemy_hallucination_disguised():
    """Health pickup disguise (24x24) - looks like a green crystal/potion."""
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))

    green = (40, 200, 80)
    green_light = (80, 230, 120)
    green_dark = (25, 140, 50)
    sparkle = (220, 255, 220)

    # Potion bottle shape
    # Bottle body
    for y in range(8, 20):
        for x in range(6, 18):
            dist = abs(x - 12) + abs(y - 14)
            if dist < 9:
                if dist < 4:
                    pixel_set(img, x, y, green_light)
                elif dist < 7:
                    pixel_set(img, x, y, green)
                else:
                    pixel_set(img, x, y, green_dark)

    # Bottle neck
    for y in range(4, 9):
        for x in range(10, 14):
            pixel_set(img, x, y, green)

    # Cork
    for x in range(10, 14):
        pixel_set(img, x, 3, (140, 100, 50))
        pixel_set(img, x, 4, (120, 80, 40))

    # + symbol (health pickup look)
    for x in range(10, 14):
        pixel_set(img, x, 13, sparkle)
    for y in range(11, 16):
        pixel_set(img, 11, y, sparkle)
        pixel_set(img, 12, y, sparkle)

    # Sparkle
    pixel_set(img, 8, 10, sparkle)
    pixel_set(img, 16, 9, sparkle)

    img.save(os.path.join(SPRITES_DIR, "enemy_hallucination_disguised.png"))
    print("  -> enemy_hallucination_disguised.png")


def make_enemy_context_rot():
    """Undead/skeleton creature (48x48), sickly yellow-green."""
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))

    # Colors
    bone = (200, 190, 150)
    bone_dark = (150, 140, 110)
    bone_light = (230, 220, 180)
    rot_green = (120, 160, 40)
    rot_dark = (80, 110, 25)
    eye_glow = (180, 220, 40)
    eye_bright = (220, 255, 60)
    tatter = (90, 100, 50)

    # Skull (rows 2-16)
    for y in range(4, 16):
        skull_half = 8 - abs(y - 9)
        skull_half = max(skull_half, 4) if y < 14 else skull_half
        for x in range(24 - skull_half, 24 + skull_half):
            pixel_set(img, x, y, bone)

    # Skull shading
    for y in range(5, 14):
        pixel_set(img, 16, y, bone_dark)
        pixel_set(img, 31, y, bone_dark)
    for x in range(18, 30):
        pixel_set(img, x, 4, bone_dark)

    # Eye sockets (dark with glow)
    for y in range(7, 11):
        for x in range(18, 22):
            pixel_set(img, x, y, (30, 25, 20))
        for x in range(26, 30):
            pixel_set(img, x, y, (30, 25, 20))
    # Glowing eyes
    pixel_set(img, 19, 8, eye_glow)
    pixel_set(img, 20, 8, eye_glow)
    pixel_set(img, 19, 9, eye_bright)
    pixel_set(img, 20, 9, eye_bright)
    pixel_set(img, 27, 8, eye_glow)
    pixel_set(img, 28, 8, eye_glow)
    pixel_set(img, 27, 9, eye_bright)
    pixel_set(img, 28, 9, eye_bright)

    # Nose hole
    pixel_set(img, 23, 11, (30, 25, 20))
    pixel_set(img, 24, 11, (30, 25, 20))

    # Jaw with teeth
    for x in range(19, 29):
        pixel_set(img, x, 14, bone_dark)
    for x in range(20, 28):
        if x % 2 == 0:
            pixel_set(img, x, 15, bone_light)

    # Ribcage / torso (rows 17-30)
    for y in range(17, 30):
        # Spine
        pixel_set(img, 23, y, bone)
        pixel_set(img, 24, y, bone)
        # Ribs
        if y % 3 == 0:
            for x in range(16, 32):
                if x != 23 and x != 24:
                    pixel_set(img, x, y, bone_dark)
                    if x < 23:
                        pixel_set(img, x, y + 1, bone_dark)
                    else:
                        pixel_set(img, x, y + 1, bone_dark)

    # Rot/decay patches (green glow on bones)
    for ry, rx_list in [(8, [16, 17]), (12, [29, 30]), (20, [17, 18]), (25, [28, 29])]:
        for rx in rx_list:
            pixel_set(img, rx, ry, rot_green)
            pixel_set(img, rx, ry + 1, rot_dark)

    # Tattered robe remnants
    for y in range(22, 38):
        wave = int(math.sin(y * 0.6) * 2)
        for x in range(14 + wave, 18 + wave):
            pixel_set(img, x, y, tatter)
        for x in range(30 + wave, 34 + wave):
            pixel_set(img, x, y, tatter)

    # Arms (bone)
    for y in range(18, 32):
        pixel_set(img, 12, y, bone)
        pixel_set(img, 13, y, bone_dark)
        pixel_set(img, 34, y, bone)
        pixel_set(img, 35, y, bone_dark)

    # Legs (bone)
    for y in range(30, 44):
        for x in range(20, 23):
            pixel_set(img, x, y, bone_dark)
        for x in range(25, 28):
            pixel_set(img, x, y, bone_dark)

    # Toxic aura particles
    for px, py in [(10, 14), (36, 10), (8, 30), (38, 26), (14, 40), (34, 42)]:
        pixel_set(img, px, py, (rot_green[0], rot_green[1], rot_green[2], 150))
        pixel_set(img, px + 1, py, (rot_green[0], rot_green[1], rot_green[2], 100))

    img.save(os.path.join(SPRITES_DIR, "enemy_context_rot.png"))
    print("  -> enemy_context_rot.png")


def make_enemy_dependency_hell():
    """Dark spider/web creature (56x56), black with red markings."""
    img = Image.new("RGBA", (56, 56), (0, 0, 0, 0))

    # Colors
    body_dark = (25, 20, 30)
    body_main = (45, 35, 55)
    body_light = (65, 55, 75)
    red_mark = (180, 30, 30)
    red_dark = (120, 20, 20)
    eye_red = (220, 40, 30)
    eye_bright = (255, 80, 60)
    leg = (35, 28, 40)
    leg_dark = (20, 15, 25)
    web = (140, 130, 150, 100)

    cx, cy = 28, 28

    # Spider body (two segments)
    # Abdomen (back, larger)
    for y in range(22, 44):
        for x in range(14, 42):
            dx = x - 28
            dy = y - 34
            dist = (dx * dx) / (12 * 12) + (dy * dy) / (9 * 9)
            if dist < 1.0:
                if dist > 0.7:
                    pixel_set(img, x, y, body_dark)
                elif dist > 0.4:
                    pixel_set(img, x, y, body_main)
                else:
                    pixel_set(img, x, y, body_light)

    # Red hourglass marking on abdomen
    for y in range(30, 40):
        mark_half = 3 - abs(y - 35) // 2
        for x in range(28 - mark_half, 28 + mark_half):
            pixel_set(img, x, y, red_mark)
    pixel_set(img, 27, 35, red_dark)
    pixel_set(img, 28, 35, red_dark)

    # Cephalothorax (front, smaller)
    for y in range(14, 26):
        for x in range(20, 36):
            dx = x - 28
            dy = y - 20
            dist = (dx * dx) / (7 * 7) + (dy * dy) / (5 * 5)
            if dist < 1.0:
                if dist > 0.6:
                    pixel_set(img, x, y, body_dark)
                else:
                    pixel_set(img, x, y, body_main)

    # Multiple red eyes (spider has 8)
    eye_positions = [(24, 16), (26, 15), (30, 15), (32, 16),
                     (25, 18), (27, 17), (29, 17), (31, 18)]
    for ex, ey in eye_positions:
        pixel_set(img, ex, ey, eye_red)
        pixel_set(img, ex + 1, ey, eye_bright)

    # Fangs
    pixel_set(img, 26, 23, (200, 200, 190))
    pixel_set(img, 26, 24, (200, 200, 190))
    pixel_set(img, 30, 23, (200, 200, 190))
    pixel_set(img, 30, 24, (200, 200, 190))

    # 8 Legs (4 per side)
    leg_angles_left = [(-12, -8), (-14, -2), (-14, 6), (-10, 12)]
    leg_angles_right = [(12, -8), (14, -2), (14, 6), (10, 12)]

    for i, (dx, dy) in enumerate(leg_angles_left):
        start_x = 20
        start_y = 20 + i * 4
        end_x = start_x + dx
        end_y = start_y + dy
        # Draw segmented leg
        mid_x = (start_x + end_x) // 2
        mid_y = start_y + dy // 3
        for t in range(20):
            frac = t / 19.0
            if frac < 0.5:
                f2 = frac * 2
                lx = int(start_x + (mid_x - start_x) * f2)
                ly = int(start_y + (mid_y - start_y) * f2)
            else:
                f2 = (frac - 0.5) * 2
                lx = int(mid_x + (end_x - mid_x) * f2)
                ly = int(mid_y + (end_y - mid_y) * f2)
            pixel_set(img, lx, ly, leg)
            pixel_set(img, lx + 1, ly, leg_dark)

    for i, (dx, dy) in enumerate(leg_angles_right):
        start_x = 36
        start_y = 20 + i * 4
        end_x = start_x + dx
        end_y = start_y + dy
        mid_x = (start_x + end_x) // 2
        mid_y = start_y + dy // 3
        for t in range(20):
            frac = t / 19.0
            if frac < 0.5:
                f2 = frac * 2
                lx = int(start_x + (mid_x - start_x) * f2)
                ly = int(start_y + (mid_y - start_y) * f2)
            else:
                f2 = (frac - 0.5) * 2
                lx = int(mid_x + (end_x - mid_x) * f2)
                ly = int(mid_y + (end_y - mid_y) * f2)
            pixel_set(img, lx, ly, leg)
            pixel_set(img, lx - 1, ly, leg_dark)

    # Web threads around body (subtle)
    for angle in range(0, 360, 45):
        rad = math.radians(angle)
        for r in range(20, 28):
            wx = int(cx + math.cos(rad) * r)
            wy = int(cy + math.sin(rad) * r)
            pixel_set(img, wx, wy, web)

    img.save(os.path.join(SPRITES_DIR, "enemy_dependency_hell.png"))
    print("  -> enemy_dependency_hell.png")


# ═══════════════════════════════════════════════════════════════════════════════
# PROJECTILES
# ═══════════════════════════════════════════════════════════════════════════════

def make_projectile():
    """Magic bolt (12x8) - bright cyan/white energy ball."""
    img = Image.new("RGBA", (12, 8), (0, 0, 0, 0))

    cx, cy = 6, 4
    for y in range(8):
        for x in range(12):
            dx = x - cx
            dy = y - cy
            dist = math.sqrt(dx * dx + dy * dy)
            if dist < 4.5:
                if dist < 1.5:
                    img.putpixel((x, y), (255, 255, 255, 255))
                elif dist < 2.5:
                    img.putpixel((x, y), (180, 230, 255, 240))
                elif dist < 3.5:
                    img.putpixel((x, y), (80, 180, 255, 200))
                else:
                    img.putpixel((x, y), (40, 120, 220, 120))

    # Trail sparks
    img.putpixel((0, 3), (80, 180, 255, 80))
    img.putpixel((0, 4), (80, 180, 255, 80))
    img.putpixel((1, 2), (120, 200, 255, 60))
    img.putpixel((1, 5), (120, 200, 255, 60))

    img.save(os.path.join(SPRITES_DIR, "projectile.png"))
    print("  -> projectile.png")


def make_projectile_enemy():
    """Enemy rot bolt (12x12) - sickly green energy."""
    img = Image.new("RGBA", (12, 12), (0, 0, 0, 0))

    cx, cy = 6, 6
    for y in range(12):
        for x in range(12):
            dx = x - cx
            dy = y - cy
            dist = math.sqrt(dx * dx + dy * dy)
            if dist < 5.5:
                if dist < 2.0:
                    img.putpixel((x, y), (220, 255, 60, 255))
                elif dist < 3.5:
                    img.putpixel((x, y), (150, 200, 30, 220))
                elif dist < 4.5:
                    img.putpixel((x, y), (100, 150, 20, 160))
                else:
                    img.putpixel((x, y), (70, 110, 15, 80))

    img.save(os.path.join(SPRITES_DIR, "projectile_enemy.png"))
    print("  -> projectile_enemy.png")


def make_turret():
    """Arcane crystal turret (24x24)."""
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))

    # Colors
    base_stone = (80, 85, 78)
    base_dark = (55, 58, 52)
    crystal = (0, 200, 210)
    crystal_bright = (100, 240, 245)
    crystal_core = (200, 255, 255)
    rune = (0, 180, 190)

    # Stone base (pyramid-ish)
    for y in range(14, 24):
        width = 4 + (y - 14)
        for x in range(12 - width // 2, 12 + width // 2):
            pixel_set(img, x, y, base_stone)
    # Base outline
    for y in range(14, 24):
        width = 4 + (y - 14)
        pixel_set(img, 12 - width // 2, y, base_dark)
        pixel_set(img, 12 + width // 2 - 1, y, base_dark)
    for x in range(4, 20):
        pixel_set(img, x, 23, base_dark)

    # Rune on base
    for x in range(10, 14):
        pixel_set(img, x, 19, rune)
    pixel_set(img, 11, 18, rune)
    pixel_set(img, 12, 18, rune)
    pixel_set(img, 11, 20, rune)
    pixel_set(img, 12, 20, rune)

    # Crystal on top
    for y in range(2, 15):
        cry_half = 5 - abs(y - 8)
        cry_half = max(cry_half, 1)
        for x in range(12 - cry_half, 12 + cry_half):
            dx = abs(x - 12)
            if dx < 2 and abs(y - 7) < 3:
                pixel_set(img, x, y, crystal_core)
            elif dx < 3:
                pixel_set(img, x, y, crystal_bright)
            else:
                pixel_set(img, x, y, crystal)

    # Glow particles
    pixel_set(img, 6, 5, (0, 200, 210, 100))
    pixel_set(img, 18, 4, (0, 200, 210, 100))
    pixel_set(img, 4, 10, (0, 200, 210, 80))
    pixel_set(img, 20, 9, (0, 200, 210, 80))

    img.save(os.path.join(SPRITES_DIR, "turret.png"))
    print("  -> turret.png")


# ═══════════════════════════════════════════════════════════════════════════════
# PLATFORM TILES
# ═══════════════════════════════════════════════════════════════════════════════

def make_floor_tile():
    """Stone brick platform (1200x32), mossy grey-green."""
    img = Image.new("RGBA", (1200, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Base stone color
    d.rectangle([0, 0, 1199, 31], fill=STONE_GRAY)

    # Brick pattern
    brick_w = 40
    brick_h = 14
    for row in range(3):
        y = row * brick_h
        offset = (row % 2) * (brick_w // 2)
        for col in range(-1, 1200 // brick_w + 2):
            bx = col * brick_w + offset
            # Brick fill with slight color variation
            r_var = random.randint(-8, 8)
            brick_col = (STONE_GRAY[0] + r_var, STONE_GRAY[1] + r_var, STONE_GRAY[2] + r_var - 3)
            d.rectangle([bx + 1, y + 1, bx + brick_w - 2, y + brick_h - 2], fill=brick_col)
            # Mortar lines (darker)
            d.line([bx, y, bx, y + brick_h], fill=STONE_DARK, width=1)
            d.line([bx, y, bx + brick_w, y], fill=STONE_DARK, width=1)

    # Top edge (lighter, worn)
    for x in range(1200):
        variation = random.randint(-5, 10)
        col = (STONE_LIGHT[0] + variation, STONE_LIGHT[1] + variation, STONE_LIGHT[2] + variation)
        pixel_set(img, x, 0, col)
        pixel_set(img, x, 1, col)

    # Moss patches along top
    for i in range(60):
        mx = random.randint(0, 1199)
        mw = random.randint(8, 25)
        for dx in range(mw):
            x = mx + dx
            if x >= 1200:
                break
            depth = random.randint(2, 6)
            for dy in range(depth):
                r_var = random.randint(-10, 10)
                moss_col = (MOSS_ACCENT[0] + r_var, MOSS_ACCENT[1] + r_var, MOSS_ACCENT[2] + r_var)
                pixel_set(img, x, dy, moss_col)

    # Bottom edge (shadow)
    for x in range(1200):
        pixel_set(img, x, 30, STONE_DARK)
        pixel_set(img, x, 31, (40, 42, 38))

    img.save(os.path.join(TILES_DIR, "floor.png"))
    print("  -> floor.png")


def make_wall_tile():
    """Castle stone wall (32x700)."""
    img = Image.new("RGBA", (32, 700), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    d.rectangle([0, 0, 31, 699], fill=STONE_GRAY)

    # Brick pattern (vertical)
    brick_h = 24
    brick_w = 14
    for col in range(3):
        x = col * brick_w
        offset = (col % 2) * (brick_h // 2)
        for row in range(-1, 700 // brick_h + 2):
            by = row * brick_h + offset
            r_var = random.randint(-10, 10)
            brick_col = (STONE_GRAY[0] + r_var, STONE_GRAY[1] + r_var - 2, STONE_GRAY[2] + r_var - 4)
            d.rectangle([x + 1, by + 1, x + brick_w - 2, by + brick_h - 2], fill=brick_col)
            d.line([x, by, x + brick_w, by], fill=STONE_DARK, width=1)
            d.line([x, by, x, by + brick_h], fill=STONE_DARK, width=1)

    # Vine patches (green streaks running down)
    for i in range(5):
        vx = random.randint(4, 28)
        vy_start = random.randint(0, 200)
        vine_len = random.randint(60, 200)
        for dy in range(vine_len):
            vy = vy_start + dy
            if vy >= 700:
                break
            wave = int(math.sin(vy * 0.15) * 2)
            r_var = random.randint(-10, 10)
            vine_col = (FOREST_GREEN[0] + r_var, FOREST_GREEN[1] + r_var, FOREST_GREEN[2] + r_var)
            pixel_set(img, vx + wave, vy, vine_col)
            pixel_set(img, vx + wave + 1, vy, vine_col)
            # Leaves every so often
            if dy % 20 < 3:
                for lx in range(-2, 3):
                    pixel_set(img, vx + wave + lx, vy, (MOSS_GREEN[0] + r_var, MOSS_GREEN[1] + r_var, MOSS_GREEN[2] + r_var))

    # Torch sconce (glowing) at a couple heights
    for torch_y in [150, 400]:
        # Bracket
        for ty in range(torch_y, torch_y + 8):
            pixel_set(img, 14, ty, (100, 80, 50))
            pixel_set(img, 15, ty, (100, 80, 50))
        # Flame
        for ty in range(torch_y - 6, torch_y):
            flame_half = 3 - abs(ty - (torch_y - 3))
            for fx in range(-flame_half, flame_half + 1):
                if ty < torch_y - 3:
                    pixel_set(img, 15 + fx, ty, (255, 200, 50))
                else:
                    pixel_set(img, 15 + fx, ty, (255, 140, 30))
        # Glow on wall near torch
        for gy in range(torch_y - 10, torch_y + 10):
            for gx in range(0, 32):
                if 0 <= gy < 700:
                    existing = img.getpixel((gx, gy))
                    if existing[3] > 0:
                        dist = abs(gx - 15) + abs(gy - torch_y)
                        if dist < 12:
                            glow = max(0, 40 - dist * 3)
                            new_col = (min(255, existing[0] + glow), min(255, existing[1] + glow // 2), existing[2], existing[3])
                            img.putpixel((gx, gy), new_col)

    img.save(os.path.join(TILES_DIR, "wall.png"))
    print("  -> wall.png")


def make_ceiling_tile():
    """Castle ceiling (1200x32)."""
    img = Image.new("RGBA", (1200, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    dark_stone = (50, 48, 45)
    d.rectangle([0, 0, 1199, 31], fill=dark_stone)

    # Brick pattern
    brick_w = 40
    brick_h = 14
    for row in range(3):
        y = row * brick_h
        offset = (row % 2) * (brick_w // 2)
        for col in range(-1, 1200 // brick_w + 2):
            bx = col * brick_w + offset
            r_var = random.randint(-5, 5)
            brick_col = (dark_stone[0] + r_var, dark_stone[1] + r_var, dark_stone[2] + r_var)
            d.rectangle([bx + 1, y + 1, bx + brick_w - 2, y + brick_h - 2], fill=brick_col)
            d.line([bx, y, bx, y + brick_h], fill=(35, 33, 30), width=1)
            d.line([bx, y, bx + brick_w, y], fill=(35, 33, 30), width=1)

    # Dripping stalactite-like elements and cobwebs
    for i in range(30):
        sx = random.randint(0, 1199)
        slen = random.randint(4, 12)
        for dy in range(slen):
            alpha = 255 - dy * 20
            pixel_set(img, sx, 31 - slen + dy, (dark_stone[0] + 10, dark_stone[1] + 10, dark_stone[2] + 10))

    # Bottom edge (shadow)
    for x in range(1200):
        pixel_set(img, x, 31, (35, 33, 30))

    img.save(os.path.join(TILES_DIR, "ceiling.png"))
    print("  -> ceiling.png")


# ═══════════════════════════════════════════════════════════════════════════════
# PARALLAX BACKGROUNDS (1920x600)
# ═══════════════════════════════════════════════════════════════════════════════

def make_bg_far():
    """Layer 1: Twilight sky with stars and distant mountains."""
    img = Image.new("RGBA", (1920, 600), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Sky gradient (deep purple to midnight blue)
    for y in range(600):
        frac = y / 599.0
        r = int(20 + frac * 15)
        g = int(10 + frac * 20)
        b = int(60 - frac * 20)
        d.line([0, y, 1919, y], fill=(r, g, b))

    # Large moon
    moon_cx, moon_cy = 1500, 100
    moon_r = 50
    for y in range(moon_cy - moon_r, moon_cy + moon_r):
        for x in range(moon_cx - moon_r, moon_cx + moon_r):
            dist = math.sqrt((x - moon_cx) ** 2 + (y - moon_cy) ** 2)
            if dist < moon_r:
                # Crescent: darken the right side
                brightness = max(0, 1.0 - dist / moon_r)
                shadow_x = x - moon_cx + 15  # offset for crescent
                shadow_dist = math.sqrt(shadow_x ** 2 + (y - moon_cy) ** 2)
                if shadow_dist < moon_r * 0.85:
                    # In shadow
                    continue
                r_val = int(200 + brightness * 55)
                g_val = int(190 + brightness * 55)
                b_val = int(160 + brightness * 40)
                pixel_set(img, x, y, (r_val, g_val, b_val))

    # Moon glow
    for y in range(moon_cy - moon_r - 20, moon_cy + moon_r + 20):
        for x in range(moon_cx - moon_r - 20, moon_cx + moon_r + 20):
            dist = math.sqrt((x - moon_cx) ** 2 + (y - moon_cy) ** 2)
            if moon_r < dist < moon_r + 18:
                alpha = int(60 * (1.0 - (dist - moon_r) / 18.0))
                existing = img.getpixel((x, y))
                new_r = min(255, existing[0] + alpha // 2)
                new_g = min(255, existing[1] + alpha // 2)
                new_b = min(255, existing[2] + alpha // 3)
                img.putpixel((x, y), (new_r, new_g, new_b, 255))

    # Stars
    for i in range(200):
        sx = random.randint(0, 1919)
        sy = random.randint(0, 350)
        brightness = random.randint(150, 255)
        size = random.choice([1, 1, 1, 2])
        star_col = (brightness, brightness, min(255, brightness + 20))
        pixel_set(img, sx, sy, star_col)
        if size == 2:
            pixel_set(img, sx + 1, sy, star_col)
            pixel_set(img, sx, sy + 1, star_col)

    # Twinkling bright stars (with cross pattern)
    for i in range(15):
        sx = random.randint(0, 1919)
        sy = random.randint(0, 250)
        col = (255, 255, 230)
        pixel_set(img, sx, sy, col)
        pixel_set(img, sx - 1, sy, (200, 200, 190))
        pixel_set(img, sx + 1, sy, (200, 200, 190))
        pixel_set(img, sx, sy - 1, (200, 200, 190))
        pixel_set(img, sx, sy + 1, (200, 200, 190))

    # Distant mountain range (dark purple silhouettes)
    mountain_heights = []
    h = 400
    for x in range(1920):
        h += random.uniform(-3, 3)
        # Occasional peaks
        if random.random() < 0.003:
            h -= random.randint(30, 80)
        h = max(280, min(460, h))
        mountain_heights.append(int(h))

    # Smooth the heights
    smoothed = mountain_heights[:]
    for i in range(3):
        new_smooth = smoothed[:]
        for x in range(2, 1918):
            new_smooth[x] = (smoothed[x - 2] + smoothed[x - 1] + smoothed[x] + smoothed[x + 1] + smoothed[x + 2]) // 5
        smoothed = new_smooth

    for x in range(1920):
        peak_y = smoothed[x]
        for y in range(peak_y, 600):
            depth = y - peak_y
            # Gradient on mountains
            r = max(0, 35 - depth // 15)
            g = max(0, 20 - depth // 20)
            b = max(0, 55 - depth // 12)
            pixel_set(img, x, y, (r, g, b))
        # Snow caps on tallest peaks
        if peak_y < 340:
            for dy in range(0, min(8, 340 - peak_y)):
                pixel_set(img, x, peak_y + dy, (180, 175, 190))

    # Second mountain range (slightly closer, slightly lighter)
    h2 = 440
    mount2 = []
    for x in range(1920):
        h2 += random.uniform(-2, 2)
        if random.random() < 0.005:
            h2 -= random.randint(20, 50)
        h2 = max(380, min(500, h2))
        mount2.append(int(h2))
    # Smooth
    for i in range(3):
        new_s = mount2[:]
        for x in range(2, 1918):
            new_s[x] = (mount2[x - 2] + mount2[x - 1] + mount2[x] + mount2[x + 1] + mount2[x + 2]) // 5
        mount2 = new_s

    for x in range(1920):
        peak_y = mount2[x]
        for y in range(peak_y, 600):
            existing = img.getpixel((x, y))
            r = max(existing[0], 45)
            g = max(existing[1], 30)
            b = max(existing[2], 65)
            pixel_set(img, x, y, (r, g, b))

    img.save(os.path.join(BG_DIR, "bg_far.png"))
    print("  -> bg_far.png")


def make_bg_mid():
    """Layer 2: Dark enchanted forest silhouettes with glowing elements."""
    img = Image.new("RGBA", (1920, 600), (0, 0, 0, 0))

    # Forest silhouettes
    tree_positions = []
    x = 0
    while x < 1920:
        tree_positions.append(x)
        x += random.randint(40, 120)

    for tx in tree_positions:
        tree_height = random.randint(200, 400)
        tree_top = 600 - tree_height
        trunk_width = random.randint(8, 16)

        # Trunk
        for y in range(tree_top + tree_height // 3, 600):
            for dx in range(-trunk_width // 2, trunk_width // 2):
                x = tx + dx
                if 0 <= x < 1920:
                    # Darker toward center
                    dist_from_center = abs(dx)
                    r = 15 + dist_from_center
                    g = 25 + dist_from_center * 2
                    b = 12 + dist_from_center
                    pixel_set(img, x, y, (r, g, b))

        # Canopy (triangular/conical for evergreen look)
        canopy_layers = random.randint(3, 5)
        for layer in range(canopy_layers):
            layer_y = tree_top + layer * (tree_height // (canopy_layers * 2))
            layer_width = (canopy_layers - layer) * random.randint(12, 22)
            layer_height = tree_height // (canopy_layers * 2) + 10

            for dy in range(layer_height):
                y = layer_y + dy
                if y >= 600:
                    break
                row_width = int(layer_width * (1.0 - dy / layer_height))
                for dx in range(-row_width, row_width):
                    x = tx + dx
                    if 0 <= x < 1920:
                        r = random.randint(10, 25)
                        g = random.randint(30, 50)
                        b = random.randint(8, 20)
                        existing = img.getpixel((x, y))
                        if existing[3] == 0 or existing[1] < g:
                            pixel_set(img, x, y, (r, g, b, 220))

    # Glowing mushrooms on the ground
    for i in range(25):
        mx = random.randint(0, 1919)
        my = random.randint(560, 595)
        glow_color = random.choice([
            (80, 200, 160),   # Teal
            (100, 180, 255),  # Blue
            (200, 150, 255),  # Purple
        ])

        # Mushroom cap
        cap_r = random.randint(4, 8)
        for dy in range(-cap_r, 1):
            for dx in range(-cap_r, cap_r + 1):
                dist = math.sqrt(dx * dx + dy * dy)
                if dist < cap_r:
                    x = mx + dx
                    y = my + dy
                    if 0 <= x < 1920 and 0 <= y < 600:
                        alpha = int(200 * (1.0 - dist / cap_r))
                        pixel_set(img, x, y, (glow_color[0], glow_color[1], glow_color[2], alpha))

        # Stem
        for dy in range(0, cap_r + 2):
            pixel_set(img, mx, my + dy, (180, 170, 150, 180))

        # Glow halo
        glow_r = cap_r + 6
        for dy in range(-glow_r, glow_r + 1):
            for dx in range(-glow_r, glow_r + 1):
                dist = math.sqrt(dx * dx + dy * dy)
                if cap_r < dist < glow_r:
                    x = mx + dx
                    y = my + dy
                    if 0 <= x < 1920 and 0 <= y < 600:
                        alpha = int(40 * (1.0 - (dist - cap_r) / (glow_r - cap_r)))
                        existing = img.getpixel((x, y))
                        new_r = min(255, existing[0] + glow_color[0] * alpha // 255)
                        new_g = min(255, existing[1] + glow_color[1] * alpha // 255)
                        new_b = min(255, existing[2] + glow_color[2] * alpha // 255)
                        new_a = max(existing[3], alpha)
                        img.putpixel((x, y), (new_r, new_g, new_b, new_a))

    # Fireflies (scattered glowing dots)
    for i in range(40):
        fx = random.randint(0, 1919)
        fy = random.randint(200, 580)
        ff_col = random.choice([
            (255, 255, 150, 200),
            (200, 255, 180, 180),
            (255, 220, 100, 160),
        ])
        pixel_set(img, fx, fy, ff_col)
        # Small glow
        for dx in [-1, 0, 1]:
            for dy in [-1, 0, 1]:
                if dx == 0 and dy == 0:
                    continue
                gx, gy = fx + dx, fy + dy
                if 0 <= gx < 1920 and 0 <= gy < 600:
                    pixel_set(img, gx, gy, (ff_col[0], ff_col[1], ff_col[2], ff_col[3] // 3))

    img.save(os.path.join(BG_DIR, "bg_mid.png"))
    print("  -> bg_mid.png")


def make_bg_near():
    """Layer 3: Foreground mushrooms, vines, magical particles."""
    img = Image.new("RGBA", (1920, 600), (0, 0, 0, 0))

    # Large foreground mushrooms (silhouetted, darker)
    for i in range(12):
        mx = random.randint(0, 1919)
        my = random.randint(540, 590)
        cap_r = random.randint(15, 35)
        stem_h = random.randint(20, 50)
        stem_w = random.randint(4, 10)

        mush_col = (10, 18, 8, 180)
        mush_edge = (15, 30, 12, 200)

        # Stem
        for dy in range(0, stem_h):
            for dx in range(-stem_w // 2, stem_w // 2 + 1):
                x = mx + dx
                y = my + dy
                if 0 <= x < 1920 and 0 <= y < 600:
                    pixel_set(img, x, y, mush_col)

        # Cap
        for dy in range(-cap_r, 2):
            for dx in range(-cap_r, cap_r + 1):
                dist = math.sqrt(dx * dx + dy * dy)
                if dist < cap_r and dy <= 0:
                    x = mx + dx
                    y = my + dy
                    if 0 <= x < 1920 and 0 <= y < 600:
                        if dist > cap_r - 2:
                            pixel_set(img, x, y, mush_edge)
                        else:
                            pixel_set(img, x, y, mush_col)

        # Spots on cap (bioluminescent)
        for s in range(random.randint(2, 5)):
            sx_off = random.randint(-cap_r // 2, cap_r // 2)
            sy_off = random.randint(-cap_r + 2, -2)
            spot_col = random.choice([
                (80, 200, 160, 150),
                (150, 100, 220, 150),
                (200, 180, 100, 150),
            ])
            for dsx in range(-2, 3):
                for dsy in range(-2, 3):
                    if dsx * dsx + dsy * dsy <= 4:
                        px = mx + sx_off + dsx
                        py = my + sy_off + dsy
                        if 0 <= px < 1920 and 0 <= py < 600:
                            pixel_set(img, px, py, spot_col)

    # Hanging vines from top
    for i in range(20):
        vx = random.randint(0, 1919)
        vine_len = random.randint(40, 150)
        vine_col = (20, 45, 15, 160)
        leaf_col = (30, 65, 20, 180)

        for dy in range(vine_len):
            wave = int(math.sin(dy * 0.2 + i) * 3)
            x = vx + wave
            if 0 <= x < 1920 and dy < 600:
                pixel_set(img, x, dy, vine_col)
                # Leaves
                if dy % 12 < 3:
                    for lx in range(-3, 4):
                        if 0 <= x + lx < 1920:
                            pixel_set(img, x + lx, dy, leaf_col)

    # Magical floating particles
    for i in range(60):
        px = random.randint(0, 1919)
        py = random.randint(100, 580)
        p_size = random.choice([1, 2, 2, 3])
        p_col = random.choice([
            (180, 220, 255, 120),   # Blue sparkle
            (220, 200, 255, 100),   # Purple sparkle
            (255, 230, 180, 110),   # Gold sparkle
            (180, 255, 200, 100),   # Green sparkle
        ])
        for pdx in range(p_size):
            for pdy in range(p_size):
                if 0 <= px + pdx < 1920 and 0 <= py + pdy < 600:
                    pixel_set(img, px + pdx, py + pdy, p_col)

    # Ground fog at bottom
    for y in range(570, 600):
        fog_alpha = int(60 * (y - 570) / 30.0)
        for x in range(1920):
            wave = math.sin(x * 0.02 + y * 0.1) * 10
            if random.random() < 0.3 + wave * 0.01:
                pixel_set(img, x, y, (100, 110, 130, fog_alpha))

    img.save(os.path.join(BG_DIR, "bg_near.png"))
    print("  -> bg_near.png")


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    print("Generating fantasy/medieval pixel art assets...")
    print()

    print("Player sprites:")
    make_player_striker()
    make_player_engineer()
    make_player_downed()
    print()

    print("Enemy sprites:")
    make_enemy_basic()
    make_enemy_merge_conflict()
    make_enemy_hallucination()
    make_enemy_hallucination_disguised()
    make_enemy_context_rot()
    make_enemy_dependency_hell()
    print()

    print("Projectile sprites:")
    make_projectile()
    make_projectile_enemy()
    make_turret()
    print()

    print("Platform tiles:")
    make_floor_tile()
    make_wall_tile()
    make_ceiling_tile()
    print()

    print("Parallax backgrounds:")
    make_bg_far()
    make_bg_mid()
    make_bg_near()
    print()

    print("All assets generated!")
