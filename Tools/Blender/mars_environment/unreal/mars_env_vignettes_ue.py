"""EnvVignettes_Mars_MAP: six rooms, each recreating one of Stephen's crypt concept frames (2026-10-19) with the
environment dressing kit (mars_env_ue), the vine generator (AMars_Vine / AMars_HeroRoot) and the drip tool
(AMars_DripLeak / AMars_Puddle / AMars_StillWater / AMars_WetStreak) inside crypt-kit rooms (mise_mars_ue.spawn_room).

    import sys, importlib
    sys.path.insert(0, r"D:\\Repo\\Mars\\Tools\\Blender\\mars_environment\\unreal")
    import mars_env_vignettes_ue as vg; importlib.reload(vg)
    vg.build_map(cook=True)             # every vignette (or build_map(["cistern"]) to rebuild one in place); cook = Jolt
    vg.build_reflections()              # its own call: builds the reflection captures PIE needs, saves
    vg.capture()                        # a later call: SceneCapture2D per vignette from its concept camera
    vg.pie_start() / vg.pie_view(name, tag) / vg.pie_stop()   # one call each (PIE ticks between calls)

Host side (plain python + PIL, no unreal):
    python mars_env_vignettes_ue.py --pie [--port 9317]   PIE pass over a running hidden editor: per vignette the client
                                                          views its camera, two high-res shots 0.5 s apart
                                                          (Saved/Screenshots/EnvVignettes/<name>_a|b.png), then sheets
    python mars_env_vignettes_ue.py --sheets       (concept | SceneCapture sheets)
    python mars_env_vignettes_ue.py --pie-sheets   (concept | PIE sheets: the reference; captures run 2.5 - 4.5 stops
                                                    darker than the game view, see CAPTURE_EV)

Driven through env_drive.py on a hidden editor (never Stephen's 9316):
    python env_drive.py --port 9317 --module mars_env_vignettes_ue --alias vg --call "vg.build_map()"

Layout: vignette i stands at X = i * PITCH (rooms along +X, 50 m apart so no lamp reaches a neighbour). A kit room's
Blender frame (x across, y into the room) maps to Unreal (100x, -100y, 100z), so a room spans Unreal y in [-D, 0] with
its S door at y = 0. Every spawned actor is labelled V<i>_<Name>_..., filed under EnvVignettes/<Name>/... and tagged
TAG plus TAG.<name>; a rebuild destroys only those (build_map(names) touches only the named vignettes and the rig).
PCG stays local-only: nothing here needs it.

Per-vignette look (exposure, grade) rides on the vignette's CameraActor post-process settings: the captures copy them
into the SceneCapture2D and the PIE pass views through that camera, so one map holds a warm and a blue room side by side.
"""
import json
import math
import os
import random
import sys

try:
    import unreal
except ImportError:          # host side: only the contact-sheet helpers run
    unreal = None

HERE = os.path.dirname(os.path.abspath(__file__))
ENV_DIR = os.path.dirname(HERE)
WATER_UE = os.path.join(os.path.dirname(ENV_DIR), "mars_water", "unreal")
CRYPT_KIT = r"C:\Users\Stephen\Documents\Houdini\Blender\export\crypt_kit"
for _p in (HERE, ENV_DIR, WATER_UE, os.path.join(CRYPT_KIT, "unreal")):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import env_spec as spec      # noqa: E402

MAP = "/Game/Mars/Maps/EnvVignettes_Mars_MAP"
FOLDER = "EnvVignettes"
TAG = "Mars.EnvVignette"
PITCH = 5000.0
NAMES = ("ossuary", "sewer", "atrium_blue", "gallery_warm", "cistern", "sarcophagus")
REVIEW = os.path.join(spec.REVIEW_DIR, "vignettes")
CONCEPTS = os.path.join(REVIEW, "concepts")          # <name>.png copies of the six concept frames
SHOTS_JSON = os.path.join(REVIEW, "vignette_shots.json")
# A SceneCapture2D renders 2.5 - 4.5 stops darker than the PIE view of the same camera (no screen-space GI and no
# history in a one-off capture), so captures add this to each camera's exposure; the camera numbers are tuned on PIE.
CAPTURE_EV = 2.5
SHOT_DIR = os.path.join(r"D:\Repo\Mars", "Saved", "Screenshots", "EnvVignettes")      # PIE screenshots
DRESS = spec.UE_ROOT + "/Meshes"
INST = spec.UE_INSTANCES
KIT = "/Game/Mars/Environment/Meshes"
WARM = (1.0, 0.75, 0.46)        # kit rule: no redder than this, except flames
FLAME = (1.0, 0.62, 0.3)
COLD = (0.32, 0.55, 1.0)
TEAL = (0.35, 0.68, 1.0)         # the sewer spirit blue (greener light turns the rust olive)
SPIRIT = (0.3, 0.62, 1.0)
GAME_MODE = "/Script/Angelscript.Mars_Gameplay_GameMode"


# ------------------------------------------------------------------ editor helpers
def _eas():
    return unreal.get_editor_subsystem(unreal.EditorActorSubsystem)


def _les():
    return unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)


def _world():
    return unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()


_CACHE = {}


def _load(path):
    if path in _CACHE:
        return _CACHE[path]
    name = path.rsplit("/", 1)[-1]
    obj = unreal.find_object(None, "%s.%s" % (path, name))
    if obj is None and unreal.EditorAssetLibrary.does_asset_exist(path):
        obj = unreal.EditorAssetLibrary.load_asset(path)
    _CACHE[path] = obj
    return obj


def mesh(name):
    """'Skull_A' -> the dressing mesh (any family); 'Crypt/CryptWall4m' or 'Boxes/BoxCrate1m' -> the crypt kit."""
    if "/" in name:
        m = _load("%s/%s_Mars_SM" % (KIT, name))
    else:
        m = None
        for fam in ("Bones", "Crypt", "Pipes", "Clutter", "Organic", "Vines"):
            m = _load("%s/%s/%s_Mars_SM" % (DRESS, fam, name))
            if m is not None:
                break
    if m is None:
        raise RuntimeError("mesh %s is missing" % name)
    return m


def mi(name):
    return _load("%s/%s" % (INST, name)) or _load(name)


FACE = {"N": 180.0, "S": 0.0, "E": -90.0, "W": 90.0}   # yaw that turns a wall prop's front (+Y local) to that side
                                                    # (compass of the kit's Blender plan: N = +y_b = Unreal -Y)


def B(x, y, z=0.0):
    """Kit-plan Blender metres -> Unreal cm (vignette-local)."""
    return (x * 100.0, -y * 100.0, z * 100.0)


def rotz(v, yaw):
    r = math.radians(yaw)
    return (v[0] * math.cos(r) - v[1] * math.sin(r), v[0] * math.sin(r) + v[1] * math.cos(r), v[2])


def child(base, yaw, local):
    """base (cm) + local offset turned by yaw."""
    o = rotz(local, yaw)
    return (base[0] + o[0], base[1] + o[1], base[2] + o[2])


