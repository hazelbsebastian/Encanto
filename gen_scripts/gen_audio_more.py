"""Voice post-processing + extra SFX, ambience and kulintang-style music.

1) voice_raw/*.wav (Windows TTS, see gen_voice_tts.ps1) -> assets/audio/voice/
   trimmed, normalized; creature lines pitch-shifted with spooky effects.
2) New SFX, looping ambience per location and music loops -> assets/audio/
Everything is synthesized here (numpy only) - no external samples.
"""
import json
import os
import wave

import numpy as np

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
AUDIO = os.path.join(os.path.dirname(HERE), "assets", "audio")
VOICE_OUT = os.path.join(AUDIO, "voice")
rng = np.random.default_rng(7)


# ----------------------------------------------------------------- io ------
def read_wav(p):
    with wave.open(p) as w:
        sr = w.getframerate()
        n = w.getnframes()
        ch = w.getnchannels()
        data = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float32) / 32768.0
    if ch > 1:
        data = data.reshape(-1, ch).mean(axis=1)
    if sr != SR:
        data = resample(data, SR / sr)
    return data


def write_wav(path, s, peak=0.89):
    s = np.asarray(s, dtype=np.float64)
    m = np.max(np.abs(s)) if len(s) else 0
    if m > 0:
        s = s / m * peak
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(s, -1, 1) * 32767).astype(np.int16).tobytes())
    print("wrote", os.path.relpath(path, AUDIO), f"{len(s) / SR:.2f}s")


# ------------------------------------------------------------ dsp ---------
def resample(s, factor):
    """factor > 1 lengthens (lower pitch when played at SR)."""
    n = int(len(s) * factor)
    return np.interp(np.linspace(0, len(s) - 1, n), np.arange(len(s)), s)


def pitch(s, p):
    return resample(s, 1.0 / p)


def trim(s, thresh=0.02, pad=0.04):
    idx = np.where(np.abs(s) > thresh)[0]
    if len(idx) == 0:
        return s
    a = max(0, idx[0] - int(pad * SR))
    b = min(len(s), idx[-1] + int(pad * 2 * SR))
    return s[a:b]


def lowpass(s, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    out = np.empty_like(s)
    acc = 0.0
    for i, v in enumerate(s):
        acc = (1 - a) * v + a * acc
        out[i] = acc
    return out


def lp_fast(s, cutoff):
    """Cheap FFT lowpass for long buffers."""
    S = np.fft.rfft(s)
    f = np.fft.rfftfreq(len(s), 1 / SR)
    S *= 1 / (1 + (f / cutoff) ** 4)
    return np.fft.irfft(S, len(s))


def hp_fast(s, cutoff):
    S = np.fft.rfft(s)
    f = np.fft.rfftfreq(len(s), 1 / SR)
    S *= 1 - 1 / (1 + (f / max(1, cutoff)) ** 4)
    return np.fft.irfft(S, len(s))


def bandpass(s, lo, hi):
    return hp_fast(lp_fast(s, hi), lo)


def reverb(s, room=0.35, wet=0.3, tail=1.2):
    out = np.concatenate([s, np.zeros(int(tail * SR))])
    dry = out.copy()
    for d, g in [(0.029, 0.7), (0.037, 0.62), (0.043, 0.55), (0.053, 0.5), (0.067, 0.45), (0.079, 0.4)]:
        k = int(d * SR * (1 + room))
        comb = np.zeros_like(out)
        comb[k:] = out[:-k] * g
        for _ in range(3):
            comb[k:] += comb[:-k] * g * 0.5
        out = out + comb * wet / 3
    return dry * (1 - wet * 0.5) + (out - dry) * wet


def echo(s, delay=0.18, fb=0.45, n=4):
    out = np.concatenate([s, np.zeros(int(delay * SR * n))])
    for i in range(1, n + 1):
        k = int(delay * SR * i)
        out[k:k + len(s)] += s * (fb ** i)
    return out


def env(n, a=0.005, r=0.1):
    e = np.ones(n)
    a, r = min(int(a * SR), n), min(int(r * SR), n)
    if a:
        e[:a] = np.linspace(0, 1, a)
    if r:
        e[-r:] *= np.linspace(1, 0, r) ** 2
    return e


def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def sine(freq, dur, amp=1.0):
    return np.sin(2 * np.pi * freq * t_axis(dur)) * amp


def noise(dur):
    return rng.uniform(-1, 1, int(dur * SR))


def place(buf, s, at):
    i = int(at * SR)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(s))
    buf[i:j] += s[: j - i]


def mixs(*parts):
    out = np.zeros(max(len(x) for x in parts))
    for x in parts:
        out[: len(x)] += x
    return out


