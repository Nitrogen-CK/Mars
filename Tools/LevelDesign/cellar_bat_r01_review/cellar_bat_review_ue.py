"""Cellar Bat R01 review room, built from Python inside the running editor (Phase 6b entry point).

Run through Monolith `editor_query run_python` (the route pale_crawler_ue.py proved), never through a console command that
loads levels inside the MCP request handler (that path hung the editor on 2026-11-05):

    import sys; sys.path.insert(0, r"D:/Repositories/CkRepos/Orion/Tools/LevelDesign/cellar_bat_r01_review")
    import importlib, cellar_bat_review_ue as m; importlib.reload(m)
    res = m.build_review_scene(); print(res)
    # ... review ... then
    print(m.restore_level(res["previous_level"]))

Bat-tracking captures (Phase 6b-2): capture_pie_movement_clip with view_target_actor = PREFIX + "CameraClose" and a probe
at ~0.5 s that runs `import cellar_bat_review_ue as m; m.chase_start()` (no reload inside PIE: the tick callback lives in
the module). chase_start() moves that camera after the bat every editor tick; it stops itself when PIE ends.

It mirrors Script/Editor/Mars_CellarBat_MapBuilder.as (the in-editor console command a human may run instead) and the
review presets in Script/WorldObjects/Monsters/Mars_SandboxBat.as: the room is 2000 x 2000 x 600 round the origin (floor
top at Z 0), the perch beam's underside at (-600, 0, 530), a pillar at the centre, the review dummy at (600, 0, 0). Entity
script actors are placed through the entity-spawner actor factory (EditorActorSubsystem.spawn_actor_from_object with the
AngelScript class), exactly as utils_mars_map_builder::Spawn_EntityScript does. Every actor it places is tagged
TAG_REVIEW and labelled with PREFIX; a rebuild deletes those first. Only the review map is saved.
"""

import traceback

import unreal

REVIEW_MAP = "/Game/ArtCandidates/CellarBat/R01/Review/CellarBat_R01_Review_MAP"
PREFIX = "CellarBatReview_"
TAG_REVIEW = "CellarBatR01Review"

CUBE = "/Engine/BasicShapes/Cube.Cube"
PROTOGRID = "/Game/Mars/Materials/ProtoGrid/ProtoGrid_%s_Mars_MI"
STONE = "/Game/Mars/Physics/Stone_Mars_PhysMat"

# AngelScript classes (the U prefix is dropped in the script package path).
AS = "/Script/Angelscript."
ROOST = AS + "Mars_BatRoost_EntityScript"
VOLUME = AS + "Mars_CellarBatReview_FlightVolume_EntityScript"
BAT = AS + "Mars_CellarBatReview_Bat_EntityScript"
DUMMY = AS + "Mars_CellarBatReview_TargetDummy_EntityScript"

ROOM_HALF, ROOM_HEIGHT, WALL = 1000.0, 600.0, 40.0
PERCH_ANCHOR = (-600.0, 0.0, 530.0)
HANG_OFFSET_Z = -80.0                                        # FMars_Bat_Roost.HangOffset default
VOLUME_CENTRE = (0.0, 0.0, 300.0)
DUMMY_LOCATION = (600.0, 0.0, 0.0)

SUN_LUX, SKY_INTENSITY = 3.0, 0.5                            # pale_crawler_ue.py neutral rig
AMBER = ((1.0, 0.55, 0.2), 8000.0, (750.0, 0.0, 300.0))      # colour, candela, location (over the dummy)
TEAL = ((0.2, 0.7, 0.8), 2500.0, (-800.0, -200.0, 150.0))    # behind the perch
CUBEMAP = "/Engine/MapTemplates/Sky/DaylightAmbientCubemap"


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


