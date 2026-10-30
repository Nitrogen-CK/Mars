"""WaterLookdev_Mars_MAP: three bays built from the crypt kit to judge the drips / puddles / wet-surface system
(DRIPS_PLAN §9.3) against the concept frames, plus frozen-time captures and the automated timing / ring-sync probes.

    Bay A  sewer   x 0..800      kit walls + pavers + roof (3.5 m), a pipe run (engine cylinders) into the kit's ladle
                                 spout, a stone basin (kit blocks) holding AMars_StillWater (opaque basin MI), a pipe-joint
                                 leak with a rust streak into the basin, a vault line of drips onto the flagstones, loose
                                 puddles, a damp streak, a warm torch and a cold lantern.
    Bay B  cistern x 1200..2000  7 m vault, the floor sunk to -150, Single Layer Water at -20 (StillWaterCistern_Mars_MI),
                                 a block causeway down the middle, piers, two cistern drip clusters hanging from the vault
                                 and landing as rings on the water, a candle-warm key and a cold back light.
    Bay C  ossuary x 2400..3200  CryptWallOssuary4m back wall, a slow ossuary seep with damp streaks and small puddles.
    Probe  x 6000                an isolated strand in front of a bright emissive board (timing parity) and a strand
                                 onto a floor seen from above (ring sync).

Each bay gets a Box Reflection Capture fitted to it (no SSR / Lumen in Mars: captures are the only reflections) and
lamps with SourceRadius >= 8 cm. PCG volumes (mars_water_pcg) are placed by place_pcg_volumes() after the bays.

Driven through env_drive.py on a hidden editor of its own (never 9316 while Stephen works):

    python Tools/Blender/mars_environment/unreal/env_drive.py --port 9318 --py "import sys; sys.path.insert(0, \\
        r'D:\\Repo\\Mars\\Tools\\Blender\\mars_water\\unreal'); import mars_water_review as wr; wr.build_map()"
    ... wr.capture()                    # a later call: the reflection captures need a tick
    ... wr.frozen_sheets()              # t = 10.000 .. 11.500 in 0.125 s steps per bay, contact sheets
    ... wr.timing_probe()               # WATER_TIMING_OK
"""
import importlib
import json
import math
import os
import sys

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
WATER_DIR = os.path.dirname(HERE)
for _p in (HERE, WATER_DIR):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import water_spec as spec  # noqa: E402
import drip_reference as ref  # noqa: E402

MAP = spec.LOOKDEV_MAP
FOLDER = "WaterLookdev"
KIT = "/Game/Mars/Environment/Meshes"
OUT_DIR = os.path.join(spec.REVIEW_DIR, "ue")
LOOK = {"exposure_bias": 9.7, "lamp_cd": 320 * 0.08 * 2.4 * 0.3, "ambient": 0.08, "fog_density": 0.02}
LOOKDEV_FOLDER = spec.UE_ROOT + "/Lookdev"
WARM = (1.0, 0.55, 0.25)
COLD = (0.35, 0.65, 1.0)
BAY_X = {"sewer": 0.0, "cistern": 1200.0, "ossuary": 2400.0}
PROBE_X = 6000.0
DIST = 700.0          # timing probe camera distance (cm)

SHOTS = {
    # name: (eye, target, fov)
    "sewer": ((420.0, 760.0, 175.0), (470.0, 60.0, 110.0), 70.0),
    "sewer_basin": ((470.0, 330.0, 150.0), (520.0, 95.0, 50.0), 55.0),
    "sewer_floor": ((250.0, 760.0, 60.0), (330.0, 300.0, 0.0), 60.0),
    "cistern": ((1600.0, 780.0, 160.0), (1600.0, 120.0, 150.0), 75.0),
    "cistern_rings": ((1420.0, 560.0, 90.0), (1370.0, 330.0, -20.0), 50.0),
    "cistern_up": ((1350.0, 330.0, 20.0), (1351.0, 331.0, 700.0), 80.0),
    "ossuary": ((2800.0, 700.0, 170.0), (2800.0, 40.0, 140.0), 70.0),
    "ossuary_seep": ((2700.0, 420.0, 90.0), (2820.0, 90.0, 10.0), 60.0),
}


def _eas():
    return unreal.get_editor_subsystem(unreal.EditorActorSubsystem)


def _world():
    return unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()


