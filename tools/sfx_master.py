#!/usr/bin/env python3
"""L1 (2026-11-05): analyse, choose and master the ElevenLabs sound-effect takes for RLDB.

The cue sheet is design/audio/sfx-cues.json (prompts, tiers, length windows). The takes live in
production/audio-staging/<cue>/<variant><n>.mp3 (gitignored). The committed choice of take per cue is
design/audio/sfx-selection.json; the mastered result is rldb/assets/audio/sfx/<cue>.wav.

Needs numpy + scipy and ffmpeg on PATH. Run through uv so nothing is installed globally:

    uv run --no-project --with numpy --with scipy python -I tools/sfx_master.py analyse   # every take -> staging/*/analysis.json, auto picks
    uv run --no-project --with numpy --with scipy python -I tools/sfx_master.py master    # selection -> rldb/assets/audio/sfx/*.wav
    uv run --no-project --with numpy --with scipy python -I tools/sfx_master.py measure DIR   # loudness table of a folder of wavs
    uv run --no-project --with numpy --with scipy python -I tools/sfx_master.py sheet CUE    # spectrogram contact sheet of every take

To swap a take: edit design/audio/sfx-selection.json (e.g. "attack": "b3.mp3"), run `master`, then
`$G --headless --path rldb --import`.

Loudness is measured as the loudest 100 ms of K-weighted (ITU-R BS.1770) power, in LUFS, with a mono file
counted as played on both speakers. Short UI cues have no 400 ms momentary window, so one metric (M100)
is used for every cue and every tier has a target (TIERS below).
"""
import json
import math
import os
import subprocess
import sys

import numpy as np
from scipy import signal

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
CUES = os.path.join(ROOT, "design", "audio", "sfx-cues.json")
SELECTION = os.path.join(ROOT, "design", "audio", "sfx-selection.json")
STAGING = os.path.join(ROOT, "production", "audio-staging")
OUT = os.path.join(ROOT, "rldb", "assets", "audio", "sfx")
SR = 44100
TP_LIMIT_DB = -1.0       # true-peak ceiling of every mastered cue
MAX_GR_DB = 6.0
LET_GO_S = 0.25          # a build-up rings on this long after its crest ...
LET_GO_TAU = 0.045       # ... falling away with this time constant (the old H29 build-ups: 45 ms)          # most limiting a transient cue may take to reach its loudness target
FRAME = int(0.005 * SR)  # 5 ms analysis frames

