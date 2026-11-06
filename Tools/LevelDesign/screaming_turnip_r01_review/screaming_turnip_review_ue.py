"""Screaming Turnip R01 review room, built from Python inside the running editor (Phase C). Bat pattern
(Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_review_ue.py): run through Monolith `editor_query run_python`, never a
console command that loads levels.

    import sys; sys.path.insert(0, r"D:/Repositories/CkRepos/Orion/Tools/LevelDesign/screaming_turnip_r01_review")
    import importlib, screaming_turnip_review_ue as m; importlib.reload(m)
    res = m.build_review_scene(); print(res)
    print(m.capture_views(r"<out dir>"))      # SceneCapture2D PNGs (bind pose: no animation is evaluated)
    print(m.restore_level(res["previous_level"]))

Room: 1200 x 1200 floor slab (top at Z 0, BlockAll, so the Jolt static world sees it), 400 cm ProtoGrid walls, no ceiling
(the neutral sun + sky light the displays), an amber key and a teal fill over the displays. Displays (static, no animation,
no collision): the SK planted in a TurnipBed (root at bed origin - SoilLine 9.6 cm), the SK on its side on the floor, the
SK at hand height 45 cm in front of the PlayerStart; the two beds on their own. Entities (the Phase D
Mars.ScreamingTurnip.BuildReviewRoom set, placed through the entity-spawner factory like utils_mars_map_builder::
Spawn_EntityScript): a planted bed entity at the origin, a second one 636 cm away, the PlayerStart (-250, 0, 100) facing +X.
Every actor placed here is tagged TAG_REVIEW and labelled PREFIX*; a rebuild deletes those first. Only the review map is
saved. The GameMode override is set afterwards through Monolith editor.author_map_settings.
"""

import json
import math
import os
import struct
import traceback
import zlib

import unreal

F_ROOT = "/Game/ArtCandidates/ScreamingTurnip/R01"
REVIEW_MAP = F_ROOT + "/Review/ScreamingTurnip_R01_Review_MAP"
PREFIX = "ScreamingTurnipR01Review_"
TAG_REVIEW = "ScreamingTurnipR01Review"

SK = F_ROOT + "/Meshes/ScreamingTurnip_R01_Mars_SK"
BED = F_ROOT + "/Meshes/TurnipBed_R01_Mars_SM"
BED_EMPTY = F_ROOT + "/Meshes/TurnipBedEmpty_R01_Mars_SM"
CUBE = "/Engine/BasicShapes/Cube.Cube"
PROTOGRID = "/Game/Mars/Materials/ProtoGrid/ProtoGrid_%s_Mars_MI"
CUBEMAP = "/Engine/MapTemplates/Sky/DaylightAmbientCubemap"
BED_ENTITY = "/Script/Angelscript.Mars_ScreamingTurnipBed_EntityScript"

ROOM_HALF, ROOM_HEIGHT, WALL = 600.0, 400.0, 40.0
# C3: sizes come from the asset manifest (B4 = x3.0), so a rebuild follows the asset. 16 cm values in brackets.
MANIFEST = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "Blender",
                                         "mars_ingredients", "screaming_turnip_r01", "export",
                                         "ScreamingTurnip_R01_Manifest.json"))
