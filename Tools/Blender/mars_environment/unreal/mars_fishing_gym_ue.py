"""Editor side of the Mars FISHING GYM: /Game/Mars/Maps/FishingGym_Mars_MAP, the fishing station standing on the bank of a
sunken pool in a crypt-kit room, under the station gym's warm light.  Where Mars.Sandbox.PlaceFishingStation drops a
pool on the sandbox's flat floor, this map gives the spot a real bank (a ledge the water sits below), room to cast the
full fan, and a second spot on another side of the pool so two seeds can be compared.

Unlike the station gym, which spawns a plan the kit exports (crypt_kitchen.py), this room is planned here (LAYOUT) and
spawned straight from the kit manifest: a 24 x 24 m hall of 4 x 4 m floor tiles with a 16 x 16 m pool cut from its middle
(the pool's tiles sit 1.2 m lower, two carved wall courses line its sides), two courses of wall, a flat roof, lanterns on
stone blocks round the walls, bare lamps over the water, a stone-block climb-out in the pool's +X+Y corner.  Run in the
editor's Python (Monolith `editor_query run_python`, or env_drive.py --module mars_fishing_gym_ue --alias fg), not in PIE:

    python Tools/Blender/mars_environment/unreal/env_drive.py --port 9317 --launch
    python Tools/Blender/mars_environment/unreal/env_drive.py --port 9317 --module mars_fishing_gym_ue --alias fg --call "fg.run_all()"
    python Tools/Blender/mars_environment/unreal/env_drive.py --port 9317 --module mars_fishing_gym_ue --alias fg --call "fg.capture()"
    python Tools/Blender/mars_environment/unreal/env_drive.py --port 9317 --quit

    fg.run_all()      the map, rebuilt (its own folders only), saved, Jolt cooked; returns the report dict
    fg.capture()      SHOTS of the OPEN gym map to <env review>/fishing_gym/<shot>.png - in a SEPARATE call
    fg.apply_look()   after editing mars_station_gym_ue.LOOK: re-applies lights / fog / grade to the open gym map

What is spawned (outliner folders):
  Mise_FishingGym/Shell   ONE actor holding the architecture as HISM components: floor tiles (bank and pool bottom), the
                          pool's wall courses, walls, wall courses, quoins, roof
  Mise_FishingGym/Pieces  what stands in the room, one StaticMeshActor each: lantern blocks and lanterns, the climb-out
                          blocks, a few barrels and crates
  FishingGym/Water        the AMars_StillWater pool
  FishingGym/Stations     one ACk_EntitySpawner_UE per SPOTS row (Mars_FishingStation_EntityScript), its
                          Fishing.Water.SurfaceZ set to the pool's surface and its Seed to the row's
  FishingGym/Lights       LAMPS as movable point lights (watts x LOOK light_scale; tagged with their watts)
  FishingGym/Rig          warm height fog, flat ambient, a reflection capture over the water, the grade, the build record
  FishingGym/Starts       four PlayerStarts, one per bank, facing the water
  FishingGym/Labels       the title and a tag per spot

Re-runnable: a rebuild destroys everything in the two folders (and any FishingGym_* actor moved out of them) and places
it again, so hand edits inside those folders do not survive; anything placed elsewhere in the outliner does.
The map takes AMars_Gameplay_GameMode as its World Settings override.
"""
import importlib
import math
import os
import sys

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
ENV_DIR = os.path.dirname(HERE)
COOKING_UE = os.path.join(os.path.dirname(ENV_DIR), "mars_cooking", "unreal")
KIT_EXPORT = os.environ.get("MISE_KIT_EXPORT", r"C:\Users\Stephen\Documents\Houdini\Blender\export\crypt_kit")
for _p in (HERE, ENV_DIR, COOKING_UE, os.path.join(KIT_EXPORT, "unreal")):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import env_spec as spec              # noqa: E402
import mars_cooking_ue as mc         # noqa: E402  (_spawn, _try, _load, capture)
import mars_station_gym_ue as mg     # noqa: E402  (LOOK, _color, _save_and_cook: the gym's numbers, shared)

