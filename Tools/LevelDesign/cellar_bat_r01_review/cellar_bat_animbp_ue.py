"""Cellar Bat R01 AnimBP builder (Phase 6b-2 prep; reused for the final AnimBP by swapping the manifest).

Builds (or rebuilds in place) `CellarBat_R01_Mars_ABP` on the manifest's skeleton, parented to the AngelScript class
`/Script/Angelscript.Mars_CellarBat_AnimInstance` (Script/WorldObjects/Monsters/Mars_CellarBat_AnimInstance.as), from a
JSON manifest `{clip name -> asset path}` (`cellar_bat_animbp_manifest_prep.json` is the prep one: every clip is the Phase 2
blockout flap).

HOW IT RUNS. Monolith's graph actions (`animation_query`) have no Python binding inside the editor, and an HTTP call from
the editor's own Python to Monolith would block the game thread that serves it. So this file is a Monolith JSON-RPC client
run by a normal Python 3 OUTSIDE the editor; the editor-only parts (asset existence, crossfade times, compile, save) go
through Monolith `editor_query run_python` calls that this client sends:

    python Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_animbp_ue.py \
        --manifest Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_animbp_manifest_prep.json [--no-save] [--readback-only]

`--readback-only` reads the manifest's own name. It prints CELLAR_BAT_ABP_OK / CELLAR_BAT_ABP_FAIL and writes `<manifest stem>_readback.json` beside the manifest.

THE GRAPH.
  AnimGraph: state machine `Bat` -> Output Pose.
  `Bat` states: RoostIdle (entry), RoostAlert, Launch, Locomotion, Telegraph, Swoop, Recover, Brake, Perch, Screech, Hit,
  Stun, DeathFall, DeathLand. Every state but Locomotion plays its manifest clip; the manifest's "loops" list says which
  loop (the rest play once and hold their last frame).
  Locomotion's inner graph: BlendSpacePlayer(`CellarBat_R01_Locomotion_Mars_BS1D`, X bound to `Speed`; samples Hover @ 0,
  FlyForward @ cruise, Glide @ the glide threshold) -> ApplyAdditive(BankRight additive copy, Alpha bound to
  `BankRightAlpha`) -> ApplyAdditive(BankLeft additive copy, Alpha bound to `BankLeftAlpha`) -> state result.
  (`BankRightAlpha = max(BankAlpha, 0)`, `BankLeftAlpha = max(-BankAlpha, 0)`, set by the AnimInstance's Apply.)
  Transitions: a full mesh between the phase-driven states (14 states, 182 since the kernel's Screeching phase; the prep
  build had 13 / 156): S -> T when `PhaseValue` (float mirror of PhaseIndex) equals one of T's phases (PHASES below; the
  sets are disjoint). Screech shows the presentation phase Screeching (the first telegraph of a sortie). Crossfade into each state per BLEND_SECONDS, set with editor Python on
  the transition nodes (Monolith has no blend-time action) and verified by from/to on `get_transitions`.
  Rebuild: never in place and never a delete. When the manifest's .uasset already exists on disk the build goes to a fresh
  name, `<name>_v<N>` (first free N from 2), and the report's "abp" says which. Point the consumer (utils_bat::
  CandidateAnimClassPath / the review preset) at it, or make it the canonical name by the clean path: delete the stale
  .uasset with the editor CLOSED (or with delete_asset before anything in the session has loaded it), then run again.
  Why: clearing in place (remove_node_slice) left the removed state machines' sub-graphs in the saved package (313
  transition nodes for 156 live ones, 4.3 MB). Deleting a loaded ABP from the live editor on 2026-11-05 was refused
  (156 native GC references from the transition nodes); ForceDeleteObject failed (ObjectTools.cpp:3963 ensure), left the
  in-memory ABP without a generated class, and the next PIE start, which compiles dirty blueprints, took the editor down.

DEAD ENDS (do not retry): a conduit hub (add_conduit works, but add_transition answers "State 'Router' not found");
  rules on `PhaseIndex` (set_transition_rule reads only float members inherited from a script/native parent, hence
  `PhaseValue`); Python `AnimStateTransitionNode.get_previous_state` (not exposed: nodes are matched by creation order).

MONOLITH CALLS THAT WORKED (2026-11-05, Monolith 0.23.0, UE 5.7.4), in order:
  animation_query create_anim_blueprint {asset_path, skeleton_path, parent_class: "/Script/Angelscript.Mars_CellarBat_AnimInstance"}
  animation_query duplicate_sequence {source_path, dest_path}                       (additive copies of BankLeft/BankRight)
  animation_query set_additive_settings {asset_path, additive_anim_type: LocalSpace, ref_pose_type: AnimFrame, ref_frame_index: 0}
  animation_query create_blend_space_1d {asset_path, skeleton_path, axis_name: Speed, axis_min: 0, axis_max}
  animation_query add_blendspace_sample {asset_path, anim_path, x, y: 0} x3 ; bake_blend_space {asset_path}
  animation_query build_state_machine {asset_path, state_machine_name: Bat, states: [{name}], entry_state: RoostIdle}
  animation_query set_output_pose_source {asset_path, source_node: <SM node>}
  animation_query set_state_animation {asset_path, machine_name: Bat, state_name, anim_asset_path, loop}
  animation_query add_anim_graph_node {asset_path, graph_name: Bat, state_name: Locomotion, node_type: BlendSpacePlayer|SequencePlayer, anim_asset}
  animation_query add_apply_additive {asset_path, graph_name: Bat, state_name: Locomotion, base_node, additive_node, alpha}
  animation_query set_anim_node_pin_binding {asset_path, node_id, pin: X|Alpha, path: [Speed|BankRightAlpha|BankLeftAlpha]}
  animation_query set_state_result_source {asset_path, machine_name: Bat, state_name: Locomotion, source_node}
  animation_query add_transition {asset_path, machine_name: Bat, from_state, to_state}
  animation_query set_transition_rule {asset_path, machine_name: Bat, from_state, to_state,
                                       rule: {kind: expression, combine: or, terms: [{lhs: PhaseValue, op: ==, rhs}]}}
  animation_query auto_layout {asset_path, graph_name: all}
  animation_query get_nodes {asset_path, graph_name: AnimGraph}  (finds the state machine node build_state_machine made)
  animation_query get_nodes {asset_path, graph_name: AnimGraph}  (finds the state machine node build_state_machine made)
  editor_query run_python (project/PIE check, crossfade_duration, compile_blueprint, save_asset of the four assets only)
  editor_query list_errored_blueprints (compile verdict)
  animation_query get_abp_info / get_state_machines / get_transitions / get_anim_graph_output_connection / get_state_info /
  get_anim_node_pin_bindings / get_blend_space_info (readback)
See the executor's PROGRESS.md entry for the call results that were observed.
"""

