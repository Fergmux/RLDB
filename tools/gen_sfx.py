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


def s_ritual_choir(r):
    """D8 Ritual anticipation: a dark choir pad (A minor, formant 'aah' voices) swelling into the climax,
    over a low drone; the reverb is long, like a temple."""
    sec = 1.15
    ch = _choir(r, (110.0, 130.81, 164.81, 220.0), sec, 0.86, 0.3)
    drone = mul(tone(55.0, sec, 3.0, ((1, 1), (2, 0.35), (3, 0.12)), 0.4), swell(n_samples(sec), n_samples(0.86), 1.2, 0.3))
    return finish(mix(scale(ch, 1.0), scale(drone, 0.45)), tail_kw=dict(wet=0.55, extra_s=0.45, delay_s=0.071, fb=0.42))


def s_ritual_impact(r):
    """D8 Ritual climax: a deep temple gong and a choir chord stab under the pillar of light, with a sub drop."""
    gong = [0.0] * n_samples(1.4)
    for ratio, amp, dec in ((1.0, 1.0, 0.9), (1.48, 0.6, 0.6), (2.0, 0.45, 0.5), (2.76, 0.35, 0.35), (3.6, 0.22, 0.25), (4.4, 0.15, 0.18)):
        part = mul(sweep(82.0 * ratio, 80.0 * ratio, 1.4), env_exp(n_samples(1.4), dec, 0.002))
        gong = mix(gong, scale(part, amp))
    stab = _choir(r, (220.0, 261.63, 329.63, 440.0), 0.9, 0.04, 0.35)
    sub = mul(sweep(120.0, 32.0, 0.8), env_exp(n_samples(0.8), 0.25, 0.002))
    crash = mul(lowpass(noise(r, 0.5), 2600), env_exp(n_samples(0.5), 0.09, 0.001))
    x = softclip(mix(scale(gong, 0.75), scale(stab, 0.6), scale(sub, 1.0), scale(crash, 0.4)), 1.8)
    return finish(x, tail_kw=dict(wet=0.5, extra_s=0.45, delay_s=0.068, fb=0.4))


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


def s_arcane_impact(r):
    """D8 Arcane climax: the lattice shatters: glass bursts, a bright bell chord and a sub thump."""
    parts = []
    for i in range(34):
        off = (i / 34.0) ** 1.6 * 0.28
        dur = r.uniform(0.008, 0.03)
        b = mul(highpass(noise(r, dur), r.uniform(2500, 6000)), env_exp(n_samples(dur), dur * 0.3, 0.0003))
        parts.append((off, scale(b, math.exp(-off / 0.12))))
    shards = mix(*parts)
    chord = mix(*[(0.005 * k, scale(bell(f, 1.2, 0.35), 0.5)) for k, f in enumerate((659.25, 830.61, 987.77, 1318.5))])
    sub = mul(sweep(95.0, 38.0, 0.6), env_exp(n_samples(0.6), 0.16, 0.002))
    return finish(softclip(mix(scale(shards, 0.7), scale(chord, 1.2), scale(sub, 1.1)), 2.4), tail_kw=dict(wet=0.45, extra_s=0.4, delay_s=0.05))


def s_fusion_vortex(r):
    """D8 Fusion anticipation: a vortex whoosh that spins faster (rising tremolo) and climbs in pitch."""
    sec = 0.85
    n = n_samples(sec)
    wind = bandpass_sweep(noise(r, sec), 250.0, 3200.0, q=2.2)
    ph = 0.0
    rot = []
    for i in range(n):
        u = i / n
        ph += TWO_PI * (4.0 + 20.0 * u * u) / SR
        rot.append(0.55 + 0.45 * math.sin(ph))
    env = [(i / n) ** 1.6 for i in range(n)]
    tones = mix(sweep(80.0, 320.0, sec), scale(sweep(120.0, 480.0, sec), 0.6))
    x = softclip(mix(scale(mul(mul(wind, rot), env), 1.6), scale(mul(tones, env), 0.5)), 2.2)
    return finish(x, tail_kw=dict(wet=0.3, extra_s=0.1, delay_s=0.04))