GYM_MAP = "/Game/Mars/Maps/FishingGym_Mars_MAP"
GAME_MODE = "/Script/Angelscript.Mars_Gameplay_GameMode"
STATION_CLASS = "/Script/Angelscript.Mars_FishingStation_EntityScript"
WATER_CLASS = "/Script/Angelscript.Mars_StillWater"
KIT_FOLDER, GYM_FOLDER = "Mise_FishingGym", "FishingGym"
LABEL_PREFIX = "FishingGym_"
AMBIENT_CUBE = "/Engine/EngineResources/GrayLightTextureCube"
WATTS_TAG, KEY_TAG = "watts=", "key="
RECORD_LABEL = LABEL_PREFIX + "BuildRecord"
REVIEW = os.path.join(spec.REVIEW_DIR, "fishing_gym")
TILE = 400.0                         # the kit's 4 m floor tile / wall bay, Unreal cm
UU = 100.0

# The room, Unreal cm, the pool's centre at the origin.  Floor tops at Z = 0 (the bank); the pool's tiles at -pool_depth;
# the water pool_depth - water_drop below the bank: the bank is a ledge the bait falls over.
LAYOUT = {
    "room_half": 1200.0,             # interior +-12 m: 6 x 6 tiles
    "pool_half": 800.0,              # the pool +-8 m: 4 x 4 tiles cut from the middle, 4 m of bank on every side
    "pool_depth": 120.0,
    "water_drop": 6.0,               # the surface this far below the bank
    "wall_courses_z": (0.0, 400.0),  # a 3.5 m wall at each; crypt_wall_course_4m (0.5 m) fills 3.5..4.0 between them
    "roof_z": 400.0,                 # crypt_roof_4x4 sits 3.5 m over its pivot: the ceiling at 7.5 m
    "pool_course_z": (-90.0, -140.0),   # two 0.5 m carved courses line the pool from the tile's underside to its floor
    "start_z": 110.0,
    "murk": 1.0,
    "water_seed": 3,
}
SURFACE_Z = -LAYOUT["water_drop"]

# The spots: (name, root, yaw, Fishing.Seed).  A station's operator stands 45 behind its root facing its +X; the root sits
# 50 cm in from the pool's edge; the spot marker is 0.6 x the 900 cm max cast out over the water; the cast fan (+-45 deg,
# 900 cm) lands inside the pool from either bank.
SPOTS = (
    ("A", (-850.0, 0.0, 0.0), 0.0, 1),       # the west bank, casting +X
    ("B", (0.0, 850.0, 0.0), -90.0, 7),      # the +Y bank, casting -Y
)
# (location, yaw) one per bank, facing the water; the first two stand behind spots A and B.
STARTS = (((-1080.0, -160.0), 0.0), ((160.0, 1080.0), -90.0), ((1080.0, -160.0), 180.0), ((-160.0, -1080.0), 90.0))
# The lamps: (x, y, z, watts, kind).  "lantern" lamps also get a camp_lantern on a box_stone_block_1m under them, so
# the light has a source; "bare" lamps hang over the water with no mesh.
LANTERN_BLOCK_TOP, LANTERN_LIGHT = 51.0, 25.0          # box_stone_block_1m is 0.51 m tall; camp_lantern's light anchor
LAMPS = tuple([(sx * 1170.0, sy * 600.0, 0.0, 400.0, "lantern", 90.0) for sx in (-1, 1) for sy in (-1, 1)]
              + [(sx * 600.0, sy * 1170.0, 0.0, 400.0, "lantern", 0.0) for sx in (-1, 1) for sy in (-1, 1)]
              + [(sx * 500.0, sy * 500.0, 420.0, 320.0, "bare", 0.0) for sx in (-1, 1) for sy in (-1, 1)])
