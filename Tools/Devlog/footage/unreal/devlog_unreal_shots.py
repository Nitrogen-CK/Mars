"""Unreal footage for the Mise en Monstre devlogs (Tools/Devlog/CONTRACT.md): clean PNG frame sequences, no text.

    (A) making-of the crypt kit  -> D:/Repo/Content/Devlog/mise_crypt/unreal/<shot>/%05d.png
    (B) water / drip breakdowns  -> D:/Repo/Content/Devlog/materials/unreal/<shot>/%05d.png

Editor side (runs inside a hidden MarsEditor through Monolith; never Stephen's 9316). The host runner
`run_shots.py` drives it:

    python run_shots.py --shot all --draft        # 960x540, every 10th frame, into the scratch draft folder
    python run_shots.py --shot cistern_rings_wide # full 1920x1080 @ 30 fps

Calls the runner makes (one Monolith call each, so the editor ticks between them):
    ds.prepare(name)                      open the shot's map (no save), its one-off setup
    ds.shoot(name, draft, start, end)     frames [start, end) of the shot (the runner chunks a shot into several calls)
    ds.finish(name)                       restore what prepare / shoot changed (materials, fog), reset the cvars
    ds.info(name)                         the shot's metadata for shot.json

Every frame is a SceneCapture2D -> render target -> export_render_target. Time-dependent materials are frozen per
frame with r.Test.OverrideTimeMaterialExpressions (frame i = t0 + i / 30 s), so the footage is exactly 30 fps whatever
the editor frame rate is; the drips, splashes, rings and flames are closed-form functions of that time.

Nothing is saved: maps are opened with EditorLoadingAndSavingUtils.load_map (no save prompt), the capture actor and
any material overrides (MaterialInstanceDynamic on the hero components) live only in the editor session and are
undone by finish().
"""
import json
import math
import os

import unreal

OUT_A = r"D:\Repo\Content\Devlog\mise_crypt\unreal"
OUT_B = r"D:\Repo\Content\Devlog\materials\unreal"
DRAFT_ROOT = r"C:\Users\Stephen\AppData\Local\Temp\claude\D--Repo-Mars\5f3efb8e-b134-46b6-83b7-6ce0a5233bff\scratchpad\unreal_agent\drafts"
FPS = 30.0
FULL = (1920, 1080)
DRAFT = (960, 540)
DRAFT_STEP = 10

MAPS = {
    "water": "/Game/Mars/Maps/WaterLookdev_Mars_MAP",
    "showcase": "/Game/Mars/Maps/CryptShowcase_Mars_MAP",
    "rooms": "/Game/Mars/Maps/CryptRooms_Mars_MAP",
    "vignettes": "/Game/Mars/Maps/EnvVignettes_Mars_MAP",
}
SOURCES = {
    "final": "SCS_FINAL_COLOR_LDR",
    "base": "SCS_BASE_COLOR",
    "normal": "SCS_NORMAL",
}


# ====================================================================================== editor helpers
def _eas():
    return unreal.get_editor_subsystem(unreal.EditorActorSubsystem)


def _world():
    return unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()


def _cvar(cmd):
    unreal.SystemLibrary.execute_console_command(_world(), cmd)


def open_map(path):
    """Open `path` in the editor unless it is already open. load_map never prompts to save the current map (the
    capture actor dirties it; nothing here is ever saved)."""
    if _world().get_path_name().split(".")[0] != path:
        unreal.EditorLoadingAndSavingUtils.load_map(path)
    return _world().get_path_name()


def actor(label):
    for a in _eas().get_all_level_actors():
        if a.get_actor_label() == label:
            return a
    return None


def _rot(eye, target, roll=0.0):
    d = [t - e for e, t in zip(eye, target)]
    yaw = math.degrees(math.atan2(d[1], d[0]))
    pitch = math.degrees(math.atan2(d[2], math.hypot(d[0], d[1])))
    return unreal.Rotator(roll=roll, pitch=pitch, yaw=yaw)


# ====================================================================================== camera maths (pure python)
def lerp(a, b, u):
    return tuple(x + (y - x) * u for x, y in zip(a, b)) if isinstance(a, (tuple, list)) else a + (b - a) * u


def ease(u):
    """Smooth start and stop (cosine ease-in-out)."""
    u = min(max(u, 0.0), 1.0)
    return 0.5 - 0.5 * math.cos(math.pi * u)


def ease_soft(u, k=0.25):
    """Constant speed in the middle, eased over the first and last k of the shot (a dolly that starts and lands)."""
    u = min(max(u, 0.0), 1.0)
    # integral of a trapezoid velocity profile, normalised to 1
    vmax = 1.0 / (1.0 - k)
    if u < k:
        return 0.5 * vmax * u * u / k
    if u > 1.0 - k:
        w = 1.0 - u
        return 1.0 - 0.5 * vmax * w * w / k
    return 0.5 * vmax * k + vmax * (u - k)


def _catmull(p0, p1, p2, p3, s):
    s2, s3 = s * s, s * s * s
    return tuple(0.5 * ((2 * b) + (-a + c) * s + (2 * a - 5 * b + 4 * c - d) * s2 + (-a + 3 * b - 3 * c + d) * s3)
                 for a, b, c, d in zip(p0, p1, p2, p3))


