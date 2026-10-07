"""Pure-Python half of the food library's Unreal side: everything mars_food_ue decides from data, with no `unreal`
import so it can be checked outside the editor.

    sidecars        read_metas / food_dir / parse_name / classify / has_morph
    slots           clean_slot / resolve_material  (mesh slot -> material instance name)
    instances       instance_plan                   (which instances exist, their parent, textures, parameters)
    cook states     FOOD_STATES / BATTER_STATES      (Custom Primitive Data per lookdev state)
    lookdev         plan_lookdev                     (placements + review shots from the sidecars)
    oil VAT         vat_textures / vat_meta          (texture names, OilVAT_Mars.json decode constants)
    misc            write_png (generated neutral textures), uv_layer_warnings, oil_column_index

Everything is driven by the JSON sidecars food_common.write_meta puts next to each FBX, plus food_spec's roster for
metadata (category, stages, variants). Nothing lists meshes by hand, so new roster entries flow through.
"""
import glob
import json
import math
import os
import re
import struct
import zlib

import food_spec as fs

# ---------------------------------------------------------------- asset names
MASTER_FOOD = "Food_Mars_M"
MASTER_BATTER = "Batter_Mars_M"
MASTER_ACCENT = "Accent_Mars_M"
MASTER_SALT = "Salt_Mars_M"
MASTER_OIL = "OilVAT_Mars_M"
MASTER_BUBBLE = "OilBubble_Mars_M"
MASTER_PARTICLE = "OilBubbleParticle_Mars_M"        # Niagara mesh-particle bubbles (pop = DynamicParameter.x)
MASTER_SPLATTER = "OilSplatter_Mars_M"             # Niagara oil droplets (flat plane particles)
MASTERS = (MASTER_FOOD, MASTER_BATTER, MASTER_ACCENT, MASTER_SALT, MASTER_OIL, MASTER_BUBBLE, MASTER_PARTICLE,
           MASTER_SPLATTER)
SPLATTER_MI = "OilSplatter_Mars_MI"
NIAGARA_SPLATTER = "OilSplatter_Mars_NS"
BUBBLE_GLASS_MF = "BubbleGlass_Mars_MF"
PARTICLE_MI = "OilBubbleParticle_Mars_MI"
NIAGARA_BUBBLES = "OilBubbles_Mars_NS"
NIAGARA_FOLDER = fs.UE_FOLDER + "/FX"
NIAGARA_MODULES = NIAGARA_FOLDER + "/Modules"

# OilBubbles_Mars_NS user parameters (name, Niagara type, default). A pan / pot instance sets SpawnExtent (box) or
# SpawnRadius (disc), SurfaceZ and LiquidColour; the rest tunes the bubble life.
NIAGARA_USER = (
    ("SpawnRate", "float", 12.0), ("SpawnRadius", "float", 45.0), ("SpawnExtent", "vec2", (0.0, 0.0)),
    ("SurfaceZ", "float", 0.0), ("StartDepth", "float", 3.0),
    ("BubbleRadiusMin", "float", 1.5), ("BubbleRadiusMax", "float", 3.0),
    ("LifetimeMin", "float", 1.2), ("LifetimeMax", "float", 1.8),
    ("RiseFraction", "float", 0.55), ("PopFraction", "float", 0.15), ("SurfaceSink", "float", 1.0),
    ("WobbleAmplitude", "float", 0.3), ("WobbleFrequency", "float", 1.5), ("ScalePulse", "float", 0.05),
    ("RingScale", "float", 1.35), ("ApexSink", "float", 0.7),
    ("LiquidColour", "color", (0.95, 0.58, 0.14, 1.0)),
)
# OilSplatter_Mars_NS user parameters
NIAGARA_SPLATTER_USER = (
    ("SplatterRate", "float", 14.0), ("SplatterRadius", "float", 2.6), ("BurstsPerSecond", "float", 3.0),
    ("SurfaceZ", "float", 0.0), ("FlingMin", "float", 2.0), ("FlingMax", "float", 8.0), ("SplatterArc", "float", 0.8),
    ("SplatterSizeMin", "float", 0.25), ("SplatterSizeMax", "float", 0.7), ("SplatterLife", "float", 2.0),
    ("SplatterColour", "color", (0.06, 0.03, 0.01, 1.0)),
)
NIAGARA_SPLATTER_SPAWN_INPUTS = ("SplatterRadius", "BurstsPerSecond", "SurfaceZ", "SplatterSizeMin", "SplatterSizeMax",
                                 "SplatterLife", "SplatterColour")
NIAGARA_SPLATTER_UPDATE_INPUTS = ("FlingMin", "FlingMax", "SurfaceZ", "SplatterArc")
NIAGARA_SPAWN_INPUTS = ("SpawnRadius", "SpawnExtent", "SurfaceZ", "StartDepth", "BubbleRadiusMin", "BubbleRadiusMax",
                        "LifetimeMin", "LifetimeMax", "LiquidColour")
NIAGARA_UPDATE_INPUTS = ("SurfaceZ", "StartDepth", "BubbleRadiusMin", "BubbleRadiusMax", "RiseFraction", "PopFraction",
                         "SurfaceSink", "WobbleAmplitude", "WobbleFrequency", "ScalePulse", "RingScale", "ApexSink")

# liquids that reuse the oil VAT meshes: <Liquid>Surface_Mars_MI / <Liquid>Bubbles_Mars_MI are children of the oil
# instances that only retint and retime them. Add a row to add a liquid (it gets its own puck and shot in the lookdev).
LIQUIDS = {
    "Stew": {"speed": 0.6, "colour": (0.45, 0.18, 0.05), "deep": (0.2, 0.07, 0.02), "bubble": (0.52, 0.21, 0.06)},
}
# the oil bubbles' look (create-only presets): domes OF the oil, a little lighter than it, the rim carries the highlight,
# an opened dome shows liquid (Back Darken near 1); liquids override only the colour (bubble = surface colour + ~15 %)
BUBBLE_LOOK = ({"Use Vertex Colour": 0.0, "Centre Brighten": 0.35, "Thin Film": 0.4, "Roughness": 0.04, "Back Darken": 0.95},
               {"Liquid Colour": (0.95, 0.58, 0.14, 1.0)})
OIL_COAT_MF = "OilCoat_Mars_MF"
VERTEX_DECODE_MF = "VertexColorDecode_Mars_MF"
FOOD_COOK_MF = "FoodCook_Mars_MF"
BASIC_SHAPE_MATERIAL = "/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial"

