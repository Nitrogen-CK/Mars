"""Unreal side of Send to Unreal: which project is this editor?  Runs inside the editor's Python (Monolith
editor_query run_python), loaded from the Blender add-on's own folder.

`info()` -> {"name": "Mars", "dir": "D:/Repo/Mars/", "uproject": "D:/Repo/Mars/Mars.uproject", "pie": bool}
The add-on asks this before every send, so what it does follows the project that is open, not a path typed into its
preferences.
"""

import os

import unreal


def info():
    uproject = unreal.Paths.convert_relative_path_to_full(unreal.Paths.get_project_file_path())
    pie = False
    try:
        pie = bool(unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).is_in_play_in_editor())
    except Exception:
        pass
    return {"name": os.path.splitext(os.path.basename(uproject))[0],
            "dir": unreal.Paths.convert_relative_path_to_full(unreal.Paths.project_dir()),
            "uproject": uproject, "pie": pie}
