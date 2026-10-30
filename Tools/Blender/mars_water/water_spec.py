"""Single source of truth for the Mars drips / droplets / puddles / wet-surface system (Tools/Environment/DRIPS_PLAN.md).

Plain Python (no unreal, no bpy). Read by drip_reference.py, check_drip_parity.py and the editor modules
unreal/mars_water_ue.py (materials, meshes, phys mat), unreal/mars_water_pcg.py (PCG volume graphs) and
unreal/mars_water_review.py (WaterLookdev_Mars_MAP + frozen-time captures).

The slot-name orders below MUST equal the AngelScript enums in Script/WorldObjects/Dressing/Water/Mars_DripTypes.as and
the PCG packer selector orders (check_drip_parity.py diffs all three).
"""
import os

# ---------------------------------------------------------------- locations
REPO = r"D:\Repo\Mars"
SHADER_DIR = os.path.join(REPO, "Shaders", "Water")             # virtual /Project/Water
DRIP_USH = os.path.join(SHADER_DIR, "MarsDrip.ush")
WET_USH = os.path.join(SHADER_DIR, "MarsWet.ush")
WET_INCLUDE = "/Project/Water/MarsWet.ush"
AS_DIR = os.path.join(REPO, "Script", "WorldObjects", "Dressing", "Water")
AS_SCHEDULE = os.path.join(AS_DIR, "Mars_DripSchedule.as")
AS_TYPES = os.path.join(AS_DIR, "Mars_DripTypes.as")
REVIEW_DIR = r"D:\Repo\Content\Water\export\review"

UE_ROOT = "/Game/Mars/Environment/Dressing/Water"
F_MESH = UE_ROOT + "/Meshes"
F_MAT = UE_ROOT + "/Materials"
F_PCG = UE_ROOT + "/PCG"
PHYSMAT_FOLDER = "/Game/Mars/Physics"
PHYSMAT = "Water_Mars_PhysMat"
PHYSMAT_SOURCE = "/Game/Mars/Physics/Mud_Mars_PhysMat"
PHYSMAT_PATH = "%s/%s.%s" % (PHYSMAT_FOLDER, PHYSMAT, PHYSMAT)
LOOKDEV_MAP = "/Game/Mars/Maps/WaterLookdev_Mars_MAP"

# ---------------------------------------------------------------- meshes (all duplicates of the engine Plane)
PLANE = "/Engine/BasicShapes/Plane"
MESHES = {
    # name: (positive bounds extension, negative bounds extension) in local cm (the Plane is 100 x 100 in XY)
    "DropletCard_Mars_SM": ((60.0, 60.0, 100.0), (60.0, 60.0, 10.0)),
    "WetDecalCard_Mars_SM": ((0.0, 0.0, 2.0), (0.0, 0.0, 2.0)),
    "StillWater_Mars_SM": ((0.0, 0.0, 2.0), (0.0, 0.0, 2.0)),
}

# ---------------------------------------------------------------- shared constants (MarsDrip.ush #defines)
CONSTANTS = {
    "MARS_DRIP_GRAVITY": 980.0,
    "MARS_DRIP_TERMINAL": 750.0,
    "MARS_DRIP_MAX_JITTER": 0.45,
    "MARS_DRIP_SKIP_PER_JITTER": 0.25,
    "MARS_DRIP_SLOTS": 4,
    "MARS_DRIP_WRAP": 3600.0,
    "MARS_DRIP_SPLASH_S": 0.28,
    "MARS_DRIP_CROWN_S": 0.16,
    "MARS_DRIP_RING_SPEED": 22.0,
    "MARS_DRIP_RING_LIFE": 1.4,
    "MARS_DRIP_RING_LAMBDA": 2.4,
}
DROP_RADIUS_CM = 0.45

# ---------------------------------------------------------------- slot contracts (= AS enums = packer orders)
DRIP_MODES = ("Drops", "DropsWithThread", "Stream", "HangingBead", "SittingBead")
DRIP_SURFACES = ("Floor", "Water", "Dry", "Air")
DRIP_SLOTS = ("Drop0", "Drop1", "Drop2", "Drop3", "Bead", "Thread")
CARD_DATA = ("Length", "Rate", "Seed", "Jitter", "Mode", "Slot", "DropScale", "Surface")
RING_DATA = ("Length", "Rate", "Seed", "Jitter", "Mode", "RingAmp")
PUDDLE_DATA = ("Seed", "Wetness", "RainRate", "Aspect")
STILLWATER_DATA = ("SizeX", "SizeY", "Seed", "Murk", "RainRate")

# PCG attribute names packed in the order above (Length is the engine's ImpactDistance)
PACK_CARD = ("ImpactDistance", "DripRate", "DripSeed", "DripJitter", "DripMode", "DripSlot", "DropScale", "DripSurface")
PACK_RING = ("ImpactDistance", "DripRate", "DripSeed", "DripJitter", "DripMode", "RingAmp")
PACK_PUDDLE = ("PuddleSeed", "PuddleWetness", "RainRate", "PuddleAspect")

# ---------------------------------------------------------------- materials
MASTERS = ("Droplet_Mars_M", "DripImpact_Mars_M", "DripRingCard_Mars_M", "PuddleWet_Mars_M", "PuddleGloss_Mars_M", "WetStreak_Mars_M",
           "StillWater_Mars_M", "StillWaterDeep_Mars_M")
