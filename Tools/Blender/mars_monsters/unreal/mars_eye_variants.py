"""Lookdev row for the eye-swarm shader: ten eyeball + lid pairs, each wearing its own MID from the generated MarsEyeball /
MarsEyelid masters with a named parameter set, in front of a ProtoGrid backdrop on Sandbox_Mars_MAP (editor world, no
PIE; the map is never saved). Each variant is captured close through a SceneCapture2D into Saved/Screenshots/EyeVariants,
and the host tiles them into a labelled sheet (mars_eye_variants_sheet.py).

    python ../../mars_environment/unreal/env_drive.py --port 9317 --py "<sys.path insert>; import mars_eye_variants as ev; ev.build(); print(ev.capture_all())"
"""
import os

import unreal

MAP = "/Game/Mars/Maps/Sandbox_Mars_MAP"
SHOT_DIR = r"D:\Repo\Mars\Saved\Screenshots\EyeVariants"
EYEBALL = "/Game/Mars/Gameplay/Monsters/EyeSwarm/Meshes/EyeSwarm_Eyeball_Mars_SM"
EYELID = "/Game/Mars/Gameplay/Monsters/EyeSwarm/Meshes/EyeSwarm_Eyelid_Mars_SM"
MASTER_EYE = "/Game/Mars/Materials/GeneratedLooks/M_CkUsf_Look_MarsEyeball"
MASTER_LID = "/Game/Mars/Materials/GeneratedLooks/M_CkUsf_Look_MarsEyelid"
BACKDROP_MI = "/Game/Mars/Materials/ProtoGrid/ProtoGrid_Wall_Mars_MI"
TAG = "EyeVariants"
# A clear spot south of Room 2 (rooms span y -700..1200): the backdrop's face at x 2200 looking -X, eyes 20 cm in front.
ROW_X = 2180.0
ROW_Y0 = -3250.0
ROW_DY = 55.0
ROW_Z = 160.0
EYE_SCALE = 2.4            # 24 cm eyeballs so a 512 px close-up reads

# The Stray wall eye (Stephen 2026-11-07): no iris, a pupil set in a graded red sclera with an orange halo, GLASSY (the
# reference shows pinpoint specular hits, so the roughness is near zero and the painted glints are almost off) and
# emissive-led so it pierces a dark, foggy room.
STRAY_EYE = {"ScleraColor": (0.72, 0.10, 0.06), "ScleraRimColor": (0.10, 0.012, 0.01), "ScleraRimStrength": 1.0,
             "ScleraRimPower": 1.4, "GradientTopTint": (0.45, 0.32, 0.32), "GradientBottomTint": (1.05, 1.0, 1.0),
             "GradientStrength": 0.8, "IrisAngleDeg": 0.0, "PupilAngleDeg": 15.0, "PupilColor": (0.03, 0.0, 0.0),
             "PupilHaloColor": (1.0, 0.42, 0.12), "PupilHaloAngleDeg": 34.0, "PupilHaloStrength": 1.0,
             "ViewRimDarken": 0.75, "ViewRimPower": 1.6, "ViewCentreBoost": 0.25, "EmissiveStrength": 4.0,
             "ScleraGlow": 0.7, "ScleraRoughness": 0.04, "GlintStrength": 0.15, "GlintSize": 6.0,
             "LidColor": (0.40, 0.09, 0.07), "UpperShadeStrength": 0.45}
STRAY_LID = {"LidColor": (0.40, 0.09, 0.07), "GradientTopTint": (0.45, 0.32, 0.32), "GradientBottomTint": (1.05, 1.0, 1.0),
             "ViewRimDarken": 0.75, "ViewRimPower": 1.6, "LidRoughness": 0.35}

