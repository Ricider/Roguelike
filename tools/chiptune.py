#!/usr/bin/env python3
"""8-bit chiptune generator: sound effects + looping music for the game.

Pure stdlib. Emulates an NES-style sound chip: two pulse channels (duty
12.5/25/50%), a stepped 4-bit triangle for bass, and an LFSR noise channel
for drums and explosions. Writes 16-bit mono WAVs (22.05 kHz) to
Assets/Audio/. Music files carry a RIFF 'smpl' loop chunk so Godot's WAV
importer loops them seamlessly.

    python3 tools/chiptune.py            # sound effects (the default)
    python3 tools/chiptune.py chipmusic  # the old 8-bit music (the game now uses tools/soundtrack.py)
"""
import math
import os
import random
import struct
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 22050
OUT_SFX = os.path.join(ROOT, "Assets", "Audio", "sfx")
OUT_MUSIC = os.path.join(ROOT, "Assets", "Audio", "music")

NOTE_INDEX = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6,
              "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def midi(name):
    """'A4' -> 69, 'C#5' -> 73."""
    pitch, octave = name[:-1], int(name[-1])
    return 12 * (octave + 1) + NOTE_INDEX[pitch]


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


# ----------------------------------------------------------------- output
def write_wav(path, samples, loop=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    gain = min(1.0, 0.92 / peak)
    pcm = struct.pack("<%dh" % len(samples), *(int(max(-1.0, min(1.0, s * gain)) * 32767) for s in samples))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm)
    if loop:
        # Append a 'smpl' chunk with one forward loop over the whole file.
        smpl = struct.pack("<9I", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, len(samples) - 1, 0, 0)
        with open(path, "r+b") as f:
            f.seek(0, 2)
            f.write(b"smpl" + struct.pack("<I", len(smpl)) + smpl)
            size = f.tell() - 8
            f.seek(4)
            f.write(struct.pack("<I", size))


# ------------------------------------------------------------- oscillators
def pulse(phase, duty):
    return 1.0 if (phase % 1.0) < duty else -1.0


def tri4(phase):
    """NES triangle: 16-step quantised triangle."""
    p = phase % 1.0
    v = 1.0 - 4.0 * abs(p - 0.5)  # -1..1
    return round((v + 1) * 7.5) / 7.5 - 1.0


class Noise:
    """15-bit LFSR noise; short=True gives the metallic 93-step mode."""

    def __init__(self, short=False):
        self.reg = 1
        self.short = short

    def step(self):
        bit = ((self.reg >> 0) ^ (self.reg >> (6 if self.short else 1))) & 1
        self.reg = (self.reg >> 1) | (bit << 14)
        return 1.0 if self.reg & 1 else -1.0


def env(t, dur, a=0.004, r=0.03, sustain=1.0, decay=0.0):
    """Attack / exponential decay / release envelope."""
    if t < a:
        return t / a
    v = sustain * math.exp(-decay * (t - a)) if decay else sustain
    if t > dur - r:
        v *= max(0.0, (dur - t) / r)
    return v


# ============================================================== SFX builder
def tone(dur, f0, f1=None, kind="pulse", duty=0.5, vol=1.0, decay=0.0, vib=0.0, curve=1.0):
    """Single voice with an exponential pitch glide from f0 to f1."""
    n = int(dur * SR)
    out = [0.0] * n
    ph = 0.0
    f1 = f0 if f1 is None else f1
    for i in range(n):
        t = i / SR
        k = (t / dur) ** curve
        f = f0 * (f1 / f0) ** k
        if vib:
            f *= 1 + vib * math.sin(t * 2 * math.pi * 7)
        ph += f / SR
        s = pulse(ph, duty) if kind == "pulse" else tri4(ph)
        out[i] = s * vol * env(t, dur, decay=decay)
    return out