import argparse
import json
import os
import sys
import urllib.request

MONOLITH = "http://localhost:9316/mcp"
EXPECTED_PROJECT = "D:/Repositories/CkRepos/Orion/Mars.uproject"
OWNED_ROOT = "/Game/ArtCandidates/CellarBat/R01/"
MACHINE = "Bat"

# EMars_Bat_Phase (Script/ECS/Bat/Mars_Bat_Feature.as) as PhaseIndex values.
P = {n: i for i, n in enumerate([
    "Roosting", "Alert", "Launching", "Patrolling", "Approaching", "Telegraphing", "Swooping", "Recovering", "Returning",
    "Braking", "Perching", "Hovering", "Hit", "Stunned", "Falling", "Landed", "Dead", "Screeching"])}

# AnimBP state -> the kernel phases it shows.
PHASES = {
    "RoostIdle": ["Roosting"],
    "RoostAlert": ["Alert"],
    "Launch": ["Launching"],
    "Locomotion": ["Patrolling", "Approaching", "Returning", "Hovering"],
    "Telegraph": ["Telegraphing"],
    "Swoop": ["Swooping"],
    "Recover": ["Recovering"],
    "Brake": ["Braking"],
    "Perch": ["Perching"],
    "Screech": ["Screeching"],
    "Hit": ["Hit"],
    "Stun": ["Stunned"],
    "DeathFall": ["Falling"],
    "DeathLand": ["Landed", "Dead"],
}
STATES = list(PHASES.keys())

# Crossfade into each state (s). Settle-friendly: hangs and perches ease in, strikes and hits snap.
BLEND_SECONDS = {
    "RoostIdle": 0.35, "RoostAlert": 0.25, "Launch": 0.2, "Locomotion": 0.25, "Telegraph": 0.15, "Swoop": 0.1,
    "Recover": 0.2, "Brake": 0.2, "Perch": 0.3, "Screech": 0.15, "Hit": 0.08, "Stun": 0.15, "DeathFall": 0.1,
    "DeathLand": 0.15,
}

