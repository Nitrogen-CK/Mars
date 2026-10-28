"""Convert Unreal's exported EXR render targets to PNG for inspection."""
from pathlib import Path
import bpy
import shutil

root = Path(__file__).resolve().parents[1]/'UnrealGameplay'
for path in root.glob('*-runtime'):
    exr = path.with_suffix('.exr')
    shutil.copyfile(path, exr)
    image = bpy.data.images.load(str(exr), check_existing=False)
    # Force the lazy EXR read before changing its source filepath to the PNG destination.
    assert len(image.pixels) == 1024 * 1536 * 4
    image.file_format = 'PNG'
    image.filepath_raw = str(path)+'.png'
    image.save()
    print('WIDGET_CAPTURE', image.filepath_raw, tuple(image.size))