class Ctx:
    """The vignette being built: origin, index, label prefix, folder, tags, biome; every spawn goes through it."""

    def __init__(self, index, name, biome="Bellfold"):
        self.i, self.name = index, name
        self.ox = index * PITCH
        self.title = "".join(w.capitalize() for w in name.split("_"))
        self.folder = "%s/%s" % (FOLDER, self.title)
        self.tags = [unreal.Name(TAG), unreal.Name("%s.%s" % (TAG, name))]
        self.count = 0
        self.lights = []
        self.biome = biome
        self.room = None
        self.light_scale = 1.0
        self.rng = random.Random(1000 + index)

    def w(self, x, y, z):
        return (self.ox + x, y, z)

    def own(self, a, label=None, sub=""):
        if label:
            a.set_actor_label("V%d_%s_%s" % (self.i + 1, self.title, label))
        a.set_folder_path(self.folder + ("/" + sub if sub else ""))
        a.set_editor_property("tags", list(a.get_editor_property("tags")) + self.tags)
        self.count += 1
        return a

    def spawn(self, obj, loc, rot=(0.0, 0.0, 0.0), sub="Props", label=None, scale=None, local=True):
        """rot = (pitch, yaw, roll) degrees; loc vignette-local unless local=False."""
        p = self.w(*loc) if local else loc
        r = unreal.Rotator(roll=rot[2], pitch=rot[0], yaw=rot[1])
        if isinstance(obj, (type, unreal.Class)):
            a = _eas().spawn_actor_from_class(obj, unreal.Vector(*p), r)
        else:
            a = _eas().spawn_actor_from_object(obj, unreal.Vector(*p), r)
        if a is None:
            raise RuntimeError("could not spawn %s" % obj)
        if scale is not None:
            a.set_actor_scale3d(unreal.Vector(*((scale,) * 3 if isinstance(scale, (int, float)) else scale)))
        return self.own(a, label or (obj.get_name().replace("_Mars_SM", "") if not isinstance(obj, (type, unreal.Class))
                                     else None), sub)

    def prop(self, name, loc, yaw=0.0, scale=None, sub="Props", pitch=0.0, roll=0.0, mats=None, label=None):
        """A dressing (or 'Crypt/...' kit) mesh; stone slots follow the vignette biome; mats = {slot index: MI}."""
        m = mesh(name)
        a = self.spawn(m, loc, (pitch, yaw, roll), sub, label, scale)
        comp = a.static_mesh_component
        if self.biome != "Bellfold" and "/" not in name:
            for k, sm in enumerate(m.get_editor_property("static_materials")):
                mat = sm.get_editor_property("material_interface")
                if mat is not None and mat.get_name() in ("EnvStone_Mars_MI", "EnvStoneDark_Mars_MI"):
                    alt = mi(mat.get_name().replace("_Mars_MI", "_%s_Mars_MI" % self.biome))
                    if alt is not None:
                        comp.set_material(k, alt)
        elif "/" in name and self.biome != "Bellfold":
            for k, alt in _mise()._biome_mats(m, self.biome, _manifest()).items():
                comp.set_material(k, alt)
        for k, mm in (mats or {}).items():
            comp.set_material(k, mi(mm) if isinstance(mm, str) else mm)
        return a

    def kit(self, piece, bx, by, bz=0.0, rot=0.0, sub="KitExtra", scale=None):
        """A crypt-kit piece by plan id at a Blender-plan placement (metres, rot degrees), as spawn_room places it."""
        e = _pieces()[piece]
        return self.prop(e["ue_folder"].rsplit("/", 1)[-1] + "/" + e["ue_name"].replace("_Mars_SM", ""),
                         B(bx, by, bz), -rot, scale, sub)

    def lamp(self, loc, color=WARM, cd=60.0, radius=1400.0, source=3.0, shadows=True, label="Lamp", spot=None):
        """spot = (pitch, yaw, outer cone deg)."""
        cls = unreal.SpotLight if spot else unreal.PointLight
        a = self.spawn(cls, loc, (spot[0], spot[1], 0.0) if spot else (0.0, 0.0, 0.0), "Lights", label)
        c = a.get_component_by_class(unreal.LocalLightComponent)
        c.set_editor_property("intensity_units", unreal.LightUnits.CANDELAS)
        c.set_editor_property("intensity", cd * self.light_scale)
        c.set_editor_property("light_color", unreal.Color(r=int(255 * color[0]), g=int(255 * color[1]),
                                                           b=int(255 * color[2]), a=255))
        c.set_editor_property("attenuation_radius", radius)
        c.set_editor_property("source_radius", source)
        c.set_editor_property("cast_shadows", shadows)
        if spot:
            c.set_editor_property("outer_cone_angle", spot[2])
            c.set_editor_property("inner_cone_angle", spot[2] * 0.6)
        self.lights.append(a)
        return a

    def reflection(self, loc, radius, kind, brightness=1.0):
        a = _env_ue().place_reflection(self.w(*loc), radius, kind, "Reflections", self.folder + "/Lights", brightness)
        return self.own(a, "Reflections_%s" % kind, "Lights")

    # -------------------------------------------------- generators
    def vine(self, loc, preset, layout, end, yaw=0.0, pitch=0.0, shape=None, seed=1, label=None, extra=None,
             guide=None, profile=None):
        """AMars_Vine; guide = [(x, y, z) vignette-local cm] for the Spline layout."""
        a = self.spawn(_class("Mars_Vine"), loc, (pitch, yaw, 0.0), "Vines", label or "%s_%s" % (preset, layout))
        a.set_editor_property("Profile", profile or _load("%s/Vines/Profiles/Vine%s_Mars_DA" % (spec.UE_ROOT, preset)))
        a.set_editor_property("Layout", getattr(unreal.Mars_VineLayout, layout.upper()))
        a.set_editor_property("End", getattr(unreal.Mars_VineEnd, end.upper()))
        a.set_editor_property("Seed", seed)
        if shape:
            sh = a.get_editor_property("Shape")
            for k, v in shape.items():
                sh.set_editor_property(k, v)
            a.set_editor_property("Shape", sh)
        for k, v in (extra or {}).items():
            a.set_editor_property(k, v)
        if guide:
            g = a.get_editor_property("Guide")
            g.set_spline_points([unreal.Vector(*self.w(*p)) for p in guide], unreal.SplineCoordinateSpace.WORLD, True)
        a.call_method("Rebuild")
        return a

    def hero_root(self, loc, seed, label="HeroRoot", **props):
        a = self.spawn(_class("Mars_HeroRoot"), loc, (0.0, 0.0, 0.0), "Vines", label)
        a.set_editor_property("Seed", seed)
        a.set_editor_property("Material", mi("VineBarkRoot_Mars_MI"))
        for k, v in props.items():
            a.set_editor_property(k, v)
        a.call_method("Rebuild")
        return a

    def leak(self, loc, preset, yaw=0.0, label=None, **props):
        wr = _water()
        a = self.spawn(_class("Mars_DripLeak"), loc, (0.0, yaw, 0.0), "Water", label or "Leak_" + preset)
        a.set_editor_property("preset", wr._enum(a, "preset", preset))
        a.call_method("ApplyPreset")
        for prop_, fields in props.items():
            if isinstance(fields, dict):
                wr._set_struct(a, prop_, **fields)
            else:
                a.set_editor_property("".join(w[:1].upper() + w[1:] for w in prop_.split("_")), fields)
        a.call_method("Rebuild")
        return a

    def puddles(self, loc, count, radius, seed=1, label="Puddles", **look):
        wr = _water()
        a = self.spawn(_class("Mars_Puddle"), loc, (0.0, 0.0, 0.0), "Water", label)
        a.set_editor_property("count", count)
        a.set_editor_property("radius", radius)
        a.set_editor_property("seed", seed)
        if look:
            wr._set_struct(a, "look", **look)
        a.call_method("Rebuild")
        return a

    def still_water(self, loc, size, deep=False, murk=1.0, material=None, label="Water", seed=1):
        a = self.spawn(_class("Mars_StillWater"), loc, (0.0, 0.0, 0.0), "Water", label)
        a.set_editor_property("size", unreal.Vector2D(*size))
        a.set_editor_property("deep", deep)
        a.set_editor_property("murk", murk)
        a.set_editor_property("seed", seed)
        if material is not None:
            a.set_editor_property("water_material", material)
        a.call_method("Rebuild")
        return a

    def streak(self, loc, yaw=0.0, seed=1, label="Streak", **streak):
        wr = _water()
        a = self.spawn(_class("Mars_WetStreak"), loc, (0.0, yaw, 0.0), "Water", label)
        a.set_editor_property("seed", seed)
        wr._set_struct(a, "streak", **streak)
        a.call_method("Rebuild")
        return a

    # -------------------------------------------------- scatter
    def scatter(self, names, centre, radius, count, sub="Scatter", scale=(0.9, 1.15)):
        """count random picks of names in a disc (vignette-local cm), random yaw."""
        out = []
        for _ in range(count):
            r = radius * math.sqrt(self.rng.random())
            t = self.rng.random() * 2.0 * math.pi
            loc = (centre[0] + r * math.cos(t), centre[1] + r * math.sin(t), centre[2] if len(centre) > 2 else 0.0)
            out.append(self.prop(self.rng.choice(names), loc, self.rng.uniform(0, 360), self.rng.uniform(*scale), sub))
        return out


def _class(name):
    return unreal.load_class(None, "/Script/Angelscript.%s" % name)


def _mise():
    import mise_mars_ue
    return mise_mars_ue


_MAN = {}


def _manifest():
    if "m" not in _MAN:
        _MAN["m"] = _mise()._manifest(CRYPT_KIT)
    return _MAN["m"]


def _pieces():
    return _mise()._pieces(_manifest())


def _water():
    import mars_water_review as wr
    return wr


def _env_ue():
    import mars_env_ue
    return mars_env_ue


# ------------------------------------------------------------------ kit rooms
def room_data(room):
    with open(os.path.join(CRYPT_KIT, "rooms", room + ".json")) as fh:
        return json.load(fh)


def anchors(room, piece, kind, data=None):
    """Anchors of `kind` on every `piece` placement of a kit room: [(Unreal cm vignette-local, yaw, anchor, placement)]."""
    m = _mise()
    e = _pieces()[piece]
    out = []
    for d in (data or room_data(room))["placements"]:
        if d["piece"] != piece:
            continue
        for an in e.get("anchors", []):
            if an.get("kind") == kind:
                bx, by, bz = m.to_ue(*m.local_to_world(an["pos"], d))
                out.append(((bx, by, bz), -d["rot"], an, d))
    return out


def spawn_room(ctx, room, drop=(), swap=None, keep=None, extra=()):
    """The kit room as one HISM actor (mise_mars_ue.spawn_room) from a filtered copy of its plan: placements whose piece
    id starts with any of `drop` (or fails keep(placement)) are left out, swap = {piece: piece} replaces pieces, extra
    placements are appended. Returns the plan used."""
    data = room_data(room)
    plc = []
    for d in data["placements"]:
        if any(d["piece"].startswith(p) for p in drop) or (keep and not keep(d)):
            continue
        d = dict(d)
        d["piece"] = (swap or {}).get(d["piece"], d["piece"])
        plc.append(d)
    plc.extend(extra)
    data["placements"] = plc
    os.makedirs(os.path.join(REVIEW, "rooms"), exist_ok=True)
    path = os.path.join(REVIEW, "rooms", "%s__%s.json" % (room, ctx.name))
    with open(path, "w") as fh:
        json.dump(data, fh)
    acts = _mise().spawn_room(path, biome=ctx.biome, origin=(ctx.ox, 0.0, 0.0), export_dir=CRYPT_KIT,
                              folder=ctx.folder + "/Kit", lights=False, sockets=False, mode="hism")
    for a in acts:
        ctx.own(a)
        a.set_actor_label("V%d_%s_Kit_%s" % (ctx.i + 1, ctx.title, room))
    ctx.room = acts[0]
    return data


def room_material(ctx, mesh_part, material):
    """Override the material of every HISM in the room actor whose mesh name contains mesh_part (all slots)."""
    n = 0
    for c in ctx.room.get_components_by_class(unreal.InstancedStaticMeshComponent):
        sm = c.get_editor_property("static_mesh")
        if sm is not None and mesh_part in sm.get_name():
            for k in range(c.get_num_materials()):
                c.set_material(k, material)
            n += 1
    return n


