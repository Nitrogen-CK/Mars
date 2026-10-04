"""Mars - Send to Unreal.

One sidebar panel (View3D > N > Mars) with two buttons:

* **Send Character to Unreal** - exports the chef and the gloves from the open FPHands_02.blend with the project's own
  export functions (verify_anims / anim_common next to the .blend: SK_Chef.fbx + SM_Chef_Hat.fbx, the A_Chef_* clips,
  the A_Chef_Emote_* and A_FPHands_Emote_* emotes, optionally SK_FPHands.fbx), then asks the running Unreal editor
  (Monolith's MCP endpoint, like the crypt kit's Send to Unreal) to re-import every exported file onto its existing
  asset: the mesh keeps its skeleton, physics asset and material slots, the clips keep their skeleton, notifies and
  montages. The import runs through `unreal/mars_character_ue.py` in this folder.
* **Send Environment to Unreal** - the crypt kit's own sender (`vns.crypt_send_to_unreal` from the vns_trim_sheet
  extension): export the changed library pieces, re-import them, re-cook the maps. Needs the kit library .blend open.

Install: junction or copy this folder into Blender's scripts/addons as `mars_send_to_unreal` and enable it. The
Preferences hold the Mars project dir, the character scripts dir and the Monolith URL.
"""

bl_info = {
    "name": "Mars - Send to Unreal",
    "author": "Mars",
    "version": (1, 0, 0),
    "blender": (4, 2, 0),
    "location": "View3D > Sidebar > Mars",
    "description": "Export the chef / gloves or the crypt kit and re-import them in the running Unreal editor",
    "category": "Import-Export",
}

import importlib
import json
import os
import sys
import urllib.request

import bpy
from bpy.props import BoolProperty, StringProperty
from bpy.types import AddonPreferences, Operator, Panel, PropertyGroup

DEFAULT_PROJECT = r"D:\Repo\Mars"
DEFAULT_CHARACTER_DIR = r"D:\Repo\Content\Characters\FPHands"
DEFAULT_URL = "http://localhost:9316/mcp"

# Where each export lands in the project (the paths AMars_PlayerCharacter's config and ABP_Chef reference).
UE_CHEF = "/Game/Mars/Gameplay/PlayerCharacter/Chef"
UE_FP = "/Game/Mars/Gameplay/PlayerCharacter/FPHands"
CHEF_SKELETON = UE_CHEF + "/Meshes/SKEL_Chef"
FP_SKELETON = UE_FP + "/Meshes/SKEL_FPHands"

# Only the FBX exporter's calls below select objects; everything else leaves the scene as it was.

# ----------------------------------------------------------------------------------------------------------------
# Unreal over Monolith (JSON-RPC to the editor's MCP endpoint; the same route the crypt kit uses)


def _texts(o):
    if isinstance(o, str):
        yield o
        try:
            yield from _texts(json.loads(o))
        except ValueError:
            pass
    elif isinstance(o, dict):
        for v in o.values():
            yield from _texts(v)
    elif isinstance(o, list):
        for v in o:
            yield from _texts(v)


def _post(url, payload, timeout):
    req = urllib.request.Request(url, json.dumps(payload).encode(),
                                 {"Content-Type": "application/json", "Accept": "application/json, text/event-stream"})
    raw = urllib.request.urlopen(req, timeout=timeout).read().decode("utf-8", "replace")
    if raw.startswith("event:") or "\ndata:" in raw:
        raw = "\n".join(line[5:].strip() for line in raw.splitlines() if line.startswith("data:"))
    return json.loads(raw)


def unreal_reachable(url):
    try:
        _post(url, {"jsonrpc": "2.0", "id": 1, "method": "tools/list"}, 3)
        return True
    except Exception:
        return False


def unreal_run_python(code, url, timeout=1800):
    return _post(url, {"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {
        "name": "editor_query", "arguments": {"action": "run_python",
                                              "params": {"command": code, "mode": "execute_file", "unattended": True}}}},
                 timeout)