_M = json.load(open(MANIFEST, "r", encoding="utf-8"))
SCALE = float(_M.get("scale_factor", 1.0))                                   # [1.0]
SOIL_LINE_Z = float(_M["sockets"]["SoilLine"]["root_relative_ue_cm"][2])      # [9.6] root -> soil line
_BED_BOUNDS = _M["beds"]["TurnipBed_R01"]["bounds_ue_cm"]
BED_BOTTOM = -float(_BED_BOUNDS["min"][2])   # [3.4] a bed at z BED_BOTTOM stands on the floor
BED_W = float(_BED_BOUNDS["max"][1] - _BED_BOUNDS["min"][1])                   # [24]
SIDE_Z = 0.5 * float(_M["dimensions_cm"]["bulb"]["w_y"])   # [4.6] bulb half-width: the SK on its side rests its bulb on the floor
BED_GAP = 48.0                                             # clear floor between neighbouring beds
BEDS_Y = (160.0, 160.0 + BED_W + BED_GAP, 160.0 + 2.0 * (BED_W + BED_GAP))   # planted, full, empty  [200, 300, 400]
ONSIDE_Y = -200.0
PLAYER_START = (-250.0, 0.0, 100.0)
HAND = (PLAYER_START[0] + 45.0, 0.0, 135.0)       # 45 cm in front of the start (root), about hand height
DISPLAYS_X = 150.0
SUN_LUX, SKY_INTENSITY = 3.0, 0.5
SUN_YAW = 30.0               # the sun travels toward +X: it lights the faces turned to the player start
FACE_PLAYER = 180.0         # every display turns its mouth (+X) toward the player start (-X)
AMBER = ((1.0, 0.55, 0.2), 900.0, (-330.0, 70.0, 190.0))     # colour, candela, location (key, behind and above the player start)
TEAL = ((0.2, 0.7, 0.8), 250.0, (330.0, -320.0, 90.0))      # fill from behind the displays
EXPOSURE_BIAS = -2.0                                          # capture manual exposure compensation (tuned by eye, r02)


def _err(e):
    return "%s: %s\n%s" % (type(e).__name__, e, traceback.format_exc())


def _les():
    return unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)


def _eas():
    return unreal.get_editor_subsystem(unreal.EditorActorSubsystem)


def _world():
    return unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()


def _world_package():
    w = _world()
    return w.get_outermost().get_name() if w else None


def _pie():
    if unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_game_world():
        return {"error": "PIE is running: stop it first"}
    return None


def _v(xyz):
    return unreal.Vector(float(xyz[0]), float(xyz[1]), float(xyz[2]))


def _rot(yaw=0.0, pitch=0.0, roll=0.0):
    return unreal.Rotator(roll=roll, pitch=pitch, yaw=yaw)


def _tag(actor, label):
    actor.set_actor_label(PREFIX + label)
    actor.set_editor_property("tags", [unreal.Name(TAG_REVIEW)])
    return actor


def _block(label, centre, size, look):
    a = _eas().spawn_actor_from_class(unreal.StaticMeshActor, _v(centre), _rot())
    smc = a.static_mesh_component
    smc.set_static_mesh(unreal.load_asset(CUBE))
    a.set_actor_scale3d(unreal.Vector(size[0] * 0.01, size[1] * 0.01, size[2] * 0.01))
    smc.set_collision_profile_name("BlockAll")
    mi = unreal.load_asset(PROTOGRID % look)
    if mi:
        smc.set_material(0, mi)
    return _tag(a, label)


def _static(label, mesh, loc, rot=None):
    a = _eas().spawn_actor_from_class(unreal.StaticMeshActor, _v(loc), rot or _rot())
    smc = a.static_mesh_component
    smc.set_static_mesh(unreal.load_asset(mesh))
    smc.set_collision_enabled(unreal.CollisionEnabled.NO_COLLISION)
    return _tag(a, label)


def _skeletal(label, loc, rot=None):
    a = _eas().spawn_actor_from_class(unreal.SkeletalMeshActor, _v(loc), rot or _rot())
    c = a.skeletal_mesh_component
    c.set_skinned_asset_and_update(unreal.load_asset(SK))
    c.set_collision_enabled(unreal.CollisionEnabled.NO_COLLISION)
    return _tag(a, label)


def _entity_script(class_path, label, location, yaw=0.0):
    cls = unreal.load_class(None, class_path)
    if cls is None:
        raise RuntimeError("AngelScript class %s is not loaded (does the script compile?)" % class_path)
    a = _eas().spawn_actor_from_object(cls, _v(location), _rot(yaw))
    if a is None:
        raise RuntimeError("the entity spawner factory placed nothing for %s" % class_path)
    return _tag(a, label)


