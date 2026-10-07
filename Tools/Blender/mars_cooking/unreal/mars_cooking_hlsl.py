"""HLSL bodies of the Custom nodes in Meat_Mars_M and Pan_Mars_M (mars_cooking_ue builds the graphs around them).

All positions are component-local centimetres. Helper functions live in a local struct because a Custom node body
is itself a function body.
"""

# ====================================================================================== meat
# Sear state -> (ramp time, crust 0..1, burn 0..1, oil coat). SearA = +X -X +Y -Y, SearB = +Z -Z Penetration OilCoat.
MEAT_COOK = """float4 sa = lerp(SearA, DbgA, UseDebug);
float4 sb = lerp(SearB, DbgB, UseDebug);
float3 he = max((BMax - BMin) * 0.5, 1e-3);
float3 q = (P - (BMax + BMin) * 0.5) / he;
float3 n = normalize(N);

// how much each seared axis faces this pixel (per-face on a cube, a smooth blend on round shapes)
float3 wp = pow(saturate(n), Sharp);
float3 wn = pow(saturate(-n), Sharp);
float wsum = wp.x + wp.y + wp.z + wn.x + wn.y + wn.z + 1e-5;
float face = (wp.x * sa.x + wn.x * sa.y + wp.y * sa.z + wn.y * sa.w + wp.z * sb.x + wn.z * sb.y) / wsum;

// the cooked band creeping in from every seared face (distance to that face, cm)
float wobble = (Mask.b - 0.5) * BandWobble;
float3 dpos = (1.0 - q) * he + wobble;
float3 dneg = (1.0 + q) * he + wobble;
float s6[6] = { sa.x, sa.y, sa.z, sa.w, sb.x, sb.y };
float d6[6] = { dpos.x, dneg.x, dpos.y, dneg.y, dpos.z, dneg.z };
float reach = BandDepth * sb.z;
float band = 0.0;
for (int i = 0; i < 6; i++)
{
    float depth = max(saturate(s6[i]) * reach, 1e-3);
    // a barely touched face (splatter) grows no band: the band's wobble would mottle it
    band = max(band, (1.0 - smoothstep(depth * (1.0 - BandSoft), depth, d6[i])) * smoothstep(0.1, 0.35, s6[i]));
}
band *= saturate(reach * 20.0);

// the crust comes up in patches and a little faster on the edges
float sear = face * (1.0 + Mask.a * EdgeBoost);
sear = max(0.0, sear + (Mask.b - 0.5) * Breakup * saturate(sear * 3.0));
float u = max(sear / max(SearRange, 1e-3), band * BandRamp);
return float4(saturate(u), smoothstep(0.2, 0.9, sear), saturate((sear - 1.25) / 0.6), sb.w);"""

# Colour, roughness, coat and normal strength from the cook state. Cook = MEAT_COOK's result, Fin = Glaze Shape - -.
MEAT_SURFACE = """float fat = Mask.r;
float crust = Cook.y;
float burn = Cook.z;
float glaze = lerp(Fin.x, DbgFin.x, UseDebug);

// marbling reads clearly while raw and melts into the crust as it browns
float3 col = lerp(Lean, Fat, fat * (1.0 - 0.75 * crust));
col *= 1.0 + (Mask.g - 0.5) * 2.0 * FibreContrast * lerp(0.4, 1.0, crust);

float rough = lerp(lerp(RoughLean, RoughFat, fat), RoughCrust, crust);
rough -= fat * crust * FatGloss;                       // rendered fat is glossy
rough = lerp(rough, RoughBurnt, burn);

float patchy = lerp(1.0, saturate(Mask.b * 1.6), CoatBreakup);
float coat = RawWet * (1.0 - crust) + (Cook.w * OilStrength + glaze * GlazeStrength) * patchy;

Roughness = saturate(rough);
Coat = saturate(coat) * (1.0 - 0.7 * burn);
NormalStrength = lerp(NrmRaw, NrmCrust, crust);
return col;"""

MEAT_NORMAL = """return normalize(float3(Nrm.xy * Strength, Nrm.z));"""

# Raw -> cooked shape: the offset baked into UV1 (x, y) and UV2.x (z), local centimetres.
MEAT_SHAPE = """float shape = lerp(Fin.y, DbgFin.y, UseDebug);
return float3(UV1.x, UV1.y, UV2.x) * saturate(shape) * Scale;"""


