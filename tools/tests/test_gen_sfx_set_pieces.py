"""H29 regression: the Fusion and Ritual summon set-piece sounds (build-up + climax) are as clean as the
Arcane one (H28) and level with it.

Reads the committed WAVs in rldb/assets/audio/sfx (written by tools/gen_sfx.py) and checks objective
properties: no clipping, no harsh noise transient (energy above 4 kHz stays well under the peak), no click
after the onset, a tail that fades to silence, loudness within 1 LU of the Arcane counterpart, and a
build-up that crests before its climax and then lets go so the climax lands.
"""
import math
import os
import struct
import unittest
import wave

SFX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "rldb", "assets", "audio", "sfx")
FRAME_S = 0.005
MAX_HF_REL_DB = -12.0     # high-passed (4 kHz) peak relative to the full peak; the old Fusion crack was -6.5
MAX_STEP_DB = 10.0        # largest rise between 5 ms frames once the sound has started
MAX_END_DB = -50.0        # the last 50 ms, relative to the peak
MAX_LU_DIFF = 1.0         # loudest 400 ms (K-weighted) against the Arcane counterpart
MIN_LET_GO_DB = 4.0       # a build-up's level in the 50 ms after its climax, under its loudest 50 ms
# Set-piece climax times (s), from rldb/src/ui/fx/fx_summon.gd CLIMAX.
CLIMAX = {"fusion": 0.78, "ritual": 0.88}
BUILD = {"fusion": "fusion_vortex", "ritual": "ritual_choir"}
HIT = {"fusion": "fusion_impact", "ritual": "ritual_impact"}
ARCANE = {"build": "arcane_shimmer", "hit": "arcane_impact"}
# The set pieces under test.
KINDS = ("fusion", "ritual")


def _load(name):
    with wave.open(os.path.join(SFX, name + ".wav"), "rb") as w:
        n = w.getnframes()
        sr = w.getframerate()
        s = struct.unpack("<%dh" % n, w.readframes(n))
    return [v / 32768.0 for v in s], sr


def _db(v):
    return 20.0 * math.log10(max(v, 1e-9))


def _rms(x):
    return math.sqrt(sum(v * v for v in x) / max(1, len(x)))


def _env(x, sr, frame_s=FRAME_S):
    w = int(frame_s * sr)
    return [_rms(x[i:i + w]) for i in range(0, len(x) - w, w)]


def _biquad(x, b, a):
    y, x1, x2, y1, y2 = [], 0.0, 0.0, 0.0, 0.0
    for v in x:
        o = b[0] * v + b[1] * x1 + b[2] * x2 - a[1] * y1 - a[2] * y2
        x2, x1, y2, y1 = x1, v, y1, o
        y.append(o)
    return y


def _momentary_max_lufs(x, sr):
    """Loudest 400 ms window (100 ms hop) of the BS.1770 K-weighted signal, in LUFS."""
    g, q, fc = 4.0, 1.0 / math.sqrt(2.0), 1500.0
    a_ = 10.0 ** (g / 40.0)
    w0 = 2.0 * math.pi * fc / sr
    al = math.sin(w0) / (2.0 * q)
    c = math.cos(w0)
    b0 = a_ * ((a_ + 1) + (a_ - 1) * c + 2 * math.sqrt(a_) * al)
    b1 = -2 * a_ * ((a_ - 1) + (a_ + 1) * c)
    b2 = a_ * ((a_ + 1) + (a_ - 1) * c - 2 * math.sqrt(a_) * al)
    a0 = (a_ + 1) - (a_ - 1) * c + 2 * math.sqrt(a_) * al
    a1 = 2 * ((a_ - 1) - (a_ + 1) * c)
    a2 = (a_ + 1) - (a_ - 1) * c - 2 * math.sqrt(a_) * al
    k = _biquad(x, [b0 / a0, b1 / a0, b2 / a0], [1.0, a1 / a0, a2 / a0])
    w0 = 2.0 * math.pi * 38.0 / sr
    al = math.sin(w0) / (2.0 * 0.5)
    c = math.cos(w0)
    a0 = 1 + al
    k = _biquad(k, [(1 + c) / 2 / a0, -(1 + c) / a0, (1 + c) / 2 / a0], [1.0, -2 * c / a0, (1 - al) / a0])
    win, hop = int(0.4 * sr), int(0.1 * sr)
    return max(-0.691 + 10.0 * math.log10(max(1e-12, sum(v * v for v in k[i:i + win]) / win))
               for i in range(0, max(1, len(k) - win), hop))


def _hf_rel_db(x, sr):
    a = 1.0 - math.exp(-2.0 * math.pi * 4000.0 / sr)
    y, hp = 0.0, []
    for v in x:
        y += a * (v - y)
        hp.append(v - y)
    return _db(max(abs(v) for v in hp)) - _db(max(abs(v) for v in x))


class SetPieceSoundTest(unittest.TestCase):
    def _each(self, check):
        for kind in KINDS:
            for role, name in (("build", BUILD[kind]), ("hit", HIT[kind])):
                with self.subTest(sound=name):
                    x, sr = _load(name)
                    check(kind, role, name, x, sr)

    def test_set_piece_sounds_never_clip(self):
        def check(kind, role, name, x, sr):
            self.assertEqual(sum(1 for v in x if abs(v) >= 0.99997), 0)
            self.assertLessEqual(_db(max(abs(v) for v in x)), -3.0)
        self._each(check)

    def test_set_piece_sounds_have_no_harsh_noise_transient(self):
        def check(kind, role, name, x, sr):
            self.assertLessEqual(_hf_rel_db(x, sr), MAX_HF_REL_DB)
        self._each(check)

    def test_set_piece_sounds_have_no_click_after_the_onset(self):
        def check(kind, role, name, x, sr):
            e = _env(x, sr)
            emax = max(e)
            start = next(i for i, v in enumerate(e) if v >= 0.1 * emax)
            steps = [_db(e[i + 1]) - _db(e[i]) for i in range(start, len(e) - 1) if e[i] > emax * 0.01]
            self.assertLessEqual(max(steps), MAX_STEP_DB)
        self._each(check)

    def test_set_piece_sounds_fade_to_silence(self):
        def check(kind, role, name, x, sr):
            last = x[-int(0.05 * sr):]
            self.assertLessEqual(_db(_rms(last)) - _db(max(abs(v) for v in x)), MAX_END_DB)
        self._each(check)

    def test_set_piece_sounds_are_level_with_arcane(self):
        ref = {role: _momentary_max_lufs(*_load(name)) for role, name in ARCANE.items()}

        def check(kind, role, name, x, sr):
            self.assertLessEqual(abs(_momentary_max_lufs(x, sr) - ref[role]), MAX_LU_DIFF)
        self._each(check)

    def test_build_ups_crest_before_the_climax_then_let_go(self):
        for kind in KINDS:
            name = BUILD[kind]
            with self.subTest(sound=name):
                x, sr = _load(name)
                e = _env(x, sr, 0.05)
                i_c = int(CLIMAX[kind] / 0.05)
                self.assertLess(e.index(max(e)), i_c)
                self.assertGreaterEqual(_db(max(e)) - _db(e[i_c]), MIN_LET_GO_DB)


if __name__ == "__main__":
    unittest.main()
