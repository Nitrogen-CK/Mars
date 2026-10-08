"""Shared contract for the Mars food library (the roster under Content/Cooking/food). Read by every Blender builder
(build_food_*.py), the texture / VAT bakers and the Unreal importer, so names, sizes, pivots, UV channels, vertex
colours and export settings agree across categories built by different people / agents.

Spaces (same as cooking_spec): builders work in CENTIMETRES, Z up; food_common turns cm into Blender metres on
object creation. Unreal local = (100 x, -100 y, 100 z) of Blender metres. FBX export uses the cooking_spec settings
plus triangulation and linear vertex colours.

Style ruling (Stephen, 2026-10-06): faceted low-poly silhouettes that still read as believable food, not
hyper-real. Flat shading (every face flat, no smooth groups), 600..2500 tris per hero ingredient, asymmetry and
hand-cut irregularity in the facets, horns / spikes / scales / leaves as real geometry. Colour is painted per facet
into vertex colours (small per-facet variation, warmer in crevices) and texture maps only add cook masks and fine
skin detail. Meats reuse the sear / penetration cook model of Meat_Mars_M; anything fried shares one oil-coat
material function; salt and pepper are separate stage meshes; the herb pile is one closed mesh for runtime cutting.
"""
import os

import cooking_spec as base

# ---------------------------------------------------------------- locations
SOURCE_DIR = base.SOURCE_DIR                                   # D:\Repo\Content\Cooking (off-repo source art)
BLEND_DIR = os.path.join(SOURCE_DIR, "food")                   # one .blend per category, written only by its builder
EXPORT_DIR = os.path.join(base.EXPORT_DIR, "food")             # FBX + PNG + EXR + JSON sidecars, flat
REVIEW_DIR = os.path.join(EXPORT_DIR, "review")                # contact sheets (workbench renders)

UE_FOLDER = base.UE_FOLDER + "/Food"                           # /Game/Mars/Gameplay/Cooking/Food/{Meshes,Textures,Materials}

# category -> (blend file, builder script). A builder owns its .blend and never opens another category's file.
CATEGORIES = {
    "meats": ("Food_Meats.blend", "build_food_meats.py"),
    "produce": ("Food_Produce.blend", "build_food_produce.py"),
    "mortar": ("Food_Mortar.blend", "build_food_mortar.py"),
    "fryer": ("Food_Fryer.blend", "build_food_fryer.py"),      # batter shell generator + oil VAT
}

# ---------------------------------------------------------------- naming
# mesh         <Name>_Mars_SM            textures  <Name>_Mask_Mars_T (RGBA masks), <Name>_Normal_Mars_T (optional)
# battered     <Name>_Battered_Mars_SM   (ingredient + batter shell, slots Flesh/Skin.. + Batter)
# stage meshes <Name>_<Stage>_Mars_SM    (salt / pepper piles)
# VAT          OilSurface_Mars_SM + OilSurface_VATPos_Mars_T / OilSurface_VATNrm_Mars_T + OilVAT_Mars.json
# sidecar      <Name>_Mars_SM.json next to every FBX (food_common.write_meta): tris, bounds, slots, uv layers, morph


def mesh_name(name, stage=None):
    return "%s_%s_Mars_SM" % (name, stage) if stage else "%s_Mars_SM" % name


# Allowed material slot names. Slots that COOK get the food master (vertex colour base + cook model); the others are
# static accents with their own simple material. Keep a mesh to the fewest slots that read.
SLOTS_COOKING = ("Flesh", "Skin", "Batter")
SLOTS_STATIC = ("Horn", "Bone", "Leaf", "Stem", "Salt", "Pepper", "Stone", "Wood", "Oil")