def _load(path):
    if unreal.EditorAssetLibrary.does_asset_exist(path):
        return unreal.EditorAssetLibrary.load_asset(path)
    return None


def _kit(name):
    """'Wall4m' -> Crypt/CryptWall4m_Mars_SM; 'Boxes/BoxStoneBlock1m' -> Boxes/BoxStoneBlock1m_Mars_SM."""
    if "/" in name:
        return _load("%s/%s_Mars_SM" % (KIT, name))
    return _load("%s/Crypt/Crypt%s_Mars_SM" % (KIT, name))


def _spawn(obj, loc, yaw=0.0, label=None, folder=FOLDER, scale=None, pitch=0.0, roll=0.0):
    rot = unreal.Rotator(roll=roll, pitch=pitch, yaw=yaw)
    if isinstance(obj, type) or isinstance(obj, unreal.Class):
        a = _eas().spawn_actor_from_class(obj, unreal.Vector(*loc), rot)
    else:
        a = _eas().spawn_actor_from_object(obj, unreal.Vector(*loc), rot)
    if label:
        a.set_actor_label(label)
    a.set_folder_path(folder)
    if scale is not None:
        a.set_actor_scale3d(unreal.Vector(*scale))
    return a


def _class(name):
    return unreal.load_class(None, "/Script/Angelscript.%s" % name)


def _set_struct(actor, prop, **fields):
    """Script structs reach Python as generic StructBase: fields go by their C++ (CamelCase) names."""
    s = actor.get_editor_property(prop)
    for k, v in fields.items():
        name = "".join(w[:1].upper() + w[1:] for w in k.split("_")).replace("Cm", "Cm")
        s.set_editor_property(name, v)
    actor.set_editor_property(prop, s)


def _enum(obj, prop, member):
    """An AngelScript enum value, through the type of the property that holds it (script enums are not module
    attributes of unreal)."""
    return getattr(type(obj.get_editor_property(prop)), _upper(member))


def _upper(member):
    out = ""
    for i, ch in enumerate(member):
        if ch.isupper() and i and not member[i - 1].isupper():
            out += "_"
        out += ch.upper()
    return out


def _material(actor, mat):
    comp = actor.get_component_by_class(unreal.StaticMeshComponent)
    comp.set_material(0, mat)


def _lookdev_mi(name, tint, roughness=0.45):
    """A lookdev-only stand-in on Accent_Mars_M for the engine-cylinder pipes (the dressing kit's PipeSpout_A / Pipe_*
    meshes replace them once mars_env_ue imports them)."""
    mel = unreal.MaterialEditingLibrary
    path = "%s/%s" % (LOOKDEV_FOLDER, name)
    mi = _load(path)
    if mi is None:
        mi = unreal.AssetToolsHelpers.get_asset_tools().create_asset(name, LOOKDEV_FOLDER, unreal.MaterialInstanceConstant,
                                                                     unreal.MaterialInstanceConstantFactoryNew())
    mel.set_material_instance_parent(mi, _load("/Game/Mars/Gameplay/Cooking/Food/Materials/Accent_Mars_M"))
    mel.set_material_instance_vector_parameter_value(mi, "Tint", unreal.LinearColor(tint[0], tint[1], tint[2], 1.0))
    mel.set_material_instance_scalar_parameter_value(mi, "Roughness", roughness)
    mel.update_material_instance(mi)
    unreal.EditorAssetLibrary.save_loaded_asset(mi)
    return mi


# ------------------------------------------------------------------ shells
def _shell(ox, folder, storeys=1, back="Wall4m", depth_rows=2, floor_z=0.0, floor="FloorPavers4x4"):
    """Floor (two 4 m modules wide, depth_rows deep), back / side walls (storeys high), roof on top."""
    fl, wall, back_wall, roof = _kit(floor), _kit("Wall4m"), _kit(back), _kit("Roof4x4")
    for i in range(2):
        for j in range(1, depth_rows + 1):
            _spawn(fl, (ox + 400.0 * i, 400.0 * j, floor_z), 0.0, None, folder + "/Floor")
            _spawn(roof, (ox + 400.0 * i, 400.0 * j, 350.0 * (storeys - 1)), 0.0, None, folder + "/Roof")
    for s in range(storeys):
        z = 350.0 * s
        for i in range(2):
            _spawn(back_wall if s == 0 else wall, (ox + 400.0 * i, 0.0, z), 0.0, None, folder + "/Walls")
        for j in range(1, depth_rows + 1):
            _spawn(wall, (ox, 400.0 * j, z), -90.0, None, folder + "/Walls")
            _spawn(wall, (ox + 800.0, 400.0 * (j - 1), z), 90.0, None, folder + "/Walls")
        if floor_z < 0.0 and s == 0:
            for i in range(2):                       # the sunk floor needs walls below 0 too
                _spawn(back_wall, (ox + 400.0 * i, 0.0, floor_z), 0.0, None, folder + "/Walls")
            for j in range(1, depth_rows + 1):
                _spawn(wall, (ox, 400.0 * j, floor_z), -90.0, None, folder + "/Walls")
                _spawn(wall, (ox + 800.0, 400.0 * (j - 1), floor_z), 90.0, None, folder + "/Walls")