def _rot(yaw=0.0, pitch=0.0):
    return unreal.Rotator(roll=0.0, pitch=pitch, yaw=yaw)


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
    pm = unreal.load_asset(STONE)
    if pm:
        smc.set_phys_material_override(pm)
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
    _block("Ceiling", (0.0, 0.0, ROOM_HEIGHT + 10.0), (span, span, 20.0), "Wall")
    _block("WallNorth", (0.0, wo, wz), (span, WALL, ROOM_HEIGHT), "Wall")
    _block("WallSouth", (0.0, -wo, wz), (span, WALL, ROOM_HEIGHT), "Wall")
    _block("WallEast", (wo, 0.0, wz), (WALL, span, ROOM_HEIGHT), "Wall")
    _block("WallWest", (-wo, 0.0, wz), (WALL, span, ROOM_HEIGHT), "Wall")
    ax, ay, az = PERCH_ANCHOR
    _block("PerchBeam", (ax, ay, az + 10.0), (300.0, 20.0, 20.0), "Platform")
    _block("PerchPost", (ax, 0.0, (az + 20.0 + ROOM_HEIGHT) * 0.5), (20.0, 20.0, ROOM_HEIGHT - az - 20.0), "Platform")
    _block("Pillar", (0.0, 0.0, wz), (120.0, 120.0, ROOM_HEIGHT), "Wall")


def _place_entities():
    ax, ay, az = PERCH_ANCHOR
    _entity_script(ROOST, "Roost", PERCH_ANCHOR)
    _entity_script(VOLUME, "FlightVolume", VOLUME_CENTRE)
    _entity_script(BAT, "Bat", (ax, ay, az + HANG_OFFSET_Z))
    _entity_script(DUMMY, "TargetDummy", DUMMY_LOCATION, 180.0)
    start = _eas().spawn_actor_from_class(unreal.PlayerStart, unreal.Vector(850.0, -820.0, 100.0), _rot(150.0, -5.0))
    _tag(start, "PlayerStart")


def _place_lights():
    sun = _eas().spawn_actor_from_class(unreal.DirectionalLight, unreal.Vector(0.0, 0.0, 500.0), _rot(-150.0, -45.0))
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
    for label, (colour, cd, loc) in (("AmberLight", AMBER), ("TealLight", TEAL)):
        p = _eas().spawn_actor_from_class(unreal.PointLight, _v(loc), _rot())
        _tag(p, label)
        pc = p.get_component_by_class(unreal.PointLightComponent)
        pc.set_editor_property("intensity_units", unreal.LightUnits.CANDELAS)
        pc.set_intensity(cd)
        pc.set_light_color(unreal.LinearColor(r=colour[0], g=colour[1], b=colour[2], a=1.0))
        pc.set_attenuation_radius(1500.0)


def _place_cameras():
    """A fixed overview camera for PIE captures (capture_pie_movement_clip view_target_actor = PREFIX + 'Camera')."""
    cam = _eas().spawn_actor_from_class(unreal.CameraActor, unreal.Vector(950.0, -950.0, 560.0), _rot(137.9, -14.0))
    _tag(cam, "Camera")
    cc = cam.get_component_by_class(unreal.CameraComponent)
    cc.set_editor_property("field_of_view", 90.0)
    cc.set_editor_property("constrain_aspect_ratio", False)
    close = _eas().spawn_actor_from_class(unreal.CameraActor, unreal.Vector(250.0, -450.0, 330.0), _rot(55.0, -16.4))
    _tag(close, "CameraClose")
    ccc = close.get_component_by_class(unreal.CameraComponent)
    ccc.set_editor_property("field_of_view", 70.0)
    ccc.set_editor_property("constrain_aspect_ratio", False)
    # The amber key over the dummy (8000 cd at 3 m) blows auto exposure out round the strike: pull the bias down for review.
    ppv = _eas().spawn_actor_from_class(unreal.PostProcessVolume, unreal.Vector(0.0, 0.0, 300.0), _rot())
    _tag(ppv, "Exposure")
    ppv.set_editor_property("unbound", True)
    settings = ppv.get_editor_property("settings")
    settings.set_editor_property("override_auto_exposure_bias", True)
    settings.set_editor_property("auto_exposure_bias", -2.5)
    ppv.set_editor_property("settings", settings)


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
        _place_entities()
        _place_lights()
        _place_cameras()
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