# name -> (eyeball uniforms, lid uniforms). Vectors are (r, g, b); scalars are floats. Missing = the look's default.
VARIANTS = [
    ("Cartoon (defaults)", {}, {}),
    ("Horror", {"ScleraColor": (0.35, 0.04, 0.03), "IrisColor": (1.0, 0.12, 0.05), "PupilColor": (0.01, 0.0, 0.0),
                "EmissiveStrength": 8.0, "LidColor": (0.45, 0.12, 0.10), "ScleraRimColor": (0.12, 0.012, 0.01),
                "IrisInnerColor": (1.0, 0.45, 0.12), "PupilHaloColor": (1.0, 0.35, 0.08), "PupilHaloStrength": 0.6,
                "ViewRimDarken": 0.5},
     {"LidColor": (0.45, 0.12, 0.10), "ViewRimDarken": 0.5}),
    ("Stray wall gradient", dict(STRAY_EYE), dict(STRAY_LID)),
    ("Cat slit", {"ScleraColor": (0.88, 0.82, 0.55), "ScleraRimColor": (0.45, 0.38, 0.18), "IrisColor": (0.30, 0.78, 0.18),
                  "IrisInnerColor": (0.85, 1.0, 0.35), "IrisAngleDeg": 38.0, "PupilAngleDeg": 15.0, "PupilSlit": 1.0,
                  "EmissiveStrength": 1.5, "IrisFibreStrength": 0.45, "LidColor": (0.30, 0.22, 0.16)},
     {"LidColor": (0.30, 0.22, 0.16)}),
    ("Arcane cyan", {"ScleraColor": (0.04, 0.07, 0.11), "ScleraRimColor": (0.02, 0.03, 0.06), "ScleraGlow": 0.35,
                     "IrisColor": (0.10, 0.85, 1.0), "IrisInnerColor": (0.80, 1.0, 1.0), "IrisAngleDeg": 40.0,
                     "PupilAngleDeg": 8.0, "EmissiveStrength": 10.0, "IrisFibreStrength": 0.7, "IrisFibreCount": 36.0,
                     "GlintStrength": 2.0, "LidColor": (0.10, 0.12, 0.18)},
     {"LidColor": (0.10, 0.12, 0.18)}),
    ("Clouded dead eye", {"ScleraColor": (0.58, 0.62, 0.64), "ScleraRimColor": (0.32, 0.36, 0.40), "IrisColor": (0.50, 0.56, 0.60),
                          "IrisInnerColor": (0.62, 0.68, 0.72), "PupilColor": (0.30, 0.33, 0.36), "IrisFibreStrength": 0.08,
                          "GlintStrength": 0.25, "GradientStrength": 0.7, "LidOpenFraction": 0.72, "LidColor": (0.45, 0.36, 0.34)},
     {"LidOpenFraction": 0.72, "LidColor": (0.45, 0.36, 0.34)}),
    ("Gold demon", {"ScleraColor": (0.07, 0.02, 0.0), "ScleraRimColor": (0.02, 0.0, 0.0), "IrisColor": (1.0, 0.72, 0.10),
                    "IrisInnerColor": (1.0, 1.0, 0.55), "PupilSlit": 1.0, "PupilAngleDeg": 14.0, "IrisAngleDeg": 36.0,
                    "EmissiveStrength": 6.0, "UpperShadeStrength": 0.6, "LidColor": (0.20, 0.05, 0.04)},
     {"LidColor": (0.20, 0.05, 0.04)}),
    ("Shader lid (no lid mesh)", {"ShaderLid": 1.0, "LidColor": (0.62, 0.36, 0.30), "IrisColor": (0.38, 0.58, 0.90),
                                  "IrisInnerColor": (0.78, 0.88, 1.0)}, None),
    ("Cute wide pupil", {"IrisAngleDeg": 46.0, "PupilAngleDeg": 24.0, "IrisColor": (0.55, 0.28, 0.62), "IrisInnerColor": (0.92, 0.60, 1.0),
                         "GlintStrength": 1.6, "GlintSize": 10.0, "LidOpenFraction": 1.0, "UpperShadeStrength": 0.2,
                         "LidColor": (0.70, 0.45, 0.42)},
     {"LidOpenFraction": 1.0, "LidColor": (0.70, 0.45, 0.42)}),
    ("Bloodshot", {"ScleraColor": (0.96, 0.86, 0.80), "ScleraRimColor": (0.80, 0.18, 0.12), "ScleraRimPower": 1.0, "ScleraRimStrength": 1.0,
                   "IrisColor": (0.60, 0.42, 0.18), "IrisInnerColor": (0.85, 0.65, 0.30), "PupilAngleDeg": 18.0,
                   "UpperShadeStrength": 0.5, "LidColor": (0.62, 0.30, 0.26)},
     {"LidColor": (0.62, 0.30, 0.26)}),
]


def _eas():
    return unreal.get_editor_subsystem(unreal.EditorActorSubsystem)


def _world():
    return unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()


def _load(path):
    obj = unreal.EditorAssetLibrary.load_asset(path)
    if obj is None:
        raise RuntimeError("missing asset %s" % path)
    return obj


def _clear():
    for a in _eas().get_all_level_actors():
        if a.actor_has_tag(TAG):
            a.destroy_actor()


