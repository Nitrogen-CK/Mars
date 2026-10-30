"""HLSL bodies for Flame_Mars_NS (Niagara custom modules, built by mars_flame_niagara through Monolith) and for the three
sprite materials (Custom nodes, built by mars_flame_ue inside the editor). Plain python: no unreal, no bpy.

Niagara module bodies: inputs are bare names bound to User.* (Size, Intensity, Colour, EmberRate, Wind, Enclosed) or to
engine attributes (DeltaTime); particle attributes are read / written directly, and only ones the stack has already
registered (InitializeParticle: Position, Lifetime, Color, SpriteSize, SpriteRotation; the stock Dynamic Material
Parameters module: DynamicMaterialParameter). Per-particle randoms live in Color.a (phase) and SpriteRotation / 360 (a
second phase); the material reads Color.rgb and the dynamic parameter. Positions are emitter-local cm (local-space
emitters: the system rides the flame node). The CPU VM has no smoothstep: polynomials are written out.
"""

# ====================================================================================== tongues
# Spawn: at the flame's root, inside a disc of 0.18 Size (narrower behind glass), 0.35-0.7 s, a random phase; the sprite
# starts about half the flame tall and wide. Color.rgb = the user Colour (the material ramps it by age).
NS_TONGUE_SPAWN = """float ph = rand(1.0f);
float a = rand(1.0f) * 6.2831853;
float r = sqrt(rand(1.0f)) * Size * lerp(0.18, 0.10, saturate(Enclosed));
Particles.Position = float3(cos(a) * r, sin(a) * r, 0.0);
Particles.Lifetime = lerp(0.35, 0.7, rand(1.0f));
Particles.Color = float4(Colour.rgb, ph);
Particles.SpriteSize = float2(Size * 0.55, Size * 0.9);
Particles.SpriteRotation = rand(1.0f) * 360.0;"""

# Update: rises with ease-out to about Size (0.8 Size behind glass), curls sideways on two sines (curl noise stand-in)
# and leans with Wind; narrows and shortens toward the tip; DynamicMaterialParameter = (phase, age 0..1, Intensity, 0).
# A dark flame (Intensity 0) still spawns but the material draws nothing: the dressing deactivates the system anyway.
NS_TONGUE_UPDATE = """float t = saturate(Particles.NormalizedAge);
float ph = Particles.Color.a;
float ph2 = Particles.SpriteRotation / 360.0;
float enc = saturate(Enclosed);
float ease = 1.0 - (1.0 - t) * (1.0 - t);
float height = Size * lerp(1.0, 0.8, enc);
float w = 6.2831853;
float sway = Size * lerp(0.14, 0.05, enc);
float2 curl = float2(sin(w * (t * 1.7 + ph * 3.1)) * ph2, cos(w * (t * 1.3 + ph2 * 2.7)) * (1.0 - ph2)) * sway * t;
float3 wind = Wind * 0.0025 * Size * ease * (1.0 - enc);
float2 xy = curl + wind.xy;
float cap = Size * lerp(0.3, 0.12, enc);
float len = length(xy);
xy = len > cap ? xy * (cap / len) : xy;
float dz = ease * height + wind.z;
float dz0 = Particles.Position.z;
Particles.Position = float3(xy, lerp(0.0, height, ease) + wind.z);
float shrink = 1.0 - 0.55 * t * t;
Particles.SpriteSize = float2(Size * 0.55 * shrink, Size * 0.9 * (1.0 - 0.35 * t));
Particles.DynamicMaterialParameter = float4(ph, t, Intensity, enc);"""