def unreal_import_character(jobs, url, helper_dir):
    """Run mars_character_ue.import_character(jobs) in the editor; returns its result dict (or {"error": ...})."""
    code = "\n".join([
        "import importlib, json, sys",
        "SRC = r'%s'" % helper_dir.replace("\\", "/"),
        "if SRC not in sys.path: sys.path.insert(0, SRC)",
        "import mars_character_ue as mc",
        "importlib.reload(mc)",
        "res = mc.import_character(json.loads(r'''%s'''))" % json.dumps(jobs),
        "print('MARS_SEND ' + json.dumps(res))"])
    try:
        resp = unreal_run_python(code, url)
    except Exception as exc:
        return {"error": "Unreal not reachable at %s (%s)" % (url, exc)}
    for t in _texts(resp):
        for line in t.splitlines():
            if line.startswith("MARS_SEND "):
                return json.loads(line[len("MARS_SEND "):])
    return {"error": "no import result: %s" % json.dumps(resp)[:1500]}


# ----------------------------------------------------------------------------------------------------------------
# preferences + per-scene options


def prefs(context=None):
    return (context or bpy.context).preferences.addons[__package__].preferences


class MARS_AP_send_to_unreal(AddonPreferences):
    bl_idname = __package__

    project_dir: StringProperty(name="Mars project", subtype="DIR_PATH", default=DEFAULT_PROJECT,
                                description="The Mars .uproject folder (holds Tools/Blender/mars_send_to_unreal/unreal)")
    character_dir: StringProperty(name="Character scripts", subtype="DIR_PATH", default=DEFAULT_CHARACTER_DIR,
                                  description="Folder with FPHands_02.blend, verify_anims.py and anim_common.py; "
                                              "the FBX files are written next to the open .blend")
    unreal_url: StringProperty(name="Unreal (Monolith)", default=DEFAULT_URL,
                               description="The running editor's Monolith MCP endpoint")

    def draw(self, context):
        col = self.layout.column()
        col.prop(self, "project_dir")
        col.prop(self, "character_dir")
        col.prop(self, "unreal_url")


class MARS_PG_send(PropertyGroup):
    body: BoolProperty(name="Body + hat", default=True, description="SK_Chef.fbx and SM_Chef_Hat.fbx")
    chef_clips: BoolProperty(name="Chef clips", default=True, description="The A_Chef_* locomotion, jump and strike clips")
    chef_emotes: BoolProperty(name="Chef emotes", default=True, description="The A_Chef_Emote_* clips")
    fp_emotes: BoolProperty(name="Glove emotes", default=True, description="The A_FPHands_Emote_* clips")
    fp_mesh: BoolProperty(name="Gloves mesh", default=False, description="SK_FPHands.fbx (rarely changes)")
    export_only: BoolProperty(name="Export only", default=False, description="Write the FBX files, do not touch Unreal")
    all_pieces: BoolProperty(name="All pieces", default=False,
                             description="Environment: export and sync every kit piece, not only the changed ones")


# ----------------------------------------------------------------------------------------------------------------
# character


def _load_character_scripts(character_dir):
    """verify_anims (and its siblings) from the character folder, reloaded so script edits are picked up."""
    if character_dir not in sys.path:
        sys.path.insert(0, character_dir)
    mods = []
    for name in ("emote_spec", "anim_common", "build_fphands", "verify_anims"):
        m = importlib.import_module(name)
        importlib.reload(m)
        mods.append(m)
    return mods[-1], mods[1]


def _job(path, folder, kind, skeleton=None):
    return {"fbx": path.replace("\\", "/"), "folder": folder, "name": os.path.splitext(os.path.basename(path))[0],
            "kind": kind, "skeleton": skeleton}