# OilCoat_Mars_MF signature (the function-call pins are looked up by these names)
COAT_INPUTS = ("Oil", "Breakup", "Roughness In")
COAT_OUTPUTS = ("ClearCoat", "ClearCoatRoughness", "Roughness Out")

# generated 4 x 4 textures that give the masters valid defaults (name, RGBA bytes, kind)
NEUTRAL_MASK = "FoodNeutral_Mask_Mars_T"      # R 1 cooks everywhere, G / B 0.5 neutral, A 0 no edge
FLAT_NORMAL = "FoodFlat_Normal_Mars_T"
VAT_REST = "FoodVATRest_Mars_T"                # 0.5 grey: decodes to no offset (min = max = 0) and an up normal
GENERATED = (
    (NEUTRAL_MASK, (255, 128, 128, 0), "masks"),
    (FLAT_NORMAL, (128, 128, 255, 255), "normal"),
    (VAT_REST, (128, 128, 255, 255), "vat_rest"),
)

COOKING = frozenset(fs.SLOTS_COOKING)
STATIC = frozenset(fs.SLOTS_STATIC)
ACCENT_SLOTS = ("Horn", "Bone", "Leaf", "Stem", "Stone", "Wood")    # always instanced
SALT_SLOTS = ("Salt", "Pepper")                                      # instances of Salt_Mars_M

# look presets applied when an instance is first created (an artist's later edits survive rebuilds)
ACCENT_LOOK = {
    "Horn": {"Roughness": 0.4}, "Bone": {"Roughness": 0.6}, "Leaf": {"Roughness": 0.45},
    "Stem": {"Roughness": 0.55}, "Stone": {"Roughness": 0.85}, "Wood": {"Roughness": 0.7},
}
SALT_LOOK = {
    "Salt": ({"Roughness": 0.2, "Subsurface Amount": 0.7}, {"Subsurface Color": (0.92, 0.94, 0.97, 1.0)}),
    "Pepper": ({"Roughness": 0.55, "Subsurface Amount": 0.1}, {"Subsurface Color": (0.12, 0.08, 0.05, 1.0)}),
}
CATEGORY_LOOK = {   # (scalars, vectors); the master defaults are tuned for meats
    "meats": ({}, {}),
    "produce": ({"Band Depth": 0.8, "Raw Wetness": 0.25, "Roughness Raw": 0.4, "Crust Replace": 0.4},
                {"Cooked Tint": (0.92, 0.86, 0.76, 1.0), "Crust Colour": (0.78, 0.62, 0.45, 1.0)}),
}

# ---------------------------------------------------------------- Custom Primitive Data states (lookdev)
# label, (Sear XY: +X -X +Y -Y), (Sear Z + Cook: +Z -Z Penetration OilCoat), (Finish: Glaze Shape Fry Wet).
# Modelled on mars_cooking_ue.CUBE_STATES; the faces the lookdev camera sees are +Z and +Y, so "Cooking" sears the
# top first. Shape (the raw -> cooked morph) follows the cook.
FOOD_STATES = (
    ("Raw", (0.0, 0.0, 0.0, 0.0), (0.0, 0.0, 0.0, 0.0), (0.0, 0.0, 0.0, 0.0)),
    ("Cooking", (0.35, 0.3, 0.45, 0.3), (0.9, 0.6, 0.5, 0.6), (0.0, 0.4, 0.0, 0.0)),
    ("Done", (1.0, 0.9, 1.05, 0.95), (1.1, 1.0, 1.0, 0.5), (0.0, 1.0, 0.0, 0.0)),
    ("Plated", (1.0, 0.9, 1.05, 0.95), (1.1, 1.0, 1.0, 0.3), (1.0, 1.0, 0.0, 0.25)),
    ("Burnt", (1.6, 1.3, 1.7, 1.4), (2.0, 1.7, 1.0, 0.2), (0.3, 1.0, 0.0, 0.0)),
)
# battered meshes: Fry 0 / 1 / 2; Shape stays 0 (the shell does not morph and the core must not poke through it)
BATTER_STATES = (
    ("Fry0", (0.0, 0.0, 0.0, 0.0), (0.0, 0.0, 0.0, 0.0), (0.0, 0.0, 0.0, 0.0)),
    ("Fry1", (0.3, 0.3, 0.3, 0.3), (0.3, 0.3, 0.6, 0.7), (0.0, 0.0, 1.0, 0.0)),
    ("Fry2", (0.8, 0.8, 0.8, 0.8), (0.9, 0.9, 1.0, 0.4), (0.0, 0.0, 2.0, 0.0)),
)


# ---------------------------------------------------------------- sidecars
def food_dir(export_dir=None):
    """The folder holding the food FBX / PNG / EXR / JSON. Accepts None (food_spec.EXPORT_DIR), the cooking export
    root (its food subfolder is used) or the food folder itself."""
    if not export_dir:
        return fs.EXPORT_DIR
    if os.path.basename(os.path.normpath(export_dir)).lower() == "food":
        return export_dir
    sub = os.path.join(export_dir, "food")
    return sub if os.path.isdir(sub) else export_dir


def read_metas(folder):
    """Every <Name>_Mars_SM.json sidecar in folder, sorted by name. A broken file is kept with meta['_error']."""
    metas = []
    for path in sorted(glob.glob(os.path.join(folder, "*_Mars_SM.json"))):
        stem = os.path.splitext(os.path.basename(path))[0]
        try:
            with open(path) as fh:
                meta = json.load(fh)
            if not isinstance(meta, dict):
                raise ValueError("not a JSON object")
        except (OSError, ValueError) as exc:
            meta = {"_error": str(exc)}
        meta.setdefault("name", stem)
        meta["_path"] = path
        metas.append(meta)
    return sorted(metas, key=lambda m: m["name"])


def parse_name(name):
    """'Drumstick_Battered_Mars_SM' -> ('Drumstick_Battered', 'Drumstick', ['Battered'])."""
    stem = name[:-len("_Mars_SM")] if name.endswith("_Mars_SM") else name
    tokens = stem.split("_")
    return stem, tokens[0], tokens[1:]


def clean_slot(name):
    """FBX slot names can pick up '.001' (Blender duplicates) or '_SkinNN' (legacy importer)."""
    return re.sub(r"(\.\d+|_Skin\d+)$", "", str(name))