def _place_geometry():
    span = ROOM_HALF * 2.0 + WALL * 2.0
    wz, wo = ROOM_HEIGHT * 0.5, ROOM_HALF + WALL * 0.5
    _block("Floor", (0.0, 0.0, -10.0), (span, span, 20.0), "Floor")
    _block("WallNorth", (0.0, wo, wz), (span, WALL, ROOM_HEIGHT), "Wall")
    _block("WallSouth", (0.0, -wo, wz), (span, WALL, ROOM_HEIGHT), "Wall")
    _block("WallEast", (wo, 0.0, wz), (WALL, span, ROOM_HEIGHT), "Wall")
    _block("WallWest", (-wo, 0.0, wz), (WALL, span, ROOM_HEIGHT), "Wall")


def _display_layout():
    """label -> (location, rotation pyr). The planted SK's root sits SOIL_LINE_Z below its bed's soil-line origin."""
    x = DISPLAYS_X
    yp, yb, ye = BEDS_Y
    return {"Display_PlantedBed": ((x, yp, BED_BOTTOM), (0.0, 0.0, 0.0)),
            "Display_Planted_SK": ((x, yp, BED_BOTTOM - SOIL_LINE_Z), (0.0, FACE_PLAYER, 0.0)),
            "Display_Bed": ((x, yb, BED_BOTTOM), (0.0, 0.0, 0.0)),
            "Display_BedEmpty": ((x, ye, BED_BOTTOM), (0.0, 0.0, 0.0)),
            "Display_OnSide_SK": ((x, ONSIDE_Y, SIDE_Z), (0.0, FACE_PLAYER, 90.0)),
            "Display_HandHeight_SK": (HAND, (0.0, FACE_PLAYER, 0.0))}


def _place_displays():
    for label, (loc, (p, y, r)) in _display_layout().items():
        mesh = {"Display_PlantedBed": BED, "Display_Bed": BED, "Display_BedEmpty": BED_EMPTY}.get(label)
        if mesh:
            _static(label, mesh, loc, _rot(yaw=y, pitch=p, roll=r))
        else:
            _skeletal(label, loc, _rot(yaw=y, pitch=p, roll=r))


def replace_displays():
    """C3: move the six existing display actors to _display_layout() (the asset grew x3.0) and save only the review map.
    No actor is deleted or spawned; entities, lights, walls and the PlayerStart are untouched. Refuses if another package
    is dirty."""
    if _pie():
        return {"error": "PIE running"}
    res = {"level": _world_package(), "moved": {}, "missing": [], "saved": False, "error": None}
    if res["level"] != REVIEW_MAP:
        res["error"] = "open %s first" % REVIEW_MAP
        return res
    dirty = [p.get_name() for p in list(unreal.EditorLoadingAndSavingUtils.get_dirty_content_packages()) +
             list(unreal.EditorLoadingAndSavingUtils.get_dirty_map_packages())]
    res["dirty_before"] = dirty
    if dirty:
        res["error"] = "dirty packages before the move: %s" % dirty
        return res
    actors = {a.get_actor_label(): a for a in _eas().get_all_level_actors()}
    for label, (loc, (p, y, r)) in _display_layout().items():
        a = actors.get(PREFIX + label)
        if a is None:
            res["missing"].append(label)
            continue
        before = a.get_actor_location()
        a.set_actor_location_and_rotation(_v(loc), _rot(yaw=y, pitch=p, roll=r), False, True)
        res["moved"][label] = {"from": [round(before.x, 2), round(before.y, 2), round(before.z, 2)], "to": list(loc)}
    dirty = sorted(set(p.get_name() for p in list(unreal.EditorLoadingAndSavingUtils.get_dirty_content_packages()) +
                       list(unreal.EditorLoadingAndSavingUtils.get_dirty_map_packages())))
    res["dirty_after_move"] = dirty
    if any(p != REVIEW_MAP for p in dirty):
        res["error"] = "a package other than the review map is dirty, not saving: %s" % dirty
        return res
    res["saved"] = bool(_les().save_current_level())
    res["dirty_after_save"] = [p.get_name() for p in list(unreal.EditorLoadingAndSavingUtils.get_dirty_content_packages()) +
                               list(unreal.EditorLoadingAndSavingUtils.get_dirty_map_packages())]
    return res