# ------------------------------------------------------------------ rig
def _rig():
    ctx = Ctx(-1, "rig")
    ctx.ox = 0.0
    ctx.title = "Rig"
    ctx.folder = FOLDER + "/Rig"
    fog = ctx.spawn(unreal.ExponentialHeightFog, (0.0, 0.0, -300.0), sub="", label="Fog", local=False)
    fc = fog.get_component_by_class(unreal.ExponentialHeightFogComponent)
    fc.set_editor_property("fog_density", 0.02)
    fc.set_editor_property("fog_height_falloff", 0.06)
    fc.set_editor_property("fog_inscattering_luminance", unreal.LinearColor(0.02, 0.05, 0.06, 1.0))
    # volumetric fog: each room's own lamps tint its haze (warm rooms amber, blue rooms blue) under one height fog
    fc.set_editor_property("enable_volumetric_fog", True)
    fc.set_editor_property("volumetric_fog_scattering_distribution", 0.35)
    fc.set_editor_property("volumetric_fog_albedo", unreal.Color(r=200, g=200, b=200, a=255))
    fc.set_editor_property("volumetric_fog_extinction_scale", 1.0)
    ppv = ctx.spawn(unreal.PostProcessVolume, (0.0, 0.0, 0.0), sub="", label="Grade", local=False)
    ppv.set_editor_property("unbound", True)
    s = ppv.get_editor_property("settings")
    for k, v in (("override_auto_exposure_method", True), ("auto_exposure_method", unreal.AutoExposureMethod.AEM_MANUAL),
                 ("override_auto_exposure_bias", True), ("auto_exposure_bias", 8.7),
                 ("override_bloom_intensity", True), ("bloom_intensity", 0.6)):
        s.set_editor_property(k, v)
    ppv.set_editor_property("settings", s)
    sky = ctx.spawn(unreal.SkyLight, (0.0, 0.0, 2000.0), sub="", label="Ambient", local=False)
    sc = sky.get_component_by_class(unreal.SkyLightComponent)
    sc.set_editor_property("source_type", unreal.SkyLightSourceType.SLS_SPECIFIED_CUBEMAP)
    cube = _load("/Engine/MapTemplates/Sky/DaylightAmbientCubemap")
    if cube:
        sc.set_editor_property("cubemap", cube)
    sc.set_editor_property("intensity", 0.04)
    # PIE: the pawn starts on the ossuary nave floor (the PIE pass then views each vignette through its camera)
    ctx.spawn(unreal.PlayerStart, (-600.0, -300.0, 120.0), (0.0, -90.0, 0.0), sub="", label="PlayerStart", local=False)
    return ctx.count


# ------------------------------------------------------------------ map
def _destroy(names):
    """Destroy this builder's actors: the rig and the named vignettes."""
    keep = set("%s.%s" % (TAG, n) for n in NAMES if n not in names)
    doomed = []
    for a in _eas().get_all_level_actors():
        tags = [str(t) for t in a.get_editor_property("tags")]
        if TAG not in tags:
            continue
        if any(t in keep for t in tags):
            continue
        doomed.append(a)
    if doomed:
        _eas().destroy_actors(doomed)
    return len(doomed)


BUILDERS = {}


def vignette(fn):
    BUILDERS[fn.__name__.replace("build_", "")] = fn
    return fn


def build_map(names=None, save=True, cook=False):
    if _les().is_in_play_in_editor():
        raise RuntimeError("stop PIE first")
    names = list(names or NAMES)
    if unreal.EditorAssetLibrary.does_asset_exist(MAP):
        if _world().get_path_name().split(".")[0] != MAP:
            _les().load_level(MAP)
    else:
        _les().new_level(MAP)
    _CACHE.clear()
    removed = _destroy(names)
    _rig()
    shots = {}
    if os.path.isfile(SHOTS_JSON):
        with open(SHOTS_JSON) as fh:
            shots = json.load(fh)
    made = {}
    mats = materials()
    for name in names:
        ctx = Ctx(NAMES.index(name), name)
        ctx.mats = mats
        shot = BUILDERS[name](ctx)
        if shot:
            shots[name] = shot
            _camera(ctx, shot)
        made[name] = ctx.count
    os.makedirs(REVIEW, exist_ok=True)
    with open(SHOTS_JSON, "w") as fh:
        json.dump(shots, fh, indent=1)
    ws = _world().get_world_settings()
    gm = unreal.load_class(None, GAME_MODE)
    if ws is not None and gm is not None:
        ws.set_editor_property("default_game_mode", gm)
    if save:
        unreal.EditorLoadingAndSavingUtils.save_current_level()
    cooked = None
    if cook and save and hasattr(unreal, "Ck_JoltCook_EditorSubsystem_UE"):      # the pawn walks on the cooked world
        jc = unreal.get_editor_subsystem(unreal.Ck_JoltCook_EditorSubsystem_UE)
        try:
            jc.cook_mesh_shapes()
            cooked = jc.cook_current_world()
        except Exception as exc:
            unreal.log_warning("[vignettes] Jolt cook: %s" % exc)
        unreal.EditorLoadingAndSavingUtils.save_current_level()
    return {"removed": removed, "made": made, "jolt": str(cooked)}


# ------------------------------------------------------------------ cameras, post
def build_reflections():
    """Build the reflection captures and save: run as its OWN call after build_map (captures spawned in the same call
    are not built yet). The crypt cubemaps reach the PIE / game world only through built capture data: unbuilt, every
    wet floor and pool reflects nothing in PIE (the editor world captures on spawn, so SceneCapture shots hide it).
    Mars has no Lightmass, so the lighting half of this call fails by design; the reflection-capture half still runs."""
    if _les().is_in_play_in_editor():
        raise RuntimeError("stop PIE first")
    _les().build_light_maps(unreal.LightingBuildQuality.QUALITY_PREVIEW, True)
    # the capture data lives in <map>_BuiltData, which save_current_level leaves dirty: save both packages
    pkgs = [p for p in unreal.EditorLoadingAndSavingUtils.get_dirty_map_packages() if p.get_name().startswith(MAP)]
    unreal.EditorLoadingAndSavingUtils.save_packages(pkgs, True)
    return [p.get_name() for p in pkgs]


def _rot(eye, target):
    d = [t - e for e, t in zip(eye, target)]
    yaw = math.degrees(math.atan2(d[1], d[0]))
    pitch = math.degrees(math.atan2(d[2], math.hypot(d[0], d[1])))
    return unreal.Rotator(roll=0.0, pitch=pitch, yaw=yaw)


def _post(settings, shot):
    """The vignette grade on a PostProcessSettings struct (camera or capture)."""
    pp = shot.get("post", {})
    for k, v in (("override_auto_exposure_method", True), ("auto_exposure_method", unreal.AutoExposureMethod.AEM_MANUAL),
                 ("override_auto_exposure_bias", True), ("auto_exposure_bias", pp.get("exposure", 8.7)),
                 ("override_bloom_intensity", True), ("bloom_intensity", pp.get("bloom", 0.6)),
                 ("override_vignette_intensity", True), ("vignette_intensity", pp.get("vignette", 0.55)),
                 ("override_white_temp", True), ("white_temp", pp.get("white_temp", 6500.0)),
                 ("override_color_saturation", True),
                 ("color_saturation", unreal.Vector4(*pp.get("saturation", (1.0, 1.0, 1.0, 1.0)))),
                 ("override_color_gain_shadows", True),
                 ("color_gain_shadows", unreal.Vector4(*pp.get("shadow_gain", (1.0, 1.0, 1.0, 1.0)))),
                 ("override_color_contrast", True),
                 ("color_contrast", unreal.Vector4(*pp.get("contrast", (1.12, 1.12, 1.12, 1.0))))):
        try:
            settings.set_editor_property(k, v)
        except Exception as exc:
            unreal.log_warning("[vignettes] post %s: %s" % (k, exc))
    return settings


def _camera(ctx, shot):
    eye, target = shot["eye"], shot["target"]
    cam = ctx.spawn(unreal.CameraActor, eye, sub="", label="Camera", local=False)
    cam.set_actor_rotation(_rot(eye, target), False)
    cc = cam.camera_component
    cc.set_editor_property("field_of_view", float(shot["fov"]))
    cc.set_editor_property("aspect_ratio", float(shot["size"][0]) / shot["size"][1])
    cc.set_editor_property("constrain_aspect_ratio", False)
    cc.set_editor_property("post_process_blend_weight", 1.0)
    cc.set_editor_property("post_process_settings", _post(cc.get_editor_property("post_process_settings"), shot))
    return cam


def _shots():
    with open(SHOTS_JSON) as fh:
        return json.load(fh)


def capture(names=None, out_dir=None, extra=None, scale=1.0, suffix="", source=None, exposure_add=0.0):
    """SceneCapture2D per vignette from its concept camera (and its grade); extra = {key: shot} for probe views;
    source="base" captures flat base colour (layout checks)."""
    out_dir = out_dir or os.path.join(REVIEW, "ue")
    shots = _shots()
    todo = {n: shots[n] for n in (shots if names is None else names) if n in shots}
    todo.update(extra or {})
    world = _world()
    unreal.SystemLibrary.execute_console_command(world, "r.TextureStreaming 0")
    os.makedirs(out_dir, exist_ok=True)
    actor = _eas().spawn_actor_from_class(unreal.SceneCapture2D, unreal.Vector(0, 0, 0))
    done = []
    try:
        comp = actor.get_component_by_class(unreal.SceneCaptureComponent2D)
        comp.set_editor_property("capture_source", unreal.SceneCaptureSource.SCS_BASE_COLOR if source == "base"
                                 else unreal.SceneCaptureSource.SCS_FINAL_COLOR_LDR)
        # capture_every_frame stays at its default (on): with it off the capture ignored every exposure bias (the camera
        # grade, the rig volume) and rendered at one fixed exposure. The actor lives only for this call.
        for key, shot in todo.items():
            ev = CAPTURE_EV + exposure_add
            if ev and source != "base":
                shot = dict(shot, post=dict(shot.get("post", {}), exposure=shot.get("post", {}).get("exposure", 8.7) + ev))
            w, h = int(shot["size"][0] * scale), int(shot["size"][1] * scale)
            rt = unreal.RenderingLibrary.create_render_target2d(world, w, h, unreal.TextureRenderTargetFormat.RTF_RGBA8)
            comp.set_editor_property("texture_target", rt)
            comp.set_editor_property("post_process_blend_weight", 1.0)
            comp.set_editor_property("post_process_settings", _post(unreal.PostProcessSettings(), shot))
            actor.set_actor_location_and_rotation(unreal.Vector(*shot["eye"]), _rot(shot["eye"], shot["target"]),
                                                  False, False)
            comp.set_editor_property("fov_angle", float(shot["fov"]))
            comp.capture_scene()
            unreal.RenderingLibrary.export_render_target(world, rt, out_dir, key + suffix + ".png")
            done.append(os.path.join(out_dir, key + suffix + ".png"))
    finally:
        actor.destroy_actor()
    return done