# ====================================================================================== embers
# Spawn: in the upper third of the flame, 1-2.5 s; a small point. Behind glass the ember dies at birth (Lifetime 0, the
# dressing also writes EmberRate 0).
NS_EMBER_SPAWN = """float ph = rand(1.0f);
float a = rand(1.0f) * 6.2831853;
float r = sqrt(rand(1.0f)) * Size * 0.22;
Particles.Position = float3(cos(a) * r, sin(a) * r, Size * lerp(0.6, 1.0, rand(1.0f)));
Particles.Lifetime = lerp(1.0, 2.5, rand(1.0f)) * (1.0 - step(0.5, Enclosed));
Particles.Color = float4(Colour.rgb, ph);
Particles.SpriteSize = float2(Size * 0.035, Size * 0.035);
Particles.SpriteRotation = rand(1.0f) * 360.0;"""

# Update: rises at about 1.2 Size per second slowing with age, turbulence on three sines, Wind drift; the point shrinks and
# the material fades it orange -> black by DynamicMaterialParameter.y.
NS_EMBER_UPDATE = """float t = saturate(Particles.NormalizedAge);
float ph = Particles.Color.a;
float ph2 = Particles.SpriteRotation / 360.0;
float age = Particles.Age;
float w = 6.2831853;
float3 v = float3(sin(w * (age * 0.9 + ph * 5.0)), cos(w * (age * 1.1 + ph2 * 4.0)), 0.0) * Size * 0.35;
v += float3(sin(w * (age * 2.3 + ph2 * 7.0)), sin(w * (age * 1.9 + ph * 9.0)), 0.0) * Size * 0.12;
v.z = Size * 1.2 * (1.0 - 0.6 * t);
v += Wind * 0.6;
Particles.Position += v * DeltaTime;
Particles.SpriteSize = float2(Size * 0.035 * (1.0 - 0.6 * t), Size * 0.035 * (1.0 - 0.6 * t));
Particles.DynamicMaterialParameter = float4(ph, t, Intensity, 0.0);"""

# ====================================================================================== glow
# Spawn: at the core, 1 s; 1.6 times the flame wide (a halo round the card, not a blob over it). Two overlap (SpawnRate 2) and the material cross-fades them on age.
NS_GLOW_SPAWN = """Particles.Position = float3(0.0, 0.0, Size * 0.45);
Particles.Lifetime = 1.0;
Particles.Color = float4(Colour.rgb, rand(1.0f));
Particles.SpriteSize = float2(Size * 1.6, Size * 1.6);
Particles.SpriteRotation = 0.0;"""

NS_GLOW_UPDATE = """float t = saturate(Particles.NormalizedAge);
Particles.Position = float3(0.0, 0.0, Size * 0.45 + Wind.z * 0.002 * Size);
Particles.DynamicMaterialParameter = float4(Particles.Color.a, t, Intensity, 0.0);"""

# ====================================================================================== materials
# A cheap value noise (two octaves) for the erosion: UV-space, scrolled by time. Inputs UV (float2), Time, Scale, Speed.
NOISE_HLSL = """float2 p = UV * Scale + float2(0.0, Time * Speed);
float2 i = floor(p); float2 f = frac(p); f = f * f * (3.0 - 2.0 * f);
float n00 = frac(sin(dot(i + float2(0.0, 0.0), float2(127.1, 311.7))) * 43758.5453);
float n10 = frac(sin(dot(i + float2(1.0, 0.0), float2(127.1, 311.7))) * 43758.5453);
float n01 = frac(sin(dot(i + float2(0.0, 1.0), float2(127.1, 311.7))) * 43758.5453);
float n11 = frac(sin(dot(i + float2(1.0, 1.0), float2(127.1, 311.7))) * 43758.5453);
float n = lerp(lerp(n00, n10, f.x), lerp(n01, n11, f.x), f.y);
p *= 2.17; i = floor(p); f = frac(p); f = f * f * (3.0 - 2.0 * f);
n00 = frac(sin(dot(i + float2(0.0, 0.0), float2(127.1, 311.7))) * 43758.5453);
n10 = frac(sin(dot(i + float2(1.0, 0.0), float2(127.1, 311.7))) * 43758.5453);
n01 = frac(sin(dot(i + float2(0.0, 1.0), float2(127.1, 311.7))) * 43758.5453);
n11 = frac(sin(dot(i + float2(1.0, 1.0), float2(127.1, 311.7))) * 43758.5453);
return n * 0.65 + lerp(lerp(n00, n10, f.x), lerp(n01, n11, f.x), f.y) * 0.35;"""

