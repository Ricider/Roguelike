#!/usr/bin/env python3
"""Modern soundtrack generator: the game's looping music, synthesised in pure Python.

Replaces the old 8-bit tunes (tools/chiptune.py still makes the sound effects).
Subtractive synths in the style of modern game and film scores: detuned
analog-style pads through resonant filters, plucked arpeggios with ping-pong
delay, a sub bass, a felt piano, punchy electronic drums (kick, snare, clap,
hats, toms), sidechain pumping, a stereo reverb and a soft-clipping master.

Writes 16-bit stereo WAVs (32 kHz) to Assets/Audio/music/ with a RIFF 'smpl'
loop chunk. Each track's reverb and delay tails are folded back onto its start,
so the loop has no seam:
  menu.wav    "Long Shadows"  - cinematic theme, D minor, 84 bpm   (menu, story screens)
  map.wav     "Command Table" - strategy electronica, A minor, 100 bpm (the war map)
  battle.wav  "Front Line"    - driving hybrid, E minor, 128 bpm   (card battles)

    python3 tools/soundtrack.py            # all three
    python3 tools/soundtrack.py map        # one
"""
import math
import os
import random
import struct
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Assets", "Audio", "music")
SR = 32000
TAIL = 3.0  # seconds of reverb/delay tail folded back onto the loop's start
NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
        "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def m(name):
    """'A4' -> 69."""
    return 12 * (int(name[-1]) + 1) + NOTE[name[:-1]]


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12.0)


class Bus:
    """A stereo buffer."""

    def __init__(self, n):
        self.L = [0.0] * n
        self.R = [0.0] * n

    def add(self, l, r, at, gain=1.0, pan=0.0):
        """Mix mono (r None) or stereo samples in at sample `at`, panned -1..1."""
        gl = math.cos((pan + 1) * math.pi / 4) * gain * 1.41
        gr = math.sin((pan + 1) * math.pi / 4) * gain * 1.41
        L, R = self.L, self.R
        n = min(len(l), len(L) - at)
        if r is None:
            for i in range(max(0, -at), n):
                s = l[i]
                L[at + i] += s * gl
                R[at + i] += s * gr
        else:
            for i in range(max(0, -at), n):
                L[at + i] += l[i] * gl
                R[at + i] += r[i] * gr

    def mix_into(self, other, gain=1.0):
        oL, oR = other.L, other.R
        for i in range(len(self.L)):
            oL[i] += self.L[i] * gain
            oR[i] += self.R[i] * gain


# ------------------------------------------------------------------ building blocks
def adsr(n, a, d, s, r, sr=SR):
    """Envelope for a note held n samples, then released over r seconds."""
    a, d, r = int(a * sr) or 1, int(d * sr) or 1, int(r * sr) or 1
    out = []
    for i in range(n + r):
        if i < a:
            v = i / a
        elif i < a + d:
            v = 1 - (1 - s) * (i - a) / d
        elif i < n:
            v = s
        else:
            v = (s if n > a + d else max(0.0, 1 - (n - a) / max(a, 1))) * (1 - (i - n) / r)
        out.append(v)
    return out


def svf_lowpass(x, cutoff, q=0.6, lfo=None):
    """Chamberlin state-variable lowpass. cutoff in Hz (or a per-sample list)."""
    low = band = 0.0
    out = [0.0] * len(x)
    damp = 1.0 / max(q, 0.05)
    fixed = not isinstance(cutoff, list)
    f = 2 * math.sin(math.pi * min(cutoff, SR / 6.5) / SR) if fixed else 0.0
    for i, s in enumerate(x):
        if not fixed:
            f = 2 * math.sin(math.pi * min(cutoff[i], SR / 6.5) / SR)
        low += f * band
        high = s - low - damp * band
        band += f * high
        out[i] = low
    return out


def highpass(x, k=0.86):
    """Cheap one-pole highpass (for hats and air)."""
    out = [0.0] * len(x)
    prev_x = prev_y = 0.0
    for i, s in enumerate(x):
        y = k * (prev_y + s - prev_x)
        out[i] = y
        prev_x, prev_y = s, y
    return out


