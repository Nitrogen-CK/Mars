"""HLSL bodies of the Custom nodes in the food masters (mars_food_ue builds the graphs around them).

Every string is a Custom-node function body. The identifiers it reads are the node's input pins, named exactly as
mars_food_ue wires them, and the identifiers it assigns (other than locals) are the node's additional outputs. Pin
names avoid the ones the material editor renames ("Input", "Coordinates", "Exponent", "TextureObject", ...).

Reused unchanged from mars_cooking_hlsl (imported there, not copied here): MEAT_COOK (sear per local axis -> ramp time,
crust, burn, oil), MEAT_NORMAL (tangent normal strength) and MEAT_SHAPE (raw -> cooked offset from UV1 / UV2 scaled by
Finish.y). The food master feeds MEAT_COOK through FOOD_COOK_FIRST so crevices brown later.

Positions are component-local centimetres, Unreal axes.
"""

# ====================================================================================== shared
# Vertex colour -> base colour + cavity AO. Inputs: VC (VertexColor RGB), Cavity (VertexColor A), SrgbDecode (scalar
# switch), CavityAO (scalar). Output AO.
# The legacy FBX importer turns each FBX colour into a byte (FbxStaticMeshImport.cpp, FColor(255 * c) then
# FLinearColor(FColor), an sRGB decode) and the static mesh build turns it back (StaticMeshBuilder.cpp,
# ToFColor(true), an sRGB encode), so VertexColor returns exactly the values the FBX holds. The food FBXs are written
# with colors_type LINEAR, so 0 (no decode) should be right; 1 treats the bytes as sRGB (pow 2.2). The lookdev swatch
# row is the check.
VERTEX_DECODE = """float3 c = saturate(VC);
AO = lerp(1.0, saturate(Cavity), saturate(CavityAO));
return lerp(c, pow(max(c, 1e-6), 2.2), saturate(SrgbDecode));"""

VEC_NORMALIZE = """return normalize(V + float3(0.0, 0.0, 1e-6));"""

# ====================================================================================== food (Food_Mars_M)
# Cook-first: open, exposed facets (mask R x vertex-colour cavity) take the sear first and crevices lag behind, so the
# sear values handed to MEAT_COOK are scaled per pixel. The debug override is resolved here; MEAT_COOK then gets the
# same value on its Sear and Dbg pins, which makes its own debug lerp a no-op.
# Inputs: SearA, SearB, DbgA, DbgB (float4), UseDebug, Mask (RGBA), Cavity, Lag. Main output = scaled Sear XY,
# additional output SearZ = scaled Sear Z + Cook (Penetration and Oil Coat pass through unscaled).
FOOD_COOK_FIRST = """float4 sa = lerp(SearA, DbgA, UseDebug);
float4 sb = lerp(SearB, DbgB, UseDebug);
float cf = saturate(Mask.r * Cavity);
float k = lerp(1.0 - saturate(Lag), 1.0, cf);
SearZ = float4(sb.xy * k, sb.z, sb.w);
return sa * k;"""

# The browning chain. Cook = MEAT_COOK's (ramp time, crust, burn, oil coat); Base = decoded vertex colour; Fin =
# Glaze Shape Fry Wet. Colour: base -> cooked tint (ramp time, which includes the penetration band) -> multiplied
# toward the crust colour by crust, then pulled toward the crust albedo (CrustReplace: a saturated painted base would
# otherwise only get redder, not browner) -> toward the char colour by burn; mask G adds grain. Wet darkens, glosses.
# Outputs: Roughness (before the oil coat), Oil (coat amount for OilCoat_Mars_MF), Patch (coat break-up mask),
# NormalStrength.
FOOD_SURFACE = """float t = Cook.x;
float crust = Cook.y;
float burn = Cook.z;
float4 fin = lerp(Fin, DbgFin, UseDebug);
float glaze = saturate(fin.x);
float wet = saturate(fin.w);

float cooked = smoothstep(0.0, max(CookedAt, 1e-3), t);
float3 col = Base * lerp(float3(1.0, 1.0, 1.0), CookedTint, cooked);
col *= lerp(float3(1.0, 1.0, 1.0), CrustColor, crust);
col = lerp(col, CrustAlbedo, crust * CrustReplace);
col *= 1.0 + (Mask.g - 0.5) * 2.0 * GrainContrast * lerp(0.4, 1.0, crust);
col = lerp(col, CharColor, burn);
col *= 1.0 - WetDarken * wet;                              // soaked food reads ~15 % darker

float rough = lerp(RoughRaw, RoughCrust, crust);
rough = lerp(rough, RoughBurnt, burn);
rough = lerp(rough, rough * WetGloss, wet);

Roughness = saturate(rough);
Oil = saturate(RawWet * (1.0 - crust) + Cook.w + glaze * GlazeStrength + wet * 0.5) * (1.0 - 0.7 * burn);
Patch = Mask.b;
NormalStrength = lerp(NrmRaw, NrmCrust, crust);
return max(col, 0.0);"""

