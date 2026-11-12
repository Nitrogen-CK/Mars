"""Fails on any drift between the steward maw shader and its numpy mirror:

    Shaders/Looks/StewardMaw.ush                       #define MARS_MAW_*, the tooth-row calls, a few literals
    Script/WorldObjects/Steward/Mars_Steward_EntityScript.as   the MarsStewardMaw look's parameter defaults
    Tools/StewardMaw/maw_preview.py                    the module constants that mirror both, and the same calls

    python -I check_maw_parity.py        # prints MAW_PARITY_OK or the mismatches (exit 1)

Run it after changing either file, and at commit. It reads all three as text; it never imports maw_preview.py (that
loads numpy, Pillow and the eye atlas at import).

What it compares:
  - every MARS_MAW_* define against the preview constant of the same name without the prefix (MARS_MAW_OUTLINE against
    the local `outline` in maw()), both ways: a define with no mirror, or a mirror with no define, is a failure;
  - the look's defaults against the preview's "look parameters": AtlasCols/Rows, RestCell, EvilCell, EyeSize,
    EyeSpread, EyeHeight, MouthHeight, MouthWidth, GlowStrength, CellPad, Color, FireColor, FleshColor;
  - the four tooth-row calls (back upper, back lower, front upper, front lower, in that order): which count and length
    define each row takes, its offset and its seed;
  - the literals listed in LITERALS below: the tooth stain colour, the throat's tint and falloff, the strands' place
    and hash seeds, and the shudder's noise rates.

What it cannot check:
  - the shape of any formula: a sign, an operator, the order of the steps, a clamp (saturate) present in one copy
    and not the other. Two copies can share every number and still draw different faces; look at a preview sheet.
  - the literals not in LITERALS (most of the eye fire's numbers among them);
  - the stand-ins the preview uses on purpose: the pixel size (2 / width / zoom against fwidth), the eye edge
    (a fixed ramp against CkUsf_SdfEdgeAA), the hash and noise (its own hash21 / vnoise / fbm against CkUsf's),
    the atlas sampling, and what the preview leaves out (Span, Veil, the exposure divide) or adds (bloom, tone curve);
  - the order of the look's parameters against the .ush signature (the generator passes them positionally).
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
USH = os.path.join(ROOT, "Shaders", "Looks", "StewardMaw.ush")
LOOK = os.path.join(ROOT, "Script", "WorldObjects", "Steward", "Mars_Steward_EntityScript.as")
PREVIEW = os.path.join(HERE, "maw_preview.py")

NUM = r"[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?"

# Look parameter -> the preview constant that mirrors its default.
DEFAULTS = {
    "AtlasCols": "COLS", "AtlasRows": "ROWS", "RestCell": "REST_CELL", "EvilCell": "EVIL_CELL",
    "EyeSize": "EYE_SIZE", "EyeSpread": "EYE_SPREAD", "EyeHeight": "EYE_HEIGHT",
    "MouthHeight": "MOUTH_HEIGHT", "MouthWidth": "MOUTH_WIDTH", "GlowStrength": "GLOW", "CellPad": "PAD",
    "Color": "COLOR", "FireColor": "FIRE", "FleshColor": "FLESH",
}

# Literals with no name in either file: (what, regex over the .ush, regex over the preview). Each regex's groups are
# the numbers compared, in order.
LITERALS = [
    ("tooth stain colour",
     r"Stain\s*=\s*float3\((%s)f?,\s*(%s)f?,\s*(%s)f?\)" % (NUM, NUM, NUM),
     r"stain\s*=\s*np\.array\(\[(%s),\s*(%s),\s*(%s)\]\)" % (NUM, NUM, NUM)),
    ("throat tint and falloff",
     r"FleshColor\s*\*\s*(%s)f?\s*\*\s*exp\(-Depth\s*/\s*(%s)f?\)" % (NUM, NUM),
     r"FLESH\[:, None, None\]\s*\*\s*(%s)\s*\*\s*np\.exp\(-np\.maximum\(depth, 0\.0\)\s*/\s*(%s)\)" % (NUM, NUM)),
    ("strand hash seeds",
     r"Hash21\(float2\(J \+ 1\.0f, (%s)f?\)\).*?Hash21\(float2\(J \+ 1\.0f, (%s)f?\)\)" % (NUM, NUM),
     r"hash21\(j \+ 1\.0, (%s)\).*?hash21\(j \+ 1\.0, (%s)\)" % (NUM, NUM)),
    ("strand placement",
     r"At\s*=\s*(%s)f?\s*\+\s*(%s)f?\s*\*" % (NUM, NUM),
     r"xj\s*=\s*(%s)\s*\+\s*(%s)\s*\*" % (NUM, NUM)),
    ("shudder noise rates",
     r"ValueNoise\(float2\(Time \* (%s)f?, (%s)f?\)\).*?ValueNoise\(float2\(Time \* (%s)f?, (%s)f?\)\)" % (NUM, NUM, NUM, NUM),
     r"vnoise\(time \* (%s), (%s)\).*?vnoise\(time \* (%s), (%s)\)" % (NUM, NUM, NUM, NUM)),
]

ROWS = ("back upper", "back lower", "front upper", "front lower")


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def num(s):
    return float(s.rstrip("fF"))


def ush_defines(text):
    out = {}
    for m in re.finditer(r"^#define\s+MARS_MAW_(\w+)\s+(%sf?)\s*$" % NUM, text, re.M):
        out[m.group(1)] = num(m.group(2))
    return out


def preview_constants(text):
    """Module-level NAME = value and NAME, NAME = value, value lines, plus np.array([...]) vectors."""
    out = {}
    for line in text.splitlines():
        m = re.match(r"^([A-Z_][A-Z0-9_]*(?:\s*,\s*[A-Z_][A-Z0-9_]*)*)\s*=\s*(.+?)\s*(?:#.*)?$", line)
        if not m:
            continue
        names = [n.strip() for n in m.group(1).split(",")]
        rhs = m.group(2)
        vec = re.match(r"^np\.array\(\[(.*)\]\)$", rhs)
        if vec and len(names) == 1:
            out[names[0]] = tuple(num(v.strip()) for v in vec.group(1).split(","))
            continue
        values = [v.strip() for v in rhs.split(",")]
        if len(values) == len(names) and all(re.fullmatch(NUM, v) for v in values):
            for n, v in zip(names, values):
                out[n] = num(v)
    m = re.search(r"^\s+outline\s*=\s*(%s)\s*$" % NUM, text, re.M)
    if m:
        out["OUTLINE"] = num(m.group(1))
    return out


def look_defaults(text):
    out = {}
    for m in re.finditer(r"(\w+)\._DefaultScalar\s*=\s*(%sf?)\s*;" % NUM, text):
        out[m.group(1)] = num(m.group(2))
    for m in re.finditer(r"(\w+)\._DefaultVector\s*=\s*FLinearColor\(([^)]*)\)\s*;", text):
        out[m.group(1)] = tuple(num(v.strip()) for v in m.group(2).split(","))[:3]  # the look reads .rgb
    return out


def ush_rows(text):
    pat = r"Mars_Maw_ToothRow\([^,]+,[^,]+,\s*float3\(MARS_MAW_(\w+),\s*(%s)f?,\s*MARS_MAW_(\w+)\),\s*(%s)f?," % (NUM, NUM)
    return [(m.group(1), num(m.group(2)), m.group(3), num(m.group(4))) for m in re.finditer(pat, text)]


def preview_rows(text):
    pat = r"=\s*tooth_row\([^,]+,[^,]+,\s*([A-Z_]+),\s*(%s),\s*([A-Z_]+),\s*(%s)," % (NUM, NUM)
    return [(m.group(1), num(m.group(2)), m.group(3), num(m.group(4))) for m in re.finditer(pat, text)]


def same(a, b):
    if isinstance(a, tuple) or isinstance(b, tuple):
        return isinstance(a, tuple) and isinstance(b, tuple) and len(a) == len(b) and all(abs(x - y) <= 1e-6 for x, y in zip(a, b))
    return abs(a - b) <= 1e-6


def main():
    ush, look, preview = read(USH), read(LOOK), read(PREVIEW)
    errors = []

    defines = ush_defines(ush)
    mirror = preview_constants(preview)
    for name, value in sorted(defines.items()):
        if name not in mirror:
            errors.append("MARS_MAW_%s has no %s in maw_preview.py" % (name, name))
        elif not same(value, mirror[name]):
            errors.append("MARS_MAW_%s: ush %s != preview %s %s" % (name, value, name, mirror[name]))
    block = re.search(r"^# the \.ush defines\n(.*?)\n\n", preview, re.M | re.S)
    if not block:
        errors.append("maw_preview.py: the '# the .ush defines' block was not found")
    else:
        for name in sorted(preview_constants(block.group(1))):
            if name not in defines:
                errors.append("preview %s is under '# the .ush defines' but StewardMaw.ush has no MARS_MAW_%s" % (name, name))

    defaults = look_defaults(look)
    for param, const in DEFAULTS.items():
        if param not in defaults:
            errors.append("%s has no default in Mars_Steward_EntityScript.as" % param)
        elif const not in mirror:
            errors.append("%s has no %s in maw_preview.py" % (param, const))
        elif not same(defaults[param], mirror[const]):
            errors.append("%s: look default %s != preview %s %s" % (param, defaults[param], const, mirror[const]))

    rows_u, rows_p = ush_rows(ush), preview_rows(preview)
    if len(rows_u) != len(ROWS) or len(rows_p) != len(ROWS):
        errors.append("tooth rows: %d calls in the ush, %d in the preview, expected %d" % (len(rows_u), len(rows_p), len(ROWS)))
    for what, u, p in zip(ROWS, rows_u, rows_p):
        if u[0] != p[0] or u[2] != p[2] or not same(u[1], p[1]) or not same(u[3], p[3]):
            errors.append("%s tooth row: ush (%s, %s, %s, seed %s) != preview (%s, %s, %s, seed %s)" % ((what,) + u + p))

    for what, pat_u, pat_p in LITERALS:
        mu, mp = re.search(pat_u, ush, re.S), re.search(pat_p, preview, re.S)
        if not mu or not mp:
            errors.append("%s: not found in %s" % (what, "the ush" if not mu else "the preview"))
            continue
        vu, vp = tuple(num(g) for g in mu.groups()), tuple(num(g) for g in mp.groups())
        if not same(vu, vp):
            errors.append("%s: ush %s != preview %s" % (what, vu, vp))

    if errors:
        print("\n".join("PARITY " + e for e in errors))
        return 1
    print("MAW_PARITY_OK (%d defines, %d look defaults, %d tooth rows, %d literals)" % (len(defines), len(DEFAULTS), len(rows_u), len(LITERALS)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
