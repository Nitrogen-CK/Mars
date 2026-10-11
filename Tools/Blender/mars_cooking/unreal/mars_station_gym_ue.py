"""Editor side of the Mars STATION GYM: /Game/Mars/Maps/StationGym_Mars_MAP, the playable cooking stations standing in a
great kitchen built from the Mise en Monstre crypt kit, under warm firelight.  Where StationLookdev_Mars_MAP shows the
station props alone under the gyms' neutral lighting, this map shows them in the level art they are meant for.

The kitchen is planned off-repo by the kit (vns_trim_sheet/assets/crypt_kitchen.py, exported by
Blender/tests/export_station_gym.py to <kit export>/rooms/station_gym_kitchen.json): a 24 x 32 m rib-vaulted hall, the
great hearth in the nave, the beast-mouth furnace in the back wall, a bay per station against the walls, two prep
islands laden with the food library under pot racks, garlic and herb rails, lanterns on chains.  This module spawns
that plan and everything Mars adds to it.  Run in the editor's Python (Monolith `editor_query run_python`), not in PIE:

    import sys, importlib
    sys.path.insert(0, r"D:\\Repo\\Mars\\Tools\\Blender\\mars_cooking\\unreal")
    import mars_station_gym_ue as mg; importlib.reload(mg)
    mg.import_kitchen_art()                 # once / after the Blender builders ran: furnace, rack and hanging meshes
    mg.build_gym_map()                      # the map, rebuilt (its own folders only), saved, Jolt cooked
    mg.capture(r"D:\\Repo\\Content\\Cooking\\export\\stations\\review\\gym")     # in a SEPARATE call
    mg.apply_look()                         # after editing LOOK: re-applies lights / fog / grade to the open gym map

What is spawned (outliner folders):
  Mise_Gym/Shell      ONE actor holding the architecture as HISM components: walls, floors, roofs, vault ribs, engaged
                      columns, carved courses (anything a room is, as opposed to what stands in it)
  Mise_Gym/Pieces/..  everything of the kit that stands in the room, one StaticMeshActor each so it can be moved: piers
                      (with their fork capitals), crates, barrels, benches, banners, boards, rugs, chain hooks and eyes
  Mise_Gym/Chains     AMars_HangingChain lanterns and garlands;  Mise_Gym/Racks  AMars_HangingRack pot racks and rails
  StationGym/Stations one ACk_EntitySpawner_UE per plan station (Mars_<Name>Station_EntityScript), yawed to its wall
  StationGym/Islands, /Candles, /Furnace   the plan's Mars meshes, one actor each (food and candles without collision)
  StationGym/Lights   the plan's lamps as movable point lights (watts x LOOK light_scale; tagged with their watts)
  StationGym/Rig      warm height fog, flat ambient, reflection captures, the grade
  StationGym/Starts   four PlayerStarts inside the south arch
What rides on something is attached to it (the plan's "on" / "of" keys): food to its table, candles and their flame
light to their crate, a capital to its pier, a lantern's light and wall eye to its chain - move the parent and the rest
follows.

Rebuilds keep hand edits.  Every spawned actor is tagged with its plan key and the transform it was built at; a
rebuild puts an actor that was moved back where it was moved to (as long as the plan still has that piece in the same
place) and does not respawn one that was deleted.  build_gym_map(reset_moved=True) / (restore_deleted=True) undo that.
The map takes AMars_Gameplay_GameMode as its World Settings override (no DefaultEngine.ini entry needed).
"""
import importlib
import json
import os
import random
import sys

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import mars_cooking_ue as mc  # noqa: E402

KIT_EXPORT = os.environ.get("MISE_KIT_EXPORT", r"C:\Users\Stephen\Documents\Houdini\Blender\export\crypt_kit")
KITCHEN_EXPORT = os.path.join(mc.spec.EXPORT_DIR, "kitchen")     # build_station_kitchen.py's FBX + sidecars
ROOM = "station_gym_kitchen"
GYM_MAP = "/Game/Mars/Maps/StationGym_Mars_MAP"
GAME_MODE = "/Script/Angelscript.Mars_Gameplay_GameMode"
STATION_CLASS = "/Script/Angelscript.Mars_%sStation_EntityScript"
# plan station name -> script name where they differ (the dicing station became the generic cutting station)
STATION_SCRIPT = {"Dicing": "Cutting"}
RACK_CLASS = "/Script/Angelscript.Mars_HangingRack"
MESH_FOLDERS = ("/Game/Mars/Gameplay/Cooking/Stations/Meshes", "/Game/Mars/Gameplay/Cooking/Food/Meshes",
                "/Game/Mars/Gameplay/Cooking/Meshes", "/Game/Mars/Gameplay/Cooking/Candles/Meshes")
