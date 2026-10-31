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
# component's scale), Radius (the sphere's local radius, cm), Surface (xyz the surface normal, w the level in radii), Slosh
# (0..1 ripple energy), Phase (0..1 per potion), Time, Sign (TwoSidedSign), Nw (vertex normal, world), the look.
# Return: base colour. Extra outputs: OutNormal (world), OutEmissive, OutMask (1 keep, 0 clip), OutRough.
LIQUID_PS = r"""
float S = max(length(Unit), 1e-4);
float R = max(Radius * S, 1e-3);
float3 N = normalize(Surface.xyz + float3(0.0, 0.0, 1e-4));
float h = Surface.w * R;

// the surface's own frame, for the ripples
float3 T1 = normalize(cross(abs(N.x) < 0.9 ? float3(1.0, 0.0, 0.0) : float3(0.0, 1.0, 0.0), N));
float3 T2 = cross(N, T1);

// the camera ray through this pixel and where it crosses the flat surface (0 at the camera, 1 at this pixel)
float3 V = D - CamRel;
float vN = dot(V, N);
float tPlane = (h - dot(CamRel, N)) / (abs(vN) > 1e-5 ? vN : 1e-5);
float3 Sflat = CamRel + V * saturate(tPlane);

// ripples: three travelling waves on the surface's frame, at rest a faint shimmer, louder while it sloshes.
// [0] at this pixel (the clip), [1] at the surface crossing (the surface's normal)
float amp = RippleAmount * R * (0.04 + Slosh);
float ripH[2];
float3 ripG[2];
[unroll] for (int k = 0; k < 2; ++k)
{
    float3 X = k == 0 ? D : Sflat;
    float2 uv = float2(dot(X, T1), dot(X, T2)) / R * RippleScale;
    float tt = Time * RippleSpeed + Phase * 17.0;
    float2 d0 = float2(0.96, 0.28);
    float2 d1 = float2(-0.53, 0.85);
    float2 d2 = float2(-0.39, -0.92);
    float a0 = dot(uv, d0) + tt;
    float a1 = dot(uv, d1) * 1.7 + tt * 1.31;
    float a2 = dot(uv, d2) * 2.9 + tt * 1.87;
    ripH[k] = amp * (sin(a0) + 0.6 * sin(a1) + 0.35 * sin(a2)) / 1.95;
    float2 g = d0 * cos(a0) + (0.6 * 1.7) * d1 * cos(a1) + (0.35 * 2.9) * d2 * cos(a2);
    ripG[k] = (amp * RippleScale / (1.95 * R)) * (g.x * T1 + g.y * T2);
}

// signed height of this pixel over the rippled surface: above it is air
float s = dot(D, N) - h - ripH[0];
OutMask = s <= 0.0 ? 1.0 : 0.0;

float3 Vn = normalize(V);
bool front = Sign > 0.0;
float path;
float3 n;
float3 col;
float3 glow;
if (front)
{
    // the wall: the liquid between here and where the ray leaves it (the far side of the sphere, or the surface if the
    // ray rises through it first), in radii
    float b = dot(D, Vn);
    float c = dot(D, D) - R * R;
    float tS = -b + sqrt(max(b * b - c, 0.0));
    float vnN = dot(Vn, N);
    float tP = vnN > 1e-4 ? (h - dot(D, N)) / vnN : 1e9;
    path = max(min(tS, tP), 0.0) / R;
    float depth = 1.0 - exp(-path * Density);
    n = normalize(Nw);
    col = lerp(LiquidColor, DeepColor, depth);

    // a bright line where the liquid meets the glass, under the surface
    float foam = 1.0 - smoothstep(0.0, FoamWidth * R, -s);
    // light through the thin edge of the volume
    float rim = pow(1.0 - saturate(dot(n, -Vn)), 3.0) * RimLight;
    // motes: two layers of rising sparks inside the volume, along the ray (parallax: they sit in the liquid, not on the
    // glass)
    float motes = 0.0;
    [unroll] for (int m = 0; m < 2; ++m)
    {
        float3 Q = (D + Vn * (path * R * (m == 0 ? 0.3 : 0.7))) / R * MoteScale + N * (Time * MoteSpeed) + Phase * 31.0 + m * 7.31;
        float3 cell = floor(Q);
        float3 f = frac(Q) - 0.5;
        float3 hsh = frac(sin(float3(dot(cell, float3(127.1, 311.7, 74.7)), dot(cell, float3(269.5, 183.3, 246.1)),
                                     dot(cell, float3(113.5, 271.9, 124.6)))) * 43758.5453);
        float3 off = (hsh - 0.5) * 0.6;
        float on = step(0.55, hsh.x);
        float r = length(f - off);
        motes += on * (1.0 - smoothstep(0.02, 0.09, r));
    }
    col = lerp(col, FoamColor, foam * 0.6);
    glow = col * Glow * (1.0 - 0.5 * depth) + LiquidColor * (rim * Glow) + FoamColor * (motes * MoteAmount * Glow);
}
else
{
    // the surface, seen at the point the ray crosses it: lit with the rippled normal, coloured by the depth of liquid
    // under it along the ray (the crossing to this back face)
    float3 Sp = Sflat;
    path = length(D - Sp) / R;
    float depth = 1.0 - exp(-path * Density);
    n = normalize(N - ripG[1]);
    // the meniscus: a pale ring where the surface meets the glass (the cut circle's radius is sqrt(R^2 - h^2))
    float3 toS = Sp - N * h;
    float radial = length(toS - N * dot(toS, N)) / sqrt(max(R * R - h * h, 1e-4));
    float meniscus = smoothstep(1.0 - FoamWidth * 2.5, 1.0, radial);
    col = lerp(lerp(LiquidColor, DeepColor, depth), SurfaceColor, SurfaceMix);
    col = lerp(col, FoamColor, meniscus * 0.85);
    glow = col * (Glow * 0.6);
}

OutNormal = n;
OutEmissive = glow;
OutRough = Roughness;
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