def readback(out_path=None):
    """Every actor in the open editor level this module placed: label, class, location, rotation, scale (and, for entity
    spawners, the script class). Written as JSON to out_path when given."""
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
        for prop in ("_EntityScript", "entity_script", "_entity_script"):
            try:
                v = a.get_editor_property(prop)
                row["entity_script"] = v.get_class().get_name() if v else None
                break
            except Exception:
                pass
        if isinstance(a, unreal.StaticMeshActor):
            smc = a.static_mesh_component
            row["collision_profile"] = str(smc.get_collision_profile_name())
            row["mobility"] = str(smc.mobility)
        rows.append(row)
    rows.sort(key=lambda r: r["label"])
    res = {"level": _world_package(), "count": len(rows), "actors": rows}
    if out_path:
        with open(out_path, "w") as f:
            json.dump(res, f, indent=2)
    return res


def _pie_scripts(class_path):
    cls = unreal.load_class(None, class_path)
    if cls is None:
        return []
    return [o for o in unreal.ObjectIterator(cls) if "UEDPIE" in o.get_path_name()]


def probe(tag="probe"):
    """PIE only: one line per live review bat (Review_Describe) and dummy (Review_DamagedCount), printed with a
    CELLARBAT_PROBE marker so the log keeps them in order with the [CellarBat] phase lines."""
    out = {"tag": tag, "bats": [], "dummies": []}
    for o in _pie_scripts(BAT):
        out["bats"].append(o.call_method("Review_Describe"))
    for o in _pie_scripts(DUMMY):
        out["dummies"].append(o.call_method("Review_DamagedCount"))
    unreal.log("CELLARBAT_PROBE %s" % out)
    return out


def kill(tag="kill"):
    """PIE only: a lethal blow on every live review bat's body health (Review_Kill), then a probe."""
    n = 0
    for o in [o for o in _pie_scripts(BAT) if o.call_method("Review_Describe") != "invalid"]:
        o.call_method("Review_Kill")
        n += 1
    unreal.log("CELLARBAT_KILL %s bats=%d" % (tag, n))
    return n


def free_grid(points, tag="free"):
    """PIE only: Review_IsPointFree for each (x, y, z) on the first live review bat; logged with CELLARBAT_FREE."""
    bats = [o for o in _pie_scripts(BAT) if o.call_method("Review_Describe") != "invalid"]
    if not bats:
        return None
    res = [(p, bool(bats[0].call_method("Review_IsPointFree", (unreal.Vector(*p),)))) for p in points]
    unreal.log("CELLARBAT_FREE %s %s" % (tag, res))
    return res


def retire_dummy(tag="retire"):
    """PIE only: Review_Retire on every live review dummy."""
    n = 0
    for o in _pie_scripts(DUMMY):
        o.call_method("Review_Retire")
        n += 1
    unreal.log("CELLARBAT_RETIRE %s dummies=%d" % (tag, n))
    return n


def set_pillar_block(block):
    """Editor world: stretch the pillar into a full-width, full-height wall across X=0 (block=True) or put it back.
    Leaves the map dirty: rebuild (build_review_scene) to save the clean room again."""
    for a in _eas().get_all_level_actors():
        if a.get_actor_label() == PREFIX + "Pillar":
            a.set_actor_scale3d(unreal.Vector(1.2, 20.0, 6.0) if block else unreal.Vector(1.2, 1.2, 6.0))
            return a.get_actor_scale3d()
    return None


