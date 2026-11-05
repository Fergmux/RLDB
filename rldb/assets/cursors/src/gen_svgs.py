"""Authoring aid for RLDB's L22 cursor art: writes the layered SVG sources into this folder
(rldb/assets/cursors/src/). The SVGs are the checked-in source of truth; this script keeps the
shared parts (the arrow, the reticle) identical across the files that reuse them.

    python -I rldb/assets/cursors/src/gen_svgs.py rldb/assets/cursors/src
    godot --headless --path rldb -s res://src/dev/cursor_bake.gd   # then bake the PNGs

The folder has a .gdignore, so Godot never imports the sources."""
import math
import os
import sys

OUT = sys.argv[1]
INK = "#140b04"

HEAD = """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <!-- RLDB cursor "{name}" (L22). 64-unit grid, hotspot {hot}. {note}
       Rasterised by rldb/src/dev/cursor_bake.gd, which adds the drop shadow{glow}. -->
"""

GOLD_DEFS = """    <linearGradient id="lit" x1="0" y1="0" x2="0.7" y2="1">
      <stop offset="0" stop-color="#fff6d2"/>
      <stop offset="0.35" stop-color="#f6d98a"/>
      <stop offset="0.75" stop-color="#dcac52"/>
      <stop offset="1" stop-color="#b47d2c"/>
    </linearGradient>
    <linearGradient id="shade" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#e6bb62"/>
      <stop offset="0.5" stop-color="#b9842f"/>
      <stop offset="1" stop-color="#7a4d15"/>
    </linearGradient>
    <linearGradient id="tailL" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#ecc56f"/>
      <stop offset="1" stop-color="#a87228"/>
    </linearGradient>
    <linearGradient id="tailR" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#a87228"/>
      <stop offset="1" stop-color="#5e3a0f"/>
    </linearGradient>
    <linearGradient id="gold" x1="0" y1="0" x2="0.6" y2="1">
      <stop offset="0" stop-color="#fff3c4"/>
      <stop offset="0.3" stop-color="#f2cf7a"/>
      <stop offset="0.7" stop-color="#d4a64a"/>
      <stop offset="1" stop-color="#8e5d1a"/>
    </linearGradient>
    <radialGradient id="sapphire" cx="0.38" cy="0.32" r="0.75">
      <stop offset="0" stop-color="#d8ecff"/>
      <stop offset="0.3" stop-color="#6fb2ff"/>
      <stop offset="0.75" stop-color="#2557b8"/>
      <stop offset="1" stop-color="#132a66"/>
    </radialGradient>
    <radialGradient id="ruby" cx="0.38" cy="0.32" r="0.75">
      <stop offset="0" stop-color="#ffe0d6"/>
      <stop offset="0.3" stop-color="#ff6a52"/>
      <stop offset="0.75" stop-color="#a8160f"/>
      <stop offset="1" stop-color="#4a0606"/>
    </radialGradient>
"""

# The arrow: tip T, left edge foot L, inner notch N, tail (A, notch V, B), tail top C, wing W.
T, L, N = (4.2, 4.2), (4.2, 46.0), (14.4, 37.0)
A, V, B = (22.6, 55.8), (25.9, 51.2), (31.0, 52.0)
C, W = (22.5, 34.0), (36.4, 34.0)
M = (18.4, 35.5)            # ridge foot, between N and C
TM = (26.8, 53.0)           # tail ridge end (the swallowtail notch side)


def pts(*p):
    return " ".join("%s%.2f,%.2f" % ("M" if i == 0 else "L", x, y) for i, (x, y) in enumerate(p)) + " Z"


