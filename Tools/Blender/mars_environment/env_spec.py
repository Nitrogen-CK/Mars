"""Shared contract for the Mars ENVIRONMENT DRESSING kit: the concept-art props (ossuary bones, crypt stone furniture,
sewer pipes and grates, cloth / clutter / lights, organic dressing) plus the meshes the vine and drip tools consume.
Read by every family builder (build_env_*.py), by env_common.py and by the Unreal importer (unreal/mars_env_ue.py), so
names, sizes, pivots, slots, sockets and folders agree across meshes built by different agents.

Spaces: builders work in CENTIMETRES, Z up; env_common turns cm into Blender metres on object creation.
Unreal local = (x, -y, z) cm (the FBX export mirrors Y). Same as the cooking station props.

Style ruling (the six concept frames, 2026-10-19, and Stephen's station ruling 2026-10-06/07): the crypt kit look -
chunky faceted low-poly, hand-cut irregularity (no perfect symmetry, jittered facets), flat shading, no smooth groups,
colour painted per facet into vertex colours (food_common.paint). Stone surfaces wear the kit's world-aligned biome
stone (EnvStone slot) so a prop and the wall behind it share one texture. No new textures on props. Breakup is in the
Unreal masters (per-instance hue / value jitter, world-space grime and moss on top faces, wetness), never baked per mesh.

Pivot rules (match the crypt kit so props snap next to kit pieces):
  floor props       XY centre of the footprint, z = 0 on the floor (flat underside)
  wall props        back plane at Blender y = 0, the prop protrudes toward Blender -y (= Unreal +Y), x centred, z = 0 at
                    its lowest point unless the entry says otherwise (sconces: z = 0 at the wall mount point)
  hanging props     the hang point, mesh toward -Z
  long props        along +X (pipes, femurs, roots), pivot at the start (pipes) or centre (bones) as the entry says
"""
import os

# ---------------------------------------------------------------- locations (off-repo source art, like the cooking sets)
SOURCE_DIR = r"D:\Repo\Content\Environment\Dressing"
BLEND_DIR = SOURCE_DIR                                       # one .blend per family, written only by its builder
EXPORT_DIR = os.path.join(SOURCE_DIR, "export")              # FBX + JSON sidecar per mesh, flat
REVIEW_DIR = os.path.join(EXPORT_DIR, "review")              # contact sheets (workbench renders)

UE_ROOT = "/Game/Mars/Environment/Dressing"
UE_MATERIALS = UE_ROOT + "/Materials"                        # masters
UE_INSTANCES = UE_MATERIALS + "/Instances"                   # <Slot>_Mars_MI
UE_TEXTURES = UE_ROOT + "/Textures"


def ue_mesh_folder(family):
    """/Game/Mars/Environment/Dressing/Meshes/<Family>"""
    return UE_ROOT + "/Meshes/" + FAMILIES[family][0]


# family key -> (Unreal folder name, .blend file, builder script)
FAMILIES = {
    "bones": ("Bones", "Dressing_Bones.blend", "build_env_bones.py"),
    "crypt": ("Crypt", "Dressing_Crypt.blend", "build_env_crypt.py"),
    "pipes": ("Pipes", "Dressing_Pipes.blend", "build_env_pipes.py"),
    "clutter": ("Clutter", "Dressing_Clutter.blend", "build_env_clutter.py"),
    "organic": ("Organic", "Dressing_Organic.blend", "build_env_organic.py"),
    "vines": ("Vines", "Dressing_Vines.blend", "build_env_vines.py"),
    "water": ("Water", "Dressing_Water.blend", "build_env_water.py"),
}

# ---------------------------------------------------------------- naming
# mesh      <Name>_Mars_SM, one FBX per mesh in EXPORT_DIR, sidecar <Name>_Mars_SM.json beside it
# sockets   empties SOCKET_<Name> parented to the mesh (env_common.add_socket), exported + written into the sidecar
# collision UCX_<MeshName>_<NN> convex children (env_common.add_ucx). Scatter and small dressing (bones, skulls,
#           leaves, moss, candles, cards) carry NO UCX: the importer gives them no collision.
# material  each slot below becomes <Slot>_Mars_MI in UE_INSTANCES (slot names are prefixed Env so they never bind to
#           the cooking set's Stone_Mars_MI / Wood_Mars_MI / Iron_Mars_MI instances by the nearest-folder rule)

