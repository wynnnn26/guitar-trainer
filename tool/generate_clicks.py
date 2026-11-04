#!/usr/bin/env python3
"""Generates the four metronome sound sets (16-bit mono WAV, 44.1 kHz).

Each set ships an accent variant (downbeat: higher, louder) and a normal one:

    assets/sounds/classic_accent.wav    classic_normal.wav     (Classic click)
    assets/sounds/woodblock_accent.wav  woodblock_normal.wav   (Woodblock)
    assets/sounds/digital_accent.wav    digital_normal.wav     (Digital beep)
    assets/sounds/soft_accent.wav       soft_normal.wav        (Soft tick)

Usage:  python3 tool/generate_clicks.py
"""
import math
import os
import random
import struct
import wave

SAMPLE_RATE = 44100

# wave, harmonic mix (2nd partial), partial ratio, noise amount, fade-in (s)
TIMBRE = {
    "classic":   dict(wave="sine", harmonic=0.35, ratio=2.0, noise=0.6, attack=0.001),
    "woodblock": dict(wave="sine", harmonic=0.5, ratio=2.7, noise=0.75, attack=0.001),
    "digital":   dict(wave="square", harmonic=0.5, ratio=2.0, noise=0.25, attack=0.001),
    "soft":      dict(wave="sine", harmonic=0.15, ratio=2.0, noise=0.2, attack=0.004),
}

# freq (Hz), duration (s), decay, gain
VARIANTS = {
    "classic":   dict(accent=(1600, 0.060, 55, 0.95), normal=(1000, 0.050, 65, 0.80)),
    "woodblock": dict(accent=(1450, 0.045, 85, 0.95), normal=(980, 0.040, 95, 0.80)),
    "digital":   dict(accent=(1320, 0.100, 30, 0.70), normal=(880, 0.090, 34, 0.60)),
    "soft":      dict(accent=(950, 0.035, 105, 0.60), normal=(640, 0.030, 115, 0.48)),
}


def wave_at(kind, phase):
    if kind == "square":
        return 1.0 if math.sin(phase) >= 0 else -1.0
    if kind == "triangle":
        return (2 / math.pi) * math.asin(math.sin(phase))
    return math.sin(phase)


def make_click(path, timbre, freq, duration_s, decay, gain):
    rng = random.Random(7)
    n = int(SAMPLE_RATE * duration_s)
    frames = bytearray()
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * decay)
        phase = 2 * math.pi * freq * t
        tone = wave_at(timbre["wave"], phase) + timbre["harmonic"] * wave_at(
            timbre["wave"], phase * timbre["ratio"]
        )
        # A few milliseconds of noise gives the click a crisp attack.
        transient = (rng.random() * 2 - 1) * math.exp(-t * 900) * 0.6
        # A short linear fade-in avoids a speaker "pop".
        fade_in = min(1.0, t / timbre["attack"])
        sample = (tone * 0.55 + transient * timbre["noise"] / 0.6) * env * fade_in * gain
        value = max(-1.0, min(1.0, sample))
        frames += struct.pack("<h", int(value * 32767))
    with wave.open(path, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(bytes(frames))
    # Read back what we wrote: a silent or truncated file would ship broken audio.
    with wave.open(path, "rb") as wav:
        frames_written = wav.getnframes()
        raw = wav.readframes(frames_written)
    peak = max((abs(v) for v in struct.unpack(f"<{len(raw) // 2}h", raw)), default=0)
    if frames_written < SAMPLE_RATE * 0.02 or peak < 0.05 * 32767:
        raise SystemExit(f"{path}: bad output (frames={frames_written}, peak={peak})")


if __name__ == "__main__":
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sounds")
    os.makedirs(out_dir, exist_ok=True)
    for name, variants in VARIANTS.items():
        for variant, (freq, dur, decay, gain) in variants.items():
            path = os.path.join(out_dir, f"{name}_{variant}.wav")
            make_click(path, TIMBRE[name], freq, dur, decay, gain)
            print("wrote", os.path.basename(path))
