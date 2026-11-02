"""Builds RootMawRoots_Mars_NS, the Root Maw's root trail, in a running editor through Monolith's niagara_query actions (the
mars_flame_niagara model). Runs OUTSIDE the editor (plain Python 3, no `unreal`):

    python mars_root_maw_niagara.py                 # the hidden editor on 9317 (env_drive.py --port 9317 --launch first)

Never run it against an editor that has a level open with a Root Maw in it (a placed spawner's preview holds the system):
the delete then fails on the locked file and saving the recreated system is a fatal "partially loaded" error that shuts
the editor down (it took down Stephen's editor on :9316 on 2026-11-02, with unsaved work in it). So the builder opens a
blank level in the editor it drives before it deletes anything, and refuses :9316 (the interactive editor) without --force.

Stephen (2026-11-02): "As it moves I want it to spawn niagara roots per unit, that will scale up as they come in and scale
down / rotate away over their life making it look like the roots are growing around where it moves and shrinks behind it".

One CPU emitter, WORLD space (a root stays where it grew while the Maw moves on), a mesh renderer over the four root meshes
(RootMaw_Root0..3_Mars_SM, pivot on the ground under the root's inner end, +X outward). Spawning:
  - SpawnPerUnit: one root every User.RootSpacing cm the component travels (the component rides the Maw's body node on the
    ground under its bulb, so this is per unit of the Maw's own travel);
  - SpawnRate bound to User.IdleRate: the slow trickle that keeps a ring of roots under a standing Maw (the entity script
    zeroes it while the Maw is buried, and raises it for a moment as it bursts out).
Each root (MarsRootSpawn / MarsRootUpdate) is placed in the bed under the head: anywhere in a disc of BedRadius cm round
the component (filled, not a ring: Stephen 2026-11-02, "it can fill a cylinder/ring under the head to fill the space
better ... look like the concept / original mesh and less like a floating head"), biased ahead of the Maw (FrontBias of
them within FrontSpread degrees of User.Heading, pushed Lead ahead by the distance it covers while they grow), turned to
point outward from the head (+- YawJitter). Its size follows the head: NearScale while the head is over it (within
BedRadius), easing to FarScale by FarRadius ("thicker or more abundant near where the head is ... as it moves away it
becomes more scarce/shrink"), times its life (Lifetime +- LifeJitter):
  grows: along its length, base to tip, over the first GrowFraction of its life (ease out): the update writes the grow
         front into Particles.DynamicMaterialParameter.x and RootMawRoot_Mars_M collapses the root past it onto its centre
         line (Stephen 2026-11-02: "have them as splines that grow"), while its scale swells from 70 % to full;
  holds: until ShrinkStart;
  goes:  retracts tip-first back into its base over the rest (ease in), shrinking to 60 %, twisting TwistDegrees about
         its pivot (either way), tipping TipDegrees into the ground and sinking SinkDepth, darkening to half.
A second CPU emitter, Tendrils, draws the roots' grounding (Stephen: "complimentary spline thickness mesh that pan based
on speed"): tube ribbons (RootMawTendril_Mars_MI) in TendrilCount lanes spread TendrilSpread either side of the path (a
TendrilWiggle sway along the distance), one ribbon point per TendrilSpacing cm travelled (SpawnPerUnit), each point living
TendrilLife: thick by the head (TendrilWidth), thinning to 35 % by FarRadius and to nothing at the end of its life; the
material's bark grooves pan by the particle's dynamic parameter x = Distance * PanRate, so they stream at the Maw's speed.
User parameters (the contract; Script/WorldObjects/Monsters/Mars_RootMaw_EntityScript.as writes the starred ones each frame,
every other one is Stephen's to tune on the asset or per component):
    RootSpacing  float  cm travelled per root (default 8: about 12 roots a metre)
  * IdleRate     float  roots a second besides travel (default 6: about 18 under a standing Maw; 0 buried; a burst as it
                        emerges)
  * Heading      vec3   the Maw's travel direction on the ground (zero standing)
  * Speed        float  the Maw's ground speed, cm/s (the lead ahead)
  * Distance     float  how far the Maw has glided, cm (wrapped; the tendrils' pan and sway)
    TendrilSpacing / TendrilCount / TendrilSpread / TendrilWidth / TendrilLife / TendrilWiggle / PanRate (floats)
    Lifetime / LifeJitter, GrowFraction, ShrinkStart, RootScale / ScaleJitter, BedRadius, NearScale / FarScale / FarRadius,
    FrontBias / FrontSpread, LeadShare, YawJitter, TwistDegrees, TipDegrees, SinkDepth (floats)
Re-running replaces the system and the module scripts (a placed component keeps its user overrides).
"""
import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
FLAME_DIR = os.path.join(os.path.dirname(os.path.dirname(HERE)), "mars_environment", "unreal")
if FLAME_DIR not in sys.path:
    sys.path.insert(0, FLAME_DIR)