def slots_of(meta):
    return [clean_slot(s) for s in (meta.get("slots") or ())]


def has_morph(meta):
    layers = meta.get("uv_layers") or ()
    try:
        amount = float(meta.get("morph_max_cm") or 0.0)
    except (TypeError, ValueError):
        amount = 0.0
    return fs.MORPH_UV[0] in layers and amount > 0.0


def cuts_of(ing):
    return tuple(fs.INGREDIENTS.get(ing, {}).get("cuts") or ())


def classify(meta):
    """swatch | oil | battered | stage | vessel | cut | hero | loose | tool | prop."""
    stem, ing, rest = parse_name(meta["name"])
    slots = set(slots_of(meta))
    info = fs.INGREDIENTS.get(ing, {})
    if ing.startswith("ColorSwatch"):
        return "swatch"
    if meta.get("particle_mesh"):
        return "particle"                             # a Niagara mesh-particle mesh (OilBubble_Mars_SM)
    if "Oil" in slots:
        return "oil"
    if "Battered" in rest or "Batter" in slots:
        return "battered"
    stages = tuple(info.get("stages") or ())
    if rest and rest[0] in stages:
        return "stage"
    if "bowl_floor_cm" in meta:
        return "vessel"
    if rest and rest[0] in cuts_of(ing) and slots & COOKING:
        return "cut"                                  # an authored cross section of the hero (Mushroom_Half)
    if slots & COOKING:
        return "hero"
    if info.get("category") == "mortar":
        try:
            size = float(meta.get("size_cm") or info.get("size_cm") or 99.0)
        except (TypeError, ValueError):
            size = 99.0
        return "loose" if info.get("variants") or size < 4.0 else "tool"
    return "prop"


def uv_layer_warnings(meta):
    """Food_Mars_M reads the morph from UV1 / UV2 (hard-wired, like Meat_Mars_M)."""
    layers = list(meta.get("uv_layers") or ())
    out = []
    if has_morph(meta):
        for want, index in ((fs.MORPH_UV[0], 1), (fs.MORPH_UV[1], 2)):
            if want not in layers:
                out.append("%s: morph layer %s missing" % (meta["name"], want))
            elif layers.index(want) != index:
                out.append("%s: %s is UV%d, Food_Mars_M reads UV%d" % (meta["name"], want, layers.index(want), index))
    return out


def is_bubble(stem, meta=None):
    """The bubble VAT mesh (OilBubble_Mars_M) vs the surface (OilVAT_Mars_M)."""
    return "bubble" in stem.lower() or "BubbleLocal" in ((meta or {}).get("uv_layers") or ())


def uv_index(metas, layer, default, bubbles=None):
    """(UV channel of a named layer on the oil meshes, distinct indices seen); bubbles True / False filters."""
    found = []
    for meta in metas:
        if "_error" in meta or classify(meta) != "oil":
            continue
        stem = parse_name(meta["name"])[0]
        if bubbles is not None and is_bubble(stem, meta) != bubbles:
            continue
        layers = list(meta.get("uv_layers") or ())
        if layer in layers:
            found.append(layers.index(layer))
    return (found[0] if found else default), sorted(set(found))


def liquid_stem(liquid, stem):
    """OilSurface -> StewSurface."""
    return liquid + stem[3:] if stem.startswith("Oil") else liquid + stem


def oil_column_index(metas):
    """(UV channel of the VAT column on the oil meshes, every distinct index seen). food_common.write_vat_uvs names
    the layer VATColumn; 1 when no sidecar says."""
    found = []
    for meta in metas:
        if "_error" not in meta and classify(meta) == "oil":
            layers = list(meta.get("uv_layers") or ())
            if "VATColumn" in layers:
                found.append(layers.index("VATColumn"))
    return (found[0] if found else 1), sorted(set(found))


# ---------------------------------------------------------------- slot -> instance
SWATCH_MI = "ColorSwatch_Mars_MI"
SWATCH_TINT50_MI = "SwatchTint50_Mars_MI"                                   # lookdev folder
SWATCH_GREY = {"SwatchGrey18_Mars_MI": 0.18, "SwatchGrey50_Mars_MI": 0.5}   # BasicShapeMaterial "Color", lookdev folder
OIL_BASE_MI = "FoodOilBase_Mars_MI"                                          # dark puck under the lookdev oil


def ingredient_mi(ing):
    return "%s_Mars_MI" % ing


def batter_mi(ing):
    return "%s_Batter_Mars_MI" % ing


def core_mi(ing):
    return "%s_BatteredCore_Mars_MI" % ing


def slot_mi(slot):
    return "%s_Mars_MI" % slot


def cut_mi(ing, cut):
    return "%s_%s_Mars_MI" % (ing, cut)


def resolve_material(mesh_name, slot, meta=None):
    """Material instance for one mesh slot, or None for a slot outside food_spec.SLOTS_*.
    Flesh / Skin -> <Ing>_Mars_MI (on a battered mesh <Ing>_BatteredCore_Mars_MI, on a cut <Ing>_<Cut>_Mars_MI, a
    child of <Ing>_Mars_MI that only swaps in the cut's own mask), Batter -> <Ing>_Batter_Mars_MI,
    Oil -> <MeshStem>_Mars_MI (OilVAT), any other static slot -> <Slot>_Mars_MI, ColorSwatch* -> ColorSwatch_Mars_MI."""
    stem, ing, rest = parse_name(mesh_name)
    slot = clean_slot(slot)
    if ing.startswith("ColorSwatch"):
        return SWATCH_MI
    if meta and meta.get("particle_mesh") and slot in STATIC:
        return PARTICLE_MI
    if slot == "Batter":
        return batter_mi(ing)
    if slot in COOKING:
        if "Battered" in rest:
            return core_mi(ing)
        if rest and rest[0] in cuts_of(ing):
            return cut_mi(ing, rest[0])
        return ingredient_mi(ing)
    if slot == "Oil":
        return "%s_Mars_MI" % stem
    if slot in STATIC:
        return slot_mi(slot)
    return None


# ---------------------------------------------------------------- oil VAT
_VAT_TEX = re.compile(r"^(?P<stem>.+?)_VAT(?P<kind>Pos|Position|Nrm|Normal)_Mars_T$")