def saw_osc(f, n, phase=None, blep=True):
    ph = random.random() if phase is None else phase
    dt = f / SR
    out = [0.0] * n
    for i in range(n):
        s = 2 * ph - 1
        if blep:
            if ph < dt:
                t = ph / dt
                s -= t + t - t * t - 1
            elif ph > 1 - dt:
                t = (ph - 1) / dt
                s -= t * t + t + t + 1
        out[i] = s
        ph += dt
        if ph >= 1:
            ph -= 1
    return out


# ------------------------------------------------------------------ instruments
def pad(chord, dur, cutoff=1300.0, amp=0.11, attack=0.6, release=0.9, width=1.0, bright=1.0):
    """Warm analog pad: three detuned saws per note, spread wide, slow filter swell."""
    n = int(dur * SR)
    env = adsr(n, attack, 0.4, 0.85, release)
    total = len(env)
    L = [0.0] * total
    R = [0.0] * total
    for midi in chord:
        # detuned voices hard left and right around a centre one: a wide, moving stereo image
        for det, pan in ((-0.11, -width), (0.05, -width * 0.6), (-0.05, width * 0.6), (0.11, width)):
            osc = saw_osc(hz(midi + det), total, blep=False)
            gl = math.cos((pan + 1) * math.pi / 4)
            gr = math.sin((pan + 1) * math.pi / 4)
            for i in range(total):
                s = osc[i]
                L[i] += s * gl
                R[i] += s * gr
    sweep = [cutoff * bright * (0.55 + 0.45 * min(1.0, i / (attack * SR + 1))) * (1 + 0.08 * math.sin(i / SR * 1.3)) for i in range(total)]
    L = svf_lowpass(L, sweep, 0.7)
    R = svf_lowpass(R, sweep, 0.7)
    g = amp / max(len(chord), 1) * 1.15
    haas = int(0.012 * SR)  # the right side a touch late: the pad opens up across the speakers
    return ([L[i] * env[i] * g for i in range(total)],
            [(R[i - haas] * env[i - haas] * g if i >= haas else 0.0) for i in range(total)])


def pluck(midi, dur, amp=0.22, bright=3200.0, decay=0.28):
    """Plucked synth: saw through a lowpass whose cutoff falls fast, short amp decay."""
    n = int((dur + decay * 2) * SR)
    osc = saw_osc(hz(midi), n)
    osc2 = saw_osc(hz(midi + 0.07), n)
    cut = [180 + bright * math.exp(-i / (SR * decay * 0.5)) for i in range(n)]
    x = svf_lowpass([(osc[i] + osc2[i]) * 0.5 for i in range(n)], cut, 0.9)
    return [x[i] * amp * math.exp(-i / (SR * decay)) for i in range(n)]


def felt_piano(midi, dur, amp=0.3):
    """Soft piano: a few decaying harmonics with a gentle hammer."""
    n = int((dur + 1.6) * SR)
    f = hz(midi)
    out = [0.0] * n
    for k, (h, dec) in enumerate(((1, 1.8), (2, 0.9), (3, 0.5), (4, 0.3))):
        w = 2 * math.pi * f * h * (1 + 0.0004 * k) / SR
        a = (0.6, 0.25, 0.1, 0.05)[k]
        for i in range(n):
            out[i] += math.sin(w * i) * a * math.exp(-i / (SR * dec))
    att = int(0.004 * SR)
    for i in range(att):
        out[i] *= i / att
    return [s * amp for s in out]


def bass(midi, dur, amp=0.32, cutoff=420.0, drive=1.6):
    """Sub + a filtered, driven saw an octave up: modern synth bass."""
    n = int((dur + 0.05) * SR)
    f = hz(midi)
    saw = svf_lowpass(saw_osc(f, n), cutoff, 0.8)
    env = adsr(n - int(0.05 * SR), 0.003, 0.12, 0.7, 0.05)
    out = [0.0] * len(env)
    w = 2 * math.pi * f / SR
    for i in range(len(env)):
        s = math.sin(w * i) * 0.8 + saw[i] * 0.5 if i < n else 0.0
        out[i] = math.tanh(s * drive) * env[i] * amp
    return out