def arrow(gem=True):
    s = []
    s.append('  <path d="%s" fill="%s" stroke="%s" stroke-width="3.6" stroke-linejoin="round"/>' % (pts(T, L, N, A, V, B, C, W), INK, INK))
    s.append('  <path d="%s" fill="url(#lit)"/>' % pts(T, L, N, M))
    s.append('  <path d="%s" fill="url(#shade)"/>' % pts(T, M, C, W))
    s.append('  <path d="%s" fill="url(#tailL)"/>' % pts(N, A, V, M))
    s.append('  <path d="%s" fill="url(#tailR)"/>' % pts(M, V, B, C))
    # Engraved inlay: a dark line with a light lip, parallel to the two outer edges of the head.
    s.append('  <path d="M7.7,37.4 L7.7,12.4 L26.6,29.9" fill="none" stroke="#6b4512" stroke-width="1.0" stroke-opacity="0.75" stroke-linejoin="round" stroke-linecap="round"/>')
    s.append('  <path d="M8.6,36.6 L8.6,14.2 L25.4,29.9" fill="none" stroke="#fff6d8" stroke-width="0.7" stroke-opacity="0.45" stroke-linejoin="round" stroke-linecap="round"/>')
    # Edge glints and the ridge.
    s.append('  <path d="M5.9,8.6 L5.9,41.6" stroke="#fffbe6" stroke-width="1.1" stroke-opacity="0.8" stroke-linecap="round"/>')
    s.append('  <path d="M7.4,6.9 L32.6,32.0" stroke="#fff3c4" stroke-width="0.9" stroke-opacity="0.5" stroke-linecap="round"/>')
    s.append('  <path d="M16.1,39.6 L22.8,53.6" stroke="#fff3c4" stroke-width="0.9" stroke-opacity="0.45" stroke-linecap="round"/>')
    if gem:
        s.append(bezel_gem(14.2, 26.2, 3.7, "sapphire"))
    return "\n".join(s)


def bezel_gem(cx, cy, r, gem):
    return "\n".join([
        '  <circle cx="%.2f" cy="%.2f" r="%.2f" fill="%s"/>' % (cx, cy, r + 0.95, INK),
        '  <circle cx="%.2f" cy="%.2f" r="%.2f" fill="url(#gold)"/>' % (cx, cy, r),
        '  <circle cx="%.2f" cy="%.2f" r="%.2f" fill="url(#%s)"/>' % (cx, cy, r * 0.72, gem),
        '  <circle cx="%.2f" cy="%.2f" r="%.2f" fill="#ffffff" fill-opacity="0.9"/>' % (cx - r * 0.26, cy - r * 0.28, r * 0.2),
    ])


def write(name, hot, note, body, defs="", glow=""):
    svg = HEAD.format(name=name, hot=hot, note=note, glow=glow)
    svg += "  <defs>\n" + GOLD_DEFS + defs + "  </defs>\n" + body + "\n</svg>\n"
    with open(os.path.join(OUT, name + ".svg"), "w", encoding="utf-8", newline="\n") as f:
        f.write(svg)


# ------------------------------------------------------------------ normal
write("normal", "(3,3) at the tip", "A gilded, faceted arrow: lit and shaded facets, an engraved inlay,\n       a swallowtail tail and a sapphire in a gold bezel.", arrow())

# ------------------------------------------------------------------ forbidden (arrow + barred medallion)
def no_badge(cx, cy, r):
    s = []
    s.append('  <circle cx="%.2f" cy="%.2f" r="%.2f" fill="%s"/>' % (cx, cy, r + 1.5, INK))
    s.append('  <circle cx="%.2f" cy="%.2f" r="%.2f" fill="url(#gold)"/>' % (cx, cy, r))
    s.append('  <circle cx="%.2f" cy="%.2f" r="%.2f" fill="#1b0b08"/>' % (cx, cy, r - 2.3))
    s.append('  <circle cx="%.2f" cy="%.2f" r="%.2f" fill="none" stroke="url(#enamel)" stroke-width="3.0"/>' % (cx, cy, r - 4.1))
    d = (r - 4.1) * 0.7071
    s.append('  <path d="M%.2f,%.2f L%.2f,%.2f" stroke="url(#enamel)" stroke-width="3.0" stroke-linecap="butt"/>' % (cx - d, cy - d, cx + d, cy + d))
    s.append('  <path d="M%.2f,%.2f A%.2f,%.2f 0 0 1 %.2f,%.2f" fill="none" stroke="#fff3c4" stroke-width="0.8" stroke-opacity="0.7"/>' % (cx - r * 0.8, cy - r * 0.45, r - 0.6, r - 0.6, cx + r * 0.1, cy - r + 0.7))
    return "\n".join(s)


ENAMEL = """    <linearGradient id="enamel" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#ff9a86"/>
      <stop offset="0.45" stop-color="#e8483c"/>
      <stop offset="1" stop-color="#8e1810"/>
    </linearGradient>
"""
write("forbidden", "(3,3) at the tip", "The gilded arrow with a barred red-enamel medallion: not here.",
      arrow(gem=False) + "\n" + no_badge(44.5, 45.0, 12.5), ENAMEL)