def display_footprints():
    """World AABBs of the display actors (component bounds; the SK ones include the mesh's bounds extension) and the
    pairwise overlaps of those boxes - a coarse no-overlap check."""
    rows = {}
    for a in _eas().get_all_level_actors():
        lab = a.get_actor_label()
        if lab.startswith(PREFIX + "Display_"):
            o, e = a.get_actor_bounds(False)
            rows[lab[len(PREFIX):]] = {"min": [round(o.x - e.x, 2), round(o.y - e.y, 2), round(o.z - e.z, 2)],
                                       "max": [round(o.x + e.x, 2), round(o.y + e.y, 2), round(o.z + e.z, 2)]}
    over = []
    names = sorted(rows)
    for i, n0 in enumerate(names):
        for n1 in names[i + 1:]:
            a, b = rows[n0], rows[n1]
            if all(a["min"][k] < b["max"][k] and b["min"][k] < a["max"][k] for k in range(3)):
                over.append([n0, n1])
    return {"boxes": rows, "overlapping_boxes": over}


def _place_entities(res):
    try:
        _entity_script(BED_ENTITY, "Bed", (0.0, 0.0, 0.0))
        _entity_script(BED_ENTITY, "SecondBed", (450.0, -450.0, 0.0))
        res["entities"] = True
    except Exception as e:
        res["entities"] = False
        res["entity_error"] = _err(e)
    start = _eas().spawn_actor_from_class(unreal.PlayerStart, _v(PLAYER_START), _rot())
    _tag(start, "PlayerStart")


def _place_lights():
    sun = _eas().spawn_actor_from_class(unreal.DirectionalLight, unreal.Vector(0.0, 0.0, 500.0), _rot(SUN_YAW, -45.0))
    _tag(sun, "NeutralSun")
    lc = sun.get_component_by_class(unreal.DirectionalLightComponent)
    lc.set_intensity(SUN_LUX)
    lc.set_light_color(unreal.LinearColor(r=1.0, g=1.0, b=1.0, a=1.0))
    sky = _eas().spawn_actor_from_class(unreal.SkyLight, unreal.Vector(0.0, 0.0, 300.0), _rot())
    _tag(sky, "NeutralSky")
    sc = sky.get_component_by_class(unreal.SkyLightComponent)
    sc.set_editor_property("source_type", unreal.SkyLightSourceType.SLS_SPECIFIED_CUBEMAP)
    sc.set_editor_property("cubemap", unreal.load_asset(CUBEMAP))
    sc.set_intensity(SKY_INTENSITY)
    for label, (colour, cd, loc) in (("AmberKey", AMBER), ("TealFill", TEAL)):
        p = _eas().spawn_actor_from_class(unreal.PointLight, _v(loc), _rot())
        _tag(p, label)
        pc = p.get_component_by_class(unreal.PointLightComponent)
        pc.set_editor_property("intensity_units", unreal.LightUnits.CANDELAS)
        pc.set_intensity(cd)
        pc.set_light_color(unreal.LinearColor(r=colour[0], g=colour[1], b=colour[2], a=1.0))
        pc.set_attenuation_radius(1000.0)


def build_review_scene():
    """Opens (or creates) the review map, replaces every actor this module placed, saves only that map."""
    if _pie():
        return _pie()
    res = {"map": REVIEW_MAP, "previous_level": _world_package(), "created": False, "deleted": 0, "actors": 0,
           "saved": False, "error": None}
    try:
        if _world_package() != REVIEW_MAP:
            if unreal.EditorAssetLibrary.does_asset_exist(REVIEW_MAP):
                ok = _les().load_level(REVIEW_MAP)
            else:
                ok = _les().new_level(REVIEW_MAP, False)
                res["created"] = True
            if not ok or _world_package() != REVIEW_MAP:
                res["error"] = "could not open %s (current level %s)" % (REVIEW_MAP, _world_package())
                return res
        for a in list(_eas().get_all_level_actors()):
            if a.actor_has_tag(TAG_REVIEW) or a.get_actor_label().startswith(PREFIX):
                _eas().destroy_actor(a)
                res["deleted"] += 1
        _place_geometry()
        _place_displays()
        _place_entities(res)
        _place_lights()
        res["saved"] = bool(_les().save_current_level())
        res["actors"] = sum(1 for a in _eas().get_all_level_actors() if a.actor_has_tag(TAG_REVIEW))
    except Exception as e:
        res["error"] = _err(e)
    return res