# FlameSprite_Mars_M: a teardrop SDF (a width profile that is round at the foot and narrows to the tip) eroded by the
# scrolling noise so the edge licks, with the candle's flicker idea per sprite (phase = Dyn.x, so no two tongues beat
# together). Dyn = (phase, age 0..1, Intensity, enclosed). Colour ramps white-hot at the foot and young, through the user
# Colour (particle colour), to dark red at the tip and old. Needs /CkUsf/Common.ush for CkUsf_SdfEdgeAA.
# Inputs: UV, Dyn (float4), PC (particle colour rgb), Noise, Time, Flicker, Softness, Core, Tip.
FLAME_SPRITE_HLSL = """float2 q = float2(UV.x - 0.5, 0.5 - UV.y) * 2.0;
float phase = Dyn.x;
float age = Dyn.y;
float t = Time * 1.0 + phase * 61.0;
float flick = 1.0 + Flicker * (sin(t * 6.1) * 0.5 + sin(t * 13.7 + 1.3) * 0.3 + sin(t * 23.3 + 2.1) * 0.2);
float h = saturate((q.y + 0.85) / 1.7);
float wide = 0.62 * sqrt(max(1.0 - h, 0.0)) * (1.0 - 0.3 * h) * (1.0 - 0.45 * age);
float erode = (Noise - 0.5) * 0.35 * (0.4 + h);
float d = abs(q.x) - wide + erode;
d = max(d, q.y - 0.9 + (Noise - 0.5) * 0.3);
d = max(d, -0.95 - q.y);
float body = CkUsf_SdfEdgeAA(d);
float soft = saturate(-d / max(Softness, 1e-3));
float hot = saturate(1.0 - h * 1.4 - age * 0.8);
float3 col = lerp(PC, Core, hot * hot);
col = lerp(col, Tip, saturate(h * 0.8 + age * 0.9 - 0.4));
float fade = (1.0 - age * age) * flick * Dyn.z;
return col * (body * 0.6 + soft * 0.4) * fade;"""

# EmberSprite_Mars_M: a soft point fading orange -> black through EyeAdaptationInverse (exposure-independent, so an ember
# reads in any room; keep Intensity low). Inputs: UV, Dyn, PC, Strength.
EMBER_SPRITE_HLSL = """float2 q = (UV - 0.5) * 2.0;
float r = length(q);
float core = saturate(1.0 - r * r);
core *= core;
float age = Dyn.y;
float3 col = lerp(PC * 1.6, float3(0.9, 0.18, 0.02), saturate(age * 1.4));
col = lerp(col, float3(0.05, 0.0, 0.0), saturate((age - 0.6) / 0.4));
float flick = 0.75 + 0.25 * sin((Dyn.x * 97.0 + age * 23.0) * 6.2831853);
return col * core * Strength * flick * Dyn.z;"""

# FlameGlow_Mars_M: a radial falloff in the user Colour; two glow sprites overlap and cross-fade on age (sin^2 + cos^2 = 1).
# Inputs: UV, Dyn, PC, Strength, Falloff.
FLAME_GLOW_HLSL = """float2 q = (UV - 0.5) * 2.0;
float r = saturate(length(q));
float g = pow(saturate(1.0 - r), Falloff);
float age = Dyn.y;
float s = sin(age * 3.14159265);
return PC * g * Strength * s * s * Dyn.z;"""