def gong(freq, dur=2.5, bright=1.0):
    """Metallic gong / kulintang kettle: inharmonic partials, exp decay."""
    t = t_axis(dur)
    partials = [(1.0, 1.0, 2.2), (2.01, 0.5 * bright, 3.5), (2.76, 0.35 * bright, 4.5), (4.07, 0.2 * bright, 6.0), (5.2, 0.1 * bright, 8)]
    s = np.zeros_like(t)
    for ratio, amp, dec in partials:
        s += amp * np.sin(2 * np.pi * freq * ratio * t + ratio) * np.exp(-t * dec / dur * 2.5)
    s *= 1 - np.exp(-t * 400)
    return s


def drum(dur=0.35, f0=110, f1=55, amp=1.0):
    t = t_axis(dur)
    f = f1 + (f0 - f1) * np.exp(-t * 25)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)
    slap = lp_fast(noise(dur), 2500) * np.exp(-t * 60) * 0.6
    return (body + slap) * amp


# ========================================================== VOICES =========
def voices():
    lines = json.load(open(os.path.join(HERE, "voice_lines.json"), encoding="utf-8"))
    for l in lines:
        p = os.path.join(HERE, "voice_raw", l["id"] + ".wav")
        if not os.path.exists(p):
            continue
        s = trim(read_wav(p))
        fx = l.get("fx", "")
        if "pitch" in l:
            s = pitch(s, l["pitch"])
        if fx == "creepy":
            t = np.arange(len(s)) / SR
            s = s * (0.75 + 0.25 * np.sin(2 * np.pi * 9 * t))
            s = reverb(s, 0.5, 0.45)
        elif fx == "echo":
            s = echo(s, 0.16, 0.5, 5)
            s = reverb(s, 0.6, 0.35)
        elif fx == "neigh":
            t = np.arange(len(s)) / SR
            wob = 1 + 0.08 * np.sin(2 * np.pi * 7 * t)
            idx = np.clip(np.cumsum(wob) - wob[0], 0, len(s) - 1)
            s = np.interp(idx, np.arange(len(s)), s)
            s = s + 0.3 * np.tanh(s * 6)
            s = reverb(s, 0.3, 0.25)
        elif fx == "deep":
            s = lp_fast(s, 1800) * 1.4
            s = np.tanh(s * 2.2)
            s = reverb(s, 0.8, 0.5, 1.6)
        else:
            # small "room" so TTS lines don't sound bone-dry
            s = reverb(s, 0.2, 0.12, 0.4)
        s = trim(s / (np.max(np.abs(s)) + 1e-9), 0.01, 0.02)[: int(4.5 * SR)]
        s[-int(0.05 * SR):] *= np.linspace(1, 0, int(0.05 * SR))
        write_wav(os.path.join(VOICE_OUT, l["id"] + ".wav"), s)


