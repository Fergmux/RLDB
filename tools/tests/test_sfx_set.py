"""L1 (2026-11-05): the mastered ElevenLabs sound set in rldb/assets/audio/sfx.

Replaces the per-cue tests of the retired procedural generator (test_gen_sfx_*.py, H28 / H29 / K1) and keeps
their intent for the new files: every cue exists and is clean (44.1 kHz 16-bit, peak headroom, no DC, a
tail that fades to silence), the UI answers at once, the summon build-ups crest just before their climax
and let go, the Arcane climax blooms instead of hitting (H28), the three climaxes are level (H29), the
Spell / Trap spotlight sits between the board sounds and the climaxes (K1), and the mix keeps its order
(hover < UI < cards < combat). The cue sheet (tiers, length windows) is design/audio/sfx-cues.json; the
files are made by tools/sfx_master.py. Python stdlib only.

Run: python -I -X utf8 -m unittest discover -s tools/tests -p "test_sfx_set.py"
"""
import array
import json
import math
import os
import re
import unittest
import wave

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
SFX = os.path.join(ROOT, "rldb", "assets", "audio", "sfx")
CUES = os.path.join(ROOT, "design", "audio", "sfx-cues.json")
SFX_GD = os.path.join(ROOT, "rldb", "src", "ui", "audio", "sfx.gd")

MAX_PEAK_DBFS = -1.0     # true-peak ceiling of the master is -1 dBTP, so samples stay under it
MAX_DC = 0.002
MAX_END_DB = -40.0       # the last 10 ms, relative to the loudest 5 ms frame
SNAPPY_TIERS = ("hover", "ui_soft", "ui", "ui_major", "tick", "tick_soft", "card", "combat", "big_hit")
MAX_ONSET_MS = 6.0       # first sample above -40 dB of the peak, from the start of the file
LET_GO_DB = 6.0          # a build-up's last 50 ms under its loudest 50 ms
CREST_SLACK_S = 0.1      # a build-up crests no later than its align time + this
MIN_ARCANE_ATTACK_MS = 15.0
MAX_CLIMAX_SPREAD_LU = 1.5
SPOT_MARGIN_LU = 0.5
ORDER = (("hover",), ("ui", "ui_soft"), ("card",), ("combat",))


def _cues():
    with open(CUES, encoding="utf-8") as f:
        return {c["name"]: c for c in json.load(f)["cues"]}


def _names():
    with open(SFX_GD, encoding="utf-8") as f:
        s = f.read()
    block = s[s.index("const NAMES"):s.index("## F22 / F25")]
    return re.findall(r'"([a-z_0-9]+)"', block)


_CACHE = {}


def _load(name):
    """(channels as lists of floats, rate, sample width, channel count)."""
    if name not in _CACHE:
        with wave.open(os.path.join(SFX, name + ".wav"), "rb") as w:
            sr, ch, sw, n = w.getframerate(), w.getnchannels(), w.getsampwidth(), w.getnframes()
            a = array.array("h")
            a.frombytes(w.readframes(n))
        chans = [[v / 32768.0 for v in a[i::ch]] for i in range(ch)]
        _CACHE[name] = (chans, sr, sw, ch)
    return _CACHE[name]


def _db(v):
    return 20.0 * math.log10(max(v, 1e-12))


def _env(x, sr, frame_s=0.005):
    w = max(1, int(frame_s * sr))
    return [math.sqrt(sum(v * v for v in x[i:i + w]) / w) for i in range(0, max(1, len(x) - w + 1), w)]


def _mono(chans):
    if len(chans) == 1:
        return chans[0]
    return [(a + b) * 0.5 for a, b in zip(chans[0], chans[1])]


def _biquad(x, b, a):
    y, x1, x2, y1, y2 = [], 0.0, 0.0, 0.0, 0.0
    b0, b1, b2 = b
    a1, a2 = a
    for v in x:
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        y.append(o)
    return y


def _kcoef(sr):
    G, Q, fc = 3.99984385397, 0.7071752369554193, 1681.9744509555319
    A = 10 ** (G / 40.0)
    w0 = 2 * math.pi * fc / sr
    al, c = math.sin(w0) / (2 * Q), math.cos(w0)
    b = [A * ((A + 1) + (A - 1) * c + 2 * math.sqrt(A) * al), -2 * A * ((A - 1) + (A + 1) * c),
         A * ((A + 1) + (A - 1) * c - 2 * math.sqrt(A) * al)]
    a = [(A + 1) - (A - 1) * c + 2 * math.sqrt(A) * al, 2 * ((A - 1) - (A + 1) * c), (A + 1) - (A - 1) * c - 2 * math.sqrt(A) * al]
    s1 = ([v / a[0] for v in b], [a[1] / a[0], a[2] / a[0]])
    w0 = 2 * math.pi * 38.13547087613982 / sr
    al, c = math.sin(w0) / (2 * 0.5003270373253953), math.cos(w0)
    b = [(1 + c) / 2, -(1 + c), (1 + c) / 2]
    a = [1 + al, -2 * c, 1 - al]
    s2 = ([v / a[0] for v in b], [a[1] / a[0], a[2] / a[0]])
    return s1, s2