# Clips that are one-shots when the manifest names no "loops" list (prep loops everything so the flap is visible in every
# state). The final manifest lists its loops (RoostIdle, Hover, FlyForward, Glide, Stun); every other state plays once and
# holds its last frame until the kernel's next phase takes it out.
ONE_SHOTS = {"Launch", "Swoop", "Recover", "Brake", "Perch", "Screech", "Hit", "DeathLand"}


def state_loops(m, state):
    if m.get("loop_all_for_prep", False):
        return True
    if "loops" in m:
        return state in m["loops"]
    return state not in ONE_SHOTS


class MonolithError(RuntimeError):
    pass


_log = []


def call(tool, action, params, timeout=300):
    body = {"jsonrpc": "2.0", "id": 1, "method": "tools/call",
            "params": {"name": tool, "arguments": {"action": action, "params": params}}}
    req = urllib.request.Request(MONOLITH, data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json", "Accept": "application/json, text/event-stream"})
    raw = urllib.request.urlopen(req, timeout=timeout).read().decode()
    res = json.loads(raw)
    if "error" in res:
        raise MonolithError("%s.%s: %s" % (tool, action, res["error"]))
    result = res["result"]
    text = "".join(c.get("text", "") for c in result.get("content", []))
    try:
        data = json.loads(text)
    except ValueError:
        data = {"text": text}
    entry = {"tool": tool, "action": action, "params": params, "ok": not result.get("isError", False)}
    _log.append(entry)
    if result.get("isError"):
        raise MonolithError("%s.%s failed: %s" % (tool, action, text[:2000]))
    return data


def anim(action, **params):
    return call("animation_query", action, params)


def py(code):
    """Run editor Python; returns the printed lines. The code must print 'RESULT:' + json on its last line to return data."""
    data = call("editor_query", "run_python", {"command": code, "unattended": True})
    out = "".join(o.get("output", "") for o in data.get("output", []) if o.get("type") == "info")
    errs = "".join(o.get("output", "") for o in data.get("output", []) if o.get("type") == "error")
    if not data.get("success", False) or errs:
        raise MonolithError("run_python failed: %s" % json.dumps(data)[-3000:])
    for line in reversed(out.splitlines()):
        if line.startswith("RESULT:"):
            return json.loads(line[len("RESULT:"):])
    return out


def obj_path(asset):
    name = asset.rsplit("/", 1)[1]
    return asset if "." in name else "%s.%s" % (asset, name)


def additive_path(m, clip):
    """The bank the Locomotion state adds: the manifest's clip itself when it is already additive ("banks_additive": the
    final banks import as LocalSpaceBase against Hover frame 0), else an additive copy under additive_dir (prep)."""
    if m.get("banks_additive", False):
        return m["clips"][clip]
    return "%s/CellarBat_R01_%s_Add_Mars_ANIM" % (m["additive_dir"], clip)


def owned_outputs(m):
    """The assets this build writes and saves: the ABP, the blend space, and the additive copies when it makes them."""
    out = [m["abp"], m["blend_space"]]
    if not m.get("banks_additive", False):
        out += [additive_path(m, "BankLeft"), additive_path(m, "BankRight")]
    return out


CONTENT_DIR = "D:/Repositories/CkRepos/Orion/Content/"


def disk_file(asset):
    return CONTENT_DIR + asset[len("/Game/"):] + ".uasset"


def resolve_abp_target(m):
    """Never rebuild over an existing AnimBP: the manifest's name when no .uasset exists on disk, else the first free
    <name>_v<N> (N from 2). Clearing a live AnimBP in place leaves the removed graphs in the package, and deleting one the
    editor has loaded fails (see the docstring). Returns the asset path to build."""
    base = m["abp"]
    if not os.path.exists(disk_file(base)):
        return base
    n = 2
    while os.path.exists(disk_file("%s_v%d" % (base, n))):
        n += 1
    return "%s_v%d" % (base, n)


def check_ground(m):
    owned = owned_outputs(m)
    for a in owned:
        if not a.startswith(OWNED_ROOT):
            raise MonolithError("refusing to write outside %s: %s" % (OWNED_ROOT, a))
    code = (
        "import unreal, json\n"
        "proj = unreal.Paths.convert_relative_path_to_full(unreal.Paths.get_project_file_path())\n"
        "pie = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_game_world() is not None\n"
        "cls = unreal.load_class(None, %r)\n"
        "ea = unreal.EditorAssetLibrary\n"
        "ex = {p: ea.does_asset_exist(p) for p in %r}\n"
        "print('RESULT:' + json.dumps({'project': proj, 'pie': pie, 'parent': str(cls.get_path_name()) if cls else None, 'exists': ex}))\n"
    ) % (m["parent_class"], owned_outputs(m) + [additive_path(m, "BankLeft"), additive_path(m, "BankRight")])
    g = py(code)
    if g["project"] != EXPECTED_PROJECT:
        raise MonolithError("Monolith answers for %s, not %s" % (g["project"], EXPECTED_PROJECT))
    if g["pie"]:
        raise MonolithError("PIE is running: stop it first")
    if not g["parent"]:
        raise MonolithError("parent class %s does not load" % m["parent_class"])
    return g


def build_additives(m, exists):
    if m.get("banks_additive", False):
        return {clip: m["clips"][clip] for clip in ("BankLeft", "BankRight")}
    out = {}
    for clip in ("BankLeft", "BankRight"):
        dest = additive_path(m, clip)
        if not exists.get(dest):
            anim("duplicate_sequence", source_path=m["clips"][clip], dest_path=dest)
        anim("set_additive_settings", asset_path=dest, additive_anim_type="LocalSpace", ref_pose_type="AnimFrame", ref_frame_index=0)
        out[clip] = dest
    return out


def build_blend_space(m, exists):
    bs = m["blend_space"]
    s = m["locomotion_speeds"]
    if not exists.get(bs):
        anim("create_blend_space_1d", asset_path=bs, skeleton_path=m["skeleton"], axis_name="Speed", axis_min=0.0, axis_max=s["axis_max"])
    else:
        info = anim("get_blend_space_info", asset_path=bs)
        for i in reversed(range(len(info.get("samples", [])))):
            anim("delete_blendspace_sample", asset_path=bs, sample_index=i)
        anim("set_blend_space_axis", asset_path=bs, axis="X", name="Speed", min=0.0, max=s["axis_max"])
    for clip in ("Hover", "FlyForward", "Glide"):
        anim("add_blendspace_sample", asset_path=bs, anim_path=m["clips"][clip], x=s[clip], y=0.0)
    anim("bake_blend_space", asset_path=bs)
    return anim("get_blend_space_info", asset_path=bs)


def anim_graph_nodes(m):
    return anim("get_nodes", asset_path=m["abp"], graph_name="AnimGraph").get("nodes", [])


def _node_name(resp):
    for k in ("node_name", "node_id", "name", "node"):
        v = resp.get(k)
        if isinstance(v, str) and v:
            return v
        if isinstance(v, dict) and v.get("name"):
            return v["name"]
    raise MonolithError("no node name in %s" % json.dumps(resp)[:500])


def build_graph(m, additives):
    abp = m["abp"]
    sm = anim("build_state_machine", asset_path=abp, state_machine_name=MACHINE,
              states=[{"name": s} for s in STATES], entry_state="RoostIdle")
    # build_state_machine reports the graph, not the node: find the AnimGraph's state machine node titled MACHINE.
    sm_nodes = [n["name"] for n in anim_graph_nodes(m)
                if n["class"] == "AnimGraphNode_StateMachine" and n.get("title", "").splitlines()[0] == MACHINE]
    if len(sm_nodes) != 1:
        raise MonolithError("expected one '%s' state machine node, found %s (build: %s)" % (MACHINE, sm_nodes, json.dumps(sm)[:800]))
    sm_node = sm_nodes[0]
    anim("set_output_pose_source", asset_path=abp, source_node=sm_node)

    for s in STATES:
        if s == "Locomotion":
            continue
        anim("set_state_animation", asset_path=abp, machine_name=MACHINE, state_name=s, anim_asset_path=m["clips"][s],
             loop=bool(state_loops(m, s)))

    # Locomotion: speed blend space, then the two bank layers.
    bsp = _node_name(anim("add_anim_graph_node", asset_path=abp, graph_name=MACHINE, state_name="Locomotion",
                          node_type="BlendSpacePlayer", anim_asset=m["blend_space"], position_x=-600, position_y=0))
    right = _node_name(anim("add_anim_graph_node", asset_path=abp, graph_name=MACHINE, state_name="Locomotion",
                            node_type="SequencePlayer", anim_asset=additives["BankRight"], position_x=-600, position_y=250))
    left = _node_name(anim("add_anim_graph_node", asset_path=abp, graph_name=MACHINE, state_name="Locomotion",
                           node_type="SequencePlayer", anim_asset=additives["BankLeft"], position_x=-300, position_y=400))
    add_r = _node_name(anim("add_apply_additive", asset_path=abp, graph_name=MACHINE, state_name="Locomotion",
                            base_node=bsp, additive_node=right, alpha=0.0, position_x=-300, position_y=0))
    add_l = _node_name(anim("add_apply_additive", asset_path=abp, graph_name=MACHINE, state_name="Locomotion",
                            base_node=add_r, additive_node=left, alpha=0.0, position_x=0, position_y=0))
    anim("set_anim_node_pin_binding", asset_path=abp, node_id=bsp, pin="X", path=["Speed"])
    anim("set_anim_node_pin_binding", asset_path=abp, node_id=add_r, pin="Alpha", path=["BankRightAlpha"])
    anim("set_anim_node_pin_binding", asset_path=abp, node_id=add_l, pin="Alpha", path=["BankLeftAlpha"])
    anim("set_state_result_source", asset_path=abp, machine_name=MACHINE, state_name="Locomotion", source_node=add_l)
    loco = {"blend_space_player": bsp, "bank_right_player": right, "bank_left_player": left,
            "apply_additive_right": add_r, "apply_additive_left": add_l}

    # Full mesh (Monolith's add_transition does not resolve conduits, so no Router hub): S -> T for every routed pair, rule
    # "PhaseIndex is one of T's phases". The phase sets are disjoint, so at most one rule out of a state holds.
    rules = []
    routed = [s for s in STATES if PHASES[s]]
    for s in routed:
        for t in routed:
            if s == t:
                continue
            anim("add_transition", asset_path=abp, machine_name=MACHINE, from_state=s, to_state=t)
            terms = [{"lhs": "PhaseValue", "op": "==", "rhs": float(P[p])} for p in PHASES[t]]
            rule = {"kind": "expression", "combine": "or", "terms": terms}
            anim("set_transition_rule", asset_path=abp, machine_name=MACHINE, from_state=s, to_state=t, rule=rule)
            rules.append([s, t])
    return {"state_machine_node": sm_node, "locomotion": loco, "transitions": len(rules), "pairs": rules}


SET_BLENDS = r'''
import unreal, json, re
# Python cannot read a transition node's states, so the nodes are matched to the builder's creation order (their
# AnimStateTransitionNode_<n> suffixes rise in creation order); get_transitions reads the result back by from/to.
order = %(order)r
live = "%(sm_node)s.%(machine)s."
nodes = [t for t in unreal.ObjectIterator(unreal.AnimStateTransitionNode) if live in t.get_path_name()
         and t.get_path_name().startswith(%(abp)r)]
nodes.sort(key=lambda t: int(re.findall(r"\d+$", t.get_name())[0]))
if len(nodes) != len(order):
    raise RuntimeError("found %%d transition nodes under %%s, expected %%d" %% (len(nodes), live, len(order)))
for t, (a, b, secs) in zip(nodes, order):
    t.set_editor_property("crossfade_duration", float(secs))
print("RESULT:" + json.dumps({"set": len(nodes)}))
'''

COMPILE = r'''
import unreal, json
abp = unreal.load_asset(%(abp)r)
unreal.BlueprintEditorLibrary.compile_blueprint(abp)
gen = unreal.BlueprintEditorLibrary.generated_class(abp)
print("RESULT:" + json.dumps({"generated": gen.get_path_name() if gen else None}))
'''

SAVE = r'''
import unreal, json
saved = {}
for p in %(paths)r:
    saved[p] = unreal.EditorAssetLibrary.save_asset(p, only_if_is_dirty=False)
dirty = [str(x.get_name()) for x in unreal.EditorLoadingAndSavingUtils.get_dirty_content_packages()] + \
        [str(x.get_name()) for x in unreal.EditorLoadingAndSavingUtils.get_dirty_map_packages()]
print("RESULT:" + json.dumps({"saved": saved, "dirty_after": dirty}))
'''


def set_blends(m, graph):
    order = [[a, b, BLEND_SECONDS[b]] for a, b in graph["pairs"]]
    res = py(SET_BLENDS % {"abp": obj_path(m["abp"]), "order": order, "sm_node": graph["state_machine_node"], "machine": MACHINE})
    # Verify by from/to on the readback (Monolith get_transitions reports cross_fade_duration).
    got = {(t["from"], t["to"]): t["cross_fade_duration"] for t in anim("get_transitions", asset_path=m["abp"], machine_name=MACHINE)["transitions"]}
    bad = [[a, b, want, got.get((a, b))] for a, b, want in order if got.get((a, b)) is None or abs(got[(a, b)] - want) > 1e-4]
    if bad:
        raise MonolithError("crossfades did not read back: %s" % bad[:10])
    res["verified"] = len(order)
    return res


def compile_abp(m):
    res = py(COMPILE % {"abp": obj_path(m["abp"])})
    errored = anim_tool_free("editor_query", "list_errored_blueprints", {})
    res["errored_blueprints"] = errored.get("blueprints", [])
    res["ok"] = bool(res["generated"]) and not any(m["abp"] in json.dumps(b) for b in res["errored_blueprints"])
    return res


def anim_tool_free(tool, action, params):
    return call(tool, action, params)


def readback(m):
    abp = m["abp"]
    rb = {"abp_info": anim("get_abp_info", asset_path=abp),
          "state_machines": anim("get_state_machines", asset_path=abp),
          "transitions": anim("get_transitions", asset_path=abp, machine_name=MACHINE),
          "output": anim("get_anim_graph_output_connection", abp_path=abp),
          "locomotion_state": anim("get_state_info", asset_path=abp, machine_name=MACHINE, state_name="Locomotion"),
          "pin_bindings": anim("get_anim_node_pin_bindings", asset_path=abp),
          "blend_space": anim("get_blend_space_info", asset_path=m["blend_space"])}
    return rb


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--no-save", action="store_true")
    ap.add_argument("--readback-only", action="store_true")
    a = ap.parse_args(argv)
    with open(a.manifest, encoding="utf-8") as f:
        m = json.load(f)
    out_path = os.path.splitext(a.manifest)[0] + "_readback.json"
    report = {"manifest": os.path.abspath(a.manifest), "manifest_abp": m["abp"]}
    try:
        if not a.readback_only:
            m["abp"] = resolve_abp_target(m)
        report["abp"] = m["abp"]
        print("building" if not a.readback_only else "reading", m["abp"])
        g = check_ground(m)
        report["ground"] = g
        if not a.readback_only:
            if g["exists"][m["abp"]]:
                raise MonolithError("%s is loaded in the editor but has no .uasset on disk: refusing to touch it" % m["abp"])
            report["create"] = anim("create_anim_blueprint", asset_path=m["abp"], skeleton_path=m["skeleton"], parent_class=m["parent_class"])
            additives = build_additives(m, g["exists"])
            report["blend_space_built"] = build_blend_space(m, g["exists"])
            report["graph"] = build_graph(m, additives)
            try:
                report["blends"] = set_blends(m, report["graph"])
            except MonolithError as e:
                report["blends"] = {"error": str(e)}
            anim("auto_layout", asset_path=m["abp"], graph_name="all")
        if a.readback_only:   # never compile here: a compile can dirty the package
            errored = call("editor_query", "list_errored_blueprints", {}).get("blueprints", [])
            report["compile"] = {"skipped": True, "errored_blueprints": errored,
                                 "ok": not any(m["abp"] in json.dumps(b) for b in errored)}
        else:
            report["compile"] = compile_abp(m)
        report["readback"] = readback(m)
        if not a.no_save and not a.readback_only:
            report["save"] = py(SAVE % {"paths": owned_outputs(m)})
        report["ok"] = report["compile"]["ok"] and "error" not in report.get("blends", {})
    except Exception as e:  # report what got done
        report["error"] = "%s: %s" % (type(e).__name__, e)
        report["ok"] = False
    report["calls"] = _log
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=1)
    print("readback ->", out_path)
    print("CELLAR_BAT_ABP_OK" if report["ok"] else "CELLAR_BAT_ABP_FAIL " + report.get("error", "compile status " + str(report.get("compile"))))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
