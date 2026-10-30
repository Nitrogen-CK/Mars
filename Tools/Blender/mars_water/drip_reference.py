"""Reference implementation of the Mars drip clock (Shaders/Water/MarsDrip.ush), plain Python 3, uint32 maths masked.

    python -I drip_reference.py --selftest            # clock invariants over 1e5 drops (the AS tests pin the same ones)
    python -I drip_reference.py --golden              # prints the 40-row golden table pasted into
                                                      #   Script/Tests/Drips/Mars_AutoTest_DripSchedule_MatchesTheReferenceTable.as
    python -I drip_reference.py --predict L RATE SEED JITTER T   # where every slot's drop is at time T (capture checks)
    python -I drip_reference.py --sheet [OUT_DIR]     # space-time PNG sheets (time across, depth down) for tuning

Floats: the shader runs in float32, the AS mirror and this file in float64. The per-strand key is built from the seed
times 2^24, which is exact in both, so the hashes agree; the seed itself is rounded to float32 first (it reaches the
shader as a float32 custom-data float).
"""
import math
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import water_spec as spec  # noqa: E402

K = spec.CONSTANTS
G = K["MARS_DRIP_GRAVITY"]
VT = K["MARS_DRIP_TERMINAL"]
MAXJ = K["MARS_DRIP_MAX_JITTER"]
SKIPJ = K["MARS_DRIP_SKIP_PER_JITTER"]
SLOTS = K["MARS_DRIP_SLOTS"]
WRAP = K["MARS_DRIP_WRAP"]
SPLASH = K["MARS_DRIP_SPLASH_S"]
M32 = 0xFFFFFFFF


def f32(x):
    return struct.unpack("f", struct.pack("f", float(x)))[0]


def hash32(x):
    x &= M32
    x ^= x >> 16
    x = (x * 0x7feb352d) & M32
    x ^= x >> 15
    x = (x * 0x846ca68b) & M32
    x ^= x >> 16
    return x


def saturate(x):
    return min(max(x, 0.0), 1.0)


def distance_at(a):
    x = G * max(a, 0.0) / VT
    return (VT * VT / G) * (x + math.log(0.5 + 0.5 * math.exp(-2.0 * x)))


def speed_at(a):
    return VT * math.tanh(G * max(a, 0.0) / VT)


def age_at(y):
    c = math.exp(G * max(y, 0.0) / (VT * VT))
    return (VT / G) * math.log(c + math.sqrt(max(c * c - 1.0, 0.0)))


class Clock:
    def __init__(self, length, rate, seed, jitter, mode=0.0, radius=spec.DROP_RADIUS_CM):
        self.length, self.rate, self.seed, self.jitter, self.mode = float(length), float(rate), f32(seed), float(jitter), float(mode)
        self.impact = self.length > 0.0
        L = abs(self.length)
        self.key = hash32(int(saturate(self.seed) * 16777216.0))
        if 0.5 < self.mode < 1.5:
            frac = self.seed * 7.13 - math.floor(self.seed * 7.13)
            self.y0 = min(14.0 + 30.0 * frac, 0.5 * L)
        else:
            self.y0 = 1.6 * radius
        self.tfall = age_at(max(L - self.y0 - radius, 1.0))
        busy = self.tfall + SPLASH
        p1 = max(1.0 / max(self.rate, 1e-3), busy / (SLOTS - 2.0 * MAXJ))
        self.n = SLOTS * max(1, int(math.floor(WRAP / (p1 * SLOTS))))
        self.p = WRAP / self.n
        self.busy = busy
        self.radius = radius

    def rand(self, k, salt):
        kk = ((k % self.n) + self.n) % self.n          # python % is already non-negative; kept for the mirror
        return hash32(((kk * 2654435761) & M32) ^ self.key ^ hash32(salt)) * (1.0 / 4294967296.0)

    def release(self, k):
        return (k + self.seed + saturate(self.jitter) * MAXJ * (2.0 * self.rand(k, 0) - 1.0)) * self.p

    def skipped(self, k):
        return self.rand(k, 1) < SKIPJ * saturate(self.jitter)

    def impact_time(self, k):
        return self.release(k) + self.tfall

    def effective_rate(self):
        return 1.0 / self.p

    def slot_drop(self, t, s):
        m = int(math.floor(t / self.p - self.seed))
        k0 = m - (((m - s) % SLOTS) + SLOTS) % SLOTS
        if self.release(k0 + SLOTS) <= t:
            return k0 + SLOTS
        if self.release(k0) <= t:
            return k0
        return k0 - SLOTS