def s_fusion_impact(r):
    """D8 Fusion climax: the core implodes (a quick suck) and explodes: sub, crack, a shimmering metal cluster."""
    suck = mul(sweep(1400.0, 180.0, 0.07), [(i / n_samples(0.07)) ** 2 for i in range(n_samples(0.07))])
    sub = mul(sweep(115.0, 30.0, 0.9), env_exp(n_samples(0.9), 0.3, 0.002))
    crack = mul(lowpass(noise(r, 0.2), 4200), env_exp(n_samples(0.2), 0.035, 0.0005))
    metal = mix(scale(bell(880.0, 1.1, 0.32), 0.6), scale(bell(1331.0, 1.1, 0.26), 0.45), scale(bell(1769.0, 1.0, 0.2), 0.35))
    rumble = mul(lowpass2(noise(r, 1.0), 300), env_exp(n_samples(1.0), 0.32, 0.01))
    hit = softclip(mix(scale(sub, 1.1), scale(crack, 0.8), scale(metal, 0.7), scale(rumble, 1.1)), 2.2)
    return finish(mix(scale(suck, 0.5), (0.07, hit)), tail_kw=dict(wet=0.42, extra_s=0.35, delay_s=0.055))


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
    ("chat", s_chat),
    ("fusion_vortex", s_fusion_vortex), ("fusion_impact", s_fusion_impact),
    ("ritual_choir", s_ritual_choir), ("ritual_impact", s_ritual_impact),
    ("arcane_shimmer", s_arcane_shimmer), ("arcane_impact", s_arcane_impact),
    ("card_slam", s_card_slam), ("serpent_coil", s_serpent_coil), ("serpent_strike", s_serpent_strike),
    ("sacrifice", s_sacrifice), ("ap_gain", s_ap_gain), ("ap_loss", s_ap_loss),
    ("ui_hover", s_ui_hover), ("panel_open", s_panel_open), ("panel_close", s_panel_close), ("tab", s_tab),
    ("toggle_on", s_toggle_on), ("toggle_off", s_toggle_off), ("hp_low_heartbeat", s_hp_low_heartbeat),
]

# Per-sound peak level (dBFS); default PEAK_DBFS. UI clicks sit well under the game sounds.
PEAK = {"chat": -12.0, "click_primary": -11.0, "click_secondary": -12.0, "back": -10.5, "deck_add": -10.0, "deck_remove": -10.5,
        "ap_gain": -10.0, "ap_loss": -11.0, "card_slam": -7.5, "sacrifice": -8.0,
        "ui_hover": -21.0, "panel_open": -13.5, "panel_close": -14.5, "tab": -13.0,
        "toggle_on": -14.0, "toggle_off": -14.5, "hp_low_heartbeat": -7.0}


# Hard duration caps (seconds); longer renders are trimmed and re-faded.
MAX_LEN = {"boom": 1.6, "charge": 1.4, "victory_big": 2.6, "exhaust": 1.3, "fuse": 1.3, "ritual": 1.4, "arcane": 1.3, "victory": 1.4, "defeat": 1.4, "turn": 0.9, "heal": 0.9, "summon": 0.8,
           "fusion_vortex": 1.0, "fusion_impact": 1.8, "ritual_choir": 1.7, "ritual_impact": 2.0, "arcane_shimmer": 1.4,
           "arcane_impact": 1.8, "card_slam": 0.6, "serpent_coil": 1.6, "serpent_strike": 1.6, "sacrifice": 1.2,
           "ap_gain": 0.6, "ap_loss": 0.45,
           "ui_hover": 0.12, "panel_open": 0.55, "panel_close": 0.35, "tab": 0.2, "toggle_on": 0.16, "toggle_off": 0.16,
           "hp_low_heartbeat": 0.75}


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