def vat_textures(names):
    """{'OilSurface': {'Pos': 'OilSurface_VATPos_Mars_T', 'Nrm': 'OilSurface_VATNrm_Mars_T'}, ...}."""
    out = {}
    for name in names:
        m = _VAT_TEX.match(name)
        if m:
            kind = "Pos" if m.group("kind").startswith("Pos") else "Nrm"
            out.setdefault(m.group("stem"), {})[kind] = name
    return out


def _vec3(v):
    if isinstance(v, dict):
        v = [v.get(k, 0.0) for k in ("x", "y", "z")]
    if isinstance(v, (int, float)) and not isinstance(v, bool):
        return (float(v),) * 3
    if isinstance(v, (list, tuple)) and len(v) >= 3:
        return tuple(float(c) for c in v[:3])
    raise ValueError("not a vector: %r" % (v,))


def _num(scopes, keys):
    for d in scopes:
        if not isinstance(d, dict):
            continue
        for k in keys:
            v = d.get(k)
            if isinstance(v, (int, float)) and not isinstance(v, bool):
                return float(v)
    return None


_BOTTOM = ("bottom", "bottom_up", "bottomup", "bottom-up", "blender")
_TOP = ("top", "top_down", "topdown", "top-down", "unreal")


def _flip(scopes):
    """1 when frame 0 is stored on the bottom image row (Unreal v runs top-down), 0 when on top, None if unknown."""
    for d in scopes:
        if not isinstance(d, dict):
            continue
        for k in ("flip_v", "flipV", "v_flip", "flip"):
            if k in d and isinstance(d[k], (bool, int, float)):
                return 1 if d[k] else 0
        for k in ("frame0_row", "row0", "first_row", "v_origin", "origin", "row_order", "rows"):
            v = d.get(k)
            if isinstance(v, str):
                v = v.strip().lower()
                if v in _BOTTOM:
                    return 1
                if v in _TOP:
                    return 0
        for k in ("v", "v_formula", "formula", "decode_v"):
            v = d.get(k)
            if isinstance(v, str):
                return 1 if re.search(r"1(\.0*)?\s*-", v) else 0
    return None


def vat_meta(data, stems, frames=None, seconds=None):
    """Decode constants per VAT stem from OilVAT_Mars.json, whatever its exact nesting: any dict carrying pos_min /
    pos_max is matched to a stem by the keys and names around it; frames, seconds (or fps) and the row order are
    looked up in that dict, then a top-level "decode" block, then the top level. Missing values fall back to
    food_spec (OIL_FRAMES, OIL_SECONDS) and flip 0, with flip_known False so the caller can warn."""
    data = data if isinstance(data, dict) else {}
    found = []

    def walk(node, path):
        if isinstance(node, dict):
            label = path + [str(node[k]) for k in ("name", "texture", "mesh", "stem") if isinstance(node.get(k), str)]
            if "pos_min" in node and "pos_max" in node:
                found.append(("/".join(label).lower(), node))
            for k, v in node.items():
                walk(v, path + [str(k)])
        elif isinstance(node, list):
            for i, v in enumerate(node):
                walk(v, path + [str(i)])

    walk(data, [])
    decode = data.get("decode") if isinstance(data.get("decode"), dict) else {}
    has_pop = isinstance(data.get("pop"), dict) or isinstance(decode.get("pop"), dict)
    out = {}
    for stem in stems:
        low = stem.lower()
        short = low[3:] if low.startswith("oil") else low
        cands = [(p, d) for p, d in found if low in p or (short and short in p)]
        if not cands and len(found) == 1 and len(stems) == 1:
            cands = found
        cands.sort(key=lambda c: (0 if "pos" in c[0] else 1, -len(c[0])))
        node = cands[0][1] if cands else {}
        scopes = (node, decode, data)
        entry = {"source": cands[0][0] if cands else None}
        try:
            entry["pos_min"], entry["pos_max"] = _vec3(node["pos_min"]), _vec3(node["pos_max"])
        except (KeyError, ValueError):
            entry["pos_min"], entry["pos_max"] = (0.0, 0.0, 0.0), (0.0, 0.0, 0.0)
            entry["source"] = None
        n = _num(scopes, ("frames", "frame_count", "num_frames", "n_frames", "frames_count"))
        sec = _num(scopes, ("seconds", "loop_seconds", "duration", "duration_s", "length_seconds", "loop_s"))
        fps = _num(scopes, ("fps", "frame_rate"))
        if n is None and fps and sec:
            n = round(fps * sec)
        if sec is None and fps and n:
            sec = n / fps
        entry["frames"] = int(round(n)) if n else int(frames or fs.OIL_FRAMES)
        entry["seconds"] = float(sec) if sec else float(seconds or fs.OIL_SECONDS)
        flip = _flip(scopes)
        entry["flip_known"] = flip is not None
        entry["flip_v"] = flip if flip is not None else 0
        entry["pop"] = has_pop                    # version 2: Pos alpha = pop progress
        entry["version"] = data.get("version", 1)
        out[stem] = entry
    known = set(e["flip_v"] for e in out.values() if e["flip_known"])
    if len(known) == 1:                                   # one baker wrote them all: a sibling's row order holds
        for e in out.values():
            if not e["flip_known"]:
                e["flip_v"], e["flip_known"] = next(iter(known)), True
    return out


# ---------------------------------------------------------------- instance plan
def _spec(name, parent, folder="inst", scalars=None, vectors=None, textures=None, create_scalars=None,
          create_vectors=None):
    return {"name": name, "parent": parent, "folder": folder, "scalars": dict(scalars or {}),
            "vectors": dict(vectors or {}), "textures": dict(textures or {}),
            "create_scalars": dict(create_scalars or {}), "create_vectors": dict(create_vectors or {})}


def _first(has_texture, names):
    for n in names:
        if has_texture(n):
            return n
    return None