KIT_FOLDER, GYM_FOLDER = "Mise_Gym", "StationGym"
AMBIENT_CUBE = "/Engine/EngineResources/GrayLightTextureCube"
# dressing mesh -> {slot name: instance}: the slab's own slots are unassigned (the dicing station draws its copy with
# these flat tints)
F_STATION_MAT = "/Game/Mars/Gameplay/Cooking/Stations/Materials"
DRESSING_MATERIALS = {"MeatSlab_Mars_SM": {"Flesh": "MeatSlabFlesh_Mars_MI", "Skin": "MeatSlabFat_Mars_MI"}}
# What of the kit is spawned as its own actor: the manifest groups that stand in a room, and the freestanding supports.
LOOSE_GROUPS = ("box", "camp", "chain", "landmark", "platform")
LOOSE_PIECES = ("crypt_capital_fork", "crypt_finial_potlid")
LOOSE_PREFIXES = ("crypt_pier_",)
NO_COLLISION_GROUPS = ("food", "candle")
UU = 100.0
WATTS_TAG, KEY_TAG, HOME_TAG = "watts=", "key=", "home="
RECORD_LABEL = "Gym_BuildRecord"
NO_BAKE_TAG = "Ck.Jolt.NoBake"

# The look, in one place (apply_look re-applies it to the open gym map without a rebuild).
LOOK = {
    "exposure_bias": 8.7,                    # manual exposure, near the kit rig's level: the lamps carry the scene
    "light_scale": 2.4,                      # on every plan lamp (watts x mise_mars_ue.CD_PER_WATT candelas)
    # a flat ambient (a SkyLight on a constant cubemap: no capture, no sky): the stone still reads in the corners no
    # lamp reaches.  Keep it low: it is what flattens the room when it is raised
    "ambient": 0.03, "ambient_color": (255, 222, 196),
    "light_radius": 1400.0,
    "fog_density": 0.022, "fog_falloff": 0.08,
    "fog_inscatter": (0.30, 0.15, 0.055),    # warm amber haze instead of the crypt's teal
    "fog_albedo": (255, 214, 170),
    "fog_scatter": 1.5,                      # volumetric scattering of the lamps
    "sun_lux": 14.0, "sun_color": (255, 206, 150), "sun_scatter": 5.0, "sun_angle": 1.2,   # only if the plan has a sun
    "bloom": 0.6, "vignette": 0.45,
    "white_temp": 7200.0,                    # the grade's white balance: above 6500 warms the whole frame
    "contrast": (1.07, 1.07, 1.07),
    "gain_shadows": (0.96, 0.98, 1.04), "gain_highlights": (1.08, 1.0, 0.88), "saturation": (1.12, 1.12, 1.12),
}


def _log(msg):
    unreal.log("[station gym] %s" % msg)


def _warn(msg):
    unreal.log_warning("[station gym] %s" % msg)


def _mm(export_dir):
    """The kit's own Unreal helper, from the export it belongs to."""
    path = os.path.join(export_dir, "unreal")
    if path not in sys.path:
        sys.path.insert(0, path)
    import mise_mars_ue as mm
    return importlib.reload(mm)


def _plan(export_dir):
    path = os.path.join(export_dir, "rooms", ROOM + ".json")
    if not os.path.isfile(path):
        raise RuntimeError("no kitchen plan at %s (run Blender/tests/export_station_gym.py)" % path)
    with open(path) as fh:
        return path, json.load(fh)


def _origin(data):
    """The plan's hearth (0, length / 2) lands on the Unreal origin."""
    return (0.0, data["generator"]["length"] * UU / 2.0, 0.0)


def _ue(origin, x, y, z):
    return (origin[0] + x * UU, origin[1] - y * UU, origin[2] + z * UU)


def _eas():
    return unreal.get_editor_subsystem(unreal.EditorActorSubsystem)


def _color(rgb):
    return unreal.Color(r=int(rgb[0]), g=int(rgb[1]), b=int(rgb[2]), a=255)


def _own(actor):
    return str(actor.get_folder_path()).startswith((KIT_FOLDER, GYM_FOLDER))


def _mesh(name):
    for folder in MESH_FOLDERS:
        mesh = mc._asset(folder, name)
        if mesh is not None:
            return mesh
    return None