# ---------------------------------------------------------------- the roster (Stephen 2026-10-06: starter 8 + salt & pepper + herb pile)
# size_cm = longest axis at rest. morph = raw -> cooked shape baked into UV1/UV2 (see MORPH below). fryable = gets a
# battered variant from the fryer generator. Sizes read against the 1 m chef whose held items are ~30 cm.
INGREDIENTS = {
    # meats: the one-mesh, material-driven cook (sear per axis + penetration band) of Meat_Mars_M
    "RoastHorned": dict(category="meats", size_cm=30.0, slots=("Flesh", "Horn"), morph=True, fryable=False,
                        ref="the horned, spiked roast joint (reference 1 / 5): a plump oval body, four to six curved horns, pulled-skin facets"),
    "Drumstick": dict(category="meats", size_cm=22.0, slots=("Flesh", "Bone"), morph=True, fryable=True,
                      ref="a cartoon drumstick (reference 5): fat teardrop of meat, exposed pale bone with a knuckle"),
    "Tentacle": dict(category="meats", size_cm=28.0, slots=("Flesh",), morph=True, fryable=True,
                     ref="a curled purple tentacle (reference 1): tapering spiral with a row of round suckers, tip curling up"),
    "MeatSlab": dict(category="meats", size_cm=36.0, slots=("Flesh", "Skin"), morph=False, fryable=False, cpu_access=True,
                     ref="a large raw joint for the cutting board: a thick loin / brisket slab with a fat cap, chopped into pieces at runtime"),
    # produce: same cook model (the sear ramp browns anything); morph where the reference shows a shape change
    "Puffer": dict(category="produce", size_cm=14.0, slots=("Skin", "Horn"), morph=True, fryable=True,
                   ref="the spiked orange puffer (reference 2): ball with short conical spikes and two bead eyes; morph = puffs up ~15% when fried"),
    "Turnip": dict(category="produce", size_cm=16.0, slots=("Skin", "Leaf"), morph=True, fryable=False,
                   ref="the screaming turnip (reference 3): white-to-magenta root, open mouth with teeth modelled in, leaf crown; morph = wilts / sags when cooked"),
    "SpikedBerry": dict(category="produce", size_cm=10.0, slots=("Skin", "Horn"), morph=False, fryable=True,
                        ref="the purple spiked berry (reference 4): squat sphere with blunt spikes and an open mouth"),
    "TomatoBulb": dict(category="produce", size_cm=12.0, slots=("Skin", "Leaf"), morph=True, fryable=False,
                       ref="the red bulb with fangs (reference 4): lobed tomato body, small leaf cap; morph = slumps when stewed"),
    "ScaledPine": dict(category="produce", size_cm=20.0, slots=("Skin", "Leaf"), morph=False, fryable=False,
                       ref="the green scaled pineapple-thing (reference 5): barrel of overlapping scale facets, spiky crown"),
    "HerbPile": dict(category="produce", size_cm=16.0, slots=("Leaf", "Stem"), morph=False, fryable=False, cpu_access=True,
                     ref="a loose pile of flat-leaf herbs on stems; ONE closed manifold mesh (every leaf and stem a closed volume) so the chopping station can slice it at runtime"),
    # Stephen 2026-10-06: "a mushroom model and a cross section of the model that can be used for cutting". Whole = one
    # closed manifold volume (sliceable at runtime, CPU access); the cut variants are authored cross sections: Half
    # (split lengthwise through cap and stem, the cut face showing pale flesh with a gill band under the cap) and Slice
    # (a 1 cm lengthwise slice). Exterior on slot Skin, every cut face / gill surface on slot Flesh so the runtime cut
    # cap can take the same material.
    "Mushroom": dict(category="produce", size_cm=12.0, slots=("Skin", "Flesh"), morph=True, fryable=True, cpu_access=True,
                     cuts=("Half", "Slice"),
                     ref="a chunky faceted button / cremini mushroom standing on its stem: domed cap 12 cm across with a slightly rolled rim, short thick stem, cream-tan cap with darker centre, pale stem; morph = shrinks ~12 % and the cap sags when cooked"),
    # mortar & pestle minigame: separate meshes per stage, all piles share one pivot (the bowl floor centre)
    "SaltCrystal": dict(category="mortar", size_cm=2.5, slots=("Salt",), morph=False, fryable=False, variants=3,
                        ref="a single rough salt crystal (reference 6): translucent-white chunky octahedral lump"),
    "SaltPile": dict(category="mortar", size_cm=12.0, slots=("Salt",), morph=False, fryable=False, stages=("Crystals", "Grit", "Dust"),
                     ref="the pile in the mortar at each stage (reference 6): chunky crystals -> coarse grit -> fine dust mound"),
    "Peppercorn": dict(category="mortar", size_cm=1.0, slots=("Pepper",), morph=False, fryable=False, variants=2,
                       ref="a single wrinkled black peppercorn"),
    "PepperPile": dict(category="mortar", size_cm=12.0, slots=("Pepper",), morph=False, fryable=False, stages=("Whole", "Cracked", "Ground"),
                       ref="whole corns -> cracked halves and flakes -> ground powder mound"),
    "Mortar": dict(category="mortar", size_cm=22.0, slots=("Stone",), morph=False, fryable=False,
                   ref="a heavy faceted stone mortar (reference 6): thick walls, 22 cm outer diameter, bowl floor 3 cm above the base"),
    "Pestle": dict(category="mortar", size_cm=18.0, slots=("Stone",), morph=False, fryable=False,
                   ref="a stone pestle (reference 6): club shape, grip at the top, rounded crushing head at the bottom"),
}