# ------------------------------------------------------------------ help (arrow + magnifier)
def magnifier(cx, cy, r):
    s = []
    hx0, hy0 = cx + r * 0.72, cy + r * 0.72
    hx1, hy1 = cx + r * 1.75, cy + r * 1.75
    s.append('  <path d="M%.2f,%.2f L%.2f,%.2f" stroke="%s" stroke-width="7.6" stroke-linecap="round"/>' % (hx0, hy0, hx1, hy1, INK))
    s.append('  <circle cx="%.2f" cy="%.2f" r="%.2f" fill="%s"/>' % (cx, cy, r + 3.3, INK))
    s.append('  <path d="M%.2f,%.2f L%.2f,%.2f" stroke="url(#wood)" stroke-width="4.2" stroke-linecap="round"/>' % (hx0 + 0.6, hy0 + 0.6, hx1, hy1))
    s.append('  <circle cx="%.2f" cy="%.2f" r="%.2f" fill="url(#gold)"/>' % (cx, cy, r + 1.9))
    s.append('  <circle cx="%.2f" cy="%.2f" r="%.2f" fill="url(#glass)"/>' % (cx, cy, r - 0.2))
    s.append('  <path d="M%.2f,%.2f A%.2f,%.2f 0 0 1 %.2f,%.2f" fill="none" stroke="#ffffff" stroke-width="1.2" stroke-opacity="0.85" stroke-linecap="round"/>' % (cx - r * 0.62, cy - r * 0.05, r * 0.62, r * 0.62, cx - r * 0.05, cy - r * 0.62))
    return "\n".join(s)


GLASS = """    <radialGradient id="glass" cx="0.4" cy="0.35" r="0.8">
      <stop offset="0" stop-color="#e4f2ff"/>
      <stop offset="0.45" stop-color="#8fc3f2"/>
      <stop offset="1" stop-color="#2f5f8f"/>
    </radialGradient>
    <linearGradient id="wood" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#8a4b4f"/>
      <stop offset="1" stop-color="#3b1d22"/>
    </linearGradient>
"""
write("help", "(3,3) at the tip", "The gilded arrow with a gold-rimmed magnifier: hover to read.",
      arrow(gem=False) + "\n" + magnifier(41.5, 39.5, 8.4), GLASS)


# ------------------------------------------------------------------ reticles
def ring(cx, cy, r, width, grad):
    return "\n".join([
        '  <circle cx="%.2f" cy="%.2f" r="%.2f" fill="none" stroke="%s" stroke-width="%.2f"/>' % (cx, cy, r, INK, width + 3.4),
        '  <circle cx="%.2f" cy="%.2f" r="%.2f" fill="none" stroke="url(#%s)" stroke-width="%.2f"/>' % (cx, cy, r, grad, width),
    ])


def prong(cx, cy, ang, r_out, r_in, half_w, grad, ink=True):
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)
    vx, vy = -uy, ux
    tip = (cx + ux * r_in, cy + uy * r_in)
    b1 = (cx + ux * r_out + vx * half_w, cy + uy * r_out + vy * half_w)
    b2 = (cx + ux * r_out - vx * half_w, cy + uy * r_out - vy * half_w)
    notch = (cx + ux * (r_out - half_w * 0.9), cy + uy * (r_out - half_w * 0.9))
    d = pts(tip, b1, notch, b2)
    s = []
    if ink:
        s.append('  <path d="%s" fill="%s" stroke="%s" stroke-width="3.2" stroke-linejoin="round"/>' % (d, INK, INK))
    s.append('  <path d="%s" fill="url(#%s)"/>' % (d, grad))
    # lit half
    s.append('  <path d="%s" fill="#fff6d8" fill-opacity="0.35"/>' % pts(tip, b1, notch))
    return "\n".join(s)


def diamond(cx, cy, r, fill, ink=True):
    d = pts((cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy))
    s = []
    if ink:
        s.append('  <path d="%s" fill="%s" stroke="%s" stroke-width="2.6" stroke-linejoin="round"/>' % (d, INK, INK))
    s.append('  <path d="%s" fill="%s"/>' % (d, fill))
    return "\n".join(s)


def rune_ticks(cx, cy, r, n, col, opacity, width=0.9, skip_cardinal=True):
    s = []
    for i in range(n):
        ang = 360.0 * i / n
        if skip_cardinal and abs((ang + 45) % 90 - 45) < 12:
            continue
        a = math.radians(ang)
        x0, y0 = cx + math.cos(a) * (r - 1.1), cy + math.sin(a) * (r - 1.1)
        x1, y1 = cx + math.cos(a) * (r + 1.1), cy + math.sin(a) * (r + 1.1)
        s.append('  <path d="M%.2f,%.2f L%.2f,%.2f" stroke="%s" stroke-width="%.2f" stroke-opacity="%.2f" stroke-linecap="round"/>' % (x0, y0, x1, y1, col, width, opacity))
    return "\n".join(s)


