"""Shared layout for the Mars cooking props: read by the Blender mesh builder, the texture generator and the Unreal
importer, so the cube's UV islands, the baked textures and the material agree.

Spaces: Blender is metres, Z up. Unreal local space is centimetres with Y mirrored (Blender (x, y, z) m ->
Unreal (100 x, -100 y, 100 z) cm). The material's sear axes are Unreal local axes.
"""

# ---------------------------------------------------------------- output locations
SOURCE_DIR = r"D:\Repo\Content\Cooking"          # off-repo source art, like D:\Repo\Content\Characters
EXPORT_DIR = SOURCE_DIR + r"\export"
BLEND_FILE = SOURCE_DIR + r"\CookingProps.blend"

UE_FOLDER = "/Game/Mars/Gameplay/Cooking"
UE_LOOKDEV_MAP = "/Game/Mars/Maps/CookingLookdev_Mars_MAP"

# ---------------------------------------------------------------- meat cube
# MeatCube_Mars_SM is HAND-AUTHORED since 2026-10-07: Stephen's CookingProps.blend (the procedural cube below plus a
# geometry-nodes noise) is the source of export\MeatCube_Mars_SM.fbx. build_cooking_meshes.py only builds the pan
# unless it is given --cube. The constants below still describe the cube for the textures and the lookdev map.
CUBE_HALF_CM = 2.0            # raw cube half extent: a 4 cm bite-size cube (was 4.0 until 2026-10-07)
CUBE_BEVEL_RAW = 0.10         # edge radius as a fraction of the half extent (a soft, stylized cut)
CUBE_BEVEL_COOKED = 0.22      # cooked: edges pull in and round over
# the cm amounts below scale with the cube so it keeps its proportions at any CUBE_HALF_CM (tuned at 4.0)
CUBE_BULGE_COOKED_CM = 0.14 * CUBE_HALF_CM / 4.0    # cooked: faces puff out
CUBE_LUMP_RAW_CM = 0.06 * CUBE_HALF_CM / 4.0        # low-frequency unevenness of the raw cut (kept low: stylized)
CUBE_LUMP_COOKED_CM = 0.11 * CUBE_HALF_CM / 4.0     # crust irregularity
# the hand-authored mesh's measured half extent (its noise makes it a touch bigger than CUBE_HALF_CM): the lookdev
# map rests the cube on it and the footprint below follows it. Re-measure after re-exporting the cube.
CUBE_MESH_HALF_CM = 2.2
# the pan's oil pool around a cube: the footprint radius gameplay feeds the pan material (Meat Footprint.z)
CUBE_FOOTPRINT_CM = CUBE_MESH_HALF_CM * 2.0 ** 0.5 * 0.9

# 1D sample positions across a face (-1..1): dense in the bevel zone so both edge radii have rings to bend
_BEVEL_RINGS = (0.78, 0.84, 0.90, 0.935, 0.96, 0.98, 1.0)
_INNER = 11


def cube_grid():
    inner = [-_BEVEL_RINGS[0] + 2.0 * _BEVEL_RINGS[0] * i / _INNER for i in range(_INNER + 1)]
    return [-c for c in reversed(_BEVEL_RINGS[1:])] + inner + list(_BEVEL_RINGS[1:])


# Face order is the sear order of the material in BLENDER axes; FACE_UE_AXIS names the Unreal local axis each lands on.
# (normal, u axis = image right, v axis = image down)
FACES = (
    ((1, 0, 0), (0, 1, 0), (0, 0, -1)),
    ((-1, 0, 0), (0, -1, 0), (0, 0, -1)),
    ((0, 1, 0), (-1, 0, 0), (0, 0, -1)),
    ((0, -1, 0), (1, 0, 0), (0, 0, -1)),
    ((0, 0, 1), (1, 0, 0), (0, -1, 0)),
    ((0, 0, -1), (-1, 0, 0), (0, -1, 0)),
)
FACE_UE_AXIS = ("+X", "-X", "-Y", "+Y", "+Z", "-Z")

# UV0: one square island per face in a 3 x 2 grid (v measured DOWN, the Unreal / image convention)
ATLAS_COLS, ATLAS_ROWS = 3, 2
ISLAND = 0.30                 # island side in UV units; the rest of each cell is padding the generator fills
TEX_SIZE = 1024


def face_cell(face):
    return face % ATLAS_COLS, face // ATLAS_COLS


def face_uv(face, a, b):
    """UV (v down) of the point at in-plane coords a (along u axis), b (along v axis), both -1..1."""
    col, row = face_cell(face)
    return ((col + 0.5) / ATLAS_COLS + a * ISLAND * 0.5, (row + 0.5) / ATLAS_ROWS + b * ISLAND * 0.5)


# ---------------------------------------------------------------- frying pan (cm, pivot = centre of the cooking surface)
PAN_BASE_R = 9.5              # flat cooking base radius
PAN_RIM_R = 14.5              # inner rim radius
PAN_HEIGHT = 4.6              # rim height above the cooking surface
PAN_THICK = 0.3
PAN_SEGMENTS = 96
