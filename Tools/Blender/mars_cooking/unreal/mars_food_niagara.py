"""Builds OilBubbles_Mars_NS (Niagara mesh-particle oil bubbles) in a running editor through Monolith's niagara_query
actions. Runs OUTSIDE the editor (plain Python 3, no `unreal`):

    python mars_food_niagara.py                 # Monolith on http://localhost:9316/mcp (the interactive editor)
    python mars_food_niagara.py --port 9317

The editor's Python cannot author Niagara module stacks (it exposes the factories, the clipboard utilities and the
NiagaraComponent API, not stack editing), so the stack is built with Monolith: an empty CPU emitter, local space,
Spawn Rate bound to User.SpawnRate, two custom-HLSL modules (MarsBubbleSpawn / MarsBubbleUpdate, bodies in
mars_food_hlsl) whose inputs are bound to the system's User.* parameters (mars_food_plan.NIAGARA_USER), the stock
Dynamic Material Parameters module (registers Particles.DynamicMaterialParameter, which MarsBubbleUpdate overwrites:
x = pop, y = phase), and a mesh renderer on OilBubble_Mars_SM (its slot carries OilBubbleParticle_Mars_MI).
Re-running replaces the system and the two module scripts.
"""
import argparse
import json
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
for _p in (HERE, os.path.dirname(HERE)):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import food_spec as fs  # noqa: E402
import mars_food_hlsl as hlsl  # noqa: E402
import mars_food_plan as plan  # noqa: E402

NS = "%s/%s" % (plan.NIAGARA_FOLDER, plan.NIAGARA_BUBBLES)
EMITTER = "Bubbles"
SPAWN_MODULE = "%s/MarsBubbleSpawn_Mars_NM" % plan.NIAGARA_MODULES
UPDATE_MODULE = "%s/MarsBubbleUpdate_Mars_NM" % plan.NIAGARA_MODULES
MESH = "%s/Meshes/OilBubble_Mars_SM.OilBubble_Mars_SM" % fs.UE_FOLDER
SPAWN_RATE = "/Niagara/Modules/Emitter/SpawnRate.SpawnRate"
DYNAMIC_PARAMS = "/Niagara/Modules/Update/Material/DynamicMaterialParameters.DynamicMaterialParameters"
TYPES = {"float": "float", "vec2": "vec2", "color": "color"}
SPLATTER_NS = "%s/%s" % (plan.NIAGARA_FOLDER, plan.NIAGARA_SPLATTER)
SPLATTER_EMITTER = "Splatter"
SPLATTER_SPAWN_MODULE = "%s/MarsSplatterSpawn_Mars_NM" % plan.NIAGARA_MODULES
SPLATTER_UPDATE_MODULE = "%s/MarsSplatterUpdate_Mars_NM" % plan.NIAGARA_MODULES
PLANE = "/Engine/BasicShapes/Plane.Plane"
SPLATTER_MI = "%s/Materials/Instances/%s.%s" % (fs.UE_FOLDER, plan.SPLATTER_MI, plan.SPLATTER_MI)


class Monolith:
    def __init__(self, port):
        self.url = "http://localhost:%d/mcp" % port
        self.sid, self.rpc = None, 0
        self._post({"jsonrpc": "2.0", "id": self._id(), "method": "initialize", "params": {
            "protocolVersion": "2025-03-26", "capabilities": {}, "clientInfo": {"name": "mars_food_niagara", "version": "1"}}})
        try:
            self._post({"jsonrpc": "2.0", "method": "notifications/initialized"})
        except Exception:
            pass

    def _id(self):
        self.rpc += 1
        return self.rpc

    def _post(self, payload, timeout=600):
        req = urllib.request.Request(self.url, data=json.dumps(payload).encode(), method="POST", headers={
            "Content-Type": "application/json", "Accept": "application/json, text/event-stream"})
        if self.sid:
            req.add_header("Mcp-Session-Id", self.sid)
        with urllib.request.urlopen(req, timeout=timeout) as r:
            self.sid = r.headers.get("Mcp-Session-Id") or self.sid
            body = r.read().decode("utf-8", "replace")
        if body.startswith("event:") or "\ndata:" in body or body.startswith("data:"):
            chunks = [l[5:].strip() for l in body.splitlines() if l.startswith("data:")]
            body = chunks[-1] if chunks else "{}"
        return json.loads(body) if body.strip() else {}

    def call(self, tool, action, params, check=True):
        rep = self._post({"jsonrpc": "2.0", "id": self._id(), "method": "tools/call",
                          "params": {"name": tool, "arguments": {"action": action, "params": params}}})
        res = rep.get("result", {})
        text = "\n".join(c.get("text", "") for c in res.get("content", []) if c.get("type") == "text")
        try:
            out = json.loads(text)
        except ValueError:
            out = text
        if check and (rep.get("error") or res.get("isError")):
            raise RuntimeError("%s.%s failed: %s" % (tool, action, (rep.get("error") or text)))
        return out

    def niagara(self, action, check=True, **params):
        return self.call("niagara_query", action, params, check)

    def python(self, code):
        return self.call("editor_query", "run_python", {"command": code, "unattended": True})