def _lamp(loc, color, cd, folder, radius=900.0, source=8.0, label=None):
    a = _spawn(unreal.PointLight, loc, 0.0, label, folder + "/Lights")
    c = a.point_light_component
    c.set_editor_property("intensity", cd)
    c.set_editor_property("light_color", unreal.Color(r=int(255 * color[0]), g=int(255 * color[1]), b=int(255 * color[2]), a=255))
    c.set_editor_property("attenuation_radius", radius)
    c.set_editor_property("source_radius", source)
    c.set_editor_property("cast_shadows", True)
    return a


def _capture_box(ox, folder, z0=-200.0, z1=700.0, kind="warm"):
    a = _spawn(unreal.BoxReflectionCapture, (ox + 400.0, 400.0, (z0 + z1) * 0.5), 0.0, "Reflections", folder)
    # a box capture's influence box is a UNIT box times the actor scale (cm), minus box_transition_distance: scale is
    # the half extent in cm, not metres (4.2 made a 4 cm box with no influence at all, so nothing reflected)
    a.set_actor_scale3d(unreal.Vector(420.0, 420.0, (z1 - z0) * 0.5))
    comp = a.get_component_by_class(unreal.BoxReflectionCaptureComponent)
    comp.set_editor_property("box_transition_distance", 40.0)
    _env_ue().set_reflection(a, kind)       # authored crypt cubemap: reflects without a capture build (see build_env_hdr)
    return a


def _env_ue():
    env_ue = os.path.join(os.path.dirname(os.path.dirname(WATER_DIR)), "mars_environment", "unreal")
    if env_ue not in sys.path:
        sys.path.insert(0, env_ue)
    import mars_env_ue
    return mars_env_ue


def _leak(loc, preset, folder, label, yaw=0.0, **props):
    a = _spawn(_class("Mars_DripLeak"), loc, yaw, label, folder + "/Drips")
    a.set_editor_property("preset", _enum(a, "preset", preset))
    a.call_method("ApplyPreset")
    for prop, fields in props.items():
        if isinstance(fields, dict):
            _set_struct(a, prop, **fields)
        else:
            a.set_editor_property("".join(w[:1].upper() + w[1:] for w in prop.split("_")), fields)
    a.call_method("Rebuild")
    return a


def _block(loc, size, folder, yaw=0.0, mesh="BoxStoneBlock1m"):
    """A kit stone block scaled to size (cm), pivot at its base centre."""
    m = _kit("Boxes/" + mesh)
    b = m.get_bounding_box()
    ext = (b.max.x - b.min.x, b.max.y - b.min.y, b.max.z - b.min.z)
    return _spawn(m, loc, yaw, None, folder, scale=(size[0] / ext[0], size[1] / ext[1], size[2] / ext[2]))


