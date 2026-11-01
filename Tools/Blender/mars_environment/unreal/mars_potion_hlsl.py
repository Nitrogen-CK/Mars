"""HLSL bodies for the potion (PotionLiquid_Mars_M, PotionCork_Mars_M), built by mars_potion_ue inside the editor. Plain
python: no unreal, no bpy.

The liquid is a closed mesh inside the flask: a sphere (the body) and the neck, pivot at the sphere's centre. It is drawn
masked and two-sided: every pixel above the liquid's surface plane is clipped, a front face below it is the liquid seen
through its wall, and a back face below it stands for the surface (the camera ray through it crosses the plane before it
reaches the far wall, so the shader shades that crossing point instead). The plane is dot(X, N) = Level * R about the
sphere's centre, with N and Level written by the entity script (custom primitive data 0-3): because the body is a sphere,
a plane at a fixed distance from its centre cuts the same volume however the flask is turned, so the fill holds.

Every position here is TRUE world space relative to the sphere's centre. A first-person primitive's pixel world position is
squashed toward the camera (FirstPersonScale), so D is the local position interpolated from the vertex shader (which runs
before the first-person transform) and turned into a world vector; the camera is the fixed point of that transform, so the
camera ray through D in true space is the ray through the pixel.
"""

# ====================================================================================== liquid
# Inputs: D (pixel - centre, world cm, true space), CamRel (camera - centre), Unit (local X axis in world: its length is the
# component's scale), UnitZ (local Z axis in world), Radius (the sphere's local radius, cm; a jar's), HalfHeight (a jar's), Surface (xyz the surface normal, w the level in radii), Slosh
# (0..1 ripple energy), Agitation (0..1, the script's lagged slosh: the cap's breakup, the aeration band, the whitecaps),
# Phase (0..1 per potion), Time, Sign (TwoSidedSign), Nw (vertex normal, world), the look.
# The surface is a height field (MARS_LIQ_HEIGHT: long swell plus an agitation-driven chop); a back face marches the camera
# ray to it (12 steps, 4 bisections), so crests and troughs show in silhouette, not only in the normal.
# Return: base colour. Extra outputs: OutNormal (world), OutEmissive, OutMask (1 keep, 0 clip), OutRough.
#
# Variants (one Custom node per combination, picked by the master's static switches through these defines):
#   MARS_LIQ_BUBBLING  a boil: bubbles rising through the volume (three layers along the ray), domes swelling and popping
#                      on the surface, the surface churned, and the rim band broken into froth beads that swell and pop
#                      round the axis, more of them the harder it boils. Boil, Bubble Scale / Speed / Density, Rim Froth,
#                      Rim Froth Frequency.
#   MARS_LIQ_BRINE     a pickling brine: cloudy rather than glowing (Haze Color by Turbidity along the ray), a sediment
#                      cloud low in the vessel, and suspended peppercorns, mustard seeds and dill (five layers along the
#                      ray) that drift and settle and swirl when the liquid sloshes. Haze Color, Turbidity, Sediment, Speck Amount / Scale.
# And one static switch that reaches the code as a constant input (Jar, 1 or 0; the compiler drops the dead branch):
#   Pickle Jar         the vessel is a cylinder (Radius, Half Height; its axis the mesh's local Z, pivot at its middle), so
#                      the level is the plane through the axis at the fill height (Surface.w in half-heights, -1 empty ..
#                      1 full): it holds the volume while the surface stays clear of the floor and the lid. And it is
#                      packed with upright low-poly pickles, traced along the ray (each a convex solid: two bands of seven
#                      facets that bulge to the middle, bevelled ends, pale warts), seen through the brine's veil, a tip
#                      over the surface drawn dry. Pickle Count / Radius / Length / Color / Light / Glow, Wart Color, Pickle Veil.
#                      They move with the slosh: Pickle Sway leans the tops back against the surface's tilt, Pickle Bob
#                      lifts and rocks each one while the liquid churns.
LIQUID_PS = r"""
#ifndef MARS_LIQ_HASH3
#define MARS_LIQ_HASH3(c) frac(sin(float3(dot(c, float3(127.1, 311.7, 74.7)), dot(c, float3(269.5, 183.3, 246.1)), dot(c, float3(113.5, 271.9, 124.6)))) * 43758.5453)
#endif
float S = max(length(Unit), 1e-4);
float R = max(Radius * S, 1e-3);
float3 N = normalize(Surface.xyz + float3(0.0, 0.0, 1e-4));
float h = Surface.w * R;

// the vessel's frame (the mesh's local axes in world); a jar's plane passes through its axis at the fill height
float3 Ax = Unit / S;
float3 Az = normalize(UnitZ);
float3 Ay = cross(Az, Ax);
bool jar = Jar > 0.5;
float HH = max(HalfHeight * S, 1e-3);
if (jar)
{ h = Surface.w * HH * dot(Az, N); }
// where a ray O + V t enters and leaves the jar's cylinder (t in V's units; TIN > TOUT: a miss)
#define MARS_LIQ_CYL(O, V, TIN, TOUT) \
{ \
    float3 _or = O - Az * dot(O, Az); \
    float3 _vr = V - Az * dot(V, Az); \
    float _a = max(dot(_vr, _vr), 1e-8); \
    float _b = dot(_or, _vr); \
    float _d = _b * _b - _a * (dot(_or, _or) - R * R); \
    float _sq = sqrt(max(_d, 0.0)); \
    float _vz = dot(V, Az); \
    _vz = abs(_vz) > 1e-6 ? _vz : 1e-6; \
    float _z0 = (-HH - dot(O, Az)) / _vz; \
    float _z1 = (HH - dot(O, Az)) / _vz; \
    TIN = _d < 0.0 ? 1e9 : max((-_b - _sq) / _a, min(_z0, _z1)); \
    TOUT = _d < 0.0 ? -1e9 : min((-_b + _sq) / _a, max(_z0, _z1)); \
}

// the surface's own frame, for the ripples
float3 T1 = normalize(cross(abs(N.x) < 0.9 ? float3(1.0, 0.0, 0.0) : float3(0.0, 1.0, 0.0), N));
float3 T2 = cross(N, T1);

// the camera ray through this pixel and where it crosses the flat surface (0 at the camera, 1 at this pixel)
float3 V = D - CamRel;
float vN = dot(V, N);
float tPlane = (h - dot(CamRel, N)) / (abs(vN) > 1e-5 ? vN : 1e-5);
float3 Sflat = CamRel + V * saturate(tPlane);

// the surface is a height field over the plane, in its own frame (T1, T2), measured along N:
//   swell  three long travelling waves, a faint shimmer at rest, louder while it sloshes (and while it boils);
//   chop   the breakup: crossed products of shorter waves, sharpened into crests, whose height grows with Agitation (the
//          script's lagged slosh energy) and whose frequency climbs with it, so a jolt tears the flat cap into a churn
//          that calms back into long swell as Agitation decays.
float churn = 0.04 + Slosh;
float rippleSpeed = RippleSpeed;
float agit = saturate(Agitation);
#if MARS_LIQ_BUBBLING
churn += 0.5 * Boil;
rippleSpeed *= 1.0 + Boil;
agit = saturate(agit + 0.35 * Boil);
#endif
float swellAmp = RippleAmount * R * churn;
float chopAmp = BreakupAmount * R * agit;
float chopFreq = RippleScale * BreakupFrequency * (0.5 + agit) / R;
float tSwell = Time * rippleSpeed + Phase * 17.0;
float tChop = Time * BreakupSpeed * (0.6 + agit) + Phase * 5.0;
#define MARS_LIQ_HEIGHT(X, OUT) \
{ \
    float2 _p = float2(dot(X, T1), dot(X, T2)); \
    float2 _a = _p * (RippleScale / R); \
    OUT = swellAmp * (sin(dot(_a, float2(0.96, 0.28)) + tSwell) + 0.6 * sin(dot(_a, float2(-0.53, 0.85)) * 1.7 + tSwell * 1.31) \
        + 0.35 * sin(dot(_a, float2(-0.39, -0.92)) * 2.9 + tSwell * 1.87)) / 1.95; \
    float2 _c = _p * chopFreq; \
    float _w = sin(dot(_c, float2(0.8, 0.6)) + tChop) * sin(dot(_c, float2(-0.6, 0.8)) * 1.3 - tChop * 1.2) \
        + 0.5 * sin(dot(_c, float2(0.31, -0.95)) * 2.3 + tChop * 1.7) * sin(dot(_c, float2(0.95, 0.31)) * 1.9 - tChop * 0.9); \
    OUT += chopAmp * sign(_w) * pow(abs(_w) / 1.5, 0.6); \
}

// signed height of this pixel over the surface: above it is air
float hereH;
MARS_LIQ_HEIGHT(D, hereH);
float s = dot(D, N) - h - hereH;
OutMask = s <= 0.0 ? 1.0 : 0.0;

// where the camera ray first meets the surface: march from where the ray enters the sphere, or comes down past the
// highest crest, to this pixel (which is under the surface: the clip kept it), then refine by bisection. A front face
// only needs the flat crossing for its rim measure; a back face shades the hit.
float3 Ssurf = Sflat;
float3 surfN = N;
float surfH = 0.0;
if (Sign <= 0.0)
{
    float hiCrest = abs(swellAmp) + chopAmp * 1.1 + 1e-3;
    float va = dot(V, V);
    float vb = dot(CamRel, V);
    float vc = dot(CamRel, CamRel) - R * R;
    float disc = vb * vb - va * vc;
    float tIn = disc > 0.0 ? (-vb - sqrt(disc)) / va : 0.0;
    if (jar)
    {
        float tOut;
        MARS_LIQ_CYL(CamRel, V, tIn, tOut);
        tIn = tIn < tOut ? tIn : 0.0;
    }
    float t0 = max(tIn, 0.0);
    if (vN < -1e-5)
    { t0 = max(t0, (h + hiCrest - dot(CamRel, N)) / vN); }
    t0 = min(t0, 1.0);
    float tLo = t0;
    float tHi = 1.0;
    bool found = false;
    [unroll] for (int m = 1; m <= 12; ++m)
    {
        float t = lerp(t0, 1.0, m / 12.0);
        float3 X = CamRel + V * t;
        float hh;
        MARS_LIQ_HEIGHT(X, hh);
        if (!found && dot(X, N) - h - hh <= 0.0)
        {
            tHi = t;
            found = true;
        }
        if (!found)
        { tLo = t; }
    }
    [unroll] for (int b = 0; b < 4; ++b)
    {
        float t = 0.5 * (tLo + tHi);
        float3 X = CamRel + V * t;
        float hh;
        MARS_LIQ_HEIGHT(X, hh);
        if (dot(X, N) - h - hh <= 0.0)
        { tHi = t; }
        else
        { tLo = t; }
    }
    Ssurf = CamRel + V * tHi;
    // the normal from the height field's slope (central differences along the surface's frame)
    float e = 0.02 * R;
    float hx0, hx1, hy0, hy1;
    float3 Sx0 = Ssurf - T1 * e;
    float3 Sx1 = Ssurf + T1 * e;
    float3 Sy0 = Ssurf - T2 * e;
    float3 Sy1 = Ssurf + T2 * e;
    MARS_LIQ_HEIGHT(Sx0, hx0);
    MARS_LIQ_HEIGHT(Sx1, hx1);
    MARS_LIQ_HEIGHT(Sy0, hy0);
    MARS_LIQ_HEIGHT(Sy1, hy1);
    surfN = normalize(N - ((hx1 - hx0) * T1 + (hy1 - hy0) * T2) / (2.0 * e));
    MARS_LIQ_HEIGHT(Ssurf, surfH);
}

float foamWidth = FoamWidth;
// how far the rim bands swell here (0: even); only the boil sets it
float rimFroth = 0.0;
#if MARS_LIQ_BUBBLING
foamWidth *= 1.0 + 1.5 * Boil;
// the rim froth: round the vessel's axis the band breaks into beads of froth, each swelling and popping on its own clock
// as the bubbles reach the edge, over a wobble travelling round the rim. The beads' count round the rim (the band's
// frequency) rises with the boil and the bubbles' density; both rim bands (the line on the glass, the meniscus on the
// top) swell by it, the top's capped so the froth never floods the surface. Measured at this pixel on the glass, at the
// surface crossing on the top.
{
    float3 Xr = Sign > 0.0 ? D : Ssurf;
    float theta = atan2(dot(Xr, T2), dot(Xr, T1)) * (0.5 / 3.14159265) + 0.5;
    float beads = max(3.0, round(RimFrothFrequency * (0.5 + 0.5 * Boil) * (0.5 + BubbleDensity)));
    float u = theta * beads;
    float3 rh = MARS_LIQ_HASH3(float3(fmod(floor(u), beads), 5.3, Phase * 11.0));
    float rf = frac(u) - 0.5 - (rh.z - 0.5) * 0.3;
    float rlife = frac(Time * BubbleSpeed * 0.7 + rh.x);
    float rsize = lerp(0.18, 0.45, rh.y) * smoothstep(0.0, 0.7, rlife) * (1.0 - step(0.9, rlife));
    float bead = sqrt(saturate(1.0 - (rf * rf) / max(rsize * rsize, 1e-4)));
    float wobble = 0.5 + 0.5 * sin(theta * 6.2831853 * beads * 0.5 + Time * rippleSpeed);
    rimFroth = saturate(RimFroth * Boil * (bead + 0.25 * wobble));
}
#endif

float3 Vn = normalize(V);
bool front = Sign > 0.0;

// a front face: the liquid between here and where the ray leaves it (the far wall, or the surface if the ray rises through
// it first), cm
float frontRun = 0.0;
if (front)
{
    float b = dot(D, Vn);
    float tS = -b + sqrt(max(b * b - (dot(D, D) - R * R), 0.0));
    if (jar)
    {
        float tIn;
        MARS_LIQ_CYL(D, Vn, tIn, tS);
    }
    float vnN = dot(Vn, N);
    float tP = vnN > 1e-4 ? (h - dot(D, N)) / vnN : 1e9;
    frontRun = max(min(tS, tP), 0.0);
}

// the pickles (Pickle Jar): the first one the ray meets in the liquid, from where it enters (this front face, or the
// surface over a back face) to where it leaves. Over the surface (a pixel the clip drops) the trace runs through the jar's
// air instead, and a tip it meets there keeps the pixel, dry. Each pickle stands on the floor round the axis (a ring and
// one in the middle), leans a little in, and is a convex solid of planes in its own frame: a lower and an upper band of
// seven facets (twisted half a facet, each bulging to the middle), a bevel at each end, and the end caps.
bool pkHit = false;
float pkT = 0.0;
float3 pkN = -Vn;
float3 pkCol = PickleColor;
float3 pkX = D;
if (jar && PickleCount >= 1.0)
{
    float3 O = front ? D : Ssurf;
    float tMax = front ? frontRun : length(D - Ssurf);
    if (s > 0.0)
    {
        float tA, tB;
        MARS_LIQ_CYL(CamRel, Vn, tA, tB);
        O = front ? D : CamRel + Vn * max(tA, 0.0);
        tMax = max(tB - dot(O - CamRel, Vn), 0.0);
    }
    #define MARS_LIQ_PLANE(NP, DP, ID) \
    { \
        float3 _n = NP; \
        float _dn = dot(v, _n); \
        float _t = ((DP) - dot(o, _n)) / (_dn < 0.0 ? min(_dn, -1e-6) : max(_dn, 1e-6)); \
        if (_dn < 0.0) \
        { \
            if (_t > tE) { tE = _t; nE = _n; fE = ID; } \
        } \
        else \
        { tX = min(tX, _t); } \
    }
    int count = (int)min(PickleCount, 12.0);
    int ring = count >= 4 ? count - 1 : count;
    float seed = floor(Phase * 97.0);
    float pr = PickleRadius * R;
    float ringR = max(R - pr * 1.15 - 0.03 * R, 0.0);
    float bestT = tMax;
    float3 bestL = 0.0;
    float bestFace = 0.0;
    float bestI = 0.0;
    float bestRad = 1.0;
    // the slosh carries them: a top leans back against the surface's tilt from level (the script's slosh spring, which tips
    // the surface toward the acceleration, so the pickles lag behind it and swing and settle with it), each pickle its own
    // share (Pickle Sway, lean per unit of tilt); and while the liquid churns (Agitation) each lifts off the floor and rocks
    // at its own rate (Pickle Bob: 1 lifts up to a tenth of the radius and rocks about 0.08 rad)
    float3 lag = float3(0.0, 0.0, 1.0) - N;
    lag -= Az * dot(lag, Az);
    lag *= min(1.0, 0.5 / max(length(lag), 1e-4));
    float bobW = PickleBob * agit;
    [loop] for (int i = 0; i < count; ++i)
    {
        float3 ph = MARS_LIQ_HASH3(float3(i, seed, 2.9));
        bool centre = i >= ring;
        float ang = (i + (ph.x - 0.5) * 0.3) / ring * 6.2831853 + Phase * 6.2831853;
        float3 out2 = Ax * cos(ang) + Ay * sin(ang);
        float rad = pr * (centre ? 1.15 : 0.9 + 0.2 * ph.z);
        float len = PickleLength * 2.0 * HH * (0.84 + 0.16 * ph.y);
        float wob = Time * (4.0 + 3.0 * ph.z) + ph.x * 6.2831853;
        float3 base = out2 * (centre ? 0.0 : ringR * (0.96 + 0.04 * ph.y)) - Az * (HH - 0.02 * R)
            + Az * (bobW * 0.1 * R * (0.5 + 0.5 * sin(wob)));
        float3 pz = normalize(Az - out2 * (centre ? 0.0 : 0.02 + 0.05 * ph.z) + Ay * ((ph.x - 0.5) * 0.04)
            + lag * (PickleSway * (0.6 + 0.8 * ph.y))
            + (Ax * sin(wob * 0.7 + 1.3) + Ay * cos(wob * 0.9)) * (bobW * 0.08));
        float3 px0 = normalize(Ax - pz * dot(Ax, pz));
        float3 py0 = cross(pz, px0);
        float tw = ph.x * 6.2831853;
        float3 px = px0 * cos(tw) + py0 * sin(tw);
        float3 py = cross(pz, px);
        float3 rel = O - base;
        float3 o = float3(dot(rel, px), dot(rel, py), dot(rel, pz));
        float3 v = float3(dot(Vn, px), dot(Vn, py), dot(Vn, pz));
        // skip a pickle whose bounding sphere the ray misses, or meets only past the best so far
        float3 bc = o - float3(0.0, 0.0, 0.5 * len);
        float bb = dot(bc, v);
        float bd = bb * bb - (dot(bc, bc) - (0.25 * len * len + 1.2 * rad * rad));
        if (bd < 0.0 || -bb - sqrt(bd) > bestT || -bb + sqrt(bd) < 0.0)
        { continue; }

        float tE = -1e9;
        float tX = 1e9;
        float3 nE = float3(0.0, 0.0, -1.0);
        float fE = 0.0;
        float eps = 0.16 * rad / (0.5 * len);   // the bands' bulge: radius lost from the middle to an end, per height
        float kb = 0.7;                         // the bevels' slope
        float ib = rsqrt(1.0 + eps * eps);
        float ik = rsqrt(1.0 + kb * kb);
        [unroll] for (int k = 0; k < 7; ++k)
        {
            float3 kh = MARS_LIQ_HASH3(float3(i, k, seed + 4.1));
            float a0 = (k + 0.15 * (kh.x - 0.5)) * 0.8975979;
            float a1 = a0 + 0.4487990;
            float2 c0 = float2(cos(a0), sin(a0));
            float2 c1 = float2(cos(a1), sin(a1));
            MARS_LIQ_PLANE(float3(c0, -eps) * ib, (rad * (0.95 + 0.1 * kh.y) - eps * 0.5 * len) * ib, k)
            MARS_LIQ_PLANE(float3(c1, eps) * ib, (rad * (0.95 + 0.1 * kh.z) + eps * 0.5 * len) * ib, 7 + k)
            MARS_LIQ_PLANE(float3(c0, kb) * ik, (0.6 * rad + kb * len) * ik, 14 + k)
            MARS_LIQ_PLANE(float3(c1, -kb) * ik, 0.6 * rad * ik, 21 + k)
        }
        MARS_LIQ_PLANE(float3(0.0, 0.0, 1.0), len, 28)
        MARS_LIQ_PLANE(float3(0.0, 0.0, -1.0), 0.0, 29)
        if (tE <= tX && tX > 0.0 && tE < bestT)
        {
            bestT = max(tE, 0.0);
            pkHit = true;
            pkN = px * nE.x + py * nE.y + pz * nE.z;
            bestL = o + v * bestT;
            bestFace = fE;
            bestI = i;
            bestRad = rad;
        }
    }
    pkT = bestT;
    pkX = O + Vn * bestT;
    if (pkHit)
    {
        // flat-shaded facets, each its own shade between Pickle Color and Pickle Light, the ends lighter; pale warts on
        // the bands
        float3 fh = MARS_LIQ_HASH3(float3(bestI, bestFace, seed + 8.3));
        pkCol = lerp(PickleColor, PickleLight, 0.1 + 0.6 * fh.x + (bestFace >= 14.0 ? 0.3 : 0.0));
        float th = atan2(bestL.y, bestL.x) * (0.5 / 3.14159265) + 0.5;
        float2 wq = float2(th * 14.0, bestL.z / max(bestRad * 0.8, 1e-3)) + bestI * 3.7;
        float3 wh = MARS_LIQ_HASH3(float3(floor(wq), bestI + 1.3));
        float wr = length(frac(wq) - 0.5 - (wh.xy - 0.5) * 0.5);
        float wart = (bestFace < 14.0 ? 1.0 : 0.0) * step(1.0 - WartAmount, wh.z) * (1.0 - smoothstep(0.1, 0.15, wr));
        pkCol = lerp(pkCol, WartColor, wart);
    }
}
if (jar && s > 0.0)
{
    // over the surface: only a dry tip keeps the pixel
    bool dry = false;
    if (pkHit)
    {
        float hx;
        MARS_LIQ_HEIGHT(pkX, hx);
        dry = dot(pkX, N) - h - hx > 0.0;
    }
    OutMask = dry ? 1.0 : 0.0;
    OutNormal = pkN;
    OutEmissive = pkCol * PickleGlow;
    OutRough = PickleRoughness;
    return pkCol;
}
// how fast the liquid veils a pickle behind it (per radius; the brine adds its haze)
float pkFog = PickleVeil;
float rough = Roughness;
// a pickle's own light (Pickle Glow), so it reads in a backlit jar
float3 pkGlow = 0.0;

float path;
float3 n;
float3 col;
float3 glow;
if (front)
{
    path = (pkHit ? pkT : frontRun) / R;
    float depth = 1.0 - exp(-path * Density);
    n = normalize(Nw);
    col = lerp(LiquidColor, DeepColor, depth);
#if MARS_LIQ_BRINE
    // cloudy: the haze thickens with the depth looked through, and thicker still low down where the sediment hangs
    float3 mid = D + Vn * (path * R * 0.5);
    float low = 1.0 - smoothstep(-0.9, 0.1, dot(mid, N) / (jar ? HH : R));
    float haze = 1.0 - exp(-path * (Turbidity + Sediment * low * 3.0));
    col = lerp(col, HazeColor, haze);
    pkFog += Turbidity + Sediment * low * 3.0;
#endif
    if (pkHit)
    {
        // the pickle through the liquid in front of it: tinted by it, veiled by it, lit with its own facets while it shows
        float veil = 1.0 - exp(-path * pkFog);
        float3 seen = pkCol * lerp(1.0, min(LiquidColor * 1.6, 1.0), saturate(path * 2.0));
        col = lerp(seen, col, veil);
        n = normalize(lerp(pkN, n, veil));
        rough = lerp(PickleRoughness, Roughness, veil);
        pkGlow = seen * (PickleGlow * (1.0 - veil));
    }

    // a bright line where the liquid meets the glass, under the surface
    float foam = 1.0 - smoothstep(0.0, foamWidth * (1.0 + 1.5 * rimFroth) * R, -s);
    // light through the thin edge of the volume
    float rim = pow(1.0 - saturate(dot(n, -Vn)), 3.0) * RimLight;
    // motes: two layers of rising sparks inside the volume, along the ray (parallax: they sit in the liquid, not on the
    // glass)
    float motes = 0.0;
    [unroll] for (int m = 0; m < 2; ++m)
    {
        float3 Q = (D + Vn * (path * R * (m == 0 ? 0.3 : 0.7))) / R * MoteScale - N * (Time * MoteSpeed) + Phase * 31.0 + m * 7.31;
        float3 cell = floor(Q);
        float3 f = frac(Q) - 0.5;
        float3 hsh = MARS_LIQ_HASH3(cell);
        float3 off = (hsh - 0.5) * 0.6;
        float on = step(0.55, hsh.x);
        float r = length(f - off);
        motes += on * (1.0 - smoothstep(0.02, 0.09, r));
    }
#if MARS_LIQ_BUBBLING
    // bubbles: three layers along the ray, each bubble a bright rim round a lighter core, rising and weaving
    float bubbles = 0.0;
    [unroll] for (int q = 0; q < 3; ++q)
    {
        float along = 0.15 + 0.35 * q;
        float3 Q = (D + Vn * (path * R * along)) / R * BubbleScale - N * (Time * BubbleSpeed * (1.0 + 0.3 * q)) + Phase * 13.0 + q * 5.17;
        float3 cell = floor(Q);
        float3 f = frac(Q) - 0.5;
        float3 hsh = MARS_LIQ_HASH3(cell);
        float on = step(1.0 - BubbleDensity, hsh.x);
        float rad = lerp(0.1, 0.24, hsh.z);
        float3 off = (hsh - 0.5) * (0.9 - 2.0 * rad) + (T1 * sin(Time * 5.0 + hsh.y * 6.28) + T2 * cos(Time * 4.1 + hsh.z * 6.28)) * 0.05;
        float r = length(f - off);
        float rimB = smoothstep(rad - 0.06, rad - 0.01, r) * (1.0 - smoothstep(rad - 0.01, rad + 0.015, r));
        float core = 1.0 - smoothstep(rad - 0.08, rad - 0.02, r);
        bubbles += on * (rimB + 0.2 * core) * (1.0 - 0.25 * q);
    }
    col = lerp(col, FoamColor, saturate(bubbles) * 0.6);
    motes += bubbles * Boil;
#endif
#if MARS_LIQ_BRINE
    // the pickling spices: peppercorns (dark, round), mustard seeds (yellow, round) and dill (green, long flecks),
    // five layers along the ray; they sink slowly, sway, and swirl round the surface's normal when it sloshes
    float specks = 0.0;
    float3 speckCol = 0.0;
    float swirl = Slosh * 2.0 + 0.15;
    [unroll] for (int p = 0; p < 5; ++p)
    {
        float along = 0.1 + 0.2 * p;
        float3 X = (D + Vn * (path * R * along)) / R;
        float a = swirl * sin(Time * 0.6 + p * 2.1);
        float2 xy = float2(dot(X, T1), dot(X, T2));
        xy = float2(xy.x * cos(a) - xy.y * sin(a), xy.x * sin(a) + xy.y * cos(a));
        float3 Q = (T1 * xy.x + T2 * xy.y + N * dot(X, N)) * SpeckScale + N * (Time * 0.04) + Phase * 23.0 + p * 3.71;
        float3 cell = floor(Q);
        float3 f = frac(Q) - 0.5;
        float3 hsh = MARS_LIQ_HASH3(cell);
        float on = step(1.0 - SpeckAmount, hsh.x);
        float3 off = (hsh - 0.5) * 0.5;
        float3 e = f - off;
        float3 tint;
        float r;
        if (hsh.y < 0.4)
        {   // peppercorn
            r = length(e) / 0.12;
            tint = float3(0.06, 0.045, 0.03);
        }
        else if (hsh.y < 0.75)
        {   // mustard seed
            r = length(e) / 0.09;
            tint = float3(0.75, 0.55, 0.15);
        }
        else
        {   // dill: a thin fleck along a random direction
            float3 dir = normalize(hsh * 2.0 - 1.0 + 1e-3);
            float t = dot(e, dir);
            r = max(length(e - dir * t) / 0.035, abs(t) / 0.3);
            tint = float3(0.18, 0.32, 0.08);
        }
        float hit = on * (1.0 - smoothstep(0.7, 1.0, r)) * (1.0 - 0.12 * p);
        speckCol = lerp(speckCol, tint, hit * (1.0 - specks));
        specks = saturate(specks + hit);
    }
    col = lerp(col, speckCol, specks);
#endif
    // the aeration: while it churns, the water under the surface turns white and fills with small bubbles (three layers
    // along the ray), in a band deeper the harder it was jolted
    if (agit > 0.01)
    {
        float bandDepth = Aeration * agit * R + 1e-3;
        float aer = 0.4 * (1.0 - smoothstep(0.0, bandDepth, -s));
        [unroll] for (int w = 0; w < 3; ++w)
        {
            float3 X = D + Vn * (path * R * (0.08 + 0.3 * w));
            float hh;
            MARS_LIQ_HEIGHT(X, hh);
            float band = 1.0 - smoothstep(0.0, bandDepth, h + hh - dot(X, N));
            float3 Q = X / R * 9.0 - N * (Time * 2.0) + Phase * 3.1 + w * 1.7;
            float3 hsh = MARS_LIQ_HASH3(floor(Q));
            float rad = lerp(0.12, 0.3, hsh.z);
            float r = length(frac(Q) - 0.5 - (hsh - 0.5) * (0.9 - 2.0 * rad));
            float ring = smoothstep(rad - 0.08, rad - 0.01, r) * (1.0 - smoothstep(rad - 0.01, rad + 0.02, r));
            float core = 1.0 - smoothstep(rad - 0.1, rad, r);
            aer += band * step(0.35, hsh.x) * (ring + 0.35 * core);
        }
        col = lerp(col, FoamColor, saturate(aer) * 0.75);
    }
    col = lerp(col, FoamColor, foam * 0.6);
    glow = col * Glow * (1.0 - 0.5 * depth) + LiquidColor * (rim * Glow) + FoamColor * (motes * MoteAmount * Glow);
}
else
{
    // the surface, seen at the point the ray crosses it: lit with the rippled normal, coloured by the depth of liquid
    // under it along the ray (the crossing to this back face)
    float3 Sp = Ssurf;
    path = (pkHit ? pkT : length(D - Sp)) / R;
    float depth = 1.0 - exp(-path * Density);
    n = surfN;
    // the meniscus: a pale ring where the surface meets the glass (the sphere's cut circle has radius sqrt(R^2 - h^2); a
    // jar's wall is R from its axis)
    float3 toS = Sp - N * h;
    float radial = jar ? length(Sp - Az * dot(Sp, Az)) / R : length(toS - N * dot(toS, N)) / sqrt(max(R * R - h * h, 1e-4));
    float meniscus = smoothstep(1.0 - min(foamWidth * 2.5 * (1.0 + rimFroth), 0.3), 1.0, radial);
    col = lerp(lerp(LiquidColor, DeepColor, depth), SurfaceColor, SurfaceMix);
#if MARS_LIQ_BRINE
    col = lerp(col, HazeColor, 1.0 - exp(-path * Turbidity));
    pkFog += Turbidity;
#endif
    if (pkHit)
    {
        // a pickle under the top, veiled by the liquid over it, the top's own colour and gloss over both
        float veil = 1.0 - exp(-path * pkFog);
        float3 seen = pkCol * lerp(1.0, min(LiquidColor * 1.6, 1.0), saturate(path * 2.0));
        col = lerp(lerp(seen, col, veil), SurfaceColor, SurfaceMix * 0.5 * (1.0 - veil));
        pkGlow = seen * (PickleGlow * (1.0 - veil));
    }
#if MARS_LIQ_BUBBLING
    // domes: each cell of the surface grows a bubble that swells, then pops into an expanding ring
    float2 suv = float2(dot(Sp, T1), dot(Sp, T2)) / R * BubbleScale * 1.4 + Phase * 7.0;
    float3 sh = MARS_LIQ_HASH3(float3(floor(suv), 3.7));
    float2 sf = frac(suv) - 0.5;
    float life = frac(Time * BubbleSpeed * 0.9 + sh.x);
    float on = step(1.0 - BubbleDensity, sh.y);
    float rad = lerp(0.12, 0.32, sh.z) * smoothstep(0.0, 0.8, life);
    float2 e = sf - (sh.xy - 0.5) * 0.3;
    float d = length(e) / max(rad, 1e-3);
    float dome = on * step(life, 0.85) * (1.0 - step(1.0, d));
    // the dome's slope bends the normal; its rim catches light
    float slope = d / sqrt(max(1.0 - d * d, 0.02));
    float2 dirE = e / max(length(e), 1e-3);
    n = normalize(n - dome * slope * 0.6 * (T1 * dirE.x + T2 * dirE.y));
    float domeRim = dome * smoothstep(0.7, 1.0, d);
    // the pop: a thin ring racing out after the bubble bursts
    float pop = on * step(0.85, life) * (1.0 - smoothstep(0.0, 0.05, abs(length(e) - (life - 0.85) * 3.0))) * (1.0 - life) * 6.0;
    col = lerp(col, FoamColor, saturate((domeRim * 0.8 + pop + dome * 0.15) * Boil));
#endif
#if MARS_LIQ_BRINE
    // a few seeds float on the top
    float2 fuv = float2(dot(Sp, T1), dot(Sp, T2)) / R * SpeckScale * 0.8 + Phase * 5.0;
    float3 fh = MARS_LIQ_HASH3(float3(floor(fuv), 9.1));
    float fr = length(frac(fuv) - 0.5 - (fh.xy - 0.5) * 0.5);
    float floater = step(1.0 - SpeckAmount * 0.5, fh.x) * (1.0 - smoothstep(0.04, 0.07, fr));
    col = lerp(col, fh.z < 0.5 ? float3(0.75, 0.55, 0.15) : float3(0.18, 0.32, 0.08), floater);
#endif
    // whitecaps on the churned crests, and a sizzle of foam cells over the cap while it settles
    if (agit > 0.01)
    {
        float crest = smoothstep(0.3, 1.0, surfH / max(chopAmp + abs(swellAmp), 1e-3)) * FoamCap * agit;
        float2 fz = float2(dot(Sp, T1), dot(Sp, T2)) / R * 8.0 + Phase * 3.0 + float2(Time * 0.3, -Time * 0.2);
        float3 zh = MARS_LIQ_HASH3(float3(floor(fz), 7.7));
        float zr = length(frac(fz) - 0.5 - (zh.xy - 0.5) * 0.4);
        float zrad = lerp(0.08, 0.22, zh.z);
        float zring = smoothstep(zrad - 0.06, zrad, zr) * (1.0 - smoothstep(zrad, zrad + 0.03, zr));
        float sizzle = step(1.0 - agit * 0.8, zh.x) * (zring + 0.4 * (1.0 - smoothstep(zrad - 0.06, zrad, zr)));
        col = lerp(col, FoamColor, saturate(crest + sizzle * 0.8 * FoamCap));
    }
    col = lerp(col, FoamColor, meniscus * 0.85);
    glow = col * (Glow * 0.6);
}

OutNormal = n;
OutEmissive = glow + pkGlow;
OutRough = rough;
return col;
"""

