#!/usr/bin/env python3
"""Offline procedural SFX generator for RLDB (F02-13).

Python 3 stdlib only. Deterministic (fixed seed). Writes 44.1 kHz 16-bit mono WAVs to
rldb/assets/audio/sfx/. All audio is synthesised here: no third-party samples.

Usage: python tools/gen_sfx.py [--out DIR]
"""
import math
import os
import random
import struct
import sys
import wave
from collections import deque

SR = 44100
PEAK_DBFS = -6.0
TWO_PI = 2.0 * math.pi


# ---------------------------------------------------------------- primitives
def n_samples(sec):
    return int(sec * SR)


def silence(sec):
    return [0.0] * n_samples(sec)


def noise(rng, sec):
    return [rng.uniform(-1.0, 1.0) for _ in range(n_samples(sec))]


def env_exp(n, decay_s, attack_s=0.002):
    """Fast linear attack then exponential decay."""
    a = max(1, int(attack_s * SR))
    out = []
    for i in range(n):
        t = i / SR
        g = math.exp(-t / decay_s)
        if i < a:
            g *= i / a
        out.append(g)
    return out


def mul(a, b):
    return [x * y for x, y in zip(a, b)]


def scale(a, k):
    return [x * k for x in a]


def mix(*tracks):
    """Sum tracks of any length (each may be (offset_s, samples))."""
    length = 0
    items = []
    for t in tracks:
        off, s = t if isinstance(t, tuple) else (0.0, t)
        o = n_samples(off)
        items.append((o, s))
        length = max(length, o + len(s))
    out = [0.0] * length
    for o, s in items:
        for i, v in enumerate(s):
            out[o + i] += v
    return out


def sine(freq, sec, phase=0.0):
    return [math.sin(TWO_PI * freq * i / SR + phase) for i in range(n_samples(sec))]


def sweep(f0, f1, sec, expo=True):
    """Sine with frequency gliding f0 -> f1."""
    n = n_samples(sec)
    ph = 0.0
    out = []
    for i in range(n):
        u = i / max(1, n - 1)
        f = f0 * ((f1 / f0) ** u) if expo else f0 + (f1 - f0) * u
        ph += TWO_PI * f / SR
        out.append(math.sin(ph))
    return out


def tone(freq, sec, decay_s, partials=((1.0, 1.0),), attack_s=0.003):
    """Additive tone with exponential decay; partials = (ratio, amp)."""
    n = n_samples(sec)
    e = env_exp(n, decay_s, attack_s)
    out = [0.0] * n
    for ratio, amp in partials:
        w = TWO_PI * freq * ratio / SR
        for i in range(n):
            out[i] += amp * math.sin(w * i)
    return mul(out, e)


def bell(freq, sec, decay_s):
    return tone(freq, sec, decay_s, ((1.0, 1.0), (2.0, 0.35), (2.76, 0.25), (5.4, 0.08)))


def lowpass(x, cutoff):
    a = 1.0 - math.exp(-TWO_PI * cutoff / SR)
    y = 0.0
    out = []
    for v in x:
        y += a * (v - y)
        out.append(y)
    return out


def lowpass2(x, cutoff):
    return lowpass(lowpass(x, cutoff), cutoff)


def highpass(x, cutoff):
    lp = lowpass(x, cutoff)
    return [v - l for v, l in zip(x, lp)]


def bandpass_sweep(x, f0, f1, q=2.0):
    """State-variable band-pass with sweeping centre frequency."""
    n = len(x)
    low = band = 0.0
    out = []
    for i, v in enumerate(x):
        u = i / max(1, n - 1)
        f = f0 * ((f1 / f0) ** u)
        k = 2.0 * math.sin(math.pi * min(f, SR / 6) / SR)
        low += k * band
        high = v - low - band / q
        band += k * high
        out.append(band)
    return out


def softclip(x, drive):
    d = math.tanh(drive)
    return [math.tanh(v * drive) / d for v in x]


def fade(x, in_s=0.003, out_s=0.012):
    n = len(x)
    fi, fo = max(1, int(in_s * SR)), max(1, int(out_s * SR))
    y = list(x)
    for i in range(min(fi, n)):
        y[i] *= i / fi
    for i in range(min(fo, n)):
        y[n - 1 - i] *= i / fo
    return y


def tail(x, delay_s=0.043, fb=0.32, wet=0.35, extra_s=0.22, damp=2800.0):
    """Cheap shared 'room': two damped feedback delays. Appends a decay tail."""
    n = len(x) + n_samples(extra_s)
    src = list(x) + [0.0] * (n - len(x))
    wet_sig = [0.0] * n
    for dl, g in ((delay_s, fb), (delay_s * 1.37, fb * 0.85)):
        d = max(1, int(dl * SR))
        buf = [0.0] * n
        a = 1.0 - math.exp(-TWO_PI * damp / SR)
        lp = 0.0
        for i in range(n):
            fed = buf[i - d] if i >= d else 0.0
            lp += a * (fed - lp)
            buf[i] = src[i] + g * lp
        for i in range(n):
            wet_sig[i] += buf[i] - src[i]
    return [s + wet * w for s, w in zip(src, wet_sig)]


def finish(x, rev=True, tail_kw=None):
    """Common chain: reverb tail, gentle HF tame, DC removal, fades."""
    if rev:
        x = tail(x, **(tail_kw or {}))
    x = lowpass(x, 9000.0)
    x = highpass(x, 30.0)
    # strip DC
    m = sum(x) / len(x)
    x = [v - m for v in x]
    return fade(x)


def normalise(x, dbfs=PEAK_DBFS):
    pk = max(abs(v) for v in x) or 1.0
    k = (10 ** (dbfs / 20.0)) / pk
    return [v * k for v in x]


# ---------------------------------------------------------------- sounds
def s_card_draw(r):
    n = noise(r, 0.16)
    x = bandpass_sweep(n, 1200, 4200, q=1.6)
    x = mul(x, [math.sin(math.pi * i / len(x)) ** 1.5 for i in range(len(x))])
    return finish(x, tail_kw=dict(wet=0.15, extra_s=0.08))


def s_card_play(r):
    crack = mul(lowpass(noise(r, 0.08), 3500), env_exp(n_samples(0.08), 0.012, 0.0008))
    body = mul(sweep(190, 80, 0.2), env_exp(n_samples(0.2), 0.05, 0.001))
    return finish(mix(scale(crack, 0.9), scale(body, 1.0)), tail_kw=dict(wet=0.25, extra_s=0.15))


def s_card_set(r):
    thump = mul(lowpass(noise(r, 0.1), 900), env_exp(n_samples(0.1), 0.02, 0.003))
    body = mul(sweep(130, 65, 0.22), env_exp(n_samples(0.22), 0.06, 0.003))
    return finish(mix(scale(thump, 0.8), body), tail_kw=dict(wet=0.2, extra_s=0.12))


def s_summon(r):
    thud = mul(sweep(110, 42, 0.45), env_exp(n_samples(0.45), 0.12, 0.002))
    dust = mul(lowpass(noise(r, 0.2), 1500), env_exp(n_samples(0.2), 0.04, 0.001))
    sh = []
    for f, off in ((660, 0.12), (880, 0.17), (1320, 0.22)):
        sh.append((off, tone(f, 0.35, 0.1, ((1, 1), (2, 0.2)), attack_s=0.02)))
    shimmer = scale(mix(*sh), 0.18)
    return finish(mix(thud, scale(dust, 0.6), shimmer), tail_kw=dict(wet=0.35, extra_s=0.25))


def s_select(r):
    t = tone(1500, 0.07, 0.014, ((1, 1), (2.4, 0.4)), 0.001)
    k = mul(lowpass(noise(r, 0.02), 4000), env_exp(n_samples(0.02), 0.004, 0.0005))
    return finish(mix(t, scale(k, 0.5)), rev=True, tail_kw=dict(wet=0.12, extra_s=0.05))


def s_confirm(r):
    a = tone(587.3, 0.3, 0.09, ((1, 1), (2, 0.25), (3, 0.08)), 0.004)
    b = tone(880.0, 0.4, 0.13, ((1, 1), (2, 0.25), (3, 0.08)), 0.004)
    return finish(mix(a, (0.09, scale(b, 0.9))), tail_kw=dict(wet=0.3, extra_s=0.15))


def s_cancel(r):
    x = mul(sweep(520, 300, 0.2), env_exp(n_samples(0.2), 0.07, 0.004))
    x = mix(x, scale(mul(sweep(1040, 600, 0.2), env_exp(n_samples(0.2), 0.04, 0.004)), 0.2))
    return finish(lowpass(x, 2500), tail_kw=dict(wet=0.15, extra_s=0.08))


def s_deny(r):
    n = n_samples(0.24)
    saw = [((i * 90.0 / SR) % 1.0) * 2 - 1 for i in range(n)]
    sq = [math.copysign(1.0, math.sin(TWO_PI * 62 * i / SR)) for i in range(n)]
    x = lowpass2(mix(scale(saw, 0.6), scale(sq, 0.4)), 480)
    x = mul(x, env_exp(n, 0.1, 0.004))
    return finish(x, tail_kw=dict(wet=0.1, extra_s=0.06))


def s_attack(r):
    n = noise(r, 0.34)
    x = bandpass_sweep(n, 500, 3800, q=1.3)
    m = len(x)
    e = [(math.sin(math.pi * (i / m) ** 0.7)) ** 1.4 for i in range(m)]
    x = mul(x, e)
    return finish(x, tail_kw=dict(wet=0.2, extra_s=0.12))


def s_impact(r):
    crack = mul(highpass(lowpass(noise(r, 0.1), 5000), 600), env_exp(n_samples(0.1), 0.014, 0.0005))
    thump = mul(sweep(150, 55, 0.28), env_exp(n_samples(0.28), 0.07, 0.001))
    return finish(mix(scale(crack, 1.1), thump), tail_kw=dict(wet=0.25, extra_s=0.15))


