"""Editor side of the vine and root generator (Script/WorldObjects/Dressing/Vines, Tools/Environment/VINES_PLAN.md).

    import sys, importlib
    sys.path.insert(0, r"D:\\Repo\\Mars\\Tools\\Blender\\mars_environment\\unreal")
    import mars_vine_ue as mv; importlib.reload(mv)
    mv.run_all()                  # instances, profiles, PCG graphs, the gym map (then mv.capture_review(dir) as its own call)

PCG stays a LOCAL-ONLY plugin (Mars.uproject's PCG line is never committed) and no AngelScript names a PCG type, so
everything PCG lives here: the four graphs are built and checked from Python, and the gym's PCG rooms are stock
APCGVolume actors running them (place_volume). Graph settings are written as node defaults; the spawned vines
(AMars_VinePcg) get their seed and traced length through Spawn Actor property overrides and their look from the Profile
the node's template actor carries.

Functions:
  build_instances()           VineBarkRoot / VineBarkWet / VineLeafIvyWet _Mars_MI (presets only on creation)
  seed_profiles(force)        runs Mars.Vine.SeedProfiles in the editor (profiles bind the imported kit meshes)
  build_pcg_graphs()          VineCurtain / VineCeilingRoots / VineUnderside / VineSkirt _Mars_PCG, rebuilt in place
  check_pcg_graphs()          re-reads every graph: node classes, key settings, unique seeds, edges -> VINE_PCG_OK / FAIL
  place_volume(graph, box)    a PCGVolume (brush via the PCG volume factory) running the graph, generated on demand
  build_gym_map()             /Game/Mars/Maps/VineGym_Mars_MAP: four bays from the crypt kit under the Mars light rig
  capture_review(out_dir)     the review shots of the open gym (one call after build_gym_map: captures need a tick)
  regression_scene() / regression_capture(out_dir, tag) / compare(png_a, png_b)
                              the before / after check of the master edit (host-side compare: plain python + PIL)
"""
import json
import math
import os
import sys

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
ENV_DIR = os.path.dirname(HERE)
COOKING_UE = os.path.join(os.path.dirname(ENV_DIR), "mars_cooking", "unreal")
for _p in (HERE, ENV_DIR, COOKING_UE):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import env_spec as spec          # noqa: E402
import mars_env_ue as me         # noqa: E402
import mars_cooking_ue as mc     # noqa: E402

EAL = unreal.EditorAssetLibrary
MEL = unreal.MaterialEditingLibrary

VINES_ROOT = spec.UE_ROOT + "/Vines"
PROFILES = VINES_ROOT + "/Profiles"
PCG_FOLDER = VINES_ROOT + "/PCG"
MESHES = spec.ue_mesh_folder("vines")
ORGANIC = spec.ue_mesh_folder("organic")
KIT = "/Game/Mars/Environment/Meshes/Crypt"
GYM_MAP = "/Game/Mars/Maps/VineGym_Mars_MAP"
REGRESS_MAP = "/Game/Developers/VineSpike/VineRegress_MAP"
GYM_FOLDER = "VineGym"
VINE_CLASS = "/Script/Angelscript.Mars_Vine"
VINE_PCG_CLASS = "/Script/Angelscript.Mars_VinePcg"
HERO_CLASS = "/Script/Angelscript.Mars_HeroRoot"


def _log(msg):
    unreal.log("[vine] %s" % msg)


def _warn(msg):
    unreal.log_warning("[vine] %s" % msg)


def _eas():
    return unreal.get_editor_subsystem(unreal.EditorActorSubsystem)


def _les():
    return unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)


def _world():
    return unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()


def _load(path):
    return me._load(path)


def _spawn(obj_or_class, loc, rot=(0.0, 0.0, 0.0), label=None, folder=GYM_FOLDER, scale=None):
    r = unreal.Rotator(roll=rot[2], pitch=rot[0], yaw=rot[1])
    if isinstance(obj_or_class, unreal.Class) or isinstance(obj_or_class, type):
        a = _eas().spawn_actor_from_class(obj_or_class, unreal.Vector(*loc), r)
    else:
        a = _eas().spawn_actor_from_object(obj_or_class, unreal.Vector(*loc), r)
    if a is None:
        raise RuntimeError("could not spawn %s" % obj_or_class)
    if label:
        a.set_actor_label(label)
    a.set_folder_path(folder)
    if scale is not None:
        a.set_actor_scale3d(unreal.Vector(*scale))
    return a


# ------------------------------------------------------------------ regression of the master edit
REGRESS_SLOTS = ("EnvBone", "EnvWood", "EnvIron", "EnvRust", "EnvCanvas", "EnvBark", "EnvMoss", "EnvWax", "EnvLeaf",
                 "EnvLeafDry")


def regression_scene():
    """A throwaway level: one sphere and one cube per dressing slot instance (engine shapes, no custom data, WPO off so
    the wind clock cannot differ between two captures), a warm key light, a cold fill, manual exposure."""
    if mc._in_pie():
        raise RuntimeError("stop PIE first")
    if EAL.does_asset_exist(REGRESS_MAP):
        _les().load_level(REGRESS_MAP)
        _eas().destroy_actors([a for a in _eas().get_all_level_actors() if not isinstance(a, (unreal.WorldSettings, unreal.Brush))])
    else:
        _les().new_level(REGRESS_MAP)
    sphere = _load("/Engine/BasicShapes/Sphere")
    cube = _load("/Engine/BasicShapes/Cube")
    floor = _spawn(cube, (450.0, 0.0, -60.0), scale=(14.0, 4.0, 0.2), label="Floor", folder="Regress")
    for i, slot in enumerate(REGRESS_SLOTS):
        mi = _load("%s/%s_Mars_MI" % (spec.UE_INSTANCES, slot))
        for j, mesh in enumerate((sphere, cube)):
            a = _spawn(mesh, (i * 100.0, j * 120.0 - 60.0, 0.0), rot=(0.0, 30.0 * j, 0.0), label="%s_%d" % (slot, j),
                       folder="Regress", scale=(0.8, 0.8, 0.8))
            c = a.static_mesh_component
            c.set_material(0, mi)
            c.set_editor_property("evaluate_world_position_offset", False)
    sun = _spawn(unreal.DirectionalLight, (0, 0, 500), rot=(-40.0, 30.0, 0.0), label="Key", folder="Regress")
    sun.get_component_by_class(unreal.DirectionalLightComponent).set_editor_property("intensity", 0.25)
    pt = _spawn(unreal.PointLight, (450.0, -300.0, 200.0), label="Fill", folder="Regress")
    pc = pt.point_light_component
    pc.set_editor_property("intensity", 60.0)
    pc.set_editor_property("light_color", unreal.Color(r=150, g=180, b=255, a=255))
    pc.set_editor_property("attenuation_radius", 2000.0)
    ppv = _spawn(unreal.PostProcessVolume, (0, 0, 0), label="Grade", folder="Regress")
    ppv.set_editor_property("unbound", True)
    s = ppv.get_editor_property("settings")
    s.set_editor_property("override_auto_exposure_method", True)
    s.set_editor_property("auto_exposure_method", unreal.AutoExposureMethod.AEM_MANUAL)
    s.set_editor_property("override_auto_exposure_bias", True)
    s.set_editor_property("auto_exposure_bias", -2.5)
    ppv.set_editor_property("settings", s)
    unreal.EditorLoadingAndSavingUtils.save_current_level()
    return {"actors": len(REGRESS_SLOTS) * 2, "floor": floor.get_name()}