def noise(dur, vol=1.0, decay=8.0, rate=1.0, rate_end=None, short=False, lp=0.0):
    """Noise burst; rate controls LFSR clock (1=bright, 0.1=rumbly)."""
    n = int(dur * SR)
    out = [0.0] * n
    gen = Noise(short)
    acc = 0.0
    cur = gen.step()
    prev = 0.0
    rate_end = rate if rate_end is None else rate_end
    for i in range(n):
        t = i / SR
        r = rate + (rate_end - rate) * (t / dur)
        acc += r
        while acc >= 1.0:
            acc -= 1.0
            cur = gen.step()
        s = cur
        if lp:
            prev = prev + lp * (s - prev)
            s = prev
        out[i] = s * vol * env(t, dur, a=0.001, decay=decay)
    return out


def mix(*parts, offsets=None):
    offsets = offsets or [0.0] * len(parts)
    n = max(int(o * SR) + len(p) for p, o in zip(parts, offsets))
    out = [0.0] * n
    for p, o in zip(parts, offsets):
        s = int(o * SR)
        for i, v in enumerate(p):
            out[s + i] += v
    return out


def seq(notes, step, kind="pulse", duty=0.5, vol=0.8, decay=6.0):
    """Quick arpeggio / jingle from note names, one per step."""
    parts = []
    offs = []
    for i, nm in enumerate(notes):
        if nm is None:
            continue
        length = step * 1.6 if i == len(notes) - 1 else step * 0.95
        parts.append(tone(length, hz(midi(nm)), kind=kind, duty=duty, vol=vol, decay=decay))
        offs.append(i * step)
    return mix(*parts, offsets=offs)


SFX = {
    # UI
    "ui_click": lambda: tone(0.05, 1320, 990, duty=0.25, vol=0.5, decay=30),
    "ui_hover": lambda: tone(0.025, 1760, duty=0.125, vol=0.18, decay=60),
    "card_select": lambda: seq(["E5", "B5"], 0.045, duty=0.25, vol=0.5, decay=25),
    "card_place": lambda: mix(tone(0.12, 220, 90, kind="tri", vol=0.9, decay=18),
                              noise(0.08, vol=0.35, decay=40, rate=0.35),
                              tone(0.06, 880, 1320, duty=0.25, vol=0.25, decay=35), offsets=[0, 0, 0.03]),
    "deny": lambda: mix(tone(0.09, 196, duty=0.5, vol=0.45), tone(0.12, 147, duty=0.5, vol=0.45), offsets=[0, 0.09]),
    "end_turn": lambda: seq(["C5", "E5", "G5", "C6"], 0.055, duty=0.25, vol=0.5, decay=14),
    # weapons
    "shot_rifle": lambda: mix(noise(0.09, vol=0.9, decay=45, rate=1.0), tone(0.04, 900, 300, duty=0.5, vol=0.3, decay=60)),
    "shot_cannon": lambda: mix(noise(0.45, vol=1.0, decay=9, rate=0.25, rate_end=0.05),
                               tone(0.25, 160, 45, kind="tri", vol=0.9, decay=10)),
    "shot_rocket": lambda: mix(noise(0.55, vol=0.6, decay=4, rate=0.08, rate_end=0.6),
                               tone(0.5, 180, 720, duty=0.125, vol=0.25, decay=4, curve=0.6)),
    "shot_laser": lambda: tone(0.18, 2200, 330, duty=0.25, vol=0.55, decay=12, curve=0.5),
    "shot_flak": lambda: mix(noise(0.07, vol=0.8, decay=50, rate=0.6), noise(0.07, vol=0.7, decay=50, rate=0.5),
                             noise(0.07, vol=0.6, decay=50, rate=0.45), offsets=[0, 0.08, 0.16]),
    "missile": lambda: mix(tone(0.35, 400, 1600, duty=0.125, vol=0.35, decay=3, curve=0.5),
                           noise(0.35, vol=0.4, decay=5, rate=0.7, short=True)),
    # impacts
    "hit": lambda: mix(noise(0.08, vol=0.7, decay=45, rate=0.5), tone(0.05, 300, 150, duty=0.5, vol=0.25, decay=50)),
    "explosion": lambda: mix(noise(0.9, vol=1.0, decay=4.5, rate=0.22, rate_end=0.03, lp=0.5),
                             tone(0.4, 110, 35, kind="tri", vol=0.8, decay=6)),
    "hq_hit": lambda: mix(tone(0.3, 90, 40, kind="tri", vol=1.0, decay=8), noise(0.25, vol=0.6, decay=12, rate=0.15),
                          tone(0.12, 587, 440, duty=0.5, vol=0.25, decay=10), offsets=[0, 0, 0.05]),
    "intercept": lambda: mix(tone(0.2, 1500, 3000, duty=0.125, vol=0.3, decay=12), noise(0.1, vol=0.4, decay=30, rate=0.9, short=True)),
    # economy / meta
    "coin": lambda: mix(tone(0.07, hz(midi("B5")), duty=0.5, vol=0.5), tone(0.28, hz(midi("E6")), duty=0.5, vol=0.5, decay=9), offsets=[0, 0.07]),
    "bio": lambda: seq(["C5", "G5", "E6"], 0.04, kind="tri", vol=0.8, decay=18),
    "heal": lambda: seq(["C6", "E6", "G6", "C7"], 0.035, duty=0.125, vol=0.35, decay=20),
    "shop_buy": lambda: mix(tone(0.06, hz(midi("E6")), duty=0.5, vol=0.45), seq(["G5", "C6", "E6", "G6"], 0.05, duty=0.25, vol=0.4), offsets=[0, 0.06]),
    "war": lambda: mix(*[noise(0.09, vol=0.5 + 0.05 * k, decay=25, rate=0.3) for k in range(8)],
                       seq(["D4", "A4", "D5"], 0.16, duty=0.5, vol=0.6, decay=3),
                       offsets=[k * 0.055 for k in range(8)] + [0.45]),
    "victory": lambda: mix(seq(["C5", "C5", "C5", "C5", None, "G#4", None, "A#4", None, "C5", None, "A#4", "C5"], 0.1, duty=0.25, vol=0.6, decay=2),
                           seq(["C3", None, None, None, "G#2", None, "A#2", None, "C3"], 0.13, kind="tri", vol=0.9, decay=1.5)),
    "defeat": lambda: mix(seq(["G4", "F#4", "F4", "E4"], 0.28, duty=0.5, vol=0.5, decay=2),
                          seq(["C3", "B2", "A#2", "A2"], 0.28, kind="tri", vol=0.8, decay=1.5)),
    "map_select": lambda: tone(0.06, 660, 880, kind="tri", vol=0.6, decay=25),
}


