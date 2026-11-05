"""Subset Noto Sans Symbols 2 to the UI symbol blocks and give it Alegreya Sans' vertical metrics,
so as a fallback it adds glyphs without making any line (or Font.get_ascent) taller.
Usage: make_symbols.py <in NotoSansSymbols2-Regular.ttf> <Alegreya ttf> <out ttf>"""
import sys
from fontTools import subset
from fontTools.ttLib import TTFont

src, ref_path, out = sys.argv[1:4]
ranges = [
    (0x2190, 0x21FF),  # Arrows
    (0x2300, 0x23FF),  # Miscellaneous Technical
    (0x25A0, 0x25FF),  # Geometric Shapes
    (0x2600, 0x26FF),  # Miscellaneous Symbols
    (0x2700, 0x27BF),  # Dingbats
    (0x27F0, 0x27FF),  # Supplemental Arrows-A
    (0x2900, 0x297F),  # Supplemental Arrows-B
    (0x2B00, 0x2BFF),  # Miscellaneous Symbols and Arrows
]
unicodes = [u for a, b in ranges for u in range(a, b + 1)]
opts = subset.Options()
opts.layout_features = ["*"]
opts.name_IDs = ["*"]
opts.notdef_outline = True
opts.glyph_names = False
font = TTFont(src)
sub = subset.Subsetter(opts)
sub.populate(unicodes=unicodes)
sub.subset(font)

ref = TTFont(ref_path)
k = font["head"].unitsPerEm / ref["head"].unitsPerEm
asc = round(ref["OS/2"].sTypoAscender * k)
desc = round(ref["OS/2"].sTypoDescender * k)  # negative
gap = 0
font["hhea"].ascent, font["hhea"].descent, font["hhea"].lineGap = asc, desc, gap
os2 = font["OS/2"]
os2.sTypoAscender, os2.sTypoDescender, os2.sTypoLineGap = asc, desc, gap
os2.usWinAscent, os2.usWinDescent = asc, -desc
os2.fsSelection |= 1 << 7  # USE_TYPO_METRICS

# Rename: a modified version under the OFL (no Reserved Font Name is declared for Noto).
name = font["name"]
for rec in name.names:
    if rec.nameID in (1, 16):
        rec.string = "RLDB Symbols"
    elif rec.nameID == 4:
        rec.string = "RLDB Symbols Regular"
    elif rec.nameID == 6:
        rec.string = "RLDBSymbols-Regular"
    elif rec.nameID == 3:
        rec.string = "RLDBSymbols-Regular;subset of Noto Sans Symbols 2"
font.save(out)
cmap = font.getBestCmap()
print(out, "glyphs:", len(font.getGlyphOrder()), "cmap:", len(cmap), "asc/desc:", asc, desc, "upm", font["head"].unitsPerEm)
print("ref hhea", ref["hhea"].ascent, ref["hhea"].descent, ref["hhea"].lineGap, "typo", ref["OS/2"].sTypoAscender, ref["OS/2"].sTypoDescender, "win", ref["OS/2"].usWinAscent, ref["OS/2"].usWinDescent)