# ------------------------------------------------------------------ keys: what was built, moved, deleted
def _tag(actor, prefix):
    for t in actor.get_editor_property("tags"):
        s = str(t)
        if s.startswith(prefix):
            return s[len(prefix):]
    return None


def _pose(actor):
    t = actor.get_actor_transform()
    l, r, s = t.translation, t.rotation.rotator(), t.scale3d
    return (l.x, l.y, l.z, r.pitch, r.yaw, r.roll, s.x, s.y, s.z)


def _pose_text(pose):
    return ",".join("%.1f" % v for v in pose)


def _same_pose(a, b):
    def turn(u, v):
        return abs((u - v + 180.0) % 360.0 - 180.0)
    return (all(abs(a[i] - b[i]) < 0.6 for i in (0, 1, 2)) and all(turn(a[i], b[i]) < 0.6 for i in (3, 4, 5))
            and all(abs(a[i] - b[i]) < 0.01 for i in (6, 7, 8)))


class _Registry:
    """The actors of one build by plan key.  register() tags an actor with its key and the pose it was built at;
    snapshot() reads those tags back off a map built earlier."""

    def __init__(self):
        self.actors = {}

    def register(self, key, actor):
        if actor is None:
            return None
        if key in self.actors:
            _warn("key %s is used twice" % key)
        tags = [t for t in actor.get_editor_property("tags") if not str(t).startswith((KEY_TAG, HOME_TAG))]
        tags += [unreal.Name(KEY_TAG + key), unreal.Name(HOME_TAG + _pose_text(_pose(actor)))]
        actor.set_editor_property("tags", tags)
        self.actors[key] = actor
        return actor

    def attach(self, child_key, parent_key):
        child, parent = self.actors.get(child_key), self.actors.get(parent_key)
        if child is None or parent is None:
            return False
        keep = unreal.AttachmentRule.KEEP_WORLD
        child.attach_to_actor(parent, "", keep, keep, keep, False)
        return True

    def depth(self, key):
        n, a = 0, self.actors[key].get_attach_parent_actor()
        while a is not None and n < 16:
            n, a = n + 1, a.get_attach_parent_actor()
        return n


def snapshot():
    """{key: (pose now, pose it was built at)} for every keyed actor of the open map, and the keys the last build
    recorded (so a key that was built and is gone was deleted by hand)."""
    now, built = {}, set()
    for a in _eas().get_all_level_actors():
        if not _own(a):
            continue
        if a.get_actor_label() == RECORD_LABEL:
            built = {str(t)[len(KEY_TAG):] for t in a.get_editor_property("tags") if str(t).startswith(KEY_TAG)}
            continue
        key, home = _tag(a, KEY_TAG), _tag(a, HOME_TAG)
        if key is None or home is None:
            continue
        try:
            now[key] = (_pose(a), tuple(float(v) for v in home.split(",")))
        except ValueError:
            pass
    return now, built


def _write_record(keys):
    a = mc._spawn(unreal.Actor, (0.0, 0.0, 0.0), label=RECORD_LABEL, folder=GYM_FOLDER + "/Rig")
    a.set_editor_property("tags", [unreal.Name(KEY_TAG + k) for k in sorted(keys)])
    return a


def restore_hand_edits(reg, before, built_before, reset_moved=False, restore_deleted=False):
    """Apply what was done by hand to the fresh build: destroy what had been deleted, move what had been moved (parents
    first, so a child that was only carried along by its parent lands where it was)."""
    deleted = (built_before - set(before)) if not restore_deleted else set()
    gone = 0
    for key in sorted(deleted):
        a = reg.actors.pop(key, None)
        if a is not None:
            a.destroy_actor()
            gone += 1
    moved = 0
    if not reset_moved:
        todo = []
        for key, a in reg.actors.items():
            if key not in before:
                continue
            was, home = before[key]
            fresh = tuple(float(v) for v in _tag(a, HOME_TAG).split(","))
            if _same_pose(home, fresh) and not _same_pose(was, home):
                todo.append((reg.depth(key), key, was))
        for _, key, was in sorted(todo):
            a = reg.actors[key]
            a.set_actor_transform(unreal.Transform(unreal.Vector(*was[0:3]), unreal.Rotator(roll=was[5], pitch=was[3], yaw=was[4]),
                                                   unreal.Vector(*was[6:9])), False, False)
            if hasattr(a, "call_method") and a.get_class().get_name() in ("Mars_HangingChain", "Mars_HangingRack"):
                a.call_method("Rebuild")
            moved += 1
    return {"kept_deleted": gone, "kept_moved": moved, "deleted_keys": sorted(deleted)}


