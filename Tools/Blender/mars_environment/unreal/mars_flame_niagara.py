"""Builds Flame_Mars_NS (the one looping flame + glow + embers effect every Mars flame wears: torch, lantern, wall torch,
brazier, sconce) in a running editor through Monolith's niagara_query actions, on the mars_food_niagara model. Runs
OUTSIDE the editor (plain Python 3, no `unreal`):

    python mars_flame_niagara.py                 # Monolith on http://localhost:9316/mcp (the interactive editor)
    python mars_flame_niagara.py --port 9317     # the hidden editor (env_drive.py --port 9317 --launch first)
    python mars_flame_niagara.py --what materials # only the three sprite materials (mars_flame_ue, inside the editor)

Contract (what Script/WorldObjects/Items/Mars_FlameDressing.as writes; FLAME_FX.md beside this file has the hand-authoring
recipe for when Monolith is down):
    User.Size       float   tongue height in cm (torch 18, lantern 10, brazier 45, hearth 60)
    User.Intensity  float   0..1, the kernel's brightness (fuel scale x flicker); 0 is dark
    User.Colour     color   the flame's colour (the light's)
    User.EmberRate  float   embers per second (torch 6, lantern 0, brazier 20)
    User.Wind       vec3    world cm/s the flame streams against (the carrier's velocity negated)
    User.Enclosed   float   0 open, 1 behind glass: tongues clamp inside the lantern, no embers
Three CPU, local-space emitters: Tongues (SpawnRate 22, MarsTongueSpawn / MarsTongueUpdate), Embers (SpawnRate bound to
User.EmberRate, MarsEmberSpawn / MarsEmberUpdate), Glow (SpawnRate 2, MarsGlowSpawn / MarsGlowUpdate); each a sprite
renderer on its material instance, the stock Dynamic Material Parameters module registering the attribute the update
module overwrites (x phase, y age, z Intensity, w Enclosed). Looping, persistent: no one-shot effect type. Re-running
replaces the system and the module scripts.
"""
import argparse
import json
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import mars_flame_hlsl as hlsl  # noqa: E402

FX_FOLDER = "/Game/Mars/Fx/Flame"
NS = FX_FOLDER + "/Flame_Mars_NS"
MODULES = FX_FOLDER + "/Modules"
F_MAT = FX_FOLDER + "/Materials"
SPAWN_RATE = "/Niagara/Modules/Emitter/SpawnRate.SpawnRate"
DYNAMIC_PARAMS = "/Niagara/Modules/Update/Material/DynamicMaterialParameters.DynamicMaterialParameters"

# (name, Niagara type, default)
USER = (
    ("Size", "float", 18.0), ("Intensity", "float", 1.0), ("Colour", "color", (1.0, 0.55, 0.25, 1.0)),
    ("EmberRate", "float", 6.0), ("Wind", "vec3", (0.0, 0.0, 0.0)), ("Enclosed", "float", 0.0),
)
TYPES = {"float": "float", "vec3": "vec3", "color": "color"}

# emitter: (spawn-rate binding or constant, spawn module, update module, spawn inputs, update inputs, material instance)
EMITTERS = {
    "Tongues": dict(rate=22.0, spawn=("MarsTongueSpawn", hlsl.NS_TONGUE_SPAWN, ("Size", "Colour", "Enclosed")),
                    update=("MarsTongueUpdate", hlsl.NS_TONGUE_UPDATE, ("Size", "Intensity", "Wind", "Enclosed")),
                    material="FlameSprite_Mars_MI", align="velocity"),
    "Embers": dict(rate="User.EmberRate", spawn=("MarsEmberSpawn", hlsl.NS_EMBER_SPAWN, ("Size", "Colour", "Enclosed")),
                   update=("MarsEmberUpdate", hlsl.NS_EMBER_UPDATE, ("Size", "Intensity", "Wind")),
                   material="EmberSprite_Mars_MI", align="camera", delta=True),
    "Glow": dict(rate=2.0, spawn=("MarsGlowSpawn", hlsl.NS_GLOW_SPAWN, ("Size", "Colour")),
                 update=("MarsGlowUpdate", hlsl.NS_GLOW_UPDATE, ("Size", "Intensity", "Wind")),
                 material="FlameGlow_Mars_MI", align="camera"),
}