# ====================================================================================== batter (Batter_Mars_M)
# Fry = Finish.z: 0 raw pale wet batter (glossy, high clear coat), 1 golden crisp (crumb roughness from mask G),
# 2 burnt. Drips / edges (mask A) colour first, mask B makes it patchy. Oil = the CPD Oil Coat (Sear Z + Cook .w)
# plus the raw batter's own wetness. Base = decoded vertex colour (the shell is painted pale raw batter).
# Outputs: Roughness, Oil, Patch, NormalStrength.
BATTER_SURFACE = """float4 fin = lerp(Fin, DbgFin, UseDebug);
float4 sb = lerp(SearB, DbgB, UseDebug);
float fry = clamp(fin.z, 0.0, 2.0);
float golden = saturate(fry);
float burnt = saturate(fry - 1.0);
float crumb = Mask.g - 0.5;

float brown = saturate(golden * (1.0 + Mask.a * EdgeBoost) + (Mask.b - 0.5) * FryBreakup * golden * (1.0 - golden) * 2.0);
float scorch = saturate(burnt * (1.0 + Mask.a * EdgeBoost) + (Mask.b - 0.5) * FryBreakup * burnt);
float3 col = Base * lerp(float3(1.0, 1.0, 1.0), GoldenTint, brown);
col *= 1.0 + crumb * 2.0 * CrumbContrast * golden;
col = lerp(col, BurntColor, scorch);

float rough = lerp(RoughRaw, RoughGolden + crumb * CrumbRough, golden);
rough = lerp(rough, RoughBurnt, burnt);

Roughness = saturate(rough);
Oil = saturate(RawCoat * (1.0 - golden) + sb.w) * (1.0 - 0.6 * burnt);
Patch = Mask.b;
NormalStrength = lerp(NrmRaw, NrmFried, golden);
return max(col, 0.0);"""

# ====================================================================================== oil coat (OilCoat_Mars_MF)
# The shared oil / glaze coat, inside the material function. Oil 0..1 and Breakup (a 0..1 mask, 0.5 neutral) come
# from the function inputs, RoughIn is the surface roughness before the coat; Strength, CoatBreakup and BaseGloss
# are the function's own parameters. Main output = clear coat amount, RoughOut = roughness under the coat (oil
# glosses the surface it wets). The .x swizzles keep it valid if the function inputs ever arrive as vectors (a
# scalar swizzles too).
OIL_COAT = """float patchy = lerp(1.0, saturate(Breakup.x * 1.6), saturate(CoatBreakup));
float coat = saturate(Oil.x) * patchy;
RoughOut = saturate(lerp(RoughIn.x, RoughIn.x * BaseGloss, coat));
return saturate(coat * Strength);"""

# ====================================================================================== oil VAT (OilVAT_Mars_M)
# Row = frame (v), column = vertex (u). Column = the VAT UV channel (food_common.write_vat_uvs: x = (index + 0.5) /
# count); T = Time. frame = frac(T * Speed / Seconds); v = (floor(frame * Frames) + 0.5) / Frames, mirrored when FlipV
# is 1 (frame 0 stored on the bottom row). The result feeds the UVs of the two VAT TextureSampleParameter2D nodes,
# which sit in the vertex shader (WPO and a vertex interpolator), where the translator forces mip 0.
OIL_VAT_UV = """float frames = max(round(Frames), 1.0);
float phase = frac(T * Speed / max(Seconds, 1e-3));
float v = (floor(phase * frames) + 0.5) / frames;
v = lerp(v, 1.0 - v, saturate(FlipV));
return float2(Column.x, v);"""