# ---------------------------------------------------------------------------------------------------------------------
# Chase camera (Phase 6b-2): the review map's CameraClose, in the PIE world, follows the bat every editor tick
# ---------------------------------------------------------------------------------------------------------------------
#
# A Slate post-tick callback (editor Python, game thread) reads the live review bat's root (Review_Location), moves the
# PIE copy of PREFIX + "CameraClose" to bat + offset (smoothed), aims it at the bat and keeps it the player's view target,
# so capture_pie_movement_clip frames the bat itself. Start it from a probe (after possession) with chase_start(); it
# stops itself when PIE ends (chase_stop() also works). Every CHASE_LOG_SECONDS it logs CELLARBAT_CHASE with the bat
# location and the camera distance, so captured frames can be matched to the [CellarBat] phase lines.

CHASE_CAMERA = PREFIX + "CameraClose"
CHASE_LOG_SECONDS = 0.5
_chase = {"handle": None}


def _game_world():
    return unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_game_world()


def _chase_tick(delta):
    st = _chase
    world = _game_world()
    if world is None:
        chase_stop("pie ended")
        return
    try:
        bat = st.get("bat")
        if bat is None:
            # PIE can hold a second, entity-less instance of the review class (Review_Describe answers "invalid"): skip it.
            live = [o for o in _pie_scripts(BAT) if o.call_method("Review_Describe") != "invalid"]
            if not live:
                return
            bat = st["bat"] = live[0]
        here = bat.call_method("Review_Location")
        if here.x == 0.0 and here.y == 0.0 and here.z == 0.0:
            here = st.get("last_bat") or here     # the bat is gone (the corpse despawned): hold the last view
        prev = st.get("last_bat")
        st["last_bat"] = here
        # Lead by one tick of the bat's velocity: the frame rendered next uses this camera, and a swoop (900 cm/s at a
        # capture-slowed frame rate) otherwise leaves the frame between the update and the render.
        lead = st["lead"]
        if prev is not None and delta > 0.0:
            here = unreal.Vector(here.x + (here.x - prev.x) * lead, here.y + (here.y - prev.y) * lead, here.z + (here.z - prev.z) * lead)
        ax, ay, az = st.get("aim", (0.0, 0.0, 0.0))
        here = unreal.Vector(here.x + ax, here.y + ay, here.z + az)   # aim point: the root + aim (the hang hangs above it)
        ox, oy, oz = st["offset"]
        want = unreal.Vector(here.x + ox, here.y + oy, here.z + oz)
        pos = st.get("pos") or want
        a = min(1.0, max(0.0, delta * st["follow_rate"]))
        pos = unreal.Vector(pos.x + (want.x - pos.x) * a, pos.y + (want.y - pos.y) * a, pos.z + (want.z - pos.z) * a)
        st["pos"] = pos
        cam = st["cam"]
        rot = unreal.MathLibrary.find_look_at_rotation(pos, here)
        cam.set_actor_location_and_rotation(pos, rot, False, True)
        pc = unreal.GameplayStatics.get_player_controller(world, 0)
        if pc and pc.get_view_target() != cam:
            pc.set_view_target_with_blend(cam, 0.0)
        st["clock"] += delta
        if st["clock"] >= st["next_log"]:
            st["next_log"] += CHASE_LOG_SECONDS
            d = ((pos.x - here.x) ** 2 + (pos.y - here.y) ** 2 + (pos.z - here.z) ** 2) ** 0.5
            unreal.log("CELLARBAT_CHASE t=%.2f bat=(%.0f,%.0f,%.0f) cam_dist=%.0f" % (st["clock"], here.x, here.y, here.z, d))
    except Exception as e:
        unreal.log_warning("CELLARBAT_CHASE error %s" % e)
        chase_stop("error")