from mars_flame_niagara import Monolith  # noqa: E402

FX_FOLDER = "/Game/Mars/Gameplay/Monsters/RootMaw/Fx"
NS = FX_FOLDER + "/RootMawRoots_Mars_NS"
MODULES = FX_FOLDER + "/Modules"
MESHES = "/Game/Mars/Gameplay/Monsters/RootMaw/Meshes"
ROOT_MESHES = tuple("%s/RootMaw_Root%d_Mars_SM.RootMaw_Root%d_Mars_SM" % (MESHES, k, k) for k in range(4))
EMITTER = "Roots"
TENDRILS = "Tendrils"
TENDRIL_MATERIAL = "/Game/Mars/Gameplay/Monsters/RootMaw/Materials/RootMawTendril_Mars_MI.RootMawTendril_Mars_MI"
DYNAMIC_PARAMS = "/Niagara/Modules/Update/Material/DynamicMaterialParameters.DynamicMaterialParameters"
SPAWN_RATE = "/Niagara/Modules/Emitter/SpawnRate.SpawnRate"
SPAWN_PER_UNIT = "/Niagara/Modules/Emitter/SpawnPerUnit.SpawnPerUnit"

# (name, Niagara type, default)
USER = (
    ("RootSpacing", "float", 8.0), ("IdleRate", "float", 6.0), ("Heading", "vec3", (0.0, 0.0, 0.0)), ("Speed", "float", 0.0),
    ("Lifetime", "float", 3.0), ("LifeJitter", "float", 0.25), ("GrowFraction", "float", 0.15), ("ShrinkStart", "float", 0.55),
    ("RootScale", "float", 1.0), ("ScaleJitter", "float", 0.25), ("BedRadius", "float", 24.0), ("NearScale", "float", 1.5),
    ("FarScale", "float", 0.45), ("FarRadius", "float", 110.0),
    ("FrontBias", "float", 0.6), ("FrontSpread", "float", 70.0), ("LeadShare", "float", 0.6), ("YawJitter", "float", 30.0),
    ("TwistDegrees", "float", 80.0), ("TipDegrees", "float", 30.0), ("SinkDepth", "float", 10.0),
    ("Distance", "float", 0.0), ("TendrilSpacing", "float", 4.0), ("TendrilCount", "float", 5.0),
    ("TendrilSpread", "float", 20.0), ("TendrilWidth", "float", 14.0), ("TendrilLife", "float", 2.2),
    ("TendrilWiggle", "float", 8.0), ("PanRate", "float", 0.03),
)
TYPES = {"float": "float", "vec3": "vec3"}

# Spawn: the ring place, the life, the stash. Particles.Velocity is a stash (no solver runs): x yaw (rad), y size, z twist
# sign; SpriteSize x the ground z, y the tip share; Color.a the tint.
SPAWN_INPUTS = ("Heading", "Speed", "Lifetime", "LifeJitter", "GrowFraction", "RootScale", "ScaleJitter", "BedRadius",
                "FrontBias", "FrontSpread", "LeadShare", "YawJitter")