def top_views(names=None, cut=330.0, width=3400.0, size=1000):
    """Orthographic base-colour plan of each room cut at z = cut (near clip), north (Blender +y) up: a layout check."""
    out_dir = os.path.join(REVIEW, "top")
    os.makedirs(out_dir, exist_ok=True)
    world = _world()
    rt = unreal.RenderingLibrary.create_render_target2d(world, size, size, unreal.TextureRenderTargetFormat.RTF_RGBA8)
    actor = _eas().spawn_actor_from_class(unreal.SceneCapture2D, unreal.Vector(0, 0, 0))
    done = []
    try:
        comp = actor.get_component_by_class(unreal.SceneCaptureComponent2D)
        comp.set_editor_property("capture_source", unreal.SceneCaptureSource.SCS_BASE_COLOR)
        comp.set_editor_property("projection_type", unreal.CameraProjectionMode.ORTHOGRAPHIC)
        comp.set_editor_property("ortho_width", width)
        comp.set_editor_property("auto_calculate_ortho_planes", False)
        comp.set_editor_property("override_custom_near_clipping_plane", True)
        comp.set_editor_property("custom_near_clipping_plane", 3000.0 - cut)
        comp.set_editor_property("texture_target", rt)
        for n in (names or NAMES):
            ox = NAMES.index(n) * PITCH
            cy = {"sewer": -900.0, "sarcophagus": -1200.0, "ossuary": -1400.0}.get(n, -1600.0)
            actor.set_actor_location_and_rotation(unreal.Vector(ox, cy, 3000.0), unreal.Rotator(roll=0.0, pitch=-90.0, yaw=-90.0),
                                                  False, False)
            comp.capture_scene()
            unreal.RenderingLibrary.export_render_target(world, rt, out_dir, n + "_top.png")
            done.append(os.path.join(out_dir, n + "_top.png"))
    finally:
        actor.destroy_actor()
    return done


# ------------------------------------------------------------------ PIE


def pie_start():
    """Request PIE (it starts on the next tick: call pie_view in a later call)."""
    _les().editor_request_begin_play()
    return True


def pie_stop():
    _les().editor_request_end_play()
    return True


def _pie_client():
    """(world, local player controller): the client world with a local controller (UEDPIE_1 under a dedicated server,
    UEDPIE_0 standalone)."""
    worlds = sorted(unreal.EditorLevelLibrary.get_pie_worlds(True), key=lambda w: w.get_outermost().get_name(),
                    reverse=True)
    for w in worlds:
        for pc in unreal.GameplayStatics.get_all_actors_of_class(w, unreal.PlayerController):
            if pc.is_local_controller():
                return w, pc
    raise RuntimeError("no PIE world with a local player controller (is PIE running?)")


def pie_view(name, tag="a", res=(1600, 900)):
    """Set the PIE client's view target to vignette `name`'s camera and queue a high-res screenshot of it into
    Saved/Screenshots/EnvVignettes/<name>_<tag>.png (written at the end of the frame: one vignette per call)."""
    world, pc = _pie_client()
    label = "V%d_%s_Camera" % (NAMES.index(name) + 1, "".join(w.capitalize() for w in name.split("_")))
    cams = [c for c in unreal.GameplayStatics.get_all_actors_of_class(world, unreal.CameraActor) if c.get_actor_label() == label]
    if not cams:
        raise RuntimeError("camera %s not in %s" % (label, world.get_outermost().get_name()))
    pc.set_view_target_with_blend(cams[0], 0.0)
    os.makedirs(SHOT_DIR, exist_ok=True)
    path = os.path.join(SHOT_DIR, "%s_%s.png" % (name, tag))
    unreal.AutomationLibrary.take_high_res_screenshot(res[0], res[1], path, cams[0])
    return {"world": world.get_outermost().get_name(), "camera": label, "file": path}


# ================================================================== vignette materials
VIG_MATS = spec.UE_ROOT + "/Vignettes/Materials"
CANDLES = "/Game/Mars/Gameplay/Cooking/Candles"


def _vmi(name, parent, scalars=None, vectors=None):
    """A vignette-only instance, (re)written every build so its numbers live here."""
    mel = unreal.MaterialEditingLibrary
    path = "%s/%s" % (VIG_MATS, name)
    m = _load(path)
    if m is None:
        m = unreal.AssetToolsHelpers.get_asset_tools().create_asset(name, VIG_MATS, unreal.MaterialInstanceConstant,
                                                                    unreal.MaterialInstanceConstantFactoryNew())
        _CACHE[path] = m
    mel.set_material_instance_parent(m, _load(parent) if isinstance(parent, str) else parent)
    for k, v in (scalars or {}).items():
        mel.set_material_instance_scalar_parameter_value(m, k, v)
    for k, v in (vectors or {}).items():
        mel.set_material_instance_vector_parameter_value(m, k, unreal.LinearColor(*v))
    mel.update_material_instance(m)
    unreal.EditorAssetLibrary.save_loaded_asset(m)
    return m


def materials():
    kit_mi = "/Game/Mars/Environment/Materials/Instances/"
    out = {
        "flame_spirit": _vmi("CandleFlameSpirit_Mars_MI", CANDLES + "/Materials/CandleFlame_Mars_MI",
                             {"Intensity": 6.0}, {"Core Color": (0.62, 0.86, 1.0, 1.0), "Tip Color": (0.12, 0.32, 1.0, 1.0),
                                                  "Base Color": (0.05, 0.1, 0.6, 1.0)}),
        "wax_spirit": _vmi("CandleWaxSpirit_Mars_MI", CANDLES + "/Materials/CandleWax_Mars_MI",
                           {"Glow Intensity": 1.4}, {"Glow Color": (0.25, 0.5, 1.0, 1.0), "Tint": (0.8, 0.86, 1.0, 1.0)}),
        "floor_wet": _vmi("StoneFloorWet_Spillring_Mars_MI", kit_mi + "StoneFloor_Spillring_Mars_MI",
                          {"PaintRoughnessBias": -0.85}),
        "floor_wet_warm": _vmi("StoneFloorWet_Bellfold_Mars_MI", kit_mi + "StoneFloor_Bellfold_Mars_MI",
                               {"PaintRoughnessBias": -0.4}),
        "lantern_spirit": mi("EnvGlowSpirit_Mars_MI"),
    }
    return out


def candles(ctx, loc, yaw=0.0, kind="CandleCluster_A", scale=1.6, spirit=False, light=True, cd=14.0, sub="Candles"):
    """A candle-set mesh (cluster / single) with its flame lamp 30 cm over it (spirit = blue flame + wax)."""
    a = ctx.spawn(_load("%s/Meshes/%s_Mars_SM" % (CANDLES, kind)), loc, (0.0, yaw, 0.0), sub, kind, scale)
    if spirit:
        mats = ctx.mats
        comp = a.static_mesh_component
        for k, sm in enumerate(comp.static_mesh.get_editor_property("static_materials")):
            slot = str(sm.get_editor_property("material_slot_name"))
            if slot == "Flame":
                comp.set_material(k, mats["flame_spirit"])
            elif slot == "Wax":
                comp.set_material(k, mats["wax_spirit"])
    if light:
        ctx.lamp((loc[0], loc[1], loc[2] + 30.0 * scale), SPIRIT if spirit else FLAME, cd, 600.0, 2.0, False, "CandleLight")
    return a


def wall_run(ctx, piece, x0, y, n, rot, z=0.0, step=4.0):
    """n kit pieces in a row along the piece's own length (Blender plan metres)."""
    out = []
    r = math.radians(rot)
    for k in range(n):
        out.append(ctx.kit(piece, x0 + math.cos(r) * step * k, y + math.sin(r) * step * k, z, rot))
    return out


def ossuary_shelf(ctx, loc, yaw, candle=None, fill=True, label="Shelf"):
    """OssuaryShelf_A with its four bays packed (OssuaryFill_A/B/B2 at each SOCKET_Bay_<n>1) and a candle ledge on top."""
    s = ctx.prop("OssuaryShelf_A", loc, yaw, sub="Ossuary", label=label)
    if fill:
        for z in (14.0, 74.6, 134.1, 193.5):
            name = ctx.rng.choice(("OssuaryFill_B", "OssuaryFill_B2", "OssuaryFill_B"))
            ctx.prop(name, child(loc, yaw, (ctx.rng.uniform(-4, 4), 30.0, z + 1.0)), yaw + ctx.rng.choice((0.0, 180.0)) * 0,
                     sub="Ossuary")
    if candle:
        ctx.prop(candle[0], child(loc, yaw, (candle[1], 70.0, 260.0)), yaw, 1.35, sub="Candles")
        ctx.lamp(child(loc, yaw, (candle[1], 95.0, 300.0)), FLAME, candle[2], 700.0, 2.0, True, "LedgeCandle")
    return s