def _apply(mid, params):
    for name, value in params.items():
        if isinstance(value, (tuple, list)):
            mid.set_vector_parameter_value(name, unreal.LinearColor(value[0], value[1], value[2], 1.0))
        else:
            mid.set_scalar_parameter_value(name, float(value))


# Lookdev only: a blink caught by the capture closes the lid over the whole eye (the clouded eye shipped that way in the
# first sheet), so the row holds its lids open; the wander keeps running.
NO_BLINK = {"BlinkIntervalMinS": 1.0e4, "BlinkIntervalMaxS": 1.0e4}


def _mesh_actor(mesh, material, location, label, phase, params):
    actor = _eas().spawn_actor_from_class(unreal.StaticMeshActor, location, unreal.Rotator(roll=0.0, pitch=0.0, yaw=180.0))
    actor.set_actor_label(label)
    actor.tags = [unreal.Name(TAG)]
    actor.set_actor_scale3d(unreal.Vector(EYE_SCALE, EYE_SCALE, EYE_SCALE))
    comp = actor.static_mesh_component
    comp.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
    comp.set_static_mesh(mesh)
    comp.set_collision_enabled(unreal.CollisionEnabled.NO_COLLISION)
    mid = comp.create_dynamic_material_instance(0, material)
    _apply(mid, dict(NO_BLINK, **params))
    comp.set_custom_primitive_data_float(0, phase)       # PhaseCpd: every variant blinks and glances on its own clock
    return actor


def build():
    """Loads the map, clears a previous row, places the backdrop, the eyes and one capture. Returns the eye centres."""
    les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
    if les.is_in_play_in_editor():
        raise RuntimeError("stop PIE first")
    world = _world()
    if world is None or world.get_path_name().split(".")[0] != MAP:
        les.load_level(MAP)
    _clear()
    eyeball, eyelid = _load(EYEBALL), _load(EYELID)
    master_eye, master_lid = _load(MASTER_EYE), _load(MASTER_LID)
    backdrop_mi = _load(BACKDROP_MI)

    n = len(VARIANTS)
    width = ROW_DY * (n + 1)
    slab = _eas().spawn_actor_from_class(unreal.StaticMeshActor, unreal.Vector(ROW_X + 30.0, ROW_Y0 + ROW_DY * (n - 1) * 0.5, ROW_Z),
                                         unreal.Rotator(roll=0.0, pitch=0.0, yaw=0.0))
    slab.set_actor_label("EyeVariants_Backdrop")
    slab.tags = [unreal.Name(TAG)]
    slab.static_mesh_component.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
    slab.static_mesh_component.set_static_mesh(_load("/Engine/BasicShapes/Cube"))
    slab.static_mesh_component.set_material(0, backdrop_mi)
    slab.set_actor_scale3d(unreal.Vector(0.2, width / 100.0, 1.6))

    centres = []
    for i, (name, eye_params, lid_params) in enumerate(VARIANTS):
        c = unreal.Vector(ROW_X, ROW_Y0 + ROW_DY * i, ROW_Z)
        phase = (i * 0.37) % 1.0
        _mesh_actor(eyeball, master_eye, c, "EyeVariant_%02d_Eye" % i, phase, eye_params)
        if lid_params is not None:
            lid = dict(lid_params)
            _mesh_actor(eyelid, master_lid, c, "EyeVariant_%02d_Lid" % i, phase, lid)
        centres.append((name, [c.x, c.y, c.z]))

    cap = _eas().spawn_actor_from_class(unreal.SceneCapture2D, unreal.Vector(ROW_X - 100.0, ROW_Y0, ROW_Z),
                                        unreal.Rotator(roll=0.0, pitch=0.0, yaw=0.0))
    cap.set_actor_label("EyeVariants_Capture")
    cap.tags = [unreal.Name(TAG)]
    comp = cap.capture_component2d
    comp.set_editor_property("capture_every_frame", False)
    comp.set_editor_property("capture_on_movement", False)
    return centres


_RT = {}