NS_ROOT_SPAWN = """float2 h = Heading.xy;
float hl = length(h);
float2 hd = h / max(hl, 0.001);
float moving = step(0.01, hl);
float frontAng = atan2(hd.y, hd.x) + (rand(1.0f) * 2.0 - 1.0) * radians(FrontSpread);
float anyAng = rand(1.0f) * 6.2831853;
float useFront = step(rand(1.0f), FrontBias * moving);
float ang = lerp(anyAng, frontAng, useFront);
float r = BedRadius * sqrt(rand(1.0f)) * RootScale;
float life = Lifetime * lerp(1.0 - LifeJitter, 1.0 + LifeJitter, rand(1.0f));
float lead = Speed * life * GrowFraction * LeadShare * moving;
float3 o = float3(cos(ang) * r, sin(ang) * r, 0.0) + float3(hd * lead, 0.0);
Particles.Position = Origin + o;
Particles.Lifetime = life;
float yaw = ang + radians((rand(1.0f) * 2.0 - 1.0) * YawJitter);
float size = lerp(1.0 - ScaleJitter, 1.0 + ScaleJitter, rand(1.0f));
float twistSign = step(0.5, rand(1.0f)) * 2.0 - 1.0;
Particles.Velocity = float3(yaw, size, twistSign);
Particles.SpriteSize = float2(Origin.z, lerp(0.5, 1.0, rand(1.0f)));
float tint = lerp(0.8, 1.05, rand(1.0f));
Particles.Color = float4(tint, tint, tint, tint);
Particles.Scale = float3(0.0, 0.0, 0.0);
Particles.MeshOrientation = float4(0.0, 0.0, sin(yaw * 0.5), cos(yaw * 0.5));
Particles.MeshIndex = (int)min(floor(rand(1.0f) * 4.0), 3.0);"""

UPDATE_INPUTS = ("GrowFraction", "ShrinkStart", "RootScale", "TwistDegrees", "TipDegrees", "SinkDepth", "BedRadius", "NearScale",
                 "FarScale", "FarRadius")
NS_ROOT_UPDATE = """float t = saturate(Particles.NormalizedAge);
float grow = saturate(t / max(GrowFraction, 0.001));
grow = 1.0 - (1.0 - grow) * (1.0 - grow);
float gone = saturate((t - ShrinkStart) / max(1.0 - ShrinkStart, 0.001));
gone = gone * gone;
float3 st = Particles.Velocity;
float away = length(Particles.Position.xy - Owner.xy);
float near = saturate((away - BedRadius * RootScale) / (max(FarRadius - BedRadius, 1.0) * RootScale));
near = near * near * (3.0 - 2.0 * near);
float s = st.y * RootScale * lerp(NearScale, FarScale, near) * (0.7 + 0.3 * grow) * (1.0 - 0.4 * gone);
Particles.Scale = float3(s, s, s);
Particles.DynamicMaterialParameter = float4(grow * (1.0 - gone), 0.0, 0.0, 0.0);
float yaw = st.x + st.z * radians(TwistDegrees) * gone;
float tip = radians(TipDegrees) * gone * Particles.SpriteSize.y;
float4 qy = float4(0.0, 0.0, sin(yaw * 0.5), cos(yaw * 0.5));
float4 qp = float4(0.0, sin(tip * 0.5), 0.0, cos(tip * 0.5));
float4 q;
q.xyz = qy.w * qp.xyz + qp.w * qy.xyz + cross(qy.xyz, qp.xyz);
q.w = qy.w * qp.w - dot(qy.xyz, qp.xyz);
Particles.MeshOrientation = q;
Particles.Position.z = Particles.SpriteSize.x - SinkDepth * RootScale * gone;
float shade = Particles.Color.a * lerp(1.0, 0.5, gone);
Particles.Color = float4(shade, shade, shade, Particles.Color.a);"""


# The tendrils. Spawn: a lane (RibbonID), its place beside the path, sunk a little into the ground.
TENDRIL_SPAWN_INPUTS = ("Heading", "TendrilCount", "TendrilSpread", "TendrilLife", "TendrilWiggle", "TendrilWidth",
                        "RootScale", "Distance")
NS_TENDRIL_SPAWN = """float2 h = Heading.xy;
float hl = length(h);
float2 hd = h / max(hl, 0.001);
float2 side = float2(-hd.y, hd.x);
float n = max(TendrilCount, 1.0);
float lanef = min(floor(rand(1.0f) * n), n - 1.0);
float lane = lanef / max(n - 1.0, 1.0) * 2.0 - 1.0;
float wig = sin(Distance * 0.045 + lanef * 2.1) * TendrilWiggle;
float off = (lane * TendrilSpread + wig) * RootScale;
Particles.Position = Origin + float3(side * off - hd * 6.0 * RootScale, TendrilWidth * 0.15 * RootScale);
NiagaraID lane_id;
lane_id.Index = (int)lanef;
lane_id.AcquireTag = 0;
Particles.RibbonID = lane_id;
Particles.Lifetime = TendrilLife;
Particles.RibbonWidth = 0.0;
Particles.Color = float4(1.0, 1.0, 1.0, 1.0);"""