def _m100(name):
    """Loudest 100 ms of K-weighted power (LUFS); a mono file counts on both speakers, as Godot plays it."""
    chans, sr, _, ch = _load(name)
    (b1, a1), (b2, a2) = _kcoef(sr)
    power = None
    for x in chans:
        y = _biquad(_biquad(x, b1, a1), b2, a2)
        p = [v * v for v in y]
        power = p if power is None else [u + v for u, v in zip(power, p)]
    if ch == 1:
        power = [2.0 * v for v in power]
    w = int(0.1 * sr)
    if len(power) < w:
        power += [0.0] * (w - len(power))
    s = sum(power[:w])
    best = s
    for i in range(w, len(power)):
        s += power[i] - power[i - w]
        best = max(best, s)
    return -0.691 + 10 * math.log10(max(best / w, 1e-12))


class SfxSetTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cues = _cues()
        cls.names = _names()

    def test_cue_sheet_covers_every_registered_name(self):
        self.assertEqual(sorted(self.cues), sorted(self.names))

    def test_every_cue_is_a_44k_16bit_wav(self):
        for n in self.names:
            with self.subTest(cue=n):
                self.assertTrue(os.path.exists(os.path.join(SFX, n + ".wav")), "%s.wav missing" % n)
                _, sr, sw, ch = _load(n)
                self.assertEqual(sr, 44100)
                self.assertEqual(sw, 2)
                self.assertIn(ch, (1, 2))

    def test_every_cue_keeps_headroom_and_has_no_dc(self):
        for n in self.names:
            with self.subTest(cue=n):
                chans, _, _, _ = _load(n)
                pk = max(max(abs(v) for v in x) for x in chans)
                self.assertLessEqual(_db(pk), MAX_PEAK_DBFS)
                for x in chans:
                    self.assertLess(abs(sum(x) / len(x)), MAX_DC)

    def test_every_cue_fits_its_length_window(self):
        for n in self.names:
            with self.subTest(cue=n):
                chans, sr, _, _ = _load(n)
                lo, hi = self.cues[n]["len"]
                dur = len(chans[0]) / sr
                self.assertGreaterEqual(dur, lo * 0.5)
                self.assertLessEqual(dur, hi + 0.02)

    def test_every_cue_fades_to_silence(self):
        for n in self.names:
            with self.subTest(cue=n):
                chans, sr, _, _ = _load(n)
                x = _mono(chans)
                e = _env(x, sr)
                tail = x[-int(0.01 * sr):]
                rms = math.sqrt(sum(v * v for v in tail) / len(tail))
                self.assertLessEqual(_db(rms) - _db(max(e)), MAX_END_DB)

    def test_action_cues_start_at_once(self):
        for n, c in self.cues.items():
            if c["tier"] not in SNAPPY_TIERS:
                continue
            with self.subTest(cue=n):
                chans, sr, _, _ = _load(n)
                x = _mono(chans)
                thr = max(abs(v) for v in x) * 10 ** (-40 / 20)
                first = next(i for i, v in enumerate(x) if abs(v) > thr)
                self.assertLessEqual(first / sr * 1000.0, MAX_ONSET_MS)

    def test_build_ups_crest_before_their_climax_then_let_go(self):
        for n, c in self.cues.items():
            if c.get("align") is None:
                continue
            with self.subTest(cue=n):
                chans, sr, _, _ = _load(n)
                e = _env(_mono(chans), sr, 0.05)
                crest = max(range(len(e)), key=lambda i: e[i]) * 0.05
                self.assertLessEqual(crest, c["align"] + CREST_SLACK_S)
                self.assertGreaterEqual(_db(max(e)) - _db(e[-1]), LET_GO_DB)

    def test_arcane_climax_blooms_instead_of_hitting(self):
        # H28 (owner): Arcane is mystical, not jarring: 10% -> 90% of the loudest 5 ms frame takes time.
        chans, sr, _, _ = _load("arcane_impact")
        e = _env(_mono(chans), sr)
        top = max(e)
        i10 = next(i for i, v in enumerate(e) if v >= 0.1 * top)
        i90 = next(i for i, v in enumerate(e) if v >= 0.9 * top)
        self.assertGreaterEqual((i90 - i10) * 5.0, MIN_ARCANE_ATTACK_MS)

    def test_the_three_climaxes_are_level(self):
        # H29: Fusion, Ritual and Arcane land equally hard.
        lv = [_m100(n) for n in ("fusion_impact", "ritual_impact", "arcane_impact")]
        self.assertLessEqual(max(lv) - min(lv), MAX_CLIMAX_SPREAD_LU, lv)

    def test_spotlight_sits_between_board_sounds_and_climaxes(self):
        # K1: a Spell / Trap shows many times a game, so it is under the set-piece climaxes and over
        # the everyday board sounds.
        climax = min(_m100(n) for n in ("fusion_impact", "ritual_impact", "arcane_impact", "serpent_strike"))
        board = max(_m100(n) for n in ("attack", "summon", "destroy", "sacrifice"))
        for n in ("spell_cast", "trap_spring"):
            with self.subTest(cue=n):
                m = _m100(n)
                self.assertLessEqual(m, climax - SPOT_MARGIN_LU)
                self.assertGreaterEqual(m, board + SPOT_MARGIN_LU)

    def test_mix_order_hover_ui_cards_combat(self):
        # The loudest cue of each quieter tier stays under the quietest cue of the next.
        groups = []
        for tiers in ORDER:
            groups.append([_m100(n) for n, c in self.cues.items() if c["tier"] in tiers])
        for quiet, loud in zip(groups, groups[1:]):
            self.assertLess(sum(quiet) / len(quiet), sum(loud) / len(loud) - 2.0)
        self.assertLess(max(groups[0]), min(groups[1]))


if __name__ == "__main__":
    unittest.main()