def _capture(name, eye, target, res, fov=30.0, ev_bias=None):
    world = _world()
    cap = [a for a in _eas().get_all_level_actors() if a.get_actor_label() == "EyeVariants_Capture"][0]
    comp = cap.capture_component2d
    rt = _RT.get(res)
    if rt is None:
        rt = unreal.RenderingLibrary.create_render_target2d(world, res[0], res[1], unreal.TextureRenderTargetFormat.RTF_RGBA8_SRGB)
        _RT[res] = rt
    comp.set_editor_property("texture_target", rt)
    comp.set_editor_property("capture_source", unreal.SceneCaptureSource.SCS_FINAL_TONE_CURVE_HDR)
    comp.set_editor_property("fov_angle", fov)
    pps = comp.get_editor_property("post_process_settings")
    pps.set_editor_property("override_auto_exposure_method", ev_bias is not None)
    pps.set_editor_property("override_auto_exposure_bias", ev_bias is not None)
    if ev_bias is not None:
        pps.set_editor_property("auto_exposure_method", unreal.AutoExposureMethod.AEM_MANUAL)
        pps.set_editor_property("auto_exposure_bias", float(ev_bias))
    comp.set_editor_property("post_process_settings", pps)
    e = unreal.Vector(*eye)
    cap.set_actor_location_and_rotation(e, unreal.MathLibrary.find_look_at_rotation(e, unreal.Vector(*target)), False, False)
    comp.capture_scene()
    os.makedirs(SHOT_DIR, exist_ok=True)
    unreal.RenderingLibrary.export_render_target(world, rt, SHOT_DIR, name + ".png")
    return os.path.join(SHOT_DIR, name + ".png")


def capture_all(distance=95.0, res=(640, 640)):
    """One close square per variant (from in front, slightly up-left of the eye) plus one row shot."""
    out = []
    for i, (name, _, _) in enumerate(VARIANTS):
        c = (ROW_X, ROW_Y0 + ROW_DY * i, ROW_Z)
        out.append(_capture("variant_%02d" % i, (c[0] - distance, c[1] + 18.0, c[2] + 14.0), c, res))
    n = len(VARIANTS)
    mid_y = ROW_Y0 + ROW_DY * (n - 1) * 0.5
    out.append(_capture("variants_row", (ROW_X - 520.0, mid_y, ROW_Z + 40.0), (ROW_X, mid_y, ROW_Z), (1920, 640)))
    return out


def names():
    return [v[0] for v in VARIANTS]


# ---------------------------------------------------------------- the dark room (the Stray reference's conditions)
DARK_TAG = "EyeVariantsDark"
DARK_X = 2180.0
DARK_Y = -3000.0
DARK_Z = 160.0
# (y offset, z offset, scale): a loose cluster like the reference, big and small
DARK_EYES = [(-230.0, 60.0, 2.6), (-150.0, -40.0, 1.3), (-95.0, 70.0, 1.1), (-30.0, 10.0, 3.2), (60.0, 90.0, 1.4),
             (110.0, -30.0, 1.0), (190.0, 40.0, 2.0), (250.0, -60.0, 1.2), (300.0, 80.0, 0.9), (-180.0, 150.0, 0.8),
             (40.0, 170.0, 1.0), (220.0, 160.0, 1.1)]
_LIGHTS = {}