# Vertex-shader packs for the one float4 vertex interpolator: world normal + one scalar (the surface's decoded height,
# Unreal local cm, or the bubbles' pop progress). N = the VAT normal already transformed local -> world.
VAT_PACK_HEIGHT = """return float4(N, Offset.z);"""
# Pos = the VAT position texel (RGBA). Alpha = pop progress (OilVAT_Mars.json version 2: 0 intact, 0..1 across the
# pop, 1 hidden); UsePop is 0 until the JSON carries a "pop" block, which ignores the alpha (older bakes hold 1 there).
VAT_PACK_POP = """return float4(N, saturate(UsePop) * Pos.a);"""

# Opaque oil / stew surface, pixel shader. Packed = interpolated (world normal, height cm). The colour is Liquid Colour
# in the crests and Liquid Colour Deep in the troughs (height below rest over DeepRange cm); UseVC 1 multiplies the
# painted vertex colour in (the oil defaults: both colours white = the painted oil), 0 uses the two colours alone (stew).
OIL_SURFACE_PS = """float depth = saturate(-Packed.w / max(DeepRange, 1e-3));
float3 liquid = lerp(LiquidColor, LiquidDeep, depth);
WorldN = normalize(Packed.xyz + float3(0.0, 0.0, 1e-6));
return liquid * lerp(float3(1.0, 1.0, 1.0), VC, saturate(UseVC));"""

# BubbleGlass_Mars_MF (OilBubble_Mars_M, OilBubbleParticle_Mars_M): opaque fake glass + the pop mask. N = world
# normal; Pop 0..1; CamV = pixel -> camera (world); Side = TwoSidedSign; BubbleUV = (height 0 base .. 1 apex, a
# per-bubble phase); LiquidColor already resolved by the caller (vertex / particle colour). Facing the camera brightens
# toward the apex / view centre, the rim darkens (fresnel) with a thin-film tint; backfaces (the inside of a popping
# dome) read as the liquid times BackDarken. Pop: the dome dissolves from the apex down to 1 - PopReach (the dome is a
# near-hemisphere and its apex sinks during the pop, so a full sweep would put the ring under the liquid halfway
# through); pop >= 0.999 hides the bubble. The edge ripples around the ring (normal angle + BubbleUV.y phase + T, faded
# in with pop) and is dithered (interleaved gradient noise) against the 0.5 opacity-mask clip.
BUBBLE_GLASS = """float3 n = normalize(N + float3(0.0, 0.0, 1e-6));
float pop = saturate(Pop);
float facing = saturate(dot(n * Side, CamV));
float fres = 1.0 - facing;
float3 col = LiquidColor * (1.0 + CentreBrighten * facing * facing * facing) * (1.0 - RimDarken * fres * fres);
float3 film = 0.5 + 0.5 * cos(6.2831853 * (fres * 1.5 + float3(0.0, 0.33, 0.67)));
col = lerp(col, col * film * 1.6, saturate(ThinFilm) * fres * fres * fres);
col = Side > 0.0 ? col : LiquidColor * BackDarken;
float edge = max(PopEdge, 1e-3);
float wobble = PopWobble * sin(atan2(n.y, n.x + 1e-5) * 5.0 + BubbleUV.y * 40.0 + T * 2.0) * saturate(pop * 4.0);
float level = (1.0 + edge) - pop * (saturate(PopReach) + 2.0 * edge);
float keep = smoothstep(-edge, edge, level + wobble - BubbleUV.x) * step(pop, 0.999);
float dither = frac(52.9829189 * frac(dot(Parameters.SvPosition.xy, float2(0.06711056, 0.00583715))));
Mask = keep - dither + 0.5;
WorldN = n;
return max(col, 0.0);"""

# OilBubble_Mars_M: unpack the interpolated (world normal, pop).
VAT_UNPACK = """Pop = Packed.w;
return normalize(Packed.xyz + float3(0.0, 0.0, 1e-6));"""

# Liquid colour with the painted vertex colour multiplied in (UseVC 1) or alone (0).
LIQUID_MIX = """return LiquidColor * lerp(float3(1.0, 1.0, 1.0), VC, saturate(UseVC));"""

