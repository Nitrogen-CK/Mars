"""Fails on any drift between the three copies of the drip contract (DRIPS_PLAN §3.1, §4.1):

    Shaders/Water/MarsDrip.ush            #define MARS_DRIP_*            (the shader clock)
    Script/.../Mars_DripSchedule.as       const k_* // MARS_DRIP_*      (the AngelScript mirror)
    Script/.../Mars_DripTypes.as          EMars_Drip* slot enums        (who writes which custom-data float)
    water_spec.py                         CONSTANTS, slot orders, PCG packer orders

    python -I check_drip_parity.py        # prints DRIP_PARITY_OK or the mismatches (exit 1)

Run it before every AS test run touching the drips and at commit.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import water_spec as spec  # noqa: E402


def ush_defines(path):
    out = {}
    for m in re.finditer(r"^#define\s+(MARS_DRIP_\w+)\s+([-0-9.eE]+)", open(path).read(), re.M):
        out[m.group(1)] = float(m.group(2))
    return out


def as_mirror(path):
    out = {}
    for m in re.finditer(r"const\s+(?:float|int32)\s+k_\w+\s*=\s*([-0-9.eE]+)\s*;\s*//\s*(MARS_DRIP_\w+)", open(path).read()):
        out[m.group(2)] = float(m.group(1))
    return out


def as_enums(path):
    text = open(path).read()
    out = {}
    for m in re.finditer(r"enum\s+(\w+)\s*\{([^}]*)\}", text):
        body = re.sub(r"//[^\n]*", "", m.group(2))
        out[m.group(1)] = tuple(x.strip() for x in body.split(",") if x.strip())
    return out


def main():
    errors = []
    ush = ush_defines(spec.DRIP_USH)
    mirror = as_mirror(spec.AS_SCHEDULE)
    for name, value in spec.CONSTANTS.items():
        if name not in ush:
            errors.append("%s missing from MarsDrip.ush" % name)
        elif abs(ush[name] - value) > 1e-9:
            errors.append("%s: ush %s != water_spec %s" % (name, ush[name], value))
        if name not in mirror:
            errors.append("%s missing from Mars_DripSchedule.as" % name)
        elif abs(mirror[name] - value) > 1e-9:
            errors.append("%s: AS %s != water_spec %s" % (name, mirror[name], value))
    for name in ush:
        if name not in spec.CONSTANTS:
            errors.append("%s in MarsDrip.ush but not in water_spec.CONSTANTS" % name)

    enums = as_enums(spec.AS_TYPES)
    expected = {
        "EMars_DripMode": spec.DRIP_MODES,
        "EMars_DripSurface": spec.DRIP_SURFACES,
        "EMars_DripSlot": spec.DRIP_SLOTS,
        "EMars_DripCardData": spec.CARD_DATA + ("Count",),
        "EMars_DripRingData": spec.RING_DATA + ("Count",),
        "EMars_PuddleData": spec.PUDDLE_DATA + ("Count",),
        "EMars_StillWaterData": spec.STILLWATER_DATA + ("Count",),
    }
    for enum, order in expected.items():
        if enums.get(enum) != tuple(order):
            errors.append("%s: AS %s != water_spec %s" % (enum, enums.get(enum), order))
    for pack, data in ((spec.PACK_CARD, spec.CARD_DATA), (spec.PACK_RING, spec.RING_DATA), (spec.PACK_PUDDLE, spec.PUDDLE_DATA)):
        if len(pack) != len(data):
            errors.append("packer %s does not cover %s" % (pack, data))
    if spec.PACK_RING[:5] != spec.PACK_CARD[:5]:
        errors.append("ring packer slots 0..4 must equal the drop card's (the ring sync contract)")
    if errors:
        print("\n".join("PARITY " + e for e in errors))
        return 1
    print("DRIP_PARITY_OK (%d constants, %d enums)" % (len(spec.CONSTANTS), len(expected)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