# ---------------------------------------------------------------- pivots and rest pose
# Every mesh: centred in XY, resting base at z = 0 (so placing at a surface height is exact), the rest pose is how
# it lies on a counter. Long items lie along +X (handle / stem end toward -X, business end toward +X).
# Piles (Salt/Pepper stages): pivot = the mortar bowl floor centre, so a pile placed at the Mortar's "Bowl" point is
# right at every stage. The Mortar carries that point in its sidecar ("bowl_floor_cm").
# Pestle: stands on its crushing head, grip up +Z (pivot at the head's contact point).
# Oil surface: a disc in the XY plane at z = 0, pivot at the centre; the game scales it to the vessel.

# ---------------------------------------------------------------- UV channels
# UV0  the texture atlas: non-overlapping islands with padding (food_common.smart_uv); Blender's own v-up convention,
#      which the FBX exporter / Unreal importer flip consistently with textures baked in Blender.
# UV1  morph x, y   UV2  morph z: the raw -> cooked vertex offset in Unreal local cm, encoded exactly like
#      MeatCube_Mars_SM: uv1 = (ox, 1 - oy), uv2 = (oz, 1). Meshes without a morph carry no UV1 / UV2.
#      For the fryer's Puffer the "cooked" shape is the fried (puffed) one.
# VAT meshes: UV1.x = (vertex index + 0.5) / vertex count (the VAT column), UV1.y = 0.
MASK_SIZE = 1024
MORPH_UV = ("ShapeXY", "ShapeZ")

# ---------------------------------------------------------------- vertex colours
# One colour attribute "Col" (corner domain, float, LINEAR values; exported with colors_type LINEAR):
#   RGB  painted base albedo (linear). Per-facet variation of +-6% value and a slight hue drift keeps the faceted
#        read; crevices a touch darker and warmer.
#   A    cavity / ambient occlusion 0..1 (1 open), used by the cook model (sear climbs the open facets first).
# The Unreal side: the FBX importer stores linear input as sRGB bytes and the VertexColor node returns those bytes
# as-is, so the Unreal master carries a "Vertex Colour sRGB" decode switch that the lookdev swatch
# (ColorSwatch_Mars_SM: 18% / 50% grey and three primaries) verifies against a capture.
COLOR_ATTR = "Col"

