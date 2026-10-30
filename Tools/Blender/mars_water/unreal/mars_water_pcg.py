"""PCG volume graphs for the Mars drips (DRIPS_PLAN §6, decision D1: PCG stays LOCAL-ONLY, so the only host is the
engine's stock APCGVolume and no AngelScript names a PCG type). Editor Python only.

    import sys, importlib
    sys.path.insert(0, r"D:\\Repo\\Mars\\Tools\\Blender\\mars_water\\unreal")
    import mars_water_pcg as wp; importlib.reload(wp)
    wp.build_all()                                   # DripVolume_{Cistern,Sewer,Ossuary,Atrium}_Mars_PCG, rebuilt IN PLACE
    wp.verify(wp.graph("Cistern"))                   # WATER_PCG_OK
    wp.place_volume((x, y, z), (ex, ey, ez), "Cistern")   # a stock PCG volume, GenerateOnDemand, generated
    wp.audit_pcg_hosts()                             # every PCG component in the open map is GenerateOnDemand

Graph (one per preset, numbers from water_spec.VOLUME_PRESETS baked in; graph user parameters cannot be created from
script):

    Input.In -> VolumeSampler (Spacing, Spacing, 100) -> Jitter -> $Density roll -> DensityFilter (coverage)
      -> RayUp (+Z 3000, unbounded, WorldStatic object type, complex, normals) -> Filter ImpactNormal.Z <= -0.35
      -> Source (rotation reset, -1 cm) -> Bounds +-18 -> SelfPruning (one strand per column)
      -> DripRate / DripSeed (attribute noise), DripJitter / DropScale / DripMode (constants; a ThreadRoll split sets
         DripMode 1 on ThreadChance of the strands)
      -> RayDown (-Z 4000, unbounded, distance + normal + physical material) -> Filter ImpactDistance >= MinLength
      -> lift 1 cm -> 3 cm rays requiring / excluding actor tag Mars.Water (W | rest; the physical material reads back
         null in editor-world queries) -> Filter ImpactNormal.Z >= 0.7 (Gf floor | Gd dry)
      -> DripSurface 1 / 0 / 2, RingAmp P / P / 0 -> Merge = I
    6 slot points (Seed 0..5) -CopyPoints-> every I (rotation / scale / seed from the slot point, attributes merged)
      -> $Scale.Z = ImpactDistance / 100 -> Drops spawner (DropletCard + Droplet_Mars_MI, PICD packer
         [ImpactDistance, DripRate, DripSeed, DripJitter, DripMode, $Seed, DropScale, DripSurface])
    Gf -> +1 cm along the normal, random yaw, scale 0.6 -> Rings spawner (DripImpact_Mars_MI mesh decal, packer 0..5)
    W  -> +0.3 cm, random yaw, scale 0.6 -> WaterRings spawner (DripRingCard_Mars_MI translucent card: Single Layer
          Water takes no DBuffer decals)
    Gf -> PuddleRoll < chance -> PuddleSeed / PuddleAspect / PuddleWetness / RainRate -> +1.5 cm, yaw, scale
       [min, max] -> Bounds 50 -> SelfPruning (no overlaps) -> PuddleWet + PuddleGloss spawners (same points)

Deviations from the plan's node table: coverage is a uniform per-point $Density roll, not Perlin2D spatial noise
(the noise left small volumes empty: no strand at all in a 4 x 8 m sewer bay); the rate is uniform in [RateMin, RateMax] (no Exp in the metadata maths ops),
DripSlot is the slot point's $Seed (seed inheritance from the source), the ambient-puddle branch and the
Mars.DripBlocker exclusion are not built.
"""
import os
import sys

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
WATER_DIR = os.path.dirname(HERE)
for _p in (HERE, WATER_DIR):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import water_spec as spec  # noqa: E402

EAL = unreal.EditorAssetLibrary
NOBAKE = "Ck.Jolt.NoBake"


def _log(msg):
    unreal.log("MarsWaterPCG: %s" % msg)