def instance_plan(metas, vat=None, vat_tex=None, has_texture=lambda name: False):
    """Ordered instance specs (parents before children). Listed scalars / vectors / textures are set on every build;
    create_* only when the instance is new. folder 'inst' = Materials/Instances, 'look' = Lookdev."""
    vat, vat_tex = vat or {}, vat_tex or {}
    metas = [m for m in metas if "_error" not in m]
    specs, seen = [], set()

    def add(spec):
        if spec["name"] not in seen:
            seen.add(spec["name"])
            specs.append(spec)

    by_ing = {}
    for meta in metas:
        by_ing.setdefault(parse_name(meta["name"])[1], []).append(meta)

    # one Food_Mars_M instance per ingredient that has a cooking slot
    for ing in sorted(by_ing):
        cooking = [m for m in by_ing[ing] if set(slots_of(m)) & COOKING]
        if not cooking:
            continue
        plain = [m for m in cooking if classify(m) not in ("battered", "cut")]
        plain = plain or [m for m in cooking if classify(m) == "cut"]
        main = next((m for m in plain if parse_name(m["name"])[0] == ing), plain[0] if plain else None)
        textures = {"Mask": _first(has_texture, ["%s_Mask_Mars_T" % ing]) or NEUTRAL_MASK}
        nrm = _first(has_texture, ["%s_Normal_Mars_T" % ing])
        if nrm:
            textures["Normal"] = nrm
        look_s, look_v = CATEGORY_LOOK.get(fs.INGREDIENTS.get(ing, {}).get("category"), ({}, {}))
        # a mesh without UV1 / UV2 reads UV0 there (the vertex factory repeats the last UV set): no morph for it
        add(_spec(ingredient_mi(ing), MASTER_FOOD, scalars={"Shape Scale": 1.0 if main and has_morph(main) else 0.0},
                  textures=textures, create_scalars=look_s, create_vectors=look_v))

    # cut variants (Mushroom_Half): a child of the ingredient instance with the cut's own mask (its UV0 differs)
    for meta in metas:
        if classify(meta) != "cut":
            continue
        stem, ing, rest = parse_name(meta["name"])
        textures = {}
        mask = _first(has_texture, ["%s_Mask_Mars_T" % stem])
        nrm = _first(has_texture, ["%s_Normal_Mars_T" % stem])
        if mask:
            textures["Mask"] = mask
        if nrm:
            textures["Normal"] = nrm
        add(_spec(cut_mi(ing, rest[0]), ingredient_mi(ing), scalars={"Shape Scale": 1.0 if has_morph(meta) else 0.0},
                  textures=textures))

    # battered meshes: the shell on Batter_Mars_M, the ingredient faces on a child of the ingredient instance
    for meta in metas:
        if classify(meta) != "battered":
            continue
        stem, ing, rest = parse_name(meta["name"])
        mask = _first(has_texture, ["%s_Mask_Mars_T" % stem, "%s_Batter_Mask_Mars_T" % ing])
        nrm = _first(has_texture, ["%s_Normal_Mars_T" % stem, "%s_Batter_Normal_Mars_T" % ing])
        textures = {"Mask": mask or NEUTRAL_MASK}
        if nrm:
            textures["Normal"] = nrm
        add(_spec(batter_mi(ing), MASTER_BATTER, textures=textures))
        if set(slots_of(meta)) & COOKING:
            core_tex = {}
            if mask:
                core_tex["Mask"] = mask          # baked over the battered mesh's own UV0
            if nrm:
                core_tex["Normal"] = nrm
            add(_spec(core_mi(ing), ingredient_mi(ing), scalars={"Shape Scale": 1.0 if has_morph(meta) else 0.0},
                      textures=core_tex))

    # accents and the salt / pepper crystals
    statics = set(ACCENT_SLOTS) | set(SALT_SLOTS)
    for meta in metas:
        statics |= set(s for s in slots_of(meta) if s in STATIC and s != "Oil")
    for slot in sorted(statics):
        if slot in SALT_SLOTS:
            s, v = SALT_LOOK.get(slot, ({}, {}))
            add(_spec(slot_mi(slot), MASTER_SALT, create_scalars=s, create_vectors=v))
        else:
            add(_spec(slot_mi(slot), MASTER_ACCENT, create_scalars=ACCENT_LOOK.get(slot, {})))

    # oil VAT: one instance per oil mesh / VAT texture pair, carrying its own textures and decode bounds
    oil_stems = set(vat_tex)
    for meta in metas:
        if classify(meta) == "oil":
            oil_stems.add(parse_name(meta["name"])[0])
    metas_by_stem = {parse_name(m["name"])[0]: m for m in metas}
    for stem in sorted(oil_stems):
        d = vat.get(stem, {})
        tex = vat_tex.get(stem, {})
        bubble = is_bubble(stem, metas_by_stem.get(stem))
        textures = {}
        if tex.get("Pos") and has_texture(tex["Pos"]):
            textures["VAT Position"] = tex["Pos"]
        if tex.get("Nrm") and has_texture(tex["Nrm"]):
            textures["VAT Normal"] = tex["Nrm"]
        scalars, vectors = {}, {}
        if d:
            scalars = {"Frames": float(d["frames"]), "Seconds": float(d["seconds"]), "Flip V": float(d["flip_v"])}
            vectors = {"Pos Min": tuple(d["pos_min"]) + (0.0,), "Pos Max": tuple(d["pos_max"]) + (0.0,)}
            if bubble:
                scalars["Use Pop"] = 1.0 if d.get("pop") else 0.0
        look_s, look_v = BUBBLE_LOOK if bubble else ({}, {})
        add(_spec("%s_Mars_MI" % stem, MASTER_BUBBLE if bubble else MASTER_OIL, scalars=scalars, vectors=vectors,
                  textures=textures, create_scalars=look_s, create_vectors=look_v))
    # liquids on the same VAT meshes (children of the oil instances: retint + retime only)
    for liquid, look in sorted(LIQUIDS.items()):
        for stem in sorted(oil_stems):
            bubble = is_bubble(stem, metas_by_stem.get(stem))
            scalars = {"Speed": float(look.get("speed", 1.0)), "Use Vertex Colour": 0.0}
            if bubble:
                vectors = {"Liquid Colour": tuple(look.get("bubble", look["colour"])) + (1.0,)}
            else:
                vectors = {"Liquid Colour": tuple(look["colour"]) + (1.0,),
                           "Liquid Colour Deep": tuple(look.get("deep", look["colour"])) + (1.0,)}
            add(_spec("%s_Mars_MI" % liquid_stem(liquid, stem), "%s_Mars_MI" % stem, scalars=scalars, vectors=vectors))

    # Niagara mesh-particle bubbles (one instance serves oil, stew and pan oil through the particle colour)
    if any(classify(m) == "particle" for m in metas):
        look_s = {k: v for k, v in BUBBLE_LOOK[0].items() if k != "Use Vertex Colour"}
        look_s["Pop Reach"] = 0.4          # a full sphere half under the surface: stop the dissolve above the waterline
        look_s.update({"Rim Darken": 0.8, "Centre Brighten": 0.2})     # the dark-rimmed beads of the pan reference
        add(_spec(PARTICLE_MI, MASTER_PARTICLE, create_scalars=look_s, create_vectors=BUBBLE_LOOK[1]))
    add(_spec(SPLATTER_MI, MASTER_SPLATTER, create_scalars={"Wobble": 0.35, "Rim Darken": 0.45}))

    # the vertex-colour check
    add(_spec(SWATCH_MI, MASTER_ACCENT, vectors={"Tint": (1.0, 1.0, 1.0, 1.0)}))
    add(_spec(SWATCH_TINT50_MI, MASTER_ACCENT, folder="look", vectors={"Tint": (0.5, 0.5, 0.5, 1.0)}))
    for name, grey in sorted(SWATCH_GREY.items()):
        add(_spec(name, BASIC_SHAPE_MATERIAL, folder="look", vectors={"Color": (grey, grey, grey, 1.0)}))
    add(_spec(OIL_BASE_MI, BASIC_SHAPE_MATERIAL, folder="look", vectors={"Color": (0.03, 0.03, 0.035, 1.0)}))
    return specs