# ================================================================== 1 ossuary
@vignette
def build_ossuary(ctx):
    """Concept 1: an aisle of ossuary bays packed with skulls, a freestanding ossuary pier, candles with wax over the
    ledges, rubble, warm candle light, a blue stair opening far away (atrium_2: the nave, galleries above)."""
    ctx.biome = "Bellfold"
    spawn_room(ctx, "crypt_atrium_2", drop=("crypt_stair", "box_"), swap={"crypt_wall_ossuary_4m": "crypt_wall_ossuary_4m"})
    # aisle of shelves: left faces E, right faces W, back at x = -+3.55 m
    ctx.light_scale = 2.5
    for k, y in enumerate((1.9, 4.0, 12.6, 14.7)):
        ossuary_shelf(ctx, B(-3.0, y), FACE["E"], ("CandleLedge_A", -40.0, 16.0) if k in (1, 2) else None,
                      label="ShelfL%d" % k)
    for k, y in enumerate((1.6, 3.7, 13.4)):
        ossuary_shelf(ctx, B(3.0, y), FACE["W"], ("CandleLedge_C", 30.0, 18.0) if k in (0, 2) else None,
                      label="ShelfR%d" % k)
    pier = B(0.7, 9.0)
    ctx.prop("OssuaryPier_A", pier, 14.0, sub="Ossuary")
    ctx.prop("CandleLedge_B", child(pier, 14.0, (-60.0, 76.0, 300.0)), 14.0, 1.4, sub="Candles")
    ctx.lamp(child(pier, 14.0, (-60.0, 110.0, 340.0)), FLAME, 14.0, 700.0, 2.0, True, "PierCandle")
    # floor: bone piles at the shelf feet, scatter, rubble, skulls
    for x, y, yaw in ((-2.6, 3.0, 80), (2.7, 2.4, -100), (-2.7, 13.5, 70), (2.6, 12.6, 260), (1.7, 9.9, 20)):
        ctx.prop(ctx.rng.choice(("BonePile_A", "BonePile_B")), B(x, y), yaw, 1.0, sub="Floor")
    ctx.scatter(("BoneScatter_A", "BoneScatter_B"), B(0.0, 5.5), 160.0, 3, "Floor")
    ctx.scatter(("Skull_A", "Skull_B", "Skull_C", "Femur_A", "Femur_B", "Humerus_A", "BoneShards_A", "Jaw_A"), B(0.2, 5.0),
                260.0, 22, "Floor", (1.0, 1.4))
    ctx.scatter(("Rubble_A", "Rubble_B", "Rubble_C"), B(0.4, 7.5), 300.0, 6, "Floor")
    ctx.prop("SkullStack_A", B(-0.6, 8.2), 30.0, 1.2, sub="Floor")
    # right foreground: a stone pedestal, candles guttering over its front edge, skulls on top
    ped = (0.35, 2.55)
    ctx.prop("Boxes/BoxStoneBlock1m", B(*ped), 90.0, (1.1, 1.5, 2.0), sub="Pedestal")
    ctx.prop("CandleLedge_C", B(ped[0], ped[1] - 0.4, 1.02), FACE["S"], 1.5, sub="Pedestal")
    ctx.lamp(B(ped[0], ped[1] - 0.65, 1.55), FLAME, 16.0, 600.0, 2.0, True, "PedestalCandles")
    ctx.prop("Skull_B", B(ped[0] - 0.2, ped[1] + 0.2, 1.02), 160.0, 1.6, sub="Pedestal")
    ctx.prop("Skull_A", B(ped[0] + 0.3, ped[1] + 0.25, 1.02), 200.0, 1.5, sub="Pedestal")
    ctx.prop("Skull_A", B(-2.4, 1.2), 70.0, 1.6, sub="Floor")
    # the far end: a banner over the N gallery, the N portal opening onto a stair climbing away in blue light
    ctx.prop("Banner_A", B(-2.6, 23.95, 7.7), FACE["S"], sub="Far")
    ctx.prop("Banner_B", B(2.8, 23.95, 7.8), FACE["S"], sub="Far")
    for y in (24.0, 28.0):
        ctx.kit("crypt_floor_4x4", -2.0, y, 0.0, 0.0, sub="Stair")
    ctx.kit("crypt_stair_flight", -1.5, 24.3, 0.0, 0.0, sub="Stair")
    for y in (24.0, 28.0):
        for z in (0.0, 3.5):
            ctx.kit("crypt_wall_4m", -2.0, y, z, 90.0, sub="Stair")
            ctx.kit("crypt_wall_4m", 2.0, y + 4.0, z, 270.0, sub="Stair")
    ctx.kit("crypt_floor_4x4", -2.0, 28.0, 4.0, 0.0, sub="Stair")
    for z in (0.0, 3.5, 7.0):
        ctx.kit("crypt_wall_4m", -2.0, 32.0, z, 0.0, sub="Stair")
    ctx.kit("crypt_roof_4x4", -2.0, 24.0, 4.5, 0.0, sub="Stair")
    ctx.kit("crypt_roof_4x4", -2.0, 28.0, 4.5, 0.0, sub="Stair")
    ctx.lamp(B(0.0, 26.5, 2.2), COLD, 70.0, 900.0, 4.0, True, "StairBlue")
    ctx.lamp(B(0.6, 30.5, 6.0), COLD, 60.0, 900.0, 4.0, True, "StairBlueTop")
    # seep: a slow drip off the gallery edge onto the nave floor, its puddles in the candle light
    ctx.leak(B(-1.6, 6.4, 3.8), "OssuarySeep", 0.0, "Leak_Seep", seed=3, trace={"attach_up": True})
    ctx.puddles(B(-0.6, 6.0, 0.4), 4, 140.0, 7, "SeepPuddles", size_min=40.0, size_max=90.0, wetness=0.85)
    for k, (x, y) in enumerate(((-2.6, 19.7), (2.4, 19.7))):     # webs under the N gallery edge
        ctx.vine(B(x, y, 2.5), "Cobweb", "Patch", "Air", shape={"PatchRadiusCm": 90.0}, seed=40 + k, label="Cobwebs")
    # light: candle-warm key, a pier lamp, gallery fill, a dim aisle glow; no cold in the near room
    ctx.lamp(B(-0.4, 4.5, 3.0), WARM, 40.0, 1300.0, 3.0, True, "Key")
    ctx.lamp(B(1.9, 7.6, 2.4), FLAME, 22.0, 900.0, 3.0, True, "PierFill")
    ctx.lamp(B(0.0, 19.5, 6.2), WARM, 22.0, 1200.0, 3.0, False, "GalleryFill")
    ctx.lamp(B(-6.0, 11.0, 2.6), WARM, 12.0, 900.0, 3.0, False, "AisleGlow")
    ctx.reflection(B(0.0, 10.0, 3.0), 1800.0, "warm", 0.35)
    return {"eye": ctx.w(*B(-1.65, 0.55, 1.45)), "target": ctx.w(*B(0.5, 14.0, 2.3)), "fov": 66.0, "size": [1200, 800],
            "post": {"exposure": 7.8, "white_temp": 5600.0, "vignette": 0.6}}


