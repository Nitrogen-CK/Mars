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
# Spawn: at the core, 1 s; three times the flame wide. Two overlap (SpawnRate 2) and the material cross-fades them on age.
NS_GLOW_SPAWN = """Particles.Position = float3(0.0, 0.0, Size * 0.45);
Particles.Lifetime = 1.0;
Particles.Color = float4(Colour.rgb, rand(1.0f));
Particles.SpriteSize = float2(Size * 3.0, Size * 3.0);
Particles.SpriteRotation = 0.0;"""

NS_GLOW_UPDATE = """float t = saturate(Particles.NormalizedAge);
Particles.Position = float3(0.0, 0.0, Size * 0.45 + Wind.z * 0.002 * Size);
Particles.DynamicMaterialParameter = float4(Particles.Color.a, t, Intensity, 0.0);"""

# ====================================================================================== materials
# A cheap value noise (two octaves) for the erosion: UV-space, scrolled by time. Inputs UV (float2), Time, Scale, Speed.
NOISE_HLSL = """float2 p = UV * Scale + float2(0.0, -Time * Speed);
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
