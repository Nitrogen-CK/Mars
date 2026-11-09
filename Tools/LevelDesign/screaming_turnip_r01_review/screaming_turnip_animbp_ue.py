"""Screaming Turnip R01 AnimBP builder (Phase K Part 3; PHASE_K_BRIEF.md D-K2).

Builds `ScreamingTurnip_R01_Mars_ABP` under /Game/ArtCandidates/ScreamingTurnip/R01/Animation/ on
`ScreamingTurnip_R01_Mars_SKEL`, parented to the AngelScript class `/Script/Angelscript.Mars_ScreamingTurnip_AnimInstance`
(Script/Items/Presentation/Mars_ScreamingTurnip_AnimInstance.as: `Sequence` UAnimSequenceBase, `ClipTime` float,
`CrownOffset` FVector, written every tick by UMars_ScreamingTurnipPresentationComponent; the consumer constant is
constants_screaming_turnip_assets::AnimClass(), Script/Items/Mars_Item_ScreamingTurnip.as).

HOW IT RUNS (the Cellar Bat builder's pattern, Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_animbp_ue.py): Monolith's
graph actions (`animation_query`) have no Python binding inside the editor, so this file is a Monolith JSON-RPC client run by
a normal Python 3 OUTSIDE the editor; compile and the per-asset save go through `editor_query run_python`.

    python Tools/LevelDesign/screaming_turnip_r01_review/screaming_turnip_animbp_ue.py [--readback-only] [--no-save]

Prints TURNIP_ABP_OK / TURNIP_ABP_FAIL and writes phaseJ/../phaseK/animbp_report.json (`R/phaseK/animbp_report.json`).

THE GRAPH (AnimGraph only, no state machine):
  SequenceEvaluator {Sequence <- Sequence, ExplicitTime <- ClipTime, bShouldLoop false, ReinitializationBehavior NoReset}
    -> LocalToComponentSpace
    -> ModifyBone {BoneToModify crown, TranslationMode BMM_Additive, TranslationSpace BCS_ComponentSpace,
                   RotationMode BMM_Ignore, ScaleMode BMM_Ignore, Alpha 1, Translation <- CrownOffset}
    -> ComponentToLocalSpace -> Output Pose.

REBUILD: never in place and never a delete (the bat builder's rule). When the .uasset already exists on disk the build
goes to `<name>_v<N>` (first free N from 2), and the consumer constant (constants_screaming_turnip_assets::
k_AnimBlueprintName) must be pointed at it by a Script change. --readback-only reads the newest existing name.

DEAD ENDS (2026-11-09, do not retry):
  1. Binding `Sequence` without exposing its pin. set_anim_node_pin_binding answers ok and get_anim_node_pin_bindings shows
     the binding, but the compile fails: "[Compiler] Sequence Evaluator (by time) references an unknown Anim Sequence Base"
     (UAnimGraphNode_AssetPlayerBase::ValidateAnimNodeDuringCompilationHelper, AnimGraphNode_AssetPlayerBase.cpp:501-535,
     looks the binding up through the EXPOSED pin, FindPin("Sequence"), and Sequence is PinHiddenByDefault). Monolith can
     expose a pin only at node creation (add_anim_graph_node expose_pins, MonolithAbpWriteActions.cpp:1407-1428). The first
     build, `ScreamingTurnip_R01_Mars_ABP`, was saved with that error by a save step that did not wait for the compile
     verdict (fixed: the save now needs compile_ok); it stays on disk (no deletes), unused. The rebuild is `_v2`.
  2. `abp.get_editor_property("parent_class")` in editor Python: not exposed on AnimBlueprint (the parent is read back
     through animation_query get_abp_info instead).

MONOLITH CALLS THAT WORKED (2026-11-09, UE 5.7.4), in order:
  editor_query run_python   (ground: project, PIE off, parent class loads with Sequence / ClipTime / CrownOffset, skeleton)
  animation_query create_anim_blueprint {asset_path, skeleton_path, parent_class: "/Script/Angelscript.Mars_ScreamingTurnip_AnimInstance"}
  animation_query add_anim_graph_node {asset_path, node_class: "/Script/AnimGraph.AnimGraphNode_SequenceEvaluator", expose_pins: ["Sequence"]}
  animation_query add_anim_graph_node {asset_path, node_type: "LocalToComponentSpace"}
  animation_query add_anim_graph_node {asset_path, node_type: "ModifyBone", bone_to_modify: "crown", expose_pins: ["Translation"]}
  animation_query add_anim_graph_node {asset_path, node_type: "ComponentToLocalSpace"}
  animation_query set_anim_graph_node_property {asset_path, node_id, graph_name: AnimGraph, property_path, value}
      SequenceEvaluator: bShouldLoop False (was True), ReinitializationBehavior NoReset (was ExplicitTime)
      ModifyBone: TranslationMode BMM_Additive, TranslationSpace BCS_ComponentSpace, RotationMode / ScaleMode BMM_Ignore, Alpha 1.0
  animation_query set_anim_node_pin_binding {asset_path, node_id, pin, path: [var], graph_name: AnimGraph}
      Sequence <- [Sequence], ExplicitTime <- [ClipTime], Translation <- [CrownOffset]
  animation_query connect_anim_graph_pins {source_node, source_pin, target_node, target_pin, graph_name: AnimGraph, compile: false}
      SequenceEvaluator.Pose -> LocalToComponentSpace.LocalPose; LocalToComponentSpace.ComponentPose -> ModifyBone.ComponentPose;
      ModifyBone.Pose -> ComponentToLocalSpace.ComponentPose
  animation_query set_output_pose_source {source_node: ComponentToLocalSpace, graph_name: AnimGraph}
  animation_query auto_layout {graph_name: AnimGraph, formatter: builtin}
  animation_query get_abp_info / get_nodes / get_anim_node_pin_bindings / get_anim_graph_output_connection (readback)
  editor_query run_python   (BlueprintEditorLibrary.compile_blueprint + generated_class; EditorAssetLibrary.save_asset of the ABP only)
  editor_query list_errored_blueprints (the compile verdict: the ABP must not be listed)
"""