def s_damage(r):
    thump = mul(sweep(95, 38, 0.45), env_exp(n_samples(0.45), 0.13, 0.001))
    crack = mul(lowpass(noise(r, 0.1), 2800), env_exp(n_samples(0.1), 0.018, 0.0005))
    x = softclip(mix(thump, scale(crack, 0.6)), 2.2)
    return finish(lowpass(x, 4000), tail_kw=dict(wet=0.3, extra_s=0.2))


def s_heal(r):
    notes = [523.25, 659.25, 783.99, 1046.5]
    parts = [(i * 0.08, scale(bell(f, 0.5, 0.17), 0.85 + 0.05 * i)) for i, f in enumerate(notes)]
    return finish(mix(*parts), tail_kw=dict(wet=0.4, extra_s=0.3))


def s_destroy(r):
    parts = []
    for i in range(14):
        off = (i ** 1.3) * 0.012
        dur = r.uniform(0.02, 0.05)
        cut = r.uniform(1500, 5000)
        g = math.exp(-off / 0.2)
        b = mul(lowpass(noise(r, dur), cut), env_exp(n_samples(dur), dur * 0.35, 0.0005))
        parts.append((off, scale(b, g)))
    low = mul(sweep(140, 60, 0.3), env_exp(n_samples(0.3), 0.08, 0.002))
    parts.append((0.0, scale(low, 0.8)))
    return finish(mix(*parts), tail_kw=dict(wet=0.3, extra_s=0.2))


def s_buff(r):
    parts = []
    for i, f in enumerate((660, 880, 1100, 1320, 1760)):
        parts.append((i * 0.045, tone(f, 0.3, 0.09, ((1, 1), (2, 0.2)), 0.01)))
    glide = mul(sweep(400, 1600, 0.3, expo=True), env_exp(n_samples(0.3), 0.15, 0.02))
    return finish(mix(scale(mix(*parts), 0.5), scale(glide, 0.3)), tail_kw=dict(wet=0.35, extra_s=0.2))


def s_debuff(r):
    n = n_samples(0.45)
    ph = 0.0
    x = []
    for i in range(n):
        t = i / SR
        f = 300 * math.exp(-t / 0.35) + 70 + 12 * math.sin(TWO_PI * 9 * t)
        ph += TWO_PI * f / SR
        x.append(math.sin(ph) + 0.4 * math.sin(2 * ph))
    x = mul(lowpass(x, 1200), env_exp(n, 0.22, 0.01))
    return finish(x, tail_kw=dict(wet=0.25, extra_s=0.15))


def s_turn(r):
    g = tone(130.8, 0.9, 0.28, ((1, 1), (2.0, 0.5), (2.4, 0.3), (3.0, 0.2), (4.2, 0.1)), 0.004)
    strike = mul(lowpass(noise(r, 0.03), 2500), env_exp(n_samples(0.03), 0.006, 0.0005))
    return finish(mix(g, scale(strike, 0.4)), tail_kw=dict(wet=0.4, extra_s=0.3, delay_s=0.06))


def s_phase(r):
    n = n_samples(0.3)
    x = mix(tone(392, 0.3, 1.0, ((1, 1), (2, 0.15)), 0.1), tone(587, 0.3, 1.0, ((1, 0.5),), 0.1))
    x = mul(x[:n], [math.sin(math.pi * i / n) ** 2 for i in range(n)])
    return finish(scale(x, 0.7), tail_kw=dict(wet=0.3, extra_s=0.15))


def s_notice(r):
    return finish(bell(698.5, 0.5, 0.14), tail_kw=dict(wet=0.35, extra_s=0.2))


def s_victory(r):
    notes = [(0.0, 392.0), (0.16, 523.25), (0.32, 659.25), (0.5, 783.99)]
    parts = [(o, bell(f, 0.7, 0.22)) for o, f in notes]
    chord = scale(mix(tone(261.6, 0.8, 0.4, ((1, 1), (2, 0.3)), 0.02),
                      tone(392.0, 0.8, 0.4, ((1, 1), (2, 0.3)), 0.02)), 0.4)
    parts.append((0.5, chord))
    return finish(mix(*parts), tail_kw=dict(wet=0.4, extra_s=0.4, delay_s=0.05))


def s_defeat(r):
    notes = [(0.0, 329.63), (0.22, 277.18), (0.44, 220.0)]
    parts = [(o, scale(tone(f, 0.8, 0.28, ((1, 1), (2, 0.25), (3, 0.1)), 0.01), 0.8)) for o, f in notes]
    low = mul(sweep(110, 55, 0.9), env_exp(n_samples(0.9), 0.3, 0.01))
    parts.append((0.44, scale(low, 0.7)))
    return finish(lowpass(mix(*parts), 3000), tail_kw=dict(wet=0.4, extra_s=0.3, delay_s=0.055))


def s_exhaust(r):
    """F03-16: hollow void pull. A low tone sliding down under a reversed airy swell, then a dull thud."""
    n = n_samples(0.8)
    sw = mul(sweep(420, 60, 0.8), [math.sin(math.pi * min(1.0, i / n)) ** 0.7 for i in range(n)])
    air = mul(lowpass(noise(r, 0.8), 1800), [(i / n) ** 2 * (1 - i / n) * 4 for i in range(n)])
    thud = mul(sweep(90, 40, 0.3), env_exp(n_samples(0.3), 0.12, 0.002))
    return finish(mix(scale(sw, 0.8), scale(air, 0.55), (0.5, scale(thud, 0.8))), tail_kw=dict(wet=0.5, extra_s=0.35, delay_s=0.07))


def s_fuse(r):
    """F03-17 Fusion: rising shimmer converging into a bright strike."""
    up = mul(sweep(300, 1400, 0.55), [(i / n_samples(0.55)) ** 1.5 for i in range(n_samples(0.55))])
    up2 = mul(sweep(450, 2100, 0.55), [(i / n_samples(0.55)) ** 1.8 for i in range(n_samples(0.55))])
    hit = bell(880.0, 0.6, 0.2)
    return finish(mix(scale(up, 0.5), scale(up2, 0.3), (0.55, scale(hit, 0.9))), tail_kw=dict(wet=0.4, extra_s=0.3, delay_s=0.05))


def s_ritual(r):
    """F03-17 Ritual: low pulsing drone with a deep strike."""
    n = n_samples(0.9)
    dr = mix(tone(110.0, 0.9, 0.9, ((1, 1), (2, 0.5), (3, 0.25)), 0.05), tone(164.8, 0.9, 0.9, ((1, 0.6), (2, 0.2)), 0.05))
    pulse = [0.55 + 0.45 * math.sin(TWO_PI * 5.0 * i / SR) for i in range(len(dr))]
    strike = mul(sweep(180, 45, 0.5), env_exp(n_samples(0.5), 0.2, 0.002))
    return finish(mix(scale(mul(dr, pulse), 0.5), (0.45, scale(strike, 0.9))), tail_kw=dict(wet=0.45, extra_s=0.3, delay_s=0.06))


def s_arcane(r):
    """F03-17 Arcane: glassy ascending chime arpeggio."""
    notes = [(0.0, 659.25), (0.1, 783.99), (0.2, 987.77), (0.3, 1318.5), (0.42, 1760.0)]
    parts = [(o, scale(bell(f, 0.8, 0.25), 0.7)) for o, f in notes]
    return finish(mix(*parts), tail_kw=dict(wet=0.5, extra_s=0.4, delay_s=0.045))


def s_victory_big(r):
    """F03-13 series victory: a longer rising fanfare."""
    notes = [(0.0, 392.0), (0.18, 523.25), (0.36, 659.25), (0.54, 783.99), (0.8, 1046.5)]
    parts = [(o, bell(f, 1.0, 0.3)) for o, f in notes]
    chord = scale(mix(tone(261.6, 1.6, 0.8, ((1, 1), (2, 0.3)), 0.02), tone(392.0, 1.6, 0.8, ((1, 1), (2, 0.3)), 0.02),
                      tone(523.25, 1.6, 0.8, ((1, 1), (2, 0.2)), 0.02)), 0.4)
    parts.append((0.8, chord))
    return finish(mix(*parts), tail_kw=dict(wet=0.45, extra_s=0.5, delay_s=0.05))


def s_boom(r):
    """F04-07 killing-blow explosion: a deep sub drop, a crack and a long rumbling tail."""
    sub = mul(sweep(110, 26, 1.1), env_exp(n_samples(1.1), 0.38, 0.002))
    crack = mul(lowpass(noise(r, 0.25), 3500), env_exp(n_samples(0.25), 0.05, 0.0005))
    rumble = mul(lowpass2(noise(r, 1.2), 380), env_exp(n_samples(1.2), 0.42, 0.01))
    x = softclip(mix(scale(sub, 1.2), scale(crack, 0.8), scale(rumble, 1.4)), 2.6)
    return finish(lowpass(x, 5000), tail_kw=dict(wet=0.4, extra_s=0.3, delay_s=0.06))


def s_charge(r):
    """F04-07 killing-blow wind-up: a rising swell that peaks at the impact."""
    n = n_samples(1.25)
    rise = [(i / n) ** 2.2 for i in range(n)]
    sw = mul(sweep(110, 880, 1.25, expo=True), rise)
    air = mul(bandpass_sweep(noise(r, 1.25), 300, 4200, q=1.6), rise)
    x = mix(scale(sw, 0.8), scale(air, 0.6))
    return finish(x, tail_kw=dict(wet=0.25, extra_s=0.05))