def dark_room(fog_density=0.012, key_intensity=60.0):
    """Darkens the editor world (sun and sky off, kept for restore_lights), spawns dense dark-red height fog, a dark
    flesh backdrop, a cluster of Stray eyes at mixed sizes and one dim warm point light low to the side for pinpoint
    specular hits. The map is never saved."""
    for a in _eas().get_all_level_actors():
        if a.actor_has_tag(DARK_TAG) or (a.actor_has_tag(TAG) and a.get_actor_label() != "EyeVariants_Capture"):
            a.destroy_actor()
    if not _LIGHTS:
        for a in _eas().get_all_level_actors():
            if isinstance(a, unreal.DirectionalLight):
                _LIGHTS[a.get_name()] = (a, a.light_component.get_editor_property("intensity"))
                a.light_component.set_intensity(0.0)
            elif isinstance(a, unreal.SkyLight):
                _LIGHTS[a.get_name()] = (a, a.light_component.get_editor_property("intensity"))
                a.light_component.set_intensity(0.02)
    fog = _eas().spawn_actor_from_class(unreal.ExponentialHeightFog, unreal.Vector(DARK_X, DARK_Y, 0.0))
    fog.tags = [unreal.Name(DARK_TAG)]
    fc = fog.component
    fc.set_editor_property("fog_density", fog_density)
    fc.set_editor_property("fog_height_falloff", 0.0001)
    fc.set_editor_property("fog_inscattering_luminance", unreal.LinearColor(0.012, 0.002, 0.001, 1.0))
    fc.set_editor_property("start_distance", 0.0)
    fc.set_editor_property("fog_max_opacity", 0.96)

    eyeball, eyelid = _load(EYEBALL), _load(EYELID)
    master_eye, master_lid = _load(MASTER_EYE), _load(MASTER_LID)
    slab = _eas().spawn_actor_from_class(unreal.StaticMeshActor, unreal.Vector(DARK_X + 40.0, DARK_Y + 40.0, DARK_Z + 60.0))
    slab.tags = [unreal.Name(DARK_TAG)]
    slab.set_actor_label("EyeDark_Backdrop")
    slab.static_mesh_component.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
    slab.static_mesh_component.set_static_mesh(_load("/Engine/BasicShapes/Cube"))
    flesh = slab.static_mesh_component.create_dynamic_material_instance(0, _load("/Engine/BasicShapes/BasicShapeMaterial"))
    flesh.set_vector_parameter_value("Color", unreal.LinearColor(0.09, 0.012, 0.008, 1.0))
    slab.set_actor_scale3d(unreal.Vector(0.4, 8.0, 5.0))

    for i, (dy, dz, sc) in enumerate(DARK_EYES):
        c = unreal.Vector(DARK_X - 5.0 * sc, DARK_Y + dy, DARK_Z + dz)
        phase = (i * 0.41) % 1.0
        for mesh, master, params, kind in ((eyeball, master_eye, STRAY_EYE, "Eye"), (eyelid, master_lid, STRAY_LID, "Lid")):
            actor = _eas().spawn_actor_from_class(unreal.StaticMeshActor, c, unreal.Rotator(roll=0.0, pitch=0.0, yaw=180.0))
            actor.set_actor_label("EyeDark_%02d_%s" % (i, kind))
            actor.tags = [unreal.Name(DARK_TAG)]
            actor.set_actor_scale3d(unreal.Vector(sc, sc, sc))
            comp = actor.static_mesh_component
            comp.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
            comp.set_static_mesh(mesh)
            comp.set_collision_enabled(unreal.CollisionEnabled.NO_COLLISION)
            mid = comp.create_dynamic_material_instance(0, master)
            # real blinks here: the reference eyes blink, and the wide shot tolerates one closed eye
            _apply(mid, dict(params, LidOpenFraction=0.85 if i % 3 else 0.6))
            comp.set_custom_primitive_data_float(0, phase)

    key = _eas().spawn_actor_from_class(unreal.PointLight, unreal.Vector(DARK_X - 260.0, DARK_Y - 320.0, DARK_Z - 40.0))
    key.tags = [unreal.Name(DARK_TAG)]
    key.set_actor_label("EyeDark_Key")
    lc = key.light_component
    lc.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
    lc.set_intensity(key_intensity)
    lc.set_light_color(unreal.LinearColor(1.0, 0.55, 0.3, 1.0))
    lc.set_editor_property("attenuation_radius", 900.0)
    lc.set_editor_property("source_radius", 25.0)

    if not [a for a in _eas().get_all_level_actors() if a.get_actor_label() == "EyeVariants_Capture"]:
        cap = _eas().spawn_actor_from_class(unreal.SceneCapture2D, unreal.Vector(DARK_X - 100.0, DARK_Y, DARK_Z))
        cap.set_actor_label("EyeVariants_Capture")
        cap.tags = [unreal.Name(TAG)]
        cap.capture_component2d.set_editor_property("capture_every_frame", False)
        cap.capture_component2d.set_editor_property("capture_on_movement", False)
    return {"eyes": len(DARK_EYES), "lights_dimmed": list(_LIGHTS.keys())}


def restore_lights():
    for a, intensity in _LIGHTS.values():
        a.light_component.set_intensity(intensity)
    _LIGHTS.clear()
    return True


def capture_dark(prefix="dark", res=(1920, 720), ev_bias=1.5):
    """A wide shot of the cluster from where the reference stands (low, off to the side) and one close shot."""
    # From the mid position with a wide lens: a capture placed further back (x <= ~1900 here) renders black in this
    # editor, whatever the lens, exposure or target size (2026-11-07); the cause was not found.
    wide = _capture(prefix + "_wide", (DARK_X - 200.0, DARK_Y - 60.0, DARK_Z + 30.0), (DARK_X, DARK_Y + 10.0, DARK_Z + 40.0), res, fov=78.0, ev_bias=ev_bias)
    mid = _capture(prefix + "_mid", (DARK_X - 200.0, DARK_Y - 60.0, DARK_Z + 30.0), (DARK_X, DARK_Y + 10.0, DARK_Z + 40.0), (1280, 720), fov=60.0, ev_bias=ev_bias)
    close = _capture(prefix + "_close", (DARK_X - 150.0, DARK_Y - 70.0, DARK_Z + 20.0), (DARK_X, DARK_Y - 30.0, DARK_Z + 10.0), (1280, 720), ev_bias=ev_bias)
    return [wide, mid, close]