def _export_character(opts, va, ac, dry_run=False):
    """Run the chosen exports; returns the Unreal import jobs for what was written."""
    jobs = []
    chef_arm = bpy.data.objects.get(va.CHEF_ARM)
    fp_arm = bpy.data.objects.get(va.FP_ARM)
    if opts.body or opts.chef_clips or opts.chef_emotes:
        if chef_arm is None:
            raise RuntimeError("no %s armature in this file - open FPHands_02.blend" % va.CHEF_ARM)
    if opts.fp_emotes or opts.fp_mesh:
        if fp_arm is None:
            raise RuntimeError("no %s armature in this file - open FPHands_02.blend" % va.FP_ARM)
    if opts.body:
        for p in va.export_chef_skeletal(dry_run):
            jobs.append(_job(p, UE_CHEF + "/Meshes", "skeletal", CHEF_SKELETON))
        for p in va.export_hat(dry_run):
            jobs.append(_job(p, UE_CHEF + "/Meshes", "static"))
    if opts.chef_clips:
        clips = [(va.chef_name(n), N) for n, N in va.CHEF_CLIPS.items()]
        for p in va._export_jobs(chef_arm, clips, dry_run):
            jobs.append(_job(p, UE_CHEF + "/Anims", "anim", CHEF_SKELETON))
    if opts.chef_emotes:
        for p in va.export_chef_emotes(dry_run):
            jobs.append(_job(p, UE_CHEF + "/Anims/Emotes", "anim", CHEF_SKELETON))
    if opts.fp_emotes:
        names = [n for n in tuple(va.FP_OLD) + tuple(va.FP_NEW) if va._act(va.fp_name(n)) is not None]
        for p in va.export_fp_emotes(names, dry_run):
            jobs.append(_job(p, UE_FP + "/Anims/Emotes", "anim", FP_SKELETON))
    if opts.fp_mesh:
        mesh = bpy.data.objects.get(va.FP_MESH)
        if mesh is None:
            raise RuntimeError("no %s mesh in this file" % va.FP_MESH)
        path = os.path.join(va.export_dir(), va.FP_MESH + ".fbx")
        with va.viewport_visible([fp_arm, mesh]):
            if dry_run:
                print("  DRY export", va.FP_MESH, "->", path)
            else:
                ac.export_skeletal_fbx(fp_arm, [mesh], path)
        jobs.append(_job(path, UE_FP + "/Meshes", "skeletal", FP_SKELETON))
    return jobs


def _helper_dir(context):
    return os.path.join(bpy.path.abspath(prefs(context).project_dir), "Tools", "Blender", "mars_send_to_unreal", "unreal")


def _send_jobs(self, context, jobs, exported_msg):
    pr = prefs(context)
    if not jobs:
        self.report({"WARNING"}, "%s - nothing to send" % exported_msg)
        return {"FINISHED"}
    url = pr.unreal_url
    if not unreal_reachable(url):
        self.report({"WARNING"}, "%s - Unreal not reachable at %s: open the editor and use Import Last Export" % (
            exported_msg, url))
        return {"FINISHED"}
    helper = _helper_dir(context)
    if not os.path.isfile(os.path.join(helper, "mars_character_ue.py")):
        self.report({"ERROR"}, "%s - %s has no mars_character_ue.py (check the Mars project dir preference)" % (
            exported_msg, helper))
        return {"CANCELLED"}
    res = unreal_import_character(jobs, url, helper)
    if res.get("error"):
        self.report({"ERROR"}, "%s - Unreal import failed: %s" % (exported_msg, str(res["error"])[-400:]))
        return {"CANCELLED"}
    failed = res.get("failed", [])
    msg = "%s - Unreal: %d re-imported%s" % (exported_msg, len(res.get("imported", [])),
                                             (", FAILED %s" % ", ".join(failed)) if failed else "")
    self.report({"WARNING"} if failed else {"INFO"}, msg)
    return {"CANCELLED"} if failed else {"FINISHED"}


class MARS_OT_send_character(Operator):
    bl_idname = "mars.send_character"
    bl_label = "Send Character to Unreal"
    bl_description = ("Export the ticked parts of the chef and gloves from this file (SK_Chef + hat, clips, emotes) "
                      "and re-import them onto their existing assets in the running Unreal editor")

    dry_run: BoolProperty(name="Dry run", default=False, options={"HIDDEN"},
                          description="List what would be exported and sent; write and import nothing")

    def execute(self, context):
        opts = context.scene.mars_send
        pr = prefs(context)
        cdir = bpy.path.abspath(pr.character_dir)
        if not os.path.isfile(os.path.join(cdir, "verify_anims.py")):
            self.report({"ERROR"}, "%s has no verify_anims.py (check the character scripts preference)" % cdir)
            return {"CANCELLED"}
        if bpy.context.mode != "OBJECT":
            self.report({"ERROR"}, "Switch to Object mode first")
            return {"CANCELLED"}
        try:
            va, ac = _load_character_scripts(cdir)
            jobs = _export_character(opts, va, ac, dry_run=self.dry_run)
        except Exception as exc:
            self.report({"ERROR"}, "Export failed: %s" % exc)
            return {"CANCELLED"}
        names = [j["name"] for j in jobs]
        if self.dry_run:
            print("MARS_SEND_DRY", json.dumps(jobs, indent=1))
            self.report({"INFO"}, "Dry run: %d files would be sent (%s)" % (len(jobs), ", ".join(names[:8])))
            return {"FINISHED"}
        exported_msg = "%d exported to %s" % (len(jobs), va.export_dir())
        if opts.export_only:
            self.report({"INFO"}, "%s (export only)" % exported_msg)
            return {"FINISHED"}
        return _send_jobs(self, context, jobs, exported_msg)