# Update: the width (in, thinning with distance from the head, out by the end of its life) and the pan phase.
TENDRIL_UPDATE_INPUTS = ("TendrilWidth", "RootScale", "BedRadius", "FarRadius", "Distance", "PanRate")
NS_TENDRIL_UPDATE = """float t = saturate(Particles.NormalizedAge);
float inw = saturate(t / 0.1);
inw = 1.0 - (1.0 - inw) * (1.0 - inw);
float away = length(Particles.Position.xy - Owner.xy);
float near = saturate((away - BedRadius * RootScale) / (max(FarRadius - BedRadius, 1.0) * RootScale));
near = near * near * (3.0 - 2.0 * near);
Particles.RibbonWidth = TendrilWidth * RootScale * inw * lerp(1.0, 0.35, near) * (1.0 - t * t);
Particles.DynamicMaterialParameter = float4(Distance * PanRate, t, 0.0, 0.0);"""


def log(msg):
    print("MarsRootMawNiagara: %s" % msg)


def _default(kind, value):
    if kind == "vec3":
        return {"x": value[0], "y": value[1], "z": value[2]}
    return value


def _module_node(m, usage, script_name, emitter=EMITTER):
    summary = m.niagara("get_emitter_summary", asset_path=NS, emitter=emitter)
    for mod in summary.get("modules", {}).get(usage, []):
        if script_name.lower() in mod.get("name", "").lower().replace(" ", ""):
            return mod.get("guid") or mod.get("name")
    raise RuntimeError("module %s not found in %s: %s" % (script_name, usage, summary.get("modules", {}).get(usage)))


def _module_path(name):
    return "%s/%s_Mars_NM" % (MODULES, name)


def _script(name):
    path = _module_path(name)
    return path + "." + path.rsplit("/", 1)[1]


def release_system(m):
    """Opens a blank level and collects garbage, so no placed Root Maw's preview holds the system when it is deleted (the
    builder only ever runs in its own hidden editor: see the module docstring)."""
    m.python("\n".join(("import unreal",
                        "les = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)",
                        "if les.is_in_play_in_editor():",
                        "    raise RuntimeError('stop PIE first')",
                        "les.new_level('/Temp/RootMawNiagaraBlank')",
                        "unreal.SystemLibrary.collect_garbage()")))