WARM = (1.0, 0.72, 0.42)
# Loose dressing: (piece, x, y, z, yaw).  The climb-out: two stone blocks stepping up the pool's +X+Y corner
# (-120 -> -70 -> -20 -> 0); the rest keeps out of both cast fans and both stands.
PIECES = (
    ("box_stone_block_1m", 530.0, 760.0, -120.0, 0.0),
    ("box_stone_block_2m", 690.0, 730.0, -120.0, 0.0),
    ("camp_barrel", 1100.0, -1100.0, 0.0, 20.0),
    ("camp_barrel", 1020.0, -1130.0, 0.0, 65.0),
    ("box_crate_1m", -1120.0, 1120.0, 0.0, 12.0),
    ("box_crate_0m6", -1120.0, 1120.0, 100.0, 40.0),
)
# Review cameras: name -> (eye, target, fov).  "start" is the view from the first player start.
SHOTS = {
    "start": ((-1080.0, -160.0, 165.0), (-200.0, 0.0, SURFACE_Z), 80.0),
    "spot_b": ((160.0, 1080.0, 165.0), (0.0, 200.0, SURFACE_Z), 80.0),
    "water": ((-800.0, 0.0, 60.0), (400.0, 0.0, SURFACE_Z), 70.0),
    "high": ((-1150.0, -1150.0, 700.0), (0.0, 0.0, SURFACE_Z), 75.0),
}


def _log(msg):
    unreal.log("[fishing gym] %s" % msg)


def _warn(msg):
    unreal.log_warning("[fishing gym] %s" % msg)


def _mm():
    import mise_mars_ue as mm
    return importlib.reload(mm)


def _eas():
    return unreal.get_editor_subsystem(unreal.EditorActorSubsystem)


def _les():
    return unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)


def _own(actor):
    return (str(actor.get_folder_path()).startswith((KIT_FOLDER, GYM_FOLDER))
            or actor.get_actor_label().startswith(LABEL_PREFIX))


def _key(actor, key):
    tags = [t for t in actor.get_editor_property("tags") if not str(t).startswith(KEY_TAG)]
    actor.set_editor_property("tags", tags + [unreal.Name(KEY_TAG + key)])
    return actor


def _class(path):
    return unreal.load_class(None, path)


# ------------------------------------------------------------------ the kit, planned here
class _Kit:
    """The kit manifest and its meshes; a plan of HISM transforms per piece and a list of loose placements."""

    def __init__(self, export_dir, biome):
        self.mm = _mm()
        self.man = self.mm._manifest(export_dir)
        self.pieces = self.mm._pieces(self.man)
        self.biome = biome
        self.cache = {}
        self.shell = {}
        self.loose = []

    def mesh(self, piece):
        if piece not in self.cache:
            e = self.pieces.get(piece)
            if e is None:
                raise KeyError("%s is not in the kit manifest" % piece)
            self.cache[piece] = self.mm._asset(e["ue_folder"], e["ue_name"])
            if self.cache[piece] is None:
                _warn("kit mesh %s is not imported" % e["ue_name"])
        return self.cache[piece]

    def place(self, piece, loc, yaw=0.0, scale=(1.0, 1.0, 1.0)):
        """One instance of `piece` at an Unreal location and yaw (the kit's pivots: floors and roofs at their corner,
        covering +X and -Y; walls at the start of their face, running along their yaw with the body behind)."""
        if self.mesh(piece) is not None:
            self.shell.setdefault(piece, []).append(self.mm._xf(loc, yaw, scale))

    def edge(self, piece, normal, distance, half, z, length=TILE):
        """Wall pieces along one edge of a square: `normal` the unit inward normal (toward the room, or the water), the
        edge `distance` out from the centre, running from -half to +half.  The kit's face plane is the pivot line and
        its body lies to the piece's local -Y (yaw t: (sin t, -cos t)), so yaw = atan2(-nx, ny) puts the body outside."""
        nx, ny = normal
        yaw = math.degrees(math.atan2(-nx, ny))
        fx, fy = ny, -nx                              # the run direction (cos yaw, sin yaw)
        cx, cy = -nx * distance, -ny * distance
        for k in range(int(round(2 * half / length))):
            s = -half + k * length
            self.place(piece, (cx + fx * s, cy + fy * s, z), yaw)

    def spawn_shell(self, folder):
        actor = self.mm._hism_actor(LABEL_PREFIX + "Shell", folder)
        n = 0
        for piece, xfs in sorted(self.shell.items()):
            mesh = self.cache[piece]
            self.mm._hism(actor, mesh, xfs, self.mm._biome_mats(mesh, self.biome, self.man))
            n += len(xfs)
        return actor, n

    def spawn_loose(self, folder):
        count, out = {}, []
        for piece, loc, yaw in self.loose:
            mesh = self.mesh(piece)
            if mesh is None:
                continue
            e = self.pieces[piece]
            k = count[piece] = count.get(piece, 0) + 1
            a = self.mm._spawn_mesh(mesh, loc, yaw, "%s%s_%02d" % (LABEL_PREFIX, e["ue_name"].replace("_Mars_SM", ""), k),
                                    "%s/%s" % (folder, e.get("group", "piece")))
            for slot, mi in self.mm._biome_mats(mesh, self.biome, self.man).items():
                a.static_mesh_component.set_material(slot, mi)
            out.append(_key(a, "piece:%s:%d" % (piece, k)))
        return out