# ================================================================== 2 sewer
@vignette
def build_sewer(ctx):
    """Concept 2: a rusty pipe with flanges and an 8-spoke valve wheel on a wet stone wall, the pipe dropping into the
    floor, water trickling into a stone basin with rings, wet flagstones with puddles, a drain grate channel, a blue
    spirit lantern on a short post, barrels / crates / a sack, ivy, and a warm torch-lit corridor beyond an arch."""
    ctx.biome = "Spillring"
    ctx.light_scale = 2.5
    spawn_room(ctx, "crypt_side_chamber", drop=("box_",), swap={"crypt_wall_ossuary_4m": "crypt_wall_4m"})
    room_material(ctx, "Floor", ctx.mats["floor_wet"])
    Y, Z = -1200.0 + 42.0, 200.0          # pipe axis 42 cm off the N wall face
    # the run from the E wall leftward: collar, tee (riser to the ceiling), flange, valve, flange, pipe, elbow down
    ctx.prop("PipeCollar", (400.0, Y, Z), 180.0, sub="Pipe")
    ctx.prop("PipeTee", (300.0, Y, Z), 0.0, sub="Pipe")
    ctx.prop("Pipe_1m", (350.0, Y, Z + 50.0), 0.0, pitch=90.0, sub="Pipe")
    ctx.prop("PipeFlange", (300.0, Y, Z), 0.0, sub="Pipe")
    ctx.prop("ValveGate_A", (250.0, Y, Z), 0.0, sub="Pipe")
    ctx.prop("ValveWheel_A", (275.0, Y + 49.0, Z), 90.0, 1.15, sub="Pipe")
    ctx.prop("PipeFlange", (250.0, Y, Z), 0.0, sub="Pipe")
    ctx.prop("Pipe_50cm", (200.0, Y, Z), 0.0, sub="Pipe")
    ctx.prop("PipeElbow90", (200.0, Y, Z), 0.0, pitch=180.0, sub="Pipe")
    ctx.prop("Pipe_1m", (150.0, Y, Z - 50.0), 0.0, pitch=-90.0, sub="Pipe")
    ctx.prop("Pipe_1m", (150.0, Y, Z - 150.0), 0.0, pitch=-90.0, sub="Pipe")
    ctx.prop("PipeCollar", (150.0, Y, 2.0), 0.0, pitch=90.0, sub="Pipe")
    ctx.prop("PipeBracket", (225.0, -1200.0, Z), FACE["S"], sub="Pipe")
    # basin under the valve, its water, the trickle and joint drips into it
    basin = (290.0, -1200.0 + 52.0, 0.0)
    ctx.prop("StoneBasin_A", basin, 0.0, sub="Basin")
    ctx.still_water((basin[0], basin[1], 47.0), (178.0, 82.0), False, 0.6, label="BasinWater")
    ctx.leak((252.0, Y + 30.0, Z - 22.0), "PipeTrickle", FACE["S"] + 90.0, "Leak_Trickle", trace={"attach_up": False})
    ctx.leak((302.0, Y + 28.0, Z - 30.0), "PipeJoint", FACE["S"] + 90.0, "Leak_Joint", trace={"attach_up": False},
             timing={"rate_min": 1.2, "rate_max": 1.8, "jitter": 0.4})
    ctx.streak((275.0, -1198.0, 300.0), 90.0, 4, "Streak_Valve", dampness=0.6, flow=20.0, width_cm=90.0)
    # drain channel, spirit lantern post, ivy
    for x in (200.0, 300.0, 400.0 - 52.0):
        ctx.prop("DrainGrate_A", (x, -1200.0 + 130.0, 0.5), 0.0, sub="Floor")
    lantern = (178.0, -1200.0 + 118.0, 0.0)
    ctx.prop("SpiritLantern_Post", lantern, 20.0, sub="Lantern")
    ctx.lamp((lantern[0] + 10.0, lantern[1] + 20.0, 75.0), TEAL, 34.0, 800.0, 2.0, True, "SpiritLantern")
    ctx.lamp((300.0, -980.0, 210.0), TEAL, 7.0, 500.0, 2.0, True, "ValveGlow")
    ctx.lamp((140.0, -1020.0, 260.0), WARM, 3.0, 400.0, 2.0, False, "RustWarm")       # keeps the rust from going olive
    ctx.vine((330.0, -1200.0 + 30.0, 70.0), "Ivy", "Creep", "Air", shape={"HeightCm": 260.0, "StrandCount": 3}, seed=21,
             label="WallIvy_A")
    ctx.vine((40.0 + 200.0, -1200.0 + 30.0, 240.0), "Ivy", "Creep", "Air", shape={"HeightCm": 100.0, "StrandCount": 2},
             seed=22, label="WallIvy_B")
    # wet floor: a vault line dripping onto the flags, loose puddles toward the camera
    ctx.leak((60.0, -760.0, 330.0), "VaultLine", 0.0, "Leak_Vault", count=4, line_length=320.0, seed=5)
    ctx.puddles((40.0, -800.0, 20.0), 9, 260.0, 11, "FloorPuddles", size_min=70.0, size_max=160.0, wetness=0.95)
    ctx.puddles((230.0, -1010.0, 20.0), 3, 90.0, 12, "BasinPuddles", size_min=50.0, size_max=110.0, wetness=0.95)
    # clutter: a big barrel left foreground, crates and a sack right, more along the W wall
    ctx.prop("Barrel_A", (-55.0, -790.0, 0.0), 30.0, 1.25, sub="Clutter")
    ctx.prop("Crate_A", (190.0, -770.0, 0.0), 12.0, 1.3, sub="Clutter")
    ctx.prop("Sack_B", (150.0, -715.0, 0.0), 50.0, 1.25, sub="Clutter")
    ctx.prop("Crate_B", (345.0, -745.0, 0.0), -8.0, 1.2, sub="Clutter")
    ctx.prop("Barrel_A", (-330.0, -1080.0, 0.0), 0.0, 1.1, sub="Clutter")
    ctx.prop("Crate_A", (-320.0, -960.0, 0.0), 30.0, 1.1, sub="Clutter")
    # the corridor beyond the N portal: floor, walls, roof, a stone balustrade, crates, a torch at its end
    for y in (12.0, 16.0):
        ctx.kit("crypt_floor_4x4", -2.0, y, 0.0, 0.0, sub="Corridor").static_mesh_component.set_material(
            0, ctx.mats["floor_wet"])
        ctx.kit("crypt_roof_4x4", -2.0, y, 0.0, 0.0, sub="Corridor")
        ctx.kit("crypt_wall_4m", -2.0, y, 0.0, 90.0, sub="Corridor")
        ctx.kit("crypt_wall_4m", 2.0, y + 4.0, 0.0, 270.0, sub="Corridor")
    ctx.kit("crypt_wall_4m", -2.0, 20.0, 0.0, 0.0, sub="Corridor")
    ctx.kit("crypt_balustrade_4m", 1.25, 12.3, 0.0, 90.0, sub="Corridor")
    ctx.prop("Crate_A", B(-1.4, 17.2), 20.0, 1.1, sub="Corridor")
    ctx.prop("Barrel_A", B(-1.45, 18.6), 0.0, 1.0, sub="Corridor")
    torch = B(-0.9, 19.96, 1.75)
    ctx.prop("TorchSconce_A", torch, FACE["S"], 1.2, sub="Corridor")
    ctx.lamp(child(torch, FACE["S"], (0.0, 45.0, 55.0)), FLAME, 35.0, 900.0, 3.0, True, "Torch")
    ctx.lamp(B(0.2, 15.0, 2.6), WARM, 6.0, 700.0, 3.0, True, "CorridorFill")
    # cold key from the vault, a rim on the pipe wall, warm spill at the arch
    ctx.lamp((60.0, -620.0, 310.0), TEAL, 12.0, 1100.0, 3.0, True, "ColdKey")
    ctx.lamp((260.0, -1000.0, 300.0), TEAL, 4.0, 700.0, 3.0, True, "PipeRim")
    ctx.lamp(B(0.0, 12.4, 1.6), WARM, 10.0, 600.0, 3.0, False, "ArchSpill")
    ctx.reflection((80.0, -800.0, 170.0), 900.0, "cold", 1.0)
    ctx.reflection(B(0.0, 16.0, 1.5), 500.0, "warm", 0.4)
    return {"eye": ctx.w(-15.0, -640.0, 130.0), "target": ctx.w(175.0, -1200.0, 135.0), "fov": 70.0, "size": [1200, 800],
            "post": {"exposure": 7.2, "white_temp": 7600.0, "vignette": 0.65, "saturation": (0.8, 0.8, 0.8, 1.0)}}


# ================================================================== atriums (3, 4)
def _atrium_shell(ctx, room):
    data = spawn_room(ctx, room, drop=("box_", "crypt_statue_alcove"), swap={"crypt_wall_ossuary_4m": "crypt_wall_4m"},
                      keep=lambda d: not (d["piece"].startswith("crypt_stair") and d["z"] < 1.0))
    for x in (-8.0, -4.0, 0.0, 4.0):           # a roof over the nave so the roots have a ceiling to hang from
        for y in range(0, 28, 4):
            ctx.kit("crypt_roof_4x4", x, float(y), 8.5, 0.0, sub="NaveRoof")
    return data


def _rail_curtains(ctx, data, room, levels, seeds, width=300.0, every=2):
    """Ivy curtains off the E and W gallery balustrades (actor 30 cm out past the rail, +X out over the nave)."""
    made = 0
    for k, (loc, yaw, an, d) in enumerate(anchors(room, "crypt_balustrade_4m", "rail", data)):
        if d["z"] not in levels or abs(abs(d["x"]) - 8.0) > 0.6 or k % every:
            continue
        out = 1.0 if d["x"] < 0 else -1.0
        ctx.vine((loc[0] + out * 30.0, loc[1], loc[2] - 2.0), "Ivy", "Curtain", "Air", 0.0 if out > 0 else 180.0,
                 shape={"WidthCm": width, "StrandCount": 5}, seed=seeds + k, label="RailIvy_%d" % k)
        made += 1
    return made


@vignette
def build_atrium_blue(ctx):
    """Concept 3: three storeys of galleries, two giant twisted roots from top to floor, ivy off the rails and up the
    pillars, blue candle niches, a sigil door on the far wall, a floor medallion; deep blue with one warm torch."""
    ctx.biome = "Spillring"
    ctx.light_scale = 2.5
    room = "crypt_atrium_3"
    data = _atrium_shell(ctx, room)
    # far (S) wall: a ledge at the first gallery level, the sigil door on it, candle niches either side
    ctx.kit("crypt_ledge_4m", 2.0, 0.0, 4.0, 180.0, sub="Sigil")
    ctx.prop("SigilDoor_A", B(0.0, 0.0, 4.0), FACE["N"], sub="Sigil")
    for x in (-2.6, 2.6):
        n = B(x, 0.0, 4.45)
        ctx.prop("CandleNiche_A", n, FACE["N"], sub="Niches")
        candles(ctx, child(n, FACE["N"], (0.0, 16.0, 20.4)), 0.0, "CandleCluster_B", 1.5, True, cd=10.0)
    ctx.prop("FloorMedallion_A", B(0.0, 13.0, 0.0), 0.0, 1.5, sub="Floor")
    # blue candle niches along the gallery back walls, all three levels
    for z in (0.5, 4.5, 8.5):
        for y in (4.0, 12.0, 20.0, 26.0):
            for side in (-1.0, 1.0):
                if z < 1.0 and y > 25.0:
                    continue
                n = B(side * 11.98, y, z)
                yaw = FACE["E"] if side < 0 else FACE["W"]
                ctx.prop("CandleNiche_A", n, yaw, sub="Niches")
                candles(ctx, child(n, yaw, (0.0, 16.0, 20.4)), yaw, ctx.rng.choice(("CandleCluster_A", "CandleCluster_C")),
                        1.4, True, cd=6.0)
    # the roots, leaning down through the void, and ivy everywhere a plant could hold
    ctx.vine(B(-4.4, 12.0, 11.85), "GiantRoot", "Drop", "Ground", seed=31, label="GiantRoot_L")
    ctx.vine(B(4.8, 15.5, 11.85), "GiantRoot", "Drop", "Ground", seed=47, label="GiantRoot_R")
    _rail_curtains(ctx, data, room, (4.0, 8.0), 300)
    for x, y in ((-8.4, 26.0), (8.4, 26.0), (-8.4, 18.0), (8.4, 10.0)):
        ctx.vine(B(x + (0.6 if x < 0 else -0.6), y, 4.2), "Ivy", "Creep", "Air", shape={"HeightCm": 360.0, "StrandCount": 2},
                 seed=int(abs(x * 10 + y)), label="PillarIvy")
    # light: a cold shaft from above onto the door and medallion, the sigil glow, cold fills on every gallery, one
    # warm torch far right
    ctx.lamp(B(-1.0, 9.0, 11.4), COLD, 900.0, 3000.0, 10.0, True, "Shaft", spot=(-72.0, 90.0, 30.0))
    ctx.lamp(B(-1.0, 1.8, 7.2), SPIRIT, 60.0, 1000.0, 4.0, False, "SigilGlow")
    ctx.lamp(B(-1.0, 15.0, 6.0), COLD, 160.0, 3200.0, 10.0, False, "VoidFill")
    ctx.lamp(B(-1.0, 13.0, 1.4), COLD, 40.0, 1200.0, 6.0, False, "FloorFill")
    for z in (2.6, 6.6, 10.6):
        for y in (5.0, 13.0, 21.0):
            for x in (-10.2, 10.2):
                ctx.lamp(B(x, y, z), SPIRIT, 40.0, 1000.0, 4.0, False, "GalleryBlue")
    torch = B(11.98, 3.0, 5.6)
    ctx.prop("TorchSconce_A", torch, FACE["W"], 1.2, sub="Torch")
    ctx.lamp(child(torch, FACE["W"], (0.0, 45.0, 55.0)), FLAME, 25.0, 700.0, 3.0, True, "Torch")
    ctx.reflection(B(0.0, 14.0, 5.0), 2600.0, "cold", 0.3)
    ctx.lamp(B(-2.0, 27.75, 10.25), COLD, 12.0, 500.0, 4.0, False, "ParapetTop")
    for k in range(5):                             # a solid parapet coping in front of the viewer, as in the frame
        ctx.prop("Boxes/BoxStoneBlock1m", B(-4.4 + 1.02 * k, 27.72, 8.0), ctx.rng.uniform(-1.5, 1.5),
                 (1.0, 1.05, 1.9), sub="Parapet")
    ctx.lamp(B(-1.5, 8.0, 6.5), COLD, 45.0, 900.0, 6.0, False, "RootRimL")
    ctx.lamp(B(2.5, 11.0, 7.5), COLD, 45.0, 900.0, 6.0, False, "RootRimR")
    return {"eye": ctx.w(*B(-2.0, 29.3, 9.95)), "target": ctx.w(*B(-1.2, 2.0, 2.0)), "fov": 82.0, "size": [1400, 700],
            "post": {"exposure": 8.3, "white_temp": 9000.0, "vignette": 0.6}}


