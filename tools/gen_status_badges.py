"""Generates the enamelled status badges (owner feedback 2026-11-05 L8).

Every status gets a layered vector badge in the game's gold-trim style:

    dark contact edge > bevelled gold bezel > inset groove > coloured enamel (radial
    gradient) > a status motif clipped to the enamel (goo, flames, arcs, sigil, mist...)
    > edge vignette > gloss > the glyph (drop shadow, dark outline, light fill)

The frame shape still says what kind of status it is (art bible colour-blind rule):
buff = round, debuff = rounded square, Rune = hexagon.

Glyphs come from `rldb/assets/icons/status/<key>.svg` (game-icons.net, CC BY 3.0, see
`rldb/assets/CREDITS.md`), except Paralyse, whose lightning bolt is drawn here (the owner
asked for "electric yellow with a bolt"). Output: `rldb/assets/icons/status/badge_<key>.svg`
(128-unit viewBox; Godot rasterises them at 2x with mipmaps, see the .import files).

    python -I -X utf8 tools/gen_status_badges.py

Stdlib only and deterministic: the same input always writes the same files.
"""
from __future__ import annotations

import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON_DIR = os.path.join(ROOT, "rldb", "assets", "icons", "status")

BUFFS = ["retain", "eternal", "pierce", "cleanse", "medic", "infiltrate", "nimble"]
DEBUFFS = ["reveal", "burn", "paralyse", "curse", "poison", "blind", "debilitate"]
KEYS = ["rune"] + BUFFS + DEBUFFS

# Fraction of the badge the glyph spans.
GLYPH_K = 0.66

# Hand-drawn lightning bolt for Paralyse, in the glyphs' 512 space.
BOLT = ("M300 28 L118 286 L232 286 L178 486 L398 196 L278 196 L344 28 Z")

# Enamel colours (centre highlight, mid, deep, rim) and the glyph outline colour.
PALETTE = {
    "poison":     (["#7fd04a", "#2f7a22", "#103a10", "#061806"], "#061806"),
    "burn":       (["#ffe07a", "#f0701e", "#a0180a", "#3a0604"], "#3a0602"),
    "paralyse":   (["#fff7a8", "#f4cc22", "#b07400", "#4a2c00"], "#3a2200"),
    "curse":      (["#cf98f6", "#8040c8", "#3c1268", "#16041f"], "#1a0530"),
    "blind":      (["#8a8a9a", "#44445a", "#191924", "#07070c"], "#06060a"),
    "debilitate": (["#d8ccb2", "#8e826a", "#40382c", "#1a1612"], "#1a140c"),
    "reveal":     (["#ffa8d8", "#d0408a", "#640c36", "#24020f"], "#3a0420"),
    "eternal":    (["#fffbe0", "#f2c64e", "#b07a14", "#4a2c04"], "#4a2804"),
    "cleanse":    (["#ffffff", "#cfeaff", "#5aa6e6", "#164e8e"], "#0f3a6a"),
    "medic":      (["#c4fad4", "#3cc070", "#137a40", "#053018"], "#053018"),
    "nimble":     (["#b4fff6", "#22b8ae", "#0a6660", "#032824"], "#032e2a"),
    "pierce":     (["#ffffff", "#c8d4e0", "#76889c", "#26303c"], "#141c26"),
    "infiltrate": (["#9a9af0", "#40409c", "#15154c", "#05051a"], "#04041a"),
    "retain":     (["#ffd2a6", "#d27c3a", "#7a3a14", "#2e1406"], "#2e1204"),
    "rune":       (["#c4e2ff", "#4a8ee8", "#16449a", "#061a40"], "#061a40"),
}