def plan_room(kit):
    """LAYOUT as kit placements: the floor (bank tiles at 0, the pool's at -depth), the pool's lining, walls in two
    courses with a carved course between, quoins, the roof."""
    L = LAYOUT
    rh, ph = L["room_half"], L["pool_half"]
    tiles = [-rh + k * TILE for k in range(int(round(2 * rh / TILE)))]
    for i, x in enumerate(tiles):
        for j, y0 in enumerate(tiles):
            y = -y0                                      # a tile at (x, y) covers x..x+400, y..y-400
            in_pool = abs(x + TILE / 2) < ph and abs(y - TILE / 2) < ph
            z = -L["pool_depth"] if in_pool else 0.0
            piece = "crypt_floor_pavers_4x4" if (not in_pool and (i + j) % 3 == 1) else "crypt_floor_4x4"
            kit.place(piece, (x, y, z))
            kit.place("crypt_roof_4x4", (x, y, L["roof_z"]))
    # the pool's sides, the carved face toward the water, from under the bank tile's 40 cm edge down to the pool floor
    for z in L["pool_course_z"]:
        for normal in ((1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0)):
            kit.edge("crypt_wall_course_4m", normal, ph, ph, z)
    # the walls: course 1 alternates the carved and the flat wall, the band course over it, course 2 flat, the roof over
    for normal in ((1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0)):
        kit.edge("crypt_wall_4m", normal, rh, rh, L["wall_courses_z"][0])
        kit.edge("crypt_wall_course_4m", normal, rh, rh, L["wall_courses_z"][0] + 350.0)
        kit.edge("crypt_wall_flat_4m", normal, rh, rh, L["wall_courses_z"][1])
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            for z in L["wall_courses_z"]:
                kit.place("crypt_corner_quoin", (sx * (rh + 20.0), sy * (rh + 20.0), z))
    for piece, x, y, z, yaw in PIECES:
        kit.loose.append((piece, (x, y, z), yaw))
    for x, y, z, watts, kind, yaw in LAMPS:
        if kind == "lantern":
            kit.loose.append(("box_stone_block_1m", (x, y, z), yaw))
            kit.loose.append(("camp_lantern", (x, y, z + LANTERN_BLOCK_TOP), yaw))


