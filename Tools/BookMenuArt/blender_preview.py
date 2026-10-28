"""Render a contact sheet of the book at chosen action frames (verification aid).

    blender -b <file.blend> --python Tools/BookMenuArt/blender_preview.py -- <out.png> [engine] [Action:frame ...]

engine: WORKBENCH (default, fast, flat material colours) or EEVEE (uses the preview materials). With no Action:frame
pairs it renders a default set covering every action. Each tile is framed on the evaluated (deformed) mesh.
"""

import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_common as bc  # noqa: E402

DEFAULT_SHOTS = [
    "Book_Lying_R_01:1", "Book_Lying_R_to_Open_01:25", "Book_Lying_Open_01:1",
    "Book_Lying_Open_Page_Turn_R_to_L_02:30", "Book_Lying_Open_Page_Turn_R_to_L_02:55",
    "Book_Lying_Open_Page_Turn_R_to_L_02:80", "Book_Lying_Open_Page_Turn_L_to_R_02:55", "Book_Lying_Open_to_R_01:30",
]
TILE = 640


def evaluated_bounds(mesh):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = mesh.evaluated_get(dg)
    pts = np.array([ev.matrix_world @ v.co for v in ev.data.vertices])
    return Vector(pts.min(0)), Vector(pts.max(0))


def setup(engine):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH" if engine == "WORKBENCH" else "BLENDER_EEVEE"
    scene.render.resolution_x = scene.render.resolution_y = TILE
    scene.render.film_transparent = False
    if engine == "WORKBENCH":
        shading = scene.display.shading
        shading.light = "STUDIO"
        shading.color_type = "MATERIAL"
        shading.show_cavity = True
        shading.cavity_type = "BOTH"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.18, 0.17, 0.16)
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    if engine != "WORKBENCH":
        sun = bpy.data.objects.new("PreviewSun", bpy.data.lights.new("PreviewSun", "SUN"))
        sun.data.energy = 3.0
        sun.rotation_euler = (math.radians(40), math.radians(15), math.radians(30))
        scene.collection.objects.link(sun)
    return cam


def frame_camera(cam, lo, hi):
    center = (lo + hi) / 2
    radius = max((hi - lo).length / 2, 0.05)
    direction = Vector((0.35, -0.75, 0.9)).normalized()
    cam.data.lens = 50
    dist = radius / math.tan(cam.data.angle / 2) * 1.05
    cam.location = center + direction * dist
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.clip_start, cam.data.clip_end = dist * 0.01, dist * 10


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = argv[0]
    engine = argv[1] if len(argv) > 1 and ":" not in argv[1] else "WORKBENCH"
    shots = [a for a in argv[1:] if ":" in a] or DEFAULT_SHOTS
    _, arm, mesh = bc.get_rig()
    for track in arm.animation_data.nla_tracks:
        track.mute = True
    cam = setup(engine)
    scene = bpy.context.scene
    tiles = []
    tmp = os.path.join(os.path.dirname(out), "_tile.png")
    for shot in shots:
        name, frame = shot.rsplit(":", 1)
        action = bpy.data.actions[name]
        arm.animation_data.action = action
        arm.animation_data.action_slot = action.slots[0]
        scene.frame_set(int(frame))
        lo, hi = evaluated_bounds(mesh)
        frame_camera(cam, lo, hi)
        scene.render.filepath = tmp
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(tmp)
        px = np.array(img.pixels[:], dtype=np.float32).reshape(TILE, TILE, 4)
        bpy.data.images.remove(img)
        tiles.append(px)
        print(f"PREVIEW {shot} bounds_cm={[round(x * 100, 1) for x in (hi - lo)]}")
    cols = min(4, len(tiles))
    rows = math.ceil(len(tiles) / cols)
    sheet = np.zeros((rows * TILE, cols * TILE, 4), dtype=np.float32)
    for i, px in enumerate(tiles):
        r, c = divmod(i, cols)
        sheet[(rows - 1 - r) * TILE:(rows - r) * TILE, c * TILE:(c + 1) * TILE] = px
    img = bpy.data.images.new("sheet", cols * TILE, rows * TILE, alpha=True)
    img.pixels = sheet.ravel()
    img.filepath_raw = out
    img.file_format = "PNG"
    img.save()
    os.remove(tmp)
    print(f"PREVIEW sheet {out}")


main()