# ------------------------------------------------------------------ bays
def _bay_sewer():
    ox, f = BAY_X["sewer"], FOLDER + "/Sewer"
    _shell(ox, f)
    cyl = _load("/Engine/BasicShapes/Cylinder")
    iron = _lookdev_mi("LookdevIron_Mars_MI", (0.035, 0.022, 0.016))
    copper = _lookdev_mi("LookdevRust_Mars_MI", (0.08, 0.035, 0.018))
    # a horizontal pipe along the back wall, a drop pipe down to the spout, collars
    p = _spawn(cyl, (ox + 330.0, 34.0, 250.0), 0.0, "Pipe_Run", f + "/Pipes", scale=(0.36, 0.36, 6.6), pitch=90.0)
    _material(p, iron)
    d = _spawn(cyl, (ox + 520.0, 34.0, 205.0), 0.0, "Pipe_Drop", f + "/Pipes", scale=(0.3, 0.3, 0.9))
    _material(d, copper or iron)
    for x in (ox + 120.0, ox + 520.0):
        c = _spawn(cyl, (x, 34.0, 250.0), 0.0, "Pipe_Collar", f + "/Pipes", scale=(0.46, 0.46, 0.14), pitch=90.0)
        _material(c, iron)
    _spawn(_kit("SpoutLadle"), (ox + 520.0, 2.0, 150.0), 0.0, "Spout", f + "/Pipes")
    # the basin: four kit blocks round a 180 x 90 water surface, water line at 45 cm
    _block((ox + 520.0, 42.5, 0.0), (230.0, 15.0, 55.0), f + "/Basin")
    _block((ox + 520.0, 147.5, 0.0), (230.0, 15.0, 55.0), f + "/Basin")
    _block((ox + 412.5, 95.0, 0.0), (15.0, 90.0, 55.0), f + "/Basin")
    _block((ox + 627.5, 95.0, 0.0), (15.0, 90.0, 55.0), f + "/Basin")
    water = _spawn(_class("Mars_StillWater"), (ox + 520.0, 95.0, 45.0), 0.0, "Basin_Water", f + "/Basin")
    water.set_editor_property("size", unreal.Vector2D(200.0, 90.0))
    water.set_editor_property("murk", 0.35)
    water.call_method("Rebuild")
    # the pipe joint over the basin (+X out of the wall: yaw 90), its rust streak down the wall behind
    _leak((ox + 520.0, 62.0, 130.0), "PipeJoint", f, "Leak_PipeJoint", yaw=90.0,
          trace={"attach_up": False}, timing={"rate_min": 1.2, "rate_max": 1.6, "jitter": 0.4},
          look={"drop_material": _load(spec.F_MAT + "/DropletRust_Mars_MI")})
    # a vault line dripping onto the flagstones, a loose puddle cluster in front, a damp streak on the left wall
    _leak((ox + 380.0, 470.0, 300.0), "VaultLine", f, "Leak_VaultLine", count=5, line_length=520.0, seed=4)
    pud = _spawn(_class("Mars_Puddle"), (ox + 300.0, 620.0, 40.0), 0.0, "Puddles", f + "/Drips")
    pud.set_editor_property("count", 5)
    pud.set_editor_property("radius", 200.0)
    pud.call_method("Rebuild")
    st = _spawn(_class("Mars_WetStreak"), (ox + 30.0, 300.0, 300.0), 0.0, "Streak_Left", f + "/Drips")
    _set_struct(st, "streak", dampness=0.55, flow=20.0, width_cm=60.0)
    st.call_method("Rebuild")
    # light: a warm torch on the left wall, a cold lantern on the back wall beside the spout (its reflection sits in the
    # basin water, like the concept), a warm lamp over the front floor so the puddles catch it
    _lamp((ox + 60.0, 260.0, 220.0), WARM, 40.0, f, radius=900.0, source=10.0, label="Torch")
    _lamp((ox + 380.0, 40.0, 120.0), COLD, 30.0, f, radius=600.0, source=10.0, label="Lantern")
    # placed where the basin close-up camera sees its mirror image in the water, around the drip's impact
    _lamp((ox + 532.0, 40.0, 75.0), COLD, 8.0, f, radius=300.0, source=6.0, label="Glint")
    _lamp((ox + 600.0, 560.0, 280.0), WARM, 22.0, f, radius=800.0, source=12.0, label="Fill")
    _lamp((ox + 700.0, 40.0, 250.0), COLD, 12.0, f, radius=500.0, source=8.0, label="BackRight")
    _capture_box(ox, f, -20.0, 360.0)