RET = """    <linearGradient id="ret" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#fff3c4"/>
      <stop offset="0.4" stop-color="#ecc666"/>
      <stop offset="1" stop-color="#9a6416"/>
    </linearGradient>
    <linearGradient id="lock" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#fffbe0"/>
      <stop offset="0.35" stop-color="#ffe27a"/>
      <stop offset="0.75" stop-color="#ffc83a"/>
      <stop offset="1" stop-color="#b07a12"/>
    </linearGradient>
    <linearGradient id="iron" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#cfc6b6"/>
      <stop offset="0.5" stop-color="#8f8678"/>
      <stop offset="1" stop-color="#4f4940"/>
    </linearGradient>
""" + ENAMEL
CX = CY = 32.0


def reticle(state):
    s = []
    if state == "target":
        r, w = 17.5, 2.6
        s.append(ring(CX, CY, r, w, "ret"))
        s.append(rune_ticks(CX, CY, r, 24, "#5a3810", 0.7, 0.8))
        for ang in (0, 90, 180, 270):
            s.append(prong(CX, CY, ang - 90, 28.5, 10.5, 4.4, "ret"))
        for ang in (45, 135, 225, 315):
            a = math.radians(ang)
            s.append(diamond(CX + math.cos(a) * r, CY + math.sin(a) * r, 2.6, "url(#sapphire)"))
        s.append('  <circle cx="32" cy="32" r="2.6" fill="%s"/>' % INK)
        s.append('  <circle cx="32" cy="32" r="1.5" fill="#fff3c4"/>')
    elif state == "target_lock":
        r, w = 14.0, 3.2
        s.append(ring(CX, CY, r, w, "lock"))
        s.append(ring(CX, CY, 7.2, 1.4, "lock"))
        s.append(rune_ticks(CX, CY, r, 24, "#6b4512", 0.75, 0.8))
        for ang in (0, 90, 180, 270):
            s.append(prong(CX, CY, ang - 90, 26.0, 8.6, 4.8, "lock"))
        for ang in (45, 135, 225, 315):
            a = math.radians(ang)
            s.append(diamond(CX + math.cos(a) * r, CY + math.sin(a) * r, 2.9, "url(#ruby)"))
        s.append(bezel_gem(CX, CY, 3.0, "ruby"))
    else:  # target_no
        r, w = 17.5, 2.6
        s.append(ring(CX, CY, r, w, "iron"))
        for ang in (0, 90, 180, 270):
            s.append(prong(CX, CY, ang - 90, 28.5, 10.5, 4.4, "iron"))
        d = r * 0.7071
        s.append('  <path d="M%.2f,%.2f L%.2f,%.2f" stroke="%s" stroke-width="7.0" stroke-linecap="round"/>' % (CX - d, CY - d, CX + d, CY + d, INK))
        s.append('  <path d="M%.2f,%.2f L%.2f,%.2f" stroke="url(#enamel)" stroke-width="3.6" stroke-linecap="round"/>' % (CX - d, CY - d, CX + d, CY + d))
    return "\n".join(s)


write("target", "(32,32) at the centre", "A rune reticle: a gold ring with rune ticks, four inward prongs,\n       sapphire studs and a pin-point centre.", reticle("target"), RET)
write("target_lock", "(32,32) at the centre", "The reticle locked on a legal target: closed in, a double ring,\n       ruby studs and a ruby heart.", reticle("target_lock"), RET, " and the warm glow (CursorSkin.ART)")
write("target_no", "(32,32) at the centre", "The reticle over a card that is not a legal target: dull iron,\n       barred in red enamel.", reticle("target_no"), RET)