def chase_start(offset=(0.0, -190.0, 60.0), fov=60.0, follow_rate=10.0, lead=1.0, aim=(0.0, 0.0, 0.0)):
    """PIE only: start the chase camera (see the section comment). Returns a status dict."""
    chase_stop("restart")
    world = _game_world()
    if world is None:
        return {"error": "no PIE world"}
    cams = [c for c in unreal.GameplayStatics.get_all_actors_of_class(world, unreal.CameraActor)
            if c.get_actor_label() == CHASE_CAMERA]
    if not cams:
        return {"error": "no PIE actor labelled %s" % CHASE_CAMERA}
    cam = cams[0]
    cc = cam.get_component_by_class(unreal.CameraComponent)
    cc.set_editor_property("field_of_view", float(fov))
    cc.set_editor_property("constrain_aspect_ratio", False)
    _chase.update({"cam": cam, "bat": None, "pos": None, "last_bat": None, "offset": tuple(offset),
                   "follow_rate": float(follow_rate), "lead": float(lead), "clock": 0.0, "next_log": 0.0,
                   "aim": tuple(aim)})
    _chase["handle"] = unreal.register_slate_post_tick_callback(_chase_tick)
    unreal.log("CELLARBAT_CHASE start offset=%s fov=%s" % (offset, fov))
    return {"camera": cam.get_name(), "offset": offset, "fov": fov}


def chase_stop(reason="stop"):
    h = _chase.get("handle")
    if h is not None:
        unreal.unregister_slate_post_tick_callback(h)
        _chase["handle"] = None
        unreal.log("CELLARBAT_CHASE stop (%s)" % reason)


def chase_set(offset=None, fov=None, aim=None):
    """PIE only: change the running chase camera's offset, FOV and/or aim (added to the bat's root; the next tick eases
    to it)."""
    if offset is not None:
        _chase["offset"] = tuple(offset)
    if aim is not None:
        _chase["aim"] = tuple(aim)
    if fov is not None and _chase.get("cam"):
        _chase["cam"].get_component_by_class(unreal.CameraComponent).set_editor_property("field_of_view", float(fov))
    unreal.log("CELLARBAT_CHASE set offset=%s fov=%s" % (_chase.get("offset"), fov))
    return {"offset": _chase.get("offset"), "fov": fov}


# ---------------------------------------------------------------------------------------------------------------------
# Phase 6b-2 final review helpers (PIE only unless noted)
# ---------------------------------------------------------------------------------------------------------------------

FINAL_MESH = "/Game/ArtCandidates/CellarBat/R01/Meshes/CellarBat_R01_Mars_SK"


def open_review():
    """Editor world: open the saved review map without rebuilding it. Returns the previous level for restore_level."""
    if _pie():
        return _pie()
    prev = _world_package()
    ok = _world_package() == REVIEW_MAP or bool(_les().load_level(REVIEW_MAP))
    return {"loaded": ok, "previous_level": prev, "current_level": _world_package()}


def damage(amount, tag="damage"):
    """A blow of `amount` through each live review bat's body zone (Review_Damage): under StunDamage (20) a Hit, at or over
    it a Stun."""
    n = 0
    for o in [o for o in _pie_scripts(BAT) if o.call_method("Review_Describe") != "invalid"]:
        o.call_method("Review_Damage", (float(amount),))
        n += 1
    unreal.log("CELLARBAT_DAMAGE %s amount=%s bats=%d" % (tag, amount, n))
    return n


def _pie_actor(label):
    world = _game_world()
    if world is None:
        return None
    for a in unreal.GameplayStatics.get_all_actors_of_class(world, unreal.Actor):
        if a.get_actor_label() == PREFIX + label:
            return a
    return None


RIG_KEY_OFFSET = (220.0, -160.0, -10.0)     # key light from the bat's front-left, level (the perch beam shades a key from above)
RIG_FILL_OFFSET = (-220.0, 160.0, -40.0)    # fill from behind-right, below
RIG_KEY_CD, RIG_FILL_CD = 1200.0, 400.0
_rig_saved = {}