def log(msg):
    print("MarsFoodNiagara: %s" % msg)


def _default(kind, value):
    if kind == "vec2":
        return {"x": value[0], "y": value[1]}
    if kind == "color":
        return {"r": value[0], "g": value[1], "b": value[2], "a": value[3]}
    return value


def _module_node(m, usage, script_name, ns=NS, emitter=EMITTER):
    """The stack node id of a module (by script / display name) in one stage, from the emitter summary."""
    summary = m.niagara("get_emitter_summary", asset_path=ns, emitter=emitter)
    for mod in summary.get("modules", {}).get(usage, []):
        if script_name.lower() in mod.get("name", "").lower().replace(" ", ""):
            return mod.get("guid") or mod.get("name")
    raise RuntimeError("module %s not found in %s: %s" % (script_name, usage, summary.get("modules", {}).get(usage)))


def build(port=9316):
    m = Monolith(port)
    # fresh assets: the system and the two module scripts are generated (a placed actor keeps its overrides)
    m.python("import unreal\n"
             "for p in (%r, %r, %r):\n"
             "    if unreal.EditorAssetLibrary.does_asset_exist(p):\n"
             "        unreal.EditorAssetLibrary.delete_asset(p)\n" % (NS, SPAWN_MODULE, UPDATE_MODULE))
    m.niagara("create_module_from_hlsl", name="MarsBubbleSpawn", save_path=SPAWN_MODULE, hlsl=hlsl.NS_BUBBLE_SPAWN,
              inputs=[{"name": n, "type": TYPES[k]} for n, k, _ in plan.NIAGARA_USER if n in plan.NIAGARA_SPAWN_INPUTS],
              description="Mars oil bubbles: spawn in a disc / box below the surface, random radius, life, phase.")
    m.niagara("create_module_from_hlsl", name="MarsBubbleUpdate", save_path=UPDATE_MODULE, hlsl=hlsl.NS_BUBBLE_UPDATE,
              inputs=[{"name": n, "type": TYPES[k]} for n, k, _ in plan.NIAGARA_USER if n in plan.NIAGARA_UPDATE_INPUTS]
              + [{"name": "DeltaTime", "type": "float"}],
              description="Mars oil bubbles: rise (ease-out), ride (wobble + pulse), pop (DynamicParameter.x, ring scale, apex sink).")
    log("module scripts created")

    m.niagara("create_system", save_path=NS)
    m.niagara("create_emitter", asset_path=NS, name=EMITTER, sim_target="cpu")
    m.niagara("set_emitter_property", asset_path=NS, emitter=EMITTER, property="bLocalSpace", value="true")
    for name, kind, value in plan.NIAGARA_USER:
        m.niagara("add_user_parameter", asset_path=NS, name=name, type=TYPES[kind], default=_default(kind, value))
    log("system, emitter (CPU, local space) and %d user parameters" % len(plan.NIAGARA_USER))

    # emitter update: spawn rate from the user parameter
    m.niagara("add_module", asset_path=NS, emitter=EMITTER, usage="emitter_update", module_script=SPAWN_RATE)
    node = _module_node(m, "emitter_update", "SpawnRate")
    m.niagara("set_module_input_binding", asset_path=NS, emitter=EMITTER, module_node=node, input="SpawnRate",
              binding="User.SpawnRate")
    # particle spawn: after InitializeParticle
    m.niagara("add_module", asset_path=NS, emitter=EMITTER, usage="particle_spawn",
              module_script=SPAWN_MODULE + "." + SPAWN_MODULE.rsplit("/", 1)[1])
    node = _module_node(m, "particle_spawn", "MarsBubbleSpawn")
    for name in plan.NIAGARA_SPAWN_INPUTS:
        m.niagara("set_module_input_binding", asset_path=NS, emitter=EMITTER, module_node=node, input=name,
                  binding="User.%s" % name)
    # particle update: ParticleState, Dynamic Material Parameters (registers the attribute), then MarsBubbleUpdate
    m.niagara("add_module", asset_path=NS, emitter=EMITTER, usage="particle_update", module_script=DYNAMIC_PARAMS)
    m.niagara("add_module", asset_path=NS, emitter=EMITTER, usage="particle_update",
              module_script=UPDATE_MODULE + "." + UPDATE_MODULE.rsplit("/", 1)[1])
    node = _module_node(m, "particle_update", "MarsBubbleUpdate")
    for name in plan.NIAGARA_UPDATE_INPUTS:
        m.niagara("set_module_input_binding", asset_path=NS, emitter=EMITTER, module_node=node, input=name,
                  binding="User.%s" % name)
    m.niagara("set_module_input_binding", asset_path=NS, emitter=EMITTER, module_node=node, input="DeltaTime",
              binding="Engine.DeltaTime")
    log("modules: SpawnRate, MarsBubbleSpawn, DynamicMaterialParameters, MarsBubbleUpdate")

    # renderer: the bubble mesh (its slot material is OilBubbleParticle_Mars_MI), no facing (mesh orientation up)
    m.niagara("remove_renderer", asset_path=NS, emitter=EMITTER, renderer_index=0, check=False)
    m.niagara("add_renderer", asset_path=NS, emitter=EMITTER, **{"class": "Mesh"})
    m.niagara("set_renderer_mesh", asset_path=NS, emitter=EMITTER, renderer_index=0, mesh=MESH)
    m.niagara("request_compile", asset_path=NS)
    diag = m.niagara("get_system_diagnostics", asset_path=NS)
    m.niagara("save_system", asset_path=NS, check=False)
    log("compiled: %d errors, %d warnings" % (diag.get("error_count", -1), diag.get("warning_count", -1)))
    for e in diag.get("errors", []) + diag.get("warnings", []):
        log("  %s: %s" % (e.get("source"), e.get("message")))
    return diag