# ====================================================================================== pan
# The oil pool: a centre puddle merged with a blob that trails the meat. Returns (normal tilt xy, film 0..1); the
# simmer comes out as Bubble (dome mask) and BubbleRim (its outline).
PAN_POOL = """struct FPanPool
{
    float2 MeatPos; float MeatR; float2 TrailPos;
    float Amount; float PoolR; float Margin; float Blend; float Wobble; float BaseR;

    float Hash(float2 p) { return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }
    float Noise(float2 p)
    {
        float2 i = floor(p);
        float2 f = frac(p);
        f = f * f * (3.0 - 2.0 * f);
        return lerp(lerp(Hash(i), Hash(i + float2(1.0, 0.0)), f.x),
                    lerp(Hash(i + float2(0.0, 1.0)), Hash(i + float2(1.0, 1.0)), f.x), f.y);
    }
    // signed distance to the pool edge (cm, negative inside)
    float Sdf(float2 p)
    {
        float d = length(p) - PoolR * sqrt(saturate(Amount));
        if (MeatR > 0.01)
        {
            float2 pa = p - MeatPos;
            float2 ba = TrailPos - MeatPos;
            float h = saturate(dot(pa, ba) / max(dot(ba, ba), 1e-4));
            float dm = length(pa - ba * h) - (MeatR + Margin * Amount);
            float k = max(Blend, 1e-3);
            float t = saturate(0.5 + 0.5 * (dm - d) / k);
            d = lerp(dm, d, t) - k * t * (1.0 - t);
        }
        d += (Noise(p * 0.9) - 0.5) * Wobble;
        return max(d, length(p) - BaseR - 0.6);          // the pool cannot climb the wall
    }
};
FPanPool pool;
pool.MeatPos = Meat.xy; pool.MeatR = Meat.z; pool.TrailPos = Trail.xy;
pool.Amount = OilAmount; pool.PoolR = PoolR; pool.Margin = Margin; pool.Blend = Blend; pool.Wobble = Wobble; pool.BaseR = BaseR;

float2 p = P.xy;
float d = pool.Sdf(p);
float on = saturate(OilAmount * 20.0);
float soft = max(EdgeSoft, 1e-3);
float film = (1.0 - smoothstep(-soft, 0.0, d)) * on;

// meniscus: the film's edge leans outward, which is where the highlight catches
float2 e = float2(0.06, 0.0);
float2 g = float2(pool.Sdf(p + e.xy) - pool.Sdf(p - e.xy), pool.Sdf(p + e.yx) - pool.Sdf(p - e.yx));
g /= max(length(g), 1e-4);
float rim = smoothstep(-soft * 2.5, -soft * 0.5, d) * (1.0 - smoothstep(-soft * 0.5, soft * 0.5, d)) * on;
float2 nxy = g * rim * Meniscus;

// simmer: small domes that swell and pop wherever there is oil. Sizzle sets how many cells are alive and speeds
// them up; a band around the meat (Simmer Width) bubbles harder; nothing bubbles under the meat.
float bubble = 0.0;
float bubbleRim = 0.0;
if (Sizzle > 0.001)
{
    float nearMeat = 0.0;
    float under = 1.0;
    if (Meat.z > 0.01)
    {
        float dm = length(p - Meat.xy) - Meat.z;
        nearMeat = smoothstep(-0.4, 0.0, dm) * (1.0 - smoothstep(SimW * 0.4, SimW, dm));
        under = smoothstep(-0.5, 0.0, dm);
    }
    float gate = film * under * saturate(0.75 + 0.25 * Sizzle + SimNear * nearMeat);
    float2 gc = p / SimCell;
    float2 id = floor(gc);
    float r1 = pool.Hash(id + 3.7);
    float ph = T * SimRate * (0.75 + 0.5 * saturate(Sizzle)) * (0.6 + 0.8 * r1) + pool.Hash(id + 11.3);
    float cyc = floor(ph);
    ph -= cyc;
    float2 c = 0.3 + 0.4 * float2(pool.Hash(id + cyc * 1.37), pool.Hash(id.yx + cyc * 2.11 + 5.0));
    float alive = step(pool.Hash(id + cyc * 0.73 + 9.0), saturate(Sizzle * SimDensity * (1.0 + SimNear * nearMeat)));
    float rad = max(SimCell * 0.3 * (0.4 + 0.6 * r1) * sqrt(ph), 1e-3);
    float2 dv = (frac(gc) - c) * SimCell;
    float dist = length(dv);
    float x = saturate(dist / rad);                                   // 0 at the dome's top, 1 at its foot
    float live = (1.0 - smoothstep(0.8, 1.0, ph)) * alive * gate;
    bubble = smoothstep(0.0, 0.2, 1.0 - x) * live;
    bubbleRim = smoothstep(0.45, 0.8, x) * (1.0 - smoothstep(0.92, 1.0, x)) * live;   // the dark bead outline
    nxy += dv / max(dist, 1e-4) * x * bubble * SimStrength;
}
BubbleRim = bubbleRim;
Bubble = bubble;
return float3(nxy, film);"""