# Glyph fill (top, bottom) per status; default is warm white.
GLYPH_FILL = {
    "poison": ("#f2ffd8", "#bfe89a"),
    "burn": ("#fffbe8", "#ffd08a"),
    "paralyse": ("#ffffff", "#fff2a0"),
    "curse": ("#fbf2ff", "#dcc0f4"),
    "eternal": ("#ffffff", "#fff0c0"),
    "cleanse": ("#ffffff", "#e8f6ff"),
    "infiltrate": ("#eef2ff", "#b8c4f0"),
}


def kind(key: str) -> str:
    if key == "rune":
        return "rune"
    return "buff" if key in BUFFS else "debuff"


# ---------------------------------------------------------------- shapes

def rounded_square(inset: float, radius: float) -> str:
    a, b, r = inset, 128.0 - inset, radius
    return (f"M{a + r:.2f} {a:.2f} H{b - r:.2f} A{r:.2f} {r:.2f} 0 0 1 {b:.2f} {a + r:.2f} "
            f"V{b - r:.2f} A{r:.2f} {r:.2f} 0 0 1 {b - r:.2f} {b:.2f} H{a + r:.2f} "
            f"A{r:.2f} {r:.2f} 0 0 1 {a:.2f} {b - r:.2f} V{a + r:.2f} A{r:.2f} {r:.2f} 0 0 1 {a + r:.2f} {a:.2f} Z")


def circle(r: float) -> str:
    return (f"M{64 - r:.2f} 64 A{r:.2f} {r:.2f} 0 1 1 {64 + r:.2f} 64 "
            f"A{r:.2f} {r:.2f} 0 1 1 {64 - r:.2f} 64 Z")


def hexagon(r: float, round_k: float = 0.16) -> str:
    """Pointy-top hexagon of circumradius r with slightly rounded corners."""
    pts = [(64 + r * math.cos(math.radians(-90 + 60 * i)), 64 + r * math.sin(math.radians(-90 + 60 * i))) for i in range(6)]
    out = []
    for i in range(6):
        p0 = pts[i - 1]
        p1 = pts[i]
        p2 = pts[(i + 1) % 6]
        a = (p1[0] + (p0[0] - p1[0]) * round_k, p1[1] + (p0[1] - p1[1]) * round_k)
        b = (p1[0] + (p2[0] - p1[0]) * round_k, p1[1] + (p2[1] - p1[1]) * round_k)
        out.append(("M" if i == 0 else "L") + f"{a[0]:.2f} {a[1]:.2f}")
        out.append(f"Q{p1[0]:.2f} {p1[1]:.2f} {b[0]:.2f} {b[1]:.2f}")
    return " ".join(out) + " Z"


def frame(k: str):
    """(contact edge, bezel, groove, enamel) paths of a kind."""
    if k == "buff":
        return circle(63.5), circle(61.5), circle(55.5), circle(53.0)
    if k == "debuff":
        return rounded_square(1.0, 30.0), rounded_square(3.0, 28.0), rounded_square(9.5, 22.5), rounded_square(12.0, 20.0)
    return hexagon(64.5), hexagon(62.0), hexagon(55.0), hexagon(52.0)


# ---------------------------------------------------------------- motifs (128 space, clipped to the enamel)

def _circles(spec, fill="none", stroke="none", sw=0.0, op=1.0):
    return "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" opacity="{op}"/>' for x, y, r in spec)