def _capture(out_dir, shots, size=(1600, 900), exposure_bias=None):
    world = _world()
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
        if exposure_bias is not None:
            pp = comp.get_editor_property("post_process_settings")
            pp.set_editor_property("override_auto_exposure_method", True)
            pp.set_editor_property("auto_exposure_method", unreal.AutoExposureMethod.AEM_MANUAL)
            pp.set_editor_property("override_auto_exposure_bias", True)
            pp.set_editor_property("auto_exposure_bias", float(exposure_bias))
            comp.set_editor_property("post_process_settings", pp)
            comp.set_editor_property("post_process_blend_weight", 1.0)
        for name, (eye, target, fov) in shots.items():
            d = [t - e for e, t in zip(eye, target)]
            yaw = math.degrees(math.atan2(d[1], d[0]))
            pitch = math.degrees(math.atan2(d[2], math.hypot(d[0], d[1])))
            actor.set_actor_location_and_rotation(unreal.Vector(*eye), unreal.Rotator(roll=0.0, pitch=pitch, yaw=yaw), False, False)
            comp.set_editor_property("fov_angle", float(fov))
            comp.capture_scene()
            unreal.RenderingLibrary.export_render_target(world, rt, out_dir, name + ".png")
            done.append(os.path.join(out_dir, name + ".png"))
    finally:
        actor.destroy_actor()
    return done


def regression_capture(out_dir, tag):
    shots = {"regress_%s" % tag: ((450.0, -900.0, 350.0), (450.0, 0.0, 0.0), 65.0)}
    return _capture(out_dir, shots, exposure_bias=-4.0)


def compare(png_a, png_b):
    """Host side (plain python with PIL): mean absolute RGB difference in 8-bit steps."""
    from PIL import Image
    import numpy as np
    a = np.asarray(Image.open(png_a).convert("RGB"), float)
    b = np.asarray(Image.open(png_b).convert("RGB"), float)
    return float(np.abs(a - b).mean())


# ------------------------------------------------------------------ meshes after import
COLLIDING = {"VineBark_A": 1, "VineBark_B": 1, "HeroRoot_Top_A": 3, "HeroRoot_Mid_A": 3, "HeroRoot_Mid_B": 3,
             "HeroRoot_Mid_C": 3, "HeroRoot_Flare_A": 4, "HeroRoot_Flare_B": 4}


def post_import():
    """After me.import_meshes(only=["vines"]): simple collision for the bark segments (one hull, the optional root
    collision path; the spline mesh deforms it) and the hero modules (convex decomposition: the legacy FBX importer did
    not pick up the exported UCX hulls), and a single LOD on every vine mesh."""
    sme = unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem)
    report = {}
    for path in EAL.list_assets(MESHES, recursive=False):
        mesh = _load(path.split(".")[0])
        if not isinstance(mesh, unreal.StaticMesh):
            continue
        name = mesh.get_name().replace("_Mars_SM", "")
        hulls = COLLIDING.get(name, 0)
        if hulls:
            sme.remove_collisions(mesh)
            sme.set_convex_decomposition_collisions(mesh, hulls, 24, 100000)
        else:
            sme.remove_collisions(mesh)
        # One LOD only: a decimated LOD1 moves the shared end rings of segments and hero modules, which opens a gap at
        # every joint in the distance (seen in the gym), and the cards and leaves are 20 - 120 triangles already.
        opts = unreal.EditorScriptingMeshReductionOptions()
        s0 = unreal.EditorScriptingMeshReductionSettings()
        s0.set_editor_property("percent_triangles", 1.0)
        s0.set_editor_property("screen_size", 1.0)
        opts.set_editor_property("reduction_settings", [s0])
        opts.set_editor_property("auto_compute_lod_screen_size", False)
        lods = sme.set_lods(mesh, opts)
        EAL.save_loaded_asset(mesh)
        # get_simple_collision_count leaves convex hulls out: count the body setup's convex elements
        agg = mesh.get_editor_property("body_setup").get_editor_property("agg_geom")
        report[name] = {"convex_hulls": len(agg.get_editor_property("convex_elems")), "lods": lods}
    _log("post_import %s" % report)
    return report


# ------------------------------------------------------------------ PCG graphs (local-only plugin: Python only)
def _pcg():
    if not hasattr(unreal, "PCGGraph"):
        raise RuntimeError("the PCG plugin is not enabled in this editor (it is a local-only plugin in Mars.uproject)")
    return unreal


def _stable_seed(text):
    h = 2166136261
    for ch in text.encode("utf-8"):
        h = ((h ^ ch) * 16777619) & 0xFFFFFFFF
    return int(h & 0x7FFFFFFF) or 1


def _sel_in(text):
    s = unreal.PCGAttributePropertyInputSelector()
    s.import_text("PCGBegin(%s)PCGEnd" % text)     # the selector's text form; a bare name silently stays @Last
    if text not in s.export_text():
        raise RuntimeError("selector %r did not take" % text)
    return s


def _sel_out(text):
    s = unreal.PCGAttributePropertyOutputSelector()
    s.import_text("PCGBegin(%s)PCGEnd" % text)     # the selector's text form; a bare name silently stays @Last
    if text not in s.export_text():
        raise RuntimeError("selector %r did not take" % text)
    return s


class _PcgGraph:
    """Builds one graph in place: emptied (the input and output nodes stay), nodes added with stable unique seeds,
    edges added and remembered for the check."""

    def __init__(self, name):
        _pcg()
        path = "%s/%s" % (PCG_FOLDER, name)
        g = _load(path)
        if g is None:
            g = mc._tools().create_asset(name, PCG_FOLDER, unreal.PCGGraph, None)
        self.g, self.name, self.nodes, self.edges = g, name, {}, []
        keep = (g.get_input_node(), g.get_output_node())
        old = [n for n in g.get_editor_property("nodes") if n not in keep]
        for n in old:
            g.remove_node(n)          # remove_nodes takes its array by reference, which Python cannot pass

    def node(self, key, cls, **props):
        node, s = self.g.add_node_of_type(cls)
        s.set_editor_property("seed", _stable_seed(self.name + "/" + key))
        for k, v in props.items():
            s.set_editor_property(k, v)
        try:
            node.set_editor_property("node_title", unreal.Name(key))
        except Exception:
            pass
        self.nodes[key] = (node, s)
        return s

    def struct(self, key, prop, **fields):
        s = self.nodes[key][1]
        st = s.get_editor_property(prop)
        for k, v in fields.items():
            st.set_editor_property(k, v)
        s.set_editor_property(prop, st)
        return st

    def _n(self, key):
        if key == "IN":
            return self.g.get_input_node()
        if key == "OUT":
            return self.g.get_output_node()
        return self.nodes[key][0]

    def edge(self, a, b, apin="Out", bpin="In"):
        """Pin labels of the default "In": a raycast reads "Origins", Copy Attributes reads "Source" and "Target" (wired
        both from the same data: copy within it), the graph output reads "Out"."""
        targets = [bpin]
        if bpin == "In":
            s = self.nodes[b][1] if b in self.nodes else None
            if b == "OUT":
                targets = ["Out"]
            elif isinstance(s, unreal.PCGWorldRaycastElementSettings):
                targets = ["Origins"]
            elif isinstance(s, unreal.PCGCopyAttributesSettings):
                targets = ["Source", "Target"]
        for pin in targets:
            self.g.add_edge(self._n(a), apin, self._n(b), pin)
            self.edges.append((a, apin, b, pin))

    def chain(self, *keys):
        for a, b in zip(keys, keys[1:]):
            self.edge(a, b)

    def finish(self):
        try:
            self.g.force_notification_for_editor()
        except Exception:
            pass
        EAL.save_loaded_asset(self.g)
        return {"nodes": len(self.nodes), "edges": len(self.edges)}


