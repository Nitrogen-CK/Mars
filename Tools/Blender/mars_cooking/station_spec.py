"""Shared contract for the Mars cooking STATION props (fryer vat + baskets, cutting station, hearth under the pan).
Read by every station builder (build_station_*.py) and the Unreal importer, so names, sizes, pivots, sockets,
collision pieces and slot colours agree across props built by different agents.

Spaces: builders work in CENTIMETRES, Z up; station_common turns cm into Blender metres on object creation.
Unreal local = (100 x, -100 y, 100 z) of Blender metres (the FBX export mirrors Y). Every station is laid out in the
STATION FRAME the entity scripts use: depth along X, width along Y, the operator stands at -X looking toward +X,
the work surface (constants_station::k_CounterHeight) is 70 cm above the floor.

Style ruling (Stephen 2026-10-06/07, the three concept boards): the crypt kit look - chiselled dark stone blocks
with chipped corners, wrought iron with faceted rivets, hand-cut plank wood, faceted wire. Flat shading everywhere,
no smooth groups, asymmetry and hand-cut irregularity in the facets, colour painted per facet into vertex colours
(food_common.paint: small per-facet jitter, warmer crevices). No textures: the Unreal side instances Accent_Mars_M
per slot (vertex colour base + roughness per slot), and Ember is emissive.

Sizes read against the 1.5 m chef and the existing station blockouts (Script/WorldObjects/Stations/*.as):
table 80 deep x 140 wide x 70 high, cutting board 50 x 90 x 4, stove slab 50 x 50 on the table, FryPan_Mars_SM at
scale 2.5 (rim radius 36, flat base radius ~24), fried items 10..16 cm across (Puffer_Battered 16, Mushroom_Battered
14.4, SpikedBerry_Battered 11.7), the OilSurface_Mars_SM disc is 1 m across and gets scaled to the vessel.
"""
import os

import cooking_spec as base

# ---------------------------------------------------------------- locations (off-repo like the food library)
SOURCE_DIR = base.SOURCE_DIR                                   # D:\Repo\Content\Cooking
BLEND_DIR = os.path.join(SOURCE_DIR, "stations")               # one .blend per station, written only by its builder
EXPORT_DIR = os.path.join(base.EXPORT_DIR, "stations")         # FBX + JSON sidecar per mesh, flat
REVIEW_DIR = os.path.join(EXPORT_DIR, "review")                # contact sheets (workbench renders)
UE_FOLDER = base.UE_FOLDER + "/Stations"                       # /Game/Mars/Gameplay/Cooking/Stations/Meshes

# station -> (blend file, builder script). A builder owns its .blend and never opens another station's file.
STATIONS = {
    "fryer": ("Station_Fryer.blend", "build_station_fryer.py"),
    "cutting": ("Station_Cutting.blend", "build_station_cutting.py"),
    "hearth": ("Station_Hearth.blend", "build_station_hearth.py"),
    "tools": ("Station_Tools.blend", "build_station_tools.py"),
}

# ---------------------------------------------------------------- naming
# mesh      <Name>_Mars_SM                 (one FBX per prop, pivot per PROPS below)
# sockets   empties named SOCKET_<Name> parented to the mesh object (the legacy FBX importer turns them into static
#           mesh sockets; station_common.export_fbx exports them and writes them into the sidecar as Unreal local cm)
# collision mesh children named UCX_<MeshName>_<NN>, each CONVEX (the importer hulls them); a concave vessel is a
#           ring of wedge prisms plus a floor slab so items with physics stay inside. Never rely on auto collision
#           for a vessel (the importer's 26-DOP hull would seal the opening).
# sidecar   <Name>_Mars_SM.json next to every FBX: tris, bounds, slots, uv layers, sockets, ucx count + extras below