class Spline:
    """Uniform Catmull-Rom through `points` (end points repeated), re-parameterised by arc length so equal steps of u
    move the camera equal distances (no speed-up on long segments)."""

    def __init__(self, points, samples=2000):
        self.p = [tuple(map(float, q)) for q in points]
        pts = [self.p[0]] + self.p + [self.p[-1]]
        self.seg = [(pts[i], pts[i + 1], pts[i + 2], pts[i + 3]) for i in range(len(self.p) - 1)]
        self.table = [(0.0, 0.0)]
        prev, acc = self._raw(0.0), 0.0
        for k in range(1, samples + 1):
            r = k / float(samples)
            q = self._raw(r)
            acc += math.dist(prev, q)
            self.table.append((acc, r))
            prev = q
        self.length = acc

    def _raw(self, r):
        n = len(self.seg)
        x = min(max(r, 0.0), 1.0) * n
        i = min(int(x), n - 1)
        return _catmull(*self.seg[i], x - i)

    def __call__(self, u):
        return self._raw(self.r_at(u))

    def r_at(self, u):
        """Raw spline parameter (0..1 over the key points) at arc-length fraction u: a companion spline with the
        same number of keys evaluated at r_at(u) stays keyed to this one (look-at targets)."""
        if len(self.p) == 1:
            return 0.0
        target = min(max(u, 0.0), 1.0) * self.length
        lo, hi = 0, len(self.table) - 1
        while hi - lo > 1:
            mid = (lo + hi) // 2
            if self.table[mid][0] < target:
                lo = mid
            else:
                hi = mid
        (a0, r0), (a1, r1) = self.table[lo], self.table[hi]
        return r0 if a1 <= a0 else r0 + (r1 - r0) * (target - a0) / (a1 - a0)


# ====================================================================================== capture rig
def _post(settings, look):
    """Grade on a PostProcessSettings: manual exposure (the capture's own bias; SceneCapture stills read 2.5 - 4.5
    stops darker than PIE at the map's bias), bloom, vignette, contrast."""
    pairs = [("override_auto_exposure_method", True), ("auto_exposure_method", unreal.AutoExposureMethod.AEM_MANUAL),
             ("override_auto_exposure_bias", True), ("auto_exposure_bias", float(look.get("ev", 11.5))),
             ("override_bloom_intensity", True), ("bloom_intensity", float(look.get("bloom", 0.5))),
             ("override_vignette_intensity", True), ("vignette_intensity", float(look.get("vignette", 0.4))),
             ("override_motion_blur_amount", True), ("motion_blur_amount", 0.0)]
    if "contrast" in look:
        pairs += [("override_color_contrast", True), ("color_contrast", unreal.Vector4(*([look["contrast"]] * 3 + [1.0])))]
    if "saturation" in look:
        pairs += [("override_color_saturation", True), ("color_saturation", unreal.Vector4(*([look["saturation"]] * 3 + [1.0])))]
    if "white_temp" in look:
        pairs += [("override_white_temp", True), ("white_temp", float(look["white_temp"]))]
    if "shadow_gain" in look:
        pairs += [("override_color_gain_shadows", True), ("color_gain_shadows", unreal.Vector4(*look["shadow_gain"]))]
    if "gamma" in look:
        pairs += [("override_color_gamma", True), ("color_gamma", unreal.Vector4(*([look["gamma"]] * 3 + [1.0])))]
    for k, v in pairs:
        try:
            settings.set_editor_property(k, v)
        except Exception as exc:
            unreal.log_warning("[devlog] post %s: %s" % (k, exc))
    return settings


class Rig:
    """One SceneCapture2D + render target for a batch of frames. capture_every_frame stays ON (its default): with it
    off the capture ignores every exposure bias and renders at one fixed exposure."""

    def __init__(self, size, look, source="final", show=None):
        self.world = _world()
        _cvar("r.TextureStreaming 0")
        self.rt = unreal.RenderingLibrary.create_render_target2d(self.world, size[0], size[1],
                                                                  unreal.TextureRenderTargetFormat.RTF_RGBA8)
        self.actor = _eas().spawn_actor_from_class(unreal.SceneCapture2D, unreal.Vector(0, 0, 0))
        self.actor.set_actor_label("DevlogCapture")
        self.comp = self.actor.get_component_by_class(unreal.SceneCaptureComponent2D)
        self.comp.set_editor_property("texture_target", self.rt)
        self.comp.set_editor_property("post_process_blend_weight", 1.0)
        self.look = dict(look)
        self.comp.set_editor_property("post_process_settings", _post(unreal.PostProcessSettings(), self.look))
        self.set_source(source)
        self.set_show(show or {})

    def set_source(self, source):
        self.source = source
        self.comp.set_editor_property("capture_source", getattr(unreal.SceneCaptureSource, SOURCES[source]))

    def set_show(self, flags):
        """flags: {ShowFlagName: bool} (Fog, Bloom, PostProcessing, Lighting, ...)."""
        arr = [unreal.EngineShowFlagsSetting(show_flag_name=k, enabled=bool(v)) for k, v in flags.items()]
        self.comp.set_editor_property("show_flag_settings", arr)

    def set_look(self, **kw):
        self.look.update(kw)
        self.comp.set_editor_property("post_process_settings", _post(unreal.PostProcessSettings(), self.look))

    def frame(self, eye, target, fov, out_dir, name, t=None, roll=0.0):
        if t is not None:
            _cvar("r.Test.OverrideTimeMaterialExpressions %.5f" % t)
        self.actor.set_actor_location_and_rotation(unreal.Vector(*eye), _rot(eye, target, roll), False, False)
        self.comp.set_editor_property("fov_angle", float(fov))
        self.comp.capture_scene()
        unreal.RenderingLibrary.export_render_target(self.world, self.rt, out_dir, name)
        return os.path.join(out_dir, name)

    def close(self):
        try:
            self.actor.destroy_actor()
        finally:
            _cvar("r.Test.OverrideTimeMaterialExpressions -1")