# OilBubbleParticle_Mars_M: Liquid Colour or the Niagara particle colour; BubbleLocal height + a per-particle phase
# (DynamicParameter.y).
PARTICLE_LIQUID = """return lerp(LiquidColor, PC, saturate(UsePC));"""
PARTICLE_LOCAL = """return float2(BubbleUV.x, Phase);"""

# Pos / Nrm = the sampled VAT texels (RGB). Position: min + rgb * (max - min), Unreal local cm offset from the rest
# mesh (OilVAT_Mars.json pos_min / pos_max). Normal: rgb * 2 - 1, Unreal local axes (additional output VatNormal).
OIL_VAT_DECODE = """VatNormal = normalize(Nrm * 2.0 - 1.0 + float3(0.0, 0.0, 1e-4));
return PosMin + Pos * (PosMax - PosMin);"""


# ====================================================================== Niagara bubbles (OilBubbles_Mars_NS)
# Niagara custom-HLSL module bodies (mars_food_niagara builds them through Monolith create_module_from_hlsl). Module
# inputs are bare names bound to the system's User.* parameters; particle attributes are read / written directly. Only
# attributes the stack has already encountered can be used (a new one fails to compile), so the per-particle state is
# carried in existing ones: Color.a = a random phase (the material reads Color.rgb only), the radius is derived from it,
# and the ride wobble is applied as a per-frame delta from Age and DeltaTime (no stored base position).
# Positions are emitter-local cm (local-space emitter): the mesh pivot is the bubble's base. The CPU VM has no
# smoothstep op: write the polynomial out.

# Particle Spawn, after InitializeParticle: a disc of SpawnRadius, or a SpawnExtent box when both extents are > 0 (the
# pan's rectangle); starts StartDepth below SurfaceZ, fully submerged; random lifetime and radius; colour + phase.
NS_BUBBLE_SPAWN = """float a = rand(1.0f);
float b = rand(1.0f);
float ph = rand(1.0f);
float ang = a * 6.2831853;
float2 disc = float2(cos(ang), sin(ang)) * sqrt(b) * SpawnRadius;
float2 box = (float2(a, b) - 0.5) * SpawnExtent;
float useBox = step(0.001, min(SpawnExtent.x, SpawnExtent.y));
float2 xy = lerp(disc, box, useBox);
float r = lerp(BubbleRadiusMin, BubbleRadiusMax, frac(ph * 7.31 + 0.13));
Particles.Position = float3(xy, SurfaceZ - StartDepth - 2.0 * r);
Particles.Lifetime = lerp(LifetimeMin, LifetimeMax, rand(1.0f));
Particles.Color = float4(LiquidColour.rgb, ph);
Particles.Scale = float3(r, r, r);"""

# Particle Update, after ParticleState and the stock DynamicMaterialParameters module (which registers the attribute):
# rise with ease-out over RiseFraction of the life to SurfaceZ (half submerged at SurfaceSink 1), then ride: a small
# xy wobble and a ScalePulse scale pulse; over the last PopFraction: DynamicMaterialParameter.x = pop 0..1 (the material
# dissolves the dome), xy scale grows to RingScale and z drops to ApexSink; ParticleState kills it at the end of its life.
NS_BUBBLE_UPDATE = """float t = saturate(Particles.NormalizedAge);
float ph = Particles.Color.a;
float r = lerp(BubbleRadiusMin, BubbleRadiusMax, frac(ph * 7.31 + 0.13));
float rise = saturate(t / max(RiseFraction, 0.001));
float ease = 1.0 - (1.0 - rise) * (1.0 - rise);
float pop = saturate((t - (1.0 - PopFraction)) / max(PopFraction, 0.001));
float zStart = SurfaceZ - StartDepth - 2.0 * r;
float zEnd = SurfaceZ - r * SurfaceSink;
float ride = step(0.999, rise);
float age = Particles.Age;
float w = 6.2831853 * WobbleFrequency;
float2 w1 = float2(sin(w * age + ph * 6.2831853), cos(w * 1.3 * age + ph * 4.1));
float2 w0 = float2(sin(w * (age - DeltaTime) + ph * 6.2831853), cos(w * 1.3 * (age - DeltaTime) + ph * 4.1));
float2 dxy = (w1 - w0) * WobbleAmplitude * ride;
Particles.Position = float3(Particles.Position.xy + dxy, lerp(zStart, zEnd, ease));
float pulse = 1.0 + ScalePulse * sin(w * 2.0 * age + ph * 9.0) * ride * (1.0 - pop);
float sxy = r * pulse * lerp(1.0, RingScale, pop);
float sz = r * pulse * lerp(1.0, ApexSink, pop);
Particles.Scale = float3(sxy, sxy, sz);
Particles.DynamicMaterialParameter = float4(pop, ph, 0.0, 0.0);"""