def motif(key: str) -> str:
    if key == "poison":
        goo = ("M8 8 H120 V34 C113 34 110 37 110 43 C110 52 101 52 101 43 C101 36 97 32 90 33 "
               "C84 34 83 40 83 55 C83 65 74 65 74 55 C74 42 70 35 62 35 C56 35 54 39 54 47 "
               "C54 54 46 54 46 47 C46 38 40 33 32 34 C25 35 24 43 24 62 C24 72 15 72 15 62 "
               "C15 46 8 40 8 38 Z")
        return (f'<path d="{goo}" fill="url(#goo)"/>'
                f'<path d="{goo}" fill="none" stroke="#c8ff80" stroke-width="1.6" opacity="0.55"/>'
                + _circles([(78.5, 72, 3.2), (19.5, 78, 2.6), (50, 60, 2.0)], fill="url(#goo)")
                + _circles([(77.5, 54, 1.3), (22.5, 60, 1.2), (105, 42, 1.1)], fill="#efffd0", op=0.8)
                + _circles([(30, 100, 7), (46, 108, 3.8), (99, 97, 5.5), (88, 108, 3.2), (66, 104, 2.4)],
                           fill="#9be04a", op=0.16)
                + _circles([(30, 100, 7), (46, 108, 3.8), (99, 97, 5.5), (88, 108, 3.2), (66, 104, 2.4)],
                           stroke="#b6f070", sw=1.6, op=0.6))
    if key == "burn":
        flames = ("M8 120 C14 98 14 86 26 70 C27 84 35 90 39 78 C42 90 49 82 50 60 C61 76 62 92 69 74 "
                  "C75 86 84 80 81 58 C96 74 100 90 107 80 C110 94 120 100 120 120 Z")
        inner = ("M18 120 C22 104 26 98 32 90 C34 100 40 102 44 94 C48 104 56 98 58 84 C64 96 68 104 74 92 "
                 "C80 102 88 98 90 86 C98 98 104 106 110 120 Z")
        return (f'<path d="{flames}" fill="url(#flame)" opacity="0.85"/>'
                f'<path d="{inner}" fill="#ffe9a0" opacity="0.45"/>'
                + _circles([(24, 46, 1.8), (98, 40, 1.5), (40, 28, 1.2), (86, 22, 1.4), (110, 60, 1.1), (16, 64, 1.2)],
                           fill="#ffd27a", op=0.9))
    if key == "paralyse":
        arcs = ["M8 40 L22 46 L18 52 L34 58 L30 63 L46 66",
                "M120 30 L104 40 L110 45 L94 52 L99 58 L84 62",
                "M10 98 L26 92 L24 100 L40 96 L38 104 L52 102",
                "M118 96 L102 100 L106 106 L90 108"]
        out = ""
        for a in arcs:
            out += f'<path d="{a}" fill="none" stroke="#fffbe0" stroke-width="5" stroke-linejoin="round" stroke-linecap="round" opacity="0.28"/>'
            out += f'<path d="{a}" fill="none" stroke="#ffffff" stroke-width="1.8" stroke-linejoin="round" stroke-linecap="round" opacity="0.9"/>'
        return out
    if key == "curse":
        star = []
        for i in range(5):
            ang = math.radians(-90 + 144 * i)
            star.append(f"{64 + 42 * math.cos(ang):.2f} {64 + 42 * math.sin(ang):.2f}")
        ticks = ""
        for i in range(24):
            ang = math.radians(i * 15)
            r0, r1 = 45, 49 if i % 2 == 0 else 47
            ticks += f"M{64 + r0 * math.cos(ang):.2f} {64 + r0 * math.sin(ang):.2f} L{64 + r1 * math.cos(ang):.2f} {64 + r1 * math.sin(ang):.2f} "
        smoke = ("M6 112 C26 98 34 116 52 104 C66 94 80 112 98 100 C108 94 116 100 124 96 "
                 "M4 26 C20 34 30 18 46 26")
        return (f'<path d="{smoke}" fill="none" stroke="#14041e" stroke-width="9" stroke-linecap="round" opacity="0.45"/>'
                f'<circle cx="64" cy="64" r="42" fill="none" stroke="#e8ccff" stroke-width="1.4" opacity="0.35"/>'
                f'<path d="M{" L".join(star)} Z" fill="none" stroke="#e8ccff" stroke-width="1.2" opacity="0.28"/>'
                f'<path d="{ticks}" stroke="#e8ccff" stroke-width="1.2" opacity="0.35"/>')
    if key == "blind":
        return ('<rect x="0" y="46" width="128" height="36" fill="url(#mist)"/>'
                '<path d="M4 58 C28 50 44 66 66 58 C86 50 100 64 124 56" fill="none" stroke="#000" stroke-width="7" stroke-linecap="round" opacity="0.35"/>'
                '<path d="M4 74 C30 82 50 68 72 76 C92 84 108 72 124 78" fill="none" stroke="#000" stroke-width="6" stroke-linecap="round" opacity="0.3"/>'
                '<path d="M10 40 C30 34 40 44 56 38" fill="none" stroke="#c8c8d8" stroke-width="1.4" stroke-linecap="round" opacity="0.25"/>')
    if key == "debilitate":
        cracks = ("M14 30 L30 42 L26 54 L40 62 M30 42 L44 36 "
                  "M114 40 L98 50 L102 62 L88 70 M98 50 L92 40 "
                  "M20 110 L34 98 L46 104 L54 92 M34 98 L30 88 "
                  "M112 106 L96 98 L90 108")
        return (f'<path d="{cracks}" fill="none" stroke="#fff6e0" stroke-width="1.2" opacity="0.35" transform="translate(0.8 0.9)"/>'
                f'<path d="{cracks}" fill="none" stroke="#120e08" stroke-width="2.2" stroke-linejoin="round" opacity="0.75"/>')
    if key == "reveal":
        rays = ""
        for i in range(16):
            ang = math.radians(i * 22.5 + 11.25)
            rays += f"M{64 + 30 * math.cos(ang):.2f} {64 + 30 * math.sin(ang):.2f} L{64 + 58 * math.cos(ang):.2f} {64 + 58 * math.sin(ang):.2f} "
        return (f'<path d="{rays}" stroke="#ffd6ee" stroke-width="2.2" stroke-linecap="round" opacity="0.32"/>'
                '<circle cx="64" cy="64" r="30" fill="#ffd0ea" opacity="0.14"/>')
    if key == "eternal":
        rays = ""
        for i in range(16):
            ang0 = math.radians(i * 22.5 - 4)
            ang1 = math.radians(i * 22.5 + 4)
            rays += (f'<path d="M64 64 L{64 + 70 * math.cos(ang0):.2f} {64 + 70 * math.sin(ang0):.2f} '
                     f'L{64 + 70 * math.cos(ang1):.2f} {64 + 70 * math.sin(ang1):.2f} Z" fill="#fff8d0" opacity="0.30"/>')
        return rays + '<circle cx="64" cy="64" r="38" fill="none" stroke="#fff4c0" stroke-width="1.2" opacity="0.5"/>'
    if key == "cleanse":
        def spark(x, y, s, op):
            return (f'<path d="M{x} {y - s} Q{x + s * 0.18} {y - s * 0.18} {x + s} {y} Q{x + s * 0.18} {y + s * 0.18} {x} {y + s} '
                    f'Q{x - s * 0.18} {y + s * 0.18} {x - s} {y} Q{x - s * 0.18} {y - s * 0.18} {x} {y - s} Z" fill="#ffffff" opacity="{op}"/>')
        return ('<path d="M10 92 C30 82 46 100 64 92 C82 84 98 100 118 90" fill="none" stroke="#ffffff" stroke-width="2.6" stroke-linecap="round" opacity="0.5"/>'
                '<path d="M14 104 C34 96 48 110 66 104 C84 98 100 110 116 102" fill="none" stroke="#2a7ac8" stroke-width="2" stroke-linecap="round" opacity="0.35"/>'
                + spark(26, 34, 7, 0.85) + spark(100, 30, 5, 0.75) + spark(104, 70, 4, 0.6) + spark(22, 70, 3.5, 0.6))
    if key == "medic":
        return ('<path d="M52 18 H76 V52 H110 V76 H76 V110 H52 V76 H18 V52 H52 Z" fill="#ffffff" opacity="0.16"/>'
                '<circle cx="64" cy="64" r="34" fill="url(#halo)"/>')
    if key == "nimble":
        return ('<path d="M10 42 C38 36 58 46 84 38 M16 56 C40 52 52 60 74 54 M12 86 C40 92 60 80 94 88 M20 100 C44 104 58 96 80 100" '
                'fill="none" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round" opacity="0.42"/>'
                '<path d="M84 38 C96 34 104 40 100 46 C97 50 92 46 95 43" fill="none" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round" opacity="0.42"/>')
    if key == "pierce":
        return ('<path d="M-10 92 L92 -10 L112 -10 L10 92 Z" fill="url(#glint)" opacity="0.55" transform="translate(14 22)"/>'
                '<path d="M30 112 L112 30" stroke="#ffffff" stroke-width="1.2" opacity="0.55"/>')
    if key == "infiltrate":
        return ('<path d="M4 118 C18 96 8 84 22 74 C30 68 26 60 18 58 M124 116 C108 98 122 86 106 74 C98 68 104 58 112 58 '
                'M40 126 C44 108 34 102 40 94 M90 126 C86 110 96 104 88 94" fill="none" stroke="#000008" stroke-width="7" stroke-linecap="round" opacity="0.55"/>'
                '<path d="M4 118 C18 96 8 84 22 74 M124 116 C108 98 122 86 106 74" fill="none" stroke="#7a7ae0" stroke-width="1.2" opacity="0.4"/>')
    if key == "retain":
        return ('<circle cx="64" cy="64" r="42" fill="none" stroke="#ffe2c4" stroke-width="1.4" opacity="0.32"/>'
                '<circle cx="64" cy="64" r="37" fill="none" stroke="#3a1606" stroke-width="1.6" opacity="0.4"/>'
                + "".join(f'<circle cx="{64 + 42 * math.cos(math.radians(a)):.2f}" cy="{64 + 42 * math.sin(math.radians(a)):.2f}" r="2.2" fill="#ffe2c4" opacity="0.45"/>' for a in range(0, 360, 45)))
    if key == "rune":
        ticks = ""
        for i in range(18):
            ang = math.radians(i * 20)
            ticks += f"M{64 + 36 * math.cos(ang):.2f} {64 + 36 * math.sin(ang):.2f} L{64 + (42 if i % 3 == 0 else 39) * math.cos(ang):.2f} {64 + (42 if i % 3 == 0 else 39) * math.sin(ang):.2f} "
        return ('<circle cx="64" cy="64" r="36" fill="none" stroke="#e0f0ff" stroke-width="1.3" opacity="0.4"/>'
                f'<path d="{ticks}" stroke="#e0f0ff" stroke-width="1.3" opacity="0.45"/>')
    return ""