# ------------------------------------------------------------------ what Mars adds
def spawn_water():
    cls = _class(WATER_CLASS)
    if cls is None:
        _warn("%s is not loaded (AngelScript not compiled?) - no water" % WATER_CLASS)
        return None
    size = 2.0 * LAYOUT["pool_half"]
    a = _eas().spawn_actor_from_class(cls, unreal.Vector(0.0, 0.0, SURFACE_Z), unreal.Rotator(0.0, 0.0, 0.0))
    a.set_actor_label(LABEL_PREFIX + "Pool")
    a.set_folder_path(GYM_FOLDER + "/Water")
    for prop, value in (("Size", unreal.Vector2D(size, size)), ("Deep", False), ("Murk", float(LAYOUT["murk"])),
                        ("Seed", int(LAYOUT["water_seed"]))):
        mc._try(a, prop, value)
    try:
        a.call_method("Rebuild")
    except Exception as exc:
        _warn("pool Rebuild: %s" % exc)
    return _key(a, "water")


def _set_fishing_spec(spawner, surface_z, seed):
    """Fishing.Water.SurfaceZ and Fishing.Seed on the spawner's instanced entity script (the spec the station reads at
    spawn).  Returns what was written, or None when the script instance is not there."""
    script = spawner.get_editor_property("_EntityScript")
    if script is None:
        return None
    fishing = script.get_editor_property("Fishing")
    water = fishing.get_editor_property("Water")
    water.set_editor_property("SurfaceZ", float(surface_z))
    fishing.set_editor_property("Water", water)
    fishing.set_editor_property("Seed", int(seed))
    script.set_editor_property("Fishing", fishing)
    back = script.get_editor_property("Fishing")
    return {"SurfaceZ": float(back.get_editor_property("Water").get_editor_property("SurfaceZ")),
            "Seed": int(back.get_editor_property("Seed"))}


def spawn_spots():
    """One entity spawner per SPOTS row through the actor factory the AS map builders use
    (UEditorActorSubsystem::SpawnActorFromObject on the entity script class), its spec set to the pool."""
    cls = _class(STATION_CLASS)
    if cls is None:
        _warn("%s is not loaded (AngelScript not compiled?) - no spots" % STATION_CLASS)
        return []
    placed = []
    for name, root, yaw, seed in SPOTS:
        a = _eas().spawn_actor_from_object(cls, unreal.Vector(*root), unreal.Rotator(roll=0.0, pitch=0.0, yaw=yaw))
        if a is None:
            _warn("spot %s did not spawn" % name)
            continue
        a.set_actor_label("%sSpot_%s" % (LABEL_PREFIX, name))
        a.set_folder_path(GYM_FOLDER + "/Stations")
        _key(a, "spot:" + name)
        try:
            written = _set_fishing_spec(a, SURFACE_Z, seed)
        except Exception as exc:
            written = None
            _warn("spot %s: could not set Fishing on the spawner's script: %s" % (name, exc))
        if written is None:
            _warn("spot %s: the spawner has no entity script instance; its spec keeps the defaults (SurfaceZ 0)" % name)
        placed.append({"name": name, "root": root, "yaw": yaw, "spec": written})
    return placed


def spawn_lights():
    n = 0
    for k, (x, y, z, watts, kind, _yaw) in enumerate(LAMPS):
        loc = (x, y, z + LANTERN_BLOCK_TOP + LANTERN_LIGHT) if kind == "lantern" else (x, y, z)
        a = mc._spawn(unreal.PointLight, loc, label="%sLight_%02d" % (LABEL_PREFIX, k), folder=GYM_FOLDER + "/Lights")
        a.set_editor_property("tags", [unreal.Name("%s%g" % (WATTS_TAG, watts))])
        c = a.point_light_component
        c.set_mobility(unreal.ComponentMobility.MOVABLE)
        c.set_editor_property("intensity_units", unreal.LightUnits.CANDELAS)
        c.set_editor_property("intensity", watts * 0.08 * mg.LOOK["light_scale"])
        c.set_editor_property("light_color", mg._color([v * 255 for v in WARM]))
        c.set_editor_property("attenuation_radius", mg.LOOK["light_radius"])
        c.set_editor_property("source_radius", 6.0 if kind == "lantern" else 12.0)
        c.set_editor_property("cast_shadows", kind == "lantern")
        c.set_editor_property("volumetric_scattering_intensity", mg.LOOK["fog_scatter"])
        _key(a, "light:%d" % k)
        n += 1
    return n