# ====================================================================== Niagara oil splatter (OilSplatter_Mars_NS)
# Flat droplets flung outward from the meat's footprint edge, landing on the oil surface and fading. Rendered as the
# engine's 1 m plane (mesh renderer, flat on XY = "aligned to the surface"), so Scale is 0.01 x the droplet size in cm;
# Scale.z (meaningless on a flat plane) carries the spawn size, SpriteRotation / 360 the random phase. Droplets spawned
# in the same 1 / BurstsPerSecond window share a direction (a burst); Time = Emitter.Age.
NS_SPLATTER_SPAWN = """float slot = floor(Time * BurstsPerSecond);
float base = frac(sin(slot * 12.9898 + 4.1) * 43758.5453);
float ph = rand(1.0f);
float ang = (base + (rand(1.0f) - 0.5) * 0.14) * 6.2831853;
float2 dir = float2(cos(ang), sin(ang));
Particles.Position = float3(dir * SplatterRadius, SurfaceZ + 0.02);
Particles.Lifetime = SplatterLife * lerp(0.8, 1.2, rand(1.0f));
Particles.SpriteRotation = ph * 360.0;
float s = lerp(SplatterSizeMin, SplatterSizeMax, rand(1.0f)) * 0.01;
Particles.Scale = float3(s * 0.6, s * 0.6, s);
Particles.Color = SplatterColour;"""

# Flight: radial (outward from the emitter origin) ease-out over 0.25..0.4 s to a FlingMin..FlingMax distance, applied as
# a per-frame delta, with a small arc of SplatterArc cm; then flat on SurfaceZ, spread to 1.25x, fading over the life.
NS_SPLATTER_UPDATE = """float ph = frac(Particles.SpriteRotation / 360.0);
float d = lerp(FlingMin, FlingMax, frac(ph * 7.31 + 0.2));
float tf = 0.25 + 0.15 * frac(ph * 3.7);
float age = Particles.Age;
float u1 = saturate(age / tf);
float u0 = saturate((age - DeltaTime) / tf);
float s1 = 1.0 - (1.0 - u1) * (1.0 - u1);
float s0 = 1.0 - (1.0 - u0) * (1.0 - u0);
float2 dir = normalize(Particles.Position.xy + float2(1e-4, 0.0));
float2 xy = Particles.Position.xy + dir * d * (s1 - s0);
float z = SurfaceZ + 0.02 + SplatterArc * 4.0 * u1 * (1.0 - u1) * (0.4 + 0.6 * frac(ph * 5.1 + 0.3));
Particles.Position = float3(xy, z);
float s = Particles.Scale.z;
float grow = lerp(0.6, 1.0, u1) * lerp(1.0, 1.25, step(1.0, u1));
Particles.Scale = float3(s * grow, s * grow, s);
float t = saturate(Particles.NormalizedAge);
float f = saturate((t - 0.35) / 0.65);                     // smoothstep: the CPU VM has no smoothstep op
Particles.Color = float4(Particles.Color.rgb, 1.0 - f * f * (3.0 - 2.0 * f));"""

# OilSplatter_Mars_M: a soft round droplet with a wobbly edge and a darker rim on the plane's UV0. PC = Particle Color
# (rgb), PCA = its alpha (the fade); Seed varies the outline per droplet (from the particle's world position).
SPLATTER_SPOT = """float2 p = (UV - 0.5) * 2.0;
float r = length(p);
float a = atan2(p.y, p.x);
float edge = 0.82 + Wobble * (0.08 * sin(a * 5.0 + Seed * 6.2831853) + 0.05 * sin(a * 9.0 + Seed * 3.1));
float body = 1.0 - smoothstep(edge - Softness, edge, r);
float rim = smoothstep(edge - 0.4, edge - 0.05, r);
Opa = body * saturate(PCA);
return PC * (1.0 - RimDarken * rim);"""