# Material slots. Stone / Wood come from the food contract (same Accent instances); the rest are new accents the
# Unreal step instances from Accent_Mars_M (ACCENT_LOOK rows: Iron rough dark metal, Wire slightly brighter, Rope
# matte fibre, Ember emissive). Keep a prop to the fewest slots that read.
SLOTS = ("Stone", "Wood", "Iron", "Wire", "Rope", "Ember")

# Base linear colours per slot (8-bit sRGB picked off the boards, converted by food_common.srgb at paint time).
PALETTE_SRGB = {
    "Stone": (58, 54, 58),        # dark basalt of the vat / hearth blocks; warm (84, 62, 50) chips at the edges
    "StoneLight": (96, 88, 84),   # the lighter chiselled faces
    "Wood": (128, 86, 48),        # plank tops, handles
    "WoodDark": (82, 52, 30),     # end grain, undersides
    "Iron": (46, 44, 50),         # wrought iron frames, posts, trivet
    "Wire": (92, 88, 82),         # basket mesh
    "Rope": (156, 128, 84),
    "Ember": (255, 120, 30),      # emissive bed under the hearth and round the vat base
}

# ---------------------------------------------------------------- the props (cm; pivot rules; sockets)
# Pivot rules: free-standing props pivot at the floor contact (XY centre, z = 0); table-top props pivot at their
# resting contact (centre of the underside); vessels that hold items with physics pivot at the CENTRE OF THE INNER
# FLOOR so a held / placed item rests at (0, 0, item half size); the skimmer handle runs along +X like FryPan's.
PROPS = {
    # ---- fryer (free-standing station; the operator stands at -X, the swing-arm post is on the far rim at +X)
    "FryerVat": dict(builder="fryer", tris_max=6000, slots=("Stone", "Iron", "Ember"),
                     outer_radius_cm=62.0, inner_radius_cm=48.0, rim_top_cm=76.0, cavity_floor_cm=40.0, oil_level_cm=66.0,
                     sockets={"Oil": (0.0, 0.0, 66.0),            # the OilSurface disc goes here, scale inner_radius / 50
                              "ArmPost": (54.0, 0.0, 76.0),        # the swing-arm post stands on the far rim
                              "SkimmerRest": (-40.0, 40.0, 76.0)}, # a notch on the near-left rim where the skimmer leans
                     ucx="12 wedge prisms for the ring wall (from cavity floor to rim top) + 1 floor slab + the plinth",
                     notes="two or three courses of chiselled basalt blocks (chipped corners, slight per-block rotation and "
                           "height jitter), an iron hoop band round the top course, ember slots (Ember slot faces) between "
                           "the base plinth stones as on board 1"),
    "FryerArm": dict(builder="fryer", tris_max=2500, slots=("Iron", "Wood"),
                     pivot="the hinge axis (rotate about Y to lift / lower the basket): a post 30 cm tall standing on the "
                           "rim at SOCKET_ArmPost with a bracket; the arm mesh pivots at the bracket pin",
                     sockets={"Hang": None},                     # end of the arm: the basket's SOCKET_Bail attaches here (fill in cm)
                     notes="the post (FryerArmPost_Mars_SM, pivot at its foot) and the arm (FryerArm_Mars_SM, pivot at the pin) "
                           "are separate meshes so the arm swings; arm reach ~60 cm so the lowered basket sits over the oil "
                           "centre and the raised one drains over the rim"),
    "FryerBasket": dict(builder="fryer", tris_max=3200, slots=("Wire", "Iron"),
                        inner_cm=(44.0, 26.0, 16.0), wire_pitch_cm=3.5,
                        pivot="centre of the inner floor",
                        sockets={"Bail": None},                  # top centre of the bail / handle where the arm hooks it
                        ucx="floor slab + 4 wall slabs (open top)",
                        notes="rectangular wire basket as on board 1: a rod frame, a wire grid on the floor and the four walls "
                              "(real thin 4-sided rods, no textures), two hooks and a bail over the top"),
    "FryerSkimmer": dict(builder="fryer", tris_max=2200, slots=("Wire", "Iron", "Wood"),
                         bowl_inner_radius_cm=10.0, bowl_depth_cm=7.0, handle_length_cm=48.0,
                         pivot="centre of the inner floor of the bowl (a 10..16 cm sphere rests at (0, 0, r))",
                         sockets={"Grip": None,                    # the hand grip on the wooden handle end (along +X)
                                  "Item": (0.0, 0.0, 6.0)},        # rest centre for a 12 cm sphere
                         ucx="12 wedge prisms round the bowl wall + 1 floor disc + 1 handle box",
                         notes="the round single-pickup deep-fry basket on board 1: a spherical-cap wire bowl (radial rods + "
                               "concentric rings), an iron rim ring, a long iron shaft along +X with a wooden grip"),
    # ---- cutting station (table-top props; the table is shared with the hearth station)
    "PrepTable": dict(builder="cutting", tris_max=3500, slots=("Wood", "Stone", "Iron"),
                      size_cm=(80.0, 160.0, 70.0),                 # depth X, width Y, height; 160 wide (was 140 in the blockout)
                      pivot="floor contact, XY centre",
                      sockets={"Board": (-5.0, 0.0, 70.0), "Input": (-5.0, -62.0, 70.0), "Output": (-5.0, 62.0, 70.0),
                               "Stove": (0.0, 0.0, 70.0)},
                      ucx="1 top slab + leg boxes",
                      notes="plank top on chiselled stone block piers as on boards 2 / 3 (stone legs, a wood apron, a lower "
                            "shelf plank), a cloth is NOT part of the mesh"),
    "CuttingBoard": dict(builder="cutting", tris_max=700, slots=("Wood",),
                         size_cm=(50.0, 90.0, 4.0),                # depth X, width Y, thickness: exactly the blockout board
                         pivot="centre of the underside", ucx="1 box",
                         notes="end-grain block board, hand-cut edges, a shallow juice groove, knife scores on top"),
    "PrepBowl": dict(builder="cutting", tris_max=1300, slots=("Stone",),
                     outer_diameter_cm=30.0, height_cm=12.0, inner_radius_cm=12.5, floor_cm=3.0,
                     pivot="centre of the inner floor (sidecar bowl_floor_cm = pivot height above the base)",
                     sockets={"Contents": (0.0, 0.0, 0.0)},
                     ucx="12 wedge prisms + floor disc",
                     notes="the ingredient bowl on the LEFT (-Y) of the board: a thick stone bowl like Mortar_Mars_SM but "
                           "wider and shallower, chiselled outside, smooth-faceted inside"),
    "PrepTray": dict(builder="cutting", tris_max=1800, slots=("Wood", "Rope"),
                     size_cm=(26.0, 30.0, 8.0),                    # depth X, width Y, height
                     pivot="centre of the inner floor",
                     sockets={"Contents": (0.0, 0.0, 0.0)},
                     ucx="floor slab + 4 wall slabs",
                     notes="the finished-ingredients tray on the RIGHT (+Y): a shallow plank tray with rope-bound corners, "
                           "or a wicker-like slat basket; cut herbs and slices get piled into it"),
    # ---- hearth (the stove under FryPan_Mars_SM; sits on the table at SOCKET_Stove)
    "Hearth": dict(builder="hearth", tris_max=4500, slots=("Stone", "Iron", "Ember"),
                   footprint_cm=56.0, slab_height_cm=6.0, firebowl_rim_cm=14.0, trivet_top_cm=20.0, trivet_ring_radius_cm=22.0,
                   pivot="centre of the underside (rests on the table top)",
                   sockets={"Flame": (0.0, 0.0, 8.0),             # the flame Niagara system, +Z up, at the ember bed
                            "Pan": (0.0, 0.0, 20.0),               # the pan's underside rests here (pan pivot = cooking surface centre)
                            "Bellows": (0.0, -34.0, 6.0)},          # where the bellows nozzle meets the fire bowl
                   ucx="1 slab box + 1 fire bowl box (open top is fine: the pan floats on SOCKET_Pan)",
                   notes="board 2: a chiselled stone slab with a recessed iron fire bowl (riveted band, feet), an ember bed "
                         "(Ember slot, a separate low mesh so it reads under the flame), and an iron trivet - three or four "
                         "bars with a ring whose top is the pan rest. The flame socket must sit BELOW the trivet ring with "
                         "clear air above it so a Niagara flame rises through the bars round the pan"),
    "EmberBed": dict(builder="hearth", tris_max=600, slots=("Ember", "Iron"),
                     pivot="same frame as the hearth (place at the hearth origin)",
                     notes="the glowing coal pile inside the fire bowl as its own mesh so the station can swap hot / cold "
                           "looks by material; faceted lumps, a few black (Iron slot) clinkers"),
    "Bellows": dict(builder="hearth", tris_max=1500, slots=("Wood", "Iron", "Rope"),
                    length_cm=45.0,
                    pivot="the nozzle tip, nozzle along +Y (so it points into the fire bowl when placed at SOCKET_Bellows "
                          "rotated to face it); handles trail toward -Y",
                    notes="board 2 top left: a wood-and-leather bellows (leather = Rope slot colour darkened) with an "
                          "iron nozzle; dressing only, no moving parts"),
    # ---- two-handed kitchen weapons (held; swung by the chef's procedural swing). Pivot = the REAR grip centre (the
    # primary hand), the tool runs along +X toward its business end, the striking / cutting side faces -Z when held
    # level. Grip_R (right glove, the rear grip at the pivot) / Grip_L (left glove, the front grip) are the FPHands grip
    # sockets (Script/ECS/FPHands/Mars_FPHands_Grips.as): X along the handle toward the head (across the palm toward
    # the index finger), Z up, away from the striking side; all sockets are unrotated.
    "MeatTenderizer": dict(builder="tools", tris_max=2600, slots=("Iron", "Wood", "Rope"),
                           overall_length_cm=58.0, grip_spacing_cm=16.0, head_cm=(12.0, 12.0, 16.0),
                           pivot="the rear grip centre; haft along +X, head at the +X end, toothed face -Z",
                           sockets={"Grip_R": (0.0, 0.0, 0.0), "Grip_L": (16.0, 0.0, 0.0),
                                    "Strike": None},             # centre of the tooth tips (fill in cm)
                           ucx="head box + haft box",
                           notes="two-hand mallet: squat iron head (4 x 4 pyramid teeth on the -Z face, flat chamfered "
                                 "+Z face, riveted bands, langets), faceted wooden haft with leather wraps at both "
                                 "grips and an iron butt ferrule"),
    "MeatCleaver": dict(builder="tools", tris_max=2200, slots=("Iron", "Wood", "Rope"),
                        overall_length_cm=62.0, grip_spacing_cm=14.0, blade_cm=(34.0, 15.0, 1.0),
                        pivot="the rear grip centre; handle along +X, blade at the +X end, edge -Z",
                        sockets={"Grip_R": (0.0, 0.0, 0.0), "Grip_L": (14.0, 0.0, 0.0),
                                 "Strike": None, "EdgeHeel": None, "EdgeToe": None},   # on the edge (fill in cm)
                        ucx="blade box + handle box",
                        notes="oversized two-hand cleaver: wood scales on a full tang (3 rivets a side), leather wrap "
                              "bands at both grips, iron pommel and bolster, a 34 cm blade with a thick dark spine, "
                              "a ground bevel band, a hexagonal hole near the toe, nicks and a wobbly hand-ground edge"),
}

# review sheet views per prop (food_common.VIEWS keys)
REVIEW_VIEWS = ("iso", "front", "top")