def spawn_starts():
    n = 0
    for k, ((x, y), yaw) in enumerate(STARTS):
        a = mc._spawn(unreal.PlayerStart, (x, y, LAYOUT["start_z"]), (0.0, 0.0, yaw), "%sPlayerStart_%d" % (LABEL_PREFIX, k),
                      GYM_FOLDER + "/Starts")
        _key(a, "start:%d" % k)
        n += 1
    return n


def _text(text, loc, yaw, size, label, color=(255, 240, 205)):
    """A text standing at loc, readable from the direction it is yawed toward."""
    a = mc._spawn(unreal.TextRenderActor, loc, (0.0, 0.0, yaw), LABEL_PREFIX + label, GYM_FOLDER + "/Labels")
    c = a.text_render
    c.set_editor_property("text", text)
    c.set_editor_property("world_size", size)
    c.set_editor_property("horizontal_alignment", unreal.HorizTextAligment.EHTA_CENTER)
    c.set_editor_property("vertical_alignment", unreal.VerticalTextAligment.EVRTA_TEXT_BOTTOM)
    c.set_editor_property("text_render_color", mg._color(color))
    return _key(a, "label:" + label)


def spawn_labels():
    rh = LAYOUT["room_half"]
    _text("FISHING GYM", (0.0, -rh + 10.0, 300.0), 90.0, 40.0, "Title")
    for name, root, yaw, seed in SPOTS:
        # the tag stands beside the operator's stand, off its left, facing back toward the start behind the spot
        r = math.radians(yaw)
        back, left = (-math.cos(r), -math.sin(r)), (math.sin(r), -math.cos(r))
        loc = (root[0] + back[0] * 110.0 + left[0] * 120.0, root[1] + back[1] * 110.0 + left[1] * 120.0, 1.0)
        _text("Spot %s   seed %d" % (name, seed), loc, yaw + 180.0, 10.0, "Tag_%s" % name)
    return 1 + len(SPOTS)


def spawn_rig():
    """Fog, the flat ambient, a reflection capture over the water and the grade; apply_look sets their values."""
    folder = GYM_FOLDER + "/Rig"
    _key(mc._spawn(unreal.ExponentialHeightFog, (0.0, 0.0, -200.0), label=LABEL_PREFIX + "Fog", folder=folder), "rig:fog")
    refl = mc._spawn(unreal.SphereReflectionCapture, (0.0, 0.0, 200.0), label=LABEL_PREFIX + "Reflection", folder=folder)
    mc._try(refl.get_component_by_class(unreal.SphereReflectionCaptureComponent), "influence_radius",
            LAYOUT["room_half"] * 1.5)
    try:                                   # the crypt's warm cubemap, when the environment HDRs are imported
        import mars_env_ue
        mars_env_ue.set_reflection(refl, "warm", LAYOUT["room_half"] * 1.5)
    except Exception as exc:
        _warn("reflection capture keeps the captured scene (no crypt cubemap): %s" % exc)
    _key(refl, "rig:reflection")
    amb = mc._spawn(unreal.SkyLight, (0.0, 0.0, 600.0), label=LABEL_PREFIX + "Ambient", folder=folder)
    ac = amb.get_component_by_class(unreal.SkyLightComponent)
    ac.set_mobility(unreal.ComponentMobility.MOVABLE)
    mc._try(ac, "source_type", unreal.SkyLightSourceType.SLS_SPECIFIED_CUBEMAP)
    mc._try(ac, "cubemap", mc._load(AMBIENT_CUBE))
    mc._try(ac, "real_time_capture", False)
    mc._try(ac, "cast_shadows", False)
    _key(amb, "rig:ambient")
    ppv = mc._spawn(unreal.PostProcessVolume, (0.0, 0.0, 0.0), label=LABEL_PREFIX + "Grade", folder=folder)
    mc._try(ppv, "unbound", True)
    _key(ppv, "rig:grade")