# ------------------------------------------------------------------ the kit: shell (instanced) + pieces (actors)
def _is_loose(piece, entry):
    return entry.get("group") in LOOSE_GROUPS or piece in LOOSE_PIECES or piece.startswith(LOOSE_PREFIXES)


def spawn_kit(data, origin, mm, export_dir, biome, reg):
    """The plan's placements: the architecture as one HISM actor, everything that stands in the room as its own
    StaticMeshActor.  Returns (instanced count, actor count)."""
    man = mm._manifest(export_dir)
    pieces = mm._pieces(man)
    ox, oy, oz = origin
    name = data["name"]
    shell, loose, cache = {}, [], {}
    for d in data["placements"]:
        e = pieces.get(d["piece"])
        if e is None:
            _warn("%s is not in the kit manifest" % d["piece"])
            continue
        if d["piece"] not in cache:
            cache[d["piece"]] = mm._asset(e["ue_folder"], e["ue_name"])
            if cache[d["piece"]] is None:
                _warn("kit mesh %s is not imported" % e["ue_name"])
        if cache[d["piece"]] is None:
            continue
        x, y, z = mm.to_ue(d["x"], d["y"], d["z"])
        sc = d.get("scale", 1.0)
        scale = tuple(sc) if isinstance(sc, list) else (sc, sc, sc)
        if _is_loose(d["piece"], e):
            loose.append((d, e, (ox + x, oy + y, oz + z), scale))
        else:
            shell.setdefault(d["piece"], []).append(mm._xf((ox + x, oy + y, oz + z), -d["rot"], scale))
    actor = mm._hism_actor("Gym_Shell", KIT_FOLDER + "/Shell", origin)
    for piece, xfs in sorted(shell.items()):
        mm._hism(actor, cache[piece], xfs, mm._biome_mats(cache[piece], biome, man))
    for a in mm._sockets_lights(data, origin, name, KIT_FOLDER + "/Shell", True, False):
        pass
    count = {}
    for d, e, loc, scale in loose:
        mesh = cache[d["piece"]]
        n = count[e["ue_name"]] = count.get(e["ue_name"], 0) + 1
        a = mm._spawn_mesh(mesh, loc, -d["rot"], "%s_%02d" % (e["ue_name"].replace("_Mars_SM", ""), n),
                           "%s/Pieces/%s" % (KIT_FOLDER, e.get("group", "piece")))
        a.set_actor_scale3d(unreal.Vector(*scale))
        for k, mi in mm._biome_mats(mesh, biome, man).items():
            a.static_mesh_component.set_material(k, mi)
        reg.register(d["key"], a)
    return sum(len(v) for v in shell.values()), len(loose)


def spawn_dressing(data, origin, reg):
    """The plan's Mars meshes, one StaticMeshActor each; food and candles carry no collision (a turnip must not trip
    the chef) and stay out of the Jolt bake; each candle group gets its own flicker phase."""
    rng = random.Random(7)
    folders = {"candle": "Candles", "furnace": "Furnace"}
    n, count = 0, {}
    for d in data.get("dressing", []):
        mesh = _mesh(d["mesh"])
        if mesh is None:
            _warn("dressing mesh %s not found" % d["mesh"])
            continue
        short = d["mesh"].replace("_Mars_SM", "")
        k = count[short] = count.get(short, 0) + 1
        a = mc._spawn(mesh, _ue(origin, d["x"], d["y"], d["z"]), (float(d.get("roll", 0.0)), 0.0, -float(d["rot"])),
                      "%s_%02d" % (short, k), "%s/%s" % (GYM_FOLDER, folders.get(d.get("group"), "Islands")))
        s = d.get("scale", 1.0)
        a.set_actor_scale3d(unreal.Vector(s, s, s))
        comp = a.static_mesh_component
        for i, slot in enumerate(mesh.get_editor_property("static_materials")):
            mi = DRESSING_MATERIALS.get(d["mesh"], {}).get(str(slot.get_editor_property("material_slot_name")))
            if mi and mc._asset(F_STATION_MAT, mi) is not None:
                comp.set_material(i, mc._asset(F_STATION_MAT, mi))
        if d.get("group") in NO_COLLISION_GROUPS:
            comp.set_collision_profile_name("NoCollision")
            comp.set_editor_property("component_tags", [unreal.Name(NO_BAKE_TAG)])
            a.set_editor_property("tags", list(a.get_editor_property("tags")) + [unreal.Name(NO_BAKE_TAG)])
        if d.get("group") == "candle":             # CandleFlame / CandleWax read primitive data 0 as a phase offset
            comp.set_default_custom_primitive_data_float(0, rng.random())
        reg.register(d["key"], a)
        n += 1
    return n