class Monolith:
    def __init__(self, port):
        self.url = "http://localhost:%d/mcp" % port
        self.sid, self.rpc = None, 0
        self._post({"jsonrpc": "2.0", "id": self._id(), "method": "initialize", "params": {
            "protocolVersion": "2025-03-26", "capabilities": {}, "clientInfo": {"name": "mars_flame_niagara", "version": "1"}}})
        try:
            self._post({"jsonrpc": "2.0", "method": "notifications/initialized"})
        except Exception:
            pass

    def _id(self):
        self.rpc += 1
        return self.rpc

    def _post(self, payload, timeout=900):
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
    print("MarsFlameNiagara: %s" % msg)


def _default(kind, value):
    if kind == "vec3":
        return {"x": value[0], "y": value[1], "z": value[2]}
    if kind == "color":
        return {"r": value[0], "g": value[1], "b": value[2], "a": value[3]}
    return value


def _module_node(m, usage, script_name, emitter):
    """The stack node id of a module (by script / display name) in one stage, from the emitter summary."""
    summary = m.niagara("get_emitter_summary", asset_path=NS, emitter=emitter)
    for mod in summary.get("modules", {}).get(usage, []):
        if script_name.lower() in mod.get("name", "").lower().replace(" ", ""):
            return mod.get("guid") or mod.get("name")
    raise RuntimeError("module %s not found in %s/%s: %s" % (script_name, emitter, usage, summary.get("modules", {}).get(usage)))


def _module_path(name):
    return "%s/%s_Mars_NM" % (MODULES, name)


def build_materials(m):
    """The three sprite materials, inside the editor (mars_flame_ue)."""
    out = m.python("import sys, importlib\n"
                   "sys.path.insert(0, r'%s')\n"
                   "import mars_flame_ue as mf\n"
                   "importlib.reload(mf)\n"
                   "print('RESULT', mf.build_materials())\n" % HERE)
    log("materials: %s" % (out if isinstance(out, str) else json.dumps(out)[:400]))
    return out