import argparse
import json
import os
import sys
import urllib.request

MONOLITH = "http://localhost:9316/mcp"
EXPECTED_PROJECT = "D:/Repositories/CkRepos/Orion/Mars.uproject"
OWNED_ROOT = "/Game/ArtCandidates/ScreamingTurnip/R01/"
FOLDER = OWNED_ROOT + "Animation"
BASE = "ScreamingTurnip_R01_Mars_ABP"
SKELETON = OWNED_ROOT + "Meshes/ScreamingTurnip_R01_Mars_SKEL"
PARENT = "/Script/Angelscript.Mars_ScreamingTurnip_AnimInstance"
CONTENT_DIR = "D:/Repositories/CkRepos/Orion/Content/"
HERE = os.path.dirname(os.path.abspath(__file__))
REPORT = os.path.join(HERE, "phaseK", "animbp_report.json")

SEQ_CLASS = "/Script/AnimGraph.AnimGraphNode_SequenceEvaluator"
SEQ_PROPS = (("bShouldLoop", "False"), ("ReinitializationBehavior", "NoReset"))
MODIFY_PROPS = (("TranslationMode", "BMM_Additive"), ("TranslationSpace", "BCS_ComponentSpace"),
                ("RotationMode", "BMM_Ignore"), ("ScaleMode", "BMM_Ignore"), ("Alpha", "1.0"))
BINDINGS = (("seq", "Sequence", ["Sequence"]), ("seq", "ExplicitTime", ["ClipTime"]), ("modify", "Translation", ["CrownOffset"]))


class MonolithError(RuntimeError):
    pass


_log = []