def still(map_key, eye, target, fov=50.0, t=12.0, ev=11.5, source="final", size=(960, 540), name="still.png",
          out_dir=None, show=None, **look):
    """One ad-hoc frame (framing and exposure tuning)."""
    open_map(MAPS[map_key])
    out_dir = out_dir or os.path.join(DRAFT_ROOT, "_stills")
    os.makedirs(out_dir, exist_ok=True)
    rig = Rig(size, dict(look, ev=ev), source, show)
    try:
        return rig.frame(eye, target, fov, out_dir, name, t)
    finally:
        rig.close()


def stills(map_key, views, size=(960, 540), out_dir=None):
    """views: [(name, eye, target, fov, t, ev, source)] in one call."""
    open_map(MAPS[map_key])
    out_dir = out_dir or os.path.join(DRAFT_ROOT, "_stills")
    os.makedirs(out_dir, exist_ok=True)
    rig = Rig(size, {"ev": 11.5})
    done = []
    try:
        for name, eye, target, fov, t, ev, source in views:
            rig.set_look(ev=ev)
            rig.set_source(source)
            done.append(rig.frame(eye, target, fov, out_dir, name + ".png", t))
    finally:
        rig.close()
    return done


# ====================================================================================== drip clock (drip_reference mirror)
WATER_DIR = r"D:\Repo\Mars\Tools\Blender\mars_water"


def _ref():
    import sys
    if WATER_DIR not in sys.path:
        sys.path.insert(0, WATER_DIR)
    import drip_reference
    return drip_reference


def clock(label, strand=0):
    """(drip_reference.Clock, source point, impact point) of strand `strand` of leak `label` in the open map."""
    leak = actor(label)
    s = leak.get_editor_property("CachedStrands")[strand]
    timing = leak.get_editor_property("Timing")
    look = leak.get_editor_property("Look")
    mode = float(look.get_editor_property("Mode").value)
    c = _ref().Clock(float(s.get_editor_property("Length")), float(s.get_editor_property("Rate")),
                     float(s.get_editor_property("Seed")), float(timing.get_editor_property("Jitter")), mode)
    src = s.get_editor_property("Source")
    imp = s.get_editor_property("Impact").get_editor_property("Point")
    return c, (src.x, src.y, src.z), (imp.x, imp.y, imp.z)


def schedule(label, strand=0, t0=10.0, t1=30.0):
    """Releases / impacts of one strand in [t0, t1] (drops the jitter skips are flagged)."""
    c, src, imp = clock(label, strand)
    k = int(math.floor(t0 / c.p - c.seed)) - 2
    rows = []
    while c.release(k) < t1:
        if c.release(k) >= t0 - c.tfall:
            rows.append((k, round(c.release(k), 3), round(c.impact_time(k), 3), bool(c.skipped(k))))
        k += 1
    return {"period": c.p, "tfall": c.tfall, "mode": c.mode, "y0": c.y0, "src": src, "imp": imp, "rows": rows}


def build_reflections():
    """Build the open map's reflection captures in memory (NOT saved). Mars has no Lightmass, so the lighting half of
    build_light_maps fails by design; the reflection-capture half still runs. Capture in a LATER call."""
    les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
    les.build_light_maps(unreal.LightingBuildQuality.QUALITY_PREVIEW, True)
    return [p.get_name() for p in unreal.EditorLoadingAndSavingUtils.get_dirty_map_packages()]


def top_view(map_key, centre, width, name, cut_z=3000.0, size=1000, source="base", near=0.0):
    """Orthographic plan (north = -Y up in the image is not guaranteed: image up = +X... see yaw) for path planning.
    Camera looks straight down from cut_z with yaw -90 so image up = -Y (Unreal north), image right = +X."""
    open_map(MAPS[map_key])
    out_dir = os.path.join(DRAFT_ROOT, "_stills")
    os.makedirs(out_dir, exist_ok=True)
    world = _world()
    rt = unreal.RenderingLibrary.create_render_target2d(world, size, size, unreal.TextureRenderTargetFormat.RTF_RGBA8)
    a = _eas().spawn_actor_from_class(unreal.SceneCapture2D, unreal.Vector(0, 0, 0))
    try:
        comp = a.get_component_by_class(unreal.SceneCaptureComponent2D)
        comp.set_editor_property("capture_source", getattr(unreal.SceneCaptureSource, SOURCES[source]))
        comp.set_editor_property("projection_type", unreal.CameraProjectionMode.ORTHOGRAPHIC)
        comp.set_editor_property("ortho_width", float(width))
        comp.set_editor_property("auto_calculate_ortho_planes", False)
        if near:
            comp.set_editor_property("override_custom_near_clipping_plane", True)
            comp.set_editor_property("custom_near_clipping_plane", float(near))
        comp.set_editor_property("texture_target", rt)
        a.set_actor_location_and_rotation(unreal.Vector(centre[0], centre[1], cut_z),
                                          unreal.Rotator(roll=0.0, pitch=-90.0, yaw=-90.0), False, False)
        comp.capture_scene()
        unreal.RenderingLibrary.export_render_target(world, rt, out_dir, name + ".png")
    finally:
        a.destroy_actor()
    return os.path.join(out_dir, name + ".png")


def plan_persp(map_key, centre, z_eye, near, fov, name, ev=12.0, source="base", size=900):
    """Straight-down perspective plan from z_eye with a custom near clip (cuts away roofs): path planning."""
    open_map(MAPS[map_key])
    out_dir = os.path.join(DRAFT_ROOT, "_stills")
    rig = Rig((size, size), {"ev": ev}, source)
    try:
        rig.comp.set_editor_property("override_custom_near_clipping_plane", True)
        rig.comp.set_editor_property("custom_near_clipping_plane", float(near))
        rig.actor.set_actor_location_and_rotation(unreal.Vector(centre[0], centre[1], z_eye),
                                                  unreal.Rotator(roll=0.0, pitch=-90.0, yaw=-90.0), False, False)
        rig.comp.set_editor_property("fov_angle", float(fov))
        rig.comp.capture_scene()
        unreal.RenderingLibrary.export_render_target(rig.world, rig.rt, out_dir, name + ".png")
    finally:
        rig.close()
    return os.path.join(out_dir, name + ".png")