def lead(midi, dur, amp=0.14, cutoff=2400.0, vib=0.12):
    """Soft saw lead with delayed vibrato."""
    n = int(dur * SR)
    f = hz(midi)
    out = [0.0] * n
    ph1 = ph2 = 0.0
    for i in range(n):
        t = i / SR
        v = 1 + vib / 12 * math.log(2) * math.sin(2 * math.pi * 5.5 * t) * min(1.0, t / 0.3)
        ph1 = (ph1 + f * v / SR) % 1
        ph2 = (ph2 + f * v * 1.004 / SR) % 1
        out[i] = (2 * ph1 - 1) + (2 * ph2 - 1)
    out = svf_lowpass(out, cutoff, 0.8)
    env = adsr(n, 0.02, 0.2, 0.75, 0.25)
    return [out[i] * env[i] * amp if i < n else 0.0 for i in range(len(env))]


def kick(amp=0.9):
    n = int(0.42 * SR)
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / SR
        f = 45 + 110 * math.exp(-t / 0.035)
        ph += 2 * math.pi * f / SR
        out[i] = math.tanh(math.sin(ph) * 1.6) * math.exp(-t / 0.22)
    for i in range(int(0.004 * SR)):  # click
        out[i] += (random.random() * 2 - 1) * 0.5 * (1 - i / (0.004 * SR))
    return [s * amp for s in out]


def snare(amp=0.5):
    n = int(0.3 * SR)
    noise = highpass([random.random() * 2 - 1 for _ in range(n)], 0.7)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        out[i] = noise[i] * math.exp(-t / 0.09) * 0.8 + math.sin(2 * math.pi * 185 * t) * math.exp(-t / 0.05) * 0.6
    return [s * amp for s in out]


def clap(amp=0.45):
    n = int(0.35 * SR)
    noise = svf_lowpass(highpass([random.random() * 2 - 1 for _ in range(n)], 0.8), 3800.0, 1.2)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        e = math.exp(-t / 0.11)
        for burst in (0.0, 0.011, 0.022):  # the three hand slaps of a clap
            if t >= burst:
                e += 0.6 * math.exp(-(t - burst) / 0.008)
        out[i] = noise[i] * e
    return [s * amp for s in out]


def hat(open_=False, amp=0.16):
    n = int((0.25 if open_ else 0.06) * SR)
    noise = highpass(highpass([random.random() * 2 - 1 for _ in range(n)], 0.6), 0.6)
    dec = 0.09 if open_ else 0.018
    return [noise[i] * math.exp(-i / (SR * dec)) * amp for i in range(n)]


def tom(f0=110.0, amp=0.55, low=False):
    n = int((0.9 if low else 0.45) * SR)
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / SR
        ph += 2 * math.pi * (f0 * (0.6 + 0.4 * math.exp(-t / 0.08))) / SR
        out[i] = math.sin(ph) * math.exp(-t / (0.45 if low else 0.2))
    return [s * amp for s in out]


def riser(dur, amp=0.25):
    n = int(dur * SR)
    noise = [random.random() * 2 - 1 for _ in range(n)]
    cut = [300 + 6000 * (i / n) ** 2 for i in range(n)]
    x = svf_lowpass(noise, cut, 1.4)
    return [x[i] * amp * (i / n) ** 1.5 for i in range(n)]


# ------------------------------------------------------------------ effects
def pingpong(bus, delay_s, feedback=0.38, mix=0.32):
    """Ping-pong echo, in place."""
    d = int(delay_s * SR)
    L, R = bus.L, bus.R
    n = len(L)
    eL = [0.0] * n
    eR = [0.0] * n
    for i in range(d, n):
        eL[i] = R[i - d] * mix + eR[i - d] * feedback
        eR[i] = L[i - d] * mix * 0.6 + eL[i - d] * feedback
    for i in range(n):
        L[i] += eL[i]
        R[i] += eR[i]


def reverb(bus, size=0.84, damp=0.25, wet=0.3):
    """Freeverb-style stereo reverb (4 combs + 2 allpasses per side), returned as a new bus."""
    out = Bus(len(bus.L))
    for side, src, dst, spread in ((0, bus.L, out.L, 0), (1, bus.R, out.R, 23)):
        combs = [int((c + spread) * SR / 44100) for c in (1116, 1188, 1277, 1356)]
        aps = [int((a + spread) * SR / 44100) for a in (556, 441)]
        n = len(src)
        acc = [0.0] * n
        for c in combs:
            buf = [0.0] * c
            idx = 0
            store = 0.0
            for i in range(n):
                y = buf[idx]
                store = y * (1 - damp) + store * damp
                buf[idx] = src[i] * 0.015 + store * size
                acc[i] += y
                idx += 1
                if idx == c:
                    idx = 0
        for a in aps:
            buf = [0.0] * a
            idx = 0
            for i in range(n):
                b = buf[idx]
                x = acc[i]
                buf[idx] = x + b * 0.5
                acc[i] = b - x
                idx += 1
                if idx == a:
                    idx = 0
        for i in range(n):
            dst[i] = acc[i] * wet
    return out


