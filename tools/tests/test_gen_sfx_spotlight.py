"""K1 (owner feedback 2026-10-23): the Spell / Trap spotlight cues.

Reads the committed rldb/assets/audio/sfx/spell_cast.wav and trap_spring.wav (written by tools/gen_sfx.py)
and checks they are as clean as the set pieces the owner liked, that they sit in the mix between the
everyday board sounds and the rarer set-piece climaxes, that each lands on the card's arrival (they start at once), that the Spell swells while the
Trap snaps, that the two are clearly different colours (the Trap darker), and that each is short enough
for one spotlight (FxSpotlight.HOLD, 1.85 s, plus its tail).
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_gen_sfx_set_pieces import (_db, _env, _hf_rel_db, _load, _momentary_max_lufs, _rms,  # noqa: E402
                                     MAX_END_DB, MAX_LU_DIFF)

SPELL = "spell_cast"
TRAP = "trap_spring"
NAMES = (SPELL, TRAP)
CLIMAXES = ("arcane_impact", "fusion_impact", "ritual_impact", "serpent_strike")   # the rare set pieces
BOARD = ("attack", "summon", "destroy", "sacrifice")   # the everyday board sounds
MIN_UNDER_CLIMAX_LU = 1.5   # loudest 400 ms (K-weighted): under the quietest climax by this much
MIN_OVER_BOARD_LU = 1.5     # and over the loudest board sound by this much
MAX_HF_REL_DB = -12.0     # high-passed (4 kHz) peak relative to the full peak, as the set pieces
STEP_FRAME_S = 0.02       # envelope frame for the click check (the low brass makes 5 ms frames beat)
MAX_STEP_DB = 8.0         # no second hit once the cue has started
MAX_ONSET_MS = 15.0       # the cue starts with the card's landing (first frame at 10% of the loudest)
SPELL_MIN_RISE_MS = 30.0  # the Spell blooms (10% -> 90% of its loudest 5 ms frame), as arcane_impact
TRAP_MIN_EARLY_DB = -3.0  # the Trap snaps: its first 20 ms is within 3 dB of its loudest 5 ms frame
SPELL_MAX_EARLY_DB = -5.0 # the Spell does not: its first 20 ms stays well under its bloom
MIN_BRIGHTNESS_GAP_DB = 4.0   # 1.5 kHz high-passed energy share: the Spell brighter than the Trap
MAX_LEN_S = 2.3
MIN_LEN_S = 1.0


def _hp_share_db(x, sr, fc=1500.0):
    """Energy above about `fc` (one-pole high-pass) relative to the whole signal, in dB."""
    import math
    a = 1.0 - math.exp(-2.0 * math.pi * fc / sr)
    y, hp = 0.0, []
    for v in x:
        y += a * (v - y)
        hp.append(v - y)
    return _db(_rms(hp)) - _db(_rms(x))


def _rise_ms(x, sr, frame_s=0.005):
    e = _env(x, sr, frame_s)
    emax = max(e)
    i10 = next(i for i, v in enumerate(e) if v >= 0.1 * emax)
    i90 = next(i for i, v in enumerate(e) if v >= 0.9 * emax)
    return (i90 - i10) * frame_s * 1000.0


def _early_db(x, sr):
    """The loudest 5 ms frame of the first 20 ms against the loudest frame overall, in dB."""
    e = _env(x, sr)
    return _db(max(e[:4])) - _db(max(e))


class SpotlightSoundTest(unittest.TestCase):
    def _each(self, check):
        for name in NAMES:
            with self.subTest(sound=name):
                x, sr = _load(name)
                check(name, x, sr)

    def test_spotlight_sounds_never_clip_and_keep_headroom(self):
        def check(name, x, sr):
            self.assertEqual(sum(1 for v in x if abs(v) >= 0.99997), 0)
            self.assertLessEqual(_db(max(abs(v) for v in x)), -3.0)
        self._each(check)

    def test_spotlight_sounds_have_no_harsh_noise_transient(self):
        def check(name, x, sr):
            self.assertLessEqual(_hf_rel_db(x, sr), MAX_HF_REL_DB)
        self._each(check)

    def test_spotlight_sounds_have_no_second_hit(self):
        def check(name, x, sr):
            e = _env(x, sr, STEP_FRAME_S)
            emax = max(e)
            start = next(i for i, v in enumerate(e) if v >= 0.1 * emax)
            steps = [_db(e[i + 1]) - _db(e[i]) for i in range(start + 1, len(e) - 1) if e[i] > emax * 0.01]
            self.assertLessEqual(max(steps), MAX_STEP_DB)
        self._each(check)

    def test_spotlight_sounds_fade_to_silence(self):
        def check(name, x, sr):
            last = x[-int(0.05 * sr):]
            self.assertLessEqual(_db(_rms(last)) - _db(max(abs(v) for v in x)), MAX_END_DB)
        self._each(check)

    def test_spotlight_sounds_sit_between_the_board_sounds_and_the_set_pieces(self):
        # A Spell or Trap is shown many times a game (often two back to back: a Spell, then the Trap
        # answering it), so its cue carries over the board sounds but stays under the rare set-piece
        # climaxes; and the two cues are level with each other.
        climax = min(_momentary_max_lufs(*_load(n)) for n in CLIMAXES)
        board = max(_momentary_max_lufs(*_load(n)) for n in BOARD)
        levels = {}

        def check(name, x, sr):
            lu = _momentary_max_lufs(x, sr)
            levels[name] = lu
            self.assertLessEqual(lu, climax - MIN_UNDER_CLIMAX_LU)
            self.assertGreaterEqual(lu, board + MIN_OVER_BOARD_LU)
        self._each(check)
        self.assertLessEqual(abs(levels[SPELL] - levels[TRAP]), MAX_LU_DIFF)

    def test_spotlight_sounds_start_on_the_landing_and_fit_one_spotlight(self):
        def check(name, x, sr):
            e = _env(x, sr)
            emax = max(e)
            onset = next(i for i, v in enumerate(e) if v >= 0.1 * emax) * 5.0
            self.assertLessEqual(onset, MAX_ONSET_MS)
            self.assertGreaterEqual(len(x) / sr, MIN_LEN_S)
            self.assertLessEqual(len(x) / sr, MAX_LEN_S)
        self._each(check)

    def test_spell_swells_and_trap_snaps(self):
        self.assertGreaterEqual(_rise_ms(*_load(SPELL)), SPELL_MIN_RISE_MS)
        self.assertLessEqual(_early_db(*_load(SPELL)), SPELL_MAX_EARLY_DB)
        self.assertGreaterEqual(_early_db(*_load(TRAP)), TRAP_MIN_EARLY_DB)

    def test_trap_is_darker_than_the_spell(self):
        spell = _hp_share_db(*_load(SPELL))
        trap = _hp_share_db(*_load(TRAP))
        self.assertGreaterEqual(spell - trap, MIN_BRIGHTNESS_GAP_DB)


if __name__ == "__main__":
    unittest.main()