class MARS_OT_import_last_export(Operator):
    bl_idname = "mars.import_last_export"
    bl_label = "Import Last Export"
    bl_description = ("Re-import the FBX files already on disk for the ticked parts (no export): for when the editor "
                      "was closed or in PIE during the last Send")

    def execute(self, context):
        opts = context.scene.mars_send
        pr = prefs(context)
        cdir = bpy.path.abspath(pr.character_dir)
        try:
            va, ac = _load_character_scripts(cdir)
            jobs = [j for j in _export_character(opts, va, ac, dry_run=True) if os.path.isfile(j["fbx"])]
        except Exception as exc:
            self.report({"ERROR"}, "Could not list the exports: %s" % exc)
            return {"CANCELLED"}
        return _send_jobs(self, context, jobs, "%d files on disk" % len(jobs))


# ----------------------------------------------------------------------------------------------------------------
# environment (delegates to the crypt kit's sender)


def _crypt_sender_available():
    return hasattr(bpy.types, "VNS_OT_crypt_send_to_unreal") or hasattr(bpy.ops.vns, "crypt_send_to_unreal")


class MARS_OT_send_environment(Operator):
    bl_idname = "mars.send_environment"
    bl_label = "Send Environment to Unreal"
    bl_description = ("The crypt kit's Send to Unreal: export the changed library pieces (gates first), re-import "
                      "them in the running editor and re-cook the maps. Open the kit library .blend first")

    @classmethod
    def poll(cls, context):
        return _crypt_sender_available()

    def execute(self, context):
        opts = context.scene.mars_send
        try:
            return bpy.ops.vns.crypt_send_to_unreal(all_pieces=opts.all_pieces)
        except Exception as exc:
            self.report({"ERROR"}, "Crypt kit sender failed: %s" % exc)
            return {"CANCELLED"}


class MARS_OT_check_unreal(Operator):
    bl_idname = "mars.check_unreal"
    bl_label = "Check Unreal"
    bl_description = "Ping the running editor's Monolith endpoint"

    def execute(self, context):
        url = prefs(context).unreal_url
        ok = unreal_reachable(url)
        context.window_manager.mars_unreal_status = "Unreal: reachable" if ok else "Unreal: not reachable (open the editor)"
        self.report({"INFO"} if ok else {"WARNING"}, context.window_manager.mars_unreal_status)
        return {"FINISHED"}


# ----------------------------------------------------------------------------------------------------------------
# panel


class MARS_PT_send_to_unreal(Panel):
    bl_label = "Send to Unreal"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Mars"

    def draw(self, context):
        lay = self.layout
        opts = context.scene.mars_send
        row = lay.row(align=True)
        row.label(text=context.window_manager.mars_unreal_status or "Unreal: unknown")
        row.operator("mars.check_unreal", text="", icon="FILE_REFRESH")

        box = lay.box()
        box.label(text="Character (FPHands_02.blend)", icon="ARMATURE_DATA")
        col = box.column(align=True)
        col.prop(opts, "body")
        col.prop(opts, "chef_clips")
        col.prop(opts, "chef_emotes")
        col.prop(opts, "fp_emotes")
        col.prop(opts, "fp_mesh")
        box.prop(opts, "export_only")
        box.operator("mars.send_character", icon="EXPORT")
        box.operator("mars.import_last_export", icon="IMPORT")

        box = lay.box()
        box.label(text="Environment (crypt kit library)", icon="MESH_CUBE")
        box.prop(opts, "all_pieces")
        if _crypt_sender_available():
            box.operator("mars.send_environment", icon="EXPORT")
        else:
            box.label(text="vns_trim_sheet extension not enabled", icon="ERROR")


classes = (MARS_AP_send_to_unreal, MARS_PG_send, MARS_OT_send_character, MARS_OT_import_last_export,
           MARS_OT_send_environment, MARS_OT_check_unreal, MARS_PT_send_to_unreal)


def register():
    for c in classes:
        bpy.utils.register_class(c)
    bpy.types.Scene.mars_send = bpy.props.PointerProperty(type=MARS_PG_send)
    bpy.types.WindowManager.mars_unreal_status = StringProperty(default="")


def unregister():
    del bpy.types.WindowManager.mars_unreal_status
    del bpy.types.Scene.mars_send
    for c in reversed(classes):
        bpy.utils.unregister_class(c)