# Drops running down the wall toward the centre plus still beads. Returns (normal tilt xy, coverage 0..1).
PAN_DROPS = """struct FPanDrops
{
    float Hash(float2 p) { return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }
    float2 Hash2(float2 p)
    {
        return frac(sin(float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)))) * 43758.5453);
    }
    // one layer of still beads on a jittered grid: xy = normal tilt, z = mask
    float3 Beads(float2 p, float cell, float density, float size)
    {
        float2 g = p / cell;
        float2 id = floor(g);
        float2 k = Hash2(id + cell * 13.0);
        float2 c = 0.32 + 0.36 * Hash2(id + 5.3);
        float rad = max(cell * 0.3 * size * (0.35 + 0.65 * k.y), 1e-3);
        float2 dv = (frac(g) - c) * cell;
        float dist = length(dv);
        float m = smoothstep(0.0, 0.3, saturate(1.0 - dist / rad)) * step(k.x, density);
        return float3(dv / max(dist, 1e-4) * (dist / rad) * m, m);
    }
};
FPanDrops o;
float2 p = P.xy;
float r = length(p);
float2 rdir = p / max(r, 1e-3);
float2 tdir = float2(-rdir.y, rdir.x);
float up = saturate(normalize(N).z * 3.0);
float amount = saturate(OilAmount * 3.0);
float wall = smoothstep(BaseR - 1.0, BaseR + 1.5, r) * (1.0 - smoothstep(RimR - 1.2, RimR - 0.3, r)) * up;

// running drops: a polar grid that scrolls toward the centre, one drop per live cell. Downhill is -r.
float cols = max(round(Cols), 3.0);
float x = (atan2(p.y, p.x) / 6.2831853 + 0.5) * cols;
float ci = min(floor(x), cols - 1.0);
float fx = x - ci;
float c1 = o.Hash(float2(ci, 1.7));
float speed = Speed * (0.45 + 1.1 * c1);
float y = (r + T * speed) / RowLen + o.Hash(float2(ci, 9.1)) * 31.0;
float ri = floor(y);
float fy = y - ri;
float2 k = o.Hash2(float2(ci, ri));
float live = step(k.x, Density * amount);
float cx = 0.5 + (k.y - 0.5) * 0.4;
float cy = 0.32 + 0.14 * sin(T * speed / RowLen * 3.0 + k.x * 6.2831853);     // stop-and-go, never uphill
float2 dv = float2((fx - cx) * 6.2831853 * r / cols, (fy - cy) * RowLen);       // cm; +y is uphill
float size = max(Size * (0.6 + 0.8 * k.y), 1e-3);
float2 dh = float2(dv.x, dv.y > 0.0 ? dv.y * 0.55 : dv.y);                      // teardrop: longer uphill
float dist = length(dh);
float head = smoothstep(0.0, 0.25, saturate(1.0 - dist / size)) * live;
float2 nt = dh / max(dist, 1e-4) * (dist / size) * head;
float along = saturate(dv.y / max(Trail, 1e-3));
float tw = size * 0.5 * (1.0 - 0.7 * along);
float streak = (1.0 - smoothstep(tw * 0.4, tw, abs(dv.x))) * step(0.0, dv.y) * (1.0 - along)
             * (1.0 - smoothstep(0.85, 1.0, fy)) * live;
nt.x += sign(dv.x) * smoothstep(0.0, tw, abs(dv.x)) * streak * 0.5;
float run = max(head, streak * 0.7) * wall;
float2 nxy = (tdir * nt.x + rdir * nt.y) * wall;

// still beads, two sizes
float still = (1.0 - smoothstep(RimR - 1.0, RimR - 0.2, r)) * up;
float3 b1 = o.Beads(p, BeadCell, BeadDensity * amount, BeadSize);
float3 b2 = o.Beads(p + 3.7, BeadCell * 0.46, BeadDensity * amount * 0.5, BeadSize);
float3 beads = (b1.z > b2.z ? b1 : b2) * still;
nxy += beads.xy * BeadNormal;
return float3(nxy, max(run, beads.z));"""