def graph(preset):
    return EAL.load_asset("%s/%s" % (spec.F_PCG, spec.graph_name(preset)))


def _sel(text, output=False):
    s = unreal.PCGAttributePropertyOutputSelector() if output else unreal.PCGAttributePropertyInputSelector()
    s.import_text("PCGBegin(%s)PCGEnd" % text)
    got = s.export_text()
    assert text.lstrip("$").split(".")[0] in got, "selector %r read back as %r" % (text, got)
    return s


def _const(kind, value):
    c = unreal.PCGMetadataTypesConstantStruct()
    c.set_editor_property("type", getattr(unreal.PCGMetadataTypes, kind))
    c.set_editor_property({"DOUBLE": "double_value", "SOFT_OBJECT_PATH": "soft_object_path_value"}[kind], value)
    return c


class _Builder:
    def __init__(self, g):
        self.g = g
        self.col, self.row = 0, 0
        self.edges = []

    def node(self, cls, title=None, col=None, **props):
        n, s = self.g.add_node_of_type(cls)
        for k, v in props.items():
            s.set_editor_property(k, v)
        if col is not None:
            self.col = col
        self.row += 1
        try:
            n.set_node_position(self.col * 360, self.row * 140)
        except Exception:
            pass
        if title:
            try:
                n.set_editor_property("node_title", unreal.Name(title))
            except Exception:
                pass
        return n, s

    def edge(self, a, a_pin, b, b_pin):
        self.g.add_edge(a, a_pin, b, b_pin)
        self.edges.append((a, a_pin, b, b_pin))
        return b

    def chain(self, src, src_pin, nodes):
        """Wires src -> nodes[0] -> nodes[1] ... through Out/In; returns the last node."""
        prev, pin = src, src_pin
        for n in nodes:
            self.edge(prev, pin, n, "In")
            prev, pin = n, "Out"
        return prev

    # ---- node helpers
    def noise(self, attr, lo, hi):
        n, s = self.node(unreal.PCGAttributeNoiseSettings, "Noise " + attr)
        s.set_editor_property("input_source", _sel("$Density"))
        s.set_editor_property("output_target", _sel(attr, True))
        s.set_editor_property("noise_min", lo)
        s.set_editor_property("noise_max", hi)
        return n

    def add_attr(self, attr, value):
        n, s = self.node(unreal.PCGAddAttributeSettings, "%s = %g" % (attr, value))
        s.set_editor_property("output_target", _sel(attr, True))
        s.set_editor_property("attribute_types", _const("DOUBLE", float(value)))
        return n

    def filt(self, attr, op, kind, value, title):
        n, s = self.node(unreal.PCGAttributeFilteringSettings, title)
        s.set_editor_property("operator", getattr(unreal.PCGAttributeFilterOperator, op))
        s.set_editor_property("target_attribute", _sel(attr))
        s.set_editor_property("use_constant_threshold", True)
        s.set_editor_property("attribute_types", _const(kind, value))
        s.set_editor_property("warn_on_data_missing_attribute", False)
        return n

    def ray(self, direction, length, title, down, tags=None):
        n, s = self.node(unreal.PCGWorldRaycastElementSettings, title)
        s.set_editor_property("raycast_mode", unreal.PCGWorldRaycastMode.NORMALIZED_WITH_LENGTH)
        s.set_editor_property("ray_direction", unreal.Vector(*direction))
        s.set_editor_property("ray_length", float(length))
        s.set_editor_property("unbounded", True)
        s.set_editor_property("keep_original_point_on_miss", False)
        q = s.get_editor_property("world_query_params")
        q.set_editor_property("collision_channel", unreal.CollisionChannel.ECC_WORLD_STATIC)
        q.set_editor_property("trace_complex", True)
        q.set_editor_property("ignore_pcg_hits", True)
        q.set_editor_property("get_impact_normal", True)
        if down:
            q.set_editor_property("get_distance", True)
            q.set_editor_property("get_reference_to_physical_material", True)
        if tags:
            q.set_editor_property("actor_tag_filter", getattr(unreal.PCGWorldQueryFilter, tags[0]))
            q.set_editor_property("actor_tags_list", tags[1])
        s.set_editor_property("world_query_params", q)
        return n

    def transform(self, title, offset=(0, 0, 0), absolute_offset=False, yaw=(0.0, 0.0), absolute_rotation=False,
                  scale=None):
        n, s = self.node(unreal.PCGTransformPointsSettings, title)
        s.set_editor_property("offset_min", unreal.Vector(*offset))
        s.set_editor_property("offset_max", unreal.Vector(*offset))
        s.set_editor_property("absolute_offset", absolute_offset)
        s.set_editor_property("rotation_min", unreal.Rotator(roll=0.0, pitch=0.0, yaw=yaw[0]))
        s.set_editor_property("rotation_max", unreal.Rotator(roll=0.0, pitch=0.0, yaw=yaw[1]))
        s.set_editor_property("absolute_rotation", absolute_rotation)
        if scale is not None:
            lo, hi = scale
            s.set_editor_property("scale_min", unreal.Vector(*lo))
            s.set_editor_property("scale_max", unreal.Vector(*hi))
            s.set_editor_property("absolute_scale", True)
            s.set_editor_property("uniform_scale", lo[0] != hi[0])
        return n

    def prune(self, half_extent, title):
        b, bs = self.node(unreal.PCGBoundsModifierSettings, "Bounds +-%g" % half_extent)
        bs.set_editor_property("mode", unreal.PCGBoundsModifierMode.SET)
        bs.set_editor_property("bounds_min", unreal.Vector(-half_extent, -half_extent, -half_extent))
        bs.set_editor_property("bounds_max", unreal.Vector(half_extent, half_extent, half_extent))
        p, ps = self.node(unreal.PCGSelfPruningSettings, title)
        params = ps.get_editor_property("parameters")
        params.set_editor_property("pruning_type", unreal.PCGSelfPruningType.LARGE_TO_SMALL)
        params.set_editor_property("randomized_pruning", True)
        ps.set_editor_property("parameters", params)
        self.edge(b, "Out", p, "In")
        return b, p

    def spawner(self, title, mesh, material, packer, cull, sort=0):
        n, s = self.node(unreal.PCGStaticMeshSpawnerSettings, title)
        s.set_mesh_selector_type(unreal.PCGMeshSelectorWeighted)
        s.set_instance_packer_type(unreal.PCGInstanceDataPackerByAttribute)
        sel = s.get_editor_property("mesh_selector_parameters")
        entry = unreal.PCGMeshSelectorWeightedEntry()
        text = ('(Descriptor=(StaticMesh="{m}",OverrideMaterials=("{mat}"),ComponentTags=("{tag}"),bCastShadow=False,'
                'bCastDynamicShadow=False,bCastStaticShadow=False,bReceivesDecals=False,InstanceEndCullDistance={c},'
                'TranslucencySortPriority={sort}),Weight=1)').format(
            m="%s/%s.%s" % (spec.F_MESH, mesh, mesh), mat="%s/%s.%s" % (spec.F_MAT, material, material), tag=NOBAKE,
            c=int(cull), sort=int(sort))
        entry.import_text(text)
        sel.set_editor_property("mesh_entries", [entry])
        pk = s.get_editor_property("instance_data_packer_parameters")
        pk.set_editor_property("attribute_selectors", [_sel(a) for a in packer])
        return n