def spawn_lights(data, origin, reg):
    """The plan's lamps: movable point lights in candelas, each tagged with its plan watts so apply_look can rescale."""
    mm_cd = 0.08                                   # mise_mars_ue.CD_PER_WATT
    n = 0
    for k, l in enumerate(data.get("lights", [])):
        a = mc._spawn(unreal.PointLight, _ue(origin, l["x"], l["y"], l["z"]), label="Gym_Light_%02d" % k,
                      folder=GYM_FOLDER + "/Lights")
        a.set_editor_property("tags", [unreal.Name("%s%g" % (WATTS_TAG, l["watts"]))])
        c = a.point_light_component
        c.set_mobility(unreal.ComponentMobility.MOVABLE)
        c.set_editor_property("intensity_units", unreal.LightUnits.CANDELAS)
        c.set_editor_property("intensity", l["watts"] * mm_cd * LOOK["light_scale"])
        r, g, b = [max(0, min(255, int(v * 255))) for v in l.get("color", (1.0, 0.62, 0.32))]
        c.set_editor_property("light_color", unreal.Color(r=r, g=g, b=b, a=255))
        c.set_editor_property("attenuation_radius", LOOK["light_radius"])
        c.set_editor_property("source_radius", 6.0)
        c.set_editor_property("cast_shadows", bool(l.get("shadow", False)))
        c.set_editor_property("volumetric_scattering_intensity", LOOK["fog_scatter"])
        reg.register(l["key"], a)
        n += 1
    return n


def spawn_chains(data, origin, mm, export_dir, reg):
    pieces = mm._pieces(mm._manifest(export_dir))
    n = mm.spawn_chains(data, origin, pieces, folder=KIT_FOLDER + "/Chains")
    by_label = {a.get_actor_label(): a for a in _eas().get_all_level_actors() if a.get_actor_label().startswith("Camp_Chain_")}
    for ch in data.get("chains", []):               # spawn_chains labels its actors for the camp
        a = by_label.get("Camp_Chain_%s" % ch["name"])
        if a is None:
            continue
        a.set_actor_label("Gym_Chain_" + ch["name"])
        reg.register("chain:" + ch["name"], a)
    return n


def spawn_racks(data, origin, reg):
    """AMars_HangingRack actors: pot racks on chains from the vault, rails of garlic and herbs on the walls."""
    cls = unreal.load_class(None, RACK_CLASS)
    if cls is None:
        _warn("%s is not loaded (AngelScript not compiled?) - no racks" % RACK_CLASS)
        return 0
    mount = type(unreal.get_default_object(cls).get_editor_property("Mount"))
    n = 0
    for r in data.get("racks", []):
        a = _eas().spawn_actor_from_class(cls, unreal.Vector(*_ue(origin, r["x"], r["y"], r["z"])),
                                          unreal.Rotator(roll=0.0, pitch=0.0, yaw=float(r["yaw_ue"])))
        if a is None:
            continue
        a.set_actor_label("Gym_Rack_" + r["name"])
        a.set_folder_path(KIT_FOLDER + "/Racks")
        wall = r.get("mount") == "wall"
        meshes = [m for m in (_mesh(name) for name in r.get("items", [])) if m is not None]
        if len(meshes) < len(r.get("items", [])):
            _warn("rack %s: %d of its hanging meshes are not imported" % (r["name"], len(r["items"]) - len(meshes)))
        for prop, value in (("Mount", mount.WALL if wall else mount.CEILING), ("BarLength", r["length_m"] * UU),
                            ("Drop", r.get("drop_m", 0.0) * UU), ("ItemMeshes", meshes), ("Seed", int(r.get("seed", 1))),
                            ("ItemYaw", float(r.get("item_yaw", 0.0))), ("YawJitter", float(r.get("yaw_jitter", 25.0))),
                            ("FlipHalf", bool(r.get("flip", not wall))), ("ExtraDropMax", 12.0 if wall else 24.0)):
            try:
                a.set_editor_property(prop, value)
            except Exception as exc:
                _warn("rack %s.%s: %s" % (r["name"], prop, exc))
        try:
            a.call_method("Rebuild")
        except Exception as exc:
            _warn("rack %s Rebuild: %s" % (r["name"], exc))
        reg.register("rack:" + r["name"], a)
        n += 1
    return n