# ------------------------------------------------------------------ knife
def knife(hot):
    # Drawn upright (tip at local (0,-48)), then turned -45 degrees so the tip points up-left at (4.5,4.5).
    s = ['  <g transform="translate(38.44,38.44) rotate(-45)">']
    blade = "M0,-48 C2.4,-38 6.4,-24 5.6,-8 L-5.6,-8 C-6.4,-24 -2.4,-38 0,-48 Z"
    s.append('    <path d="%s" fill="%s" stroke="%s" stroke-width="3.4" stroke-linejoin="round"/>' % (blade, INK, INK))
    s.append('    <path d="%s" fill="url(#steel)"/>' % blade)
    # The lit half of the blade (left of the spine) and the dark fuller.
    s.append('    <path d="M0,-48 C-2.4,-38 -6.4,-24 -5.6,-8 L0,-8 Z" fill="#ffffff" fill-opacity="0.32"/>')
    s.append('    <path d="M0,-40 L0,-11" stroke="#3a3f48" stroke-width="1.3" stroke-opacity="0.8" stroke-linecap="round"/>')
    s.append('    <path d="M0.9,-39 L0.9,-11" stroke="#ffffff" stroke-width="0.6" stroke-opacity="0.6" stroke-linecap="round"/>')
    if hot:
        s.append('    <path d="%s" fill="url(#ember)" fill-opacity="0.16"/>' % blade)
        s.append('    <path d="M0,-44 C2.0,-36 5.0,-24 4.5,-10" fill="none" stroke="#fff6d8" stroke-width="1.0" stroke-opacity="0.95" stroke-linecap="round"/>')
    # Runes etched in blood on the blade.
    rc = "#ff3a1c" if hot else "#9e1a14"
    s.append('    <path d="M-2.0,-30 L0,-32.6 L2.0,-30 M-2.0,-24.5 L0,-27.1 L2.0,-24.5 M-2.0,-19 L0,-21.6 L2.0,-19" fill="none" stroke="%s" stroke-width="1.1" stroke-opacity="0.9" stroke-linecap="round" stroke-linejoin="round"/>' % rc)
    # Crescent guard.
    guard = "M-14,-12 Q0,-2.5 14,-12 Q13.6,-6.6 11.2,-4.0 Q0,1.8 -11.2,-4.0 Q-13.6,-6.6 -14,-12 Z"
    s.append('    <path d="%s" fill="%s" stroke="%s" stroke-width="3.2" stroke-linejoin="round"/>' % (guard, INK, INK))
    s.append('    <path d="%s" fill="url(#gold)"/>' % guard)
    s.append('    <path d="M-11.6,-10.2 Q0,-2.6 11.6,-10.2" fill="none" stroke="#fff6d8" stroke-width="0.8" stroke-opacity="0.7"/>')
    # Grip: wine leather with gold wire.
    s.append('    <rect x="-3.0" y="-3.5" width="6.0" height="17" rx="1.6" fill="%s" stroke="%s" stroke-width="3.0"/>' % (INK, INK))
    s.append('    <rect x="-3.0" y="-3.5" width="6.0" height="17" rx="1.6" fill="url(#grip)"/>')
    for y in (0.0, 4.2, 8.4):
        s.append('    <path d="M-3,%.1f L3,%.1f" stroke="#e9c06a" stroke-width="1.1"/>' % (y + 1.6, y - 0.4))
    # Pommel: a gem in a gold cap.
    s.append('    <circle cx="0" cy="18.6" r="5.9" fill="%s"/>' % INK)
    s.append('    <circle cx="0" cy="18.6" r="4.9" fill="url(#gold)"/>')
    s.append('    <circle cx="0" cy="18.6" r="3.3" fill="url(#ruby)"/>')
    s.append('    <circle cx="-1.0" cy="17.5" r="0.75" fill="#ffffff" fill-opacity="0.9"/>')
    s.append('  </g>')
    return "\n".join(s)


KNIFE = """    <linearGradient id="steel" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#f4f6f8"/>
      <stop offset="0.48" stop-color="#c3c9d1"/>
      <stop offset="0.52" stop-color="#8d949e"/>
      <stop offset="1" stop-color="#555b65"/>
    </linearGradient>
    <linearGradient id="ember" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#ffe7a8"/>
      <stop offset="0.35" stop-color="#ffa040"/>
      <stop offset="0.8" stop-color="#e2461c"/>
      <stop offset="1" stop-color="#8e1a0c"/>
    </linearGradient>
    <linearGradient id="grip" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#8a4b4f"/>
      <stop offset="1" stop-color="#2e1418"/>
    </linearGradient>
"""
write("knife", "(4.5,4.5) at the blade's point", "The ritual dagger of sacrifice mode: a steel leaf blade etched with\n       blood runes, a crescent gold guard, a wine-leather grip and a ruby pommel.", knife(False), KNIFE)
write("knife_hot", "(4.5,4.5) at the blade's point", "The ritual dagger over a unit a click would sacrifice: the blade\n       catches a pale-gold light and its runes burn red.", knife(True), KNIFE, " and the pale-gold glow (CursorSkin.ART)")