def _fresh_graph(name):
    path = "%s/%s" % (spec.F_PCG, name)
    g = EAL.load_asset(path) if EAL.does_asset_exist(path) else None
    if g is None:
        g = unreal.AssetToolsHelpers.get_asset_tools().create_asset(name, spec.F_PCG, unreal.PCGGraph, None)
    keep = (g.get_input_node(), g.get_output_node())
    nodes = [n for n in g.get_editor_property("nodes") if n not in keep]
    for n in nodes:                       # RemoveNodes takes its array by reference: Python sees no argument
        g.remove_node(n)
    return g


def build_graph(preset):
    """DripVolume_<preset>_Mars_PCG, rebuilt in place (volumes keep their reference)."""
    p = spec.VOLUME_PRESETS[preset]
    g = _fresh_graph(spec.graph_name(preset))
    b = _Builder(g)
    sp = p["spacing"]
    inp = g.get_input_node()

    # ---- sources: a grid over the volume, jittered, clustered, hung from the ceiling, one per column
    vs, vss = b.node(unreal.PCGVolumeSamplerSettings, "Grid", col=1, voxel_size=unreal.Vector(sp, sp, 100.0))
    b.edge(inp, "In", vs, "Volume")
    jit = b.transform("Jitter", (0, 0, 0))
    js = jit.get_settings()
    js.set_editor_property("offset_min", unreal.Vector(-0.4 * sp, -0.4 * sp, 0.0))
    js.set_editor_property("offset_max", unreal.Vector(0.4 * sp, 0.4 * sp, 0.0))
    js.set_editor_property("absolute_offset", True)
    # coverage: a uniform per-point roll in $Density (Perlin2D spatial noise left whole small volumes empty)
    sn = b.noise("$Density", 0.0, 1.0)
    df, dfs = b.node(unreal.PCGDensityFilterSettings, "Coverage", lower_bound=1.0 - p["coverage"], upper_bound=1.0)
    up = b.ray((0, 0, 1), 3000, "RayUp", False)
    soffit = b.filt("ImpactNormal.Z", "LESSER_OR_EQUAL", "DOUBLE", -0.35, "Soffits")
    b.chain(vs, "Out", [jit, sn, df])
    b.edge(df, "Out", up, "Origins")
    b.edge(up, "Out", soffit, "In")
    src = b.transform("Source", (0, 0, -1), absolute_offset=True, absolute_rotation=True)
    b.edge(soffit, "InsideFilter", src, "In")
    bnd, pr = b.prune(18.0, "One per column")
    b.edge(src, "Out", bnd, "In")

    # ---- per-strand values
    rate = b.noise("DripRate", p["rate"][0], p["rate"][1])
    seed = b.noise("DripSeed", 0.0, 1.0)
    jit_a = b.add_attr("DripJitter", p["jitter"])
    scale_a = b.add_attr("DropScale", 1.0)
    last = b.chain(pr, "Out", [rate, seed, jit_a, scale_a])
    if p["thread"] > 0.0:
        roll = b.noise("ThreadRoll", 0.0, 1.0)
        b.edge(last, "Out", roll, "In")
        split = b.filt("ThreadRoll", "LESSER", "DOUBLE", p["thread"], "Thread?")
        b.edge(roll, "Out", split, "In")
        m1, m0 = b.add_attr("DripMode", 1.0), b.add_attr("DripMode", 0.0)
        b.edge(split, "InsideFilter", m1, "In")
        b.edge(split, "OutsideFilter", m0, "In")
        mm, _ = b.node(unreal.PCGMergeSettings, "Modes")
        b.edge(m1, "Out", mm, "In")
        b.edge(m0, "Out", mm, "In")
        strands = mm
    else:
        strands = b.add_attr("DripMode", 0.0)
        b.edge(last, "Out", strands, "In")

    # ---- impacts
    down = b.ray((0, 0, -1), 4000, "RayDown", True)
    b.edge(strands, "Out", down, "Origins")
    longf = b.filt("ImpactDistance", "GREATER_OR_EQUAL", "DOUBLE", p["min_length"], "Long enough")
    b.edge(down, "Out", longf, "In")
    # water or not: the hit's physical material reads back null in editor-world queries (overrides on box and mesh
    # components alike), so two 3 cm probe rays from 1 cm above each impact split the impacts by actor tag: one that
    # requires Mars.Water (still-water probes) and one that excludes it
    lift = b.transform("Lift 1 cm", (0, 0, 1.0), absolute_offset=True)
    b.edge(longf, "InsideFilter", lift, "In")
    water = b.ray((0, 0, -1), 3.0, "IsWater", False, ("REQUIRE", "Mars.Water"))
    other = b.ray((0, 0, -1), 3.0, "NotWater", False, ("EXCLUDE", "Mars.Water"))
    b.edge(lift, "Out", water, "Origins")
    b.edge(lift, "Out", other, "Origins")
    floor = b.filt("ImpactNormal.Z", "GREATER_OR_EQUAL", "DOUBLE", 0.7, "IsFloor")
    b.edge(other, "Out", floor, "In")
    s_w = b.chain(water, "Out", [b.add_attr("DripSurface", 1.0), b.add_attr("RingAmp", p["ring_amp"])])
    s_f = b.chain(floor, "InsideFilter", [b.add_attr("DripSurface", 0.0), b.add_attr("RingAmp", p["ring_amp"])])
    s_d = b.chain(floor, "OutsideFilter", [b.add_attr("DripSurface", 2.0), b.add_attr("RingAmp", 0.0)])
    impacts, _ = b.node(unreal.PCGMergeSettings, "Impacts", col=6)
    for s_ in (s_w, s_f, s_d):
        b.edge(s_, "Out", impacts, "In")

    # ---- drop cards: 6 slot points copied onto every impact
    cp, cps = b.node(unreal.PCGCreatePointsSettings, "6 slots", col=7)
    pts = []
    for i in range(6):
        pt = unreal.PCGPoint()
        pt.set_editor_property("seed", i)
        pts.append(pt)
    cps.set_editor_property("points_to_create", pts)
    cpy, cpys = b.node(unreal.PCGCopyPointsSettings, "Cards per strand")
    for prop in ("rotation_inheritance", "scale_inheritance", "seed_inheritance"):
        cpys.set_editor_property(prop, unreal.PCGCopyPointsInheritanceMode.SOURCE)
    cpys.set_editor_property("attribute_inheritance", unreal.PCGCopyPointsMetadataInheritanceMode.SOURCE_FIRST)
    b.edge(cp, "Out", cpy, "Source")
    b.edge(impacts, "Out", cpy, "Target")
    hundred = b.add_attr("Hundredth", 0.01)
    b.edge(cpy, "Out", hundred, "In")
    sz, szs = b.node(unreal.PCGMetadataMathsSettings, "Scale.Z = fall / 100")
    szs.set_editor_property("operation", unreal.PCGMetadataMathsOperation.MULTIPLY)
    szs.set_editor_property("input_source1", _sel("ImpactDistance"))
    szs.set_editor_property("input_source2", _sel("Hundredth"))
    szs.set_editor_property("output_target", _sel("$Scale.Z", True))
    b.edge(hundred, "Out", sz, "InA")
    b.edge(hundred, "Out", sz, "InB")
    drops = b.spawner("Drops", "DropletCard_Mars_SM", "Droplet_Mars_MI",
                      spec.PACK_CARD[:5] + ("$Seed",) + spec.PACK_CARD[6:], 4000)
    b.edge(sz, "Out", drops, "In")

    # ---- rings: mesh decals on floors, translucent ring cards on water (Single Layer Water takes no decals)
    rt = b.transform("Ring pose", (0, 0, 1.0), yaw=(0.0, 360.0), scale=((0.6, 0.6, 1.0), (0.6, 0.6, 1.0)))
    b.edge(s_f, "Out", rt, "In")
    rings = b.spawner("Rings", "WetDecalCard_Mars_SM", "DripImpact_Mars_MI", spec.PACK_RING, 2500, sort=2)
    b.edge(rt, "Out", rings, "In")
    wrt = b.transform("Water ring pose", (0, 0, 0.3), absolute_offset=True, yaw=(0.0, 360.0),
                      scale=((0.6, 0.6, 1.0), (0.6, 0.6, 1.0)))
    b.edge(s_w, "Out", wrt, "In")
    wrings = b.spawner("WaterRings", "WetDecalCard_Mars_SM", "DripRingCard_Mars_MI", spec.PACK_RING, 2500, sort=1)
    b.edge(wrt, "Out", wrings, "In")

    # ---- puddles on the floor impacts
    proll = b.noise("PuddleRoll", 0.0, 1.0)
    b.edge(s_f, "Out", proll, "In")
    pf = b.filt("PuddleRoll", "LESSER", "DOUBLE", p["puddle_chance"], "Puddle?")
    b.edge(proll, "Out", pf, "In")
    pchain = [b.noise("PuddleSeed", 0.0, 1.0), b.noise("PuddleAspect", 0.0, 1.0),
              b.noise("PuddleWetness", p["wetness"][0], p["wetness"][1]), b.add_attr("RainRate", p["rain"])]
    plast = b.chain(pf, "InsideFilter", pchain)
    s0, s1 = p["puddle_scale"]
    ppose = b.transform("Puddle pose", (0, 0, 1.5), yaw=(0.0, 360.0), scale=((s0, s0, 1.0), (s1, s1, 1.0)))
    b.edge(plast, "Out", ppose, "In")
    pb, pp = b.prune(50.0, "No overlaps")
    b.edge(ppose, "Out", pb, "In")
    pw = b.spawner("PuddleWet", "WetDecalCard_Mars_SM", "PuddleWet_Mars_MI", spec.PACK_PUDDLE, 6000, sort=0)
    pg = b.spawner("PuddleGloss", "WetDecalCard_Mars_SM", "PuddleGloss_Mars_MI", spec.PACK_PUDDLE, 6000, sort=1)
    b.edge(pp, "Out", pw, "In")
    b.edge(pp, "Out", pg, "In")
    try:
        g.force_notification_for_editor()
    except Exception:
        pass
    EAL.save_loaded_asset(g)
    return {"graph": g.get_path_name(), "nodes": len(g.get_editor_property("nodes")), "edges": len(b.edges)}