# ============================================================= SFX =========
def sfx():
    out = lambda name, s: write_wav(os.path.join(AUDIO, name + ".wav"), s)

    # wing flap: two soft filtered noise bursts
    b = np.zeros(int(0.45 * SR))
    for at in (0.0, 0.2):
        n = lp_fast(noise(0.16), 900) * env(int(0.16 * SR), 0.01, 0.12)
        place(b, n, at)
    out("wing_flap", b)

    # whoosh (dash / dive)
    d = 0.55
    t = t_axis(d)
    w = bandpass(noise(d), 300, 3000) * np.sin(np.pi * t / d) ** 2
    out("whoosh", w)

    # gallop: clip-clop pattern
    b = np.zeros(int(0.7 * SR))
    for at in (0.0, 0.12, 0.32, 0.44):
        place(b, bandpass(noise(0.05), 600, 3500) * env(int(0.05 * SR), 0.001, 0.045), at)
        place(b, sine(160, 0.06) * env(int(0.06 * SR), 0.001, 0.05) * 0.6, at)
    out("gallop", b)

    # rock hit on flesh/wood
    out("rock_hit", mixs(drum(0.2, 240, 90), bandpass(noise(0.08), 1500, 6000) * env(int(0.08 * SR), 0.001, 0.07) * 0.5))
    # tree knock
    tk = (sine(190, 0.35) + 0.6 * sine(430, 0.35) + 0.3 * sine(710, 0.35)) * np.exp(-t_axis(0.35) * 14)
    out("tree_hit", tk + bandpass(noise(0.35), 800, 4000) * np.exp(-t_axis(0.35) * 40) * 0.5)
    # tree fall: creak then crash
    cd = 1.2
    tc = t_axis(cd)
    f = 90 + 40 * np.sin(2 * np.pi * 1.3 * tc) + 25 * np.sin(2 * np.pi * 17 * tc)
    creak = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.3 * np.sin(np.pi * tc / cd)
    creak = lp_fast(creak, 1800)
    crash = lp_fast(noise(1.6), 2500) * np.exp(-t_axis(1.6) * 3)
    boom = drum(1.2, 80, 30, 1.6)
    b = np.zeros(int(3.0 * SR))
    place(b, creak, 0)
    place(b, crash, 1.1)
    place(b, boom, 1.1)
    out("tree_fall", reverb(b, 0.5, 0.3))
    # smoke puff
    out("smoke_puff", bandpass(noise(0.9), 400, 5000) * env(int(0.9 * SR), 0.05, 0.7) * 0.8)
    # heartbeat (low hearts warning)
    b = np.zeros(int(0.8 * SR))
    place(b, drum(0.25, 70, 40), 0)
    place(b, drum(0.25, 65, 38, 0.7), 0.22)
    out("heartbeat", b)
    # UI
    out("ui_move", sine(1760, 0.045) * env(int(0.045 * SR), 0.002, 0.04))
    b = np.zeros(int(0.22 * SR))
    place(b, sine(660, 0.08) * env(int(0.08 * SR), 0.002, 0.07), 0)
    place(b, sine(990, 0.1) * env(int(0.1 * SR), 0.002, 0.09), 0.08)
    out("puzzle_swap", b)
    out("gong", reverb(gong(196, 3.2, 1.2) + 0.6 * gong(98, 3.2, 0.6), 0.7, 0.35, 1.5))
    # kulintang flourish (stage start): ascending pentatonic kettles
    scale = [392, 440, 523, 587, 659, 784]
    b = np.zeros(int(2.4 * SR))
    for i, fq in enumerate(scale):
        place(b, gong(fq, 1.2, 0.8) * 0.7, i * 0.09)
    place(b, gong(131, 2.0, 0.5), 0.54)
    out("kulintang_flourish", reverb(b, 0.5, 0.3))
    # landing thump
    out("land", drum(0.15, 140, 60, 0.7))
    # jeepney brake squeal
    d = 0.8
    tb = t_axis(d)
    sq = np.sin(2 * np.pi * np.cumsum(2200 + 300 * np.sin(2 * np.pi * 6 * tb)) / SR) * 0.25 * env(len(tb), 0.05, 0.3)
    out("jeep_brake", sq + bandpass(noise(d), 200, 1500) * env(len(tb), 0.02, 0.4) * 0.5)
    # target lock tick
    out("lock_on", sine(1320, 0.06) * env(int(0.06 * SR), 0.002, 0.05) + sine(1980, 0.06) * 0.4 * env(int(0.06 * SR), 0.002, 0.05))


# ======================================================= AMBIENCE ==========
def seamless(buf, fade=1.5):
    """Crossfade the tail into the head so the loop has no click."""
    k = int(fade * SR)
    head, tail = buf[:k].copy(), buf[-k:].copy()
    ramp = np.linspace(0, 1, k)
    buf[:k] = head * ramp + tail * (1 - ramp)
    return buf[:-k]


def wind(dur, strength=0.25, lo=150, hi=900):
    t = t_axis(dur)
    base = bandpass(noise(dur), lo, hi)
    mod = 0.6 + 0.4 * np.sin(2 * np.pi * t / 7.3) * np.sin(2 * np.pi * t / 3.1 + 1)
    return base * mod * strength


def chirp_bird():
    d = rng.uniform(0.08, 0.2)
    t = t_axis(d)
    f0 = rng.uniform(2500, 4200)
    f = f0 + rng.uniform(-900, 900) * np.sin(np.pi * t / d) + 300 * np.sin(2 * np.pi * rng.uniform(20, 45) * t)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(t), 0.01, d * 0.6) * rng.uniform(0.2, 0.5)