# Brushed metal + seasoning + the oil layers -> colour, roughness, metallic, clear coat and the local-space normal.
PAN_SURFACE = """struct FPanSurf
{
    float Hash1(float x) { return frac(sin(x * 127.1) * 43758.5453); }
    float Noise1(float x)
    {
        float i = floor(x);
        float f = frac(x);
        f = f * f * (3.0 - 2.0 * f);
        return lerp(Hash1(i), Hash1(i + 1.0), f);
    }
    float Hash(float2 p) { return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }
    float Noise(float2 p)
    {
        float2 i = floor(p);
        float2 f = frac(p);
        f = f * f * (3.0 - 2.0 * f);
        return lerp(lerp(Hash(i), Hash(i + float2(1.0, 0.0)), f.x),
                    lerp(Hash(i + float2(0.0, 1.0)), Hash(i + float2(1.0, 1.0)), f.x), f.y);
    }
};
FPanSurf s;
float2 p = P.xy;
float r = length(p);
float3 n = normalize(N);
float inside = saturate(n.z * 3.0) * (1.0 - smoothstep(RimR + 0.1, RimR + 0.4, r));   // the cooking surface

// lathe rings: roughness streaks and a faint radial tilt, faded out before they alias
float rf = r * RingFreq;
float ring = (s.Noise1(rf) - 0.5) + 0.5 * (s.Noise1(rf * 3.1 + 7.0) - 0.5);
ring *= saturate(1.0 - fwidth(rf) * 1.5);
float rough = Rough + ring * RingStrength;

// seasoning: burnt-on oil. Thin, it bronzes the steel; thick, it is a near-black matte skin. Fond adds to it.
float amount = Seasoning + Fond;
float blotch = s.Noise(p * 0.3) * 0.55 + s.Noise(p * 0.95 + 4.0) * 0.3 + s.Noise(p * 2.7 + 9.0) * 0.15;
float bands = s.Noise1(r * 1.7 + 3.0 + blotch * 2.5) * 0.6 + s.Noise1(r * 4.3 + blotch * 4.0) * 0.4;   // wobbly scorch rings
float reach = r + (blotch - 0.5) * SeasonRadius * 0.7 * SeasonBreakup;
float cover = (1.0 - smoothstep(SeasonRadius * 0.6, SeasonRadius * 1.15, reach)) * inside;
float thick = cover * lerp(0.6, 1.3, blotch) * lerp(1.0 - 0.6 * SeasonBands, 1.0, bands) * amount;
float bronze = smoothstep(0.0, 0.25, thick);
float skin = smoothstep(0.2, 0.7, thick);
float speck = smoothstep(0.8, 0.9, s.Noise(p * 5.5 + 2.0)) * cover * saturate(amount * 2.0) * SeasonSpecks;
skin = saturate(max(skin, speck));
float3 col = lerp(MetalColor * lerp(1.0, SeasonThin, bronze), SeasonThick, skin);
float metal = lerp(Metallic, SeasonMetal, skin);
rough = lerp(rough + 0.08 * bronze, SeasonRough, skin);

// oil: a clear film. It wets and warms what is under it, carries a darker line at its edge, and is the clear coat.
float film = Pool.z * inside;
float drops = Drops.z * (1.0 - film) * inside;
float wet = saturate(film + drops * 0.6);
col *= lerp(1.0, OilTint, wet);
float body = film * OilOpacity;                                // the oil's own amber hides part of what is under it
col = lerp(col, OilBody, body);
metal = lerp(metal, 0.0, body);
col *= 1.0 - film * (1.0 - film) * 4.0 * OilEdge;              // the meniscus is thicker, so darker
rough = lerp(rough, rough * 0.55, wet);

// simmer beads: a dark outline (the bead's side refracts the dark pan) around a clear dome that keeps the
// highlight; the dome's tilt comes in through Pool.xy
col *= 1.0 - saturate(BubbleRim * SimRimDark) * inside;
col = lerp(col, col * OilTint, Bubble * inside * 0.5);

// the meat's dark reflection, which the reflection capture cannot give
if (Meat.z > 0.01)
{
    col *= 1.0 - (1.0 - smoothstep(Meat.z * 0.6, Meat.z + ContactSoft, length(p - Meat.xy))) * Contact * inside;
}

n.xy += p / max(r, 1e-3) * ring * RingStrength * 0.25 * (1.0 - film);
n = lerp(n, float3(0.0, 0.0, 1.0), film * OilLevel);                                   // a liquid lies level
n.xy += (Pool.xy + Drops.xy * DropNormal * (1.0 - film)) * inside;

OutRoughness = saturate(rough);
OutMetallic = saturate(metal);
OutCoat = saturate(max(max(film, drops), Bubble * inside)) * OilCoat;
OutNormal = normalize(n);
return col;"""