def build_all():
    return {k: build_graph(k) for k in spec.VOLUME_PRESETS}


# ------------------------------------------------------------------ checks
def verify(g):
    """Reloads nothing (the graph object is the asset); asserts the contract and prints WATER_PCG_OK."""
    errors = []
    spawners = {}
    rays = []
    for n in g.get_editor_property("nodes"):
        s = n.get_settings()
        if isinstance(s, unreal.PCGStaticMeshSpawnerSettings):
            spawners[str(n.get_editor_property("node_title"))] = s
        if isinstance(s, unreal.PCGWorldRaycastElementSettings):
            rays.append(s)
    want = {"Drops": spec.PACK_CARD[:5] + ("$Seed",) + spec.PACK_CARD[6:], "Rings": spec.PACK_RING,
            "WaterRings": spec.PACK_RING,
            "PuddleWet": spec.PACK_PUDDLE, "PuddleGloss": spec.PACK_PUDDLE}
    for title, order in want.items():
        s = spawners.get(title)
        if s is None:
            errors.append("no %s spawner" % title)
            continue
        sels = s.get_editor_property("instance_data_packer_parameters").get_editor_property("attribute_selectors")
        got = tuple(x.export_text() for x in sels)
        if len(got) != len(order) or any(o.lstrip("$") not in x for o, x in zip(order, got)):
            errors.append("%s packer %s != %s" % (title, got, order))
        entry = s.get_editor_property("mesh_selector_parameters").get_editor_property("mesh_entries")[0]
        text = entry.export_text()
        if NOBAKE not in text:
            errors.append("%s descriptor lacks %s" % (title, NOBAKE))
        if "bCastShadow=False" not in text:
            errors.append("%s descriptor casts shadows" % title)
    if len(rays) != 4:
        errors.append("expected 4 raycasts (up, down, water / not water), got %d" % len(rays))
    for r in rays:
        q = r.get_editor_property("world_query_params")
        if not r.get_editor_property("unbounded"):
            errors.append("a raycast is bounded")
        if q.get_editor_property("collision_channel") != unreal.CollisionChannel.ECC_WORLD_STATIC:
            errors.append("a raycast is not on WorldStatic")
        if not q.get_editor_property("get_impact_normal"):
            errors.append("a raycast drops the impact normal")
    out = {"spawners": sorted(spawners), "rays": len(rays), "errors": errors}
    if not errors:
        print("WATER_PCG_OK", g.get_name())
    return out


