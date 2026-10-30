"""EnvLookdev_Mars_MAP: every imported dressing mesh laid out by family in rows in front of a kit wall, on a kit floor,
under the kit's warm lamp look (manual exposure, warm point lamps, a cold rim, low ambient, fog), plus captures.

    import sys, importlib
    sys.path.insert(0, r"D:\\Repo\\Mars\\Tools\\Blender\\mars_environment\\unreal")
    import mars_env_lookdev_ue as ml; importlib.reload(ml)
    ml.build_map()                      # rebuilds the map from scratch (returns to the map that was open unless stay)
    ml.capture(r"D:\\...\\shots")       # one call later (reflection captures need a tick): a shot per family + overview

Layout (Unreal cm): the back wall runs along X at y = 0 with the room on +Y; families are rows at increasing +Y, each
row spaced by its own largest depth; wall-mounted meshes (env_spec: back at Blender y = 0) sit against the wall at
y = 0; cameras stand at +Y looking toward -Y.
"""
import glob
import json
import math
import os
import sys

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
ENV_DIR = os.path.dirname(HERE)
for _p in (HERE, ENV_DIR):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import env_spec as spec      # noqa: E402

MAP = "/Game/Mars/Maps/EnvLookdev_Mars_MAP"
FOLDER = "EnvLookdev"
KIT = "/Game/Mars/Environment/Meshes/Crypt"
FAMILY_ORDER = ("bones", "crypt", "pipes", "clutter", "organic", "vines", "water")
WALL_KEYWORDS = ("Shelf", "Niche", "Banner", "Sconce", "WallLantern", "WallGrate", "Bracket", "Collar", "SigilDoor",
                 "Drape", "CandleLedge", "OssuaryFill")
HANG_KEYWORDS = ()
LOOK = {"exposure_bias": 8.7, "lamp_cd": 320 * 0.08 * 2.4, "lamp_color": (1.0, 0.84, 0.66), "rim_color": (0.35, 0.5, 1.0),
        "ambient": 0.12, "fog_density": 0.02}


def _eas():
    return unreal.get_editor_subsystem(unreal.EditorActorSubsystem)


def _load(path):
    name = path.rsplit("/", 1)[-1]
    obj = unreal.find_object(None, "%s.%s" % (path, name))
    if obj is None and unreal.EditorAssetLibrary.does_asset_exist(path):
        obj = unreal.EditorAssetLibrary.load_asset(path)
    return obj


def _spawn(obj_or_class, loc, yaw=0.0, label=None, folder=FOLDER, pitch=0.0):
    rot = unreal.Rotator(roll=0.0, pitch=pitch, yaw=yaw)
    if isinstance(obj_or_class, type):
        a = _eas().spawn_actor_from_class(obj_or_class, unreal.Vector(*loc), rot)
    else:
        a = _eas().spawn_actor_from_object(obj_or_class, unreal.Vector(*loc), rot)
    if label:
        a.set_actor_label(label)
    a.set_folder_path(folder)
    return a


def _metas():
    out = {}
    for p in sorted(glob.glob(os.path.join(spec.EXPORT_DIR, "*_Mars_SM.json"))):
        with open(p) as fh:
            m = json.load(fh)
        if "env_family" in m:
            out.setdefault(m["env_family"], []).append(m)
    return out


def _is_wall(name):
    return any(k in name for k in WALL_KEYWORDS)


def _text(label, loc, size=24.0, folder=FOLDER + "/Labels"):
    a = _spawn(unreal.TextRenderActor, loc, 90.0, "Label_" + label, folder)
    c = a.text_render
    c.set_editor_property("text", label)
    c.set_editor_property("world_size", size)
    c.set_editor_property("horizontal_alignment", unreal.HorizTextAligment.EHTA_CENTER)
    c.set_editor_property("text_render_color", unreal.Color(r=230, g=220, b=200, a=255))
    return a


