"""Legibility rules for the enamelled status badges (tools/gen_status_badges.py).

Final L-batch review (design/review-final-2026-11-05.md, item a): at a field card's native size
(about 16-20 px) the glyphs read as faint smudges. These tests pin what fixed it: a glyph that
fills the enamel, an outline that stays at least about a pixel wide at field size, a dark halo
behind the glyph, enough contrast between the glyph and its enamel, and committed SVGs that match
the generator.

    python -I -X utf8 -m unittest discover -s tools/tests -p "test_status_badges.py"
"""
import os
import sys
import unittest

TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, TOOLS)
import gen_status_badges as gb  # noqa: E402

FIELD_PX = 18.0          # a badge on a field card at 1600x1000
MIN_OUTLINE_PX = 0.95    # the outline must survive as about one pixel there
MIN_GLYPH_K = 0.66       # fraction of the badge the glyph spans (diagonal glyphs may stay at 0.66)
MIN_MID_CONTRAST = 1.5   # glyph fill vs the enamel's mid tone (WCAG ratio); the outline adds more


def _lum(hex_col: str) -> float:
    h = hex_col.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def _contrast(a: str, b: str) -> float:
    la, lb = sorted((_lum(a), _lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


class StatusBadgeLegibilityTest(unittest.TestCase):
    def test_outline_is_about_a_pixel_at_field_size(self):
        self.assertGreaterEqual(gb.OUTLINE_W * FIELD_PX / 128.0, MIN_OUTLINE_PX)

    def test_glyph_fills_the_enamel(self):
        self.assertGreaterEqual(gb.GLYPH_K, 0.72)
        for key in gb.KEYS:
            self.assertGreaterEqual(gb.GLYPH_K_FOR.get(key, gb.GLYPH_K), MIN_GLYPH_K, key)

    def test_every_glyph_contrasts_with_its_enamel(self):
        for key in gb.KEYS:
            stops, _ = gb.PALETTE[key]
            _, bottom = gb.GLYPH_FILL.get(key, ("#fffaf0", "#e8dcc4"))
            self.assertGreaterEqual(_contrast(bottom, stops[1]), MIN_MID_CONTRAST, key)

    def test_badges_draw_a_dark_halo_behind_the_glyph(self):
        for key in gb.KEYS:
            svg = gb.badge(key)
            self.assertIn(f'opacity="{gb.HALO_OPACITY}"', svg, key)

    def test_committed_badges_match_the_generator(self):
        for key in gb.KEYS:
            path = os.path.join(gb.ICON_DIR, f"badge_{key}.svg")
            with open(path, encoding="utf-8", newline="") as f:
                self.assertEqual(f.read(), gb.badge(key), f"{key}: rerun tools/gen_status_badges.py")


if __name__ == "__main__":
    unittest.main()