# instance -> (parent, {scalar overrides}, {vector overrides}, {static switch overrides})
INSTANCES = {
    "Droplet_Mars_MI": ("Droplet_Mars_M", {}, {}, {}),
    "DropletRust_Mars_MI": ("Droplet_Mars_M", {"Transmission": 0.7}, {"WaterTint": (0.75, 0.55, 0.40, 1.0),
                                                                       "BodyTint": (0.05, 0.03, 0.015, 1.0)}, {}),
    "DropletMurk_Mars_MI": ("Droplet_Mars_M", {"Transmission": 0.6}, {"WaterTint": (0.55, 0.6, 0.45, 1.0),
                                                                       "BodyTint": (0.03, 0.035, 0.02, 1.0)}, {}),
    "DripImpact_Mars_MI": ("DripImpact_Mars_M", {}, {}, {}),
    "DripRingCard_Mars_MI": ("DripRingCard_Mars_M", {}, {}, {}),
    "PuddleWet_Mars_MI": ("PuddleWet_Mars_M", {}, {}, {}),
    "PuddleWetSewer_Mars_MI": ("PuddleWet_Mars_M", {"RimDarken": 0.5}, {"WaterTint": (0.02, 0.03, 0.015, 1.0)}, {}),
    "PuddleGloss_Mars_MI": ("PuddleGloss_Mars_M", {}, {}, {}),
    "PuddleGlossRain_Mars_MI": ("PuddleGloss_Mars_M", {}, {}, {"RainRipples": True}),
    "WetStreakDamp_Mars_MI": ("WetStreak_Mars_M", {}, {"MineralTint": (0.5, 0.48, 0.42, 1.0)}, {}),
    "WetStreakRust_Mars_MI": ("WetStreak_Mars_M", {}, {"MineralTint": (0.09, 0.04, 0.015, 1.0)}, {}),
    "StillWaterBasin_Mars_MI": ("StillWater_Mars_M", {}, {}, {}),
    # 2026-10-24 (vignettes): the moss-black defaults read as a hole in concept 5's blue cistern; a navy body that keeps
    # blue longest, a glossier surface reflecting the cold crypt cubemap, less of the floor shown through.
    "StillWaterCistern_Mars_MI": ("StillWaterDeep_Mars_M", {"Roughness": 0.04, "Specular": 0.5, "ColorScaleBehindWater": 0.35},
                                  {"DeepColour": (0.004, 0.008, 0.018, 1.0), "EdgeColour": (0.012, 0.022, 0.035, 1.0),
                                   "Absorption": (0.05, 0.02, 0.011, 1.0), "Scattering": (0.0008, 0.0016, 0.0032, 1.0)}, {}),
}
# PS / VS instruction budgets (DRIPS_PLAN §8); the builder logs the measured counts against these
BUDGETS = {"Droplet_Mars_M": (260, 320), "DripImpact_Mars_M": (200, None), "PuddleWet_Mars_M": (90, None),
           "PuddleGloss_Mars_M": (200, None), "StillWater_Mars_M": (180, None)}

# ---------------------------------------------------------------- presets (EMars_DripPreset; the PCG volumes bake these)
PRESETS = {
    "CisternDrip": dict(layout="Cluster", count=6, radius=120.0, rate=(0.25, 0.9), jitter=0.6, mode="Drops",
                        puddle=(40.0, 110.0), wetness=0.85, streak=None),
    "VaultLine": dict(layout="Line", count=8, line=600.0, rate=(0.3, 1.0), jitter=0.7, mode="Drops",
                      puddle=(35.0, 80.0), wetness=0.8, streak=None),
    "PipeJoint": dict(layout="Single", count=1, rate=(1.5, 2.5), jitter=0.4, mode="DropsWithThread", puddle=None,
                      wetness=0.85, streak="Rust"),
    "PipeTrickle": dict(layout="Single", count=1, rate=(6.0, 9.0), jitter=0.3, mode="Stream", puddle=None,
                        wetness=0.85, streak="Rust"),
    "OssuarySeep": dict(layout="Cluster", count=3, radius=40.0, rate=(0.08, 0.2), jitter=0.8, mode="Drops",
                        puddle=(35.0, 75.0), wetness=0.8, streak="Damp"),   # 2026-10-24: was 20-40 cm, 0.5
    "Beads": dict(layout="Cluster", count=12, radius=30.0, rate=(0.0, 0.0), jitter=0.0, mode="HangingBead",
                  puddle=None, wetness=0.0, streak=None),
}

# PCG volume presets (graph name suffix -> numbers baked into the graph)
VOLUME_PRESETS = {
    "Cistern": dict(spacing=120.0, coverage=0.45, rate=(0.25, 0.9), jitter=0.6, thread=0.1, puddle_chance=0.6,
                    puddle_scale=(0.4, 1.1), wetness=(0.7, 0.9), rain=0.0, min_length=60.0, ring_amp=1.0),
    "Sewer": dict(spacing=150.0, coverage=0.25, rate=(0.3, 1.2), jitter=0.5, thread=0.35, puddle_chance=0.8,
                  puddle_scale=(0.5, 1.4), wetness=(0.75, 0.95), rain=0.0, min_length=60.0, ring_amp=1.0),
    "Ossuary": dict(spacing=160.0, coverage=0.15, rate=(0.08, 0.2), jitter=0.8, thread=0.0, puddle_chance=0.5,
                    puddle_scale=(0.2, 0.45), wetness=(0.4, 0.6), rain=0.0, min_length=60.0, ring_amp=0.8),
    "Atrium": dict(spacing=200.0, coverage=0.3, rate=(0.2, 0.6), jitter=0.7, thread=0.0, puddle_chance=0.4,
                   puddle_scale=(0.5, 1.2), wetness=(0.6, 0.85), rain=0.0, min_length=60.0, ring_amp=1.0),
}


def graph_name(preset):
    return "DripVolume_%s_Mars_PCG" % preset