# ---------------------------------------------------------------- UI clicks (F22 / F25 / F24)
# One family: a short transient, a pitched body and a wooden "thock", so every control sounds like the
# same table. Gold (primary) buttons ring brighter and brassier; brown (secondary) ones are a darker,
# softer leather-and-wood knock; Back is a two-knock descending close; deck edits are a card slide.
def _thock(f0, f1, sec, decay):
    return mul(sweep(f0, f1, sec), env_exp(n_samples(sec), decay, 0.0008))


def s_click_primary(r):
    """F25 gold button: crisp brass tick over a short wooden thock."""
    tick = mul(highpass(noise(r, 0.012), 2500), env_exp(n_samples(0.012), 0.0018, 0.0003))
    body = tone(1320, 0.09, 0.016, ((1, 1), (2.71, 0.35), (4.13, 0.12)), 0.0008)
    low = _thock(420, 260, 0.05, 0.012)
    return finish(mix(scale(tick, 0.55), body, scale(low, 0.5)), tail_kw=dict(wet=0.1, extra_s=0.05))


def s_click_secondary(r):
    """F25 brown button: darker leather-and-wood knock, same envelope family as the gold click."""
    tick = mul(lowpass(noise(r, 0.014), 3200), env_exp(n_samples(0.014), 0.0025, 0.0004))
    body = tone(760, 0.07, 0.012, ((1, 1), (2.3, 0.25)), 0.0008)
    low = _thock(300, 180, 0.05, 0.014)
    return finish(lowpass(mix(scale(tick, 0.6), scale(body, 0.8), scale(low, 0.7)), 5000), tail_kw=dict(wet=0.08, extra_s=0.04))


def s_back(r):
    """F22 back / close: two muted knocks stepping down a fifth over a soft page-close swish."""
    swish = mul(bandpass_sweep(noise(r, 0.09), 2600, 900, q=1.4), [math.sin(math.pi * i / n_samples(0.09)) ** 1.5 for i in range(n_samples(0.09))])
    k1 = mix(tone(660, 0.07, 0.013, ((1, 1), (2.3, 0.22)), 0.0008), scale(_thock(280, 170, 0.05, 0.013), 0.6))
    k2 = mix(tone(440, 0.09, 0.018, ((1, 1), (2.3, 0.2)), 0.0008), scale(_thock(220, 130, 0.06, 0.016), 0.7))
    x = mix(scale(swish, 0.35), k1, (0.058, scale(k2, 0.85)))
    return finish(lowpass(x, 4200), tail_kw=dict(wet=0.12, extra_s=0.06))


def s_deck_add(r):
    """F24 card added to the deck: a quick upward card slide landing on a soft gold tick."""
    n = n_samples(0.09)
    slide = mul(bandpass_sweep(noise(r, 0.09), 900, 3600, q=1.6), [math.sin(math.pi * i / n) ** 1.5 for i in range(n)])
    tick = tone(1480, 0.08, 0.015, ((1, 1), (2.71, 0.3)), 0.0008)
    low = _thock(360, 240, 0.05, 0.012)
    x = mix(scale(slide, 0.55), (0.06, scale(tick, 0.7)), (0.06, scale(low, 0.45)))
    return finish(x, tail_kw=dict(wet=0.12, extra_s=0.05))


def s_deck_remove(r):
    """F24 card taken out of the deck: a downward slide into a muted low thock."""
    n = n_samples(0.1)
    slide = mul(bandpass_sweep(noise(r, 0.1), 3200, 800, q=1.6), [math.sin(math.pi * i / n) ** 1.5 for i in range(n)])
    knock = mix(tone(520, 0.08, 0.014, ((1, 1), (2.3, 0.2)), 0.0008), scale(_thock(240, 140, 0.06, 0.016), 0.8))
    x = mix(scale(slide, 0.55), (0.07, scale(knock, 0.8)))
    return finish(lowpass(x, 4500), tail_kw=dict(wet=0.1, extra_s=0.05))


def s_chat(r):
    # A1 chat message while the chat box is closed: two soft rising glass bells over a faint
    # parchment flick, quieter than a game notice so it never competes with play.
    flick = lowpass(highpass(mul(noise(r, 0.05), env_exp(n_samples(0.05), 0.012, 0.001)), 1800), 6000)
    b1 = bell(1318.5, 0.35, 0.09)
    b2 = bell(1760.0, 0.45, 0.13)
    x = mix(scale(flick, 0.35), (0.0, scale(b1, 0.55)), (0.085, scale(b2, 0.7)))
    return finish(lowpass(x, 7000), tail_kw=dict(wet=0.3, extra_s=0.18))


def s_chat_pop(r):
    # J17 new chat message (the preview bubble pops out under the Chat button): a rounded bubble
    # "bloop" (a short sine glide up with a soft body), then a bright, friendly two-bell chime a
    # fourth apart with a little sparkle on top. Clearly a message, still lighter than game sounds.
    n = n_samples(0.07)
    bloop = mul(sweep(420.0, 980.0, 0.07), env_exp(n, 0.03, 0.004))
    body = mul(sine(210.0, 0.07), env_exp(n, 0.02, 0.003))
    b1 = bell(1567.98, 0.42, 0.11)            # G6
    b2 = bell(2093.0, 0.55, 0.16)             # C7
    sparkle = mul(highpass(noise(r, 0.12), 6000), env_exp(n_samples(0.12), 0.03, 0.002))
    x = mix(scale(bloop, 0.7), scale(body, 0.25), (0.055, scale(b1, 0.6)), (0.13, scale(b2, 0.62)),
            (0.13, scale(sparkle, 0.06)))
    return finish(lowpass(x, 8500), tail_kw=dict(wet=0.28, extra_s=0.2))


# ---------------------------------------------------------------- set pieces (D8 / B5 / D6, 2026-10-20)
# Layered designs: each set piece has an anticipation layer that swells into its climax (played at the start)
# and a separate climax hit, so the climax always lands on the visual flash whatever the frame rate.
def saw(freq, sec, detune_cents=0.0, vib_hz=0.0, vib_depth=0.0, phase=0.0):
    """Band-limited-ish sawtooth (8 additive partials) with optional vibrato."""
    n = n_samples(sec)
    f = freq * (2.0 ** (detune_cents / 1200.0))
    out = []
    ph = phase
    for i in range(n):
        fi = f * (1.0 + vib_depth * math.sin(TWO_PI * vib_hz * i / SR))
        ph += TWO_PI * fi / SR
        v = 0.0
        for k in range(1, 9):
            v += math.sin(ph * k) / k
        out.append(v * 0.55)
    return out


def formant(x, centres):
    """Parallel fixed band-passes (vowel formants): centres = ((freq, q, gain), ...)."""
    return mix(*[scale(bandpass_sweep(x, f, f, q), g) for f, q, g in centres])


def swell(n, peak_at, attack_pow=1.8, release_s=0.25):
    """Envelope rising (power curve) to 1 at sample `peak_at`, then an exponential release."""
    out = []
    for i in range(n):
        if i < peak_at:
            out.append((i / max(1, peak_at)) ** attack_pow)
        else:
            out.append(math.exp(-(i - peak_at) / SR / release_s))
    return out


AAH = ((730.0, 6.0, 1.0), (1090.0, 7.0, 0.5), (2440.0, 8.0, 0.22))


def _choir(r, notes, sec, peak_s, release_s):
    n = n_samples(sec)
    voices = []
    for vi, f in enumerate(notes):
        for d in (-7.0, 0.0, 6.0):
            voices.append(saw(f, sec, d, 4.6 + 0.3 * vi + 0.1 * d, 0.004, r.uniform(0, TWO_PI)))
    body = formant(mix(*voices), AAH)
    breath = scale(formant(lowpass(noise(r, sec), 5000), AAH), 0.12)
    return mul(mix(body, breath), swell(n, n_samples(peak_s), 1.6, release_s))


OOH = ((320.0, 6.0, 1.0), (800.0, 7.0, 0.35), (2300.0, 8.0, 0.1))


def _vowel_choir(r, notes, sec, vowel_a, vowel_b, vib_hz=4.8):
    """H29: a dark choir: three slightly detuned voices per note through formant band-passes that glide
    from vowel `vowel_a` to `vowel_b` (e.g. 'ooh' opening to 'aah'), darkened. notes = ((freq, start_s,
    attack_s, amp), ...); each voice enters with a raised-cosine swell."""
    n = n_samples(sec)
    body = [0.0] * n
    for vi, (f, st, at, amp) in enumerate(notes):
        v = mix(*[saw(f, sec, d, vib_hz + 0.27 * vi + 0.08 * d, 0.0035, r.uniform(0, TWO_PI)) for d in (-8.0, 0.0, 7.0)])
        s0, na = n_samples(st), max(1, n_samples(at))
        for i in range(n):
            j = i - s0
            v[i] *= 0.0 if j < 0 else (amp * (0.5 - 0.5 * math.cos(math.pi * j / na)) if j < na else amp)
        body = mix(body, v)
    breath = scale(lowpass(noise(r, sec), 4000.0), 0.1)
    src = mix(body, breath)
    out = mix(*[scale(bandpass_sweep(src, fa, fb, qa), 0.5 * (ga + gb)) for (fa, qa, ga), (fb, _qb, gb) in zip(vowel_a, vowel_b)])
    return lowpass(out, 3200.0)


def _drum(r, f0, f1, dec, amp):
    """A soft-skinned ritual drum: a pitched body dropping f0 -> f1 with an 8 ms rounded attack and a
    low (250 Hz) skin, never a crack. Tapered to silence."""
    sec = dec * 6.0
    n = n_samples(sec)
    a = n_samples(0.008)
    env = [(0.5 - 0.5 * math.cos(math.pi * min(1.0, i / a))) * math.exp(-i / SR / dec) for i in range(n)]
    body = mul(sweep(f0, f1, sec), env)
    skin = mul(lowpass2(noise(r, sec), 250.0), [(0.5 - 0.5 * math.cos(math.pi * min(1.0, i / n_samples(0.012)))) * math.exp(-i / SR / (dec * 0.4)) for i in range(n)])
    return taper(scale(mix(body, scale(skin, 0.6)), amp), sec * 0.4)