# Mastering tiers. m100 = target loudest-100 ms K-weighted loudness (LUFS). The music plays at about
# -15.5 LUFS integrated (loudest 100 ms about -10.3) on a bus at the same default level as SFX, so the set
# pieces land level with the music's peaks (as the procedural set did: about -10.5), combat and
# cards a little under them, the UI well beneath. The targets follow the old set's balance, which the
# owner had tuned (H28 / H29 / K1), with the frequent cues (cards, confirm) a few dB calmer. hpf = high-pass corner (Hz), mono = fold to mono,
# pre = pre-roll kept before the onset (s), fin/fout = fade in / max fade out (s), floor = trim
# threshold for the tail (dB under the peak frame).
TIERS = {
    "hover":        dict(m100=-32.0, lpf=9000, hpf=150, mono=True,  pre=0.0005, fin=0.0005, fout=0.03, floor=-42),
    "ui_soft":      dict(m100=-28.0, hpf=120, mono=True,  pre=0.0005, fin=0.0005, fout=0.03, floor=-45),
    "ui":           dict(m100=-24.0, hpf=90,  mono=True,  pre=0.0005, fin=0.0005, fout=0.05, floor=-48),
    "ui_major":     dict(m100=-18.0, hpf=70,  mono=True,  pre=0.001,  fin=0.001,  fout=0.12, floor=-50),
    "notice_soft":  dict(m100=-19.0, hpf=70,  mono=False, pre=0.001,  fin=0.001,  fout=0.2,  floor=-52),
    "notice":       dict(m100=-14.5, hpf=50,  mono=False, pre=0.002,  fin=0.001,  fout=0.3,  floor=-55),
    "card":         dict(m100=-16.0, hpf=60,  mono=True,  pre=0.001,  fin=0.001,  fout=0.12, floor=-50),
    "tick":         dict(m100=-17.0, hpf=70,  mono=True,  pre=0.001,  fin=0.001,  fout=0.12, floor=-50),
    "tick_soft":    dict(m100=-22.0, hpf=90,  mono=True,  pre=0.0005, fin=0.0005, fout=0.05, floor=-48),
    "heartbeat":    dict(m100=-14.0, hpf=25,  mono=True,  pre=0.002,  fin=0.002,  fout=0.15, floor=-50),
    "combat":       dict(m100=-13.5, hpf=35,  mono=True,  pre=0.001,  fin=0.001,  fout=0.2,  floor=-55),
    "status":       dict(m100=-15.0, hpf=40,  mono=False, pre=0.002,  fin=0.002,  fout=0.3,  floor=-55),
    "status_soft":  dict(m100=-18.0, hpf=50,  mono=False, pre=0.002,  fin=0.002,  fout=0.3,  floor=-55),
    "summon":       dict(m100=-13.5, hpf=30,  mono=False, pre=0.002,  fin=0.002,  fout=0.4,  floor=-58),
    "spotlight":    dict(m100=-12.0, hpf=30,  mono=False, pre=0.002,  fin=0.002,  fout=0.5,  floor=-58),
    "build":        dict(m100=-12.5, hpf=30,  mono=False, pre=0.0,    fin=0.03,   fout=0.07, floor=-58),
    "climax_build": dict(m100=-12.5, hpf=30,  mono=False, pre=0.002,  fin=0.01,   fout=0.4,  floor=-58),
    "climax":       dict(m100=-10.5, hpf=28,  mono=False, pre=0.002,  fin=0.002,  fout=0.8,  floor=-60),
    "big_hit":      dict(m100=-10.0, hpf=25,  mono=False, pre=0.001,  fin=0.001,  fout=0.6,  floor=-60),
    "stinger":      dict(m100=-12.0, hpf=30,  mono=False, pre=0.003,  fin=0.002,  fout=0.6,  floor=-60),
}
# Tiers whose onset must be immediate (the sound answers an action): attack (10% -> 90% of the
# loudest 5 ms frame) and lead-in are scored hard.
SNAPPY = {"hover", "ui_soft", "ui", "ui_major", "card", "tick", "tick_soft", "combat", "big_hit"}
# The longest natural rise (s) each snappy tier may have before a take is marked down; a swing or a
# paper swipe swells a little by nature, a click must not.
ATTACK_OK = {"hover": 0.01, "ui_soft": 0.01, "ui": 0.01, "tick_soft": 0.01, "ui_major": 0.025, "tick": 0.03,
             "card": 0.06, "combat": 0.03, "big_hit": 0.02}
ATTACK_OK_CUE = {"attack": 0.13, "miss": 0.13, "stance_attack": 0.08, "card_shuffle": 0.2, "card_draw": 0.09,
                 "card_return": 0.12, "card_discard": 0.09, "deck_add": 0.05, "deck_remove": 0.05, "panel_open": 0.06,
                 "panel_close": 0.05, "exhaust": 0.4, "sacrifice": 0.2, "sacrifice_mode_on": 0.12, "ap_gain": 0.04,
                 "target_arm": 0.3, "hourglass_flip": 0.06, "draft_reveal": 0.12}
# Per-cue overrides of the tier (the owner asked for Arcane to bloom, not hit: H28).
SWELL = {"arcane_impact": 0.03}   # minimum attack (s) of a cue that must swell in


def load_cues():
    with open(CUES, encoding="utf-8") as f:
        return {c["name"]: c for c in json.load(f)["cues"]}


def decode(path):
    """Decodes any audio file to float stereo at SR (shape (n, 2)). A mono file is copied to both
    channels at full level, as Godot plays it (ffmpeg's own upmix would pan it 3 dB down)."""
    pr = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=channels",
                         "-of", "csv=p=0", path], capture_output=True, text=True, check=True)
    ch = 1 if pr.stdout.strip() == "1" else 2
    r = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", str(ch), "-ar", str(SR), "-"],
                       capture_output=True, check=True)
    x = np.frombuffer(r.stdout, dtype=np.float32).reshape(-1, ch).astype(np.float64)
    return np.repeat(x, 2, axis=1) if ch == 1 else x


def db(v):
    return 20.0 * math.log10(max(float(v), 1e-12))


def _kweight_sos():
    G, Q, fc = 3.99984385397, 0.7071752369554193, 1681.9744509555319
    A = 10 ** (G / 40.0)
    w0 = 2 * math.pi * fc / SR
    al = math.sin(w0) / (2 * Q)
    c = math.cos(w0)
    b = [A * ((A + 1) + (A - 1) * c + 2 * math.sqrt(A) * al), -2 * A * ((A - 1) + (A + 1) * c),
         A * ((A + 1) + (A - 1) * c - 2 * math.sqrt(A) * al)]
    a = [(A + 1) - (A - 1) * c + 2 * math.sqrt(A) * al, 2 * ((A - 1) - (A + 1) * c),
         (A + 1) - (A - 1) * c - 2 * math.sqrt(A) * al]
    s1 = np.array(b + a) / a[0]
    fc2, Q2 = 38.13547087613982, 0.5003270373253953
    w0 = 2 * math.pi * fc2 / SR
    al = math.sin(w0) / (2 * Q2)
    c = math.cos(w0)
    b = [(1 + c) / 2, -(1 + c), (1 + c) / 2]
    a = [1 + al, -2 * c, 1 - al]
    s2 = np.array(b + a) / a[0]
    return np.vstack([s1, s2])