def build_system(m):
    release_system(m)
    m.python("import unreal\n"
             "for p in %r:\n"
             "    if unreal.EditorAssetLibrary.does_asset_exist(p):\n"
             "        unreal.EditorAssetLibrary.delete_asset(p)\n" % ([NS] + [_module_path(n) for n in (
                 "MarsRootSpawn", "MarsRootUpdate", "MarsTendrilSpawn", "MarsTendrilUpdate")],))
    kinds = {n: k for n, k, _ in USER}
    m.niagara("create_module_from_hlsl", name="MarsRootSpawn", save_path=_module_path("MarsRootSpawn"), hlsl=NS_ROOT_SPAWN,
              inputs=[{"name": n, "type": TYPES[kinds[n]]} for n in SPAWN_INPUTS] + [{"name": "Origin", "type": "vec3"}],
              description="Mars Root Maw roots: the ring place, life, size and stash.")
    m.niagara("create_module_from_hlsl", name="MarsRootUpdate", save_path=_module_path("MarsRootUpdate"), hlsl=NS_ROOT_UPDATE,
              inputs=[{"name": n, "type": TYPES[kinds[n]]} for n in UPDATE_INPUTS] + [{"name": "Owner", "type": "vec3"}],
              description="Mars Root Maw roots: grow, hold, shrink while twisting and tipping into the ground.")
    m.niagara("create_module_from_hlsl", name="MarsTendrilSpawn", save_path=_module_path("MarsTendrilSpawn"), hlsl=NS_TENDRIL_SPAWN,
              inputs=[{"name": n, "type": TYPES[kinds[n]]} for n in TENDRIL_SPAWN_INPUTS] + [{"name": "Origin", "type": "vec3"}],
              description="Mars Root Maw tendrils: a lane beside the path.")
    m.niagara("create_module_from_hlsl", name="MarsTendrilUpdate", save_path=_module_path("MarsTendrilUpdate"), hlsl=NS_TENDRIL_UPDATE,
              inputs=[{"name": n, "type": TYPES[kinds[n]]} for n in TENDRIL_UPDATE_INPUTS] + [{"name": "Owner", "type": "vec3"}],
              description="Mars Root Maw tendrils: width and pan phase.")
    log("module scripts created")

    m.niagara("create_system", save_path=NS)
    for name, kind, value in USER:
        m.niagara("add_user_parameter", asset_path=NS, name=name, type=TYPES[kind], default=_default(kind, value))
    log("system and %d user parameters" % len(USER))

    m.niagara("create_emitter", asset_path=NS, name=EMITTER, sim_target="cpu")
    m.niagara("set_emitter_property", asset_path=NS, emitter=EMITTER, property="bLocalSpace", value="false")
    m.niagara("add_module", asset_path=NS, emitter=EMITTER, usage="emitter_update", module_script=SPAWN_RATE)
    node = _module_node(m, "emitter_update", "SpawnRate")
    m.niagara("set_module_input_binding", asset_path=NS, emitter=EMITTER, module_node=node, input="SpawnRate", binding="User.IdleRate")
    m.niagara("add_module", asset_path=NS, emitter=EMITTER, usage="emitter_update", module_script=SPAWN_PER_UNIT)
    node = _module_node(m, "emitter_update", "SpawnPerUnit")
    inputs = m.niagara("get_module_inputs", asset_path=NS, emitter=EMITTER, module_node=node, check=False)
    log("SpawnPerUnit inputs: %s" % json.dumps(inputs)[:1200])
    m.niagara("set_module_input_binding", asset_path=NS, emitter=EMITTER, module_node=node, input="Spawn Spacing", binding="User.RootSpacing", check=False)
    m.niagara("set_module_input_binding", asset_path=NS, emitter=EMITTER, module_node=node, input="SpawnSpacing", binding="User.RootSpacing", check=False)
    for inp, value in (("Use Max Movement Threshold", True), ("Max Movement Threshold", 600.0)):
        m.niagara("set_module_input_value", asset_path=NS, emitter=EMITTER, module_node=node, input=inp, value=value, check=False)

    m.niagara("add_module", asset_path=NS, emitter=EMITTER, usage="particle_spawn", module_script=_script("MarsRootSpawn"))
    node = _module_node(m, "particle_spawn", "MarsRootSpawn")
    for inp in SPAWN_INPUTS:
        m.niagara("set_module_input_binding", asset_path=NS, emitter=EMITTER, module_node=node, input=inp, binding="User.%s" % inp)
    m.niagara("set_module_input_binding", asset_path=NS, emitter=EMITTER, module_node=node, input="Origin", binding="Engine.Owner.Position")
    m.niagara("add_module", asset_path=NS, emitter=EMITTER, usage="particle_update", module_script=DYNAMIC_PARAMS)
    m.niagara("add_module", asset_path=NS, emitter=EMITTER, usage="particle_update", module_script=_script("MarsRootUpdate"))
    node = _module_node(m, "particle_update", "MarsRootUpdate")
    for inp in UPDATE_INPUTS:
        m.niagara("set_module_input_binding", asset_path=NS, emitter=EMITTER, module_node=node, input=inp, binding="User.%s" % inp)
    m.niagara("set_module_input_binding", asset_path=NS, emitter=EMITTER, module_node=node, input="Owner", binding="Engine.Owner.Position")

    m.niagara("remove_renderer", asset_path=NS, emitter=EMITTER, renderer_index=0, check=False)
    m.niagara("add_renderer", asset_path=NS, emitter=EMITTER, **{"class": "Mesh"})
    for k, mesh in enumerate(ROOT_MESHES):
        m.niagara("set_renderer_mesh", asset_path=NS, emitter=EMITTER, renderer_index=0, mesh=mesh, mesh_index=k)
    log("emitter %s: SpawnRate(IdleRate), SpawnPerUnit(RootSpacing), MarsRootSpawn, DynamicMaterialParameters, "
        "MarsRootUpdate, mesh renderer x%d" % (EMITTER, len(ROOT_MESHES)))
    build_tendrils(m)

    m.niagara("request_compile", asset_path=NS)
    diag = m.niagara("get_system_diagnostics", asset_path=NS)
    m.niagara("save_system", asset_path=NS, check=False)
    log("compiled: %d errors, %d warnings" % (diag.get("error_count", -1), diag.get("warning_count", -1)))
    for e in diag.get("errors", []) + diag.get("warnings", []):
        log("  %s: %s" % (e.get("source"), e.get("message")))
    return diag