def _raycast(G, key, direction, length, unbounded=False, keep=False, distance=False, impact=False, exclude_tag=None):
    s = G.node(key, unreal.PCGWorldRaycastElementSettings,
               raycast_mode=unreal.PCGWorldRaycastMode.NORMALIZED_WITH_LENGTH, ray_direction=unreal.Vector(*direction),
               ray_length=float(length), keep_original_point_on_miss=keep, unbounded=unbounded)
    fields = dict(ignore_pcg_hits=True, trace_complex=False, get_impact=impact or keep, get_distance=distance)
    if exclude_tag:
        fields.update(actor_tag_filter=unreal.PCGWorldQueryFilter.EXCLUDE, actor_tags_list=exclude_tag)
    G.struct(key, "world_query_params", **fields)
    return s


def _density_filter(G, key, lo, hi=1.0):
    return G.node(key, unreal.PCGDensityFilterSettings, lower_bound=float(lo), upper_bound=float(hi))


def _transform(G, key, off_min=(0, 0, 0), off_max=(0, 0, 0), absolute_offset=True, rot_min=None, rot_max=None):
    props = dict(offset_min=unreal.Vector(*off_min), offset_max=unreal.Vector(*off_max), absolute_offset=absolute_offset)
    if rot_min is not None:
        props.update(rotation_min=unreal.Rotator(roll=rot_min[2], pitch=rot_min[0], yaw=rot_min[1]),
                     rotation_max=unreal.Rotator(roll=rot_max[2], pitch=rot_max[0], yaw=rot_max[1]), absolute_rotation=True)
    return G.node(key, unreal.PCGTransformPointsSettings, **props)


def _prune(G, key_ext, key_prune, extents):
    G.node(key_ext, unreal.PCGPointExtentsModifierSettings, extents=unreal.Vector(extents, extents, extents),
           mode=unreal.PCGPointExtentsModifierMode.SET)
    s = G.node(key_prune, unreal.PCGSelfPruningSettings)
    G.struct(key_prune, "parameters", pruning_type=unreal.PCGSelfPruningType.ALL_EQUAL, randomized_pruning=True)
    G.edge(key_ext, key_prune)
    return s


def _noise(G, key, target, lo, hi):
    return G.node(key, unreal.PCGAttributeNoiseSettings, output_target=_sel_out(target), mode=unreal.PCGAttributeNoiseMode.SET,
                  noise_min=float(lo), noise_max=float(hi))


def _maths(G, key, op, a, b, out):
    s = G.node(key, unreal.PCGMetadataMathsSettings, operation=op)
    s.set_editor_property("input_source1", _sel_in(a))
    s.set_editor_property("input_source2", _sel_in(b))
    s.set_editor_property("output_target", _sel_out(out))
    return s


def _maths_edge(G, src, key):
    G.edge(src, key, "Out", "InA")
    G.edge(src, key, "Out", "InB")


def _template(G, key, props):
    """The template actor of a Spawn Actor node: its class, then its properties (the spawned vines' profile and layout)."""
    s = G.nodes[key][1]
    s.set_editor_property("template_actor_class", unreal.load_class(None, VINE_PCG_CLASS))
    s.set_editor_property("allow_template_actor_editing", True)
    t = s.get_editor_property("template_actor")
    if t is None:
        raise RuntimeError("%s: no template actor after allow_template_actor_editing" % key)
    for k, v in props.items():
        if k == "Shape":
            shape = t.get_editor_property("Shape")
            for sk, sv in v.items():
                shape.set_editor_property(sk, sv)
            t.set_editor_property("Shape", shape)
        else:
            t.set_editor_property(k, v)
    return t


def _spawn_vines(G, key, overrides, template):
    s = G.node(key, unreal.PCGSpawnActorSettings, option=unreal.PCGSpawnActorOption.NO_MERGING,
               attach_options=unreal.PCGAttachOptions.ATTACHED, warn_on_identical_spawn=False)
    descs = []
    for src, target in overrides:
        d = unreal.PCGObjectPropertyOverrideDescription()
        d.set_editor_property("input_source", _sel_in(src))
        d.set_editor_property("property_target", target)
        descs.append(d)
    s.set_editor_property("spawned_actor_property_override_descriptions", descs)
    _template(G, key, template)
    return s


def _mesh_spawner(G, key, meshes, packer, shadow=False, cull=(3500, 5000)):
    s = G.node(key, unreal.PCGStaticMeshSpawnerSettings, warn_on_identical_spawn=False,
               allow_merge_different_data_in_same_instanced_components=True)
    s.set_mesh_selector_type(unreal.PCGMeshSelectorWeighted)
    s.set_instance_packer_type(unreal.PCGInstanceDataPackerByAttribute)
    sel = s.get_editor_property("mesh_selector_parameters")
    entries = []
    for mesh_path, weight in meshes:
        e = unreal.PCGMeshSelectorWeightedEntry()
        name = mesh_path.rsplit("/", 1)[-1]
        e.import_text('(Descriptor=(StaticMesh="%s.%s",Mobility=Static,bCastShadow=%s,InstanceStartCullDistance=%d,'
                      'InstanceEndCullDistance=%d,WorldPositionOffsetDisableDistance=3000,bAffectDistanceFieldLighting=False,'
                      'ComponentTags=("Ck.Jolt.NoBake")),Weight=%d)' % (mesh_path, name, "True" if shadow else "False",
                                                                         cull[0], cull[1], int(round(weight * 100))))
        entries.append(e)
    sel.set_editor_property("mesh_entries", entries)
    pk = s.get_editor_property("instance_data_packer_parameters")
    pk.set_editor_property("attribute_selectors", [_sel_in(a) for a in packer])
    return s


def _existing(paths):
    return [(p, w) for p, w in paths if EAL.does_asset_exist(p)]


def _vine_profile(preset):
    return _load("%s/Vine%s_Mars_DA" % (PROFILES, preset))


def _enum(name, member):
    return getattr(getattr(unreal, name), member)


def build_graph_curtain():
    """Graph A: ivy curtains off rails and ledges. Volume points every 40 x 40 cm (one layer per 3.5 m storey) dropped
    onto up-facing tops; four probes 30 cm past each top keep only those with nothing within 150 cm below (a lip),
    pruned to a site every ~1.8 m, each spawning a fitted AMars_VinePcg (Curtain, Air, VineIvy) yawed outward."""
    G = _PcgGraph("VineCurtain_Mars_PCG")
    G.node("Points", unreal.PCGVolumeSamplerSettings, voxel_size=unreal.Vector(40.0, 40.0, 350.0))
    G.edge("IN", "Points", "In", "Volume")
    _raycast(G, "Tops", (0, 0, -1), 350.0, exclude_tag="Mars.NoVines")
    G.node("TopFacing", unreal.PCGNormalToDensitySettings, normal=unreal.Vector(0, 0, 1), strength=1.0)
    _density_filter(G, "KeepTops", 0.85)
    G.chain("Points", "Tops", "TopFacing", "KeepTops")
    G.node("Lips", unreal.PCGMergeSettings)
    for i, (off, yaw) in enumerate((((30, 0, 8), 0.0), ((-30, 0, 8), 180.0), ((0, 30, 8), 90.0), ((0, -30, 8), 270.0))):
        _transform(G, "Out%d" % i, off, off, True, (0.0, yaw, 0.0), (0.0, yaw, 0.0))
        _raycast(G, "Drop%d" % i, (0, 0, -1), 150.0, unbounded=True, keep=True, impact=True)
        G.node("Edge%d" % i, unreal.PCGAttributeFilteringSettings, operator=unreal.PCGAttributeFilterOperator.EQUAL,
               target_attribute=_sel_in("ImpactResult"), use_constant_threshold=True)
        G.struct("Edge%d" % i, "attribute_types", type=unreal.PCGMetadataTypes.BOOLEAN, bool_value=False)
        G.chain("KeepTops", "Out%d" % i, "Drop%d" % i, "Edge%d" % i)
        G.edge("Edge%d" % i, "Lips", "InsideFilter", "In")
    G.node("Excluded", unreal.PCGDataFromActorSettings)
    G.struct("Excluded", "actor_selector", actor_filter=unreal.PCGActorFilter.ALL_WORLD_ACTORS,
             actor_selection=unreal.PCGActorSelection.BY_TAG, actor_selection_tag="Mars.VineExclude", select_multiple=True)
    G.node("Carve", unreal.PCGDifferenceSettings)
    G.edge("Lips", "Carve", "Out", "Source")
    G.edge("Excluded", "Carve", "Out", "Differences")
    _prune(G, "Spacing", "Prune", 90.0)
    G.edge("Carve", "Spacing")
    _spawn_vines(G, "Vines", [("$Seed", "Seed")],
                 dict(Profile=_vine_profile("Ivy"), Layout=_enum("Mars_VineLayout", "CURTAIN"),
                      End=_enum("Mars_VineEnd", "AIR"), Shape={"WidthCm": 160.0, "StrandCount": 7}))
    G.chain("Prune", "Vines", "OUT")
    return G.finish()