def _bay_cistern():
    ox, f = BAY_X["cistern"], FOLDER + "/Cistern"
    _shell(ox, f, storeys=2, floor_z=-150.0)
    # a causeway of blocks down the middle, top at 0
    for j in range(4):
        _block((ox + 400.0, 100.0 + 200.0 * j, -150.0), (130.0, 196.0, 150.0), f + "/Causeway", mesh="BoxStoneBlock2m")
    for (x, y) in ((ox + 170.0, 230.0), (ox + 630.0, 230.0), (ox + 170.0, 600.0), (ox + 630.0, 600.0)):
        _spawn(_kit("PierH7m5"), (x, y, -150.0), 0.0, None, f + "/Piers")
    water = _spawn(_class("Mars_StillWater"), (ox + 400.0, 400.0, -20.0), 0.0, "Cistern_Water", f + "/Water")
    water.set_editor_property("size", unreal.Vector2D(800.0, 800.0))
    water.set_editor_property("deep", True)
    water.call_method("Rebuild")
    _leak((ox + 160.0, 360.0, 600.0), "CisternDrip", f, "Leak_CisternA", radius=110.0, seed=2)
    _leak((ox + 640.0, 470.0, 600.0), "CisternDrip", f, "Leak_CisternB", radius=120.0, seed=7, count=5)
    _lamp((ox + 60.0, 700.0, 110.0), WARM, 30.0, f, radius=900.0, source=8.0, label="Candle")
    _lamp((ox + 400.0, 50.0, 220.0), COLD, 45.0, f, radius=1200.0, source=20.0, label="Moon")
    _lamp((ox + 650.0, 650.0, 350.0), WARM, 15.0, f, radius=900.0, source=12.0, label="Fill")
    _lamp((ox + 140.0, 250.0, 450.0), COLD, 15.0, f, radius=700.0, source=12.0, label="HighLeft")
    _lamp((ox + 131.0, 150.0, 66.0), COLD, 12.0, f, radius=500.0, source=15.0, label="Glint")
    # mirrored for the wide cistern camera: their images sit in the water among the strands
    _lamp((ox + 133.0, 104.0, 120.0), COLD, 14.0, f, radius=600.0, source=18.0, label="GlintLeft")
    _lamp((ox + 667.0, 193.0, 120.0), WARM, 10.0, f, radius=600.0, source=14.0, label="GlintRight")
    _capture_box(ox, f, -160.0, 720.0, kind="cold")


def _bay_ossuary():
    ox, f = BAY_X["ossuary"], FOLDER + "/Ossuary"
    _shell(ox, f, back="WallOssuary4m")
    _leak((ox + 420.0, 90.0, 300.0), "OssuarySeep", f, "Leak_Seep", yaw=90.0, seed=3,
          streak={"on_wall": True, "dampness": 0.6, "flow": 10.0, "width_cm": 45.0})
    for x, seed in ((ox + 170.0, 2), (ox + 640.0, 5)):
        st = _spawn(_class("Mars_WetStreak"), (x, 30.0, 330.0), 90.0, "Streak_%d" % seed, f + "/Drips")
        st.set_editor_property("seed", seed)
        _set_struct(st, "streak", dampness=0.5, flow=8.0, width_cm=50.0)
        st.call_method("Rebuild")
    pud = _spawn(_class("Mars_Puddle"), (ox + 420.0, 260.0, 40.0), 0.0, "Puddles", f + "/Drips")
    pud.set_editor_property("count", 3)
    pud.set_editor_property("radius", 140.0)
    _set_struct(pud, "look", size_min=25.0, size_max=60.0, wetness=0.6)
    pud.call_method("Rebuild")
    _lamp((ox + 200.0, 160.0, 140.0), WARM, 30.0, f, radius=800.0, source=8.0, label="Candle")
    _lamp((ox + 520.0, 330.0, 60.0), WARM, 12.0, f, radius=500.0, source=10.0, label="FloorCandle")
    _lamp((ox + 700.0, 500.0, 300.0), COLD, 15.0, f, radius=800.0, source=10.0, label="Rim")
    _capture_box(ox, f, -20.0, 360.0)