def spawn_stations(data, origin, reg):
    """One entity spawner per plan station, through the same actor factory the AS map builders use
    (UEditorActorSubsystem::SpawnActorFromObject on the entity script class)."""
    placed = []
    for s in data.get("stations", []):
        cls = unreal.load_class(None, STATION_CLASS % STATION_SCRIPT.get(s["name"], s["name"]))
        if cls is None:
            _warn("no script class for the %s station (AngelScript not compiled?)" % s["name"])
            continue
        a = _eas().spawn_actor_from_object(cls, unreal.Vector(*_ue(origin, s["x"], s["y"], 0.0)),
                                           unreal.Rotator(roll=0.0, pitch=0.0, yaw=float(s["yaw_ue"])))
        if a is None:
            _warn("the %s station did not spawn" % s["name"])
            continue
        a.set_actor_label("Gym_%sStation" % s["name"])
        a.set_folder_path(GYM_FOLDER + "/Stations")
        reg.register("station:" + s["name"], a)
        placed.append(s["name"])
    return placed


def spawn_starts(data, origin, reg):
    n = 0
    for s in sorted(data.get("sockets", []), key=lambda q: q["name"]):
        if not s["name"].startswith("gym_start_"):
            continue
        a = mc._spawn(unreal.PlayerStart, _ue(origin, s["x"], s["y"], s["z"]), (0.0, 0.0, -s["rot"] - 90.0),
                      "PlayerStart_%d" % n, GYM_FOLDER + "/Starts")
        reg.register("start:%d" % n, a)
        n += 1
    return n


def spawn_rig(data, origin, reg):
    """Fog, the flat ambient, reflection captures and the grade (and the plan's sun, if it has one); apply_look sets
    their values."""
    folder = GYM_FOLDER + "/Rig"
    reg.register("rig:fog", mc._spawn(unreal.ExponentialHeightFog, (0.0, 0.0, -200.0), label="Gym_Fog", folder=folder))
    sun = data.get("sun")
    if sun:
        a = mc._spawn(unreal.DirectionalLight, (0.0, 0.0, 2400.0), (0.0, float(sun["pitch"]), float(sun["yaw_ue"])),
                      "Gym_Sun", folder)
        a.get_component_by_class(unreal.DirectionalLightComponent).set_mobility(unreal.ComponentMobility.MOVABLE)
        reg.register("rig:sun", a)
    for k, r in enumerate(data.get("reflections", [])):
        a = mc._spawn(unreal.SphereReflectionCapture, _ue(origin, r["x"], r["y"], r["z"]), label="Gym_Reflection_%d" % k,
                      folder=folder)
        mc._try(a.get_component_by_class(unreal.SphereReflectionCaptureComponent), "influence_radius", r["radius_m"] * UU)
        reg.register("rig:reflection:%.1f,%.1f,%.1f" % (r["x"], r["y"], r["z"]), a)
    amb = mc._spawn(unreal.SkyLight, (0.0, 0.0, 600.0), label="Gym_Ambient", folder=folder)
    ac = amb.get_component_by_class(unreal.SkyLightComponent)
    ac.set_mobility(unreal.ComponentMobility.MOVABLE)
    mc._try(ac, "source_type", unreal.SkyLightSourceType.SLS_SPECIFIED_CUBEMAP)
    mc._try(ac, "cubemap", mc._load(AMBIENT_CUBE))
    mc._try(ac, "real_time_capture", False)
    mc._try(ac, "cast_shadows", False)
    reg.register("rig:ambient", amb)
    ppv = mc._spawn(unreal.PostProcessVolume, (0.0, 0.0, 0.0), label="Gym_Grade", folder=folder)
    mc._try(ppv, "unbound", True)
    reg.register("rig:grade", ppv)


def attach_riders(data, reg):
    """The plan's "on" / "of" relations as actor attachments (world transforms kept)."""
    n = 0
    for d in data["placements"] + data.get("dressing", []):
        if d.get("on") and d.get("key") in reg.actors:
            n += reg.attach(d["key"], d["on"])
    for ch in data.get("chains", []):
        for anchor in ch.get("anchors", []):
            n += reg.attach(anchor, "chain:" + ch["name"])
        if ch.get("on"):
            n += reg.attach("chain:" + ch["name"], ch["on"])
    for l in data.get("lights", []):
        if l.get("of"):
            n += reg.attach(l["key"], l["of"])
        elif l.get("of_chain"):
            n += reg.attach(l["key"], "chain:" + l["of_chain"])
    return n