def build_graph_ceiling_roots():
    """Graph B: roots dropping from ceilings and vault soffits, their length the traced floor distance below (a second
    ray) times a drawn fraction, written to each spawned vine's LengthOverrideCm."""
    G = _PcgGraph("VineCeilingRoots_Mars_PCG")
    G.node("Points", unreal.PCGVolumeSamplerSettings, voxel_size=unreal.Vector(300.0, 300.0, 150.0))
    G.edge("IN", "Points", "In", "Volume")
    _transform(G, "Jitter", (-120, -120, 0), (120, 120, 0), True)
    _raycast(G, "Up", (0, 0, 1), 3000.0, unbounded=True, exclude_tag="Mars.NoVines")
    G.node("Ceilings", unreal.PCGNormalToDensitySettings, normal=unreal.Vector(0, 0, -1), strength=1.0)
    _density_filter(G, "KeepCeilings", 0.6)
    G.node("Clumps", unreal.PCGSpatialNoiseSettings)
    _density_filter(G, "KeepClumps", 0.3)
    G.chain("Points", "Jitter", "Up", "Ceilings", "KeepCeilings", "Clumps", "KeepClumps")
    _prune(G, "Spacing", "Prune", 150.0)
    G.edge("KeepClumps", "Spacing")
    _transform(G, "Anchor", (0, 0, -5), (0, 0, -5), True, (0, 0, 0), (0, 0, 0))
    G.node("Remember", unreal.PCGCopyAttributesSettings, input_source=_sel_in("$Position"), output_target=_sel_out("AnchorPos"))
    _raycast(G, "Down", (0, 0, -1), 3000.0, unbounded=True, keep=True, distance=True)
    G.node("Restore", unreal.PCGCopyAttributesSettings, input_source=_sel_in("AnchorPos"), output_target=_sel_out("$Position"))
    _noise(G, "Fraction", "LengthFrac", 0.35, 0.9)
    _maths(G, "Length", unreal.PCGMetadataMathsOperation.MULTIPLY, "ImpactDistance", "LengthFrac", "LengthCm")
    _transform(G, "Yaw", (0, 0, 0), (0, 0, 0), False, (0, 0, 0), (0, 360, 0))
    G.chain("Prune", "Anchor", "Remember", "Down", "Restore", "Fraction")
    _maths_edge(G, "Fraction", "Length")
    G.edge("Length", "Yaw")
    _spawn_vines(G, "Vines", [("$Seed", "Seed"), ("LengthCm", "LengthOverrideCm")],
                 dict(Profile=_vine_profile("ThinRoot"), Layout=_enum("Mars_VineLayout", "DROP"),
                      End=_enum("Mars_VineEnd", "AIR")))
    G.chain("Yaw", "Vines", "OUT")
    return G.finish()


STRAND_MESHES = [("%s/VineMossStrand_A_Mars_SM" % MESHES, 0.4), ("%s/VineMossStrand_B_Mars_SM" % MESHES, 0.35),
                 ("%s/VineMossStrand_C_Mars_SM" % MESHES, 0.25)]


def build_graph_underside():
    """Graph C: stemless moss strands under ceilings and arch soffits, PCG-only instancing. A strand's length is the
    traced floor distance times a drawn fraction; its card is stretched to it ($Scale.z = L / 100) and the foliage
    master's four floats are packed per instance: VarSeed, Dryness, WindAdd (WindWeight - 1), LengthAdd (L / 100 - 1)."""
    G = _PcgGraph("VineUnderside_Mars_PCG")
    G.node("Points", unreal.PCGVolumeSamplerSettings, voxel_size=unreal.Vector(45.0, 45.0, 200.0))
    G.edge("IN", "Points", "In", "Volume")
    _transform(G, "Jitter", (-20, -20, 0), (20, 20, 0), True)
    _raycast(G, "Up", (0, 0, 1), 3000.0, unbounded=True, exclude_tag="Mars.NoVines")
    G.node("Undersides", unreal.PCGNormalToDensitySettings, normal=unreal.Vector(0, 0, -1), strength=1.0)
    _density_filter(G, "KeepUndersides", 0.2)
    G.node("Clumps", unreal.PCGSpatialNoiseSettings)
    _density_filter(G, "KeepClumps", 0.5)
    G.chain("Points", "Jitter", "Up", "Undersides", "KeepUndersides", "Clumps", "KeepClumps")
    _prune(G, "Spacing", "Prune", 20.0)
    G.edge("KeepClumps", "Spacing")
    _transform(G, "Anchor", (0, 0, 2), (0, 0, 2), True, (0, 0, 0), (0, 0, 0))
    G.node("Remember", unreal.PCGCopyAttributesSettings, input_source=_sel_in("$Position"), output_target=_sel_out("AnchorPos"))
    _transform(G, "Below", (0, 0, -4), (0, 0, -4), True)
    _raycast(G, "Down", (0, 0, -1), 3000.0, unbounded=True, keep=True, distance=True)
    G.node("Restore", unreal.PCGCopyAttributesSettings, input_source=_sel_in("AnchorPos"), output_target=_sel_out("$Position"))
    G.chain("Prune", "Anchor", "Remember", "Below", "Down", "Restore")
    _noise(G, "Fraction", "LengthFrac", 0.06, 0.3)
    _noise(G, "Hundredth", "K", 0.01, 0.01)
    _noise(G, "One", "One", 1.0, 1.0)
    _noise(G, "Width", "W", 0.7, 1.4)
    _noise(G, "Seed", "VarSeed", 0.0, 1.0)
    _noise(G, "Dry", "Dryness", 0.0, 0.3)
    _noise(G, "Wind", "WindAdd", -0.4, 0.2)
    G.chain("Restore", "Fraction", "Hundredth", "One", "Width", "Seed", "Dry", "Wind")
    _maths(G, "Length", unreal.PCGMetadataMathsOperation.MULTIPLY, "ImpactDistance", "LengthFrac", "LengthCm")
    _maths_edge(G, "Wind", "Length")
    _maths(G, "Stretch", unreal.PCGMetadataMathsOperation.MULTIPLY, "LengthCm", "K", "LenScale")
    _maths_edge(G, "Length", "Stretch")
    _maths(G, "LengthAdd", unreal.PCGMetadataMathsOperation.SUBTRACT, "LenScale", "One", "LengthAdd")
    _maths_edge(G, "Stretch", "LengthAdd")
    s = G.node("Scale", unreal.PCGMetadataMakeVectorSettings, output_type=unreal.PCGMetadataTypes.VECTOR)
    s.set_editor_property("input_source1", _sel_in("W"))
    s.set_editor_property("input_source2", _sel_in("W"))
    s.set_editor_property("input_source3", _sel_in("LenScale"))
    s.set_editor_property("output_target", _sel_out("$Scale"))
    for pin in ("X", "Y", "Z"):
        G.edge("LengthAdd", "Scale", "Out", pin)
    _transform(G, "Yaw", (0, 0, 0), (0, 0, 0), False, (-3, 0, -3), (3, 360, 3))
    G.edge("Scale", "Yaw")
    _mesh_spawner(G, "Strands", _existing(STRAND_MESHES), ["VarSeed", "Dryness", "WindAdd", "LengthAdd"])
    G.chain("Yaw", "Strands", "OUT")
    return G.finish()