# ====================================================================================== the flame card
# One static-mesh card per flame (the engine Plane on the flame node, rolled upright, scaled W x H), fully procedural in the
# vertex shader: the quad is rebuilt from its UVs as a billboard about the vertical axis, its base pinned at the flame
# node and its tip bent by Lean (custom primitive data 2-4, world cm at the tip: the dressing's smoothed, negated carrier
# velocity, so the flame trails the motion and rights itself when it stops) plus the flicker sway. Lean.w = 1 behind
# glass caps the bend at 0.4 H instead of 1.2 H. Height / Width are custom primitive data 6 / 7 (cm; the Plane's own
# scale only sizes its bounds). The part of the lean straight along the view becomes an outward bend on screen
# (Exaggerate). A ripple (WaveAmount x the trail, WaveCycles along the flame, WaveSpeed) travels up a trailing flame.
# Inputs: UV, WP (world position without offsets), ObjPos, Cam, ViewFwd, Height, Width, Exaggerate, Time, Phase,
# WaveAmount, WaveCycles, WaveSpeed, Lean (float4),
# Flicker (float3: brightness, sway x, sway y).
FLAME_CARD_VS_HLSL = """float H = max(Height, 0.1);
float W = max(Width, 0.1);
float u = UV.x - 0.5;
float v = saturate(1.0 - UV.y);
float3 up = float3(0.0, 0.0, 1.0);
float3 toCam = Cam - ObjPos;
float3 toCamFlat = float3(toCam.xy, 0.0);
float3 fwd = normalize(toCamFlat + float3(1e-3, 0.0, 0.0));
float3 right = normalize(cross(up, fwd));
// The trail is the push opposite the carrier's motion. The part of it across the view shows as is; the part straight at
// the camera (walking forward with the torch ahead) would only foreshorten - and first-person rendering squashes depth -
// so it is turned into what perspective shows of a tip coming at the eye: a bend outward from the view's centre.
float3 lean = Lean.xyz;
float3 viewDir = normalize(ObjPos - Cam);
float along = dot(lean, viewDir);
float3 across = lean - viewDir * along;
float3 off = ObjPos - Cam;
float3 radial = off - ViewFwd * dot(off, ViewFwd);
float rl = length(radial);
float3 outward = rl > 1e-3 ? radial / rl : right;
outward = normalize(outward - viewDir * dot(outward, viewDir) + float3(0.0, 0.0, 1e-4));
lean = across + outward * max(-along, 0.0) * Exaggerate - outward * max(along, 0.0) * 0.5 * Exaggerate;
float lmax = H * lerp(0.45, 0.2, saturate(Lean.w));
float ll = length(lean);
lean = ll > lmax ? lean * (lmax / ll) : lean;
ll = length(lean);
// the trail curls: the foot barely moves, the tip most
float bend = pow(v, 1.6);
// a ripple travels up the trailing flame, across the trail as seen from the camera, growing with the trail and toward the
// tip, like a flag's edge in the wind
float3 perp = normalize(cross(ll > 1e-3 ? lean / ll : right, viewDir) + float3(1e-4, 0.0, 0.0));
float ripple = sin(v * WaveCycles * 6.2831853 - Time * WaveSpeed + Phase * 6.2831853) * WaveAmount * ll * v;
float3 sway = (right * Flicker.y + fwd * Flicker.z) * H * 0.08 * v * v;
float stretch = 1.0 + (Flicker.x - 1.0) * 0.3;
// the flame swings rather than stretches: the further the tip leans, the lower it stands, so its length stays about H
float keep = sqrt(max(1.0 - (ll * ll) / (H * H), 0.5));
float3 p = ObjPos + right * (u * W) + up * (v * H * stretch * lerp(1.0, keep, bend)) + lean * bend + perp * ripple + sway;
return p - WP;"""

