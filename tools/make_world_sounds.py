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


# footstep_ground_1..3.wav: a footstep on dirt and gravel outdoors (a gritty
# crunch that drops off fast, over a low dull thud). Metal footsteps indoors
# come from gen_sounds.gd; these are the outdoor set.
def alpha(cutoff):
    return 1 - np.exp(-2 * np.pi * cutoff / RATE)


def envelope(t, attack, decay):
    return np.clip(t / attack, 0, 1) * np.exp(-t / decay)


rng_ground = np.random.default_rng(11)
for variant, name in enumerate(["footstep_ground_1.wav", "footstep_ground_2.wav", "footstep_ground_3.wav"]):
    v = variant * 0.35
    t = np.arange(int(RATE * 0.16)) / RATE
    thud = np.sin(2 * np.pi * (60 + v * 25) * t) * 0.45 * envelope(t, 0.004, 0.045)
    crunch = lowpass(rng_ground.uniform(-1, 1, t.size), alpha(2600 + v * 700)) * 0.6 * envelope(t, 0.002, 0.03)
    save(name, thud + crunch)
