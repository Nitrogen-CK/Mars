"""Host-side driver for the environment dressing work: runs editor Python in a Mars editor over Monolith (JSON-RPC), with
a hidden editor of its own when asked. Plain python 3 (no unreal, no bpy).

    python env_drive.py --port 9317 --launch                    # start a hidden MarsEditor on 9317 and wait for it
    python env_drive.py --port 9317 --call "me.run_all()"       # import mars_env_ue as me (reloaded) and print the result
    python env_drive.py --port 9317 --module mars_vine_ue --call "mv.build()" --alias mv
    python env_drive.py --port 9317 --py "import unreal; print(unreal.SystemLibrary.get_engine_version())"
    python env_drive.py --port 9317 --quit                      # quit that editor

Port 9316 is Stephen's interactive editor: this driver never launches or quits an editor there, and refuses to run
anything there while it is in PIE or has unsaved packages unless --force.
The hidden editor logs to Saved/Logs/HiddenEnv_Mars.log on 9317, HiddenEnv_<port>_Mars.log elsewhere (-abslog) so it never holds Saved/Logs/Mars.log (the git /
Build.bat guard hook probes that file).
"""
import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
COOKING_UE = os.path.join(os.path.dirname(os.path.dirname(HERE)), "mars_cooking", "unreal")
sys.path.insert(0, COOKING_UE)
import mars_cook_parity as cp      # noqa: E402  (Monolith client, wait_for, launch, quit_editor)

PROJECT = r"D:\Repo\Mars"
LOG = os.path.join(PROJECT, "Saved", "Logs", "HiddenEnv_Mars.log")


def log_for(port):
    """9317 keeps HiddenEnv_Mars.log; any other port logs to HiddenEnv_<port>_Mars.log so two hidden editors never
    share (or lock) one log."""
    return LOG if port == 9317 else os.path.join(PROJECT, "Saved", "Logs", "HiddenEnv_%d_Mars.log" % port)


def module_code(module, alias, call):
    return ("import sys, importlib\n"
            "sys.path.insert(0, r'%s')\n"
            "import %s as %s\n"
            "importlib.reload(%s)\n"
            "import json\n"
            "_r = %s\n"
            "print('RESULT ' + json.dumps(_r, default=str))\n") % (HERE, module, alias, alias, call)


def guard_interactive(m):
    out = m.python("import unreal\n"
                   "les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)\n"
                   "dirty = [p.get_name() for p in unreal.EditorLoadingAndSavingUtils.get_dirty_content_packages()]\n"
                   "dirty += [p.get_name() for p in unreal.EditorLoadingAndSavingUtils.get_dirty_map_packages()]\n"
                   "print('STATE', les.is_in_play_in_editor(), dirty)\n")
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=9317)
    ap.add_argument("--launch", action="store_true")
    ap.add_argument("--quit", action="store_true")
    ap.add_argument("--py")
    ap.add_argument("--call")
    ap.add_argument("--module", default="mars_env_ue")
    ap.add_argument("--alias", default="me")
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()

    if a.port == 9316 and (a.launch or a.quit):
        sys.exit("9316 is the interactive editor: never launch or quit it from here")
    if a.launch:
        cp.launch(a.port, log_for(a.port))
        m = cp.wait_for(a.port, 1500)
        print("READY", a.port)
    else:
        m = cp.Monolith(a.port)
    if a.port == 9316 and not a.force and (a.py or a.call):
        state = guard_interactive(m)
        print(state)
        if "STATE False []" not in state:
            sys.exit("the interactive editor is in PIE or has unsaved packages; pass --force to run anyway")
    if a.py:
        print(m.python(a.py))
    if a.call:
        text = m.python(module_code(a.module, a.alias, a.call))
        try:
            outer = json.loads(text)
            outs = [o.get("output", "") for o in outer.get("output", [])] if isinstance(outer, dict) else [text]
            print("\n".join(outs))
        except Exception:
            print(text)
    if a.quit:
        cp.quit_editor(m, None)
        print("QUIT sent")


if __name__ == "__main__":
    main()