def motif_defs(key: str) -> str:
    return ('<linearGradient id="goo" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#b4f05a"/>'
            '<stop offset="0.6" stop-color="#5cb82a"/><stop offset="1" stop-color="#2e7a14"/></linearGradient>'
            '<linearGradient id="flame" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#fff0a0"/>'
            '<stop offset="0.35" stop-color="#ffa030"/><stop offset="0.8" stop-color="#ff5010" stop-opacity="0.6"/>'
            '<stop offset="1" stop-color="#ff3000" stop-opacity="0"/></linearGradient>'
            '<linearGradient id="mist" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#000" stop-opacity="0"/>'
            '<stop offset="0.5" stop-color="#000" stop-opacity="0.62"/><stop offset="1" stop-color="#000" stop-opacity="0"/></linearGradient>'
            '<radialGradient id="halo" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#ffffff" stop-opacity="0.45"/>'
            '<stop offset="1" stop-color="#ffffff" stop-opacity="0"/></radialGradient>'
            '<linearGradient id="glint" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#ffffff" stop-opacity="0"/>'
            '<stop offset="0.5" stop-color="#ffffff" stop-opacity="1"/><stop offset="1" stop-color="#ffffff" stop-opacity="0"/></linearGradient>')


# ---------------------------------------------------------------- glyph