def build_tendrils(m):
    m.niagara("create_emitter", asset_path=NS, name=TENDRILS, sim_target="cpu")
    m.niagara("set_emitter_property", asset_path=NS, emitter=TENDRILS, property="bLocalSpace", value="false")
    m.niagara("add_module", asset_path=NS, emitter=TENDRILS, usage="emitter_update", module_script=SPAWN_PER_UNIT)
    node = _module_node(m, "emitter_update", "SpawnPerUnit", TENDRILS)
    m.niagara("set_module_input_binding", asset_path=NS, emitter=TENDRILS, module_node=node, input="Spawn Spacing", binding="User.TendrilSpacing")
    for inp, value in (("Use Max Movement Threshold", True), ("Max Movement Threshold", 600.0)):
        m.niagara("set_module_input_value", asset_path=NS, emitter=TENDRILS, module_node=node, input=inp, value=value, check=False)
    m.niagara("add_module", asset_path=NS, emitter=TENDRILS, usage="particle_spawn", module_script=_script("MarsTendrilSpawn"))
    node = _module_node(m, "particle_spawn", "MarsTendrilSpawn", TENDRILS)
    for inp in TENDRIL_SPAWN_INPUTS:
        m.niagara("set_module_input_binding", asset_path=NS, emitter=TENDRILS, module_node=node, input=inp, binding="User.%s" % inp)
    m.niagara("set_module_input_binding", asset_path=NS, emitter=TENDRILS, module_node=node, input="Origin", binding="Engine.Owner.Position")
    m.niagara("add_module", asset_path=NS, emitter=TENDRILS, usage="particle_update", module_script=DYNAMIC_PARAMS)
    m.niagara("add_module", asset_path=NS, emitter=TENDRILS, usage="particle_update", module_script=_script("MarsTendrilUpdate"))
    node = _module_node(m, "particle_update", "MarsTendrilUpdate", TENDRILS)
    for inp in TENDRIL_UPDATE_INPUTS:
        m.niagara("set_module_input_binding", asset_path=NS, emitter=TENDRILS, module_node=node, input=inp, binding="User.%s" % inp)
    m.niagara("set_module_input_binding", asset_path=NS, emitter=TENDRILS, module_node=node, input="Owner", binding="Engine.Owner.Position")
    m.niagara("remove_renderer", asset_path=NS, emitter=TENDRILS, renderer_index=0, check=False)
    m.niagara("add_renderer", asset_path=NS, emitter=TENDRILS, **{"class": "Ribbon"})
    m.niagara("set_renderer_material", asset_path=NS, emitter=TENDRILS, renderer_index=0, material=TENDRIL_MATERIAL)
    m.niagara("configure_ribbon", asset_path=NS, emitter=TENDRILS, renderer_index=0, shape="Tube", tube_subdivisions=6,
              uv_mode="TiledOverRibbonLength", tiling_length=30.0, width_binding="Particles.RibbonWidth",
              ribbon_id_binding="Particles.RibbonID", link_order_binding="Particles.Age")
    log("emitter %s: SpawnPerUnit(TendrilSpacing), MarsTendrilSpawn, DynamicMaterialParameters, MarsTendrilUpdate, tube ribbon"
        % TENDRILS)


def report(m):
    out = {"summary": m.niagara("get_emitter_summary", asset_path=NS, emitter=EMITTER, check=False),
           "renderers": m.niagara("list_renderers", asset_path=NS, emitter=EMITTER, check=False),
           "user": m.niagara("get_user_parameters", asset_path=NS, check=False)}
    print(json.dumps(out, indent=1)[:6000])
    return out


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=9317)
    ap.add_argument("--report", action="store_true", help="only print the system's emitter summary, renderers and user parameters")
    ap.add_argument("--force", action="store_true", help="allow the interactive editor's port 9316 (its level is replaced)")
    a = ap.parse_args()
    if a.port == 9316 and not (a.force or a.report):
        sys.exit("9316 is the interactive editor: the build replaces its open level; use the hidden editor (9317) or --force")
    mono = Monolith(a.port)
    if a.report:
        report(mono)
        sys.exit(0)
    errors = build_system(mono).get("error_count", 0)
    report(mono)
    sys.exit(1 if errors else 0)