def build_graph_skirt():
    """Graph D: moss pads and dead leaves at wall and pier bases. Floor points; four short horizontal rays keep those
    near a wall, pushed out along the wall normal and pruned, then a random choice splits them into moss (paint master
    floats: VarSeed, MossAdd, WetAdd, 0) and litter (foliage floats: VarSeed, Dryness, WindAdd -0.8, 0)."""
    G = _PcgGraph("VineSkirt_Mars_PCG")
    G.node("Points", unreal.PCGVolumeSamplerSettings, voxel_size=unreal.Vector(50.0, 50.0, 100.0))
    G.edge("IN", "Points", "In", "Volume")
    _raycast(G, "Floor", (0, 0, -1), 800.0, unbounded=True, exclude_tag="Mars.NoVines")
    G.node("Up", unreal.PCGNormalToDensitySettings, normal=unreal.Vector(0, 0, 1), strength=1.0)
    _density_filter(G, "KeepFloors", 0.85)
    _transform(G, "Lift", (0, 0, 10), (0, 0, 10), True, (0, 0, 0), (0, 0, 0))
    G.chain("Points", "Floor", "Up", "KeepFloors", "Lift")
    G.node("Walls", unreal.PCGMergeSettings)
    for i, d in enumerate(((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0))):
        _raycast(G, "Wall%d" % i, d, 90.0, unbounded=True, distance=True)
        G.chain("Lift", "Wall%d" % i)
        G.edge("Wall%d" % i, "Walls")
    _transform(G, "OffWall", (0, 0, 5), (0, 0, 25), False)
    _transform(G, "Settle", (0, 0, -10), (0, 0, -10), True, (0, 0, 0), (0, 360, 0))
    G.chain("Walls", "OffWall", "Settle")
    _prune(G, "Spacing", "Prune", 30.0)
    G.edge("Settle", "Spacing")
    G.node("Split", unreal.PCGRandomChoiceSettings, ratio=0.6)
    G.edge("Prune", "Split")
    _noise(G, "Seed", "VarSeed", 0.0, 1.0)
    _noise(G, "Moss", "MossAdd", -0.2, 0.6)
    _noise(G, "Wet", "WetAdd", 0.0, 0.3)
    _noise(G, "Zero", "Zero", 0.0, 0.0)
    G.edge("Split", "Seed", "Chosen", "In")
    G.chain("Seed", "Moss", "Wet", "Zero")
    pads = _existing([("%s/MossPad_A_Mars_SM" % ORGANIC, 0.5), ("%s/MossPad_B_Mars_SM" % ORGANIC, 0.5)])
    _mesh_spawner(G, "MossPads", pads or _existing([("%s/VineKnot_A_Mars_SM" % MESHES, 1.0)]),
                  ["VarSeed", "MossAdd", "WetAdd", "Zero"], shadow=True)
    G.chain("Zero", "MossPads", "OUT")
    _noise(G, "LSeed", "VarSeed", 0.0, 1.0)
    _noise(G, "LDry", "Dryness", 0.5, 1.0)
    _noise(G, "LWind", "WindAdd", -0.8, -0.8)
    _noise(G, "LZero", "Zero", 0.0, 0.0)
    G.edge("Split", "LSeed", "Discarded", "In")
    G.chain("LSeed", "LDry", "LWind", "LZero")
    litter = _existing([("%s/DeadLeaves_Pile_A_Mars_SM" % ORGANIC, 0.3), ("%s/DeadLeaves_Pile_B_Mars_SM" % ORGANIC, 0.3),
                        ("%s/DeadLeaves_Scatter_A_Mars_SM" % ORGANIC, 0.4)])
    _mesh_spawner(G, "Litter", litter or _existing([("%s/VineLeaves_C_Mars_SM" % MESHES, 1.0)]),
                  ["VarSeed", "Dryness", "WindAdd", "Zero"], shadow=False)
    G.chain("LZero", "Litter", "OUT")
    return G.finish()


GRAPHS = {"VineCurtain_Mars_PCG": build_graph_curtain, "VineCeilingRoots_Mars_PCG": build_graph_ceiling_roots,
          "VineUnderside_Mars_PCG": build_graph_underside, "VineSkirt_Mars_PCG": build_graph_skirt}


def _log_lines():
    path = os.path.join(r"D:\Repo\Mars\Saved\Logs", "HiddenEnv_Mars.log")
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return fh.read().splitlines()
    except OSError:
        return []


def build_pcg_graphs(only=None):
    """Builds the four graphs in place; fails on any new LogPCG pin-label error (AddEdge reports success on a wrong pin)."""
    before = len(_log_lines())
    out = {}
    for name, fn in GRAPHS.items():
        if only and name not in only:
            continue
        out[name] = fn()
    errors = [l for l in _log_lines()[before:] if ("does not have the" in l and "label" in l) or "LogPCG: Error" in l]
    out["label_errors"] = errors[:20]
    _log("build_pcg_graphs %s" % out)
    if errors:
        raise RuntimeError("PCG wiring errors: %s" % errors[:5])
    return out


# ------------------------------------------------------------------ profiles, instances
def seed_profiles(force=True):
    """Mars.Vine.SeedProfiles (force refills the numbers and rebinds the kit meshes)."""
    unreal.SystemLibrary.execute_console_command(_world(), "Mars.Vine.SeedProfiles%s" % (" force" if force else ""))
    return sorted(str(p) for p in EAL.list_assets(PROFILES, recursive=False))


VINE_INSTANCES = {
    "VineBarkRoot_Mars_MI": (me.PAINT_MASTER, {"Roughness": 0.85, "Moss Amount": 0.5, "Grime Amount": 0.35,
                                               "Value Variation": 0.18}, {}),
    "VineBarkWet_Mars_MI": (me.PAINT_MASTER, {"Roughness": 0.85, "Wetness": 0.7, "Moss Amount": 0.6}, {}),
    "VineLeafIvyWet_Mars_MI": (me.FOLIAGE_MASTER, {"Roughness": 0.3}, {}),
    # 2026-10-24 (vignettes): cobwebs on the shared olive EnvStrand read as nothing in a dark crypt; pale, catching the
    # light from behind. Rootlets on it read as pale straight lines; darker, rooty brown with no backlight.
    "VineCobweb_Mars_MI": (me.FOLIAGE_MASTER, {"Roughness": 0.45, "Cavity AO": 0.2, "Wind Strength": 1.5, "Value Variation": 0.1},
                           {"Tint": (2.4, 2.4, 2.5, 1.0), "Subsurface Color": (0.32, 0.32, 0.34, 1.0)}),
    "VineRootlet_Mars_MI": (me.FOLIAGE_MASTER, {"Roughness": 0.8, "Wind Strength": 2.0, "Value Variation": 0.2},
                            {"Tint": (0.55, 0.42, 0.34, 1.0), "Subsurface Color": (0.03, 0.022, 0.015, 1.0)}),
}

