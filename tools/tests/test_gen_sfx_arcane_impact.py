"""H28 regression: the Arcane summon's completion sound must swell in, not hit, and must die away smoothly.

Reads the committed rldb/assets/audio/sfx/arcane_impact.wav (written by tools/gen_sfx.py) and checks the
objective properties the redesign was measured by: no clipping, a peak with headroom, a rounded attack
(no transient), no click (no sudden jump in the 5 ms envelope) and a tail that fades to silence.
"""
import math
import os
import struct
import unittest
import wave

WAV = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "rldb", "assets", "audio", "sfx", "arcane_impact.wav")
FRAME_S = 0.005
MIN_ATTACK_MS = 30.0      # the old shattering hit reached 90% of its level in 5 ms
MAX_PEAK_DBFS = -4.4      # gen_sfx PEAK["arcane_impact"] is -4.5
MAX_STEP_DB = 8.0         # the largest rise between 5 ms frames after the onset
MAX_END_DB = -50.0        # the last 50 ms, relative to the peak


def _load():
    with wave.open(WAV, "rb") as w:
        n = w.getnframes()
        sr = w.getframerate()
        s = struct.unpack("<%dh" % n, w.readframes(n))
    return [v / 32768.0 for v in s], sr


def _env(x, sr):
    w = int(FRAME_S * sr)
    return [math.sqrt(sum(v * v for v in x[i:i + w]) / w) for i in range(0, len(x) - w, w)]


def _db(v):
    return 20.0 * math.log10(max(v, 1e-9))


class ArcaneImpactShapeTest(unittest.TestCase):
    def setUp(self):
        self.x, self.sr = _load()
        self.e = _env(self.x, self.sr)

    def test_arcane_impact_peak_has_headroom_and_never_clips(self):
        pk = max(abs(v) for v in self.x)
        self.assertLessEqual(_db(pk), MAX_PEAK_DBFS)
        self.assertEqual(sum(1 for v in self.x if abs(v) >= 0.99997), 0)

    def test_arcane_impact_attack_swells_instead_of_hitting(self):
        emax = max(self.e)
        i10 = next(i for i, v in enumerate(self.e) if v >= 0.1 * emax)
        i90 = next(i for i, v in enumerate(self.e) if v >= 0.9 * emax)
        self.assertGreaterEqual((i90 - i10) * FRAME_S * 1000.0, MIN_ATTACK_MS)

    def test_arcane_impact_has_no_click_after_the_onset(self):
        emax = max(self.e)
        start = next(i for i, v in enumerate(self.e) if v >= 0.1 * emax)
        steps = [_db(self.e[i + 1]) - _db(self.e[i]) for i in range(start, len(self.e) - 1) if self.e[i] > emax * 0.01]
        self.assertLessEqual(max(steps), MAX_STEP_DB)

    def test_arcane_impact_tail_fades_to_silence(self):
        pk = max(abs(v) for v in self.x)
        last = self.x[-int(0.05 * self.sr):]
        rms = math.sqrt(sum(v * v for v in last) / len(last))
        self.assertLessEqual(_db(rms) - _db(pk), MAX_END_DB)


if __name__ == "__main__":
    unittest.main()