def apply_look():
    """Re-apply mars_station_gym_ue.LOOK to the open map's gym actors (found by label): lamp intensities from their
    watts tags, the fog, the ambient, the grade.  Does not save."""
    LOOK = mg.LOOK
    v4 = lambda c: unreal.Vector4(c[0], c[1], c[2], 1.0)  # noqa: E731
    lamps = 0
    for a in _eas().get_all_level_actors():
        label = a.get_actor_label()
        if isinstance(a, unreal.PointLight) and label.startswith(LABEL_PREFIX + "Light_"):
            watts = mg._tag(a, WATTS_TAG)
            c = a.point_light_component
            if watts:
                c.set_editor_property("intensity", float(watts) * 0.08 * LOOK["light_scale"])
            c.set_editor_property("attenuation_radius", LOOK["light_radius"])
            c.set_editor_property("volumetric_scattering_intensity", LOOK["fog_scatter"])
            lamps += 1
        elif label == LABEL_PREFIX + "Fog":
            c = a.get_component_by_class(unreal.ExponentialHeightFogComponent)
            mc._try(c, "fog_density", LOOK["fog_density"])
            mc._try(c, "fog_height_falloff", LOOK["fog_falloff"])
            mc._try(c, "fog_inscattering_luminance", unreal.LinearColor(*LOOK["fog_inscatter"], 1.0))
            mc._try(c, "enable_volumetric_fog", True)
            mc._try(c, "volumetric_fog_albedo", mg._color(LOOK["fog_albedo"]))
        elif label == LABEL_PREFIX + "Ambient":
            c = a.get_component_by_class(unreal.SkyLightComponent)
            mc._try(c, "intensity", LOOK["ambient"])
            mc._try(c, "light_color", mg._color(LOOK["ambient_color"]))
            mc._try(c, "lower_hemisphere_is_black", False)
        elif label == LABEL_PREFIX + "Grade":
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


# ------------------------------------------------------------------ the map
def _open_or_create():
    """Load the gym map (creating it the first time) and clear this builder's actors.  Returns (les, the map that was
    open before, how many actors were cleared)."""
    les = _les()
    world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    current = world.get_outermost().get_name() if world else None
    dirty = [p.get_name() for p in unreal.EditorLoadingAndSavingUtils.get_dirty_map_packages()]
    if current in dirty and current != GYM_MAP:
        raise RuntimeError("%s has unsaved changes; save it before building the fishing gym" % current)
    cleared = 0
    if unreal.EditorAssetLibrary.does_asset_exist(GYM_MAP):
        if current != GYM_MAP:
            les.load_level(GYM_MAP)
        doomed = [a for a in _eas().get_all_level_actors() if _own(a)]
        cleared = len(doomed)
        if doomed:
            _eas().destroy_actors(doomed)
    else:
        les.new_level(GYM_MAP)
    return les, current, cleared