KSOS = _kweight_sos()


def loudness_max(x, win_s):
    """Loudest `win_s` window of K-weighted power (LUFS); a mono (n,) signal counts on both speakers."""
    st = x if x.ndim == 2 else np.stack([x, x], axis=1)
    y = signal.sosfilt(KSOS, st, axis=0)
    p = (y ** 2).sum(axis=1)
    w = max(1, int(win_s * SR))
    if len(p) < w:
        p = np.concatenate([p, np.zeros(w - len(p))])
    c = np.concatenate([[0.0], np.cumsum(p)])
    m = (c[w:] - c[:-w]) / w
    return -0.691 + 10 * math.log10(max(m.max(), 1e-12))


def true_peak_db(x):
    st = x if x.ndim == 2 else x[:, None]
    up = signal.resample_poly(st, 4, 1, axis=0)
    return db(np.abs(up).max())


def envelope(x):
    m = x.mean(axis=1) if x.ndim == 2 else x
    n = len(m) // FRAME
    if n == 0:
        return np.array([np.sqrt(np.mean(m ** 2))])
    return np.sqrt((m[:n * FRAME].reshape(n, FRAME) ** 2).mean(axis=1) + 1e-20)


def _flat_runs(x):
    """Samples in runs of 4+ near-equal values at the take's own ceiling (hard-clipped tops)."""
    m = np.abs(x).max(axis=1)
    top = m.max()
    if top < 0.5:
        return 0
    hot = np.concatenate([[0], (m >= top * 0.995).astype(np.int8), [0]])
    d = np.diff(hot)
    starts, ends = np.where(d == 1)[0], np.where(d == -1)[0]
    runs = ends - starts
    return int(runs[runs >= 4].sum())


def analyse_signal(x, tier):
    """Objective measures of one take (see score())."""
    mono = x.mean(axis=1)
    env = envelope(x)
    e_db = 20 * np.log10(env)
    pk_frame = e_db.max()
    act = np.where(e_db > pk_frame - 40)[0]
    start_f = int(act[0]) if len(act) else 0
    floor = TIERS[tier]["floor"]
    tail = np.where(e_db > pk_frame + floor)[0]
    end_f = int(tail[-1]) + 1 if len(tail) else len(env)
    peak_i = int(np.argmax(env))
    # attack: first frame at 10% -> first at 90% of the loudest frame
    lin = env / env.max()
    i10 = int(np.argmax(lin >= 0.1))
    i90 = int(np.argmax(lin >= 0.9))
    # hits: frames whose level jumps by more than 12 dB over the frame 20 ms earlier, after the onset
    jumps = 0
    last = -100
    for i in range(start_f + 4, end_f):
        if e_db[i] - e_db[i - 4] > 12 and e_db[i] > pk_frame - 20 and i - last > 10:
            jumps += 1
            last = i
    seg = mono[start_f * FRAME:end_f * FRAME]
    if len(seg) < 256:
        seg = mono
    f, P = signal.welch(seg, SR, nperseg=min(2048, len(seg)))
    P = P + 1e-30
    cen = float((f * P).sum() / P.sum())
    hf = float(P[f >= 6000].sum() / P.sum())
    lf = float(P[f < 150].sum() / P.sum())
    flat = float(np.exp(np.mean(np.log(P))) / np.mean(P))
    s = (x[:, 0] - x[:, 1]) / 2
    width = db(np.sqrt(np.mean(s ** 2)) + 1e-12) - db(np.sqrt(np.mean(mono ** 2)) + 1e-12)
    nf = float(np.percentile(e_db[start_f:end_f], 5)) - pk_frame if end_f > start_f + 4 else -60.0
    dc = float(abs(mono.mean()))
    return dict(dur=len(x) / SR, lead=start_f * FRAME / SR, end=end_f * FRAME / SR, eff=(end_f - start_f) * FRAME / SR,
                crest=(peak_i - start_f) * FRAME / SR, attack=max(0, i90 - i10) * FRAME / SR,
                onset10=max(0, i10 - start_f) * FRAME / SR,
                peak=db(np.abs(x).max()), clip=_flat_runs(x),
                m100=loudness_max(x, 0.1), m400=loudness_max(x, 0.4), centroid=cen, hf=hf, lf=lf, flat=flat,
                width=width, hits=jumps, floor_rel=nf, dc=dc)