def call(tool, action, params, timeout=300):
    body = {"jsonrpc": "2.0", "id": 1, "method": "tools/call",
            "params": {"name": tool, "arguments": {"action": action, "params": params}}}
    req = urllib.request.Request(MONOLITH, data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json", "Accept": "application/json, text/event-stream"})
    res = json.loads(urllib.request.urlopen(req, timeout=timeout).read().decode())
    if "error" in res:
        raise MonolithError("%s.%s: %s" % (tool, action, res["error"]))
    result = res["result"]
    text = "".join(c.get("text", "") for c in result.get("content", []))
    try:
        data = json.loads(text)
    except ValueError:
        data = {"text": text}
    _log.append({"tool": tool, "action": action, "params": params, "ok": not result.get("isError", False),
                 "answer": text[:400]})
    if result.get("isError"):
        raise MonolithError("%s.%s failed: %s" % (tool, action, text[:2000]))
    return data


def anim(action, **params):
    return call("animation_query", action, params)


def py(code):
    data = call("editor_query", "run_python", {"command": code, "unattended": True})
    out = "".join(o.get("output", "") for o in data.get("output", []) if o.get("type") == "info")
    errs = "".join(o.get("output", "") for o in data.get("output", []) if o.get("type") == "error")
    if not data.get("success", False) or errs:
        raise MonolithError("run_python failed: %s" % json.dumps(data)[-3000:])
    for line in reversed(out.splitlines()):
        if line.startswith("RESULT:"):
            return json.loads(line[len("RESULT:"):])
    return out


def disk_file(name):
    return CONTENT_DIR + FOLDER[len("/Game/"):] + "/" + name + ".uasset"


def resolve_target(readback_only):
    names = [BASE] + ["%s_v%d" % (BASE, n) for n in range(2, 50)]
    on_disk = [n for n in names if os.path.exists(disk_file(n))]
    if readback_only:
        if not on_disk:
            raise MonolithError("no %s on disk to read back" % BASE)
        return FOLDER + "/" + on_disk[-1]
    free = next(n for n in names if not os.path.exists(disk_file(n)))
    return FOLDER + "/" + free


GROUND = r'''
import unreal, json
proj = unreal.Paths.convert_relative_path_to_full(unreal.Paths.get_project_file_path())
pie = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_game_world() is not None
cls = unreal.load_class(None, %(parent)r)
ea = unreal.EditorAssetLibrary
dirty = [str(x.get_name()) for x in unreal.EditorLoadingAndSavingUtils.get_dirty_content_packages()] + \
        [str(x.get_name()) for x in unreal.EditorLoadingAndSavingUtils.get_dirty_map_packages()]
props = {}
if cls:
    cdo = unreal.get_default_object(cls)
    for p in ("Sequence", "ClipTime", "CrownOffset"):
        try:
            props[p] = str(type(cdo.get_editor_property(p)).__name__)
        except Exception as e:
            props[p] = "error: " + str(e)[:80]
print("RESULT:" + json.dumps({"project": proj, "pie": pie, "parent": cls.get_path_name() if cls else None, "props": props,
                              "target_in_memory": ea.does_asset_exist(%(target)r), "skeleton": ea.does_asset_exist(%(skel)r),
                              "dirty": dirty}))
'''

COMPILE = r'''
import unreal, json
abp = unreal.load_asset(%(abp)r)
unreal.BlueprintEditorLibrary.compile_blueprint(abp)
gen = unreal.BlueprintEditorLibrary.generated_class(abp)
print("RESULT:" + json.dumps({"generated": gen.get_path_name() if gen else None,
                              "skeleton": abp.get_editor_property("target_skeleton").get_path_name()}))
'''

SAVE = r'''
import unreal, json
saved = unreal.EditorAssetLibrary.save_asset(%(abp)r, only_if_is_dirty=False)
dirty = [str(x.get_name()) for x in unreal.EditorLoadingAndSavingUtils.get_dirty_content_packages()] + \
        [str(x.get_name()) for x in unreal.EditorLoadingAndSavingUtils.get_dirty_map_packages()]
print("RESULT:" + json.dumps({"saved": saved, "dirty_after": dirty}))
'''


def node_name(resp):
    for k in ("node_name", "node_id", "name", "node"):
        if isinstance(resp.get(k), str):
            return resp[k]
    raise MonolithError("no node name in %s" % json.dumps(resp)[:600])


def build(abp):
    nodes = {}
    anim("create_anim_blueprint", asset_path=abp, skeleton_path=SKELETON, parent_class=PARENT)
    # Sequence is PinHiddenByDefault: it must be exposed AT CREATION (Monolith has no expose action for an existing node),
    # or the compile's asset check finds no pin to see the binding on (DEAD END 1 in the header).
    nodes["seq"] = node_name(anim("add_anim_graph_node", asset_path=abp, node_class=SEQ_CLASS, expose_pins=["Sequence"],
                                  position_x=-900, position_y=0))
    nodes["l2c"] = node_name(anim("add_anim_graph_node", asset_path=abp, node_type="LocalToComponentSpace", position_x=-600, position_y=0))
    nodes["modify"] = node_name(anim("add_anim_graph_node", asset_path=abp, node_type="ModifyBone", bone_to_modify="crown",
                                     expose_pins=["Translation"], position_x=-300, position_y=0))
    nodes["c2l"] = node_name(anim("add_anim_graph_node", asset_path=abp, node_type="ComponentToLocalSpace", position_x=0, position_y=0))
    props = {}
    for prop, value in SEQ_PROPS:
        props["seq." + prop] = anim("set_anim_graph_node_property", asset_path=abp, node_id=nodes["seq"], graph_name="AnimGraph",
                                    property_path=prop, value=value)
    for prop, value in MODIFY_PROPS:
        props["modify." + prop] = anim("set_anim_graph_node_property", asset_path=abp, node_id=nodes["modify"],
                                       graph_name="AnimGraph", property_path=prop, value=value)
    binds = {}
    for key, pin, path in BINDINGS:
        binds["%s.%s" % (key, pin)] = anim("set_anim_node_pin_binding", asset_path=abp, node_id=nodes[key], pin=pin, path=path,
                                           graph_name="AnimGraph")
    wires = {
        "seq->l2c": anim("connect_anim_graph_pins", asset_path=abp, source_node=nodes["seq"], source_pin="Pose",
                         target_node=nodes["l2c"], target_pin="LocalPose", graph_name="AnimGraph", compile=False),
        "l2c->modify": anim("connect_anim_graph_pins", asset_path=abp, source_node=nodes["l2c"], source_pin="ComponentPose",
                            target_node=nodes["modify"], target_pin="ComponentPose", graph_name="AnimGraph", compile=False),
        "modify->c2l": anim("connect_anim_graph_pins", asset_path=abp, source_node=nodes["modify"], source_pin="Pose",
                            target_node=nodes["c2l"], target_pin="ComponentPose", graph_name="AnimGraph", compile=False),
        "c2l->output": anim("set_output_pose_source", asset_path=abp, source_node=nodes["c2l"], graph_name="AnimGraph"),
    }
    layout = anim("auto_layout", asset_path=abp, graph_name="AnimGraph", formatter="builtin")
    return {"nodes": nodes, "props": props, "bindings": binds, "wires": wires, "layout": layout}


def readback(abp):
    rb = {"abp_info": anim("get_abp_info", asset_path=abp),
          "nodes": anim("get_nodes", asset_path=abp, graph_name="AnimGraph"),
          "pin_bindings": anim("get_anim_node_pin_bindings", asset_path=abp),
          "output": anim("get_anim_graph_output_connection", abp_path=abp)}
    return rb


def check(rb, abp):
    """The graph proof: four nodes of the right classes, the three bindings, the output driven by ComponentToLocalSpace."""
    text = json.dumps(rb)
    fails = []
    for cls in ("SequenceEvaluator", "LocalToComponentSpace", "ModifyBone", "ComponentToLocalSpace"):
        if cls not in text:
            fails.append("node %s missing" % cls)
    b = json.dumps(rb["pin_bindings"])
    for _, pin, path in BINDINGS:
        if pin not in b or path[0] not in b:
            fails.append("binding %s <- %s missing" % (pin, path[0]))
    if "ComponentToLocalSpace" not in json.dumps(rb["output"]):
        fails.append("output not driven by ComponentToLocalSpace: %s" % json.dumps(rb["output"])[:300])
    return fails


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--readback-only", action="store_true")
    ap.add_argument("--no-save", action="store_true")
    ap.add_argument("--resume", action="store_true",
                    help="the graph was built in this editor session but a later step failed before the save: skip the build")
    a = ap.parse_args(argv)
    report = {"error": None}
    try:
        abp = resolve_target(a.readback_only)
        report["abp"] = abp
        g = py(GROUND % {"parent": PARENT, "target": abp, "skel": SKELETON})
        report["ground"] = g
        if g["project"] != EXPECTED_PROJECT:
            raise MonolithError("Monolith answers for %s" % g["project"])
        if g["pie"]:
            raise MonolithError("PIE is running")
        if not g["parent"] or not g["skeleton"]:
            raise MonolithError("parent class or skeleton missing: %s" % g)
        if not a.readback_only:
            if g["target_in_memory"] and not a.resume:
                raise MonolithError("%s exists in memory but not on disk (an unsaved earlier build): stop" % abp)
            if not a.resume:
                report["build"] = build(abp)
        report["readback"] = readback(abp)
        report["graph_fails"] = check(report["readback"], abp)
        if a.readback_only:
            report["compile"] = {"skipped": True}
            errored = call("editor_query", "list_errored_blueprints", {})
        else:
            report["compile"] = py(COMPILE % {"abp": abp})
            errored = call("editor_query", "list_errored_blueprints", {})
        report["errored_blueprints"] = errored
        name = abp.rsplit("/", 1)[1]
        report["compile_ok"] = (a.readback_only or bool(report["compile"].get("generated"))) and             (name + '"') not in json.dumps(errored) and (name + ".") not in json.dumps(errored)
        if not a.no_save and not a.readback_only and report["compile_ok"] and not report["graph_fails"]:
            report["save"] = py(SAVE % {"abp": abp})
        elif not a.no_save and not a.readback_only:
            report["save"] = {"saved": False, "why": "not saved: the compile or the graph check failed"}
        report["ok"] = not report["graph_fails"] and report["compile_ok"] and \
            (a.no_save or a.readback_only or report["save"]["saved"])
    except Exception as e:
        report["error"] = str(e)
        report["ok"] = False
    report["calls"] = _log
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    out = REPORT if not a.readback_only else REPORT.replace(".json", "_readback.json")
    with open(out, "w") as fh:
        json.dump(report, fh, indent=1)
    print(json.dumps({k: report.get(k) for k in ("abp", "error", "graph_fails", "compile", "compile_ok", "save")}, indent=1)[:4000])
    print("TURNIP_ABP_OK" if report["ok"] else "TURNIP_ABP_FAIL " + str(report.get("error") or report.get("graph_fails")))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