def build_system(m):
    spec_paths = [NS]
    for em in EMITTERS.values():
        spec_paths += [_module_path(em["spawn"][0]), _module_path(em["update"][0])]
    # fresh assets: the system and the module scripts are generated (a placed component keeps its user overrides)
    m.python("import unreal\n"
             "for p in %r:\n"
             "    if unreal.EditorAssetLibrary.does_asset_exist(p):\n"
             "        unreal.EditorAssetLibrary.delete_asset(p)\n" % (spec_paths,))

    user_kind = {n: k for n, k, _ in USER}
    for name, em in EMITTERS.items():
        for key, extra in (("spawn", ()), ("update", (("DeltaTime", "float"),) if em.get("delta") else ())):
            mod_name, body, inputs = em[key]
            m.niagara("create_module_from_hlsl", name=mod_name, save_path=_module_path(mod_name), hlsl=body,
                      inputs=[{"name": n, "type": TYPES[user_kind[n]]} for n in inputs] + [{"name": n, "type": t} for n, t in extra],
                      description="Mars flame (%s): %s stage." % (name, key))
    log("module scripts created")

    m.niagara("create_system", save_path=NS)
    for name, kind, value in USER:
        m.niagara("add_user_parameter", asset_path=NS, name=name, type=TYPES[kind], default=_default(kind, value))
    log("system and %d user parameters" % len(USER))

    for name, em in EMITTERS.items():
        m.niagara("create_emitter", asset_path=NS, name=name, sim_target="cpu")
        m.niagara("set_emitter_property", asset_path=NS, emitter=name, property="bLocalSpace", value="true")
        # emitter update: the spawn rate, bound or constant
        m.niagara("add_module", asset_path=NS, emitter=name, usage="emitter_update", module_script=SPAWN_RATE)
        node = _module_node(m, "emitter_update", "SpawnRate", name)
        if isinstance(em["rate"], str):
            m.niagara("set_module_input_binding", asset_path=NS, emitter=name, module_node=node, input="SpawnRate", binding=em["rate"])
        else:
            # Monolith's constant setter is set_module_input_value (set_module_input does not exist; discovered 2026-10-29)
            m.niagara("set_module_input_value", asset_path=NS, emitter=name, module_node=node, input="SpawnRate", value=em["rate"])
        # particle spawn: after InitializeParticle
        spawn_name, _, spawn_inputs = em["spawn"]
        path = _module_path(spawn_name)
        m.niagara("add_module", asset_path=NS, emitter=name, usage="particle_spawn", module_script=path + "." + path.rsplit("/", 1)[1])
        node = _module_node(m, "particle_spawn", spawn_name, name)
        for inp in spawn_inputs:
            m.niagara("set_module_input_binding", asset_path=NS, emitter=name, module_node=node, input=inp, binding="User.%s" % inp)
        # particle update: ParticleState, Dynamic Material Parameters (registers the attribute), then the Mars update
        m.niagara("add_module", asset_path=NS, emitter=name, usage="particle_update", module_script=DYNAMIC_PARAMS)
        update_name, _, update_inputs = em["update"]
        path = _module_path(update_name)
        m.niagara("add_module", asset_path=NS, emitter=name, usage="particle_update", module_script=path + "." + path.rsplit("/", 1)[1])
        node = _module_node(m, "particle_update", update_name, name)
        for inp in update_inputs:
            m.niagara("set_module_input_binding", asset_path=NS, emitter=name, module_node=node, input=inp, binding="User.%s" % inp)
        if em.get("delta"):
            m.niagara("set_module_input_binding", asset_path=NS, emitter=name, module_node=node, input="DeltaTime", binding="Engine.DeltaTime")
        # renderer: a sprite on the emitter's material instance; tongues stretch along their velocity, the rest face the camera
        m.niagara("remove_renderer", asset_path=NS, emitter=name, renderer_index=0, check=False)
        m.niagara("add_renderer", asset_path=NS, emitter=name, **{"class": "Sprite"})
        m.niagara("set_renderer_material", asset_path=NS, emitter=name, renderer_index=0,
                  material="%s/%s.%s" % (F_MAT, em["material"], em["material"]))
        if em["align"] == "velocity":
            # best effort: the action may not exist on an older Monolith; the sprite then faces the camera unaligned
            m.niagara("set_renderer_property", asset_path=NS, emitter=name, renderer_index=0, property="Alignment",
                      value="VelocityAligned", check=False)
        log("emitter %s: SpawnRate, %s, DynamicMaterialParameters, %s, sprite renderer on %s" % (name, spawn_name, update_name, em["material"]))

    m.niagara("request_compile", asset_path=NS)
    diag = m.niagara("get_system_diagnostics", asset_path=NS)
    m.niagara("save_system", asset_path=NS, check=False)
    log("compiled: %d errors, %d warnings" % (diag.get("error_count", -1), diag.get("warning_count", -1)))
    for e in diag.get("errors", []) + diag.get("warnings", []):
        log("  %s: %s" % (e.get("source"), e.get("message")))
    return diag


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=9316)
    ap.add_argument("--what", choices=("materials", "system", "all"), default="all",
                    help="materials builds the three sprite masters + instances; system rebuilds Flame_Mars_NS (discards hand edits)")
    a = ap.parse_args()
    mono = Monolith(a.port)
    errors = 0
    if a.what in ("materials", "all"):
        build_materials(mono)
    if a.what in ("system", "all"):
        errors += build_system(mono).get("error_count", 0)
    sys.exit(1 if errors else 0)