def _rig():
    sky = _spawn(unreal.SkyLight, (0, 0, 900), 0.0, "Ambient", FOLDER + "/Rig")
    sc = sky.get_component_by_class(unreal.SkyLightComponent)
    sc.set_editor_property("source_type", unreal.SkyLightSourceType.SLS_SPECIFIED_CUBEMAP)
    cube = _load("/Engine/MapTemplates/Sky/DaylightAmbientCubemap")
    if cube:
        sc.set_editor_property("cubemap", cube)
    sc.set_editor_property("intensity", LOOK["ambient"])
    fog = _spawn(unreal.ExponentialHeightFog, (0, 0, -200), 0.0, "Fog", FOLDER + "/Rig")
    fc = fog.get_component_by_class(unreal.ExponentialHeightFogComponent)
    fc.set_editor_property("fog_density", LOOK["fog_density"])
    fc.set_editor_property("fog_height_falloff", 0.08)
    ppv = _spawn(unreal.PostProcessVolume, (0, 0, 0), 0.0, "Grade", FOLDER + "/Rig")
    ppv.set_editor_property("unbound", True)
    s = ppv.get_editor_property("settings")
    s.set_editor_property("override_auto_exposure_method", True)
    s.set_editor_property("auto_exposure_method", unreal.AutoExposureMethod.AEM_MANUAL)
    s.set_editor_property("override_auto_exposure_bias", True)
    s.set_editor_property("auto_exposure_bias", LOOK["exposure_bias"])
    s.set_editor_property("override_bloom_intensity", True)
    s.set_editor_property("bloom_intensity", 0.5)
    ppv.set_editor_property("settings", s)


def _probe():
    """An isolated strand 300 cm long in front of a bright emissive board 60 cm behind it (timing parity), lit by
    nothing (the probe MI has no refraction, so the drops are dark on the bright board)."""
    f = FOLDER + "/Probe"
    cube = _load("/Engine/BasicShapes/Cube")
    board = _spawn(cube, (PROBE_X, -60.0, 200.0), 0.0, "Probe_Board", f, scale=(4.0, 0.05, 5.0))
    glow = _load("/Game/Mars/Environment/Materials/Instances/Glow_Mars_MI")
    _material(board, glow)
    floor = _spawn(cube, (PROBE_X, 0.0, -10.0), 0.0, "Probe_Floor", f, scale=(4.0, 4.0, 0.2))
    leak = _leak((PROBE_X, 0.0, 300.0), "Custom", f, "Probe_Leak", trace={"attach_up": False},
                 timing={"rate_min": 0.5, "rate_max": 0.5, "jitter": 0.6}, seed=11,
                 impact={"puddles": False, "ring_amp": 1.0}, look={"drop_material": _probe_mi()})
    return leak


def _probe_mi():
    """LookdevProbeDrop_Mars_MI: no refraction, black body and tint, no specular: drops read as dark silhouettes on
    the probe's bright board (timing parity only)."""
    mel = unreal.MaterialEditingLibrary
    name = "LookdevProbeDrop_Mars_MI"
    mi = _load("%s/%s" % (LOOKDEV_FOLDER, name))
    if mi is None:
        mi = unreal.AssetToolsHelpers.get_asset_tools().create_asset(name, LOOKDEV_FOLDER, unreal.MaterialInstanceConstant,
                                                                     unreal.MaterialInstanceConstantFactoryNew())
    mel.set_material_instance_parent(mi, _load(spec.F_MAT + "/Droplet_Mars_M"))
    mel.set_material_instance_static_switch_parameter_value(mi, "UseSceneRefraction", False)
    for k in ("WaterTint", "BodyTint", "SparkleTint"):
        mel.set_material_instance_vector_parameter_value(mi, k, unreal.LinearColor(0, 0, 0, 1))
    mel.set_material_instance_scalar_parameter_value(mi, "Specular", 0.0)
    mel.update_material_instance(mi)
    unreal.EditorAssetLibrary.save_loaded_asset(mi)
    return mi


def build_map(pcg_volumes=True):
    les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
    if les.is_in_play_in_editor():
        raise RuntimeError("stop PIE first")
    if unreal.EditorAssetLibrary.does_asset_exist(MAP):
        les.load_level(MAP)
        _eas().destroy_actors([a for a in _eas().get_all_level_actors()
                               if not isinstance(a, (unreal.WorldSettings, unreal.Brush))])
    else:
        les.new_level(MAP)
    _rig()
    _bay_sewer()
    _bay_cistern()
    _bay_ossuary()
    _probe()
    pcg = place_pcg_volumes() if pcg_volumes else None
    unreal.EditorLoadingAndSavingUtils.save_current_level()
    return {"actors": len(_eas().get_all_level_actors()), "pcg": pcg}


def _actor(label):
    for a in _eas().get_all_level_actors():
        if a.get_actor_label() == label:
            return a
    return None


