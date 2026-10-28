"""Shared paths and helpers for the BookMenu worn-book Blender scripts (run with Blender 5.2, headless or in the UI)."""

import os

import bpy

ROOT = os.path.dirname(os.path.abspath(__file__))
UE_EXPORT_DIR = os.path.join(ROOT, "Export")
BLEND_DIR = os.path.join(ROOT, "Blender")
TEXTURE_DIR = os.path.join(ROOT, "Textures")
TO_UNREAL_DIR = os.path.join(ROOT, "ToUnreal")

SOURCE_BLEND = os.path.join(BLEND_DIR, "BookMenu_Source.blend")
WORN_BLEND = os.path.join(BLEND_DIR, "BookMenu_Worn.blend")

ARMATURE_NAME = "Book_Armature"
MESH_NAME = "SK_Book_01"
# The FBX root null Unreal writes above the armature (imported as an Empty, scale 0.01 = cm -> m). Its scale is the one
# knob that sizes the book in Blender; blender_export.py puts it back to UE_ROOT_SCALE so the skeleton round-trips.
ROOT_NAME = "SK_Book_01_Root"
UE_ROOT_SCALE = 0.01

# Unreal material slot names of SK_Book_01, by index. The FBX carries material-instance names instead; restoring the
# slot names keeps a reimport onto the existing mesh matching slots by name.
SLOT_NAMES = ["Cover", "PagesBase", "PageA", "PageB", "PageC", "PageD", "PageFirst", "PageLast"]

UV_BASE = "DiffuseUV"         # Unreal UV0: tiling materials / page widget rectangle (shared by every page)
UV_LIGHTMAP = "LightMapUV"    # Unreal UV1
UV_UNIQUE = "DiffuseUV.001"   # Unreal UV2: the plugin's Mask textures (R/G/B = cavity|text/edge/dirt) live here. Unique
                              # for the cover and for PageA/PageD/PagesBase/PageFirst/PageLast, but the turning sheet's
                              # PageB/PageC rects overlap all of those, so it cannot carry stains.
UV_STAIN = "StainUV"          # Unreal UV3, added by blender_stains.py: UV2 everywhere except the sheet, whose faces take
                              # the UV2 of the page they lie on (PageB -> PageD, PageC -> PageA) and so share its stains.

MORPH_CURVES = ["PageBend_01", "PageBend_02", "PageBend_03", "PageBend_04"]
FPS = 60


def get_rig():
    return bpy.data.objects[ROOT_NAME], bpy.data.objects[ARMATURE_NAME], bpy.data.objects[MESH_NAME]


def ensure_dir(path):
    os.makedirs(path, exist_ok=True)
    return path