# ------------------------------------------------------------------ pointer (gilded gauntlet)
def pointer():
    s = []
    parts = []
    # index finger (hotspot at its tip, (23,3))
    finger = "M18.2,32 L18.2,8.2 C18.2,2.6 27.8,2.6 27.8,8.2 L27.8,32 Z"
    # curled fingers (knuckles), from the index outward
    k1 = "M27,27.6 C27,23.6 35.2,23.6 35.2,27.6 L35.2,40 L27,40 Z"
    k2 = "M34.6,30.2 C34.6,26.4 42.2,26.4 42.2,30.2 L42.2,41.6 L34.6,41.6 Z"
    k3 = "M41.6,33.6 C41.6,30.2 48.2,30.2 48.2,33.6 L48.2,43 L41.6,43 Z"
    # back of the hand
    palm = "M14.6,34 L48.2,38.6 L48.2,45.5 C48.2,51 44.4,53.2 40.5,53.2 L21.6,53.2 C17,53.2 14.2,49.6 14.2,45.2 Z"
    # thumb, laid along the left
    thumb = "M18.6,32.2 L11.2,35.4 C7.4,37.2 7.6,42.6 11.6,44.2 L18.6,47 Z"
    # cuff (flared)
    cuff = "M17.4,51.4 L44.4,51.4 L46.8,61.4 L15,61.4 Z"
    shapes = [(cuff, "cuffg"), (palm, "gold"), (thumb, "shade"), (k3, "shade"), (k2, "shade"), (k1, "gold"), (finger, "fing")]
    for d, _ in shapes:
        s.append('  <path d="%s" fill="%s" stroke="%s" stroke-width="3.6" stroke-linejoin="round"/>' % (d, INK, INK))
    for d, g in shapes:
        s.append('  <path d="%s" fill="url(#%s)" stroke="#3a2308" stroke-width="0.9" stroke-linejoin="round"/>' % (d, g))
    # articulated finger plates and knuckle glints
    for y in (15.2, 23.4):
        s.append('  <path d="M18.6,%.1f L27.4,%.1f" stroke="#4a2c0a" stroke-width="1.1"/>' % (y, y))
        s.append('  <path d="M18.8,%.1f L27.2,%.1f" stroke="#fff6d8" stroke-width="0.6" stroke-opacity="0.55"/>' % (y + 1.1, y + 1.1))
    s.append('  <path d="M20.4,8.6 L20.4,30" stroke="#fffbe6" stroke-width="1.2" stroke-opacity="0.75" stroke-linecap="round"/>')
    for x0, x1, y in ((28.6, 33.6, 26.6), (36.0, 40.8, 29.2), (42.9, 46.9, 32.6)):
        s.append('  <path d="M%.1f,%.1f Q%.1f,%.1f %.1f,%.1f" fill="none" stroke="#fff6d8" stroke-width="0.8" stroke-opacity="0.6" stroke-linecap="round"/>' % (x0, y + 0.6, (x0 + x1) / 2, y - 1.0, x1, y + 0.6))
    # knuckle rivets along the back of the hand
    for x, y in ((22.0, 41.4), (30.6, 42.6), (38.6, 43.6)):
        s.append('  <circle cx="%.1f" cy="%.1f" r="1.1" fill="#5a3810"/>' % (x, y))
        s.append('  <circle cx="%.1f" cy="%.1f" r="0.5" fill="#fff6d8" fill-opacity="0.8"/>' % (x - 0.3, y - 0.3))
    # cuff rim and its sapphire
    s.append('  <path d="M17.8,54.2 L44.0,54.2" stroke="#4a2c0a" stroke-width="1.0"/>')
    s.append('  <path d="M18.0,55.1 L43.8,55.1" stroke="#fff6d8" stroke-width="0.6" stroke-opacity="0.5"/>')
    s.append(bezel_gem(31.0, 57.6, 2.6, "sapphire"))
    return "\n".join(s)


PTR = """    <linearGradient id="fing" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#fff3c4"/>
      <stop offset="0.45" stop-color="#ecc666"/>
      <stop offset="1" stop-color="#a06c1e"/>
    </linearGradient>
    <linearGradient id="cuffg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#d4a64a"/>
      <stop offset="1" stop-color="#7a4d15"/>
    </linearGradient>
"""
write("pointer", "(23,3) at the fingertip", "A gilded gauntlet pointing: articulated finger plates, curled\n       knuckle plates, a riveted back and a flared cuff with a sapphire.", pointer(), PTR)
print("ok")