GONG = ((1.0, 1.0, 1.6, 0.012), (1.48, 0.55, 1.1, 0.12), (2.0, 0.42, 0.9, 0.2), (2.76, 0.3, 0.7, 0.3),
        (3.6, 0.2, 0.55, 0.4), (4.4, 0.13, 0.45, 0.45), (5.4, 0.08, 0.35, 0.5))


def s_ritual_choir(r):
    """D8 / H29 Ritual anticipation: dark and sacred. A low choir drone on an open fifth (A2-E3-A3) swells
    from 'ooh' to 'aah' as the minor third (C4) enters, over an A1 drone, while a ritual heartbeat
    (soft low drums, lub-dub) quickens toward the climax (0.88 s). The choir crests with the last beat at
    0.75 s and draws a breath, so the gong tolls out of a hush. A long, dark temple hall."""
    sec = 1.05
    climax = 0.75
    ch = _vowel_choir(r, ((110.0, 0.0, 0.5, 0.9), (164.81, 0.04, 0.5, 0.7), (220.0, 0.12, 0.45, 0.6), (261.63, 0.38, 0.35, 0.45)),
                      sec, OOH, AAH)
    n = n_samples(sec)
    sw = [((i / n_samples(climax)) ** 1.5) if i < n_samples(climax) else math.exp(-(i - n_samples(climax)) / SR / 0.06) for i in range(n)]
    drone = mul(tone(55.0, sec, 4.0, ((1, 1), (2, 0.3), (3, 0.1)), 0.3), sw)
    beats = []
    for t, amp in ((0.06, 0.45), (0.36, 0.62), (0.58, 0.8), (0.74, 1.0)):
        beats.append((t, _drum(r, 64.0, 46.0, 0.11, amp)))
        if t < 0.7:
            beats.append((t + 0.15, _drum(r, 58.0, 44.0, 0.09, amp * 0.6)))
    drums = mix(*beats)
    x = mix(scale(taper(mul(ch, sw), 0.15), 1.0), scale(taper(drone, 0.15), 0.5), scale(drums, 0.9))
    x = hall(x, wet=0.5, predelay_s=0.03, rt60=2.4, damp=3500.0, extra_s=0.45)
    return finish(taper(x, 0.45), rev=False)


def s_ritual_impact(r):
    """D8 / H29 Ritual climax: ominous grandeur. A temple gong on A1 tolls with a soft mallet, its upper
    partials blooming in after the strike; a deep ritual drum and an A1 sub give it weight, and the choir
    swells into a solemn chord that resolves from a suspended fourth (A-D-E) into A minor (A-C-E), the key
    of the build-up. A very long, dark temple hall; no crash, no soft-clip."""
    sec = 2.4
    n = n_samples(sec)
    gong = [0.0] * n
    for ratio, amp, dec, bloom in GONG:
        f = 55.0 * ratio
        nb = max(1, n_samples(bloom))
        part = mul(sweep(f * 0.995, f, sec), [(0.5 - 0.5 * math.cos(math.pi * min(1.0, i / nb))) * math.exp(-i / SR / dec) for i in range(n)])
        gong = mix(gong, scale(part, amp))
    drum = _drum(r, 78.0, 42.0, 0.3, 1.0)
    sub = mul(sine(55.0, sec), [(0.5 - 0.5 * math.cos(math.pi * min(1.0, i / n_samples(0.06)))) * math.exp(-i / SR / 0.7) for i in range(n)])
    # The suspension: D4 sounds first and gives way to C4 at 0.2 s.
    sus = _vowel_choir(r, ((293.66, 0.0, 0.1, 0.5),), 0.5, AAH, AAH)
    sus = mul(sus, [1.0 if i < n_samples(0.18) else max(0.0, 1.0 - (i - n_samples(0.18)) / n_samples(0.2)) for i in range(len(sus))])
    ch = _vowel_choir(r, ((110.0, 0.0, 0.12, 0.9), (164.81, 0.0, 0.12, 0.7), (220.0, 0.02, 0.14, 0.65), (261.63, 0.18, 0.2, 0.5),
                          (329.63, 0.05, 0.18, 0.4)), sec, OOH, AAH)
    ch = mul(mix(ch, sus), [math.exp(-i / SR / 1.1) for i in range(n)])
    x = mix(scale(taper(gong, 0.8), 0.6), scale(drum, 0.8), scale(taper(sub, 0.6), 0.4), scale(taper(ch, 0.8), 0.9))
    x = hall(x, wet=0.6, predelay_s=0.035, rt60=3.0, damp=3200.0, extra_s=0.45)
    x = smooth_limit(x, 3.0)
    return finish(taper(x, 0.8), rev=False)


PENTA = (1318.5, 1567.98, 1760.0, 2093.0, 2349.3, 2637.0, 3136.0, 3520.0, 4186.0)


def s_arcane_shimmer(r):
    """D8 Arcane anticipation: crystalline shimmer, glassy grains thickening into the climax over a rising
    FM glass tone and air."""
    sec = 0.95
    n = n_samples(sec)
    parts = []
    for i in range(46):
        u = r.random() ** 0.55            # grains crowd toward the climax
        f = r.choice(PENTA) * r.choice((1.0, 1.0, 0.5))
        g = 0.25 + 0.5 * u
        parts.append((u * (sec - 0.12), scale(tone(f, 0.25, r.uniform(0.05, 0.14), ((1, 1), (2.76, 0.25), (5.4, 0.08)), 0.001), g)))
    grains = mix(*parts)
    ph = 0.0
    glass = []
    for i in range(n):
        u = i / n
        fc = 600.0 * (3.0 ** u)
        ph += TWO_PI * fc / SR
        glass.append(math.sin(ph + 1.4 * math.sin(ph * 3.5)) * (u ** 1.8))
    air = mul(highpass(noise(r, sec), 4000), [(i / n) ** 2.4 for i in range(n)])
    return finish(mix(scale(grains, 0.8), scale(glass, 0.35), scale(air, 0.25)), tail_kw=dict(wet=0.5, extra_s=0.4, delay_s=0.045))


def hall(x, wet=0.4, predelay_s=0.02, rt60=2.0, damp=6000.0, extra_s=1.0):
    """A smoother, longer 'hall' than tail(): four damped parallel combs and two all-passes (Schroeder),
    after a pre-delay. Appends `extra_s` of decay. Used where a long airy tail must not flutter."""
    n = len(x) + n_samples(extra_s)
    src = list(x) + [0.0] * (n - len(x))
    pd = n_samples(predelay_s)
    a = 1.0 - math.exp(-TWO_PI * damp / SR)
    acc = [0.0] * n
    for ms in (29.7, 37.1, 41.1, 43.7):
        d = int(ms * SR / 1000.0)
        g = 10.0 ** (-3.0 * (ms / 1000.0) / rt60)
        buf = [0.0] * n
        lp = 0.0
        for i in range(n):
            inp = src[i - pd] if i >= pd else 0.0
            fed = buf[i - d] if i >= d else 0.0
            lp += a * (fed - lp)
            buf[i] = inp + g * lp
            acc[i] += fed
    y = acc
    for ms, g in ((5.0, 0.7), (1.7, 0.7)):
        d = int(ms * SR / 1000.0)
        out = [0.0] * n
        for i in range(n):
            xd = y[i - d] if i >= d else 0.0
            yd = out[i - d] if i >= d else 0.0
            out[i] = -g * y[i] + xd + g * yd
        y = out
    k = wet * 0.25
    return [s + k * v for s, v in zip(src, y)]


def _glass_voice(r, f, sec, start_s, attack_s, decay_s):
    """A glass-harmonica voice: three slowly drifting, detuned near-sines (a slow chorus), swelling in
    with a raised-cosine attack at `start_s` and dying away exponentially. No hit, no click."""
    n = n_samples(sec)
    out = [0.0] * n
    s0, na = n_samples(start_s), max(1, n_samples(attack_s))
    for cents in (-6.0, 0.0, 7.0):
        base = f * 2.0 ** (cents / 1200.0)
        lfo_w = TWO_PI * r.uniform(0.22, 0.45) / SR
        lfo_ph = r.uniform(0.0, TWO_PI)
        ph = r.uniform(0.0, TWO_PI)
        for i in range(s0, n):
            ph += TWO_PI * base * (1.0 + 0.0018 * math.sin(lfo_ph + lfo_w * i)) / SR
            out[i] += math.sin(ph) + 0.12 * math.sin(2.0 * ph) + 0.035 * math.sin(3.0 * ph)
    for i in range(n):
        j = i - s0
        if j < 0:
            out[i] = 0.0
            continue
        g = math.exp(-j / SR / decay_s)
        if j < na:
            g *= 0.5 - 0.5 * math.cos(math.pi * j / na)
        out[i] *= g / 3.0
    return out


def taper(x, out_s):
    """Rounds the last `out_s` seconds of `x` down to silence (a raised-cosine fade), so a voice that is
    still ringing when its buffer ends dies away instead of stopping with a click."""
    y = list(x)
    n, nf = len(y), min(len(y), max(1, n_samples(out_s)))
    for i in range(nf):
        y[n - 1 - i] *= 0.5 - 0.5 * math.cos(math.pi * i / nf)
    return y