def set_rig(mode, tag="rig", at=None):
    """The two review point lights in the PIE world, brought to the bat for a palette judgement: 'neutral' (white key +
    white fill), 'amberteal' (the map's amber key + teal fill colours), same positions and intensities in both, so only the
    colour differs; 'map' puts both back as built. The sun and sky are left alone (the closed room shades them out)."""
    amber, teal = _pie_actor("AmberLight"), _pie_actor("TealLight")
    if amber is None or teal is None:
        return {"error": "no PIE review lights"}
    for a in (amber, teal):
        c = a.get_component_by_class(unreal.PointLightComponent)
        if a.get_name() not in _rig_saved:
            _rig_saved[a.get_name()] = (a.get_actor_location(), c.get_editor_property("light_color"), c.get_editor_property("intensity"))
    if mode == "map":
        for a in (amber, teal):
            loc, col, inten = _rig_saved[a.get_name()]
            c = a.get_component_by_class(unreal.PointLightComponent)
            a.set_actor_location(loc, False, True)
            c.set_light_color(unreal.LinearColor(r=col.r / 255.0, g=col.g / 255.0, b=col.b / 255.0, a=1.0))
            c.set_intensity(inten)
        unreal.log("CELLARBAT_RIG %s mode=map" % tag)
        return {"mode": mode}
    if at is not None:
        here = unreal.Vector(float(at[0]), float(at[1]), float(at[2]))   # a fixed spot (e.g. the strike zone)
    else:
        bats = [o for o in _pie_scripts(BAT) if o.call_method("Review_Describe") != "invalid"]
        here = bats[0].call_method("Review_Location") if bats else unreal.Vector(0.0, 0.0, 300.0)
        here = unreal.Vector(here.x, here.y, here.z + _chase.get("aim", (0.0, 0.0, 0.0))[2])
    white = (1.0, 1.0, 1.0)
    for a, off, cd, colour in ((amber, RIG_KEY_OFFSET, RIG_KEY_CD, white if mode == "neutral" else AMBER[0]),
                               (teal, RIG_FILL_OFFSET, RIG_FILL_CD, white if mode == "neutral" else TEAL[0])):
        c = a.get_component_by_class(unreal.PointLightComponent)
        a.set_actor_location(unreal.Vector(here.x + off[0], here.y + off[1], here.z + off[2]), False, True)
        c.set_intensity(cd)
        c.set_light_color(unreal.LinearColor(r=colour[0], g=colour[1], b=colour[2], a=1.0))
    unreal.log("CELLARBAT_RIG %s mode=%s at=(%.0f,%.0f,%.0f) key=%s cd fill=%s cd" % (tag, mode, here.x, here.y, here.z, RIG_KEY_CD, RIG_FILL_CD))
    return {"mode": mode}


def _bat_meshes():
    return [c for c in unreal.ObjectIterator(unreal.SkeletalMeshComponent) if "UEDPIE" in c.get_path_name()
            and c.get_skinned_asset() is not None and c.get_skinned_asset().get_path_name().startswith(FINAL_MESH)]


def force_lod(lod, tag="lod"):
    """Forces the bat mesh's LOD: 0 = automatic, N = LOD N-1 (SkinnedMeshComponent.set_forced_lod)."""
    comps = _bat_meshes()
    for c in comps:
        c.set_forced_lod(int(lod))
    unreal.log("CELLARBAT_LOD %s forced=%s components=%d" % (tag, lod, len(comps)))
    return len(comps)


def mesh_info(tag="mesh"):
    """The live bat mesh components: asset, anim class, materials, bounds radius (logged CELLARBAT_MESH)."""
    out = []
    for c in _bat_meshes():
        inst = c.get_anim_instance()
        origin, extent, radius = unreal.SystemLibrary.get_component_bounds(c)
        out.append({"comp": c.get_path_name().rsplit(".", 1)[-1], "anim": inst.get_class().get_name() if inst else None,
                    "materials": [m.get_name() if m else None for m in c.get_materials()],
                    "bounds_radius": round(radius, 1), "bounds_extent": [round(extent.x, 1), round(extent.y, 1), round(extent.z, 1)]})
    unreal.log("CELLARBAT_MESH %s %s" % (tag, out))
    return out