def apply_look():
    """Re-apply LOOK to the open map's gym actors (found by label): lamp intensities from their watts tags, the fog,
    the sun, the grade.  Does not save."""
    v4 = lambda c: unreal.Vector4(c[0], c[1], c[2], 1.0)  # noqa: E731
    lamps = 0
    for a in _eas().get_all_level_actors():
        label = a.get_actor_label()
        if isinstance(a, unreal.PointLight) and label.startswith("Gym_Light_"):
            watts = _tag(a, WATTS_TAG)
            c = a.point_light_component
            if watts:
                c.set_editor_property("intensity", float(watts) * 0.08 * LOOK["light_scale"])
            c.set_editor_property("attenuation_radius", LOOK["light_radius"])
            c.set_editor_property("volumetric_scattering_intensity", LOOK["fog_scatter"])
            lamps += 1
        elif label == "Gym_Fog":
            c = a.get_component_by_class(unreal.ExponentialHeightFogComponent)
            mc._try(c, "fog_density", LOOK["fog_density"])
            mc._try(c, "fog_height_falloff", LOOK["fog_falloff"])
            mc._try(c, "fog_inscattering_luminance", unreal.LinearColor(*LOOK["fog_inscatter"], 1.0))
            mc._try(c, "enable_volumetric_fog", True)
            mc._try(c, "volumetric_fog_albedo", _color(LOOK["fog_albedo"]))
        elif label == "Gym_Sun":
            c = a.get_component_by_class(unreal.DirectionalLightComponent)
            mc._try(c, "intensity", LOOK["sun_lux"])
            mc._try(c, "light_color", _color(LOOK["sun_color"]))
            mc._try(c, "light_source_angle", LOOK["sun_angle"])
            mc._try(c, "volumetric_scattering_intensity", LOOK["sun_scatter"])
            mc._try(c, "cast_shadows", True)
        elif label == "Gym_Ambient":
            c = a.get_component_by_class(unreal.SkyLightComponent)
            mc._try(c, "intensity", LOOK["ambient"])
            mc._try(c, "light_color", _color(LOOK["ambient_color"]))
            mc._try(c, "lower_hemisphere_is_black", False)
        elif label == "Gym_Grade":
            s = a.get_editor_property("settings")
            for k, v in (("override_auto_exposure_method", True), ("auto_exposure_method", unreal.AutoExposureMethod.AEM_MANUAL),
                         ("override_auto_exposure_bias", True), ("auto_exposure_bias", LOOK["exposure_bias"]),
                         ("override_bloom_intensity", True), ("bloom_intensity", LOOK["bloom"]),
                         ("override_vignette_intensity", True), ("vignette_intensity", LOOK["vignette"]),
                         ("override_white_temp", True), ("white_temp", LOOK["white_temp"]),
                         ("override_color_contrast", True), ("color_contrast", v4(LOOK["contrast"])),
                         ("override_color_saturation", True), ("color_saturation", v4(LOOK["saturation"])),
                         ("override_color_gain_shadows", True), ("color_gain_shadows", v4(LOOK["gain_shadows"])),
                         ("override_color_gain_highlights", True), ("color_gain_highlights", v4(LOOK["gain_highlights"]))):
                mc._try(s, k, v)
            a.set_editor_property("settings", s)
    _log("look applied (%d lamps)" % lamps)
    return lamps


# ------------------------------------------------------------------ art import
def import_kitchen_art(path=None):
    """The kitchen dressing build_station_kitchen.py exports (furnace maw, rack hardware, hanging pans, garlic, herbs):
    imported with the station importer (UCX hulls and sockets kept), slots bound to the station / food instances."""
    import mars_station_ue as ms
    importlib.reload(ms)
    path = path or KITCHEN_EXPORT
    reports = ms.import_meshes(path)
    ms.build_materials()
    ms.assign_slots(path)
    return reports