def place_volume(centre, extent, preset, label=None, folder="WaterLookdev/PCG", generate=True):
    """A stock APCGVolume with the preset graph, GenerateOnDemand (never GenerateOnLoad), generated now."""
    eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
    label = label or "DripVolume_%s" % preset
    for a in eas.get_all_level_actors():
        if a.get_actor_label() == label:
            eas.destroy_actor(a)
    g = graph(preset)
    vol = unreal.EditorLevelLibrary.spawn_actor_from_object(g, unreal.Vector(*centre))
    if vol is None or not isinstance(vol, unreal.PCGVolume):
        if vol is not None:
            eas.destroy_actor(vol)
        vol = eas.spawn_actor_from_class(unreal.PCGVolume, unreal.Vector(*centre))
    vol.set_actor_label(label)
    vol.set_folder_path(folder)
    vol.set_actor_scale3d(unreal.Vector(extent[0] / 100.0, extent[1] / 100.0, extent[2] / 100.0))
    comp = vol.get_editor_property("pcg_component")
    comp.set_graph(g)
    comp.set_editor_property("generation_trigger", unreal.PCGComponentGenerationTrigger.GENERATE_ON_DEMAND)
    if generate:
        comp.generate_local(True)
    return {"label": label, "graph": g.get_name(), "trigger": str(comp.get_editor_property("generation_trigger"))}