def duck(bus, kick_samples, depth=0.55, release=0.16):
    """Sidechain pumping: dip the bus after every kick."""
    n = len(bus.L)
    g = [1.0] * n
    rel = int(release * SR * 4)
    for k in kick_samples:
        for i in range(rel):
            j = k + i
            if j >= n:
                break
            g[j] = min(g[j], 1 - depth * math.exp(-i / (release * SR)))
    for i in range(n):
        bus.L[i] *= g[i]
        bus.R[i] *= g[i]


# ------------------------------------------------------------------ output
def write(name, master, n_loop):
    """Fold the tail onto the start, soft-clip, normalise and write a looping stereo WAV."""
    L, R = master.L, master.R
    for i in range(len(L) - n_loop):
        L[i] += L[n_loop + i]
        R[i] += R[n_loop + i]
    L, R = L[:n_loop], R[:n_loop]
    peak = max(1e-9, max(max(abs(s) for s in L), max(abs(s) for s in R)))
    pre = 1.15 / peak
    L = [math.tanh(s * pre) for s in L]
    R = [math.tanh(s * pre) for s in R]
    peak = max(max(abs(s) for s in L), max(abs(s) for s in R))
    g = 0.89 / peak  # about -1 dBFS
    frames = bytearray()
    for i in range(n_loop):
        frames += struct.pack("<hh", int(L[i] * g * 32767), int(R[i] * g * 32767))
    path = os.path.join(OUT, name + ".wav")
    os.makedirs(OUT, exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))
    smpl = struct.pack("<9I", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
    smpl += struct.pack("<6I", 0, 0, 0, n_loop - 1, 0, 0)
    with open(path, "r+b") as f:
        f.seek(0, 2)
        f.write(b"smpl" + struct.pack("<I", len(smpl)) + smpl)
        size = f.tell() - 8
        f.seek(4)
        f.write(struct.pack("<I", size))
    print("music %-7s %.1fs  %s" % (name, n_loop / SR, path))


def chord_of(root, kind, octave=3):
    base = m(root + str(octave))
    return [base + iv for iv in {"min": (0, 3, 7, 12), "maj": (0, 4, 7, 12), "sus": (0, 5, 7, 12), "min7": (0, 3, 7, 10)}[kind]]


# ------------------------------------------------------------------ tracks
def track_menu():
    """Long Shadows: a slow cinematic theme."""
    random.seed(11)
    bpm, beats = 84, 4
    spb = 60.0 / bpm
    prog = [("D", "min"), ("Bb", "maj"), ("F", "maj"), ("C", "maj")]  # i - VI - III - VII, two bars each
    bars = 16
    n_loop = int(bars * beats * spb * SR)
    n = n_loop + int(TAIL * SR)
    pads, keys, low, drums = Bus(n), Bus(n), Bus(n), Bus(n)
    bar = beats * spb
    motif = [0, 2, 4, 2, 3, 2, 1, 0]  # chord tones walked per beat (index into the chord, +12 above)
    for b in range(bars):
        root, kind = prog[(b // 2) % 4]
        chord = chord_of(root, kind, 3)
        t0 = int(b * bar * SR)
        if b % 2 == 0:
            l, r = pad(chord + [chord[1] + 12], 2 * bar, cutoff=900 + (500 if b >= 8 else 0), amp=0.14, attack=1.2, release=1.6)
            pads.add(l, r, t0)
            low.add(bass(chord[0] - 12, 2 * bar, amp=0.22, cutoff=180), None, t0)
        # felt piano: a falling, broken chord with a melody note on top
        for k in range(beats * 2):
            note = chord[motif[k] % 4] + 12 + (12 if motif[k] >= 4 else 0)
            if k % 2 == 0 or b >= 8:
                keys.add(felt_piano(note, spb * 0.6, amp=0.18 if k % 2 == 0 else 0.1), None, t0 + int(k * spb / 2 * SR),
                         pan=0.25 * math.sin(k))
        if b >= 8 and b % 2 == 0:  # distant low drums under the second half
            drums.add(tom(62, 0.5, low=True), None, t0)
            drums.add(tom(62, 0.3, low=True), None, t0 + int(2.5 * spb * SR))
    pingpong(keys, spb * 0.75, 0.3, 0.25)
    master = Bus(n)
    for bus, gain in ((pads, 1.0), (keys, 1.0), (low, 1.0), (drums, 0.9)):
        bus.mix_into(master, gain)
    send = Bus(n)
    for bus, gain in ((pads, 0.9), (keys, 1.0), (drums, 0.6)):
        bus.mix_into(send, gain)
    reverb(send, 0.88, 0.3, 0.55).mix_into(master)
    write("menu", master, n_loop)


def track_map():
    """Command Table: modern strategy-game electronica that builds and breathes."""
    random.seed(23)
    bpm, beats = 100, 4
    spb = 60.0 / bpm
    prog = [("A", "min"), ("F", "maj"), ("C", "maj"), ("G", "maj"), ("A", "min"), ("F", "maj"), ("E", "min"), ("G", "maj")]
    bars = 24
    bar = beats * spb
    n_loop = int(bars * bar * SR)
    n = n_loop + int(TAIL * SR)
    pads, arps, low, drums, top = Bus(n), Bus(n), Bus(n), Bus(n), Bus(n)
    K, C, HH, OH = kick(0.8), clap(0.38), hat(False, 0.12), hat(True, 0.09)
    kicks = []
    arp_pattern = [0, 2, 1, 3, 2, 1, 3, 2]  # 8ths through chord tones
    melody = {16: [(0, "E5", 1.5), (1.5, "D5", 0.5), (2, "C5", 2)], 17: [(0, "A4", 3), (3, "C5", 1)],
              18: [(0, "G4", 1.5), (1.5, "A4", 0.5), (2, "C5", 1), (3, "D5", 1)], 19: [(0, "B4", 4)],
              20: [(0, "E5", 1.5), (1.5, "G5", 0.5), (2, "E5", 2)], 21: [(0, "C5", 3), (3, "A4", 1)],
              22: [(0, "B4", 2), (2, "G4", 2)], 23: [(0, "B4", 3), (3, "D5", 1)]}
    for b in range(bars):
        root, kind = prog[b % 8]
        chord = chord_of(root, kind, 3)
        t0 = int(b * bar * SR)
        section = 0 if b < 8 else (1 if b < 16 else 2)  # light, full, full + lead
        l, r = pad(chord, bar, cutoff=1100 + 500 * section, amp=0.12, attack=0.4, release=0.8)
        pads.add(l, r, t0)
        for k in range(beats * 2):
            note = chord[arp_pattern[k]] + 12 + (12 if k in (3, 7) else 0)
            arps.add(pluck(note, spb / 2, amp=0.2, bright=2200 + 900 * section), None, t0 + int(k * spb / 2 * SR), pan=-0.3 if k % 2 else 0.3)
        if section >= 1:
            for k in range(beats * 2):
                low.add(bass(chord[0] - 12, spb / 2 * 0.9, amp=0.26 if k % 2 == 0 else 0.18), None, t0 + int(k * spb / 2 * SR))
            for k in range(beats):
                ts = t0 + int(k * spb * SR)
                if k in (0, 2):
                    drums.add(K, None, ts)
                    kicks.append(ts)
                if k in (1, 3):
                    drums.add(C, None, ts)
                drums.add(HH, None, ts + int(spb / 2 * SR), pan=0.3)
                drums.add(HH, None, ts, gain=0.6, pan=-0.2)
            if b % 4 == 3:
                drums.add(OH, None, t0 + int(3.5 * spb * SR), pan=0.4)
        if section == 2:
            for (beat, note, dur) in melody.get(b, []):
                top.add(lead(m(note), dur * spb, amp=0.12), None, t0 + int(beat * spb * SR), pan=0.1)
    pingpong(arps, spb * 0.75, 0.42, 0.35)
    pingpong(top, spb * 0.5, 0.3, 0.25)
    duck(pads, kicks, 0.35)
    duck(low, kicks, 0.5)
    master = Bus(n)
    for bus, gain in ((pads, 1.0), (arps, 0.9), (low, 1.0), (drums, 1.0), (top, 1.0)):
        bus.mix_into(master, gain)
    send = Bus(n)
    for bus, gain in ((pads, 0.7), (arps, 0.8), (top, 0.9), (drums, 0.25)):
        bus.mix_into(send, gain)
    reverb(send, 0.84, 0.25, 0.45).mix_into(master)
    write("map", master, n_loop)


def track_battle():
    """Front Line: a driving hybrid track with a breakdown."""
    random.seed(37)
    bpm, beats = 128, 4
    spb = 60.0 / bpm
    prog = [("E", "min"), ("C", "maj"), ("G", "maj"), ("D", "maj")]
    bars = 24
    bar = beats * spb
    n_loop = int(bars * bar * SR)
    n = n_loop + int(TAIL * SR)
    pads, low, drums, top, fx = Bus(n), Bus(n), Bus(n), Bus(n), Bus(n)
    K, S, HH, OH = kick(0.95), snare(0.5), hat(False, 0.13), hat(True, 0.1)
    kicks = []
    hook = [(0, "E5", 0.5), (0.5, "G5", 0.5), (1, "B5", 1), (2.5, "A5", 0.5), (3, "G5", 1)]
    for b in range(bars):
        root, kind = prog[b % 4]
        chord = chord_of(root, kind, 3)
        t0 = int(b * bar * SR)
        breakdown = 16 <= b < 20
        l, r = pad(chord + [chord[2] + 12], bar, cutoff=1800 if not breakdown else 900, amp=0.13, attack=0.05, release=0.3)
        pads.add(l, r, t0)
        if not breakdown:
            for k in range(beats * 4):
                low.add(bass(chord[0] - 12 + (12 if k % 4 == 3 else 0), spb / 4 * 0.85, amp=0.24, cutoff=600, drive=2.2), None,
                        t0 + int(k * spb / 4 * SR))
            for k in range(beats):
                ts = t0 + int(k * spb * SR)
                drums.add(K, None, ts)
                kicks.append(ts)
                if k in (1, 3):
                    drums.add(S, None, ts)
                for h in range(4):
                    drums.add(HH, None, ts + int(h * spb / 4 * SR), gain=1.0 if h % 2 else 0.55, pan=0.25 if h % 2 else -0.15)
            drums.add(OH, None, t0 + int(3.5 * spb * SR), pan=0.4)
            if 8 <= b < 16 or b >= 20:
                for (beat, note, dur) in hook:
                    top.add(lead(m(note) - (0 if b % 2 == 0 else 2), dur * spb, amp=0.12, cutoff=3200), None, t0 + int(beat * spb * SR))
        else:
            for k in range(beats * 2):
                top.add(pluck(chord[k % 4] + 24, spb / 2, amp=0.16, bright=2600), None, t0 + int(k * spb / 2 * SR), pan=0.4 if k % 2 else -0.4)
        if b == 19:
            fx.add(riser(bar, 0.3), None, t0)
        if b == 23:  # a tom fill into the loop
            for k, f in enumerate((180, 150, 120, 95)):
                drums.add(tom(f, 0.45), None, t0 + int((3 + k * 0.25) * spb * SR))
    pingpong(top, spb * 0.75, 0.35, 0.3)
    duck(pads, kicks, 0.6, 0.14)
    duck(low, kicks, 0.45, 0.1)
    master = Bus(n)
    for bus, gain in ((pads, 1.0), (low, 1.0), (drums, 1.0), (top, 1.0), (fx, 1.0)):
        bus.mix_into(master, gain)
    send = Bus(n)
    for bus, gain in ((pads, 0.5), (top, 0.8), (drums, 0.2), (fx, 0.6)):
        bus.mix_into(send, gain)
    reverb(send, 0.8, 0.3, 0.35).mix_into(master)
    write("battle", master, n_loop)


TRACKS = {"menu": track_menu, "map": track_map, "battle": track_battle}

if __name__ == "__main__":
    for name in (sys.argv[1:] or list(TRACKS)):
        TRACKS[name]()