# ------------------------------------------------------------------ the map
def build_gym_map(export_dir=None, biome="Bellfold", cook_jolt=True, stay=False, reset_moved=False, restore_deleted=False):
    """Build (or rebuild) the station gym.  Only the actors in the map's own folders (Mise_Gym, StationGym) are
    replaced, so anything placed by hand elsewhere in the outliner survives; inside those folders an actor that was
    moved keeps its place and one that was deleted stays deleted (see the module docstring).  Returns a report dict;
    goes back to the map that was open unless stay is set."""
    if mc._in_pie():
        raise RuntimeError("stop PIE before building the station gym")
    export_dir = export_dir or KIT_EXPORT
    path, data = _plan(export_dir)
    mm = _mm(export_dir)
    les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
    world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    current = world.get_outermost().get_name() if world else None
    dirty = [p.get_name() for p in unreal.EditorLoadingAndSavingUtils.get_dirty_map_packages()]
    if current in dirty and current != GYM_MAP:
        raise RuntimeError("%s has unsaved changes; save it before building the station gym" % current)
    before, built_before = {}, set()
    if mc.EAL.does_asset_exist(GYM_MAP):
        if current != GYM_MAP:
            les.load_level(GYM_MAP)
        before, built_before = snapshot()
        _eas().destroy_actors([a for a in _eas().get_all_level_actors() if _own(a)])
    else:
        les.new_level(GYM_MAP)
    origin = _origin(data)
    reg = _Registry()
    instanced, pieces = spawn_kit(data, origin, mm, export_dir, biome, reg)
    chains = spawn_chains(data, origin, mm, export_dir, reg)
    racks = spawn_racks(data, origin, reg)
    lamps = spawn_lights(data, origin, reg)
    dressing = spawn_dressing(data, origin, reg)
    stations = spawn_stations(data, origin, reg)
    starts = spawn_starts(data, origin, reg)
    spawn_rig(data, origin, reg)
    riders = attach_riders(data, reg)
    all_keys = set(reg.actors)
    edits = restore_hand_edits(reg, before, built_before, reset_moved, restore_deleted)
    # the record keeps deleted keys listed, so they stay deleted on the next rebuild too
    _write_record(all_keys if not restore_deleted else set(reg.actors))
    apply_look()
    world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    gm = unreal.load_class(None, GAME_MODE)
    if world and gm:
        world.get_world_settings().set_editor_property("default_game_mode", gm)
    else:
        _warn("%s not loaded: the map keeps the project's default game mode" % GAME_MODE)
    # A save fails (returns False, logs "Error saving") when another editor instance has the map open: the build is
    # then only in this editor's memory, so the report must say so.
    saved = bool(les.save_current_level())
    cooked = None
    if saved and cook_jolt and hasattr(unreal, "Ck_JoltCook_EditorSubsystem_UE"):
        jc = unreal.get_editor_subsystem(unreal.Ck_JoltCook_EditorSubsystem_UE)
        try:
            jc.cook_mesh_shapes()
            cooked = jc.cook_current_world()
        except Exception as exc:
            _warn("Jolt cook: %s" % exc)
        saved = bool(les.save_current_level())
    report = {"map": GYM_MAP, "plan": data["name"], "instanced": instanced, "pieces": pieces, "chains": chains,
              "racks": racks, "lamps": lamps, "dressing": dressing, "stations": stations, "starts": starts,
              "attached": riders, "kept_moved": edits["kept_moved"], "kept_deleted": edits["kept_deleted"],
              "cooked": cooked, "saved": saved}
    if not saved:
        _warn("the map did NOT save (is it open in another editor?): %s" % report)
        raise RuntimeError("station gym built in memory but %s did not save - close it in any other editor and rerun" % GYM_MAP)
    _log("built: %s" % report)
    if current and current != GYM_MAP and not stay:
        les.load_level(current)
    return report


def shots(export_dir=None):
    """The plan's review cameras in Unreal space: name -> (eye, target, fov)."""
    _, data = _plan(export_dir or KIT_EXPORT)
    origin = _origin(data)
    return {s["name"]: (_ue(origin, *s["eye"]), _ue(origin, *s["target"]), s["fov"]) for s in data.get("shots", [])}


def capture(out_dir, names=None, size=(1600, 1000), export_dir=None):
    """Render the plan's review shots of the OPEN gym map to <out_dir>/<shot>.png (a scene capture of the editor world:
    darker and more saturated than the game view, so judge the look in PIE).  Spawning the capture actor dirties the
    map; nothing is saved."""
    saved = dict(mc.SHOTS)
    mc.SHOTS.clear()
    mc.SHOTS.update(shots(export_dir))
    try:
        mc.capture(out_dir, shots=names, size=size)
    finally:
        mc.SHOTS.clear()
        mc.SHOTS.update(saved)