def ambience():
    out = lambda name, s: write_wav(os.path.join(AUDIO, name + ".wav"), s, peak=0.6)
    D = 24.0

    # countryside birds + wind + cicadas (Banaue, Chocolate Hills)
    b = wind(D + 1.5, 0.35)
    for _ in range(46):
        at = rng.uniform(0, D)
        for k in range(int(rng.integers(1, 4))):
            place(b, chirp_bird(), at + k * 0.14)
    t = t_axis(D + 1.5)
    cicada = bandpass(noise(D + 1.5), 4500, 7000) * (0.5 + 0.5 * np.sin(2 * np.pi * 43 * t)) * (0.4 + 0.6 * np.clip(np.sin(2 * np.pi * t / 11), 0, 1)) * 0.12
    out("amb_countryside", seamless(b + cicada))

    # beach waves + gulls (Boracay)
    t = t_axis(D + 1.5)
    surf = lp_fast(noise(D + 1.5), 1100)
    swell = (0.35 + 0.65 * np.clip(np.sin(2 * np.pi * t / 6.0), 0, 1) ** 1.5)
    b = surf * swell * 0.8 + hp_fast(noise(D + 1.5), 3000) * swell ** 3 * 0.12
    for at in (3.0, 11.5, 18.0):
        for k in range(3):
            dg = 0.35
            tg = t_axis(dg)
            f = 1400 - 500 * tg / dg
            place(b, np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tg), 0.02, 0.2) * 0.12, at + k * 0.45)
    out("amb_beach", seamless(b))

    # old city: wind, distant church bells, pigeons (Intramuros)
    b = wind(D + 1.5, 0.25, 120, 700)
    for at in (2.0, 12.0):
        for k in range(3):
            place(b, reverb(gong(523, 3.0, 1.4) * 0.25, 0.9, 0.5, 1.0), at + k * 1.1)
    for _ in range(8):
        at = rng.uniform(0, D)
        dc = 0.5
        tc = t_axis(dc)
        coo = np.sin(2 * np.pi * (320 + 40 * np.sin(2 * np.pi * 3 * tc)) * tc) * env(len(tc), 0.05, 0.3) * 0.1
        place(b, lp_fast(coo, 900), at)
    out("amb_city", seamless(b))

    # volcano: strong wind + deep rumble (Mayon)
    t = t_axis(D + 1.5)
    rumble = lp_fast(noise(D + 1.5), 70) * (0.6 + 0.4 * np.sin(2 * np.pi * t / 9)) * 3.0
    b = wind(D + 1.5, 0.45, 200, 1200) + rumble
    for _ in range(18):
        place(b, chirp_bird() * 0.5, rng.uniform(0, D))
    out("amb_volcano", seamless(b))


# ========================================================== MUSIC ==========
def music_loop(name, bpm, melody, bass, scale, bars=8, bright=0.9, drums=True, gain=0.5):
    beat = 60.0 / bpm
    D = bars * 4 * beat
    b = np.zeros(int((D + 3.0) * SR))
    # melody: indices into scale, one per 8th note (None = rest)
    for i, n in enumerate(melody * (bars * 8 // len(melody))):
        if n is None:
            continue
        place(b, gong(scale[n], 0.9, bright) * 0.32, i * beat / 2)
    # agung (deep gong) + gandingan bass
    for i, n in enumerate(bass * (bars // len(bass) if len(bass) <= bars else 1)):
        place(b, gong(scale[n] / 4, 3.0, 0.4) * 0.55, i * 4 * beat)
        place(b, gong(scale[n] / 2, 1.2, 0.5) * 0.25, i * 4 * beat + 2 * beat)
    if drums:
        for i in range(bars * 4):
            place(b, drum(0.3, 150, 70, 0.45), i * beat)
            if i % 2 == 1:
                place(b, drum(0.12, 420, 260, 0.25), i * beat + beat / 2)
    # wrap the ringing tail back onto the start so the loop is seamless
    n = int(D * SR)
    loop = b[:n].copy()
    tail = b[n:]
    loop[: len(tail)] += tail
    loop = reverb(loop, 0.5, 0.2, 0.0)[:n]
    write_wav(os.path.join(AUDIO, name + ".wav"), loop, peak=gain)


def music():
    penta = [262, 294, 330, 392, 440, 523, 587, 659, 784, 880]
    minor = [220, 262, 294, 330, 392, 440, 523, 587, 659, 784]
    mel_a = [4, None, 5, 4, 3, None, 2, 3, 4, 6, 5, 4, 3, 2, 1, None]
    mel_b = [2, 4, 5, None, 7, 6, 5, 4, 5, None, 4, 3, 2, 3, 4, None]
    music_loop("music_explore", 108, mel_a + mel_b, [0, 3, 4, 3, 0, 3, 4, 0], penta)
    boss = [0, 2, 3, None, 3, 2, 0, None, 5, 4, 3, 2, 3, None, 1, 0]
    music_loop("music_boss", 132, boss, [0, 0, 2, 1, 0, 0, 2, 3], minor, bright=1.3, gain=0.55)
    calm = [4, None, None, 5, 7, None, 5, None, 4, None, 2, None, 3, None, None, None]
    music_loop("music_title", 84, calm, [0, 3, 4, 0], penta, bars=8, drums=False, gain=0.45)


if __name__ == "__main__":
    voices()
    sfx()
    ambience()
    music()