# ---------------------------------------------------------------- checks
def selftest(n=100000):
    import random
    rnd = random.Random(7)
    worst = {}
    for trial in range(40):
        L = rnd.choice([10.0, 100.0, 350.0, 1050.0, 1200.0, rnd.uniform(20, 3000)])
        rate = math.exp(rnd.uniform(math.log(0.05), math.log(10.0)))
        c = Clock(L, rate, rnd.random(), rnd.random(), 0.0)
        assert c.n % SLOTS == 0 and abs(c.n * c.p - WRAP) < 1e-6, (c.n, c.p)
        assert c.effective_rate() <= rate * (1 + 1e-9) or c.p * rate >= 1 - 1e-9
        last = None
        for k in range(-5, n // 40):
            r = c.release(k)
            if last is not None:
                assert r - last >= c.p * (1 - 0.9 * c.jitter) - 1e-9, ("order", trial, k)
            last = r
            assert c.release(k + SLOTS) >= c.release(k) + c.busy - 1e-9, ("overlap", trial, k)
        assert abs((c.release(c.n - 1) - WRAP) - c.release(-1)) < 1e-6, "wrap"
        # landing: Y0 + DistanceAt(TFall) + R == L
        if L > c.y0 + c.radius + 1.0:
            worst["land"] = max(worst.get("land", 0.0), abs(c.y0 + distance_at(c.tfall) + c.radius - L))
    for a in (0.0, 0.01, 0.3, 1.0, 2.5, 6.0):
        worst["inverse"] = max(worst.get("inverse", 0.0), abs(age_at(distance_at(a)) - a))
    # mean interval and skip rate at Jitter 0.6
    c = Clock(350.0, 0.8, 0.3, 0.6)
    rel = [c.release(k) for k in range(n)]
    gaps = [b - a for a, b in zip(rel, rel[1:])]
    mean = sum(gaps) / len(gaps)
    sd = math.sqrt(sum((g - mean) ** 2 for g in gaps) / len(gaps))
    skips = sum(1 for k in range(n) if c.skipped(k)) / n
    print("SELFTEST land %.2e inverse %.2e mean %.5f (P %.5f) cv %.3f skip %.4f (expect %.4f)"
          % (worst["land"], worst["inverse"], mean, c.p, sd / mean, skips, SKIPJ * 0.6))
    assert worst["land"] < 0.05 and worst["inverse"] < 1e-4
    assert abs(mean - c.p) / c.p < 0.02 and sd / mean > 0.1 and abs(skips - SKIPJ * 0.6) < 0.02
    print("DRIP_REFERENCE_OK")


GOLDEN_STRANDS = ((350.0, 0.8, 0.3, 0.6, 0.0), (100.0, 2.0, 0.71, 0.4, 1.0), (1050.0, 0.5, 0.05, 0.7, 0.0),
                  (1200.0, 1.3, 0.9, 1.0, 0.0), (60.0, 7.0, 0.42, 0.3, 2.0), (-600.0, 0.4, 0.66, 0.8, 0.0),
                  (2500.0, 0.25, 0.123, 0.5, 0.0), (35.0, 4.0, 0.999, 0.2, 1.0))
GOLDEN_KS = (-1, 0, 3, 17, 250)


def golden_rows():
    rows = []
    for (L, rate, seed, jit, mode) in GOLDEN_STRANDS:
        c = Clock(L, rate, seed, jit, mode)
        for k in GOLDEN_KS:
            rows.append((L, rate, f32(seed), jit, mode, k, c.release(k), c.impact_time(k), c.skipped(k), c.p, c.tfall))
    return rows


def print_golden():
    print("// generated by Tools/Blender/mars_water/drip_reference.py --golden (Length, Rate, Seed, Jitter, Mode, K ->"
          " Release, Impact, Skipped, Period, FallSeconds)")
    for r in golden_rows():
        print("        Add_Row(FMars_DripGoldenRow(%.1f, %.4f, %.9f, %.2f, %.1f, %d, %.6f, %.6f, %s, %.9f, %.6f));"
              % (r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], "true" if r[8] else "false", r[9], r[10]))


def predict(L, rate, seed, jitter, t, mode=0.0):
    c = Clock(L, rate, seed, jitter, mode)
    out = []
    for s in range(SLOTS):
        k = c.slot_drop(t, s)
        a = t - c.release(k)
        if c.skipped(k):
            out.append((s, k, "skipped", None))
        elif a < c.tfall:
            out.append((s, k, "falling", c.y0 + distance_at(a)))
        elif a < c.tfall + SPLASH and c.impact:
            out.append((s, k, "splash", abs(L)))
        else:
            out.append((s, k, "idle", None))
    return c, out


def sheet(out_dir):
    from PIL import Image, ImageDraw
    os.makedirs(out_dir, exist_ok=True)
    paths = []
    for (L, rate, seed, jit, mode) in GOLDEN_STRANDS[:5]:
        c = Clock(L, rate, seed, jit, mode)
        w, h = 1200, 400
        img = Image.new("RGB", (w, h), (12, 12, 16))
        d = ImageDraw.Draw(img)
        span = 12.0
        for px in range(w):
            t = 100.0 + span * px / w
            for s in range(SLOTS):
                k = c.slot_drop(t, s)
                if c.skipped(k):
                    continue
                a = t - c.release(k)
                if a < c.tfall:
                    y = (c.y0 + distance_at(a)) / abs(L) * (h - 20)
                    d.point((px, int(y)), fill=(200, 220, 255))
                elif a < c.tfall + SPLASH and c.impact:
                    d.point((px, h - 18), fill=(255, 160, 80))
        d.text((6, 6), "L %.0f rate %.2f (eff %.2f) seed %.2f jit %.2f mode %d tfall %.2fs" %
               (L, rate, c.effective_rate(), seed, jit, mode, c.tfall), fill=(255, 255, 255))
        p = os.path.join(out_dir, "spacetime_L%d_r%.2f.png" % (int(L), rate))
        img.save(p)
        paths.append(p)
    print("SHEETS", paths)
    return paths


def main(argv):
    if "--selftest" in argv:
        selftest()
    if "--golden" in argv:
        print_golden()
    if "--predict" in argv:
        i = argv.index("--predict")
        L, rate, seed, jit, t = (float(x) for x in argv[i + 1:i + 6])
        c, out = predict(L, rate, seed, jit, t)
        print("P %.6f N %d TFall %.6f Y0 %.4f" % (c.p, c.n, c.tfall, c.y0))
        for row in out:
            print(row)
    if "--sheet" in argv:
        i = argv.index("--sheet")
        out = argv[i + 1] if len(argv) > i + 1 and not argv[i + 1].startswith("--") else spec.REVIEW_DIR
        sheet(out)


if __name__ == "__main__":
    main(sys.argv[1:])