# profile -> its strand material (kept by Fill_Preset, so a forced reseed leaves them bound)
STRAND_MATERIALS = {"VineCobweb_Mars_DA": "VineCobweb_Mars_MI", "VineRootlets_Mars_DA": "VineRootlet_Mars_MI"}


def bind_strand_materials():
    out = {}
    for prof, mat in STRAND_MATERIALS.items():
        p = _load("%s/%s" % (PROFILES, prof))
        r = p.get_editor_property("Rendering")
        r.set_editor_property("StrandMaterial", _load("%s/%s" % (spec.UE_INSTANCES, mat)))
        p.set_editor_property("Rendering", r)
        EAL.save_loaded_asset(p)
        out[prof] = mat
    return out


def build_instances(force=False):
    out = []
    for name, (master, scalars, vectors) in VINE_INSTANCES.items():
        me._instance(name, "%s/%s" % (spec.UE_MATERIALS, master), scalars, vectors, force=force)
        out.append(name)
    return out


# ------------------------------------------------------------------ the gym
# Mars light rig numbers (the lookdev map): warm lamps, a cold rim, manual exposure, fog, no sky light.
GYM_LOOK = {"lamp_cd": 400.0, "lamp_color": (255, 170, 98), "moon_lux": 1.5, "moon_color": (110, 140, 255),
            "spirit_cd": 160.0, "spirit_color": (90, 170, 255), "fog_density": 0.015}
TILE = 400.0


def _mesh(name):
    m = _load("%s/%s" % (KIT, name))
    if m is None:
        raise RuntimeError("kit piece %s is missing" % name)
    return m


def _bounds(mesh):
    b = mesh.get_bounds()
    o, e = b.origin, b.box_extent
    return (o.x - e.x, o.y - e.y, o.z - e.z), (o.x + e.x, o.y + e.y, o.z + e.z)


def _place_min(mesh, at, folder, yaw=0.0, label=None, scale=None):
    """Spawns mesh so its unrotated bounds' minimum corner lands at `at` (yaw 0 / 180 handled for runs)."""
    lo, hi = _bounds(mesh)
    if abs(yaw) < 1e-3:
        loc = (at[0] - lo[0], at[1] - lo[1], at[2] - lo[2])
    else:
        loc = (at[0] + hi[0], at[1] + hi[1], at[2] - lo[2])
    return _spawn(mesh, loc, (0.0, yaw, 0.0), label, folder, scale)


def _floor(x0, y0, nx, ny, z, folder, piece="CryptFloor4x4_Mars_SM"):
    mesh = _mesh(piece)
    lo, hi = _bounds(mesh)
    for i in range(nx):
        for j in range(ny):
            # the walking surface (bounds top) at z
            _spawn(mesh, (x0 + i * TILE - lo[0], y0 + j * TILE - lo[1], z - hi[2]), folder=folder)


def _roof(x0, y0, nx, ny, z, folder):
    """Roof tiles whose underside is at z."""
    mesh = _mesh("CryptRoof4x4_Mars_SM")
    lo, hi = _bounds(mesh)
    for i in range(nx):
        for j in range(ny):
            _spawn(mesh, (x0 + i * TILE - lo[0], y0 + j * TILE - lo[1], z - lo[2]), folder=folder)


def _wall_run(x0, y, n, storeys, folder, piece="CryptWall4m_Mars_SM", yaw=0.0):
    mesh = _mesh(piece)
    for s in range(storeys):
        for i in range(n):
            x = x0 + i * TILE if yaw == 0.0 else x0 + (i + 1) * TILE
            _spawn(mesh, (x, y, s * 350.0), (0.0, yaw, 0.0), folder=folder)


def _side_wall(x, y0, n, storeys, folder, facing_pos_x=True):
    mesh = _mesh("CryptWall4m_Mars_SM")
    for s in range(storeys):
        for i in range(n):
            # a wall run along +Y: yaw -90 runs toward -Y, +90 toward +Y
            if facing_pos_x:
                _spawn(mesh, (x, y0 + (i + 1) * TILE, s * 350.0), (0.0, -90.0, 0.0), folder=folder)
            else:
                _spawn(mesh, (x, y0 + i * TILE, s * 350.0), (0.0, 90.0, 0.0), folder=folder)


def _lamp(loc, folder, cd=None, color=None, radius=1600.0, label=None):
    a = _spawn(unreal.PointLight, loc, label=label, folder=folder + "/Light")
    c = a.point_light_component
    col = color or GYM_LOOK["lamp_color"]
    c.set_editor_property("intensity", cd or GYM_LOOK["lamp_cd"])
    c.set_editor_property("light_color", unreal.Color(r=col[0], g=col[1], b=col[2], a=255))
    c.set_editor_property("attenuation_radius", radius)
    c.set_editor_property("source_radius", 8.0)
    return a


def _vine(loc, profile, layout, end, folder, yaw=0.0, pitch=0.0, shape=None, seed=0, label=None, extra=None):
    cls = unreal.load_class(None, VINE_CLASS)
    a = _spawn(cls, loc, (pitch, yaw, 0.0), label, folder)
    a.set_editor_property("Profile", _vine_profile(profile))
    a.set_editor_property("Layout", _enum("Mars_VineLayout", layout))
    a.set_editor_property("End", _enum("Mars_VineEnd", end))
    a.set_editor_property("Seed", seed)
    if shape:
        sh = a.get_editor_property("Shape")
        for k, v in shape.items():
            sh.set_editor_property(k, v)
        a.set_editor_property("Shape", sh)
    for k, v in (extra or {}).items():
        a.set_editor_property(k, v)
    a.call_method("Rebuild")
    return a


def _hero(loc, folder, seed, label):
    a = _spawn(unreal.load_class(None, HERO_CLASS), loc, (0.0, 0.0, 0.0), label, folder)
    a.set_editor_property("Seed", seed)
    a.set_editor_property("Material", _load("%s/VineBarkRoot_Mars_MI" % spec.UE_INSTANCES))
    a.call_method("Rebuild")
    return a


def place_volume(graph, center, size, label=None, folder=GYM_FOLDER + "/PCG"):
    """A stock PCGVolume running `graph` (asset name or object) over a box (size in cm), generated on demand now."""
    _pcg()
    g = graph if not isinstance(graph, str) else _load("%s/%s" % (PCG_FOLDER, graph))
    vol = unreal.EditorLevelLibrary.spawn_actor_from_object(g, unreal.Vector(*center))
    if vol is None:
        raise RuntimeError("could not place a volume for %s" % graph)
    # the factory's brush size is not documented: scale, measure, correct
    vol.set_actor_scale3d(unreal.Vector(1.0, 1.0, 1.0))
    vol.set_actor_location(unreal.Vector(*center), False, False)
    for _ in range(3):
        _origin, ext = vol.get_actor_bounds(False)
        sc = vol.get_actor_scale3d()
        vol.set_actor_scale3d(unreal.Vector(sc.x * size[0] / max(2.0 * ext.x, 1e-3), sc.y * size[1] / max(2.0 * ext.y, 1e-3),
                                            sc.z * size[2] / max(2.0 * ext.z, 1e-3)))
    if label:
        vol.set_actor_label(label)
    vol.set_folder_path(folder)
    comp = vol.get_component_by_class(unreal.PCGComponent)
    comp.set_editor_property("generation_trigger", unreal.PCGComponentGenerationTrigger.GENERATE_ON_DEMAND)
    comp.set_graph(g)
    comp.generate_local(True)
    return vol