# ---------------------------------------------------------------- mask textures (PNG RGBA 8-bit, linear, TC_MASKS)
#   R  cook-first mask: 1 where browning / crust starts (outer skin, fat, spike tips), 0 in the deepest crevices
#   G  grain / fibre / skin speckle, 0.5 neutral (the master uses it as a signed detail term)
#   B  crust break-up noise, 0.5 neutral (patchiness of the browning)
#   A  rim / edge mask 0..1 (1 on sharp convex edges; extra sear and the dust-catch of the mortar)
# Normal maps (optional, DirectX green-down like the meat cube) only where a surface has fine relief the facets
# cannot carry: tentacle sucker rings, scale ridges, bone pores.

# ---------------------------------------------------------------- Custom Primitive Data layout of the food master
# Same first ten floats as Meat_Mars_M so gameplay drives every cooking mesh the same way.
CPD = {
    "SearXY": 0,        # +X, -X, +Y, -Y sear 0 raw, 1 full crust, 2 burnt
    "SearZCook": 4,     # +Z, -Z, Penetration 0..1, Oil Coat 0..1
    "Finish": 8,        # Glaze 0..1, Shape 0..1 (raw -> cooked morph), Fry 0..2 (batter raw -> golden -> burnt), Wet 0..1 (stew / soup soak)
}

# ---------------------------------------------------------------- oil VAT (fryer category)
OIL_DISC_DIAMETER_CM = 100.0     # the game scales the disc to its vessel
OIL_GRID = 64                    # 64 x 64 verts on the disc = 4096 VAT columns (texture width)
OIL_FPS = 30
OIL_SECONDS = 4.0                # the loop; frame N == frame 0
OIL_FRAMES = int(OIL_FPS * OIL_SECONDS)
BUBBLE_COUNT = 48                # rising / popping bubble domes in the second VAT
# Textures: EXR float16, linear, no mips, nearest sampling. Row = frame (v), column = vertex (u).
#   *_VATPos_Mars_T  RGB = vertex offset from the rest mesh in Unreal local cm, normalised to 0..1 over the bounds
#                    written to OilVAT_Mars.json ("pos_min", "pos_max" per texture); decode = min + rgb * (max - min)
#   *_VATNrm_Mars_T  RGB = normal * 0.5 + 0.5 (Unreal local axes)
# Decode in the material: frame = frac(Time * Speed / Seconds); v = (floor(frame * Frames) + 0.5) / Frames;
# u = UV1.x; sample both, offset into WPO (local -> world), normal replaces the vertex normal.
# Version 2 (Stephen 2026-10-06, glassy bubbles that pop): the BUBBLES position texture's alpha = pop progress per
# vertex per frame (0 intact, 0..1 across the last ~15 % of the bubble's cycle while it widens into a base ring,
# exactly 1 while the bubble is hidden); the surface alpha stays 1. OilBubbles_Mars_SM carries a static UV2
# "BubbleLocal": x = height within its bubble at rest (0 base .. 1 apex), y = (bubble index + 0.5) / BUBBLE_COUNT.
# The bubble material is opaque + masked: Opacity Mask = BubbleLocal.x < 1 - pop, so the dome dissolves from the
# apex down and leaves the ring; the liquid colour is an instance parameter so the stew reuses the same meshes.
OIL_POP_WINDOW = 0.15

# ---------------------------------------------------------------- batter (fryer category)
# A geometry-node group "MarsBatterShell" in Food_Fryer.blend: input mesh -> lumpy closed shell 0.6..1.4 cm thick
# with drips under overhangs and crumb nodules, remeshed to faceted low-poly (<= 1.5x the input's tris). The
# builder applies it to every fryable ingredient's RAW mesh and exports <Name>_Battered_Mars_SM (ingredient faces
# kept with their slots, shell faces on slot "Batter", shell vertex colour = pale raw batter). Raw vs fried is the
# Fry value in CPD slot Finish.z on the batter material; the oil-coat function is shared with the meats.
BATTER_THICKNESS_CM = (0.6, 1.4)