def build_splatter(port=9316):
    """OilSplatter_Mars_NS: one CPU, local-space emitter "Splatter": SpawnRate (User.SplatterRate), MarsSplatterSpawn
    after InitializeParticle, MarsSplatterUpdate after ParticleState, a mesh renderer on the engine plane with
    OilSplatter_Mars_MI (flat droplets on the XY plane). Separate from OilBubbles_Mars_NS so neither rebuild touches the
    other system."""
    m = Monolith(port)
    ns, em = SPLATTER_NS, SPLATTER_EMITTER
    m.python("import unreal\n"
             "for p in (%r, %r, %r):\n"
             "    if unreal.EditorAssetLibrary.does_asset_exist(p):\n"
             "        unreal.EditorAssetLibrary.delete_asset(p)\n" % (ns, SPLATTER_SPAWN_MODULE, SPLATTER_UPDATE_MODULE))
    user = plan.NIAGARA_SPLATTER_USER
    m.niagara("create_module_from_hlsl", name="MarsSplatterSpawn", save_path=SPLATTER_SPAWN_MODULE,
              hlsl=hlsl.NS_SPLATTER_SPAWN,
              inputs=[{"name": n, "type": TYPES[k]} for n, k, _ in user if n in plan.NIAGARA_SPLATTER_SPAWN_INPUTS]
              + [{"name": "Time", "type": "float"}],
              description="Mars oil splatter: droplets at the footprint edge, bursts share a direction.")
    m.niagara("create_module_from_hlsl", name="MarsSplatterUpdate", save_path=SPLATTER_UPDATE_MODULE,
              hlsl=hlsl.NS_SPLATTER_UPDATE,
              inputs=[{"name": n, "type": TYPES[k]} for n, k, _ in user if n in plan.NIAGARA_SPLATTER_UPDATE_INPUTS]
              + [{"name": "DeltaTime", "type": "float"}],
              description="Mars oil splatter: fling outward, land flat, spread, fade.")
    m.niagara("create_system", save_path=ns)
    m.niagara("create_emitter", asset_path=ns, name=em, sim_target="cpu")
    m.niagara("set_emitter_property", asset_path=ns, emitter=em, property="bLocalSpace", value="true")
    for name, kind, value in user:
        m.niagara("add_user_parameter", asset_path=ns, name=name, type=TYPES[kind], default=_default(kind, value))
    m.niagara("add_module", asset_path=ns, emitter=em, usage="emitter_update", module_script=SPAWN_RATE)
    node = _module_node(m, "emitter_update", "SpawnRate", ns, em)
    m.niagara("set_module_input_binding", asset_path=ns, emitter=em, module_node=node, input="SpawnRate",
              binding="User.SplatterRate")
    m.niagara("add_module", asset_path=ns, emitter=em, usage="particle_spawn",
              module_script=SPLATTER_SPAWN_MODULE + "." + SPLATTER_SPAWN_MODULE.rsplit("/", 1)[1])
    node = _module_node(m, "particle_spawn", "MarsSplatterSpawn", ns, em)
    for name in plan.NIAGARA_SPLATTER_SPAWN_INPUTS:
        m.niagara("set_module_input_binding", asset_path=ns, emitter=em, module_node=node, input=name,
                  binding="User.%s" % name)
    # Emitter.Age, not Engine.Time: the burst slots must advance with the simulation (AdvanceSimulation / warm-up)
    m.niagara("set_module_input_binding", asset_path=ns, emitter=em, module_node=node, input="Time", binding="Emitter.Age")
    m.niagara("add_module", asset_path=ns, emitter=em, usage="particle_update",
              module_script=SPLATTER_UPDATE_MODULE + "." + SPLATTER_UPDATE_MODULE.rsplit("/", 1)[1])
    node = _module_node(m, "particle_update", "MarsSplatterUpdate", ns, em)
    for name in plan.NIAGARA_SPLATTER_UPDATE_INPUTS:
        m.niagara("set_module_input_binding", asset_path=ns, emitter=em, module_node=node, input=name,
                  binding="User.%s" % name)
    m.niagara("set_module_input_binding", asset_path=ns, emitter=em, module_node=node, input="DeltaTime",
              binding="Engine.DeltaTime")
    m.niagara("remove_renderer", asset_path=ns, emitter=em, renderer_index=0, check=False)
    m.niagara("add_renderer", asset_path=ns, emitter=em, **{"class": "Mesh"})
    m.niagara("set_renderer_mesh", asset_path=ns, emitter=em, renderer_index=0, mesh=PLANE)
    m.niagara("set_renderer_material", asset_path=ns, emitter=em, renderer_index=0, material=SPLATTER_MI)
    m.niagara("request_compile", asset_path=ns)
    diag = m.niagara("get_system_diagnostics", asset_path=ns)
    m.niagara("save_system", asset_path=ns, check=False)
    log("splatter compiled: %d errors, %d warnings" % (diag.get("error_count", -1), diag.get("warning_count", -1)))
    for e in diag.get("errors", []) + diag.get("warnings", []):
        log("  %s: %s" % (e.get("source"), e.get("message")))
    return diag


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=9316)
    ap.add_argument("--what", choices=("bubbles", "splatter", "all"), default="all",
                    help="bubbles rebuilds OilBubbles_Mars_NS (discards hand edits to it), splatter OilSplatter_Mars_NS")
    a = ap.parse_args()
    errors = 0
    if a.what in ("bubbles", "all"):
        errors += build(a.port).get("error_count", 0)
    if a.what in ("splatter", "all"):
        errors += build_splatter(a.port).get("error_count", 0)
    sys.exit(1 if errors else 0)