def gen_sfx():
    for name, fn in SFX.items():
        write_wav(os.path.join(OUT_SFX, name + ".wav"), fn())
        print("sfx", name)


# ================================================================== MUSIC
# A tiny tracker. Each song = tempo + 16 bars of chords; channels are
# generated from the chords (bass, arpeggio, drums) plus a composed lead.
CHORDS = {
    "Am": ["A", "C", "E"], "F": ["F", "A", "C"], "C": ["C", "E", "G"], "G": ["G", "B", "D"],
    "E": ["E", "G#", "B"], "Dm": ["D", "F", "A"], "A#": ["A#", "D", "F"], "Gm": ["G", "A#", "D"],
    "A": ["A", "C#", "E"], "Em": ["E", "G", "B"], "D": ["D", "F#", "A"], "B": ["B", "D#", "F#"],
    "Bm": ["B", "D", "F#"],
}


def chord_midis(ch, octave):
    names = CHORDS[ch]
    root = midi(names[0] + str(octave))
    out = []
    for nm in names:
        m = midi(nm + str(octave))
        while m < root:
            m += 12
        out.append(m)
    return out


class Track:
    def __init__(self, bpm, bars, steps_per_bar=16):
        self.step = 60.0 / bpm / 4.0
        self.steps = bars * steps_per_bar
        self.n = int(round(self.steps * self.step * SR))
        self.buf = [0.0] * self.n

    def note(self, start_step, len_steps, m, kind="pulse", duty=0.5, vol=0.3, decay=0.0, vib=0.0, slide_from=None):
        t0 = int(round(start_step * self.step * SR))
        dur = len_steps * self.step
        n = int(dur * SR)
        f = hz(m)
        ph = 0.0
        for i in range(n):
            idx = t0 + i
            if idx >= self.n:
                idx -= self.n  # wrap so loop tails stay seamless
            t = i / SR
            ff = f
            if slide_from is not None and t < 0.04:
                ff = hz(slide_from) + (f - hz(slide_from)) * (t / 0.04)
            if vib and t > 0.12:
                ff *= 1 + vib * math.sin(t * 2 * math.pi * 6)
            ph += ff / SR
            s = pulse(ph, duty) if kind == "pulse" else tri4(ph)
            self.buf[idx] += s * vol * env(t, dur, a=0.003, r=0.02, decay=decay)

    def drum(self, step, kind, vol=0.3):
        t0 = int(round(step * self.step * SR))
        if kind == "kick":
            part = mix(tone(0.12, 150, 42, kind="tri", vol=1.0, decay=14), noise(0.02, vol=0.3, decay=80, rate=0.3))
        elif kind == "snare":
            part = mix(noise(0.14, vol=1.0, decay=22, rate=0.7), tone(0.05, 220, 160, kind="tri", vol=0.4, decay=40))
        elif kind == "hat":
            part = noise(0.035, vol=0.6, decay=90, rate=1.0, short=True)
        elif kind == "ohat":
            part = noise(0.12, vol=0.5, decay=25, rate=1.0, short=True)
        else:  # tom
            part = tone(0.14, 200, 90, kind="tri", vol=1.0, decay=14)
        for i, v in enumerate(part):
            idx = t0 + i
            if idx >= self.n:
                idx -= self.n
            self.buf[idx] += v * vol