def generated(label):
    """Instance counts of every ISM the volume's PCG component generated (call after a tick or two)."""
    eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
    for a in eas.get_all_level_actors():
        if a.get_actor_label() == label:
            out = {}
            for c in a.get_components_by_class(unreal.InstancedStaticMeshComponent):
                mesh = c.get_editor_property("static_mesh")
                mats = c.get_materials()
                key = "%s/%s" % (mesh.get_name() if mesh else None, mats[0].get_name() if mats and mats[0] else None)
                out[key] = out.get(key, 0) + c.get_instance_count()
                out.setdefault("_tags", sorted(set(str(t) for t in c.component_tags)))
                out.setdefault("_collision", str(c.get_collision_enabled()))
                out.setdefault("_custom_floats", c.get_editor_property("num_custom_data_floats"))
            comp = a.get_editor_property("pcg_component")
            out["_generated"] = comp.get_editor_property("generated") if hasattr(comp, "get_editor_property") else None
            return out
    return None


def audit_pcg_hosts():
    """Every PCG component in the open map must be GenerateOnDemand (the default GenerateOnLoad would regenerate on
    every load)."""
    eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
    bad, n = [], 0
    for a in eas.get_all_level_actors():
        for c in a.get_components_by_class(unreal.PCGComponent):
            n += 1
            if c.get_editor_property("generation_trigger") != unreal.PCGComponentGenerationTrigger.GENERATE_ON_DEMAND:
                bad.append(a.get_actor_label())
    return {"components": n, "not_on_demand": bad}


def snapshot(label):
    """{material: [instance locations rounded to 0.1 cm]} of a volume's generated ISMs."""
    eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
    for a in eas.get_all_level_actors():
        if a.get_actor_label() == label:
            out = {}
            for c in a.get_components_by_class(unreal.InstancedStaticMeshComponent):
                mats = c.get_materials()
                key = mats[0].get_name() if mats and mats[0] else "?"
                locs = []
                for i in range(c.get_instance_count()):
                    t = c.get_instance_transform(i, True).translation
                    locs.append((round(t.x, 1), round(t.y, 1), round(t.z, 1)))
                out.setdefault(key, []).extend(locs)
            return {k: sorted(v) for k, v in out.items()}
    return None


def regenerate(label):
    eas = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
    for a in eas.get_all_level_actors():
        if a.get_actor_label() == label:
            comp = a.get_editor_property("pcg_component")
            comp.cleanup_local(True)
            comp.generate_local(True)
            return True
    return False