def glyph_path(key: str) -> str:
    if key == "paralyse":
        return BOLT
    with open(os.path.join(ICON_DIR, key + ".svg"), encoding="utf-8") as f:
        src = f.read()
    paths = re.findall(r'<path[^>]*\sd="([^"]+)"', src)
    if not paths:
        raise SystemExit(f"no glyph path in {key}.svg")
    return " ".join(paths)


def badge(key: str) -> str:
    k = kind(key)
    edge, bezel, groove, enamel = frame(k)
    stops, outline = PALETTE[key]
    gtop, gbot = GLYPH_FILL.get(key, ("#fffaf0", "#e8dcc4"))
    gs = 128.0 * GLYPH_K / 512.0
    off = (128.0 - 128.0 * GLYPH_K) / 2.0
    gt = f"translate({off:.3f} {off:.3f}) scale({gs:.5f})"
    gp = glyph_path(key)
    # Outline width in glyph units (about 3.8 badge units).
    ow = 3.8 / gs
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">
<!-- RLDB status badge "{key}" ({k}); generated by tools/gen_status_badges.py. Glyph: see assets/CREDITS.md. -->
<defs>
<linearGradient id="bezel" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#fff4c8"/><stop offset="0.3" stop-color="#ecc56c"/><stop offset="0.62" stop-color="#b8863a"/><stop offset="1" stop-color="#5e3e14"/>
</linearGradient>
<linearGradient id="groove" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#3a2408"/><stop offset="0.55" stop-color="#7a5420"/><stop offset="1" stop-color="#f4d48a"/>
</linearGradient>
<radialGradient id="enamel" cx="0.42" cy="0.36" r="0.72" fx="0.40" fy="0.30">
<stop offset="0" stop-color="{stops[0]}"/><stop offset="0.45" stop-color="{stops[1]}"/><stop offset="0.82" stop-color="{stops[2]}"/><stop offset="1" stop-color="{stops[3]}"/>
</radialGradient>
<radialGradient id="vig" cx="0.5" cy="0.5" r="0.5">
<stop offset="0.62" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.55"/>
</radialGradient>
<linearGradient id="gloss" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#ffffff" stop-opacity="0.55"/><stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
</linearGradient>
<linearGradient id="glyph" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="{gtop}"/><stop offset="1" stop-color="{gbot}"/>
</linearGradient>
{motif_defs(key)}
<clipPath id="en"><path d="{enamel}"/></clipPath>
</defs>
<path d="{edge}" fill="#140c04"/>
<path d="{bezel}" fill="url(#bezel)"/>
<path d="{bezel}" fill="none" stroke="#fff6d0" stroke-width="1" opacity="0.5"/>
<path d="{groove}" fill="url(#groove)"/>
<path d="{enamel}" fill="url(#enamel)"/>
<g clip-path="url(#en)">
{motif(key)}
<path d="{enamel}" fill="url(#vig)"/>
<ellipse cx="60" cy="34" rx="40" ry="20" fill="url(#gloss)" opacity="0.55"/>
</g>
<path d="{enamel}" fill="none" stroke="#000" stroke-width="1.6" opacity="0.45"/>
<g transform="translate(0 2.6) {gt}" opacity="0.6"><path d="{gp}" fill="#000" stroke="#000" stroke-width="{ow:.1f}" stroke-linejoin="round"/></g>
<g transform="{gt}"><path d="{gp}" fill="{outline}" stroke="{outline}" stroke-width="{ow:.1f}" stroke-linejoin="round"/></g>
<g transform="{gt}"><path d="{gp}" fill="url(#glyph)"/></g>
</svg>
"""


def main() -> int:
    for key in KEYS:
        out = os.path.join(ICON_DIR, f"badge_{key}.svg")
        with open(out, "w", encoding="utf-8", newline="\n") as f:
            f.write(badge(key))
    print(f"wrote {len(KEYS)} badges to {ICON_DIR}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