def compose(track, progression, key_scale, seed, lead_oct=5, style="battle"):
    """Bass + arpeggio + drums from the chords, and a motif-based lead."""
    rng = random.Random(seed)
    bars = len(progression)
    # --- bass: triangle, root/octave eighths (march: root-fifth)
    for b, ch in enumerate(progression):
        root = chord_midis(ch, 2)[0]
        fifth = chord_midis(ch, 2)[2]
        for e in range(8):
            if style == "map" and e % 2 == 1:
                continue
            m = root if e % 2 == 0 else (root + 12 if style == "battle" else fifth)
            ln = 2 if style != "map" else 4
            track.note(b * 16 + e * 2, ln * 0.9, m, kind="tri", vol=0.55)
    # --- arpeggio: 50% pulse, 16ths (map: 8ths), quiet
    for b, ch in enumerate(progression):
        tones = chord_midis(ch, 4)
        pattern = tones + [tones[0] + 12] if style != "map" else tones + [tones[1] + 12]
        step_len = 1 if style == "battle" else 2
        for k in range(16 // step_len):
            m = pattern[k % len(pattern)] if style != "menu" else pattern[(k * 2) % len(pattern)]
            track.note(b * 16 + k * step_len, step_len * 0.85, m, duty=0.5, vol=0.075 if style == "battle" else 0.065, decay=6)
    # --- drums
    for b in range(bars):
        s0 = b * 16
        fill = (b % 8 == 7)
        for st in range(16):
            if style == "battle":
                if st in (0, 6, 8) or (st == 10 and b % 2):
                    track.drum(s0 + st, "kick", 0.5)
                if st in (4, 12):
                    track.drum(s0 + st, "snare", 0.35)
                if st % 2 == 0:
                    track.drum(s0 + st, "hat", 0.12)
                if fill and st >= 12:
                    track.drum(s0 + st, "snare", 0.25)
            elif style == "menu":  # military march: snare rolls
                if st in (0, 8):
                    track.drum(s0 + st, "kick", 0.45)
                if st in (4, 12) or (st in (13, 14, 15) and b % 2):
                    track.drum(s0 + st, "snare", 0.25 if st in (4, 12) else 0.15)
                if st % 4 == 2:
                    track.drum(s0 + st, "hat", 0.08)
                if fill and st >= 8 and st % 2 == 0:
                    track.drum(s0 + st, "tom", 0.35)
            else:  # map: sparse and calm
                if st == 0:
                    track.drum(s0 + st, "kick", 0.35)
                if st == 8 and b % 2:
                    track.drum(s0 + st, "tom", 0.2)
                if st % 4 == 2:
                    track.drum(s0 + st, "hat", 0.05)
    # --- lead: 2-bar motif, repeated/varied over the chords (A A' B A'')
    scale = [midi(n + str(lead_oct)) for n in key_scale]
    scale = scale + [m + 12 for m in scale]

    def nearest_chord_tone(prev, ch):
        cands = [m for base in chord_midis(ch, lead_oct - 1) for m in (base, base + 12, base + 24)]
        cands = [m for m in cands if scale[0] - 3 <= m <= scale[-1]]
        return min(cands, key=lambda m: (abs(m - prev), m))

    if style == "map":
        rhythm = [(0, 6), (6, 2), (8, 4), (12, 4), (16, 8), (24, 4), (28, 4)]
    elif style == "menu":
        rhythm = [(0, 3), (3, 1), (4, 4), (8, 3), (11, 1), (12, 4), (16, 2), (18, 2), (20, 4), (24, 8)]
    else:
        rhythm = [(0, 2), (2, 2), (4, 3), (7, 1), (8, 2), (10, 2), (12, 4), (16, 2), (18, 1), (19, 1), (20, 2), (22, 2), (24, 6), (30, 2)]
    # motif as scale-step deltas, generated once, reused for structure
    motif = [rng.choice([-2, -1, 1, 1, 2, 0, 3, -3]) for _ in rhythm]
    b_motif = [rng.choice([-2, -1, 1, 2, 2, -1]) for _ in rhythm]
    prev = scale[4]
    for phrase in range(bars // 2):
        section = (phrase // 2) % 4  # 0:A 1:A' 2:B 3:A''
        deltas = b_motif if section == 2 else motif
        if section == 3 and phrase % 2 == 1:
            deltas = list(reversed(motif))
        base_step = phrase * 32
        for k, (off, ln) in enumerate(rhythm):
            bar = (base_step + off) // 16
            ch = progression[bar % bars]
            strong = off % 8 == 0
            if strong:
                m = nearest_chord_tone(prev, ch)
            else:
                idx = min(range(len(scale)), key=lambda j: abs(scale[j] - prev))
                idx = max(0, min(len(scale) - 1, idx + deltas[k]))
                m = scale[idx]
            # cadence: land on the chord root at the end of each 8-bar half
            if (phrase % 4 == 3) and k == len(rhythm) - 1:
                m = chord_midis(ch, lead_oct)[0]
            duty = 0.25 if style != "map" else 0.125
            track.note(base_step + off, ln * 0.92, m, duty=duty, vol=0.16 if style != "map" else 0.14,
                       decay=1.5 if ln <= 2 else 0.8, vib=0.006 if ln >= 4 else 0.0,
                       slide_from=prev if (style == "battle" and abs(m - prev) <= 2 and not strong) else None)
            prev = m


SONGS = {
    # name: (bpm, progression (1 chord per bar), scale, seed, style)
    "battle": (144, ["Am", "Am", "F", "F", "C", "C", "G", "G", "Am", "Am", "F", "F", "E", "E", "E", "E"],
               ["A", "B", "C", "D", "E", "F", "G"], 7, "battle"),
    "menu": (108, ["Dm", "Dm", "A#", "A#", "F", "F", "C", "C", "Dm", "Dm", "Gm", "Gm", "A", "A", "A", "A"],
             ["D", "E", "F", "G", "A", "A#", "C"], 11, "menu"),
    "map": (92, ["Em", "Em", "C", "C", "G", "G", "D", "D", "Em", "Em", "C", "C", "Bm", "Bm", "B", "B"],
            ["E", "F#", "G", "A", "B", "C", "D"], 5, "map"),
}


def gen_music():
    for name, (bpm, prog, scale, seed, style) in SONGS.items():
        tr = Track(bpm, len(prog))
        compose(tr, prog, scale, seed, style=style)
        write_wav(os.path.join(OUT_MUSIC, name + ".wav"), tr.buf, loop=True)
        print("music", name, "%.1fs" % (tr.n / SR))


if __name__ == "__main__":
    # The game's music is now tools/soundtrack.py; "chipmusic" still renders the old
    # 8-bit tunes (over the same files) if you ever want them back.
    what = sys.argv[1:] or ["sfx"]
    if "sfx" in what:
        gen_sfx()
    if "chipmusic" in what:
        gen_music()
    if "music" in what:
        print("The music is made by tools/soundtrack.py now (use 'chipmusic' for the old 8-bit tunes).")