@vignette
def build_gallery_warm(ctx):
    """Concept 4: the atrium in warm light from a gallery: red banners with the gold flame, wall lanterns, crates /
    barrels / sacks on the galleries, the roots through the void, a warm lantern beside the viewer."""
    ctx.biome = "Bellfold"
    ctx.light_scale = 2.5
    room = "crypt_atrium_carved"
    data = _atrium_shell(ctx, room)
    # far (E) side: banners and lanterns on the gallery back walls, two levels
    for z, hang in ((4.0, 7.6), (8.0, 11.6)):
        for y in (7.0, 15.0, 23.0):
            ctx.prop("Banner_A", B(11.98, y, hang - 0.0), FACE["W"], sub="Banners")
        for y in (11.0, 19.0, 3.0):
            lan = B(11.98, y, z + 2.3)
            ctx.prop("WallLantern_A", lan, FACE["W"], 1.2, sub="Lanterns")
            ctx.lamp(child(lan, FACE["W"], (0.0, 55.0, -30.0)), WARM, 18.0, 800.0, 3.0, True, "Lantern")
        ctx.prop("Banner_A", B(-3.0, 31.98, hang), FACE["S"], sub="Banners")
        ctx.prop("Banner_A", B(3.0, 31.98, hang), FACE["S"], sub="Banners")
    # ground level: blue lanterns on the arcade piers
    for y in (6.0, 14.0, 22.0):
        lan = B(11.98, y, 2.2)
        ctx.prop("WallLantern_A", lan, FACE["W"], 1.2, sub="Lanterns", mats={1: ctx.mats["lantern_spirit"]})
        ctx.lamp(child(lan, FACE["W"], (0.0, 55.0, -30.0)), SPIRIT, 10.0, 600.0, 3.0, False, "SpiritLantern")
    # gallery clutter, far side and the viewer's own gallery
    for y in (5.0, 13.0, 21.0):
        x = 10.6
        ctx.prop("Crate_A", B(x, y, 4.0), ctx.rng.uniform(0, 40), 1.1, sub="Clutter")
        ctx.prop("Barrel_A", B(x + 0.2, y + 1.1, 4.0), 0.0, 1.0, sub="Clutter")
        ctx.prop("Sack_A", B(x - 0.7, y - 0.6, 4.0), 30.0, 1.0, sub="Clutter")
        ctx.prop("SackPile_A", B(x, y + 2.6, 8.0), 90.0, 1.0, sub="Clutter")
        ctx.prop("Crate_B", B(x, y - 1.0, 8.0), 15.0, 1.1, sub="Clutter")
    ctx.prop("Barrel_A", B(-10.6, 16.2, 4.0), 0.0, 1.15, sub="Near")
    ctx.prop("Sack_A", B(-10.2, 15.7, 4.0), 60.0, 1.2, sub="Near")
    ctx.prop("Crate_A", B(-10.7, 12.0, 4.0), 20.0, 1.2, sub="Near")
    ctx.prop("Crate_B", B(-10.75, 11.95, 4.68), -10.0, 1.1, sub="Near")
    ctx.prop("Sack_B", B(-10.3, 16.6, 4.0), 10.0, 1.2, sub="Near")
    for z in (4.0, 8.0):                           # dim warm pools along the far galleries
        for y in range(3, 29, 4):
            ctx.lamp(B(10.4, float(y), z + 2.6), WARM, 9.0, 650.0, 4.0, False, "FarGallery")
    ctx.lamp(B(-1.0, 11.0, 5.0), COLD, 30.0, 900.0, 6.0, False, "RootRimA")
    ctx.lamp(B(3.0, 15.5, 6.0), COLD, 30.0, 900.0, 6.0, False, "RootRimB")
    # roots
    ctx.vine(B(-1.2, 13.5, 11.85), "GiantRoot", "Drop", "Ground", seed=53, label="GiantRoot_A")
    ctx.vine(B(3.6, 18.0, 11.85), "GiantRoot", "Drop", "Ground", seed=61, label="GiantRoot_B")
    ctx.vine(B(1.0, 6.0, 11.85), "GiantRoot", "Drop", "Ground", seed=67, label="GiantRoot_C")
    # light: warm key over the viewer's parapet (the chef's lantern), warm high fill, cold low fill in the pit
    ctx.lamp(B(-10.0, 13.6, 4.75), WARM, 16.0, 700.0, 2.0, True, "HandLantern")
    ctx.lamp(B(4.0, 15.0, 10.5), WARM, 30.0, 1800.0, 6.0, False, "HighFill")
    ctx.lamp(B(0.0, 15.0, 1.5), COLD, 25.0, 1500.0, 6.0, False, "PitFill")
    ctx.reflection(B(0.0, 15.0, 5.0), 2600.0, "warm", 0.3)
    return {"eye": ctx.w(*B(-11.6, 14.0, 6.1)), "target": ctx.w(*B(6.0, 14.6, 2.4)), "fov": 72.0, "size": [1400, 788],
            "post": {"exposure": 8.4, "white_temp": 5700.0, "vignette": 0.6}}


# ================================================================== 5 cistern
@vignette
def build_cistern(ctx):
    """Concept 5: a stone causeway across dark still water between piers, vault drips with ripple rings, hanging moss,
    an iron portcullis at the end backlit blue, a candle in a wall niche beside the viewer."""
    ctx.biome = "Spillring"
    ctx.light_scale = 2.5
    room = "crypt_hall_carved"
    spawn_room(ctx, room, drop=("box_",), swap={"crypt_wall_ossuary_4m": "crypt_wall_4m"})
    water_z = 40.0
    mats = ctx.mats
    ctx.still_water(B(0.0, 16.0, water_z / 100.0), (2380.0, 3180.0), True, 1.0, label="CisternWater")
    # causeway: 3 m flags on a raised bed, curb stones along both edges
    for y in range(0, 32, 4):
        ctx.kit("crypt_floor_3x4", -1.5, float(y), 0.62, 0.0, sub="Causeway")
    blk = mesh("Boxes/BoxStoneBlock1m")
    for y in [0.5 + 1.08 * k for k in range(29)]:
        for x in (-1.5, 1.5):
            ctx.prop("Boxes/BoxStoneBlock1m", B(x, y, 0.62), 90.0 + ctx.rng.uniform(-3, 3),
                     (1.0, 0.62, ctx.rng.uniform(0.32, 0.46)), sub="Causeway")
    room_material(ctx, "Floor3x4", mats["floor_wet"])
    # the N portal: a portcullis, a passage behind it, a cold back light
    ctx.prop("Portcullis_A", B(0.0, 31.85, 0.0), 0.0, sub="Portcullis")
    for y in (32.0,):
        ctx.kit("crypt_floor_4x4", -2.0, y, 0.0, 0.0, sub="Passage")
        ctx.kit("crypt_roof_4x4", -2.0, y, 0.0, 0.0, sub="Passage")
        ctx.kit("crypt_wall_4m", -2.0, y, 0.0, 90.0, sub="Passage")
        ctx.kit("crypt_wall_4m", 2.0, y + 4.0, 0.0, 270.0, sub="Passage")
        ctx.kit("crypt_wall_4m", -2.0, y + 4.0, 0.0, 0.0, sub="Passage")
    ctx.lamp(B(0.0, 34.6, 1.8), COLD, 120.0, 700.0, 3.0, True, "PortcullisBack")
    ctx.lamp(B(0.0, 33.0, 3.0), COLD, 30.0, 500.0, 3.0, False, "PortcullisRim")
    # the viewer's left: a wall stub with a candle niche
    # a wall stub standing on the causeway edge: its niche (faces +x, 0.35 - 1.45 m up the piece) at the viewer's eye
    ctx.kit("crypt_wall_niche_2m", -1.95, 1.0, 0.62, 90.0, sub="Near")
    ctx.kit("crypt_wall_2m", -1.95, -1.0, 0.62, 90.0, sub="Near")
    ctx.kit("crypt_wall_niche_2m", -1.95, 1.0, -0.6, 90.0, sub="Near")      # its footing down into the water
    candles(ctx, B(-1.82, 2.0, 0.99), FACE["E"], "CandleSingle_B", 2.2, False, light=False)
    ctx.lamp(B(-1.3, 2.0, 1.6), FLAME, 4.0, 650.0, 2.0, True, "NicheCandle")
    ctx.scatter(("Rubble_A", "Rubble_C"), B(-1.2, 1.4, 0.62), 60.0, 3, "Near")
    # drips from the vault onto the water, hanging moss strands under the arches
    for k, (x, y) in enumerate(((-3.0, 7.0), (3.2, 12.5), (-2.6, 19.0), (2.8, 24.0), (-5.5, 11.0))):
        ctx.leak(B(x, y, 9.0), "CisternDrip", 0.0, "Leak_Cistern%d" % k, seed=11 + k, count=4, radius=90.0)
    for k, (x, y) in enumerate(((-4.0, 6.0), (4.0, 6.0), (-4.0, 12.0), (4.0, 12.0), (-4.0, 20.0), (4.0, 20.0),
                                (0.0, 10.0), (0.0, 22.0))):
        ctx.vine(B(x, y, 7.0), "HangingMoss", "Patch", "Air", shape={"PatchRadiusCm": 160.0}, seed=70 + k, label="Moss")
    # light: cold dominant from the portcullis end and high fill, the candle warm
    ctx.lamp(B(0.0, 18.0, 8.5), COLD, 80.0, 2400.0, 3.0, False, "HighCold")
    ctx.lamp(B(0.0, 9.0, 4.0), COLD, 25.0, 1200.0, 3.0, False, "MidCold")
    ctx.lamp(B(-5.0, 9.0, 3.0), COLD, 12.0, 900.0, 3.0, False, "PierRimL")
    ctx.lamp(B(5.0, 13.0, 3.0), COLD, 12.0, 900.0, 3.0, False, "PierRimR")
    ctx.reflection(B(0.0, 16.0, 3.0), 2600.0, "cold", 0.3)
    return {"eye": ctx.w(*B(-0.95, 0.4, 1.5)), "target": ctx.w(*B(0.35, 30.0, 1.4)), "fov": 70.0, "size": [1200, 800],
            "post": {"exposure": 9.5, "white_temp": 8000.0, "vignette": 0.65}}