def build_gym_map(pcg=True):
    """VineGym_Mars_MAP from the crypt kit: (a) a 3-storey atrium (16 x 16 m, 10.5 m to the roof) with two galleries
    behind balustrades, piers, two hero roots, two giant roots, ivy wrapped on the piers and curtains off the balustrades
    (a Curtain PCG volume plus two fitted vines); (b) a sewer wall with a pipe the ivy wraps and creeps along; (c) a cistern
    soffit with an Underside PCG volume, a moss patch and a Skirt volume; (d) an ossuary bay with thin air roots,
    rootlets and cobwebs. Rebuilt from scratch; the level that was open is left for this one."""
    if mc._in_pie():
        raise RuntimeError("stop PIE first")
    if EAL.does_asset_exist(GYM_MAP):
        _les().load_level(GYM_MAP)
        old = _eas().get_all_level_actors()
        for a in old:
            comp = a.get_component_by_class(unreal.PCGComponent) if hasattr(unreal, "PCGComponent") else None
            if comp is not None:
                comp.cleanup_local(True)
        # a PCGVolume is a Brush: keep only the world settings and the level's builder brush
        _eas().destroy_actors([a for a in _eas().get_all_level_actors()
                               if not isinstance(a, unreal.WorldSettings) and a.get_class().get_name() != "Brush"])
    else:
        _les().new_level(GYM_MAP)
    made = {}
    # (a) atrium
    A = GYM_FOLDER + "/Atrium"
    _floor(0.0, 0.0, 4, 4, 0.0, A + "/Kit")
    _wall_run(0.0, 0.0, 4, 3, A + "/Kit")
    _side_wall(0.0, 0.0, 4, 3, A + "/Kit", True)
    _side_wall(1600.0, 0.0, 4, 3, A + "/Kit", False)
    _roof(0.0, 0.0, 4, 4, 1050.0, A + "/Kit")
    for z in (350.0, 700.0):
        _floor(0.0, 0.0, 4, 1, z, A + "/Gallery%d" % int(z))
        bal = _mesh("CryptBalustrade4m_Mars_SM")
        for i in range(4):
            _place_min(bal, (i * TILE, TILE - 40.0, z), A + "/Gallery%d" % int(z))
    pier = _mesh("CryptPierH11m5_Mars_SM")
    for px in (300.0, 1300.0):
        _spawn(pier, (px, 1250.0, 0.0), folder=A + "/Kit")
    made["heroes"] = [_hero((800.0, 1000.0, 1050.0), A + "/Vines", 11, "HeroRoot_A").get_name(),
                      _hero((520.0, 700.0, 1050.0), A + "/Vines", 23, "HeroRoot_B").get_name()]
    made["giant"] = [_vine((1100.0, 700.0, 1000.0), "GiantRoot", "DROP", "GROUND", A + "/Vines", seed=5, label="GiantRoot_A").get_name(),
                     _vine((300.0, 900.0, 1000.0), "GiantRoot", "DROP", "GROUND", A + "/Vines", seed=9, label="GiantRoot_B").get_name()]
    for i, px in enumerate((300.0, 1300.0)):
        _vine((px + 90.0, 1250.0, 20.0), "Ivy", "WRAP", "GROUND", A + "/Vines", shape={"Turns": 3.0, "HeightCm": 650.0,
                                                                                        "StrandCount": 2}, seed=31 + i,
              label="PierIvy_%d" % i)
    for i, x in enumerate((420.0, 1180.0)):
        _vine((x, 430.0, 458.0), "Ivy", "CURTAIN", "AIR", A + "/Vines", yaw=90.0, shape={"WidthCm": 300.0, "StrandCount": 8},
              seed=41 + i, label="RailCurtain_%d" % i)
    _lamp((800.0, 900.0, 300.0), A, label="Lamp_Floor")
    _lamp((800.0, 600.0, 600.0), A, label="Lamp_Gallery")
    _lamp((300.0, 600.0, 250.0), A, label="Lamp_West")
    _lamp((1300.0, 600.0, 250.0), A, label="Lamp_East")
    _lamp((800.0, 1450.0, 800.0), A, cd=GYM_LOOK["lamp_cd"] * 0.6, radius=2200.0, label="Lamp_High")
    _lamp((400.0, 1300.0, 200.0), A, cd=GYM_LOOK["spirit_cd"], color=GYM_LOOK["spirit_color"], label="Spirit_Pier")
    # (b) sewer
    B = GYM_FOLDER + "/Sewer"
    _floor(2000.0, 0.0, 2, 2, 0.0, B + "/Kit")
    _wall_run(2000.0, 0.0, 2, 1, B + "/Kit")
    pipe = _spawn(_load("/Engine/BasicShapes/Cylinder"), (2400.0, 60.0, 130.0), (90.0, 0.0, 0.0), "Pipe", B + "/Kit",
                  (0.44, 0.44, 7.0))
    pipe.static_mesh_component.set_material(0, _load("%s/EnvRust_Mars_MI" % spec.UE_INSTANCES))
    wet = _load("%s/VineBarkWet_Mars_MI" % spec.UE_INSTANCES)
    _vine((2080.0, 60.0, 130.0), "Ivy", "WRAP", "AIR", B + "/Vines", pitch=-90.0, shape={"Turns": 4.0, "HeightCm": 600.0,
                                                                                          "StrandCount": 1}, seed=51,
          label="PipeIvy")
    _vine((2550.0, 40.0, 60.0), "Ivy", "CREEP", "GROUND", B + "/Vines", shape={"HeightCm": 320.0, "StrandCount": 3}, seed=52,
          label="WallIvy")
    _vine((2250.0, 300.0, 340.0), "ThinRoot", "DROP", "GROUND", B + "/Vines", seed=53, label="WetRoot",
          extra={"Collision": _enum("Mars_VineCollision", "OFF")})
    _roof(2000.0, 0.0, 2, 2, 350.0, B + "/Kit")
    _lamp((2400.0, 500.0, 250.0), B, label="Lamp_Sewer")
    # (c) cistern
    C = GYM_FOLDER + "/Cistern"
    _floor(3200.0, 0.0, 2, 2, 0.0, C + "/Kit")
    _wall_run(3200.0, 0.0, 2, 2, C + "/Kit")
    _roof(3200.0, 0.0, 2, 2, 500.0, C + "/Kit")
    _vine((3400.0, 500.0, 300.0), "HangingMoss", "PATCH", "AIR", C + "/Vines", shape={"PatchRadiusCm": 120.0}, seed=61,
          label="MossPatch")
    _lamp((3600.0, 600.0, 200.0), C, cd=GYM_LOOK["spirit_cd"], color=GYM_LOOK["spirit_color"], label="Spirit_Cistern")
    _lamp((3900.0, 300.0, 300.0), C, label="Lamp_Cistern")
    # (d) ossuary
    D = GYM_FOLDER + "/Ossuary"
    _floor(4400.0, 0.0, 2, 2, 0.0, D + "/Kit")
    _wall_run(4400.0, 0.0, 2, 1, D + "/Kit", piece="CryptWallOssuary4m_Mars_SM")
    _roof(4400.0, 0.0, 2, 2, 350.0, D + "/Kit")
    for i, x in enumerate((4550.0, 4800.0, 5050.0)):
        _vine((x, 120.0 + 40.0 * i, 330.0), "ThinRoot", "DROP", "AIR", D + "/Vines", seed=71 + i, label="AirRoot_%d" % i)
    _vine((4700.0, 450.0, 300.0), "Rootlets", "PATCH", "GROUND", D + "/Vines", shape={"PatchRadiusCm": 110.0}, seed=81,
          label="Rootlets")
    _vine((5100.0, 650.0, 300.0), "Cobweb", "PATCH", "AIR", D + "/Vines", shape={"PatchRadiusCm": 80.0}, seed=82,
          label="Cobwebs")
    _lamp((4800.0, 500.0, 220.0), D, label="Lamp_Ossuary")
    # rig: cold moon, fog, manual exposure, a reflection capture per bay
    moon = _spawn(unreal.DirectionalLight, (0, 0, 2000), (-35.0, 40.0, 0.0), "Moon", GYM_FOLDER + "/Rig")
    mc_ = moon.get_component_by_class(unreal.DirectionalLightComponent)
    mc_.set_editor_property("intensity", GYM_LOOK["moon_lux"])
    col = GYM_LOOK["moon_color"]
    mc_.set_editor_property("light_color", unreal.Color(r=col[0], g=col[1], b=col[2], a=255))
    fog = _spawn(unreal.ExponentialHeightFog, (0, 0, 0), label="Fog", folder=GYM_FOLDER + "/Rig")
    fog.get_component_by_class(unreal.ExponentialHeightFogComponent).set_editor_property("fog_density", GYM_LOOK["fog_density"])
    ppv = _spawn(unreal.PostProcessVolume, (0, 0, 0), label="Grade", folder=GYM_FOLDER + "/Rig")
    ppv.set_editor_property("unbound", True)
    s = ppv.get_editor_property("settings")
    s.set_editor_property("override_auto_exposure_method", True)
    s.set_editor_property("auto_exposure_method", unreal.AutoExposureMethod.AEM_MANUAL)
    s.set_editor_property("override_auto_exposure_bias", True)
    s.set_editor_property("auto_exposure_bias", 8.7)
    ppv.set_editor_property("settings", s)
    for x in (800.0, 2400.0, 3600.0, 4800.0):
        cap = _spawn(unreal.SphereReflectionCapture, (x, 600.0, 250.0), label="Reflections", folder=GYM_FOLDER + "/Rig")
        cap.get_component_by_class(unreal.SphereReflectionCaptureComponent).set_editor_property("influence_radius", 1400.0)
    if pcg:
        made["volumes"] = [
            place_volume("VineCurtain_Mars_PCG", (800.0, 450.0, 600.0), (1500.0, 200.0, 800.0), "Curtain_Galleries").get_name(),
            place_volume("VineUnderside_Mars_PCG", (3600.0, 400.0, 250.0), (760.0, 760.0, 480.0), "Underside_Cistern").get_name(),
            place_volume("VineSkirt_Mars_PCG", (3600.0, 400.0, 150.0), (780.0, 780.0, 280.0), "Skirt_Cistern").get_name(),
            place_volume("VineCeilingRoots_Mars_PCG", (4800.0, 500.0, 170.0), (760.0, 560.0, 320.0), "CeilingRoots_Ossuary").get_name(),
        ]
    unreal.EditorLoadingAndSavingUtils.save_current_level()
    return made