def smooth_limit(x, reduce_db, look_s=0.01, release_s=0.3):
    """A clean look-ahead peak limiter: pulls the loudest peaks down by `reduce_db` with a gain that
    falls ahead of each peak and recovers slowly, so it lowers the crest factor without the
    harmonics of soft-clip."""
    n = len(x)
    pk = max(abs(v) for v in x) or 1.0
    thr = pk * 10.0 ** (-reduce_db / 20.0)
    req = [min(1.0, thr / abs(v)) if v else 1.0 for v in x]
    w = max(1, n_samples(look_s))
    # Minimum of the required gain over +-w (a sliding window minimum, monotonic deque).
    win = [1.0] * n
    dq = deque()
    for i in range(n + w):
        if i < n:
            while dq and req[dq[-1]] >= req[i]:
                dq.pop()
            dq.append(i)
        c = i - w
        while dq and dq[0] < c - w:
            dq.popleft()
        if 0 <= c < n:
            win[c] = req[dq[0]]
    rel = 1.0 - math.exp(-1.0 / (release_s * SR))
    g, gains = 1.0, [0.0] * n
    for i in range(n):
        g = min(win[i], g + (1.0 - g) * rel)
        gains[i] = g
    # Round the gain's corners with a moving average no wider than the look-ahead.
    h = max(1, w // 2)
    acc = sum(gains[0:h])
    out = [0.0] * n
    for i in range(n):
        if i + h < n:
            acc += gains[i + h]
        if i - h - 1 >= 0:
            acc -= gains[i - h - 1]
        cnt = min(n - 1, i + h) - max(0, i - h) + 1
        out[i] = x[i] * acc / cnt
    return out


def s_arcane_impact(r):
    """D8 Arcane climax (H28: mystical, not jarring): the lattice resolves into light. An open Dsus2
    glass-harmonica chord (D-A-E-A-D, inside the shimmer's C pentatonic, so the build-up resolves into
    it) blooms upward voice by voice with slow chorus, under a soft glass 'ting', a warm sub bloom,
    a breath of air and a sparkle that climbs and fades; all of it rings out into a long airy hall.
    No noise bursts, no soft-clip, no hit: the softest attack that still lands on the flash."""
    sec = 2.0
    chord = [0.0] * n_samples(sec)
    # (freq, start, attack, decay, amp): the low voices first, the top voices bloom in after.
    for f, st, at, dec, amp in ((293.66, 0.0, 0.03, 1.5, 0.85), (440.0, 0.02, 0.035, 1.3, 0.75),
                                (659.25, 0.045, 0.04, 1.1, 0.62), (880.0, 0.075, 0.05, 0.95, 0.5),
                                (1174.66, 0.11, 0.06, 0.8, 0.4)):
        chord = mix(chord, scale(_glass_voice(r, f, sec, st, at, dec), amp))
    # A high halo (A6) swells in slowly over the bloom: the light that hangs in the air after the flash.
    chord = taper(mix(chord, scale(_glass_voice(r, 1760.0, sec, 0.05, 0.35, 0.7), 0.16)), 0.7)
    # A soft glass 'ting' marks the instant: pure sines with a 6 ms rounded attack.
    ting = taper(mix(scale(tone(1318.5, 1.3, 0.34, ((1, 1), (2.0, 0.08)), 0.006), 0.26),
                     scale(tone(1760.0, 1.3, 0.28, ((1, 1),), 0.006), 0.2)), 0.4)
    # Sub bloom for weight: D2 settling from a touch above, with an 80 ms swell (no punch).
    ns = n_samples(1.6)
    sub = taper(mul(sweep(82.0, 73.42, 1.6), [(0.5 - 0.5 * math.cos(math.pi * min(1.0, i / n_samples(0.08)))) * math.exp(-i / SR / 0.5)
                                              for i in range(ns)]), 0.5)
    # A breath of air, swelling then fading (filtered, never a burst).
    na = n_samples(1.2)
    air = taper(mul(lowpass2(highpass(noise(r, 1.2), 3000.0), 8000.0),
                    [(min(1.0, i / n_samples(0.07)) ** 2) * math.exp(-i / SR / 0.35) for i in range(na)]), 0.4)
    # The sparkle climbs through the pentatonic and thins out.
    parts = []
    for k in range(16):
        off = 0.06 + 0.95 * (k / 15.0) ** 1.35
        f = PENTA[min(len(PENTA) - 1, k * len(PENTA) // 16)] * r.choice((1.0, 1.0, 1.0025))
        g = 0.4 * math.exp(-off / 0.55) * r.uniform(0.75, 1.0)
        parts.append((off, scale(taper(tone(f, 0.7, r.uniform(0.09, 0.16), ((1, 1), (2.0, 0.06)), 0.004), 0.2), g)))
    sparkle = mix(*parts)
    x = mix(scale(chord, 1.0), scale(ting, 1.0), scale(sub, 0.5), scale(air, 0.08), scale(sparkle, 1.0))
    x = hall(x, wet=0.55, predelay_s=0.022, rt60=2.2, damp=6500.0, extra_s=0.35)
    # Level the dense bloom (several voices peak together) so its loudness matches the other climaxes.
    x = smooth_limit(x, 4.0)
    # A long, smooth fade so the hall dies away instead of stopping.
    return finish(taper(x, 0.7), rev=False)


def _brass_voice(f0, f1, glide_s, sec, start_s, attack_s, decay_s, bright, cents=0.0, phase=0.0, partials=10):
    """H29: a brass-like voice: additive partials (1/k) behind a 'lip' brightness that opens and closes,
    so it blooms 'bwaah' instead of hitting. Glides f0 -> f1 over `glide_s` (exponential), enters at
    `start_s` with a raised-cosine attack and decays exponentially. `bright(t)` gives the roll-off
    (about 1 = mellow, 6 = blazing) at time t after the start. Partials above 8 kHz are left out."""
    n = n_samples(sec)
    out = [0.0] * n
    s0, na = n_samples(start_s), max(1, n_samples(attack_s))
    k_det = 2.0 ** (cents / 1200.0)
    ph = phase
    ng = max(1, n_samples(glide_s))
    for i in range(s0, n):
        j = i - s0
        f = (f0 * (f1 / f0) ** min(1.0, j / ng)) * k_det
        ph += TWO_PI * f / SR
        q = math.exp(-1.0 / max(0.3, bright(j / SR)))
        a, v = 1.0, 0.0
        for k in range(1, partials + 1):
            if f * k > 8000.0:
                break
            v += a * math.sin(ph * k) / k
            a *= q
        g = math.exp(-j / SR / decay_s)
        if j < na:
            g *= 0.5 - 0.5 * math.cos(math.pi * j / na)
        out[i] = v * g
    return out


def s_fusion_vortex(r):
    """D8 / H29 Fusion anticipation: two forces drawn together. Two brass-like tones, G2 rising and F3
    falling, glide into one C3 unison just before the climax (0.78 s), beating faster as they close and
    opening from mellow to blazing; a swirling vortex of wind spins faster around them and a C2 sub rises
    underneath. Everything swells to 0.72 s and then draws in, a breath before the forge blooms."""
    sec = 0.92
    climax = 0.72
    n, nc = n_samples(sec), n_samples(climax)
    sw = [((i / nc) ** 1.8) if i < nc else math.exp(-(i - nc) / SR / 0.045) for i in range(n)]
    bright = lambda t: 1.2 + 4.3 * min(1.0, t / climax) ** 1.5
    a = _brass_voice(98.0, 130.81, climax, sec, 0.0, 0.2, 9.0, bright, 0.0, r.uniform(0, TWO_PI))
    b = _brass_voice(174.61, 130.81, climax, sec, 0.0, 0.2, 9.0, bright, 2.0, r.uniform(0, TWO_PI))
    sub = sweep(49.0, 65.41, sec)
    wind = lowpass(bandpass_sweep(noise(r, sec), 300.0, 2000.0, q=3.0), 3000.0)
    ph = 0.0
    rot = []
    for i in range(n):
        u = i / n
        ph += TWO_PI * (3.0 + 11.0 * u * u) / SR
        rot.append(0.55 + 0.45 * math.sin(ph))
    x = taper(mix(scale(mul(mix(a, b), sw), 0.6), scale(mul(sub, sw), 0.12), scale(mul(mul(wind, rot), sw), 1.1)), 0.1)
    x = hall(x, wet=0.3, predelay_s=0.015, rt60=1.2, damp=4500.0, extra_s=0.25)
    x = smooth_limit(x, 4.0)
    return finish(taper(x, 0.22), rev=False)


def s_fusion_impact(r):
    """D8 / H29 Fusion climax: the forces forge into one. A low brass C major chord (C2-C3-G3-C4-E4, the
    unison the build-up converged on) blooms open with a 45 ms swell and mellows as it rings, over a deep
    soft-mallet boom; a heroic fifth (G4-C5) rises out of it and a forge glint sparks on top. A warm hall,
    no crack, no soft-clip."""
    sec = 2.0
    bloom = lambda t: 2.0 + 5.0 * (min(1.0, t / 0.08) if t < 0.08 else math.exp(-(t - 0.08) / 0.5))
    chord = [0.0] * n_samples(sec)
    for f, st, amp, dec in ((65.41, 0.0, 0.4, 1.2), (130.81, 0.0, 0.8, 1.1), (196.0, 0.01, 0.7, 1.0),
                            (261.63, 0.02, 0.65, 0.9), (329.63, 0.03, 0.55, 0.8)):
        for c in (-5.0, 5.0):
            chord = mix(chord, scale(_brass_voice(f, f, 0.0, sec, st, 0.045, dec, bloom, c, r.uniform(0, TWO_PI)), amp * 0.5))
    horn = lambda t: 1.2 + 1.8 * min(1.0, t / 0.2)
    rise = mix(_brass_voice(392.0, 392.0, 0.0, sec, 0.12, 0.18, 0.7, horn, 0.0, r.uniform(0, TWO_PI)),
               scale(_brass_voice(523.25, 523.25, 0.0, sec, 0.16, 0.18, 0.65, horn, 3.0, r.uniform(0, TWO_PI)), 0.8))
    glint = taper(tone(1046.5, 0.9, 0.3, ((1, 0.12), (2.4, 0.05), (3.9, 0.03)), 0.006), 0.3)
    nb = n_samples(1.4)
    boom = taper(mul(sweep(72.0, 41.0, 1.4), [(0.5 - 0.5 * math.cos(math.pi * min(1.0, i / n_samples(0.012)))) * math.exp(-i / SR / 0.4)
                                              for i in range(nb)]), 0.4)
    x = mix(scale(taper(chord, 0.6), 1.0), scale(taper(rise, 0.6), 0.5), scale(glint, 1.0), scale(boom, 0.45))
    x = hall(x, wet=0.45, predelay_s=0.02, rt60=2.0, damp=4500.0, extra_s=0.4)
    x = smooth_limit(x, 5.0)
    return finish(taper(x, 0.7), rev=False)


def s_card_slam(r):
    """D8 landing: a card slammed down on the wooden table: low thump, wood knock and a puff of dust."""
    thump = mul(sweep(130.0, 48.0, 0.3), env_exp(n_samples(0.3), 0.08, 0.0008))
    knock = tone(210.0, 0.15, 0.04, ((1, 1), (2.3, 0.4), (3.9, 0.15)), 0.0005)
    dust = mul(lowpass(noise(r, 0.3), 1600), env_exp(n_samples(0.3), 0.09, 0.004))
    return finish(softclip(mix(scale(thump, 1.1), scale(knock, 0.6), scale(dust, 0.35)), 1.6), tail_kw=dict(wet=0.22, extra_s=0.12))


def s_serpent_coil(r):
    """B5: the Serpents rise and coil: a hiss swelling and fading, a watery swirl and a low rising tone."""
    sec = 1.3
    n = n_samples(sec)
    hiss = mul(highpass(noise(r, sec), 3200), [0.4 + 0.6 * abs(math.sin(math.pi * (i / n) * 2.5)) * (i / n) for i in range(n)])
    swirl_src = noise(r, sec)
    swirl = []
    low = band = 0.0
    for i, v in enumerate(swirl_src):
        u = i / n
        f = 700.0 + 450.0 * math.sin(TWO_PI * (1.2 + 2.5 * u) * u)
        k = 2.0 * math.sin(math.pi * f / SR)
        low += k * band
        high = v - low - band / 3.0
        band += k * high
        swirl.append(band * (0.3 + 0.7 * u))
    ph = 0.0
    tonal = []
    for i in range(n):
        u = i / n
        ph += TWO_PI * (70.0 + 70.0 * u) * (1.0 + 0.01 * math.sin(TWO_PI * 5.0 * i / SR)) / SR
        tonal.append(math.sin(ph) * (u ** 1.2))
    return finish(mix(scale(hiss, 0.35), scale(swirl, 0.9), scale(tonal, 0.55)), tail_kw=dict(wet=0.4, extra_s=0.25, delay_s=0.06))


def s_serpent_strike(r):
    """B5: the serpent darts (rising whoosh) and lands on the plate: a heavy water splash, sub and bubbles."""
    wsec = 0.23
    wn = n_samples(wsec)
    whoosh = mul(bandpass_sweep(noise(r, wsec), 600.0, 3600.0, q=1.8), [(i / wn) ** 1.5 for i in range(wn)])
    splash = mul(lowpass(noise(r, 0.5), 4200), env_exp(n_samples(0.5), 0.12, 0.001))
    sub = mul(sweep(95.0, 32.0, 0.8), env_exp(n_samples(0.8), 0.24, 0.002))
    bubbles = []
    for i in range(14):
        off = r.uniform(0.02, 0.35)
        f0 = r.uniform(280.0, 520.0)
        b = mul(sweep(f0, f0 * 2.4, 0.03), env_exp(n_samples(0.03), 0.012, 0.001))
        bubbles.append((off, scale(b, 0.35 * math.exp(-off / 0.25))))
    hit = softclip(mix(scale(splash, 1.0), scale(sub, 1.1), mix(*bubbles)), 2.0)
    return finish(mix(scale(whoosh, 0.9), (wsec, hit)), tail_kw=dict(wet=0.38, extra_s=0.3, delay_s=0.05))


def s_sacrifice(r):
    """D6: a unit consumed: a soft fire whoosh, crackling, a low tone sinking away and embers rising."""
    sec = 0.9
    n = n_samples(sec)
    whoosh = mul(bandpass_sweep(noise(r, sec), 300.0, 1500.0, q=1.4), [math.sin(math.pi * min(1.0, i / (n * 0.7))) ** 1.4 for i in range(n)])
    cr = []
    for i in range(36):
        off = r.uniform(0.05, 0.75)
        dur = r.uniform(0.003, 0.009)
        cr.append((off, scale(mul(highpass(noise(r, dur), 2000), env_exp(n_samples(dur), dur * 0.3, 0.0002)), r.uniform(0.3, 0.8))))
    sink = mul(sweep(220.0, 105.0, 0.8), env_exp(n_samples(0.8), 0.3, 0.02))
    rise = mix(*[(0.42 + 0.06 * k, scale(bell(f, 0.35, 0.09), 0.3)) for k, f in enumerate((1046.5, 1318.5, 1568.0))])
    return finish(mix(scale(whoosh, 0.9), scale(mix(*cr), 0.5), scale(sink, 0.4), rise), tail_kw=dict(wet=0.35, extra_s=0.25))


def s_ap_gain(r):
    """D6: AP gained: a bright two-note amber twinkle with a tiny sparkle."""
    a = bell(1046.5, 0.35, 0.09)
    b = bell(1567.98, 0.4, 0.11)
    sp = mul(highpass(noise(r, 0.08), 6000), env_exp(n_samples(0.08), 0.02, 0.001))
    return finish(mix(scale(a, 0.7), (0.06, scale(b, 0.8)), (0.06, scale(sp, 0.2))), tail_kw=dict(wet=0.3, extra_s=0.15))


def s_ap_loss(r):
    """D6: AP lost: a dull, short descending blip."""
    x = mul(sweep(520.0, 330.0, 0.22), env_exp(n_samples(0.22), 0.07, 0.003))
    y = mul(sweep(1040.0, 660.0, 0.22), env_exp(n_samples(0.22), 0.04, 0.003))
    return finish(lowpass(mix(x, scale(y, 0.25)), 2600), tail_kw=dict(wet=0.22, extra_s=0.12))


# ---------------------------------------------------------------- UI feedback (H1 WP-1, design review 1.4.6)
# The same warm wood, brass and leather family as the clicks, but quieter and shorter: hover and
# toggles sit far under the music, the panel cues are a parchment movement with a faint brass ring.
def s_ui_hover(r):
    """Button / menu-item hover: a very soft brass brush with a faint wooden tick, about 40 ms."""
    n = n_samples(0.04)
    brush = mul(bandpass_sweep(noise(r, 0.04), 2400, 4200, q=1.3), [math.sin(math.pi * i / n) ** 2 for i in range(n)])
    tick = tone(2350, 0.03, 0.006, ((1, 1), (2.6, 0.2)), 0.0006)
    knock = _thock(520, 380, 0.03, 0.006)
    return finish(lowpass(mix(scale(brush, 0.7), scale(tick, 0.35), scale(knock, 0.25)), 6500), tail_kw=dict(wet=0.06, extra_s=0.03))


def _parchment(r, sec, f0, f1):
    """A paper movement: band-passed noise swept f0 -> f1 with a fine crinkle (random grain bursts)."""
    n = n_samples(sec)
    body = mul(bandpass_sweep(noise(r, sec), f0, f1, q=1.2), [math.sin(math.pi * i / n) ** 1.3 for i in range(n)])
    crinkle = []
    for _ in range(int(sec * 70)):
        off = r.uniform(0.0, sec * 0.85)
        d = r.uniform(0.002, 0.006)
        crinkle.append((off, scale(mul(highpass(noise(r, d), 2500), env_exp(n_samples(d), d * 0.3, 0.0003)), r.uniform(0.15, 0.45))))
    return mix(body, scale(mix(*crinkle), 0.35))


def s_panel_open(r):
    """Modal open: a parchment unfurl rising in pitch under a low, slow brass shimmer, about 250 ms."""
    paper = _parchment(r, 0.22, 600, 2800)
    n = n_samples(0.42)
    swell_env = [min(1.0, (i / (n * 0.35))) ** 1.6 * math.exp(-max(0.0, i / SR - 0.15) / 0.12) for i in range(n)]
    brass = mul(mix(tone(392.0, 0.42, 10.0, ((1, 1), (2, 0.4), (3, 0.18), (4.01, 0.08)), 0.01),
                    scale(tone(587.3, 0.42, 10.0, ((1, 1), (2, 0.3)), 0.01), 0.6)), swell_env)
    shimmer = mul(highpass(noise(r, 0.3), 6500), [math.sin(math.pi * i / n_samples(0.3)) ** 2 * 0.5 for i in range(n_samples(0.3))])
    return finish(mix(scale(paper, 0.8), (0.03, scale(lowpass(brass, 3000), 0.32)), (0.06, scale(shimmer, 0.06))), tail_kw=dict(wet=0.22, extra_s=0.12))


def s_panel_close(r):
    """Modal close: the unfurl reversed and shorter (falling paper, a lower brass touch), about 160 ms."""
    paper = _parchment(r, 0.14, 2600, 650)
    n = n_samples(0.26)
    env = [min(1.0, i / (n * 0.08)) * math.exp(-i / SR / 0.07) for i in range(n)]
    brass = mul(tone(329.6, 0.26, 10.0, ((1, 1), (2, 0.35), (3, 0.12)), 0.004), env)
    return finish(mix(scale(paper, 0.8), (0.02, scale(lowpass(brass, 2400), 0.28))), tail_kw=dict(wet=0.16, extra_s=0.08))


def s_tab(r):
    """Tab switch: a leather-flap thump, about 90 ms."""
    flap = mul(lowpass(noise(r, 0.05), 1400), env_exp(n_samples(0.05), 0.012, 0.001))
    thump = _thock(170, 85, 0.09, 0.026)
    slap = mul(bandpass_sweep(noise(r, 0.02), 1800, 900, q=1.5), env_exp(n_samples(0.02), 0.004, 0.0005))
    return finish(lowpass(mix(scale(flap, 0.6), thump, scale(slap, 0.3)), 3500), tail_kw=dict(wet=0.08, extra_s=0.04))


def _latch(r, f_a, f_b):
    """A small brass latch: two clicks a few ms apart at pitches f_a then f_b."""
    def click(f):
        t = mul(highpass(noise(r, 0.008), 3000), env_exp(n_samples(0.008), 0.0012, 0.0002))
        b = tone(f, 0.05, 0.008, ((1, 1), (2.7, 0.3)), 0.0005)
        return mix(scale(t, 0.6), b)
    return mix(click(f_a), (0.028, scale(click(f_b), 0.85)), scale(_thock(380, 260, 0.04, 0.008), 0.3))


def s_toggle_on(r):
    """Check box / toggle on: a latch closing, stepping up."""
    return finish(lowpass(_latch(r, 1700, 2300), 7000), tail_kw=dict(wet=0.08, extra_s=0.04))


def s_toggle_off(r):
    """Check box / toggle off: the same latch, stepping down."""
    return finish(lowpass(_latch(r, 1900, 1350), 6000), tail_kw=dict(wet=0.08, extra_s=0.04))


def s_hp_low_heartbeat(r):
    """Low HP (D4): a soft, warm lub-dub felt more than heard: two low thumps with a body knock."""
    def beat(f0, f1, amp):
        sub = mul(sweep(f0, f1, 0.2), env_exp(n_samples(0.2), 0.06, 0.004))
        body = mul(lowpass(noise(r, 0.05), 300), env_exp(n_samples(0.05), 0.012, 0.002))
        return scale(mix(sub, scale(body, 0.4)), amp)
    x = mix(beat(78.0, 46.0, 1.0), (0.21, beat(70.0, 42.0, 0.72)))
    return finish(lowpass(softclip(x, 1.3), 900), tail_kw=dict(wet=0.12, extra_s=0.15, damp=900.0))


# ---------------------------------------------------------------- H1 WP-9 motion and sound pass
def s_card_hover(r):
    """Card hover (design review #32): a soft paper slide, a card lifted off the felt, about 60 ms."""
    n = n_samples(0.06)
    slide = mul(bandpass_sweep(noise(r, 0.06), 1500, 3400, q=1.1), [math.sin(math.pi * i / n) ** 1.6 for i in range(n)])
    body = mul(lowpass(noise(r, 0.03), 900), env_exp(n_samples(0.03), 0.008, 0.002))
    return finish(lowpass(mix(scale(slide, 0.8), scale(body, 0.25)), 6000), tail_kw=dict(wet=0.05, extra_s=0.03))


def s_reward_reveal(r):
    """Rewards open (#63): a rising three-note glass-and-brass chime over a soft shimmer, about 600 ms."""
    notes = (659.25, 880.0, 1174.66)
    x = mix(*[(0.09 * k, scale(bell(f, 0.5, 0.16), 0.55 - 0.08 * k)) for k, f in enumerate(notes)])
    n = n_samples(0.45)
    shimmer = mul(highpass(noise(r, 0.45), 7000), [math.sin(math.pi * i / n) ** 2 for i in range(n)])
    return finish(mix(x, (0.05, scale(shimmer, 0.05))), tail_kw=dict(wet=0.35, extra_s=0.25))


def s_reward_pick(r):
    """A reward taken (#62): a cut gem set in its socket: a bright two-partial ping on a brass tick."""
    ping = tone(1567.98, 0.4, 0.12, ((1, 1), (2.76, 0.25), (5.4, 0.08)), 0.0008)
    low = tone(783.99, 0.35, 0.14, ((1, 1), (2, 0.3)), 0.002)
    tick = mul(highpass(noise(r, 0.01), 3500), env_exp(n_samples(0.01), 0.0015, 0.0002))
    return finish(mix(scale(tick, 0.5), scale(low, 0.45), (0.012, scale(ping, 0.7))), tail_kw=dict(wet=0.3, extra_s=0.2))


def s_step_done(r):
    """Tutorial step complete: a small bright chime, a rising fourth, quiet and short."""
    a = bell(1046.5, 0.3, 0.08)
    b = bell(1396.91, 0.4, 0.12)
    return finish(mix(scale(a, 0.6), (0.07, scale(b, 0.75))), tail_kw=dict(wet=0.3, extra_s=0.18))


# ---------------------------------------------------------------- K1 (2026-10-23): the Spell / Trap spotlight
# One cue per full-screen card presentation, played the moment the card lands in the centre (its glint and
# sparks). Same build as the set pieces (glass voices, brass voices, a long hall, a clean limiter), but shorter,
# so a chain of spotlights never smears, and a little under the set-piece climaxes in the mix (PEAK).
APENTA = (1760.0, 1975.5, 2217.5, 2637.0, 2960.0, 3520.0)   # A major pentatonic, A6 up


def s_spell_cast(r):
    """K1 Spell cast / activated: an arcane cast. A rising glass 'fwip' releases into a bright A major
    glass-harmonica bloom (A3-E4-A4-C#5-E5) whose voices open one by one, an FM glass tone that climbs an
    octave as the spell takes flight, a spiral of sparkles up the A pentatonic, a warm A2 sub and a breath
    of air; all of it rings out in an airy hall. Soft attack on the landing, no hit, no noise burst."""
    sec = 1.7
    n = n_samples(sec)
    pick = n_samples(0.05)
    # The pickup: a filtered air sweep rising into the landing, then letting go (never a burst).
    fwip = taper(mul(lowpass2(bandpass_sweep(noise(r, 0.2), 900.0, 5200.0, q=2.4), 7000.0),
                     [((i / pick) ** 2 if i < pick else math.exp(-(i - pick) / SR / 0.05)) for i in range(n_samples(0.2))]), 0.06)
    chord = [0.0] * n
    for f, st, at, dec, amp in ((220.0, 0.0, 0.045, 1.1, 0.8), (329.63, 0.015, 0.05, 1.0, 0.7),
                                (440.0, 0.035, 0.035, 0.9, 0.6), (554.37, 0.06, 0.04, 0.8, 0.5),
                                (659.25, 0.09, 0.05, 0.7, 0.42)):
        chord = mix(chord, scale(_glass_voice(r, f, sec, st, at, dec), amp))
    chord = taper(chord, 0.6)
    # The cast: an FM glass tone climbing A4 -> A5 as the spell takes flight, its brightness easing off.
    ph, cast = 0.0, []
    nc = n_samples(0.9)
    for i in range(nc):
        u = i / nc
        f = 440.0 * 2.0 ** min(1.0, u / 0.35)
        ph += TWO_PI * f / SR
        g = (0.5 - 0.5 * math.cos(math.pi * min(1.0, i / n_samples(0.02)))) * math.exp(-i / SR / 0.28)
        cast.append(math.sin(ph + (1.2 * math.exp(-i / SR / 0.15)) * math.sin(ph * 2.0)) * g)
    cast = taper(cast, 0.3)
    # The spiral of sparkles, climbing and thinning.
    parts = []
    for k in range(14):
        off = 0.03 + 0.7 * (k / 13.0) ** 1.3
        f = APENTA[k % len(APENTA)] * (1.0 if k < 7 else 1.0025)
        g = 0.38 * math.exp(-off / 0.5) * r.uniform(0.75, 1.0)
        parts.append((off, scale(taper(tone(f, 0.6, r.uniform(0.08, 0.14), ((1, 1), (2.0, 0.05)), 0.004), 0.2), g)))
    sparkle = mix(*parts)
    ns = n_samples(1.2)
    sub = taper(mul(sweep(118.0, 110.0, 1.2), [(0.5 - 0.5 * math.cos(math.pi * min(1.0, i / n_samples(0.05)))) * math.exp(-i / SR / 0.35)
                                               for i in range(ns)]), 0.4)
    na = n_samples(0.9)
    air = taper(mul(lowpass2(highpass(noise(r, 0.9), 3000.0), 8000.0),
                    [(min(1.0, i / n_samples(0.05)) ** 2) * math.exp(-i / SR / 0.25) for i in range(na)]), 0.3)
    x = mix(scale(fwip, 0.35), scale(chord, 1.0), scale(cast, 0.32), scale(sparkle, 1.0), scale(sub, 0.4), scale(air, 0.07))
    x = hall(x, wet=0.5, predelay_s=0.02, rt60=1.8, damp=6500.0, extra_s=0.3)
    x = smooth_limit(x, 4.0)
    return finish(taper(x, 0.6), rev=False)


def _iron(r, f, sec, dec):
    """An iron jaw ringing: inharmonic partials (a struck bar) through a dark low-pass, 2 ms rounded attack."""
    n = n_samples(sec)
    out = [0.0] * n
    for ratio, amp, d in ((1.0, 1.0, 1.0), (2.76, 0.45, 0.6), (5.4, 0.18, 0.35), (8.93, 0.06, 0.2)):
        w = TWO_PI * f * ratio / SR
        ph = r.uniform(0.0, TWO_PI)
        for i in range(n):
            out[i] += amp * math.sin(w * i + ph) * math.exp(-i / SR / (dec * d))
    a = n_samples(0.002)
    for i in range(min(a, n)):
        out[i] *= 0.5 - 0.5 * math.cos(math.pi * i / a)
    return lowpass2(out, 3200.0)


def s_trap_spring(r):
    """K1 Trap activated: a trap springs. A tight mechanical snap (a wooden latch knock on a low thump,
    rounded, never a noise crack) sets off an iron jaw ringing; the cover is torn away (a falling
    whoosh) and a dark brass stinger rises out of it, an open D fifth with an Eb grinding against the D
    (menace, not fanfare). A darker, shorter hall than the Spell; nothing harsh above 4 kHz."""
    sec = 1.5
    n = n_samples(sec)
    knock = tone(780.0, 0.12, 0.022, ((1, 1), (2.31, 0.35), (3.62, 0.12)), 0.0012)
    click = mul(lowpass2(noise(r, 0.03), 2200.0), env_exp(n_samples(0.03), 0.005, 0.0008))
    thump = mul(sweep(150.0, 52.0, 0.35), [(0.5 - 0.5 * math.cos(math.pi * min(1.0, i / n_samples(0.003)))) * math.exp(-i / SR / 0.09)
                                           for i in range(n_samples(0.35))])
    snap = mix(scale(knock, 0.55), scale(click, 0.5), scale(thump, 1.0))
    jaw = taper(_iron(r, 196.0, 1.1, 0.45), 0.3)
    nw = n_samples(0.42)
    whoosh = taper(mul(lowpass(bandpass_sweep(noise(r, 0.42), 2600.0, 420.0, q=1.6), 3500.0),
                       [(min(1.0, i / n_samples(0.03)) ** 1.5) * math.exp(-i / SR / 0.14) for i in range(nw)]), 0.1)
    # The stinger: low brass, blooming open then closing as it rings.
    lip = lambda t: 1.4 + 3.2 * (min(1.0, t / 0.07) if t < 0.07 else math.exp(-(t - 0.07) / 0.35))
    sting = [0.0] * n
    for f, st, amp, dec, c in ((73.42, 0.02, 0.55, 0.7, -4.0), (110.0, 0.025, 0.6, 0.65, 4.0),
                               (146.83, 0.03, 0.5, 0.6, -3.0), (155.56, 0.06, 0.32, 0.55, 3.0)):
        sting = mix(sting, scale(_brass_voice(f * 1.03, f, 0.05, sec, st, 0.03, dec, lip, c, r.uniform(0, TWO_PI)), amp))
    sting = taper(sting, 0.5)
    x = mix(scale(snap, 1.8), scale(jaw, 0.22), (0.015, scale(whoosh, 0.5)), scale(sting, 0.7))
    x = hall(x, wet=0.4, predelay_s=0.015, rt60=1.5, damp=4000.0, extra_s=0.25)
    x = smooth_limit(x, 5.5)   # level the snap's peak so the stinger carries the loudness
    return finish(taper(x, 0.5), rev=False)


SOUNDS = [
    ("card_draw", s_card_draw), ("card_play", s_card_play), ("card_set", s_card_set),
    ("summon", s_summon), ("select", s_select), ("confirm", s_confirm),
    ("cancel", s_cancel), ("deny", s_deny), ("attack", s_attack),
    ("impact", s_impact), ("damage", s_damage), ("heal", s_heal),
    ("destroy", s_destroy), ("buff", s_buff), ("debuff", s_debuff),
    ("turn", s_turn), ("phase", s_phase), ("notice", s_notice),
    ("victory", s_victory), ("defeat", s_defeat),
    ("exhaust", s_exhaust), ("fuse", s_fuse), ("ritual", s_ritual), ("arcane", s_arcane), ("victory_big", s_victory_big),
    ("boom", s_boom), ("charge", s_charge),
    ("click_primary", s_click_primary), ("click_secondary", s_click_secondary), ("back", s_back),
    ("deck_add", s_deck_add), ("deck_remove", s_deck_remove),
    ("chat", s_chat), ("chat_pop", s_chat_pop),
    ("fusion_vortex", s_fusion_vortex), ("fusion_impact", s_fusion_impact),
    ("ritual_choir", s_ritual_choir), ("ritual_impact", s_ritual_impact),
    ("arcane_shimmer", s_arcane_shimmer), ("arcane_impact", s_arcane_impact),
    ("card_slam", s_card_slam), ("serpent_coil", s_serpent_coil), ("serpent_strike", s_serpent_strike),
    ("sacrifice", s_sacrifice), ("ap_gain", s_ap_gain), ("ap_loss", s_ap_loss),
    ("ui_hover", s_ui_hover), ("panel_open", s_panel_open), ("panel_close", s_panel_close), ("tab", s_tab),
    ("toggle_on", s_toggle_on), ("toggle_off", s_toggle_off), ("hp_low_heartbeat", s_hp_low_heartbeat),
    ("card_hover", s_card_hover), ("reward_reveal", s_reward_reveal), ("reward_pick", s_reward_pick),
    ("step_done", s_step_done),
    ("spell_cast", s_spell_cast), ("trap_spring", s_trap_spring),
]

# Per-sound peak level (dBFS); default PEAK_DBFS. UI clicks sit well under the game sounds.
PEAK = {"chat": -12.0, "chat_pop": -10.0,"click_primary": -11.0, "click_secondary": -12.0, "back": -10.5, "deck_add": -10.0, "deck_remove": -10.5,
        "ap_gain": -10.0, "ap_loss": -11.0, "card_slam": -7.5, "sacrifice": -8.0,
        "ui_hover": -21.0, "panel_open": -13.5, "panel_close": -14.5, "tab": -13.0,
        "toggle_on": -14.0, "toggle_off": -14.5, "hp_low_heartbeat": -7.0,
        "card_hover": -22.0, "reward_reveal": -12.0, "reward_pick": -11.0, "step_done": -13.0,
        # H28: a sustained chord reads quieter than a hit at the same peak; -4.5 dBFS puts its
        # loudest 400 ms near fusion_impact (about -15 vs -14 LUFS) and keeps the summed set piece (shimmer +
        # this + card_slam) at about -1.4 dBFS (the old one: -2).
        "arcane_impact": -4.5,
        # H29: the same rule for the other two set pieces. Each climax sits within 1 LU of arcane_impact and
        # each build-up within 1 LU of arcane_shimmer (loudest 400 ms, K-weighted); the low brass of Fusion
        # needs the most peak for the same loudness.
        "fusion_vortex": -5.0, "fusion_impact": -3.5, "ritual_choir": -4.5, "ritual_impact": -5.0,
        # K1: the spotlight cues. A Spell or Trap shows many times a game, so each cue sits about 2 LU under
        # the set-piece climaxes and about 2 LU over the board sounds (loudest 400 ms, K-weighted).
        "spell_cast": -7.5, "trap_spring": -5.0}


# Hard duration caps (seconds); longer renders are trimmed and re-faded.
MAX_LEN = {"boom": 1.6, "charge": 1.4, "victory_big": 2.6, "exhaust": 1.3, "fuse": 1.3, "ritual": 1.4, "arcane": 1.3, "victory": 1.4, "defeat": 1.4, "turn": 0.9, "heal": 0.9, "summon": 0.8,
           "fusion_vortex": 1.3, "fusion_impact": 2.6, "ritual_choir": 2.0, "ritual_impact": 2.9, "arcane_shimmer": 1.4,
           "arcane_impact": 2.4, "card_slam": 0.6, "serpent_coil": 1.6, "serpent_strike": 1.6, "sacrifice": 1.2,
           "ap_gain": 0.6, "ap_loss": 0.45,
           "ui_hover": 0.12, "panel_open": 0.55, "panel_close": 0.35, "tab": 0.2, "toggle_on": 0.16, "toggle_off": 0.16,
           "hp_low_heartbeat": 0.75, "card_hover": 0.14, "chat_pop": 0.8, "reward_reveal": 0.9, "reward_pick": 0.6, "step_done": 0.6,
           "spell_cast": 2.2, "trap_spring": 2.0}


def write_wav(path, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", max(-32768, min(32767, int(round(v * 32767))))) for v in x))


def analyse(path):
    with wave.open(path, "rb") as w:
        n = w.getnframes()
        raw = w.readframes(n)
        rate, ch, sw = w.getframerate(), w.getnchannels(), w.getsampwidth()
    s = struct.unpack("<%dh" % n, raw)
    pk = max(abs(v) for v in s)
    rms = math.sqrt(sum(v * v for v in s) / n)
    dc = sum(s) / n
    clip = sum(1 for v in s if abs(v) >= 32767)
    db = lambda v: 20 * math.log10(max(v, 1) / 32768.0)
    return dict(rate=rate, ch=ch, bits=sw * 8, dur=n / rate, peak=db(pk), rms=db(rms), dc=dc / 32768.0, clip=clip)


def main():
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "rldb", "assets", "audio", "sfx")
    if "--out" in sys.argv:
        out = sys.argv[sys.argv.index("--out") + 1]
    os.makedirs(out, exist_ok=True)
    print("%-10s %6s %3s %4s %8s %9s %9s %10s %5s" % ("name", "rate", "ch", "bits", "dur(ms)", "peak dB", "rms dB", "dc", "clip"))
    for name, fn in SOUNDS:
        rng = random.Random(0xC0FFEE ^ sum(ord(c) * (i + 1) for i, c in enumerate(name)))
        x = fn(rng)
        cap = n_samples(MAX_LEN.get(name, 0.9))
        if len(x) > cap:
            x = fade(x[:cap], 0.001, 0.08)
        x = normalise(x, PEAK.get(name, PEAK_DBFS))
        path = os.path.join(out, name + ".wav")
        write_wav(path, x)
        a = analyse(path)
        print("%-10s %6d %3d %4d %8.0f %9.2f %9.2f %10.6f %5d" % (
            name, a["rate"], a["ch"], a["bits"], a["dur"] * 1000, a["peak"], a["rms"], a["dc"], a["clip"]))


if __name__ == "__main__":
    main()