def build_gym_map(export_dir=None, biome="Bellfold", cook_jolt=True, stay=True):
    """Build (or rebuild) the fishing gym: only the actors in the map's own folders (Mise_FishingGym, FishingGym) and
    the FishingGym_* labels are replaced, so anything placed by hand elsewhere in the outliner survives.  Returns a
    report dict; stays on the gym map unless stay is False."""
    if mc._in_pie():
        raise RuntimeError("stop PIE before building the fishing gym")
    les, current, cleared = _open_or_create()
    kit = _Kit(export_dir or KIT_EXPORT, biome)
    plan_room(kit)
    shell, instanced = kit.spawn_shell(KIT_FOLDER + "/Shell")
    _key(shell, "shell")
    loose = kit.spawn_loose(KIT_FOLDER + "/Pieces")
    water = spawn_water()
    spots = spawn_spots()
    lamps = spawn_lights()
    starts = spawn_starts()
    labels = spawn_labels()
    spawn_rig()
    apply_look()
    record = mc._spawn(unreal.Actor, (0.0, 0.0, 0.0), label=RECORD_LABEL, folder=GYM_FOLDER + "/Rig")
    record.set_editor_property("tags", [unreal.Name("surface_z=%g" % SURFACE_Z), unreal.Name("pool=%g" % (2 * LAYOUT["pool_half"]))])
    world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    gm = _class(GAME_MODE)
    if world and gm:
        world.get_world_settings().set_editor_property("default_game_mode", gm)
    else:
        _warn("%s not loaded: the map keeps the project's default game mode" % GAME_MODE)
    # A save fails (returns False, logs "Error saving") when another editor instance has the map open: the build is
    # then only in this editor's memory, so the report must say so.
    saved, cooked = mg._save_and_cook(les, cook_jolt)
    report = {"map": GYM_MAP, "cleared": cleared, "instanced": instanced, "pieces": len(loose),
              "water": water is not None, "surface_z": SURFACE_Z, "pool": 2 * LAYOUT["pool_half"],
              "spots": spots, "lamps": lamps, "starts": starts, "labels": labels, "cooked": str(cooked), "saved": saved}
    if not saved:
        _warn("the map did NOT save (is it open in another editor?): %s" % report)
        raise RuntimeError("fishing gym built in memory but %s did not save - close it in any other editor and rerun" % GYM_MAP)
    _log("built: %s" % report)
    if current and current != GYM_MAP and not stay:
        les.load_level(current)
    return report


def run_all(export_dir=None, biome="Bellfold", cook_jolt=True):
    return build_gym_map(export_dir, biome, cook_jolt)


def capture(out_dir=None, names=None, size=(1600, 1000)):
    """Render SHOTS of the OPEN gym map to <out_dir>/<shot>.png (a scene capture of the editor world: darker and more
    saturated than the game view, so judge the look in PIE).  Spawning the capture actor dirties the map; nothing is
    saved.  Run as its own call after run_all."""
    world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
    current = world.get_outermost().get_name() if world else None
    if current != GYM_MAP:
        _les().load_level(GYM_MAP)
    out_dir = out_dir or REVIEW
    saved = dict(mc.SHOTS)
    mc.SHOTS.clear()
    mc.SHOTS.update(SHOTS)
    try:
        mc.capture(out_dir, shots=names, size=size)
    finally:
        mc.SHOTS.clear()
        mc.SHOTS.update(saved)
    return {"out_dir": out_dir, "shots": sorted(names or SHOTS)}


def inspect():
    """What the open gym map holds: the spots' specs as the spawners carry them, the water, the lamps."""
    out = {"spots": [], "water": None, "lamps": 0}
    for a in _eas().get_all_level_actors():
        label = a.get_actor_label()
        if not label.startswith(LABEL_PREFIX):
            continue
        if label.startswith(LABEL_PREFIX + "Spot_"):
            script = a.get_editor_property("_EntityScript")
            spec_ = script.get_editor_property("Fishing") if script is not None else None
            loc = a.get_actor_location()
            out["spots"].append({"label": label, "root": (loc.x, loc.y, loc.z), "yaw": a.get_actor_rotation().yaw,
                                 "surface_z": spec_.get_editor_property("Water").get_editor_property("SurfaceZ") if spec_ else None,
                                 "seed": spec_.get_editor_property("Seed") if spec_ else None})
        elif label == LABEL_PREFIX + "Pool":
            loc = a.get_actor_location()
            size = a.get_editor_property("Size")
            out["water"] = {"z": loc.z, "size": (size.x, size.y), "deep": a.get_editor_property("Deep")}
        elif label.startswith(LABEL_PREFIX + "Light_"):
            out["lamps"] += 1
    return out