# ------------------------------------------------------------------ captures
def capture(names=None, size=(1600, 1000), suffix="", out_dir=None, frozen=None, source=None):
    """SceneCapture2D shots of SHOTS (name: (eye, target, fov)); frozen = drip time to freeze the Time nodes at
    (r.Test.OverrideTimeMaterialExpressions), None for live time."""
    out_dir = out_dir or OUT_DIR
    world = _world()
    unreal.SystemLibrary.execute_console_command(world, "r.TextureStreaming 0")
    if frozen is not None:
        unreal.SystemLibrary.execute_console_command(world, "r.Test.OverrideTimeMaterialExpressions %.4f" % frozen)
    os.makedirs(out_dir, exist_ok=True)
    rt = unreal.RenderingLibrary.create_render_target2d(world, size[0], size[1], unreal.TextureRenderTargetFormat.RTF_RGBA8)
    actor = _eas().spawn_actor_from_class(unreal.SceneCapture2D, unreal.Vector(0, 0, 0))
    done = []
    try:
        comp = actor.get_component_by_class(unreal.SceneCaptureComponent2D)
        comp.set_editor_property("texture_target", rt)
        comp.set_editor_property("capture_source", source or unreal.SceneCaptureSource.SCS_FINAL_COLOR_LDR)
        comp.set_editor_property("capture_every_frame", False)
        comp.set_editor_property("capture_on_movement", False)
        for name in (names or SHOTS):
            eye, target, fov = SHOTS[name]
            d = [t - e for e, t in zip(eye, target)]
            yaw = math.degrees(math.atan2(d[1], d[0]))
            pitch = math.degrees(math.atan2(d[2], math.hypot(d[0], d[1])))
            actor.set_actor_location_and_rotation(unreal.Vector(*eye), unreal.Rotator(roll=0.0, pitch=pitch, yaw=yaw),
                                                  False, False)
            comp.set_editor_property("fov_angle", float(fov))
            comp.capture_scene()
            unreal.RenderingLibrary.export_render_target(world, rt, out_dir, name + suffix + ".png")
            done.append(os.path.join(out_dir, name + suffix + ".png"))
    finally:
        actor.destroy_actor()
        if frozen is not None:
            unreal.SystemLibrary.execute_console_command(world, "r.Test.OverrideTimeMaterialExpressions -1")
    return done


def frozen_sheets(names=("sewer_basin", "cistern_rings", "sewer_floor", "ossuary_seep"), t0=10.0, t1=11.5, step=0.125,
                  size=(640, 400)):
    """Frozen-time frames t0..t1 per shot into OUT_DIR/frozen/<shot>_<t>.png (contact sheets are built outside the
    editor by sheets())."""
    out = os.path.join(OUT_DIR, "frozen")
    paths = []
    n = int(round((t1 - t0) / step)) + 1
    for i in range(n):
        t = t0 + i * step
        paths += capture(list(names), size, suffix="_t%06.3f" % t, out_dir=out, frozen=t)
    return paths


def timing_probe(t=None):
    """Predict, from drip_reference, where each falling drop of the probe strand is at frozen time t and report the
    rows a narrow (near-orthographic) side camera should see them at. Captures the frame; the pixel check runs outside
    the editor (check_timing_png)."""
    leak = _actor("Probe_Leak")
    if leak is None:
        raise RuntimeError("no probe leak in the open map")
    strands = leak.get_editor_property("cached_strands")
    s = strands[0]
    length = float(s.get_editor_property("length"))
    rate = float(s.get_editor_property("rate"))
    seed = float(s.get_editor_property("seed"))
    if t is None:                              # 60 % of the way down the first non-skipped drop after 20 s
        c = ref.Clock(length, rate, seed, 0.6)
        k = int(math.floor(20.0 / c.p - c.seed))
        while c.skipped(k) or c.release(k) < 20.0:
            k += 1
        t = round(c.release(k) + 0.6 * c.tfall, 3)
    clock, rows = ref.predict(length, rate, seed, 0.6, t)
    src = s.get_editor_property("source")
    eye = (PROBE_X, DIST, src.z - length * 0.5)
    fov = 2.0 * math.degrees(math.atan((length * 0.65 * 0.4) / DIST))
    SHOTS["probe"] = (eye, (PROBE_X, 0.0, eye[2]), fov)
    size = (400, 1000)
    path = capture(["probe"], size, suffix="_t%.3f" % t, frozen=t)[0]
    # the camera is fov wide horizontally: rows per cm = (width / 2) / (dist * tan(fov / 2)) (square pixels)
    px_per_cm = (size[0] * 0.5) / (DIST * math.tan(math.radians(fov) * 0.5))
    expect = []
    for slot, k, state, depth in rows:
        if state == "falling":
            z = src.z - depth
            expect.append((slot, k, round(size[1] * 0.5 - (z - eye[2]) * px_per_cm, 1)))
    info = {"png": path, "t": t, "length": length, "rate": rate, "seed": seed, "period": clock.p, "tfall": clock.tfall,
            "expected_rows": expect, "px_per_cm": px_per_cm, "head_offset_px": spec.DROP_RADIUS_CM * px_per_cm}
    with open(os.path.join(OUT_DIR, "probe_t%.3f.json" % t), "w") as fh:
        json.dump(info, fh, indent=1)
    return info