def restore_level(path):
    """Loads the level that was open before build_review_scene (its previous_level)."""
    if _pie():
        return _pie()
    if not path or path.startswith("/Temp"):
        return {"loaded": False, "error": "no saved level to restore (%r)" % path}
    try:
        return {"loaded": bool(_les().load_level(path)), "current_level": _world_package(), "error": None}
    except Exception as e:
        return {"loaded": False, "error": _err(e)}


def open_review():
    if _pie():
        return _pie()
    prev = _world_package()
    ok = _world_package() == REVIEW_MAP or bool(_les().load_level(REVIEW_MAP))
    return {"loaded": ok, "previous_level": prev, "current_level": _world_package()}


def readback(out_path=None):
    import json
    rows = []
    for a in _eas().get_all_level_actors():
        if not (a.actor_has_tag(TAG_REVIEW) or a.get_actor_label().startswith(PREFIX)):
            continue
        loc, rot, scl = a.get_actor_location(), a.get_actor_rotation(), a.get_actor_scale3d()
        row = {"label": a.get_actor_label(), "class": a.get_class().get_name(),
               "location": [round(loc.x, 2), round(loc.y, 2), round(loc.z, 2)],
               "rotation_pyr": [round(rot.pitch, 2), round(rot.yaw, 2), round(rot.roll, 2)],
               "scale": [round(scl.x, 4), round(scl.y, 4), round(scl.z, 4)]}
        if isinstance(a, unreal.StaticMeshActor):
            m = a.static_mesh_component.static_mesh
            row["mesh"] = m.get_path_name() if m else None
        if isinstance(a, unreal.SkeletalMeshActor):
            m = a.skeletal_mesh_component.get_skinned_asset()
            row["mesh"] = m.get_path_name() if m else None
        rows.append(row)
    rows.sort(key=lambda r: r["label"])
    ws = _world().get_world_settings()
    gm = ws.get_editor_property("default_game_mode")
    res = {"level": _world_package(), "count": len(rows), "actors": rows,
           "game_mode_override": gm.get_path_name() if gm else None}
    if out_path:
        with open(out_path, "w") as f:
            json.dump(res, f, indent=2)
    return res


# --------------------------------------------------------------------------------------------------------------- captures
def _write_png_rgb(path, w, h, samples):
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for c in samples[y * w:(y + 1) * w]:
            raw.extend((c.r, c.g, c.b))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) +
                chunk(b"IDAT", zlib.compress(bytes(raw), 6)) + chunk(b"IEND", b""))