# ====================================================================================== shots
def _clamp01(x):
    return min(max(x, 0.0), 1.0)


def _polar(c, r, deg, z):
    a = math.radians(deg)
    return (c[0] + r * math.cos(a), c[1] + r * math.sin(a), z)


class Shot:
    """A shot: map, frame count, frozen-time origin t0, the capture look, and cam(i, n) -> per-frame dict
    {eye, target, fov[, ev][, source][, stage]}. Optional prepare / per-frame / finish hooks."""

    def __init__(self, name, group, map_key, frames, t0, look, cam, description, source="final", notes="",
                 on_prepare=None, on_frame=None, on_finish=None, visible=None, build_reflections=False, strands=None,
                 hide_folders=None):
        self.name, self.group, self.map_key, self.frames, self.t0 = name, group, map_key, frames, t0
        self.look, self.cam, self.description, self.source, self.notes = look, cam, description, source, notes
        self.on_prepare, self.on_frame, self.on_finish = on_prepare, on_frame, on_finish
        self.visible = visible or []          # [(seconds_from, seconds_to, what is on screen)] for caption placement
        self.build_reflections = build_reflections
        self.hide_folders = hide_folders or []  # outliner folders hidden from this shot's capture only (hidden_actors)
        self.strands = strands or []          # [(DripLeak label, strand index)] the camera looks at (shot.json)

    def out_dir(self, draft):
        if draft:
            return os.path.join(DRAFT_ROOT, self.name)
        return os.path.join(OUT_A if self.group == "A" else OUT_B, self.name)


SHOTS = {}


def _add(shot):
    SHOTS[shot.name] = shot
    return shot


# ---------------------------------------------------------------- (A) making-of: CryptShowcase fly-through
# Plaza / gallery / Bellfold nave (Unreal cm; the nave's south portal is at x 0, y 0; the gallery's wall row runs
# along y ~1100 - 1160 south of the plaza; the nave's raised altar platform spans y -1590 .. -1027, so the path stops
# short of it). The camera drifts west along the gallery's wall row, cranes up over the plaza while turning north (high
# enough that the in-world BELLFOLD sign over the portal stays below frame), clears the nave's south wall at 9 m and
# descends into the open-topped nave over the landmark statue and the altar, ending on the west arcade.
FLY_EYES = [(2800, 660, 250), (1750, 620, 280), (800, 650, 700), (60, 300, 900), (0, -250, 800), (-150, -500, 650)]
FLY_TARGETS = [(1500, 1000, 150), (500, 800, 250), (100, -700, 640), (0, -1100, 350), (-200, -1350, 330), (-700, -1500, 250)]


def _cam_fly(i, n):
    eyes = Spline(FLY_EYES)
    targets = Spline(FLY_TARGETS)
    u = ease_soft(i / float(n - 1), 0.2)
    r = eyes.r_at(u)
    return {"eye": eyes(u), "target": targets._raw(r), "fov": 70.0}


_add(Shot("showcase_fly", "A", "showcase", 300, 12.0, {"ev": 12.5, "bloom": 0.5, "vignette": 0.4}, _cam_fly,
          "CryptShowcase: a dolly west along the kit gallery's wall row, then a crane up over the plaza turning north, "
          "over the Bellfold nave's south wall and down into the open-topped nave (landmark statue, altar, arcades, "
          "balustrade galleries, candle shrines). Lit final look. The nave name plaques and the gallery's big title "
          "(Mise_Showcase/Labels) are hidden from this capture; nothing else is changed.",
          hide_folders=["Mise_Showcase/Labels"],
          visible=[(0.0, 3.5, "kit gallery wall row (labelled pieces on the paved floor, teal sky)"),
                   (3.5, 6.0, "crane up and turn: plaza, the nave's south wall and its upper gallery"),
                   (6.0, 10.0, "looking down into the Bellfold nave: statue on the altar, arcades, side shrines; ends on "
                    "the west arcade")]))


# ---------------------------------------------------------------- (A) CryptRooms octagon hub orbit
HUB = (14000.0, -1230.0)          # crypt_octagon_hub_Spillring: 25 x 25 m octagon, central pier, 11.5 m clear vault


def _cam_orbit(i, n):
    u = i / float(n - 1)
    th = 90.0 + 110.0 * ease_soft(u, 0.2)              # starts south of the pier (+Y), swings round to the west side
    rise = ease(_clamp01((u - 0.4) / 0.6))
    look_up = ease(_clamp01((u - 0.35) / 0.65))
    eye = _polar(HUB, 800.0 - 150.0 * ease(u), th, 170.0 + 680.0 * rise)
    # aim across the room just past the central pier (so the pier slides through frame instead of filling it),
    # then up into the ribs springing from it
    target = _polar(HUB, 600.0 - 300.0 * look_up, th + 240.0, 220.0 + 830.0 * look_up)
    return {"eye": eye, "target": target, "fov": 78.0, "ev": 13.0 + 1.2 * rise}


_add(Shot("rooms_octagon_orbit", "A", "rooms", 240, 12.0, {"ev": 13.0, "bloom": 0.5, "vignette": 0.4}, _cam_orbit,
          "CryptRooms, crypt_octagon_hub (Spillring biome): a slow orbit round the central pier at head height, "
          "then rising and tilting up into the vault ribs. Exposure eases up 1.2 EV during the rise (the vault is "
          "lit only by the wall torches).",
          visible=[(0.0, 3.2, "octagon hub at head height: torch-lit walls, doors, the dark central pier"),
                   (3.2, 8.0, "camera rises and tilts up: the umbrella vault ribs springing from the pier")]))