def score(a, cue):
    """Lower is better. Fit to the cue's length window, onset, single-event shape, cleanliness."""
    tier = cue["tier"]
    lo, hi = cue["len"]
    s = 0.0
    why = []
    eff = a["eff"]
    if eff < lo:
        s += (lo - eff) / lo * 4
        why.append("short")
    elif eff > hi:
        # long takes are trimmed with a fade; only a little worse unless far too long
        s += min(3.0, (eff - hi) / hi * 1.5)
        why.append("long")
    if tier in SNAPPY:
        ok = ATTACK_OK_CUE.get(cue["name"], ATTACK_OK[tier])
        if a["attack"] > ok:
            s += min(3.0, (a["attack"] - ok) / ok)
            why.append("slow attack")
        if a["hits"] > (1 if tier in ("ui", "hover", "ui_soft", "tick_soft") else 2):
            s += 1.5 * (a["hits"] - 1)
            why.append("multi-hit")
    if cue["name"] in SWELL and a["attack"] < SWELL[cue["name"]]:
        s += 3.0
        why.append("hard attack")
    if tier == "build":
        rel = a["crest"] / max(a["eff"], 1e-3)
        s += max(0.0, 0.75 - rel) * 6              # a riser must crest late
        if a["crest"] < 0.5:
            s += 2.0
            why.append("crest early")
    if tier in ("climax", "big_hit", "summon", "spotlight") and a["crest"] > 0.6:
        s += min(3.0, (a["crest"] - 0.6) * 3)         # the climax must land on the flash
        why.append("late crest")
    if a["clip"] > 0:
        s += min(1.5, a["clip"] / 40)                # flat-topped runs in the source (overs are recoverable)
        why.append("clips")
    if a["floor_rel"] > -25 and tier in SNAPPY:
        s += (a["floor_rel"] + 25) / 10
        why.append("noisy floor")
    if tier in ("hover", "ui", "ui_soft", "tick_soft") and a["hf"] > 0.25:
        s += (a["hf"] - 0.25) * 8                     # harsh top end fatigues on repeat
        why.append("bright")
    if tier == "hover" and a["centroid"] > 5000:
        s += (a["centroid"] - 5000) / 2000
    if a["lead"] > 0.25 and tier in SNAPPY:
        s += 0.5                                      # trimmed anyway, but a sign of a vague take
    return round(s, 3), why


def take_files(name):
    d = os.path.join(STAGING, name)
    if not os.path.isdir(d):
        return []
    return sorted(f for f in os.listdir(d) if f.endswith(".mp3"))


def cmd_analyse(only=None):
    cues = load_cues()
    auto = {}
    for name, cue in cues.items():
        if only and name not in only:
            continue
        files = take_files(name)
        if not files:
            print("%-20s NO TAKES" % name)
            continue
        rows = {}
        for fn in files:
            x = decode(os.path.join(STAGING, name, fn))
            a = analyse_signal(x, cue["tier"])
            a["score"], a["why"] = score(a, cue)
            rows[fn] = a
        with open(os.path.join(STAGING, name, "analysis.json"), "w", encoding="utf-8") as f:
            json.dump(rows, f, indent=1)
        best = min(rows, key=lambda k: rows[k]["score"])
        auto[name] = best
        b = rows[best]
        print("%-20s %-7s %2d takes  best %-7s score %5.2f eff %.2fs att %3.0fms crest %.2fs hits %d cen %4.0f hf %.2f %s" % (
            name, cue["tier"], len(files), best, b["score"], b["eff"], b["attack"] * 1000, b["crest"], b["hits"],
            b["centroid"], b["hf"], ",".join(b["why"])))
    path = os.path.join(STAGING, "auto-selection.json")
    old = {}
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            old = json.load(f)
    old.update(auto)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(old, f, indent=1, sort_keys=True)


def _fade(n, kind="in"):
    t = np.linspace(0, 1, max(n, 1))
    w = 0.5 - 0.5 * np.cos(np.pi * t)
    return w if kind == "in" else w[::-1]