def build_map(stay=True):
    les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
    if les.is_in_play_in_editor():
        raise RuntimeError("stop PIE first")
    if unreal.EditorAssetLibrary.does_asset_exist(MAP):
        les.load_level(MAP)
        _eas().destroy_actors([a for a in _eas().get_all_level_actors()
                               if not isinstance(a, (unreal.WorldSettings, unreal.Brush))])
    else:
        les.new_level(MAP)

    metas = _metas()
    placed = {}
    # rows: wall pieces against the wall line, floor pieces in rows going +Y; X packed by each mesh's width
    x_gap, row_gap = 60.0, 120.0
    widths = []
    y = 150.0
    wall_x = 0.0
    shots = {}
    for fam in FAMILY_ORDER:
        rows = metas.get(fam, [])
        if not rows:
            continue
        x = 0.0
        depth = 0.0
        floor_items = [m for m in rows if not _is_wall(m["name"])]
        wall_items = [m for m in rows if _is_wall(m["name"])]
        for m in floor_items:
            lo, hi = m["bounds_min_cm"], m["bounds_max_cm"]
            w = hi[0] - lo[0]
            d = hi[1] - lo[1]
            mesh = _load("%s/%s" % (m["ue_folder"], m["name"]))
            if mesh is None:
                continue
            cx = x - lo[0]
            _spawn(mesh, (cx, y - lo[1], -lo[2] if lo[2] < 0 else 0.0), 0.0, m["name"], FOLDER + "/" + fam)
            _text(m["name"].replace("_Mars_SM", ""), (x + w * 0.5, y - lo[1] + d * 0.5 + 40.0, 2.0), 14.0)
            placed[m["name"]] = (cx, y)
            x += w + x_gap
            depth = max(depth, d)
        for m in wall_items:
            lo, hi = m["bounds_min_cm"], m["bounds_max_cm"]
            w = hi[0] - lo[0]
            mesh = _load("%s/%s" % (m["ue_folder"], m["name"]))
            if mesh is None:
                continue
            z = 120.0 if hi[2] - lo[2] < 150 else 0.0
            _spawn(mesh, (wall_x - lo[0], 0.0, z), 0.0, m["name"], FOLDER + "/" + fam + "/Wall")
            _text(m["name"].replace("_Mars_SM", ""), (wall_x + w * 0.5, 30.0, z - 20.0), 12.0)
            placed[m["name"]] = (wall_x - lo[0], 0.0)
            wall_x += w + x_gap
        widths.append(x)
        _text(fam.upper(), (-150.0, y + depth * 0.5, 30.0), 40.0)
        shots[fam] = ((max(x, 400) * 0.5, y + depth + 900.0, 420.0), (max(x, 400) * 0.5, y + depth * 0.5, 60.0), 60.0)
        y += depth + row_gap
    span_x = max(widths + [wall_x, 1600.0])
    # kit floor and back wall
    floor = _load(KIT + "/CryptFloor4x4_Mars_SM")
    wall = _load(KIT + "/CryptWall4m_Mars_SM")
    nx = int(math.ceil((span_x + 800) / 400.0))
    ny = int(math.ceil((y + 800) / 400.0))
    for i in range(nx):
        for j in range(ny):
            if floor:
                _spawn(floor, (-400.0 + i * 400.0, j * 400.0, 0.0), 0.0, None, FOLDER + "/Kit/Floor")
        if wall:
            _spawn(wall, (-400.0 + i * 400.0, 0.0, 0.0), 0.0, None, FOLDER + "/Kit/Wall")
            _spawn(wall, (-400.0 + i * 400.0, 0.0, 350.0), 0.0, None, FOLDER + "/Kit/Wall")
    # light: warm lamps every 6 m along the rows, a cold rim from behind, low ambient, fog, manual exposure
    for i in range(int(span_x // 600) + 2):
        for yy in (250.0, y * 0.5 + 200.0, y + 200.0):
            lamp = _spawn(unreal.PointLight, (i * 600.0, yy, 330.0), 0.0, "Lamp_%d_%d" % (i, int(yy)), FOLDER + "/Rig")
            c = lamp.point_light_component
            c.set_editor_property("intensity", LOOK["lamp_cd"])
            c.set_editor_property("light_color", unreal.Color(r=255, g=int(255 * LOOK["lamp_color"][1]),
                                                               b=int(255 * LOOK["lamp_color"][2]), a=255))
            c.set_editor_property("attenuation_radius", 1400.0)
            c.set_editor_property("source_radius", 6.0)
    rim = _spawn(unreal.DirectionalLight, (0, 0, 800), 0.0, "Rim_Cold", FOLDER + "/Rig", pitch=-25.0)
    rim.set_actor_rotation(unreal.Rotator(roll=0.0, pitch=-25.0, yaw=60.0), False)
    rc = rim.get_component_by_class(unreal.DirectionalLightComponent)
    rc.set_editor_property("intensity", 1.6)
    rc.set_editor_property("light_color", unreal.Color(r=90, g=128, b=255, a=255))
    sky = _spawn(unreal.SkyLight, (0, 0, 600), 0.0, "Ambient", FOLDER + "/Rig")
    sc = sky.get_component_by_class(unreal.SkyLightComponent)
    sc.set_editor_property("source_type", unreal.SkyLightSourceType.SLS_SPECIFIED_CUBEMAP)
    cube = _load("/Engine/MapTemplates/Sky/DaylightAmbientCubemap")
    if cube:
        sc.set_editor_property("cubemap", cube)
    sc.set_editor_property("intensity", LOOK["ambient"])
    fog = _spawn(unreal.ExponentialHeightFog, (0, 0, 0), 0.0, "Fog", FOLDER + "/Rig")
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
    ppv.set_editor_property("settings", s)
    cap = _spawn(unreal.SphereReflectionCapture, (span_x * 0.5, y * 0.5, 250.0), 0.0, "Reflections", FOLDER + "/Rig")
    cap.get_component_by_class(unreal.SphereReflectionCaptureComponent).set_editor_property("influence_radius", 3000.0)
    shots["overview"] = ((span_x * 0.5, y + 1800.0, 1200.0), (span_x * 0.5, y * 0.4, 0.0), 70.0)
    shots["wall"] = ((wall_x * 0.5, 900.0, 300.0), (wall_x * 0.5, 0.0, 180.0), 75.0)
    with open(os.path.join(spec.REVIEW_DIR, "ue_lookdev_shots.json"), "w") as fh:
        json.dump(shots, fh, indent=1)
    unreal.EditorLoadingAndSavingUtils.save_current_level()
    return {"placed": len(placed), "rows_y": y, "span_x": span_x, "shots": list(shots)}


def capture(out_dir=None, names=None, size=(1600, 1000), extra=None):
    """SceneCapture2D shots of the open map. Shots come from build_map's json (family rows, overview, wall) plus extra
    {name: ((eye), (target), fov)}."""
    out_dir = out_dir or os.path.join(spec.REVIEW_DIR, "ue")
    with open(os.path.join(spec.REVIEW_DIR, "ue_lookdev_shots.json")) as fh:
        shots = {k: tuple(tuple(x) if isinstance(x, list) else x for x in v) for k, v in json.load(fh).items()}
    if extra:
        shots.update(extra)
    world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    unreal.SystemLibrary.execute_console_command(world, "r.TextureStreaming 0")
    os.makedirs(out_dir, exist_ok=True)
    rt = unreal.RenderingLibrary.create_render_target2d(world, size[0], size[1], unreal.TextureRenderTargetFormat.RTF_RGBA8)
    actor = _eas().spawn_actor_from_class(unreal.SceneCapture2D, unreal.Vector(0, 0, 0))
    done = []
    try:
        comp = actor.get_component_by_class(unreal.SceneCaptureComponent2D)
        comp.set_editor_property("texture_target", rt)
        comp.set_editor_property("capture_source", unreal.SceneCaptureSource.SCS_FINAL_COLOR_LDR)
        comp.set_editor_property("capture_every_frame", False)
        comp.set_editor_property("capture_on_movement", False)
        for name in (names or shots):
            eye, target, fov = shots[name]
            d = [t - e for e, t in zip(eye, target)]
            yaw = math.degrees(math.atan2(d[1], d[0]))
            pitch = math.degrees(math.atan2(d[2], math.hypot(d[0], d[1])))
            actor.set_actor_location_and_rotation(unreal.Vector(*eye), unreal.Rotator(roll=0.0, pitch=pitch, yaw=yaw),
                                                  False, False)
            comp.set_editor_property("fov_angle", float(fov))
            comp.capture_scene()
            unreal.RenderingLibrary.export_render_target(world, rt, out_dir, name + ".png")
            done.append(os.path.join(out_dir, name + ".png"))
    finally:
        actor.destroy_actor()
    return done