# ====================================================================================== cork
# Inputs: P (local position, cm), Scale (cells per cm), Dark, Light. Return: base colour: a speckled cork.
CORK_PS = r"""
float3 q = P * Scale;
float3 i = floor(q);
float3 f = frac(q);
f = f * f * (3.0 - 2.0 * f);
float n000 = frac(sin(dot(i + float3(0,0,0), float3(127.1, 311.7, 74.7))) * 43758.5453);
float n100 = frac(sin(dot(i + float3(1,0,0), float3(127.1, 311.7, 74.7))) * 43758.5453);
float n010 = frac(sin(dot(i + float3(0,1,0), float3(127.1, 311.7, 74.7))) * 43758.5453);
float n110 = frac(sin(dot(i + float3(1,1,0), float3(127.1, 311.7, 74.7))) * 43758.5453);
float n001 = frac(sin(dot(i + float3(0,0,1), float3(127.1, 311.7, 74.7))) * 43758.5453);
float n101 = frac(sin(dot(i + float3(1,0,1), float3(127.1, 311.7, 74.7))) * 43758.5453);
float n011 = frac(sin(dot(i + float3(0,1,1), float3(127.1, 311.7, 74.7))) * 43758.5453);
float n111 = frac(sin(dot(i + float3(1,1,1), float3(127.1, 311.7, 74.7))) * 43758.5453);
float n = lerp(lerp(lerp(n000, n100, f.x), lerp(n010, n110, f.x), f.y), lerp(lerp(n001, n101, f.x), lerp(n011, n111, f.x), f.y), f.z);
float speck = step(0.78, frac(sin(dot(floor(P * Scale * 3.1), float3(12.9898, 78.233, 37.719))) * 43758.5453));
return lerp(Dark, Light, n) * (1.0 - 0.35 * speck);
"""