def limit(x, ceiling_db, look_s=0.003, release_s=0.08):
    """Smooth look-ahead peak limiter: gain never lets |x| exceed the ceiling (sample peak)."""
    thr = 10 ** (ceiling_db / 20)
    a = np.abs(x).max(axis=1) if x.ndim == 2 else np.abs(x)
    need = np.minimum(1.0, thr / np.maximum(a, 1e-12))
    la = max(1, int(look_s * SR))
    # look-ahead minimum over the window
    padded = np.concatenate([need, np.ones(la)])
    g = np.minimum.reduce([padded[i:i + len(need)] for i in range(0, la + 1, max(1, la // 8))])
    # release smoothing (attack instant thanks to the look-ahead minimum)
    rc = math.exp(-1.0 / (release_s * SR))
    out = np.empty_like(g)
    cur = 1.0
    for i, v in enumerate(g):
        cur = v if v < cur else v + (cur - v) * rc
        out[i] = cur
    # short smoothing of the gain to avoid zipper noise
    k = max(1, int(0.001 * SR))
    out = np.convolve(out, np.ones(k) / k, mode="same")
    out = np.minimum(out, g)
    return x * (out[:, None] if x.ndim == 2 else out)


def _region(path, frm=None, to=None):
    """Seconds `frm`..`to` of a take; a cut edge gets a short raised-cosine fade (3 ms in, 30 ms out)."""
    x = decode(path)
    a = int(float(frm or 0.0) * SR)
    b = int(float(to) * SR) if to is not None else len(x)
    x = x[a:b].copy()
    if frm:
        k = min(len(x), int(0.003 * SR))
        x[:k] *= _fade(k, "in")[:, None]
    if to is not None:
        k = min(len(x), int(0.03 * SR))
        x[len(x) - k:] *= _fade(k, "out")[:, None]
    return x


def master_one(src, cue, pick=None):
    """Returns (signal, report). `signal` is (n,) mono or (n, 2) stereo float at SR. `pick` is the
    selection entry:
    - "from" / "to" (s) cut a region of the take before anything else (one grain of a take with several);
    - "layers": [{"take", "from", "to", "at", "db"}] mixes other regions (of this or another take of the
      cue) in at `at` seconds, `db` relative (a set piece built from a hit and a bloom);
    - "db" nudges the tier target; "hpf" / "lpf" override the filters."""
    pick = pick or {}
    t = TIERS[cue["tier"]]
    x = _region(src, pick.get("from"), pick.get("to"))
    for lay in pick.get("layers", []):
        lx = _region(os.path.join(os.path.dirname(src), lay["take"]), lay.get("from"), lay.get("to"))
        lx = lx * 10 ** (float(lay.get("db", 0.0)) / 20)
        at = int(float(lay.get("at", 0.0)) * SR)
        if at + len(lx) > len(x):
            x = np.concatenate([x, np.zeros((at + len(lx) - len(x), 2))])
        x[at:at + len(lx)] += lx
    # DC and rumble: a 4th-order high-pass (also removes the mp3 DC offset); an optional low-pass
    # softens the top of the cues heard most often (hovers).
    sos = signal.butter(4, float(pick.get("hpf", cue.get("hpf", t["hpf"]))), "highpass", fs=SR, output="sos")
    x = signal.sosfiltfilt(sos, x, axis=0)
    lpf = pick.get("lpf", cue.get("lpf", t.get("lpf")))
    if lpf:
        x = signal.sosfiltfilt(signal.butter(2, float(lpf), "lowpass", fs=SR, output="sos"), x, axis=0)
    if t["mono"]:
        x = x.mean(axis=1)
    env = envelope(x if x.ndim == 2 else np.stack([x, x], 1))
    e_db = 20 * np.log10(env)
    pk = e_db.max()
    act = np.where(e_db > pk - 40)[0]
    start_f = int(act[0]) if len(act) else 0
    # sample-accurate onset inside the first active frame: first sample above -40 dB of the peak sample
    mono = x if x.ndim == 1 else x.mean(axis=1)
    thr = np.abs(mono).max() * 10 ** (-40 / 20)
    seg0 = max(0, (start_f - 1) * FRAME)
    above = np.where(np.abs(mono[seg0:]) > thr)[0]
    onset = seg0 + (int(above[0]) if len(above) else 0)
    tail = np.where(e_db > pk + t["floor"])[0]
    end = (int(tail[-1]) + 1) * FRAME if len(tail) else len(mono)
    lo, hi = cue["len"]
    start = max(0, onset - int(t["pre"] * SR))
    align = cue.get("align")
    ramp = None
    if align is not None:
        # Riser (H29): crest exactly at `align` s, then let go in 70 ms so the climax lands out of a breath.
        # The take's own crest is moved to `align` when it comes later; a rising gain (from -18 dB, a
        # power curve) shapes whatever the take does into a swell that peaks at `align`.
        e50 = np.convolve(env, np.ones(10) / 10, mode="same")
        crest = (int(np.argmax(e50[start // FRAME:])) + start // FRAME) * FRAME
        start = max(start, crest - int(align * SR))
        end = min(len(mono), start + int((align + LET_GO_S) * SR))
        tt = np.arange(end - start) / SR
        ramp = np.where(tt < align, 0.125 + 0.875 * np.clip(tt / align, 0, 1) ** float(pick.get("curve", 1.6)),
                        np.exp(-(tt - align) / LET_GO_TAU))
    end = max(end, start + int(lo * SR * 0.5))
    capped = end > start + int(hi * SR)
    end = min(end, start + int(hi * SR), len(mono))
    y = x[start:end].copy()
    pad = 0
    if ramp is not None:
        ramp = ramp[:len(y)]
        y = y * (ramp[:, None] if y.ndim == 2 else ramp)
    n = len(y)
    fin = max(1, int(t["fin"] * SR))
    fout = max(1, min(int(t["fout"] * SR), n // 3))
    if capped:
        fout = max(fout, min(int(0.3 * n), n // 2))   # cut while still sounding: a longer fade
    w = np.ones(n)
    w[:fin] *= _fade(fin, "in")
    w[n - fout:] *= _fade(fout, "out")
    y = y * (w[:, None] if y.ndim == 2 else w)
    # loudness to the tier target, then the true-peak ceiling
    target = float(cue.get("m100", t["m100"])) + float(pick.get("db", 0.0))
    # A transient-heavy cue (a card snap, a slam) can only reach its target through the limiter; it may
    # take up to MAX_GR_DB of gain reduction, then it stays a little under the target instead.
    raw = y
    gain_db = target - loudness_max(raw, 0.1)
    for _ in range(8):
        y = raw * 10 ** (gain_db / 20)
        if true_peak_db(y) > TP_LIMIT_DB - 0.05:
            y = limit(y, TP_LIMIT_DB - 0.4)
            if true_peak_db(y) > TP_LIMIT_DB - 0.05:
                y = y * 10 ** ((TP_LIMIT_DB - 0.1 - true_peak_db(y)) / 20)
        short = target - loudness_max(y, 0.1)
        gr = gain_db - (target - loudness_max(raw, 0.1)) + max(0.0, short)
        if short <= 0.25 or gr >= MAX_GR_DB:
            break
        gain_db += short
    rep = dict(src=os.path.relpath(src, ROOT).replace("\\", "/"), len=round(n / SR, 3), ch=1 if y.ndim == 1 else 2,
               m100=round(loudness_max(y, 0.1), 2), m400=round(loudness_max(y, 0.4), 2), tp=round(true_peak_db(y), 2),
               onset_ms=round((onset - start + pad) / SR * 1000 if align is None else -1, 1))
    return y, rep


def write_wav16(path, y):
    import wave
    rng = np.random.default_rng(1)
    tpdf = (rng.random(y.shape) - rng.random(y.shape)) / 32768.0
    q = np.clip(np.round((y + tpdf) * 32767), -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1 if y.ndim == 1 else 2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(q.tobytes())


def cmd_master(only=None):
    cues = load_cues()
    with open(SELECTION, encoding="utf-8") as f:
        sel = json.load(f)
    reports = {}
    for name, cue in cues.items():
        if only and name not in only:
            continue
        pick = sel.get(name)
        if not pick:
            print("%-20s no selection" % name)
            continue
        fn = pick["take"] if isinstance(pick, dict) else pick
        src = os.path.join(STAGING, name, fn)
        y, rep = master_one(src, cue, pick if isinstance(pick, dict) else None)
        write_wav16(os.path.join(OUT, name + ".wav"), y)
        reports[name] = rep
        with open(os.path.join(STAGING, name, "master.json"), "w", encoding="utf-8") as f:
            json.dump(rep, f, indent=1)
        print("%-20s %-12s %-7s len %.2fs ch%d M100 %6.1f M400 %6.1f TP %5.1f onset %s ms" % (
            name, cue["tier"], fn, rep["len"], rep["ch"], rep["m100"], rep["m400"], rep["tp"], rep["onset_ms"]))
    path = os.path.join(STAGING, "master-report.json")
    old = {}
    if os.path.exists(path) and only:
        with open(path, encoding="utf-8") as f:
            old = json.load(f)
    old.update(reports)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(old, f, indent=1, sort_keys=True)


def cmd_measure(folder):
    for fn in sorted(os.listdir(folder)):
        if fn.endswith((".wav", ".ogg", ".mp3")):
            x = decode(os.path.join(folder, fn))
            print("%-24s %5.2fs M100 %6.1f M400 %6.1f TP %5.1f" % (fn, len(x) / SR, loudness_max(x, 0.1),
                                                                   loudness_max(x, 0.4), true_peak_db(x)))


def cmd_sheet(name):
    files = take_files(name)
    out = os.path.join(STAGING, name, "sheet.png")
    inputs = []
    for fn in files:
        inputs += ["-i", os.path.join(STAGING, name, fn)]
    parts = []
    for i in range(len(files)):
        # top: the waveform (level over time); bottom: a log-frequency spectrogram (20 Hz - 16 kHz)
        parts.append("[%d:a]aformat=channel_layouts=mono,asplit[w%d][p%d];[w%d]showwavespic=s=360x50:colors=white:scale=sqrt[ww%d];"
                     "[p%d]showspectrumpic=s=360x110:legend=0:scale=cbrt:fscale=log:start=20:stop=16000:color=fiery[sp%d];"
                     "[ww%d][sp%d]vstack[s%d]" % (i, i, i, i, i, i, i, i, i, i))
    cols = 4
    rows = math.ceil(len(files) / cols)
    layout = "|".join("%d_%d" % ((i % cols) * 364, (i // cols) * 164) for i in range(len(files)))
    parts.append("".join("[s%d]" % i for i in range(len(files))) + "xstack=inputs=%d:layout=%s:fill=black[o]" % (len(files), layout))
    subprocess.run(["ffmpeg", "-v", "error", "-y"] + inputs + ["-filter_complex", ";".join(parts), "-map", "[o]",
                    "-frames:v", "1", out], check=True)
    print(out, "rows", rows, "order", files)


def cmd_board(out, names):
    """One review image for several cues: a row per cue, a tile per take (waveform over a log-frequency
    spectrogram, all on one time scale per cue), labelled with the take, its trimmed length and score.
    Needs pillow (uv --with pillow)."""
    from PIL import Image, ImageDraw
    cues = load_cues()
    tw, th, lab = 180, 104, 14
    rows = []
    for name in names:
        files = take_files(name)
        an = {}
        ap = os.path.join(STAGING, name, "analysis.json")
        if os.path.exists(ap):
            with open(ap, encoding="utf-8") as f:
                an = json.load(f)
        xs = [decode(os.path.join(STAGING, name, fn)).mean(axis=1) for fn in files]
        span = max(len(x) for x in xs) / SR if xs else 1.0
        row = Image.new("RGB", (tw * 8, th + lab * 2), (12, 12, 16))
        d = ImageDraw.Draw(row)
        c = cues[name]
        d.text((4, 1), "%s  [%s]  target %.2f-%.2fs  span %.2fs" % (name, c["tier"], c["len"][0], c["len"][1], span), fill=(255, 220, 120))
        for i, (fn, x) in enumerate(zip(files, xs)):
            x0 = (i % 8) * tw
            ncol = tw - 4
            f, t, S = signal.spectrogram(x, SR, nperseg=512, noverlap=384)
            S = 10 * np.log10(S + 1e-12)
            S = np.clip((S - (S.max() - 70)) / 70, 0, 1)
            # log-frequency rows (40 Hz - 16 kHz) and time columns on the cue's shared span
            fr = np.geomspace(40, 16000, 64)
            fi = np.clip(np.searchsorted(f, fr), 0, len(f) - 1)
            cols = np.clip((np.arange(ncol) / ncol * span * SR / 128).astype(int), 0, S.shape[1] - 1)
            valid = np.arange(ncol) / ncol * span < len(x) / SR
            img = S[fi][:, cols] * valid[None, :]
            img = (np.flipud(img) * 255).astype(np.uint8)
            spec = Image.fromarray(img).resize((ncol, 64))
            row.paste(Image.merge("RGB", (spec, spec.point(lambda v: v * 0.7), spec.point(lambda v: v * 0.3))), (x0 + 2, lab + 36))
            env = envelope(np.stack([x, x], 1))
            edb = np.clip((20 * np.log10(env) + 60) / 60, 0, 1)
            for k in range(ncol):
                j = int(k / ncol * span / (FRAME / SR))
                if j < len(edb):
                    h = int(edb[j] * 34)
                    d.line([(x0 + 2 + k, lab + 35), (x0 + 2 + k, lab + 35 - h)], fill=(200, 200, 210))
            a = an.get(fn, {})
            d.text((x0 + 4, th + lab), "%s %.2fs s%.1f" % (fn[:-4], a.get("eff", 0), a.get("score", 0)), fill=(170, 210, 255))
        rows.append(row)
    sheet = Image.new("RGB", (tw * 8, sum(r.height for r in rows)), (0, 0, 0))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y))
        y += r.height
    sheet.save(out)
    print(out)


TIER_TITLES = [
    ("UI: clicks, hovers, toggles and panels", ("hover", "ui_soft", "ui", "ui_major")),
    ("Notices and flow", ("notice_soft", "notice", "tick_soft")),
    ("Card movement", ("card",)),
    ("Combat", ("combat", "big_hit", "heartbeat")),
    ("Statuses and effects", ("status", "status_soft", "tick")),
    ("Set pieces", ("summon", "build", "climax", "climax_build", "spotlight")),
    ("Stingers", ("stinger",)),
]


def cmd_doc(out_md):
    """Writes the readable design table (cue, context, length, character, prompt, chosen take and why)
    and production/audio-staging/index.md (every take, the chosen one marked)."""
    cues = load_cues()
    with open(SELECTION, encoding="utf-8") as f:
        sel = json.load(f)
    rep = {}
    for n in cues:
        rp = os.path.join(STAGING, n, "master.json")
        if os.path.exists(rp):
            with open(rp, encoding="utf-8") as f:
                rep[n] = json.load(f)
    lines = []
    for title, tiers in TIER_TITLES:
        names = [n for n, c in cues.items() if c["tier"] in tiers]
        if not names:
            continue
        lines += ["", "### " + title, "",
                  "| Cue | Context | Target | Final | Character (prompt) | Take | Why this take |",
                  "|---|---|---|---|---|---|---|"]
        for n in names:
            c = cues[n]
            s = sel.get(n, {})
            take = s.get("take", "") if isinstance(s, dict) else s
            why = s.get("why", "") if isinstance(s, dict) else ""
            r = rep.get(n, {})
            v = take[:1] if take else ""
            idx = ord(v) - ord("a") if v else 0
            prompt = c["p"][idx] if 0 <= idx < len(c["p"]) else c["p"][0]
            final = "%.2f s, %s, %.1f LUFS" % (r["len"], "stereo" if r.get("ch") == 2 else "mono", r["m100"]) if r else ""
            lines.append("| `%s` | %s | %.2f-%.2f s | %s | %s | %s | %s |" % (
                n, c["ctx"], c["len"][0], c["len"][1], final, prompt.replace("|", "/"), take, why.replace("|", "/")))
    with open(out_md, encoding="utf-8") as f:
        head = f.read().split("<!-- TABLE -->")[0]
    with open(out_md, "w", encoding="utf-8", newline="\n") as f:
        f.write(head + "<!-- TABLE -->\n" + "\n".join(lines).lstrip("\n") + "\n")
    idx = ["# SFX staging index (L1, 2026-11-05)", "",
           "Every ElevenLabs take, per cue. **Bold** is the take in the game. To swap: edit "
           "`design/audio/sfx-selection.json`, then `tools/sfx_master.py master <cue>` and a Godot import.", ""]
    for n, c in cues.items():
        take = sel.get(n, {})
        take = take.get("take", "") if isinstance(take, dict) else take
        an = {}
        ap = os.path.join(STAGING, n, "analysis.json")
        if os.path.exists(ap):
            with open(ap, encoding="utf-8") as f:
                an = json.load(f)
        parts = []
        for fn in take_files(n):
            a = an.get(fn, {})
            t = "%s (%.2fs, score %.1f)" % (fn, a.get("eff", 0), a.get("score", 0))
            parts.append("**%s**" % t if fn == take else t)
        idx.append("- `%s`: %s" % (n, ", ".join(parts)))
        for i, p in enumerate(c["p"]):
            idx.append("  - %s: %s" % (chr(97 + i), p))
    with open(os.path.join(STAGING, "index.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(idx) + "\n")
    print(out_md)


if __name__ == "__main__":
    c = sys.argv[1] if len(sys.argv) > 1 else "analyse"
    rest = sys.argv[2:]
    if c == "analyse":
        cmd_analyse(set(rest) if rest else None)
    elif c == "master":
        cmd_master(set(rest) if rest else None)
    elif c == "measure":
        cmd_measure(rest[0])
    elif c == "sheet":
        cmd_sheet(rest[0])
    elif c == "board":
        cmd_board(rest[0], rest[1:])
    elif c == "doc":
        cmd_doc(os.path.join(ROOT, "design", "audio", "sfx-design-2026-11-05.md"))
    elif c == "boards":   # every cue, in cue-sheet order, N per image, into production/audio-staging/_boards/
        per = int(rest[0]) if rest else 5
        names = list(load_cues())
        os.makedirs(os.path.join(STAGING, "_boards"), exist_ok=True)
        for i in range(0, len(names), per):
            cmd_board(os.path.join(STAGING, "_boards", "board_%02d.png" % (i // per + 1)), names[i:i + per])
    else:
        print(__doc__)