# ---------------------------------------------------------------- lookdev layout
GAP = 8.0
OIL_LOOK_DIAMETER_CM = 36.0
PLANE = "@plane"            # the engine's 1 m plane
NIAGARA = "@niagara"        # an OilBubbles_Mars_NS actor (placement carries user parameter overrides / an attach parent)
CYLINDER = "@cylinder"      # the engine's 1 m cylinder (placed with its bottom at loc z)


def _size(meta):
    try:
        return max(float(meta.get("size_cm") or 0.0), 1.0)
    except (TypeError, ValueError):
        return 10.0


def _bowl(meta):
    """Bowl floor point from the mortar sidecar: a height or an (x, y, z) point; food_spec says 3 cm up."""
    v = meta.get("bowl_floor_cm") if meta else None
    if isinstance(v, (int, float)) and not isinstance(v, bool):
        return (0.0, 0.0, float(v))
    if isinstance(v, (list, tuple)) and len(v) >= 3:
        return tuple(float(c) for c in v[:3])
    return (0.0, 0.0, 3.0)


def _hash(i, salt):
    x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453
    return x - math.floor(x)


def _shot(cx, cy, width, depth, height, fov=40.0):
    """(eye, target, fov) looking at a row from the +Y side, about 45 degrees down."""
    span = max(width, depth * 1.4, 12.0)
    d = span * 0.5 / math.tan(math.radians(fov * 0.5)) * 1.15
    eye = (round(cx, 2), round(cy + d * 0.70, 2), round(height * 0.4 + d * 0.72, 2))
    return (eye, (round(cx, 2), round(cy, 2), round(height * 0.35, 2)), fov)


def _place(out, label, mesh, loc, yaw=0.0, scale=1.0, cpd=None, material=None, folder="Food", size=10.0,
           bounds_scale=None, roll=0.0, user=None, attach=None):
    out.append({"label": label, "mesh": mesh, "loc": tuple(round(c, 3) for c in loc), "yaw": float(yaw),
                "scale": scale, "cpd": cpd, "material": material, "folder": folder, "size": size,
                "bounds_scale": bounds_scale, "roll": float(roll), "user": dict(user or {}), "attach": attach})


def _scatter(out, metas, x0, width, y0, salt):
    """Three loose copies of each small item in a band y0 .. y0 + 6 cm (deterministic jitter)."""
    k = 0
    for m in metas:
        stem = parse_name(m["name"])[0]
        for c in range(3):
            fx, fy, fr = _hash(k, salt), _hash(k, salt + 1), _hash(k, salt + 2)
            _place(out, "%s_Loose%d" % (stem, c), m["name"], (x0 + fx * width, y0 + fy * 6.0, 0.0), fr * 360.0,
                   folder="Food/Mortar", size=_size(m))
            k += 1