# ================================================================== 6 sarcophagus
@vignette
def build_sarcophagus(ctx):
    """Concept 6: a relief sarcophagus on its plinth with a candle dripping wax off the lid, a faceted urn, dead leaves
    heaped at the base, hooded statues in arched wall niches, iron bars, a dark arch to a stair."""
    ctx.biome = "Bellfold"
    ctx.light_scale = 2.5
    room = "crypt_ossuary_hall"
    spawn_room(ctx, room, drop=("box_",), keep=lambda d: not (d["piece"] == "crypt_pier_h11m5" and d["y"] < 10.0))
    sar = B(0.0, 13.0, 0.0)
    ctx.prop("Sarcophagus_A", sar, 0.0, sub="Sarcophagus")
    ctx.prop("CandleLedge_B", child(sar, 0.0, (92.0, 63.0, 122.0)), 0.0, 1.6, sub="Sarcophagus")
    ctx.lamp(child(sar, 0.0, (92.0, 80.0, 175.0)), FLAME, 26.0, 800.0, 2.0, True, "LidCandle")
    ctx.prop("Urn_A", child(sar, 0.0, (-165.0, 70.0, 0.0)), 15.0, 1.1, sub="Sarcophagus")
    ctx.prop("Urn_C", child(sar, 0.0, (-185.0, -20.0, 0.0)), 40.0, 1.0, sub="Sarcophagus")
    for (x, y, yaw, n) in ((-105.0, 85.0, 0.0, "DeadLeaves_Pile_A"), (60.0, 88.0, 10.0, "DeadLeaves_Pile_B"),
                           (-140.0, 20.0, 90.0, "DeadLeaves_Pile_B"), (140.0, 40.0, -70.0, "DeadLeaves_Pile_A")):
        ctx.prop(n, child(sar, 0.0, (x, y, 0.0)), yaw, 1.1, sub="Leaves")
    ctx.scatter(("DeadLeaves_Scatter_A",), child(sar, 0.0, (0.0, 260.0, 0.0)), 260.0, 6, "Leaves")
    # E wall: statues in niches either side of the barred portal
    for y in (17.6, 20.2):
        n = B(7.98, y, 0.0)
        ctx.prop("StatueNiche_A", n, FACE["W"], sub="Statues")
        ctx.prop(ctx.rng.choice(("HoodedStatue_A", "HoodedStatue_B")), child(n, FACE["W"], (0.0, 26.5, 22.0)), FACE["W"],
                 sub="Statues")
    ctx.prop("Portcullis_B", B(7.85, 12.0, 0.0), FACE["W"], sub="Bars")
    # W portal: a stair climbing away into faint cold light
    ctx.kit("crypt_floor_4x4", -12.0, 10.0, 0.0, 0.0, sub="Stair")
    ctx.kit("crypt_stair_flight", -11.6, 10.5, 0.0, 270.0, sub="Stair")
    ctx.lamp(B(-10.0, 11.8, 2.2), COLD, 8.0, 700.0, 3.0, True, "StairCold")
    # cobwebs in the arches, rootlets through the vault seams
    ctx.vine(B(7.4, 12.0, 2.6), "Cobweb", "Patch", "Air", shape={"PatchRadiusCm": 80.0}, seed=91, label="Cobwebs_E")
    ctx.vine(B(-7.5, 10.0, 2.6), "Cobweb", "Patch", "Air", shape={"PatchRadiusCm": 80.0}, seed=92, label="Cobwebs_W")
    ctx.vine(B(-1.0, 15.5, 6.0), "Rootlets", "Patch", "Ground", shape={"PatchRadiusCm": 140.0}, seed=93, label="Rootlets")
    # near-left foreground block
    ctx.prop("Boxes/BoxStoneBlock2m", B(-2.4, 6.2, 0.0), 80.0, (0.9, 1.0, 1.7), sub="Near")
    ctx.scatter(("Rubble_A", "Rubble_B"), B(-1.4, 7.4), 80.0, 2, "Near")
    # light: the lid candle and the chef's lantern; very low fill
    ctx.lamp(B(2.0, 11.4, 0.65), FLAME, 26.0, 750.0, 2.0, True, "FloorLantern")
    ctx.lamp(B(5.6, 18.9, 2.2), WARM, 7.0, 900.0, 3.0, False, "StatueFill")
    ctx.lamp(B(-2.6, 15.8, 2.8), WARM, 5.0, 900.0, 3.0, False, "BackRim")
    ctx.lamp(B(-6.5, 10.6, 2.0), COLD, 6.0, 800.0, 3.0, False, "ArchCold")
    ctx.lamp(B(0.0, 20.0, 5.0), WARM, 5.0, 1200.0, 3.0, False, "VaultFill")
    ctx.reflection(B(0.0, 12.0, 2.0), 1500.0, "warm", 0.3)
    return {"eye": ctx.w(*B(-0.9, 7.3, 0.5)), "target": ctx.w(*B(0.35, 14.0, 1.15)), "fov": 62.0, "size": [1400, 700],
            "post": {"exposure": 8.1, "white_temp": 6300.0, "vignette": 0.7, "saturation": (0.9, 0.9, 0.9, 1.0)}}


# ================================================================== host side: contact sheets
def contact_sheets(names=NAMES, ue_dir=None, out_dir=None, height=560, suffix="", tag="sheet"):
    """concept | capture side by side per vignette (PIL), plus one overview sheet of all six. pie=True: the PIE
    screenshots (Saved/Screenshots/EnvVignettes/<name>_a.png) instead of the SceneCapture2D shots."""
    from PIL import Image, ImageDraw
    ue_dir = ue_dir or os.path.join(REVIEW, "ue")
    out_dir = out_dir or os.path.join(REVIEW, "sheets")
    os.makedirs(out_dir, exist_ok=True)
    made, rows = [], []
    for n in names:
        a_p, b_p = os.path.join(CONCEPTS, n + ".png"), os.path.join(ue_dir, n + suffix + ".png")
        if not (os.path.isfile(a_p) and os.path.isfile(b_p)):
            continue
        ims = [Image.open(p).convert("RGB") for p in (a_p, b_p)]
        ims = [im.resize((int(im.width * height / im.height), height), Image.LANCZOS) for im in ims]
        sheet = Image.new("RGB", (ims[0].width + ims[1].width + 12, height + 30), (18, 18, 20))
        x = 0
        d = ImageDraw.Draw(sheet)
        for im, cap in zip(ims, ("concept", "Unreal")):
            sheet.paste(im, (x, 30))
            d.text((x + 8, 8), "%s - %s" % (n, cap), fill=(230, 220, 200))
            x += im.width + 12
        p = os.path.join(out_dir, "%s_%s.png" % (n, tag))
        sheet.save(p)
        made.append(p)
        rows.append(sheet)
    if rows:
        w = max(r.width for r in rows)
        allsheet = Image.new("RGB", (w, sum(r.height for r in rows)), (18, 18, 20))
        y = 0
        for r in rows:
            allsheet.paste(r, (0, y))
            y += r.height
        allsheet = allsheet.resize((allsheet.width // 2, allsheet.height // 2), Image.LANCZOS)
        p = os.path.join(out_dir, "all_%s.png" % tag)
        allsheet.save(p)
        made.append(p)
    return made


def pie_shots(port=9317, names=NAMES, settle=25.0):
    """Host side: PIE on the hidden editor at `port`, two shots per vignette 0.5 s apart, PIE stopped, sheets made."""
    import subprocess
    import time
    drive = [sys.executable, os.path.join(HERE, "env_drive.py"), "--port", str(port), "--module",
             "mars_env_vignettes_ue", "--alias", "vg", "--call"]
    run = lambda call: subprocess.run(drive + [call], capture_output=True, text=True).stdout
    run("vg.pie_stop() if vg._les().is_in_play_in_editor() else None")
    time.sleep(3.0)
    run("vg.pie_start()")
    time.sleep(settle)
    for n in names:
        run("vg.pie_view(%r, 'a')" % n)
        time.sleep(0.5)
        run("vg.pie_view(%r, 'b')" % n)
        time.sleep(1.5)
    run("vg.pie_stop()")
    return contact_sheets(ue_dir=SHOT_DIR, suffix="_a", tag="pie")


if __name__ == "__main__":
    if "--pie" in sys.argv:
        port = int(sys.argv[sys.argv.index("--port") + 1]) if "--port" in sys.argv else 9317
        print("\n".join(pie_shots(port)))
    if "--sheets" in sys.argv:
        print("\n".join(contact_sheets()))
    if "--pie-sheets" in sys.argv:
        print("\n".join(contact_sheets(ue_dir=SHOT_DIR, suffix="_a", tag="pie")))