GYM_SHOTS = {
    "atrium_wide": ((800.0, 1580.0, 260.0), (800.0, 600.0, 520.0), 85.0),
    "rail_close": ((900.0, 1000.0, 520.0), (700.0, 420.0, 380.0), 60.0),
    "root_base": ((1000.0, 1350.0, 160.0), (800.0, 1000.0, 60.0), 70.0),
    "hero_full": ((1250.0, 1550.0, 500.0), (700.0, 900.0, 520.0), 80.0),
    "sewer_pipe": ((2400.0, 700.0, 180.0), (2400.0, 60.0, 130.0), 70.0),
    "cistern_moss": ((3600.0, 780.0, 150.0), (3500.0, 300.0, 380.0), 75.0),
    "ossuary_rootlets": ((4800.0, 780.0, 160.0), (4750.0, 200.0, 180.0), 75.0),
}


def capture_review(out_dir, names=None, size=(1600, 1000), exposure_bias=None):
    """The gym's review shots (run as its own call after build_gym_map: reflection captures and PCG need a tick)."""
    shots = {k: v for k, v in GYM_SHOTS.items() if not names or k in names}
    return _capture(out_dir, shots, size, exposure_bias)


def luminance_check(png, mask_rgb=None):
    """Host side: share of pixels darker than 0.02 linear luminance (the leaf floor check reads the leaf-mask region the
    caller crops; without a crop it reports the whole frame)."""
    from PIL import Image
    import numpy as np
    a = np.asarray(Image.open(png).convert("RGB"), float) / 255.0
    lin = np.where(a <= 0.04045, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)
    lum = lin @ np.array([0.2126, 0.7152, 0.0722])
    return float((lum < 0.02).mean())


def check_pcg_graphs():
    """Re-reads every graph: node count per settings class, unique seeds, the template actor of each Spawn Actor node,
    the mesh entries and packer selectors of each spawner. Prints VINE_PCG_OK or VINE_PCG_FAIL."""
    _pcg()
    report, fails = {}, []
    expect = {"VineCurtain_Mars_PCG": ("PCGSpawnActorSettings", "PCGVolumeSamplerSettings", "PCGWorldRaycastElementSettings"),
              "VineCeilingRoots_Mars_PCG": ("PCGSpawnActorSettings", "PCGMetadataMathsSettings", "PCGCopyAttributesSettings"),
              "VineUnderside_Mars_PCG": ("PCGStaticMeshSpawnerSettings", "PCGMetadataMakeVectorSettings"),
              "VineSkirt_Mars_PCG": ("PCGStaticMeshSpawnerSettings", "PCGRandomChoiceSettings")}
    for name, classes in expect.items():
        g = _load("%s/%s" % (PCG_FOLDER, name))
        if g is None:
            fails.append("%s missing" % name)
            continue
        nodes = list(g.get_editor_property("nodes"))
        settings = [n.get_settings() for n in nodes]
        kinds = {}
        seeds = []
        for s in settings:
            if s is None:
                continue
            kinds[s.get_class().get_name()] = kinds.get(s.get_class().get_name(), 0) + 1
            seeds.append(s.get_editor_property("seed"))
        if len(seeds) != len(set(seeds)):
            fails.append("%s: duplicate node seeds" % name)
        for c in classes:
            if c not in kinds:
                fails.append("%s: no %s node" % (name, c))
        for s in settings:
            if isinstance(s, unreal.PCGSpawnActorSettings):
                t = s.get_editor_property("template_actor")
                if t is None or t.get_editor_property("Profile") is None:
                    fails.append("%s: spawn node without a template profile" % name)
                if s.get_editor_property("warn_on_identical_spawn"):
                    fails.append("%s: warn_on_identical_spawn is on" % name)
            if isinstance(s, unreal.PCGStaticMeshSpawnerSettings):
                entries = s.get_editor_property("mesh_selector_parameters").get_editor_property("mesh_entries")
                sels = s.get_editor_property("instance_data_packer_parameters").get_editor_property("attribute_selectors")
                if not entries:
                    fails.append("%s: a spawner without meshes" % name)
                if len(sels) != 4:
                    fails.append("%s: a packer with %d selectors (want 4)" % (name, len(sels)))
                if any("@Last" in x.export_text() for x in sels):
                    fails.append("%s: a packer selector left at @Last" % name)
        report[name] = {"nodes": len(nodes), "classes": kinds}
    print("VINE_PCG_FAIL %s" % fails if fails else "VINE_PCG_OK")
    return {"report": report, "fails": fails}


def run_all():
    build_instances()
    seed_profiles(True)
    graphs = build_pcg_graphs()
    check = check_pcg_graphs()
    gym = build_gym_map()
    return {"graphs": graphs, "check": check["fails"], "gym": gym}