def place_pcg_volumes():
    """One stock PCG volume per drip preset bay (mars_water_pcg graphs), GenerateOnDemand, generated."""
    import mars_water_pcg as wp
    out = {}
    importlib.reload(wp)
    # the sewer and ossuary volumes cover the front halves of their bays (the hand leaks own the back walls)
    out["Sewer"] = wp.place_volume((BAY_X["sewer"] + 400.0, 600.0, 175.0), (380.0, 180.0, 160.0), "Sewer")
    out["Cistern"] = wp.place_volume((BAY_X["cistern"] + 400.0, 400.0, 300.0), (380.0, 380.0, 300.0), "Cistern")
    out["Ossuary"] = wp.place_volume((BAY_X["ossuary"] + 400.0, 600.0, 175.0), (380.0, 180.0, 160.0), "Ossuary")
    return out


def shot(name, eye, target, fov=50.0, frozen=None, size=(1000, 700), source=None):
    """One ad-hoc capture (debug and tuning)."""
    SHOTS[name] = (tuple(eye), tuple(target), fov)
    return capture([name], size, frozen=frozen, source=source)[0]


def recapture():
    """Marks every reflection capture dirty (a 1 cm nudge there and back) so the editor recaptures it on the next ticks,
    after the lights and materials are in. Capture in a later call."""
    n = 0
    for a in _eas().get_all_level_actors():
        if isinstance(a, unreal.ReflectionCapture):
            loc = a.get_actor_location()
            a.set_actor_location(loc + unreal.Vector(0, 0, 1), False, False)
            a.set_actor_location(loc, False, False)
            n += 1
    return n


def next_impact(label, t0, strand=0):
    """(impact time >= t0 of the strand's next non-skipped drop, its impact point) from drip_reference."""
    leak = _actor(label)
    s = leak.get_editor_property("CachedStrands")[strand]
    timing = leak.get_editor_property("Timing")
    look = leak.get_editor_property("Look")
    mode = float(look.get_editor_property("Mode").value)
    c = ref.Clock(float(s.get_editor_property("Length")), float(s.get_editor_property("Rate")),
                  float(s.get_editor_property("Seed")), float(timing.get_editor_property("Jitter")), mode)
    k = int(math.floor(t0 / c.p - c.seed)) - 2
    while c.impact_time(k) < t0 or c.skipped(k):
        k += 1
    imp = s.get_editor_property("Impact").get_editor_property("Point")
    return c.impact_time(k), (imp.x, imp.y, imp.z), c


def ring_probe(label="Leak_PipeJoint", t0=10.0, strand=0):
    """Ring sync: normals (SCS_NORMAL) and colour from straight above the impact at I - 0.05 (flat) and I + 0.05 /
    + 0.3 / + 0.8 s (rings at 22 cm/s). Returns the png paths and the impact time."""
    t, p, c = next_impact(label, t0, strand)
    eye, target = (p[0], p[1] + 0.01, p[2] + 60.0), (p[0], p[1], p[2])
    out = []
    for dt in (-0.3, -0.05, 0.05, 0.3, 0.8):
        SHOTS["ring"] = (eye, target, 60.0)
        out += capture(["ring"], (500, 500), suffix="_n%+.2f" % dt, frozen=t + dt, source=unreal.SceneCaptureSource.SCS_NORMAL)
        out += capture(["ring"], (500, 500), suffix="_c%+.2f" % dt, frozen=t + dt)
    return {"impact": t, "point": p, "period": c.p, "tfall": c.tfall, "png": out}