def _opaque_png(world, rt, path, w, h):
    rl = unreal.RenderingLibrary
    probes = [rl.read_render_target_pixel(world, rt, x, y) for x, y in ((w // 2, h // 2), (1, 1), (w - 2, h - 2))]
    if all(p.a == 255 for p in probes):
        return False
    r = rl.read_render_target(world, rt, True)
    samples = list(r[-1] if isinstance(r, tuple) else r)
    if len(samples) != w * h:
        raise RuntimeError("read_render_target returned %d samples, expected %d" % (len(samples), w * h))
    _write_png_rgb(path, w, h, samples)
    return True


def _views():
    """(name, camera location, look-at target, fov)."""
    # C3: the Phase C camera offsets from each target, x SCALE (the beds view: framed for the 72 cm beds' span instead)
    x, k = DISPLAYS_X, SCALE
    yp, yb, ye = BEDS_Y
    eye = (PLAYER_START[0], PLAYER_START[1], PLAYER_START[2] + 64.0)          # default BaseEyeHeight above the start
    planted = (x, yp, BED_BOTTOM + 3.0 * k)
    side = (x, ONSIDE_Y, SIDE_Z)
    mz = float(_M["sockets"]["MouthCue"]["root_relative_ue_cm"][2])
    beds_mid = (x, 0.5 * (yb + ye), 0.0)

    def off(t, d):
        return (t[0] + d[0] * k, t[1] + d[1] * k, t[2] + d[2] * k)
    return [
        ("room_from_playerstart", eye, (DISPLAYS_X, 0.0, 20.0), 90.0),
        ("fp_hand_height", eye, HAND, 90.0),
        ("planted_front", off(planted, (-60.0, 0.0, 5.6)), planted, 40.0),
        ("planted_threequarter", off(planted, (-45.0, 45.0, 23.6)), planted, 40.0),
        ("beds", (x - 180.0, beds_mid[1], 150.0), beds_mid, 60.0),
        ("onside", off(side, (-50.0, 35.0, 20.4)), side, 40.0),
        ("hand_mouth_closeup", (HAND[0] - 22.0 * k, 0.0, HAND[2] + mz), (HAND[0], 0.0, HAND[2] + mz), 50.0),
    ]


def capture_views(out_dir, size=(1280, 960)):
    if _pie():
        return _pie()
    res = {"written": [], "alpha_rewritten": [], "error": None}
    if _world_package() != REVIEW_MAP:
        res["error"] = "open %s first; current level is %s" % (REVIEW_MAP, _world_package())
        return res
    world, w, h = _world(), int(size[0]), int(size[1])
    os.makedirs(out_dir, exist_ok=True)
    cap, rt = None, None
    try:
        rt = unreal.RenderingLibrary.create_render_target2d(world, w, h, unreal.TextureRenderTargetFormat.RTF_RGBA8,
                                                             unreal.LinearColor(r=0.0, g=0.0, b=0.0, a=1.0), False, False)
        cap = _eas().spawn_actor_from_class(unreal.SceneCapture2D, unreal.Vector(0.0, 0.0, 100.0), _rot(), True)
        comp = cap.get_editor_property("capture_component2d")
        comp.set_editor_property("texture_target", rt)
        comp.set_editor_property("capture_source", unreal.SceneCaptureSource.SCS_FINAL_COLOR_LDR)
        comp.set_editor_property("capture_every_frame", False)
        comp.set_editor_property("capture_on_movement", False)
        comp.set_editor_property("always_persist_rendering_state", True)
        pp = comp.get_editor_property("post_process_settings")
        for k, v in (("override_auto_exposure_method", True), ("auto_exposure_method", unreal.AutoExposureMethod.AEM_MANUAL),
                     ("override_auto_exposure_apply_physical_camera_exposure", True),
                     ("auto_exposure_apply_physical_camera_exposure", False),
                     ("override_auto_exposure_bias", True), ("auto_exposure_bias", EXPOSURE_BIAS)):
            pp.set_editor_property(k, v)
        comp.set_editor_property("post_process_settings", pp)
        for name, loc, target, fov in _views():
            comp.set_editor_property("fov_angle", float(fov))
            cap.set_actor_location(_v(loc), False, True)
            cap.set_actor_rotation(unreal.MathLibrary.find_look_at_rotation(_v(loc), _v(target)), True)
            for _ in range(3):
                comp.capture_scene()
            fname = "UE_review_%s.png" % name
            unreal.RenderingLibrary.export_render_target(world, rt, out_dir, fname)
            path = os.path.abspath(os.path.join(out_dir, fname))
            if not os.path.isfile(path):
                raise RuntimeError("export_render_target wrote nothing at " + path)
            if _opaque_png(world, rt, path, w, h):
                res["alpha_rewritten"].append(name)
            res["written"].append(path)
    except Exception as e:
        res["error"] = _err(e)
    finally:
        if cap:
            _eas().destroy_actor(cap)
        if rt is not None:
            unreal.RenderingLibrary.release_render_target2d(rt)
    return res
