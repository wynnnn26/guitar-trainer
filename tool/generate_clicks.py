#!/usr/bin/env python3
"""Generates the two metronome click sounds (16-bit mono WAV, 44.1 kHz).

Usage:  python3 tool/generate_clicks.py
Output: assets/sounds/click_accent.wav  (downbeat, higher pitch)
        assets/sounds/click_normal.wav  (other beats)
"""
import math
import os
import random
import struct
import wave

SAMPLE_RATE = 44100


def make_click(path, freq, duration_s, decay, gain):
    rng = random.Random(7)
    n = int(SAMPLE_RATE * duration_s)
    frames = bytearray()
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * decay)
        tone = math.sin(2 * math.pi * freq * t) + 0.35 * math.sin(2 * math.pi * freq * 2 * t)
        # A few milliseconds of noise gives the click a crisp attack.
        transient = (rng.random() * 2 - 1) * math.exp(-t * 900) * 0.6
        # 1 ms linear fade-in avoids a speaker "pop".
        fade_in = min(1.0, t / 0.001)
        sample = (tone * 0.55 + transient) * env * fade_in * gain
        value = max(-1.0, min(1.0, sample))
        frames += struct.pack("<h", int(value * 32767))
    with wave.open(path, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(bytes(frames))


if __name__ == "__main__":
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sounds")
    os.makedirs(out_dir, exist_ok=True)
    make_click(os.path.join(out_dir, "click_accent.wav"), 1600, 0.060, 55, 0.95)
    make_click(os.path.join(out_dir, "click_normal.wav"), 1000, 0.050, 65, 0.80)
    print("Generated click sounds in", os.path.abspath(out_dir))