# ---------------------------------------------------------------- (A) material stages on one hero arcade
# The south-east arcade of the Bellfold nave: two piers, round arches, the balustrade gallery above, a candle shrine.
STAGE_EYE, STAGE_TARGET, STAGE_FOV = (400.0, -900.0, 180.0), (800.0, -1500.0, 250.0), 70.0
STAGE_BOX = ((-1300.0, -2500.0), (1300.0, 200.0))      # components with bounds inside this XY box get the MIDs
STAGES = [("base_colour", "SCS_BASE_COLOR: unlit base colour, paint wash off, emissive off"),
          ("normals", "SCS_NORMAL: world-space normals (kit normal maps + the paint-wash detail normal)"),
          ("lit_no_wash", "lit final colour, paint wash off (PaintStrength 0), no fog, emissive off, no bloom"),
          ("wash_in", "paint wash fading in: PaintStrength 0 -> authored value (eased)"),
          ("fog_emissive_in", "height + volumetric fog, emissive (EmissiveStrength / Glow Strength) and bloom fade in"),
          ("final", "final: everything at its authored value")]
STAGE_LEN = 60
DEVLOG_MID = "DevlogMID"
WASH_MASTERS = ("MiseAtlas_Mars_M", "Surface_Mars_M")
EMISSIVE_MASTERS = ("MiseAtlas_Mars_M", "Emissive_Mars_M")