# slot -> (Unreal master, base colour sRGB for the vertex paint, note)
SLOT_TABLE = {
    "EnvStone": ("world-aligned biome stone (child of StoneWall_<Biome>_Mars_MI)", (120, 112, 104),
                 "carved / masonry stone: the texture, paint wash and biome come from the kit wall set (the vertex colour "
                 "is NOT read by that master, so tone changes need the EnvStoneDark slot)"),
    "EnvStoneDark": ("world-aligned biome stone, darker (child of StoneWall_<Biome>_Mars_MI, Tint ~0.55)", (84, 78, 74),
                     "the dark stone of inlays, medallion rings, recess backs, soot-blackened faces"),
    "EnvBone": ("EnvPaint_Mars_M", (198, 176, 134), "skulls, bones; warm ivory, ochre in crevices"),
    "EnvWood": ("EnvPaint_Mars_M", (112, 76, 46), "planks, shelves, poles, crates"),
    "EnvIron": ("EnvPaint_Mars_M", (52, 50, 56), "wrought iron: bars, grates, brackets, lantern cages, bolts"),
    "EnvRust": ("EnvPaint_Mars_M", (118, 62, 36), "rusted iron: pipes, flanges, valve wheels"),
    "EnvBrass": ("EnvPaint_Mars_M", (150, 112, 54), "aged brass / bronze fittings"),
    "EnvCanvas": ("EnvPaint_Mars_M", (170, 148, 108), "sacks, rope, rags"),
    "EnvCloth": ("EnvPaint_Mars_M", (136, 30, 30), "red banners, drapes"),
    "EnvGold": ("EnvPaint_Mars_M", (198, 152, 60), "banner emblems, gilt trim"),
    "EnvWax": ("EnvPaint_Mars_M", (232, 220, 190), "candle wax, drips over ledges (use the candle set for lit candles)"),
    "EnvBark": ("EnvPaint_Mars_M", (82, 58, 38), "roots, vine stems, branches"),
    "EnvMoss": ("EnvPaint_Mars_M", (80, 96, 46), "moss pads, drapes"),
    "EnvLeaf": ("EnvFoliage_Mars_M", (44, 66, 34), "ivy leaves (two-sided, wind)"),
    "EnvLeafDry": ("EnvFoliage_Mars_M", (128, 74, 36), "dead leaves, dry ivy"),
    "EnvStrand": ("EnvFoliage_Mars_M", (70, 82, 44), "hanging moss strands, rootlets, cobwebs (two-sided, wind, length sway)"),
    "EnvGlowWarm": ("Emissive_Mars_M", (255, 184, 104), "lantern cores, braziers (emissive, Strength ~8)"),
    "EnvGlowSpirit": ("Emissive_Mars_M", (90, 170, 255), "blue spirit lanterns, sigil inlays, spirit candles"),
    "EnvFlame": ("CandleFlame_Mars_M (candle_gen flame UV1 contract)", (255, 160, 70),
                 "torch / brazier flames; follow candle_gen's Flame contract (UV1 u = id, v = height) so it flickers"),
}
SLOTS = tuple(SLOT_TABLE)

# variant colours for per-facet painting (sRGB); builders mix these with the slot base for hand-painted variation
PALETTE_SRGB = {slot: row[1] for slot, row in SLOT_TABLE.items()}
PALETTE_SRGB.update({
    "EnvBoneDark": (138, 112, 76),     # crevices, eye sockets' rims, old stained bone
    "EnvBoneLight": (226, 210, 172),   # brow ridges, top faces catching candle light
    "EnvWoodDark": (72, 48, 30),
    "EnvIronLight": (92, 88, 90),      # worn edges
    "EnvRustDark": (72, 40, 28),       # pitting, undersides
    "EnvRustOrange": (164, 88, 40),    # fresh flaking rust
    "EnvClothDark": (88, 20, 22),      # folds
    "EnvLeafLight": (74, 98, 46),
    "EnvLeafDark": (28, 42, 24),
    "EnvBarkDark": (52, 36, 24),
    "EnvMossDark": (52, 64, 32),
})

# ---------------------------------------------------------------- vertex data contract
# "Col"   corner colours, LINEAR RGB = albedo painted per facet; A = cavity / AO (1 open, 0 deep crevice)
# UV0     "UVMap" smart UV (kept for tools; the masters do not need it)
# UV1     optional "EnvData" (written with env_common.write_data_uv): u = per-piece random id 0..1 (a leaf cluster, a
#         moss strand, a bone in a pile), v as UNREAL reads it = flex weight 0 at the attachment, 1 at the free tip (the
#         foliage wind and drip / sway WPO read it). Blender stores v as 1 - value (the FBX -> Unreal V flip).
DATA_UV = "EnvData"

# Triangle budgets (max). Instanced scatter must stay small; hero furniture can be richer.
TRIS = {
    "scatter": 400,       # one skull, one bone, one leaf cluster, a rubble chunk
    "cluster": 2500,      # bone pile, skull stack, leaf pile, candle-ledge drip, sack
    "prop": 4000,         # urn, lantern, sconce, banner, valve, grate, pipe fitting
    "furniture": 9000,    # sarcophagus, ossuary shelf, statue, sigil door, portcullis
}
