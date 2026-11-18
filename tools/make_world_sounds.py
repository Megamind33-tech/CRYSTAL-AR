"""THE HUNT: procedural sounds for the world (project-owned, generated).
    python3 tools/make_world_sounds.py
drill_loop.wav: a drill rig at work (motor hum, grinding bit, rattle).
storm_wind.wav: a Martian dust storm (gusting filtered noise, grit hiss).
Both 16-bit mono 22050 Hz, seamless loops (cross-faded ends)."""
import numpy as np, wave, os

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio", "generated")
rng = np.random.default_rng(7)


def lowpass(x, a):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def loop(x, fade=4000):
    head = x[:fade].copy()
    x = x[fade:]
    ramp = np.linspace(0, 1, fade)
    x[-fade:] = x[-fade:] * (1 - ramp) + head * ramp
    return x


def save(name, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.85
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(data.tobytes())
    print("SOUND", name, len(data) / RATE, "s")


t = np.arange(int(RATE * 4.2)) / RATE
motor = 0.5 * np.sin(2 * np.pi * 58 * t) + 0.25 * np.sin(2 * np.pi * 116 * t) + 0.12 * np.sin(2 * np.pi * 174 * t)
grind = lowpass(rng.standard_normal(t.size), 0.25) * (0.6 + 0.4 * np.sin(2 * np.pi * 7.5 * t))
rattle = (np.sin(2 * np.pi * 13 * t) > 0.92).astype(float) * rng.standard_normal(t.size) * 0.4
save("drill_loop.wav", loop(motor + 0.9 * grind + rattle))

t = np.arange(int(RATE * 8.4)) / RATE
noise = rng.standard_normal(t.size)
body = lowpass(noise, 0.035)
gust = 0.55 + 0.45 * np.sin(2 * np.pi * 0.23 * t + 1.3 * np.sin(2 * np.pi * 0.07 * t))
hiss = (noise - lowpass(noise, 0.3)) * 0.15
save("storm_wind.wav", loop(body * gust * 3.0 + hiss * gust))

# honk.wav: a rover's horn (two detuned square-ish tones, a short blast).
t = np.arange(int(RATE * 0.55)) / RATE
tone = np.sign(np.sin(2 * np.pi * 330 * t)) * 0.5 + np.sign(np.sin(2 * np.pi * 415 * t)) * 0.5
env = np.minimum(1.0, t / 0.02) * np.minimum(1.0, (t[-1] - t) / 0.06)
save("honk.wav", lowpass(tone, 0.35) * env)

# jet_loop.wav: a jetpack's roar (rumbling filtered noise, a burner hiss).
t = np.arange(int(RATE * 2.4)) / RATE
noise = rng.standard_normal(t.size)
roar = lowpass(noise, 0.06) * (0.8 + 0.2 * np.sin(2 * np.pi * 9 * t))
hiss = (noise - lowpass(noise, 0.4)) * 0.25
save("jet_loop.wav", loop(roar * 3.0 + hiss, fade=2000))


# Footsteps: footstep_<surface>_1..6.wav, a booted step on each surface
# (GameAudio picks the set from what's underfoot). A step is two contacts
# 25-50 ms apart, heel then sole; each is the boot's soft rubber knock plus
# the surface's own voice:
#   wood     the deck boards' hollow knock (resonances 160-900 Hz)
#   metal    a deck plate's ring (inharmonic partials from ~400 Hz, decaying
#            over ~0.15 s) and a little grate rattle
#   concrete a hard, dry tap (a short bright click) and grit under the sole
#   sand     ground and gravel: a granular crunch (tiny grain clicks) over a
#            dull thud
# Six variants each (strike strength, heel-sole gap, pitch, grit, a scuff on
# some), loudness-matched so no set jumps out; 22050 Hz mono, 16-bit.
def biquad(x, kind, f, q):
    w = 2 * np.pi * f / RATE
    a = np.sin(w) / (2 * q)
    c = np.cos(w)
    if kind == "bp":
        b0, b1, b2 = a, 0.0, -a
    elif kind == "lp":
        b0, b1, b2 = (1 - c) / 2, 1 - c, (1 - c) / 2
    else:  # hp
        b0, b1, b2 = (1 + c) / 2, -(1 + c), (1 + c) / 2
    a0, a1, a2 = 1 + a, -2 * c, 1 - a
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        y[i] = o
    return y


def decay(t, tau, attack=0.0015):
    return np.clip(t / attack, 0, 1) * np.exp(-t / tau)


def modes(t, freqs, taus, amps, r):
    out = np.zeros_like(t)
    for f, tau, a in zip(freqs, taus, amps):
        out += a * np.sin(2 * np.pi * f * r.uniform(0.97, 1.03) * t + r.uniform(0, 6.28)) * decay(t, tau, 0.0008)
    return out


def hit(surface, t, strength, r):
    """One contact (heel or sole) on a surface, starting at t = 0."""
    noise = r.standard_normal(t.size)
    knock = biquad(noise, "lp", 260, 0.7) * decay(t, 0.018) * 2.2  # the boot's rubber thump
    if surface == "wood":
        body = modes(t, [165, 240, 410, 620, 890], [0.05, 0.04, 0.03, 0.022, 0.015], [1.0, 0.7, 0.5, 0.35, 0.2], r)
        click = biquad(noise, "bp", 1800, 1.2) * decay(t, 0.006) * 0.6
        out = knock * 0.8 + body * 0.55 + click
    elif surface == "metal":
        f0 = r.uniform(380, 460)
        body = modes(t, [f0, f0 * 2.31, f0 * 3.73, f0 * 5.2, f0 * 7.9], [0.13, 0.1, 0.07, 0.05, 0.035],
                     [0.6, 0.5, 0.35, 0.25, 0.15], r)
        clank = biquad(noise, "bp", 2600, 2.0) * decay(t, 0.01) * 0.8
        gate = (np.sin(2 * np.pi * r.uniform(35, 55) * t) > 0.6).astype(float)
        rattle = biquad(noise * gate, "bp", 3000, 1.5) * decay(t, 0.05) * 0.2
        out = knock * 0.7 + body * 0.3 + clank + rattle
    elif surface == "concrete":
        tap = biquad(noise, "bp", r.uniform(2200, 3000), 0.9) * decay(t, 0.007) * 1.6
        grit = biquad(noise * (r.uniform(0, 1, t.size) > 0.7), "hp", 3500, 0.7) * decay(t, 0.03) * 0.3
        out = knock + tap + grit
    else:  # sand / ground
        grains = (r.uniform(0, 1, t.size) > 0.93) * r.standard_normal(t.size)
        crunch = biquad(grains, "bp", r.uniform(2400, 3600), 0.8) * decay(t, 0.045, 0.004) * 2.2
        crunch += biquad(grains, "bp", 900, 1.0) * decay(t, 0.03, 0.004) * 0.8
        out = knock * 1.2 + crunch
    return out * strength


DUR = {"wood": 0.26, "metal": 0.4, "concrete": 0.2, "sand": 0.26}
for surface in ["wood", "metal", "concrete", "sand"]:
    for variant in range(1, 7):
        r = np.random.default_rng(100 * len(surface) + variant)
        n = int(RATE * DUR[surface])
        t = np.arange(n) / RATE
        x = hit(surface, t, r.uniform(0.85, 1.0), r)
        gap = int(RATE * r.uniform(0.025, 0.05))  # the sole comes down after the heel
        x[gap:] += hit(surface, t[: n - gap], r.uniform(0.45, 0.7), r)
        if variant % 3 == 0:  # a scuff: the sole drags as it lifts (soft hiss)
            x += biquad(r.standard_normal(n), "bp", 1500, 0.7) * np.exp(-(((t - 0.09) / 0.03) ** 2)) * 0.12
        x *= np.minimum(1.0, (t[-1] - t) / 0.02)  # no click at the end
        # Matched loudness: RMS over the first 80 ms, then a soft limit.
        rms = np.sqrt(np.mean(x[: int(RATE * 0.08)] ** 2)) + 1e-9
        x = np.tanh(x / rms * 0.16) * 0.67
        data = (x * 32767).astype(np.int16)
        name = "footstep_%s_%d.wav" % (surface, variant)
        with wave.open(os.path.join(OUT, name), "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(data.tobytes())
        print("SOUND", name, n / RATE, "s")