def _cam_stages(i, n):
    s = min(i // STAGE_LEN, len(STAGES) - 1)
    k = (i - s * STAGE_LEN) / float(STAGE_LEN - 1)
    wash = {0: 0.0, 1: 0.0, 2: 0.0, 3: ease(k)}.get(s, 1.0)
    glow = {4: ease(k), 5: 1.0}.get(s, 0.0)
    src = {0: "base", 1: "normal"}.get(s, "final")
    return {"eye": STAGE_EYE, "target": STAGE_TARGET, "fov": STAGE_FOV, "source": src,
            "stage": {"index": s, "name": STAGES[s][0], "wash": wash, "glow": glow}}


def _in_box(a):
    o, e = a.get_actor_bounds(False)
    (x0, y0), (x1, y1) = STAGE_BOX
    return o.x - e.x < x1 and o.x + e.x > x0 and o.y - e.y < y1 and o.y + e.y > y0 and e.x < 1e5


def _stage_mids():
    """[(mid, base master name, authored PaintStrength, authored emissive, emissive param)] for every MID prepare made."""
    out = []
    mel = unreal.MaterialEditingLibrary
    for a in _eas().get_all_level_actors():
        if not _in_box(a):
            continue
        for c in a.get_components_by_class(unreal.PrimitiveComponent):
            try:
                n = c.get_num_materials()
            except Exception:
                continue
            for k in range(n):
                m = c.get_material(k)
                if isinstance(m, unreal.MaterialInstanceDynamic) and m.get_name().startswith(DEVLOG_MID):
                    parent = m.get_editor_property("parent")
                    base = m.get_base_material().get_name()
                    wash = mel.get_material_instance_scalar_parameter_value(parent, "PaintStrength") \
                        if base in WASH_MASTERS else None
                    glow_p = "Strength" if base == "Emissive_Mars_M" else "EmissiveStrength"
                    glow = mel.get_material_instance_scalar_parameter_value(parent, glow_p) \
                        if base in EMISSIVE_MASTERS else None
                    out.append((m, base, wash, glow, glow_p))
    return out


def _fog_actor():
    for a in _eas().get_all_level_actors():
        if isinstance(a, unreal.ExponentialHeightFog):
            return a
    return None


FOG_KEYS = ("fog_density", "fog_max_opacity", "volumetric_fog_extinction_scale")


def _stages_prepare(shot):
    n = 0
    for a in _eas().get_all_level_actors():
        if not _in_box(a):
            continue
        for c in a.get_components_by_class(unreal.PrimitiveComponent):
            try:
                count = c.get_num_materials()
            except Exception:
                continue
            for k in range(count):
                m = c.get_material(k)
                if m is None or isinstance(m, unreal.MaterialInstanceDynamic):
                    continue
                if m.get_base_material().get_name() not in WASH_MASTERS + EMISSIVE_MASTERS:
                    continue
                c.create_dynamic_material_instance(k, m, "%s_%d" % (DEVLOG_MID, n))
                n += 1
    fog = _fog_actor()
    state = {"mids": n}
    if fog is not None:
        fc = fog.get_component_by_class(unreal.ExponentialHeightFogComponent)
        state["fog"] = {k: float(fc.get_editor_property(k)) for k in FOG_KEYS}
        state["fog_label"] = fog.get_actor_label()
    _save_state(shot.name, state)
    return state


def _set_fog(k, state):
    fog = _fog_actor()
    if fog is None or "fog" not in state:
        return
    fc = fog.get_component_by_class(unreal.ExponentialHeightFogComponent)
    f = state["fog"]
    fc.set_fog_density(f["fog_density"] * k)
    fc.set_fog_max_opacity(f["fog_max_opacity"] * k)
    fc.set_volumetric_fog_extinction_scale(max(f["volumetric_fog_extinction_scale"] * k, 0.0))
    fc.set_volumetric_fog(k > 0.001)


class _StageCtx:
    mids = None
    state = None


def _stages_frame(shot, rig, frame):
    st = frame["stage"]
    if _StageCtx.mids is None:
        _StageCtx.mids = _stage_mids()
        _StageCtx.state = _load_state(shot.name)
    for mid, base, wash, glow, glow_p in _StageCtx.mids:
        if wash is not None:
            mid.set_scalar_parameter_value("PaintStrength", wash * st["wash"])
        if glow is not None:
            mid.set_scalar_parameter_value(glow_p, glow * st["glow"])
    _set_fog(st["glow"], _StageCtx.state)
    rig.set_look(bloom=0.5 * st["glow"])


def _stages_finish(shot):
    restored = 0
    for a in _eas().get_all_level_actors():
        for c in a.get_components_by_class(unreal.PrimitiveComponent):
            try:
                count = c.get_num_materials()
            except Exception:
                continue
            for k in range(count):
                m = c.get_material(k)
                if isinstance(m, unreal.MaterialInstanceDynamic) and m.get_name().startswith(DEVLOG_MID):
                    c.set_material(k, m.get_editor_property("parent"))
                    restored += 1
    state = _load_state(shot.name)
    if state:
        _set_fog(1.0, state)
    return restored


_add(Shot("material_stages", "A", "showcase", 360, 12.0, {"ev": 11.9, "bloom": 0.5, "vignette": 0.4}, _cam_stages,
          "Bellfold nave, south-east arcade, one fixed camera, six 2 s stages: " +
          "; ".join("%d) %s" % (k + 1, d) for k, (_, d) in enumerate(STAGES)) + ".",
          on_prepare=_stages_prepare, on_frame=_stages_frame, on_finish=_stages_finish,
          hide_folders=["Mise_Showcase/Labels"],
          visible=[(2.0 * k, 2.0 * k + 2.0, "%s: %s" % s) for k, s in enumerate(STAGES)]))


# ---------------------------------------------------------------- (A) EnvVignettes sarcophagus crypt dolly
SARC_EYE, SARC_TARGET = (24910.0, -730.0, 55.0), (25035.0, -1400.0, 115.0)
SARC_SIDE = (0.983, 0.183, 0.0)    # perpendicular to the concept camera's view direction


def _cam_vignette(i, n):
    s = -170.0 + 340.0 * ease_soft(i / float(n - 1), 0.3)
    eye = tuple(e + d * s for e, d in zip(SARC_EYE, SARC_SIDE))
    target = tuple(t + d * s * 0.4 for t, d in zip(SARC_TARGET, SARC_SIDE))
    return {"eye": eye, "target": target, "fov": 60.0}


_add(Shot("vignette_pan", "A", "vignettes", 240, 12.0,
          {"ev": 11.4, "bloom": 0.6, "vignette": 0.7, "white_temp": 6300.0, "saturation": 0.9, "contrast": 1.12},
          _cam_vignette,
          "EnvVignettes, sarcophagus crypt (concept recreation): a slow 3.4 m lateral dolly left to right past the carved "
          "sarcophagus with its candle cluster, dead leaves and the wall niches behind; parallax against the pier.",
          visible=[(0.0, 8.0, "carved sarcophagus centre-frame, candles top right of it, pier behind, niches right")]))


# ---------------------------------------------------------------- (A) kit gallery dolly
def _cam_gallery(i, n):
    u = ease_soft(i / float(n - 1), 0.2)
    x = 2700.0 - 2000.0 * u
    return {"eye": (x, 560.0, 240.0), "target": (x - 260.0, 1250.0, 120.0), "fov": 62.0}


_add(Shot("kit_gallery_dolly", "A", "showcase", 240, 12.0, {"ev": 12.5, "bloom": 0.4, "vignette": 0.35}, _cam_gallery,
          "CryptShowcase kit gallery: a 20 m dolly west along the first gallery row (walls, wall courses, portals, "
          "arches) with each piece's in-world name/size label on the floor; the supports row and the railing behind.",
          hide_folders=["Mise_Showcase/Labels"],
          visible=[(0.0, 8.0, "kit pieces in a row on the paved gallery floor, in-world labels at their feet")]))


# ---------------------------------------------------------------- (B) water / drips (WaterLookdev_Mars_MAP)
PJ = (520.0, 62.0, 130.0)      # Leak_PipeJoint source (sewer bay): mode 1 thread, bead hangs 21.6 cm below, falls
PJ_BEAD_Z = 108.43             # into the basin water at z 45 (period 0.675 s, fall 0.365 s)
VAULT1 = (229.0, 468.0, 0.0)   # Leak_VaultLine strand 1 impact on the sewer floor (3.5 m fall, 0.93 s)
STREAK2 = (2570.0, 0.0)        # ossuary Streak_2 on the back wall (y 0)


def _cam_strand(i, n):
    u = i / float(n - 1)
    d = 270.0 - 15.0 * u
    a = math.radians(0.0)          # from +X, along the back wall: the warm far wall (x 0) is the backdrop
    return {"eye": (PJ[0] + d * math.cos(a), PJ[1] + d * math.sin(a), 92.0), "target": (PJ[0], PJ[1], 88.0), "fov": 38.0}


def _cam_bead(i, n):
    a = math.radians(150.0)
    return {"eye": (PJ[0] + 15.0 * math.cos(a), PJ[1] + 15.0 * math.sin(a), PJ_BEAD_Z + 0.3),
            "target": (PJ[0], PJ[1], PJ_BEAD_Z - 1.2), "fov": 35.0}


def _cam_splash(i, n):
    u = ease(i / float(n - 1))
    return {"eye": lerp((229.0, 545.0, 78.0), (229.0, 535.0, 70.0), u), "target": VAULT1, "fov": 50.0}


def _cam_cistern(i, n):
    u = i / 359.0
    # low over the causeway's west edge, looking at the cistern-A cluster's landing zone (x 1290-1425, y 263-459)
    return {"eye": lerp((1530.0, 640.0, 62.0), (1515.0, 615.0, 58.0), u), "target": (1365.0, 360.0, -20.0), "fov": 56.0}


def _cam_puddle(i, n):
    u = ease(i / float(n - 1))
    return {"eye": lerp((450.0, 900.0, 150.0), (380.0, 790.0, 110.0), u),
            "target": lerp((280.0, 600.0, 0.0), (275.0, 610.0, 0.0), u), "fov": 60.0}


def _cam_streak(i, n):
    u = ease_soft(i / float(n - 1), 0.3)
    return {"eye": (STREAK2[0], 330.0 - 10.0 * u, 190.0), "target": (STREAK2[0], 0.0, 330.0 - 290.0 * u), "fov": 60.0}


WATER_LOOK = {"bloom": 0.5, "vignette": 0.35}
_add(Shot("drip_strand_side", "B", "water", 360, 12.0, dict(WATER_LOOK, ev=10.0), _cam_strand,
          "Sewer bay pipe-joint leak (Leak_PipeJoint, mode 1 'thread'): from the side, the thin thread under the spout, "
          "the bead swelling at its tip, the drop releasing and falling with drag, the splash and rings on the basin "
          "water. Period 0.675 s, fall 0.365 s: about 17 drops in 12 s. Camera on the +X side, 270 -> 255 cm away (a very slow push).",
          strands=[("Leak_PipeJoint", 0)], build_reflections=True,
          visible=[(0.0, 12.0, "strand from spout (top) to basin water (bottom); the warm brick wall behind; "
                    "drops are ~8-10 px wide at 1080p, streaking while they fall")]))
_add(Shot("drip_bead_macro", "B", "water", 240, 12.0, dict(WATER_LOOK, ev=10.7), _cam_bead,
          "Macro (15 cm from the bead) of the pipe-joint thread tip: the bead swells, necks and releases every ~0.68 s; "
          "the refracting bead and its glint against the dark sewer wall.",
          strands=[("Leak_PipeJoint", 0)], build_reflections=True,
          visible=[(0.0, 8.0, "bead centre-frame on its thread; about 12 release cycles")]))
_add(Shot("drip_splash_floor", "B", "water", 240, 12.5, dict(WATER_LOOK, ev=13.0), _cam_splash,
          "Looking down at a vault-line strand's impact point on the wet sewer floor (Leak_VaultLine strand 1): the drop "
          "arrives (a 1-2 frame streak), the splash crown (0.16 s), and impact rings expanding at 22 cm/s over 1.4 s "
          "across the impact puddle; neighbouring strands' rings cross the frame.",
          strands=[("Leak_VaultLine", 1)], build_reflections=True,
          visible=[(0.0, 8.0, "wet floor and impact puddle; this strand's impacts at about t=0.29, 1.24, 2.95, 4.42 s")]))
_add(Shot("cistern_rings_wide", "B", "water", 360, 12.0, dict(WATER_LOOK, ev=12.0), _cam_cistern,
          "Cistern bay, wide and low over the still water (single-layer water): drops from the 6 m vault landing as "
          "rings, the lamp reflections (GlintLeft / Glint) breaking up as the rings cross them, a pier and the causeway.",
          strands=[("Leak_CisternA", k) for k in range(6)], build_reflections=True,
          visible=[(0.0, 12.0, "dark still water foreground-centre, lamp glints left of centre, causeway right")]))
_add(Shot("water_normals", "B", "water", 180, 12.0, dict(WATER_LOOK, ev=12.0), _cam_cistern,
          "cistern_rings_wide's first 180 frames (same camera, same frozen times) with capture source SCS_NORMAL "
          "(world normals): the ring normals on the water.", source="normal", strands=[("Leak_CisternA", k) for k in range(6)], build_reflections=True))
_add(Shot("water_basecolor", "B", "water", 180, 12.0, dict(WATER_LOOK, ev=12.0), _cam_cistern,
          "cistern_rings_wide's first 180 frames with capture source SCS_BASE_COLOR.", source="base",
          strands=[("Leak_CisternA", k) for k in range(6)], build_reflections=True))
_add(Shot("puddle_wet_floor", "B", "water", 240, 12.0, dict(WATER_LOOK, ev=12.0), _cam_puddle,
          "Sewer bay floor puddle cluster (Mars_Puddle, 5 puddles): wet darkening, glossy puddle cores catching the "
          "lamps, the vault line's impacts and rings; the camera slowly pushes in.",
          build_reflections=True,
          visible=[(0.0, 8.0, "paved floor with dark wet puddle shapes, lamp glints in them")]))
_add(Shot("puddle_wet_floor_mask", "B", "water", 240, 12.0, dict(WATER_LOOK, ev=12.0), _cam_puddle,
          "puddle_wet_floor, same camera and frozen times, capture source SCS_BASE_COLOR: the puddles' wet darkening "
          "reads as the mask (no roughness capture source exists).", source="base", build_reflections=True))
_add(Shot("wetstreak_wall", "B", "water", 240, 12.0, dict(WATER_LOOK, ev=11.3), _cam_streak,
          "Ossuary bay back wall wet streak (Streak_2): a slow tilt down from the damp source under the ceiling, along "
          "the dark rivulet streaks, past the ossuary niches to the floor.",
          build_reflections=True,
          visible=[(0.0, 3.0, "streak source under the ceiling"), (3.0, 6.0, "rivulets down the brick courses"),
                   (6.0, 8.0, "niches and floor")]))


# ====================================================================================== state across calls
def _state_path(name):
    d = os.path.join(DRAFT_ROOT, "_state")
    os.makedirs(d, exist_ok=True)
    return os.path.join(d, name + ".json")


def _save_state(name, state):
    with open(_state_path(name), "w") as fh:
        json.dump(state, fh, indent=1)


def _load_state(name):
    p = _state_path(name)
    if not os.path.isfile(p):
        return {}
    with open(p) as fh:
        return json.load(fh)


# ====================================================================================== runner API
def shot_names(which="all"):
    order = list(MAPS)          # group shots by map so each map is opened once
    if which in ("all", None):
        return sorted(SHOTS, key=lambda n: order.index(SHOTS[n].map_key))
    if which in ("A", "B"):
        return sorted([n for n, s in SHOTS.items() if s.group == which], key=lambda n: order.index(SHOTS[n].map_key))
    return [n for n in which.split(",") if n in SHOTS] or [which]


def _indices(shot, draft):
    return list(range(0, shot.frames, DRAFT_STEP)) if draft else list(range(shot.frames))


def strand_info(label, strand):
    """The cached strand an explainer needs to re-render the drip clock in sync: length, rate, seed (cached_strands, as
    mars_water_review.timing_probe reads them), jitter + mode (the actor's Timing / Look), source and impact."""
    c, src, imp = clock(label, strand)
    return {"leak": label, "index": strand, "length_cm": c.length, "rate": c.rate, "seed": c.seed, "jitter": c.jitter,
            "mode": c.mode, "period_s": c.p, "fall_s": c.tfall, "source": list(src), "impact": list(imp)}


def info(name, draft=False):
    s = SHOTS[name]
    idx = _indices(s, draft)
    fps = FPS / DRAFT_STEP if draft else FPS
    first, last = s.cam(0, s.frames), s.cam(s.frames - 1, s.frames)
    out = {"name": name, "out_dir": s.out_dir(draft), "fps": fps, "frames_written": len(idx),
            "real_seconds_covered": s.frames / FPS, "description": s.description,
            "extra": {"map": MAPS[s.map_key], "group": s.group, "frozen_t0": s.t0,
                      "frozen_time": "frame i is rendered at r.Test.OverrideTimeMaterialExpressions = t0 + i / 30",
                      "capture_source": SOURCES[s.source], "size": list(DRAFT if draft else FULL),
                      "draft": bool(draft), "look": s.look, "camera_first": first, "camera_last": last,
                      "visible": s.visible, "notes": s.notes,
                      "camera": {"eye": list(first["eye"]), "target": list(first["target"]), "fov": first["fov"]}}}
    if s.strands:
        open_map(MAPS[s.map_key])
        out["extra"]["strand"] = strand_info(*s.strands[0])
        if len(s.strands) > 1:
            out["extra"]["strands"] = [strand_info(*k) for k in s.strands]
    return out


def prepare(name):
    s = SHOTS[name]
    open_map(MAPS[s.map_key])
    out = {"map": _world().get_path_name()}
    if s.build_reflections:
        dirty = [p.get_name() for p in unreal.EditorLoadingAndSavingUtils.get_dirty_map_packages()]
        if not any(p.endswith("_BuiltData") for p in dirty):
            out["reflections"] = build_reflections()       # captures run in a later call (the runner's next call)
    if s.on_prepare:
        out["prepare"] = s.on_prepare(s)
    return out


def _hide(rig, s):
    """Hide the shot's hide_folders actors from this capture only (the level is untouched)."""
    if not s.hide_folders:
        return 0
    hidden = [a for a in _eas().get_all_level_actors()
              if any(str(a.get_folder_path()) == f or str(a.get_folder_path()).startswith(f + "/") for f in s.hide_folders)]
    for a in hidden:
        rig.comp.hide_actor_components(a, False)
    return len(hidden)


def shoot(name, draft=False, start=0, end=None):
    """Write frames [start, end) of the shot's written sequence (draft: every DRAFT_STEP-th frame, renumbered)."""
    s = SHOTS[name]
    if _world().get_path_name().split(".")[0] != MAPS[s.map_key]:
        open_map(MAPS[s.map_key])
    idx = _indices(s, draft)
    end = len(idx) if end is None else min(end, len(idx))
    out_dir = s.out_dir(draft)
    os.makedirs(out_dir, exist_ok=True)
    rig = Rig(DRAFT if draft else FULL, s.look, s.source)
    _hide(rig, s)
    last = None
    try:
        for k in range(start, end):
            i = idx[k]
            f = s.cam(i, s.frames)
            src = f.get("source", s.source)
            if src != rig.source:
                rig.set_source(src)
            if "ev" in f and f["ev"] != rig.look.get("ev"):
                rig.set_look(ev=f["ev"])
            if s.on_frame:
                s.on_frame(s, rig, f)
            last = rig.frame(f["eye"], f["target"], f["fov"], out_dir, "%05d.png" % k, s.t0 + i / FPS)
    finally:
        rig.close()
    return {"written": end - start, "last": last}


def finish(name):
    s = SHOTS[name]
    out = {}
    if s.on_finish:
        out["finish"] = s.on_finish(s)
    _cvar("r.Test.OverrideTimeMaterialExpressions -1")
    return out


def spot(name, frames, full=True):
    """Render chosen frame indices of a shot (full size) into the scratch _spot/<name>/ folder: checks before a run.
    Runs the shot's prepare / finish hooks around them (call prepare in an earlier call for reflection builds)."""
    s = SHOTS[name]
    open_map(MAPS[s.map_key])
    out_dir = os.path.join(DRAFT_ROOT, "_spot", name)
    os.makedirs(out_dir, exist_ok=True)
    if s.on_prepare:
        s.on_prepare(s)
    rig = Rig(FULL if full else DRAFT, s.look, s.source)
    _hide(rig, s)
    done = []
    try:
        for i in frames:
            f = s.cam(i, s.frames)
            if f.get("source", s.source) != rig.source:
                rig.set_source(f.get("source", s.source))
            if "ev" in f:
                rig.set_look(ev=f["ev"])
            if s.on_frame:
                s.on_frame(s, rig, f)
            done.append(rig.frame(f["eye"], f["target"], f["fov"], out_dir, "%05d.png" % i, s.t0 + i / FPS))
    finally:
        rig.close()
        if s.on_finish:
            s.on_finish(s)
    return done