# The candle's flicker (mars_candle_ue.FLICKER_HLSL): x = brightness about 1, y / z = sideways sway in -1..1. Phase is
# custom primitive data 0 (one random number per flame, set by the dressing). Inputs: Time, Speed, Phase, Amount.
FLAME_CARD_FLICKER_HLSL = """float t = Time * Speed + Phase * 61.0;
float n = sin(t * 6.1) * 0.5 + sin(t * 13.7 + 1.3) * 0.3 + sin(t * 23.3 + 2.1) * 0.2;
float i = 1.0 + n * Amount;
float sx = sin(t * 2.3) * 0.6 + sin(t * 5.9 + 0.7) * 0.4;
float sy = sin(t * 1.9 + 1.1) * 0.6 + sin(t * 4.7 + 2.3) * 0.4;
return float3(max(i, 0.05), sx, sy);"""

# The card's pixel shader: the teardrop SDF of the sprite eroded by the scrolling noise, white-hot at the foot through the
# flame Colour to the Tip colour, times the flicker and Intensity (custom primitive data 1, the kernel's brightness: 0 is
# dark). Two noises: Noise (coarse) warps and erodes the body, Detail (fine, faster) eats the edge and tears the top into
# licks (Tear). TRANSLUCENT: the additional output Mask is the opacity (soft edge Feather wide), the return is the
# emissive colour.
# Needs /CkUsf/Common.ush. Inputs: UV, Noise, Detail, Flicker, Intensity, Softness, Strength, Core, Tip,
# Colour, Warp, Erode, Tear, Feather.
FLAME_CARD_PS_HLSL = """float2 q = float2(UV.x - 0.5, 0.5 - UV.y) * 2.0;
// the flame spans q.y -0.9 (foot) .. 0.8 (tip); the card is about twice the flame's width
float h = saturate((q.y + 0.9) / 1.7);
// the upper flame wavers side to side on the coarse noise
q.x += (Noise - 0.5) * Warp * h * h;
// a round foot (a quarter circle over the lowest fifth) narrowing to the tip: no flat bottom
float foot = h < 0.2 ? sqrt(saturate(h * (0.4 - h))) / 0.2 : 1.0;
float wide = 0.42 * foot * sqrt(max(1.0 - h, 0.0)) * (1.0 - 0.3 * h);
float erode = (Noise - 0.5) * Erode * (0.2 + h) * 0.7 + (Detail - 0.5) * Erode * h * h;
float d = abs(q.x) - wide + erode;
d += max(q.y - 0.8, 0.0) * 3.0 + max(-0.9 - q.y, 0.0) * 3.0;
// above mid-height the flame tears into licks wherever the fine noise is low (blended in by height: a plain max with 0
// below it would push the whole lower flame onto its edge)
d = lerp(d, max(d, (Tear - Detail) * 0.6), smoothstep(0.35, 0.85, h));
// a guttering flame (Intensity dipping) shrinks a little as well as dimming
d += (1.0 - saturate(Intensity)) * 0.12;
// nothing ever reaches the quad's border, whatever the noise does
float border = saturate((1.0 - abs(q.x)) / 0.25) * saturate((1.0 - q.y) / 0.2) * saturate((q.y + 1.0) / 0.1);
// translucent coverage: a soft edge Feather wide (never sharper than a pixel)
Mask = saturate(0.5 - d / max(Feather, fwidth(d))) * border;
// solid inside: hot core, the flame colour toward the edge, darker at the very edge and the foot
float inner = saturate(-d / max(Softness, 1e-3));
float hot = saturate(1.0 - h * 1.4) * inner;
float3 col = lerp(Colour, Core, hot * hot);
col = lerp(col, Tip, saturate(h * 0.8 - 0.4));
col *= lerp(0.55, 1.0, inner) * lerp(0.8, 1.15, Detail) * lerp(0.6, 1.0, smoothstep(0.0, 0.18, h));
return col * Flicker.x * lerp(0.35, 1.0, saturate(Intensity)) * Strength;"""

# Each flame's noise lives in its own place (Phase, custom primitive data 0), so two torches never tear alike.
PHASED_UV_HLSL = """return UV + float2(Phase * 17.31, Phase * 5.17);"""

# ResolvedView.ViewForward as a node output (no material expression exposes it).
VIEW_FORWARD_HLSL = """return ResolvedView.ViewForward;"""