def plan_lookdev(metas, vat=None):
    """Placements and review shots for FoodLookdev_Mars_MAP. The camera side is +Y. Rows run along +X and stack toward
    -Y: every cooking ingredient (the five FOOD_STATES), every battered mesh (the three BATTER_STATES), then static
    props. The mortar set sits to +X, the oil to -X, the vertex-colour swatch in front (+Y)."""
    metas = [m for m in metas if "_error" not in m]
    kinds = {}
    for meta in metas:
        kinds.setdefault(classify(meta), []).append(meta)
    order = {"meats": 0, "produce": 1}

    def key(m):
        ing = parse_name(m["name"])[1]
        return (order.get(fs.INGREDIENTS.get(ing, {}).get("category"), 2), m["name"])

    out, shots = [], {}
    cuts = {}
    heroes = set(parse_name(m["name"])[1] for m in kinds.get("hero", []))
    for m in kinds.get("cut", []):
        ing = parse_name(m["name"])[1]
        if ing in heroes:
            cuts.setdefault(ing, []).append(m)
        else:
            kinds.setdefault("hero", []).append(m)      # a cut without its hero gets a row of its own

    # ---- cooking rows (cut variants continue the hero's row in Raw and Done), battered rows
    rows = [("hero", m, FOOD_STATES) for m in sorted(kinds.get("hero", []), key=key)]
    rows += [("battered", m, BATTER_STATES) for m in sorted(kinds.get("battered", []), key=key)]
    y, half_w, first = 0.0, 20.0, True
    for kind, meta, states in rows:
        s = _size(meta)
        y -= (0.0 if first else GAP) + s * 0.5
        first = False
        pitch = s * 1.15 + GAP
        n = len(states)
        stem = parse_name(meta["name"])[0]
        for i, (label, sa, sb, fin) in enumerate(states):
            x = (i - (n - 1) * 0.5) * pitch
            _place(out, "%s_%s" % (stem, label), meta["name"], (x, y, 0.0), 20.0, cpd=(sa, sb, fin),
                   folder="Food/%s" % ("Battered" if kind == "battered" else "Cooking"), size=s,
                   bounds_scale=1.3 if has_morph(meta) else None)
        extra = sorted(cuts.get(stem, []), key=lambda m: m["name"]) if kind == "hero" else []
        k = n
        for cm in extra:
            cstem = parse_name(cm["name"])[0]
            for label, sa, sb, fin in (FOOD_STATES[0], FOOD_STATES[2]):
                x = (k - (n - 1) * 0.5) * pitch
                _place(out, "%s_%s" % (cstem, label), cm["name"], (x, y, 0.0), 20.0, cpd=(sa, sb, fin),
                       folder="Food/Cooking", size=_size(cm), bounds_scale=1.3 if has_morph(cm) else None)
                k += 1
        half_w = max(half_w, (n * 0.5 + (k - n)) * pitch)
        shots["%s_%s" % ("battered" if kind == "battered" else "row", stem)] = _shot((k - n) * pitch * 0.5, y, k * pitch, s, s)
        y -= s * 0.5

    # ---- static props (herb pile and anything else without a cooking slot)
    props = sorted(kinds.get("prop", []), key=key)
    if props:
        s = max(_size(m) for m in props)
        y -= (0.0 if first else GAP) + s * 0.5
        x = -half_w
        xs = []
        for m in props:
            ps = _size(m)
            _place(out, parse_name(m["name"])[0], m["name"], (x + ps * 0.5, y, 0.0), 20.0, folder="Food/Props", size=ps)
            xs.append(x + ps * 0.5)
            x += ps * 1.2 + GAP
        shots["props"] = _shot((min(xs) + max(xs)) * 0.5, y, max(xs) - min(xs) + s * 1.5, s, s)
        half_w = max(half_w, x)
        y -= s * 0.5
    y_bottom = y

    # ---- mortar set (+X): per pile a row of mortars, one stage in each at the bowl floor, the pestle beside, loose
    # crystals / corns scattered in front
    vessels = sorted(kinds.get("vessel", []), key=lambda m: m["name"])
    vessel = vessels[0] if vessels else None
    msize = _size(vessel) if vessel else 14.0
    bowl = _bowl(vessel)
    tools = sorted(kinds.get("tool", []), key=lambda m: m["name"])
    loose = sorted(kinds.get("loose", []), key=lambda m: m["name"])
    piles = {}
    for m in kinds.get("stage", []):
        piles.setdefault(parse_name(m["name"])[1], []).append(m)
    x0 = half_w + 40.0
    mpitch = msize * 1.25 + GAP
    my, mx_max, used_loose = 0.0, x0, set()
    pile_names = sorted(piles)
    for r, ing in enumerate(pile_names):
        stages = list(fs.INGREDIENTS.get(ing, {}).get("stages") or ())

        def stage_key(m, stages=stages):
            tok = parse_name(m["name"])[2][0]
            return (stages.index(tok) if tok in stages else 99, m["name"])

        group = sorted(piles[ing], key=stage_key)
        my -= (0.0 if r == 0 else GAP + msize * 0.25) + msize * 0.5
        for j, m in enumerate(group):
            mx = x0 + msize * 0.5 + j * mpitch
            stem = parse_name(m["name"])[0]
            if vessel:
                _place(out, "%s_Mortar" % stem, vessel["name"], (mx, my, 0.0), folder="Food/Mortar", size=msize)
                _place(out, stem, m["name"], (mx + bowl[0], my + bowl[1], bowl[2]), folder="Food/Mortar", size=_size(m))
            else:
                _place(out, stem, m["name"], (mx, my, 0.0), folder="Food/Mortar", size=_size(m))
            mx_max = max(mx_max, mx + msize * 0.5)
        end_x = x0 + len(group) * mpitch
        for t, tool in enumerate(tools):
            ts = _size(tool)
            tx = end_x + t * (ts * 0.6 + GAP)
            _place(out, "%s_%s" % (parse_name(tool["name"])[0], ing), tool["name"], (tx, my, 0.0),
                   folder="Food/Mortar", size=ts)
            mx_max = max(mx_max, tx + ts * 0.3)
        slots = set()
        for m in group:
            slots |= set(slots_of(m))
        mine = [m for m in loose if set(slots_of(m)) & slots]
        _scatter(out, mine, x0, max(end_x - x0, mpitch), my + msize * 0.5 + GAP * 0.6, r)
        used_loose |= set(m["name"] for m in mine)
        shots["mortar_%s" % ing] = _shot(x0 + (end_x - x0) * 0.5, my, end_x - x0 + msize, msize, msize)
        my -= msize * 0.5
    rest = [m for m in loose if m["name"] not in used_loose]
    if rest or (not pile_names and (tools or vessel)):
        my -= (GAP if pile_names else 0.0) + msize * 0.5
        if not pile_names:
            for t, m in enumerate(([vessel] if vessel else []) + tools):
                _place(out, parse_name(m["name"])[0], m["name"], (x0 + t * mpitch + msize * 0.5, my, 0.0),
                       folder="Food/Mortar", size=_size(m))
                mx_max = max(mx_max, x0 + (t + 1) * mpitch)
        _scatter(out, rest, x0, max(mpitch * 3.0, 30.0), my + msize * 0.5, 7)
        mx_max = max(mx_max, x0 + max(mpitch * 3.0, 30.0))
        my -= msize * 0.5
    if pile_names or rest or tools or vessel:
        shots["mortar"] = _shot((x0 + mx_max) * 0.5, my * 0.5, mx_max - x0 + 10.0, -my, msize)

    # ---- oil (-X): the disc scaled to a pan's worth, the bubbles in the same frame, lifted on a dark puck by the
    # largest scaled VAT offset (sidecar vat.max_offset_cm) so the troughs never cut into the counter
    oils = sorted(kinds.get("oil", []), key=lambda m: m["name"])
    if oils:
        disc = next((m for m in oils if "Surface" in m["name"]), oils[0])
        scale = OIL_LOOK_DIAMETER_CM / _size(disc)
        # the disc's trough depth (VAT pos_min z, else the sidecar's max offset) sets the lift; the puck's top stays
        # just under the deepest trough so the resting bubbles (just under the disc) sit inside the puck
        dstem = parse_name(disc["name"])[0]
        trough = -float(((vat or {}).get(dstem) or {}).get("pos_min", (0.0, 0.0, -0.0))[2] or 0.0)
        if trough <= 0.0:
            trough = float((disc.get("vat") or {}).get("max_offset_cm") or 3.0)
        lift = round(trough * scale + 0.6, 2)
        base_h = max(lift - trough * scale - 0.12, 0.2)
        ox = -(half_w + 40.0 + OIL_LOOK_DIAMETER_CM * 0.5)
        oy = -OIL_LOOK_DIAMETER_CM * 0.5
        base_d = OIL_LOOK_DIAMETER_CM * 1.04 / 100.0
        pitch = OIL_LOOK_DIAMETER_CM * 1.04 + GAP * 2.0
        # the oil itself, then one puck per LIQUIDS row toward -Y, each with its own shot
        for i, liquid in enumerate(["Oil"] + sorted(LIQUIDS)):
            ly = oy - i * pitch
            _place(out, "%sBase" % liquid, CYLINDER, (ox, ly, 0.0), scale=(base_d, base_d, base_h / 100.0),
                   material=OIL_BASE_MI, folder="Food/Oil", size=OIL_LOOK_DIAMETER_CM * 1.04)
            for m in oils:
                stem = parse_name(m["name"])[0]
                mi = None if liquid == "Oil" else "%s_Mars_MI" % liquid_stem(liquid, stem)
                _place(out, stem if liquid == "Oil" else liquid_stem(liquid, stem), m["name"], (ox, ly, lift),
                       scale=scale, material=mi, folder="Food/Oil", size=OIL_LOOK_DIAMETER_CM, bounds_scale=1.5)
            shots[liquid.lower()] = _shot(ox, ly, OIL_LOOK_DIAMETER_CM * 1.25, OIL_LOOK_DIAMETER_CM, lift * 2.0, 40.0)
        # Niagara bubbles (when the particle mesh is exported): an oil disc of their own on a third puck, the system
        # at its surface; and a second system attached to a food mesh rolled 20 degrees (local-space following)
        if kinds.get("particle"):
            ny = oy - (1 + len(LIQUIDS)) * pitch
            _place(out, "NiagaraBase", CYLINDER, (ox, ny, 0.0), scale=(base_d, base_d, base_h / 100.0),
                   material=OIL_BASE_MI, folder="Food/Niagara", size=OIL_LOOK_DIAMETER_CM * 1.04)
            _place(out, "NiagaraOilSurface", disc["name"], (ox, ny, lift), scale=scale, folder="Food/Niagara",
                   size=OIL_LOOK_DIAMETER_CM, bounds_scale=1.5)
            _place(out, "NiagaraBubbles", NIAGARA, (ox, ny, lift), folder="Food/Niagara", size=OIL_LOOK_DIAMETER_CM,
                   user={"SpawnRadius": OIL_LOOK_DIAMETER_CM * 0.42, "SurfaceZ": 0.6, "StartDepth": 1.2,
                         "BubbleRadiusMin": 0.55, "BubbleRadiusMax": 1.0, "SpawnRate": 14.0, "WobbleAmplitude": 0.15})
            heroes = sorted(kinds.get("hero", []), key=key)
            if heroes:
                host = heroes[0]
                hs = _size(host)
                hx = ox + OIL_LOOK_DIAMETER_CM * 0.5 + hs * 0.8
                _place(out, "NiagaraHost_%s" % parse_name(host["name"])[0], host["name"], (hx, ny, 0.0), 0.0,
                       roll=20.0, folder="Food/Niagara", size=hs)
                top = abs(float((host.get("bounds_max_cm") or (0, 0, hs * 0.5))[2]))
                _place(out, "NiagaraBubbles_Attached", NIAGARA, (hx, ny, top), folder="Food/Niagara", size=hs,
                       user={"SpawnExtent": (hs * 0.5, hs * 0.3), "SurfaceZ": 0.0, "StartDepth": 0.6,
                             "BubbleRadiusMin": 0.35, "BubbleRadiusMax": 0.6, "SpawnRate": 8.0, "WobbleAmplitude": 0.08},
                       attach="NiagaraHost_%s" % parse_name(host["name"])[0])
                shots["niagara"] = _shot((ox + hx) * 0.5, ny, hx - ox + hs + OIL_LOOK_DIAMETER_CM * 0.6,
                                         OIL_LOOK_DIAMETER_CM, 8.0, 40.0)
            else:
                shots["niagara"] = _shot(ox, ny, OIL_LOOK_DIAMETER_CM * 1.25, OIL_LOOK_DIAMETER_CM, lift * 2.0, 40.0)
        # low close-up across the oil disc so the bubble domes (and a pop ring, once the pop bake is in) fill the frame
        shots["oil_close"] = ((round(ox + 3.0, 2), round(oy + 13.0, 2), round(lift + 4.5, 2)),
                              (round(ox, 2), round(oy - 1.0, 2), round(lift + 0.6, 2)), 42.0)

    # ---- vertex-colour swatch (+Y): BasicShapeMaterial greys, the Accent master at Tint 0.5 on the engine plane (no
    # vertex colours = white, so it must match Swatch_Grey50), and the exported swatch mesh at Tint 1 (its 18 % / 50 %
    # patches must match the two greys when "Vertex Colour sRGB" is right)
    sy = GAP + 14.0
    sx = -30.0
    for label, mi in (("Swatch_Grey18", "SwatchGrey18_Mars_MI"), ("Swatch_Grey50", "SwatchGrey50_Mars_MI"),
                      ("Swatch_AccentTint50", SWATCH_TINT50_MI)):
        _place(out, label, PLANE, (sx, sy, 0.05), scale=0.12, material=mi, folder="Food/Swatch", size=12.0)
        sx += 15.0
    for m in sorted(kinds.get("swatch", []), key=lambda m: m["name"]):
        s = _size(m)
        _place(out, parse_name(m["name"])[0], m["name"], (sx + s * 0.5, sy, 0.0), folder="Food/Swatch", size=s)
        sx += s + GAP
    shots["swatch"] = _shot((sx - 30.0) * 0.5 - 7.5, sy, sx + 37.5, 14.0, 4.0, 45.0)

    xs = [p["loc"][0] for p in out] + [-half_w, half_w]
    ys = [p["loc"][1] for p in out] + [0.0, y_bottom, my]
    pad = 25.0
    extent = (min(xs) - pad, max(xs) + pad, min(ys) - pad, max(ys) + pad)
    cx, cy = (extent[0] + extent[1]) * 0.5, (extent[2] + extent[3]) * 0.5
    shots["overview"] = _shot(cx, cy, extent[1] - extent[0], extent[3] - extent[2], 10.0, 60.0)
    return {"placements": out, "shots": shots, "extent": extent}


# ---------------------------------------------------------------- tiny PNG writer (generated default textures)
def write_png(path, width, height, rgba):
    """Solid RGBA8 PNG, no external dependencies."""
    row = b"\x00" + bytes(bytearray(rgba)) * width
    raw = row * height

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
    folder = os.path.dirname(path)
    if folder:
        os.makedirs(folder, exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(png)
    return path
