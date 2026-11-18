"""Synthesizes simple SFX (no external samples) for Encanto using numpy + wave."""
import os
import numpy as np
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")
os.makedirs(OUT, exist_ok=True)

def env(n, attack=0.01, release=0.2):
    a = int(SR * attack)
    r = int(SR * release)
    e = np.ones(n)
    a = min(a, n)
    r = min(r, n)
    if a > 0:
        e[:a] = np.linspace(0, 1, a)
    if r > 0:
        e[-r:] *= np.linspace(1, 0, r)
    return e

def tone(freq, dur, wave_type="sine", vol=0.5, sweep_to=None, attack=0.01, release=0.2):
    n = int(SR * dur)
    t = np.linspace(0, dur, n, endpoint=False)
    f = np.linspace(freq, sweep_to, n) if sweep_to else np.full(n, freq)
    phase = 2 * np.pi * np.cumsum(f) / SR
    if wave_type == "sine":
        s = np.sin(phase)
    elif wave_type == "square":
        s = np.sign(np.sin(phase))
    elif wave_type == "saw":
        s = 2 * (phase / (2 * np.pi) % 1) - 1
    else:
        s = np.sin(phase)
    s *= env(n, attack, release) * vol
    return s

def noise_burst(dur, vol=0.4, attack=0.001, release=0.15, lowpass=None):
    n = int(SR * dur)
    s = (np.random.rand(n) * 2 - 1)
    if lowpass:
        k = max(1, int(SR / lowpass))
        kernel = np.ones(k) / k
        s = np.convolve(s, kernel, mode="same")
    s *= env(n, attack, release) * vol
    return s

def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out

def concat(*parts):
    return np.concatenate(parts)

def write_wav(name, samples):
    samples = np.clip(samples, -1, 1)
    data = (samples * 32767).astype(np.int16)
    p = os.path.join(OUT, name)
    with wave.open(p, "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(data.tobytes())
    print("wrote", p)

def generate():
    write_wav("click.wav", tone(1200, 0.06, "square", vol=0.3, attack=0.002, release=0.05))

    engine = mix(
        tone(80, 1.2, "saw", vol=0.25, attack=0.05, release=0.05),
        noise_burst(1.2, vol=0.08, lowpass=300, attack=0.05, release=0.05),
    )
    write_wav("jeepney_engine.wav", engine)

    horn = concat(
        tone(320, 0.25, "square", vol=0.4, attack=0.01, release=0.05),
        tone(260, 0.35, "square", vol=0.4, attack=0.01, release=0.1),
    )
    write_wav("jeepney_horn.wav", horn)

    write_wav("footstep.wav", noise_burst(0.08, vol=0.3, lowpass=500, release=0.06))

    write_wav("jump.wav", tone(300, 0.18, "sine", vol=0.4, sweep_to=700, attack=0.005, release=0.1))

    write_wav("shoot.wav", mix(
        tone(900, 0.08, "square", vol=0.35, sweep_to=200, attack=0.001, release=0.06),
        noise_burst(0.05, vol=0.2, lowpass=2000, release=0.04),
    ))

    write_wav("charge.wav", tone(150, 1.0, "sine", vol=0.3, sweep_to=900, attack=0.05, release=0.05))
    write_wav("charge_release.wav", mix(
        tone(900, 0.3, "sawtooth" if False else "saw", vol=0.4, sweep_to=120, attack=0.001, release=0.2),
        noise_burst(0.3, vol=0.3, lowpass=1500, release=0.25),
    ))

    write_wav("enemy_attack.wav", noise_burst(0.25, vol=0.35, lowpass=800, attack=0.001, release=0.2))

    write_wav("damage.wav", tone(400, 0.2, "square", vol=0.4, sweep_to=100, attack=0.001, release=0.15))

    puzzle_notes = [523, 659, 784, 1047]
    puzzle = concat(*[tone(f, 0.15, "sine", vol=0.35, attack=0.005, release=0.1) for f in puzzle_notes])
    write_wav("puzzle_complete.wav", puzzle)

    write_wav("enemy_defeat.wav", mix(
        tone(500, 0.3, "sine", vol=0.3, sweep_to=80, attack=0.001, release=0.25),
        noise_burst(0.3, vol=0.2, lowpass=1000, release=0.25),
    ))

    victory_notes = [523, 659, 784, 1047, 1319]
    victory = concat(*[tone(f, 0.18, "square", vol=0.3, attack=0.005, release=0.12) for f in victory_notes])
    write_wav("victory.wav", victory)

    write_wav("game_over.wav", concat(
        tone(300, 0.3, "sine", vol=0.35, sweep_to=150, attack=0.01, release=0.2),
        tone(150, 0.5, "sine", vol=0.35, sweep_to=60, attack=0.01, release=0.4),
    ))

    write_wav("puzzle_piece_pickup.wav", tone(700, 0.12, "sine", vol=0.35, sweep_to=1100, attack=0.002, release=0.08))
    write_wav("coin.wav", tone(900, 0.15, "square", vol=0.3, sweep_to=1400, attack=0.002, release=0.1))
    write_wav("bayong_open.wav", concat(
        noise_burst(0.15, vol=0.2, lowpass=1200, release=0.1),
        tone(600, 0.25, "sine", vol=0.3, sweep_to=1200, attack=0.01, release=0.2),
    ))

if __name__ == "__main__":
    generate()
