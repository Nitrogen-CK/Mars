"""Mars environment dressing kit, family "clutter" (ENV_KIT.md): sacks, banners, torch sconce, lanterns, brazier and the
candle-ledge drips from the six crypt concept frames (2026-10-19). Headless Blender 5.2, rebuilt from fixed seeds.

  Sack_A_Mars_SM            upright tied grain sack (~62 cm): SDF cloth meshed by surface nets, its body cut into ~40
                            flat chiselled facets (VSA regions pulled planar; bigger on the belly, smaller at the neck
                            and base), a flat spread bottom (~38 x 36 cm footprint), creases down from the gathered neck,
                            the flare flopped ~25 degrees, rope tie + tails, two faded red stripes   EnvCanvas  floor, cluster
  Sack_B_Mars_SM            slumped sack: broad flat base, the top sagging toward the neck side, a pleated neck cone
                            rising out of the shoulder into the tie (no scoop), three diagonal sag creases over the top
  Sack_C_Mars_SM            a sack lying on its side, the tied neck toward the room (Unreal +Y), concept 4
  SackPile_A_Mars_SM        four sacks pressed into one heap (hard union k 0.4: separate sacks with dark creases)
                                                                                    EnvCanvas            floor, cluster
  Banner_A_Mars_SM          concept 4: red 1.2 x 3.0 m, iron rod with gilt finials on two wall brackets, a sleeve, broad
                            folds on 10 cm x 20 cm cloth cells (no decimation noise), zigzag hem, ONE gold flame emblem
                            + gold top / side / hem borders as decal faces 3 mm proud      EnvCloth/Gold/Iron  wall, prop
  Banner_B_Mars_SM          narrow (0.7 x 3.3 m) and torn: four 15-19 cm strips hanging 22-52 cm below straight tear
                            slits, each ending in a diagonal cut with 2-3 ragged points, shallow pleats (<= 3.5 cm), no twist
  TorchSconce_A_Mars_SM     iron wall plate, twisted arm, collar + basket, wooden torch, pitch-rag head with four ragged
                            rag tails, ONE soft 6-sided teardrop flame (9.5 cm wide at 33 %, bent 13 degrees, 36 tris) with
                            two 5 cm side tongues fused into its root (candle_gen Flame contract)
                                                                      EnvIron/Wood/Canvas/Flame  sconce, prop
  WallLantern_A_Mars_SM     wall plate, twisted arm (45 cm reach) with a J hook, a scroll brace resting on the plate, a
                            24 x 24 cm cage lantern (36 cm body, 2.5 cm posts) hung by its ring, a 10 cm candle and a
                            small rounded glow core                             EnvIron/GlowWarm/Wax  sconce, prop
  SpiritLantern_Post_Mars_SM  concept 2: octagonal flared foot, turned shaft with collars, hexagonal gothic cage, a
                            blue teardrop flame resting in an iron dish, spired roof, ~1 m   EnvIron/GlowSpirit  floor, prop
  Brazier_A_Mars_SM         hammered iron bowl on three ~4 cm legs ending in 1.5-turn scrolls on foot pads, a 3 cm
                            stretcher ring, riveted band, 22 chunky coals heaped into a dome over the rim, four soft fire
                            tongues sharing one root mass (tallest ~30 cm over the rim)  EnvIron/GlowWarm/Flame  floor, prop
  CandleLedge_A_Mars_SM     concept 1: six hand-cut prism candles (7/8 sides, dished tops, drip ribbons) along ~48 cm
                            of ledge, staggered in depth; a surface-nets spill (~650 tris) makes the pools, the rolled lip
                            over the edge and the fat drips down the face       EnvWax/Iron(wick)/Flame    ledge, cluster
  CandleLedge_B_Mars_SM     concept 6: a fat candle, a stub and a thin one, a heavy pour over the edge
  CandleLedge_C_Mars_SM     concept 1's long run: seven candles along ~60 cm
  Barrel_A_Mars_SM          concepts 2/4: coopered barrel 82 cm, 14 uneven staves (chipped tops, lifted feet), 4 tilted
                            conical hoops, planked head                         EnvWood/Iron         floor, prop
  Crate_A_Mars_SM           concepts 2/4: battened crate 62 x 58 x 56 cm, uneven boards, chipped battens, a shoved lid
                            board, diagonal braces, nails
  Crate_B_Mars_SM           a smaller OPEN crate (46 x 40 x 38 cm) with a dark hold, for gallery stacks
  Railing_A_Mars_SM         concept 2: 16 cm post with a saddle block, 12 x 10 chamfered top rail laid on the posts and an
                            8 x 8 mid rail, both sagging; chains every 200 cm along +X (pivot: the post's centre)
  RailingPost_A_Mars_SM     the end post that closes a railing run
  (Barrel / Crate / Railing / Sack_C / CandleLedge_C are not in ENV_KIT yet: see the report.)

Mesh contract (env_spec): <Name>_Mars_SM, flat shaded, "Col" painted per facet (linear RGB, cavity in A), UV0 "UVMap".
Flames follow candle_gen's Flame contract: slot EnvFlame, Col white, UV1 "CandleData" u = flame id (constant per tongue,
distinct per tongue), v (as Unreal reads it, stored 1 - v) = height along the flame 0 base .. 1 tip; every other face of
a flame mesh carries u = the nearest flame's id and v = 0, except candle wax, which carries candle_gen's glow. Round 2:
the flames are env_clutter_parts.tongue (candle_gen's faceted teardrop with 3 rings instead of 4, a bent spine and a
curled tip); the ledge candles are hand-cut prisms, and only the spill uses candle_gen's surface nets + decimator.
Banners carry UV1 "EnvData" (u = piece id, v = flex 0 at the rod .. 1 at the hem) for a sway material. No UCX anywhere:
ENV_KIT asks for none in this family (the importer then gives these meshes no simple collision).

Pivots: floor props XY centre of the footprint, z = 0 on the floor. Sconces (torch, wall lantern): the wall mount point at
the origin, back plate on y = 0, protruding toward Blender -y (Unreal +Y). Banners: x / z = the rod axis (the hang point),
y = 0 the wall plane behind the brackets (the rod axis sits 6 cm off the wall). Candle ledges: the ledge edge at y = 0,
z = 0; the ledge top is z = 0 at y > 0, its face is y = 0 at z < 0.

Run (always absolute paths):
  "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" -b --factory-startup --python
      D:\\Repo\\Mars\\Tools\\Blender\\mars_environment\\build_env_clutter.py -- [--export] [--sheets] [--save] [--only <names>]
Prints ENV_CLUTTER_OK when every check passed (ENV_CLUTTER_FAIL + the reasons otherwise).
"""
import json
import math
import os
import sys
import time

import bmesh
import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import env_clutter_parts as ep   # noqa: E402
from env_clutter_parts import (X, Y, Z, TAU, Parts, _n, lerp, smoothstep, rot_z, rot_matrix, axis_frame,  # noqa: E402
                               place_on_axis, bezier, bar, twisted_normals, hoop, lathe, lathe_on_axis, lathe_closed,
                               lump, rivet, chamfer_box, extrude_outline, flame, tongue, iron_col)

ec, fc, sc, spec, cg = ep.ec, ep.fc, ep.sc, ep.spec, ep.cg
FAMILY = "clutter"
CANDLE_UV = ep.CANDLE_UV
DATA_UV = spec.DATA_UV


def P(name):
    return ec.palette(name)


# ================================================================ rules
FLOOR = lambda pv: pv[:, 2].min() < 0.05                                    # noqa: E731
WALL = lambda pv: pv[:, 1].max() > -0.05                                    # noqa: E731


def LEDGE(pv):
    top = (np.abs(pv[:, 2]) < 0.05) & (pv[:, 1] > -0.05)
    face = (np.abs(pv[:, 1]) < 0.05) & (pv[:, 2] < 0.05)
    return bool(np.any(top | face))


RULES = {
    "Sack_A": dict(cat="cluster", slots=("EnvCanvas",), pivot="floor", uv1=None, sockets=(), anchor=FLOOR),
    "Sack_B": dict(cat="cluster", slots=("EnvCanvas",), pivot="floor", uv1=None, sockets=(), anchor=FLOOR),
    "SackPile_A": dict(cat="cluster", slots=("EnvCanvas",), pivot="floor", uv1=None, sockets=(), anchor=FLOOR),
    "Sack_C": dict(cat="cluster", slots=("EnvCanvas",), pivot="floor", uv1=None, sockets=(), anchor=FLOOR),
    "Banner_A": dict(cat="prop", slots=("EnvCloth", "EnvGold", "EnvIron"), pivot="banner", uv1=DATA_UV, sockets=(),
                     anchor=WALL),
    "Banner_B": dict(cat="prop", slots=("EnvCloth", "EnvGold", "EnvIron"), pivot="banner", uv1=DATA_UV, sockets=(),
                     anchor=WALL),
    "TorchSconce_A": dict(cat="prop", slots=("EnvIron", "EnvWood", "EnvCanvas", "EnvFlame"), pivot="sconce",
                          uv1=CANDLE_UV, sockets=("Flame",), anchor=WALL),
    "WallLantern_A": dict(cat="prop", slots=("EnvIron", "EnvGlowWarm", "EnvWax"), pivot="sconce", uv1=None,
                          sockets=("Light",), anchor=WALL),
    "SpiritLantern_Post": dict(cat="prop", slots=("EnvIron", "EnvGlowSpirit"), pivot="floor", uv1=None,
                               sockets=("Light",), anchor=FLOOR),
    "Brazier_A": dict(cat="prop", slots=("EnvIron", "EnvGlowWarm", "EnvFlame"), pivot="floor", uv1=CANDLE_UV,
                      sockets=("Fire",), anchor=FLOOR),
    "CandleLedge_A": dict(cat="cluster", slots=("EnvWax", "EnvIron", "EnvFlame"), pivot="ledge", uv1=CANDLE_UV,
                          sockets=tuple("Flame_%02d" % i for i in range(6)), anchor=LEDGE),
    "CandleLedge_B": dict(cat="cluster", slots=("EnvWax", "EnvIron", "EnvFlame"), pivot="ledge", uv1=CANDLE_UV,
                          sockets=("Flame_00", "Flame_01", "Flame_02"), anchor=LEDGE),
    "CandleLedge_C": dict(cat="cluster", slots=("EnvWax", "EnvIron", "EnvFlame"), pivot="ledge", uv1=CANDLE_UV,
                          sockets=tuple("Flame_%02d" % i for i in range(7)), anchor=LEDGE),
    # wood goods from concepts 2 and 4 (the round-1 review's "missing" list; not yet in ENV_KIT, see the report)
    "Barrel_A": dict(cat="prop", slots=("EnvWood", "EnvIron"), pivot="floor", uv1=None, sockets=(), anchor=FLOOR),
    "Crate_A": dict(cat="prop", slots=("EnvWood", "EnvIron"), pivot="floor", uv1=None, sockets=(), anchor=FLOOR),
    "Crate_B": dict(cat="prop", slots=("EnvWood", "EnvIron"), pivot="floor", uv1=None, sockets=(), anchor=FLOOR),
    "Railing_A": dict(cat="prop", slots=("EnvWood", "EnvIron"), pivot="post", uv1=None, sockets=(), anchor=FLOOR),
    "RailingPost_A": dict(cat="prop", slots=("EnvWood",), pivot="floor", uv1=None, sockets=(), anchor=FLOOR),
}
NAMES = tuple(RULES)
PIVOT_NOTE = {
    "floor": "XY centre of the footprint, z = 0 on the floor (flat underside)",
    "sconce": "the wall mount point (centre of the back plate) at the origin, back plate on y = 0, protruding toward "
              "Blender -y (Unreal +Y)",
    "banner": "x / z = the rod axis (the hang point), y = 0 = the wall plane behind the brackets; the rod axis is 6 cm "
              "off the wall (Unreal +Y 6), the cloth hangs toward -Z",
    "post": "the first post's footprint centre at the origin, z = 0 on the floor; the rails run 200 cm along +X (Unreal "
            "+X) to where the next segment's post stands",
    "ledge": "the ledge edge at y = 0, z = 0: candles stand on the ledge top (z = 0, Blender +y / Unreal -Y), the wax "
             "runs over the edge and down the face (y = 0, z < 0); x centred on the piece",
}


# ================================================================ sacks (SDF cloth)
class Sack:
    """One tied grain sack as a distance field: a lumpy, bottom-heavy ellipsoid body with pleats gathered toward the
    neck, a tapered neck, a rope tie (torus) with two hanging tails, and the gathered cloth flaring above the tie."""

    def __init__(self, seed, centre, radii, yaw=0.0, roll=0.0, neck=None, flare=None, bulge=0.14, pleat=(6, 0.05),
                 lumpiness=0.9, tails=(30.0, -40.0), stripe=None, q=2.5, creases=4, crease_depth=0.1, shoulder=1.3,
                 sag=(0.0, 0.0), facets=34, neck_pleats=0, neck_pleat_amp=0.18, neck_k=4.5, diag=(),
                 fine_top=1.2, fine_base=1.0):
        rng = np.random.default_rng(seed)
        self.seed = seed
        self.facets = facets
        self.neck_pleats, self.neck_pleat_amp, self.neck_k = neck_pleats, neck_pleat_amp, neck_k
        self.diag = diag                  # long sag creases across the top: (angle deg, offset / rx, depth cm, width cm)
        self.fine_top, self.fine_base = fine_top, fine_base     # facet density boost near the neck / the base
        self.shoulder = shoulder
        self.sag = sag
        self.crease_depth = crease_depth
        # deliberate folds running down from the neck: crease angles spread round the body, jittered
        base = rng.uniform(0.0, TAU)
        self.creases = [base + TAU * k / max(creases, 1) + rng.uniform(-0.35, 0.35) for k in range(creases)]
        self.c = np.asarray(centre, float)
        self.R = np.asarray(radii, float)
        self.M = rot_matrix(Z, yaw) @ rot_matrix(X, roll)            # columns: the body's local axes in world
        self.bulge = bulge
        self.q = q
        self.pleat_n, self.pleat_amp = pleat
        self.lumpiness = lumpiness
        self.ph = rng.uniform(0.0, TAU, 8)
        self.P0, self.P1 = np.asarray(neck[0], float), np.asarray(neck[1], float)
        self.r0, self.r1 = neck[2], neck[3]
        self.a1 = _n(self.P1 - self.P0)
        self.fa = _n(flare[0])
        self.fL, self.rf = flare[1], flare[2]
        self.fu, self.fw, _ = axis_frame(self.fa)
        self.tie_R, self.tie_r = self.r1 + 0.25, 1.25
        self.stripe = stripe
        u, w, _ = axis_frame(self.a1)
        self.tails = []
        for k, ang in enumerate(tails):
            a = math.radians(ang)
            d = u * math.cos(a) + w * math.sin(a)
            start = self.P1 + d * (self.tie_R + 0.4)
            drop = _n(np.array([d[0], d[1], 0.0]) * 0.35 + np.array([0.0, 0.0, -1.0]))
            length = rng.uniform(7.5, 10.5)
            end = start + drop * length + d * 1.2
            self.tails.append((start, end, 0.85, 0.7, end + drop * 0.6, rng.uniform(1.2, 1.45)))

    def local(self, x, y, z):
        dx, dy, dz = x - self.c[0], y - self.c[1], z - self.c[2]
        m = self.M
        return (dx * m[0, 0] + dy * m[1, 0] + dz * m[2, 0], dx * m[0, 1] + dy * m[1, 1] + dz * m[2, 1],
                dx * m[0, 2] + dy * m[1, 2] + dz * m[2, 2])

    def components(self, x, y, z):
        lx, ly, lz = self.local(x, y, z)
        rx, ry, rz = self.R
        zr = np.clip(lz / rz, -1.5, 1.5)
        # the upper half slumps sideways (sag = fraction of the radius the top shifts by)
        slump = smoothstep(-0.35, 1.0, zr) ** 1.5
        lx = lx - self.sag[0] * rx * slump
        ly = ly - self.sag[1] * ry * slump
        widen = 1.0 + self.bulge * smoothstep(0.25, -1.0, zr)
        th = np.arctan2(ly, lx)
        pleat = 1.0 + self.pleat_amp * smoothstep(0.15, 0.95, zr) * np.sin(self.pleat_n * th + self.ph[0])
        sag = 1.0 + 0.045 * np.sin(2.0 * th + self.ph[1]) + 0.03 * np.sin(3.0 * th + self.ph[2])
        groove = 0.0
        for tc in self.creases:
            dth = np.abs(np.angle(np.exp(1j * (th - tc))))
            groove = groove + np.clip(1.0 - dth / 0.34, 0.0, 1.0) ** 1.5
        crease = 1.0 - self.crease_depth * smoothstep(-0.45, 0.8, zr) * groove
        k = widen * pleat * sag * crease
        rxy = np.sqrt((lx / (rx * k)) ** 2 + (ly / (ry * k)) ** 2)
        q = self.q + self.shoulder * smoothstep(0.0, 0.7, zr)                 # flat, squared-off shoulders
        kk = (rxy ** q + np.abs(lz / rz) ** q) ** (1.0 / q)
        body = (kk - 1.0) * np.minimum(np.minimum(rx * k, ry * k), rz) * 0.85     # a superellipsoid: a filled bag
        body = body - self.lumpiness * ep.sine_lumps(x, y, z, self.seed, 0.16)
        for ang, off, depth, width in self.diag:
            a = math.radians(ang)
            dist = lx * math.cos(a) + ly * math.sin(a) - off * rx
            g = np.clip(1.0 - np.abs(dist) / width, 0.0, 1.0) ** 1.5
            body = body + depth * g * smoothstep(0.05, 0.75, zr)
        if self.neck_pleats:
            # a cone from the body to the tie with gathered pleat ridges that converge on the tie
            u, w, _ = axis_frame(self.a1)
            e = self.P1 - self.P0
            L = float(np.linalg.norm(e))
            px, py, pz = x - self.P0[0], y - self.P0[1], z - self.P0[2]
            s = px * self.a1[0] + py * self.a1[1] + pz * self.a1[2]
            t = np.clip(s / L, 0.0, 1.0)
            qx, qy, qz = px - t * e[0], py - t * e[1], pz - t * e[2]
            r = np.sqrt(qx * qx + qy * qy + qz * qz)
            phi = np.arctan2(qx * w[0] + qy * w[1] + qz * w[2], qx * u[0] + qy * u[1] + qz * u[2])
            ridge = (0.5 + 0.5 * np.cos(self.neck_pleats * phi + self.ph[5])) ** 2
            rad = (self.r0 + (self.r1 - self.r0) * t ** 0.8) * (1.0 + self.neck_pleat_amp * ridge * (1.0 - t) ** 0.7)
            neck = r - rad
        else:
            neck = ep.sd_capsule(x, y, z, self.P0, self.P1, self.r0, self.r1, power=0.8)
        # the gathered flare above the tie: a pleated cone with a crumpled, dished top
        px, py, pz = x - self.P1[0], y - self.P1[1], z - self.P1[2]
        s = px * self.fa[0] + py * self.fa[1] + pz * self.fa[2]
        qu = px * self.fu[0] + py * self.fu[1] + pz * self.fu[2]
        qw = px * self.fw[0] + py * self.fw[1] + pz * self.fw[2]
        r = np.sqrt(qu * qu + qw * qw)
        phi = np.arctan2(qw, qu)
        t = np.clip(s / self.fL, 0.0, 1.0)
        rad = (self.r1 * 0.92 + (self.rf - self.r1 * 0.92) * t ** 0.75) * \
            (1.0 + 0.2 * np.sin(7.0 * phi + self.ph[3]) * smoothstep(0.15, 1.0, t))
        top = self.fL * (1.0 + 0.12 * np.sin(3.0 * phi + self.ph[4])) - 2.2 * (1.0 - np.clip(r / np.maximum(rad, 1e-3),
                                                                                                0.0, 1.0) ** 2)
        flare = np.maximum(r - rad, np.maximum(-s - 1.0, s - top))
        tie = ep.sd_torus(x, y, z, self.P1, self.a1, self.tie_R, self.tie_r)
        tails = None
        for a, b, ra, rb, knot, kr in self.tails:
            d = np.minimum(ep.sd_capsule(x, y, z, a, b, ra, rb), ep.sd_sphere(x, y, z, knot, kr))
            tails = d if tails is None else np.minimum(tails, d)
        rope = tie if tails is None else np.minimum(tie, tails)
        return {"body": body, "neck": neck, "flare": flare, "rope": rope}

    def sdf(self, x, y, z):
        p = self.components(x, y, z)
        d = cg._smin(p["body"], p["neck"], self.neck_k)
        d = cg._smin(d, p["flare"], 1.6)
        return cg._smin(d, p["rope"], 0.35)

    def bounds(self):
        ext = self.R.max() * 1.35
        tip = self.P1 + self.fa * self.fL * 1.2
        pts = [self.c - ext, self.c + ext, tip - self.rf * 1.4, tip + self.rf * 1.4, self.P1]
        for a, b, *_ in self.tails:
            pts += [a, b]
        pts = np.array(pts)
        return pts.min(axis=0) - 4.0, pts.max(axis=0) + 4.0


def sacks_field(sacks, k=0.4):
    def fn(x, y, z):
        d = sacks[0].sdf(x, y, z)
        for s in sacks[1:]:
            d = cg._smin(d, s.sdf(x, y, z), k)
        return np.maximum(d, -z)                                     # the floor cuts a flat base
    return fn


def sack_tags(sacks, cen):
    """Owner sack and part (body / neck / flare / rope) of faces with centres cen (field frame)."""
    own = np.stack([s.sdf(cen[:, 0], cen[:, 1], cen[:, 2]) for s in sacks])
    owner = np.argmin(own, axis=0)
    comps = [s.components(cen[:, 0], cen[:, 1], cen[:, 2]) for s in sacks]
    tags = []
    for i in range(len(cen)):
        d = {name_: float(val[i]) for name_, val in comps[owner[i]].items()}
        best = min(d, key=d.get)
        if d["rope"] < min(d["body"], d["neck"], d["flare"]) + 0.25:
            tags.append("rope")
        elif best in ("flare", "neck"):
            tags.append(best)
        else:
            tags.append("body")
    return owner, tags


def bisect_stripes(v, t, sacks):
    """Cut the striped sacks' faces along their stripe planes (local z = a, b) so the stripe has straight edges."""
    mesh = bpy.data.meshes.new("_stripe")
    mesh.from_pydata(np.asarray(v, float).tolist(), [], np.asarray(t).tolist())
    bm = bmesh.new()
    bm.from_mesh(mesh)
    for k, s in enumerate(sacks):
        if not s.stripe:
            continue
        axis = s.M[:, 2]
        for a, b in s.stripe:
            for zc in (a, b):
                co = s.c + axis * zc
                faces = list(bm.faces)
                cen = np.array([f.calc_center_median()[:] for f in faces])
                own = np.argmin(np.stack([o.sdf(cen[:, 0], cen[:, 1], cen[:, 2]) for o in sacks]), axis=0)
                near = np.abs((cen - co) @ axis) < 6.0
                fsel = [f for f, ok in zip(faces, (own == k) & near) if ok]
                geom = list({e for f in fsel for e in f.edges}) + fsel + list({x for f in fsel for x in f.verts})
                bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-4, plane_co=co.tolist(), plane_no=axis.tolist())
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.verts.index_update()
    vv = np.array([x.co[:] for x in bm.verts], float)
    tt = np.array([[x.index for x in f.verts] for f in bm.faces], np.int64)
    bm.free()
    bpy.data.meshes.remove(mesh)
    return vv, tt


def build_sacks(name, sacks, target_tris, voxel):
    lo = np.min([s.bounds()[0] for s in sacks], axis=0)
    hi = np.max([s.bounds()[1] for s in sacks], axis=0)
    lo[2] = -1.5 * voxel
    field = sacks_field(sacks)
    vals, origin = ep.sample_grid(field, lo, hi, voxel)
    v, t, full = ep.sdf_to_mesh(vals, origin, voxel, target_tris)
    v[v[:, 2] < 0.3 * voxel, 2] = 0.0
    v, t = ep.clean_closed(v, t)
    # chunky facets: per sack, its body faces are split into ~30-40 near-flat regions and each region is pulled flat
    # (the neck, flare, rope and the floor contact stay as meshed)
    fcen = v[t].mean(axis=1)
    owner, tags = sack_tags(sacks, fcen)
    labels = np.full(len(t), -1)
    for k, s in enumerate(sacks):
        m = (owner == k) & np.array([tg == "body" for tg in tags])
        # bigger planes on the belly, smaller ones near the neck and the base (round-2 review)
        zr = s.local(fcen[:, 0], fcen[:, 1], fcen[:, 2])[2] / s.R[2]
        dens = 1.0 + s.fine_top * smoothstep(0.35, 0.9, zr) + s.fine_base * smoothstep(-0.45, -0.9, zr)
        lab = ep.facet_regions(v, t, m, s.facets, s.seed + 11, density=dens)
        sel = lab >= 0
        labels[sel] = lab[sel] + (labels.max() + 1)
    v = ep.planarize(v, t, labels, fixed=v[:, 2] < 1e-6)
    cen_reg, lab_reg = v[t].mean(axis=1), labels.copy()
    v, t = ep.clean_closed(v, t)
    if any(s.stripe for s in sacks):
        v, t = bisect_stripes(v, t, sacks)
        v, t = ep.clean_closed(v, t)
    v[:, 2] = np.maximum(v[:, 2], 0.0)
    v[v[:, 2] < 0.02, 2] = 0.0
    # drop zero-volume fins the clean-up can leave (a face doubled with its reverse): both copies go
    key = [tuple(sorted(x)) for x in t.tolist()]
    seen = {}
    for i, kk in enumerate(key):
        seen.setdefault(kk, []).append(i)
    drop = {i for ids in seen.values() if len(ids) > 1 for i in ids}
    if drop:
        t = np.array([x for i, x in enumerate(t.tolist()) if i not in drop], np.int64)
        v, t = ep.clean_closed(v, t)
    # pivot: XY centre of the footprint
    foot = v[v[:, 2] < 1e-6]
    shift = np.array([0.5 * (v[:, 0].min() + v[:, 0].max()), 0.5 * (v[:, 1].min() + v[:, 1].max()), 0.0])
    cen = v[t].mean(axis=1)
    owner, tags = sack_tags(sacks, cen)
    # each final face keeps its facet region (nearest region face before the clean-up / stripe cut)
    region = np.empty(len(t), np.int64)
    for i0 in range(0, len(t), 512):
        d2 = ((cen[i0:i0 + 512, None, :] - cen_reg[None, :, :]) ** 2).sum(axis=2)
        region[i0:i0 + 512] = lab_reg[np.argmin(d2, axis=1)]
    for i in range(len(t)):
        if tags[i] == "body":
            s = sacks[owner[i]]
            if s.stripe:
                lz = s.local(cen[i:i + 1, 0], cen[i:i + 1, 1], cen[i:i + 1, 2])[2][0]
                if any(a < lz < b for a, b in s.stripe):
                    tags[i] = "stripe"
    v = v - shift
    parts = Parts(("EnvCanvas",))
    parts.add((v, t.tolist()), "EnvCanvas", tags, group=0)
    parts.group = [int(o) for o in owner]
    obj = parts.build(name + "_Mars_SM")
    # cavity / AO from the field itself (folds, the creases between pressed sacks, the floor)
    vn = ep.vertex_normals(v, t)
    ao = ep.field_ao(lambda x, y, z: np.minimum(field(x + shift[0], y + shift[1], z), z + 1.2), v, vn,
                     steps=((1.0, 0.4), (2.6, 0.35), (5.5, 0.25)))
    cav = fc.cavity(obj)
    alpha = np.clip(ao * (0.7 + 0.3 * np.clip(cav * 2.0, 0.0, 1.0)), 0.0, 1.0)
    canvas = P("EnvCanvas")
    red = P("EnvCloth")
    rng = np.random.default_rng(sacks[0].seed + 5)
    tone = {k: rng.uniform(0.86, 1.1) for k in range(len(sacks))}
    warm = {k: rng.uniform(-0.04, 0.05) for k in range(len(sacks))}
    # one hand-painted value per facet region: about +-12 % between neighbouring planes
    reg_tone = {r: rng.uniform(0.88, 1.12) for r in sorted(set(int(x) for x in region))}

    def fn(i, tag, g, c, nrm):
        base = canvas * tone[g] * np.array([1.0 + warm[g], 1.0, 1.0 - warm[g]])
        k = rng.uniform()
        if tag == "rope":
            col = canvas * np.array([0.62, 0.52, 0.38])
        elif tag == "flare":
            col = base * (1.1 if k > 0.4 else 0.95)
        elif tag == "stripe":
            col = lerp(base, red, 0.55) * 0.92 * reg_tone[int(region[i])]
        elif tag == "neck":
            col = base * 0.97
        else:
            col = base * reg_tone[int(region[i])]
        if c[2] < 2.5:
            col = col * 0.82                                      # floor grime along the base
        return col

    ep.paint_parts(obj, parts, fn, variation=0.02, seed=sacks[0].seed, cavity_darken=0.42, alpha=alpha)
    body = labels >= 0
    info = {"surface_nets_tris": int(full), "voxel_cm": voxel, "sacks": len(sacks),
            "facet_regions": int(len(set(labels[body].tolist()))),
            "footprint_cm": [round(float(x), 1) for x in (foot.max(axis=0) - foot.min(axis=0))[:2]] if len(foot) else None}
    return obj, parts, info


def sack_a():
    """Upright: the body's centre sits low so the floor cuts a flat, spread bottom (~34 x 32 cm footprint, the bulge
    swelling just above the floor); the gathered flare above the tie flops ~25 degrees to one side."""
    s = Sack(4101, (0.0, 0.0, 18.0), (19.5, 17.5, 27.0), yaw=12.0, bulge=0.2, pleat=(6, 0.06), lumpiness=0.8,
             neck=((0.6, 0.3, 39.0), (2.2, 0.8, 49.5), 8.5, 4.6),
             flare=((0.46, 0.12, 0.88), 9.5, 8.4), tails=(20.0, -55.0), stripe=((-1.0, 1.6), (4.0, 5.2)), facets=40,
             shoulder=0.75, crease_depth=0.15, fine_top=1.4, fine_base=1.2)
    return build_sacks("Sack_A", [s], 1000, 0.75)


def sack_b():
    """Slumped: a broad flat base, the top 30 % sagging toward the neck side (+x), the neck a pleated cone tapering
    out of the shoulder over ~12 cm into the tie (no scoop at its root), the flare flopped down the side, and three
    long diagonal sag creases across the top (cloth over grain, not a boulder)."""
    s = Sack(4102, (0.0, 0.0, 11.0), (28.0, 24.0, 19.0), yaw=-8.0, bulge=0.3, pleat=(5, 0.02), lumpiness=0.45,
             neck=((9.0, 0.5, 22.0), (21.0, 1.5, 31.5), 11.0, 4.6), sag=(0.3, 0.06), shoulder=0.6,
             flare=((0.9, 0.05, -0.42), 10.0, 8.2), tails=(70.0, 160.0), facets=34, creases=0, crease_depth=0.0,
             neck_pleats=5, neck_pleat_amp=0.24, neck_k=6.0,
             diag=((32.0, -0.2, 2.6, 3.6), (68.0, 0.2, 2.2, 3.2), (-24.0, 0.45, 2.0, 3.0)))
    return build_sacks("Sack_B", [s], 1000, 0.75)


def sack_c():
    """Concept 4: a sack lying on its side, the tied neck toward the room (Blender -y / Unreal +Y), its belly slumped
    flat on the floor and a pleated neck cone gathered into the tie."""
    s = Sack(4103, (0.0, 4.0, 12.0), (21.0, 15.0, 26.0), roll=90.0, yaw=0.0, bulge=0.12, pleat=(5, 0.03),
             lumpiness=0.6, neck=((0.5, -16.0, 13.0), (1.2, -32.0, 15.5), 10.0, 4.4), shoulder=0.7,
             flare=((0.15, -0.9, 0.42), 9.0, 8.2), tails=(40.0, 150.0), facets=34, creases=0, crease_depth=0.0,
             neck_pleats=5, neck_pleat_amp=0.18, neck_k=6.0)
    return build_sacks("Sack_C", [s], 1000, 0.75)


def sack_pile():
    sacks = [
        Sack(4111, (-25.0, -12.0, 15.5), (28.0, 21.0, 16.5), yaw=20.0, roll=-4.0, bulge=0.2, pleat=(5, 0.04),
             lumpiness=1.0, neck=((-45.0, -20.0, 19.0), (-55.0, -24.5, 17.0), 8.4, 4.3),
             flare=((-0.7, -0.2, -0.68), 8.5, 7.2), tails=(80.0, 200.0)),
        Sack(4112, (27.0, -9.0, 15.5), (29.0, 20.0, 16.0), yaw=-14.0, roll=4.0, bulge=0.2, pleat=(5, 0.04),
             lumpiness=1.0, neck=((48.0, -14.0, 18.0), (58.0, -16.5, 16.0), 8.4, 4.3),
             flare=((0.74, -0.1, -0.66), 8.5, 7.4), tails=(60.0, 170.0)),
        Sack(4113, (3.0, 21.0, 23.0), (20.0, 17.0, 23.5), yaw=40.0, bulge=0.15, pleat=(6, 0.06), lumpiness=0.9,
             neck=((3.4, 21.3, 39.0), (4.2, 21.8, 50.0), 8.2, 4.5),
             flare=((0.1, 0.12, 1.0), 9.0, 8.0), tails=(-60.0, 120.0), stripe=((2.0, 4.4), (6.6, 7.8))),
        Sack(4114, (1.0, -11.0, 41.0), (27.0, 18.0, 13.5), yaw=6.0, roll=-6.0, bulge=0.1, pleat=(5, 0.04),
             lumpiness=0.9, neck=((22.0, -9.0, 44.0), (32.5, -8.0, 43.0), 8.0, 4.2),
             flare=((0.62, 0.1, -0.78), 8.0, 7.0), tails=(90.0, 220.0)),
    ]
    return build_sacks("SackPile_A", sacks, 2000, 0.9)


# ================================================================ banners (cloth sheet + decals)
ROD_Y = -6.0
ROD_R = 1.7
CLOTH_T = 0.8


def thick_sheet(front, back, tris_front):
    """Close a triangulated front sheet with its back (reversed) and side strips along the boundary."""
    nv = len(front)
    verts = np.concatenate([front, back])
    faces = [list(t) for t in tris_front]
    faces += [[t[0] + nv, t[2] + nv, t[1] + nv] for t in tris_front]
    directed = {}
    for t in tris_front:
        for k in range(3):
            directed[(t[k], t[(k + 1) % 3])] = directed.get((t[k], t[(k + 1) % 3]), 0) + 1
    side = []
    for (p, q) in directed:
        if (q, p) not in directed:
            side.append([q, p, p + nv, q + nv])
    return verts, faces, len(faces) - len(side), side


def flame_emblem():
    """The gold flame emblem outline (unit height, the base point at (0, -0.15)): ONE upward heraldic flame - a tall
    central tongue to 1.0, two side tongues curling outward to about 0.6, the body narrowing to a point below. No bowl,
    no crescent (round-1 review: the crescent under a three-lobed flame read as a smiley face)."""
    return np.array([
        (0.00, -0.15), (0.10, -0.07), (0.19, 0.03), (0.26, 0.14), (0.30, 0.26), (0.34, 0.36), (0.40, 0.45),
        (0.45, 0.55), (0.48, 0.66),                                             # right tongue: flicks up and out
        (0.41, 0.59), (0.33, 0.51), (0.25, 0.45),                               # its inner edge to the notch
        (0.25, 0.56), (0.22, 0.67), (0.16, 0.77), (0.10, 0.86), (0.09, 0.93), (0.13, 1.00),   # central tongue, S-curved
        (0.03, 0.95), (-0.05, 0.87), (-0.11, 0.78), (-0.14, 0.68), (-0.15, 0.58), (-0.20, 0.49),
        (-0.28, 0.53), (-0.36, 0.58), (-0.45, 0.63),                            # left tongue tip
        (-0.43, 0.54), (-0.38, 0.45), (-0.34, 0.35), (-0.30, 0.24), (-0.26, 0.13), (-0.19, 0.03), (-0.10, -0.07)])


def build_banner(name, W, H, ncol, nrow, hem_fn, fold_amp, fold_waves, seed, emblem, bands, tatter=False,
                 notches=(), holes=(), xs=None, ripple=0.0, fray=0.0):
    """notches: (side -1 left / +1 right, s centre 0..1 down the drop, depth cm, half height in rows) V-cuts pulled
    into a long edge; holes: lists of (i, j) grid cells whose triangles are dropped (thick_sheet then walls the hole)
    with the hole's rim vertices jittered so it reads ragged. xs: explicit column positions (tear slits = column
    pairs); round 2 dropped the per-column ripple (it twisted the strips into shards): ripple / fray default 0."""
    rng = np.random.default_rng(seed)
    parts = Parts(("EnvCloth", "EnvGold", "EnvIron"))
    rod_half = W * 0.5 + 8.0
    # ---- the cloth: a pattern grid (x, z), folded in y, thickened into a closed sheet
    if xs is None:
        xs = np.linspace(-W * 0.5, W * 0.5, ncol + 1)
        xs[1:-1] += rng.uniform(-0.12, 0.12, ncol - 1) * (W / ncol)
    else:
        xs = np.asarray(xs, float)
        ncol = len(xs) - 1
    hem = hem_fn(xs, rng)
    s = np.linspace(0.0, 1.0, nrow + 1)
    top = 0.0
    wave = np.zeros(ncol + 1)
    for amp, length, ph in fold_waves:
        wave += amp * np.sin(TAU * xs / length + ph)
    wave += rng.uniform(-0.05, 0.05, ncol + 1)
    grid2 = np.zeros((ncol + 1, nrow + 1, 2))
    yoff = np.zeros((ncol + 1, nrow + 1))
    for i in range(ncol + 1):
        for j in range(nrow + 1):
            x = xs[i]
            if fray and i in (0, ncol) and s[j] > 0.45:
                x += (1 if i == 0 else -1) * rng.uniform(0.0, fray) * s[j]          # frayed, pulled-in edges
            z = top + (hem[i] - top) * s[j]
            grid2[i, j] = (x, z)
            a = fold_amp[0] + (fold_amp[1] - fold_amp[0]) * s[j] ** 1.1
            ripple_ = ripple * math.sin(3.1 * s[j] * TAU / 3.0 + i) * s[j]
            curl = (1.2 * s[j] if i in (0, ncol) else 0.0)                       # the edges curl back a little
            yoff[i, j] = wave[i] * a + ripple_ + curl - 1.6 * s[j] ** 1.5          # the hem drifts off the wall
    yoff[:, 0] = 0.0
    # the back of the cloth must stay in front of the wall (y < 0): more room toward the room than toward the wall
    yoff = np.clip(yoff, -8.0, -ROD_Y - CLOTH_T * 0.5 - 0.9)
    # ---- V-notches cut into the long edges: the edge column pulled in, the columns next to it compressed (monotonic)
    for side, sc_, depth, half_rows in notches:
        jc = int(round(sc_ * nrow))
        for j in range(max(1, jc - half_rows), min(nrow, jc + half_rows) + 1):
            d = depth * (1.0 - abs(j - jc) / (half_rows + 0.5))
            if d <= 0.0:
                continue
            reach = d + 5.0
            edge_x = grid2[0 if side < 0 else ncol, j, 0]
            for i in range(ncol + 1):
                e = abs(grid2[i, j, 0] - edge_x)
                if e < reach:
                    grid2[i, j, 0] += -side * d * (1.0 - e / reach)
    hole_cells = {tuple(c) for h in holes for c in h}
    rim = {(i + di, j + dj) for (i, j) in hole_cells for di in (0, 1) for dj in (0, 1)}
    for (i, j) in sorted(rim):
        grid2[i, j] += rng.uniform(-0.9, 0.9, 2)
    idx = lambda i, j: i * (nrow + 1) + j                                       # noqa: E731
    front = np.zeros(((ncol + 1) * (nrow + 1), 3))
    back = np.zeros_like(front)
    flex = np.zeros(len(front))
    for i in range(ncol + 1):
        for j in range(nrow + 1):
            x, z = grid2[i, j]
            y = ROD_Y + yoff[i, j]
            front[idx(i, j)] = (x, y - CLOTH_T * 0.5, z)
            back[idx(i, j)] = (x, y + CLOTH_T * 0.5, z)
            flex[idx(i, j)] = s[j]
    tris = []
    for i in range(ncol):
        for j in range(nrow):
            a, b, c, d = idx(i, j), idx(i + 1, j), idx(i + 1, j + 1), idx(i, j + 1)
            if (i, j) in hole_cells:
                continue
            tris.append((a, c, b))                                  # facing -y (the room)
            tris.append((a, d, c))
    verts, faces, n_sheet, side = thick_sheet(front, back, tris)
    tags = ["front"] * len(tris) + ["back"] * len(tris) + ["edge"] * len(side)
    parts.add((verts, faces + side), "EnvCloth", tags, flex=np.concatenate([flex, flex]))
    # ---- the sleeve round the rod
    sv, sf = lathe_on_axis([(0.0, -W * 0.5 - 0.4), (ROD_R + 1.05, -W * 0.5 - 0.4), (ROD_R + 1.25, 0.0),
                            (ROD_R + 1.05, W * 0.5 + 0.4), (0.0, W * 0.5 + 0.4)], 8, (0.0, ROD_Y, 0.0), X, 11.0)
    parts.add((sv, sf), "EnvCloth", "sleeve")
    # ---- decals: emblem + bands, ear-clipped, clipped to the front facets, 3 mm proud
    tri = np.array(tris)
    sheet2d = np.stack([grid2.reshape(-1, 2)[tri[:, k]] for k in range(3)], axis=1)
    sheet3d = np.stack([front[tri[:, k]] for k in range(3)], axis=1)
    vn = ep.vertex_normals(front, tri)
    sheet_n = np.stack([vn[tri[:, k]] for k in range(3)], axis=1)
    sheet_s = np.stack([flex[tri[:, k]] for k in range(3)], axis=1)
    polys = []
    for (cx, cz, height) in emblem:
        polys.append(flame_emblem() * height + np.array([cx, cz]))
    for band in bands:
        polys.append(band)
    dv, dt, dflex = ep.project_decals(sheet2d, sheet3d, sheet_n, sheet_s, polys, 0.3)
    parts.add((dv, dt), "EnvGold", "emblem", closed=False, face_dir=(0.0, -1.0, 0.0), flex=dflex)
    # ---- the rod, gilt finials, two wall brackets
    rv, rf = lathe_on_axis([(0.0, -rod_half), (ROD_R, -rod_half), (ROD_R, rod_half), (0.0, rod_half)], 8,
                           (0.0, ROD_Y, 0.0), X, 22.5)
    parts.add((rv, rf), "EnvIron", "rod")
    fin = [(0.0, -1.2), (1.9, -0.8), (2.5, 0.5), (2.1, 1.7), (1.0, 2.4), (1.25, 3.1), (0.7, 3.9), (2.0, 5.1),
           (0.9, 7.6), (0.0, 9.6)]
    for sgn in (-1.0, 1.0):
        fv, ff = lathe_on_axis(fin, 6, (sgn * (rod_half - 0.6), ROD_Y, 0.0), X * sgn, 0.0)
        parts.add((fv, ff), "EnvGold", "finial")
        xb = sgn * (W * 0.5 + 3.6)
        bv_, bf_ = chamfer_box((xb, -0.65, -1.6), (4.4, 1.3, 10.0), 0.35)
        parts.add((bv_, bf_), "EnvIron", "plate")
        arm = [(xb, -0.9, -2.05), (xb, ROD_Y - 2.55, -2.05)]
        parts.add(bar(arm, [Z, Z], 0.6, 0.6), "EnvIron", "bracket")
        lip = [(xb, ROD_Y - 2.65, -2.4), (xb, ROD_Y - 2.65, 0.9)]
        parts.add(bar(lip, [Y, Y], 0.5, 0.36), "EnvIron", "bracket")
        for zz in (-4.8, 1.6):
            parts.add(rivet((xb, -1.3, zz), -Y, rng, r=0.6, h=0.45), "EnvIron", "rivet")
    obj = parts.build(name + "_Mars_SM")
    # ---- paint
    cloth, dark, gold, iron, iron_l = P("EnvCloth"), P("EnvClothDark"), P("EnvGold"), P("EnvIron"), P("EnvIronLight")
    if tatter:
        cloth = lerp(cloth, dark, 0.22)
    prng = np.random.default_rng(seed + 1)

    def fn(i, tag, g, c, nrm):
        if tag == "front":
            ridge = float(np.clip(-(c[1] - ROD_Y) / 3.0, -1.0, 1.0))
            col = lerp(dark, cloth * 1.12, 0.55 + 0.45 * ridge)
            if tatter:
                sv_ = float(np.clip(-c[2] / H, 0.0, 1.0))
                col = col * (1.0 - 0.34 * smoothstep(0.45, 1.0, sv_))
            return col                                     # one value per fold plane: no per-triangle noise
        if tag == "back":
            return dark * 0.85
        if tag == "edge":
            return dark * 0.75
        if tag == "sleeve":
            return lerp(dark, cloth, 0.6)
        if tag == "emblem":
            ridge = float(np.clip(-(c[1] - ROD_Y) / 3.0, -1.0, 1.0))
            return gold * (0.9 + 0.12 * ridge)
        if tag == "finial":
            return gold * prng.uniform(0.85, 1.12)
        if tag == "rivet":
            return iron_l * 1.1
        if tag == "rod":
            return lerp(iron, iron_l, 0.4 if nrm[2] > 0.3 else 0.0)
        return iron * prng.uniform(0.9, 1.15)

    ep.paint_parts(obj, parts, fn, variation=0.012, seed=seed + 2, cavity_darken=0.3)
    info = {"cloth_width_cm": W, "cloth_drop_cm": round(float(-hem.min()), 1), "rod_axis_cm": [0.0, ROD_Y, 0.0],
            "rod_length_cm": round(2 * rod_half + 2 * 9.0, 1), "decal_tris": len(dt), "decal_lift_cm": 0.3}
    return obj, parts, info


def banner_a():
    W, H = 120.0, 300.0

    def hem(xs, rng):
        tri = np.abs(((xs + 60.0) % 40.0) - 20.0) / 20.0                      # 1 at the notches, 0 at the points
        return -H + 26.0 * tri + rng.uniform(-0.8, 0.8, len(xs))

    xs_band = np.linspace(-60.0, 60.0, 13)
    hz = -H + 26.0 * np.abs(((xs_band + 60.0) % 40.0) - 20.0) / 20.0
    band_lo = np.column_stack([xs_band * 0.985, hz + 7.0])
    band_hi = np.column_stack([xs_band * 0.985, hz + 11.0])
    hem_band = np.concatenate([band_lo, band_hi[::-1]])
    top_band = np.array([(-58.5, -9.5), (58.5, -9.5), (58.5, -6.0), (-58.5, -6.0)])
    # gold borders down both long edges (3 cm), stopping 0.5 cm short of the top and hem bands (no coplanar overlap)
    zb = lambda x: float(np.interp(x, band_hi[:, 0], band_hi[:, 1])) + 0.5          # noqa: E731
    sides = [np.array([(x0, -10.0), (x0, zb(x0)), (x1, zb(x1)), (x1, -10.0)]) for x0, x1 in ((-58.5, -55.5),
                                                                                            (55.5, 58.5))]
    # round 2: 10 cm columns (one triangle row per fold half-wave) and 20 cm bands, so the cloth and its emblem are
    # long vertical pleat strips, not decimation noise
    return build_banner("Banner_A", W, H, 12, 15, hem, (0.6, 5.0), ((1.0, 40.0, 0.4), (0.3, 20.0, 2.1)), 4201,
                        emblem=[(0.0, -134.0, 60.0)], bands=[hem_band, top_band] + sides)


# Banner_B's torn strips: (x0, x1, drop below the tear tops cm, slope of the diagonal cut cm/cm)
BANNER_B_STRIPS = ((-35.0, -16.2, 30.0, 0.32), (-16.2, 0.4, 52.0, -0.28), (0.4, 19.5, 22.0, 0.3), (19.5, 35.0, 42.0,
                                                                                                  -0.35))
BANNER_B_SLIT = 0.7          # half width of a tear slit between two strips at its top


def banner_b():
    """Narrow, long and torn (round 2): four cloth strips 15-19 cm wide hanging 22-52 cm below straight tear slits,
    each strip ending in a straight diagonal cut broken into 2-3 ragged triangle points; the strips keep the upper
    cloth's shallow pleat wave (<= 3.5 cm) and never twist."""
    W, H = 70.0, 330.0
    z_tear = -H + 62.0                       # the tops of the slits between strips
    xs, kind = [], []
    for k, (x0, x1, L, slope) in enumerate(BANNER_B_STRIPS):
        a = x0 + (BANNER_B_SLIT if k > 0 else 0.0)
        b = x1 - (BANNER_B_SLIT if k < len(BANNER_B_STRIPS) - 1 else 0.0)
        n = max(3, int(round((b - a) / 3.6)))
        for q, x in enumerate(np.linspace(a, b, n + 1)):
            xs.append(x)
            kind.append((k, q, n))
    xs = np.array(xs)

    def hem(xs_, rng):
        z = np.zeros(len(xs_))
        for i, (k, q, n) in enumerate(kind):
            x0, x1, L, slope = BANNER_B_STRIPS[k]
            xc = 0.5 * (x0 + x1)
            edge = (q == 0 and k > 0) or (q == n and k < len(BANNER_B_STRIPS) - 1)
            if edge:
                z[i] = z_tear + rng.uniform(-1.0, 1.0)              # the top of a slit
                continue
            z[i] = z_tear - L + slope * (xs_[i] - xc)
            if 0 < q < n:
                z[i] += rng.uniform(4.0, 7.5) if q % 2 else rng.uniform(-1.5, 0.0)     # ragged triangle points
        return z

    top_band = np.array([(-33.5, -8.5), (33.5, -8.5), (33.5, -6.0), (-33.5, -6.0)])
    notches = ((-1, 0.72, 5.0, 1), (1, 0.82, 4.0, 1))
    return build_banner("Banner_B", W, H, len(xs) - 1, 22, hem, (0.4, 3.0), ((1.0, 26.0, 1.3), (0.25, 13.0, 0.2)),
                        4202, emblem=[(0.0, -74.0, 36.0)], bands=[top_band], tatter=True, notches=notches, xs=xs)


# ================================================================ torch sconce
def build_torch():
    rng = np.random.default_rng(4301)
    parts = Parts(("EnvIron", "EnvWood", "EnvCanvas", "EnvFlame"))
    # wall plate: a pointed gothic lozenge, bevelled front, two bolts
    outline = np.array([(0.0, 12.5), (4.2, 7.6), (4.2, -7.6), (0.0, -12.5), (-4.2, -7.6), (-4.2, 7.6)])
    outline = outline + rng.uniform(-0.12, 0.12, outline.shape)
    parts.add(extrude_outline(outline, 0.0, -1.7, bevel=0.75, y_bevel=-1.1), "EnvIron", "plate")
    for zz in (8.9, -8.9):
        parts.add(rivet((0.0, -1.7, zz), -Y, rng, r=0.75, h=0.55), "EnvIron", "rivet")
    tilt = math.radians(14.0)
    d = np.array([0.0, -math.sin(tilt), math.cos(tilt)])                      # the torch leans off the wall
    C = np.array([0.0, -14.5, 3.0])                                           # the collar
    L = C - d * 7.0                                                           # the lower ring
    # twisted square arm from the plate into the collar
    arm = np.array([(0.0, -1.2 - 11.2 * k / 8.0, 3.0) for k in range(9)])
    parts.add(bar(arm, twisted_normals(arm, Z, 180.0), 0.72, 0.72), "EnvIron", "arm")
    # brace: from the plate's lower point curving up into the lower ring
    br = bezier((0.0, -1.0, -7.2), (0.0, -6.5, -8.6), (0.0, -10.0, -6.5), L + np.array([0.0, 1.9, 0.0]), 8)
    parts.add(bar(br, [X] * len(br), 0.5, 0.5), "EnvIron", "brace")
    stick_r = lambda t: 1.65 + 0.65 * t                                        # noqa: E731  radius along the stick
    s0, s1 = -17.0, 21.0                                                       # stick ends along d from C
    # collar + lower ring grip the stick (inner radius a touch under the stick's)
    r_c, r_l = stick_r((0.0 - s0) / (s1 - s0)), stick_r((-7.0 - s0) / (s1 - s0))
    parts.add(hoop(C, d, r_c + 0.32, 0.45, 0.85, 10), "EnvIron", "collar")
    parts.add(hoop(L, d, r_l + 0.28, 0.4, 0.6, 10), "EnvIron", "collar")
    u, w, _ = axis_frame(d)
    for ang in (60.0, 180.0, 300.0):
        a = math.radians(ang)
        rd = u * math.cos(a) + w * math.sin(a)
        p0 = L + rd * (r_l + 0.15)
        p1 = C + rd * (r_c + 0.15)
        dia = _n(rd + np.cross(d, rd))                                     # diamond section: no face parallel to a ring
        parts.add(bar([p0, p1], [dia, dia], 0.34, 0.34), "EnvIron", "basket")
    # the stick
    prof = [(0.0, s0 - 0.6)]
    for t in np.linspace(0.0, 1.0, 7):
        prof.append((stick_r(t), s0 + (s1 - s0) * t))
    prof.append((0.0, s1 + 0.3))
    sv, sf = lathe_on_axis(prof, 7, C, d, 8.0, jitter=0.09, rng=rng)
    parts.add((sv, sf), "EnvWood", "stick")
    # the pitch head: wrapped rag bands of distinct radii, a little skew, and a domed pitch cap
    T = C + d * s1
    head_tags = []
    # the lower two bands hug the stick, the top two flare out (~1.3x) to cup the fire
    for k, (zc, ro, hh, tilt_deg) in enumerate(((-9.6, 3.45, 3.0, 7.0), (-6.6, 3.95, 3.2, -9.0),
                                                (-3.5, 4.75, 3.0, 5.0), (-0.6, 5.15, 3.1, -6.0))):
        ri = stick_r(1.0) - 0.35
        band = [(ri, -hh * 0.5), (ro - 0.45, -hh * 0.5), (ro, -hh * 0.18), (ro + 0.1, hh * 0.15),
                (ro - 0.5, hh * 0.5), (ri, hh * 0.5)]
        bv_, bf_ = lathe_closed(band, 8, rng.uniform(0, 45))
        bv_ = bv_ + rng.uniform(-0.12, 0.12, bv_.shape)
        ax = rot_matrix(u, tilt_deg) @ d
        bv_ = place_on_axis(bv_, T + d * zc, ax)
        parts.add((bv_, bf_), "EnvCanvas", "rag")
    cap = [(0.0, -1.6), (4.2, -1.3), (5.0, 0.2), (4.4, 1.0), (2.4, 1.4), (0.0, 1.55)]     # dark pitch dome
    cv, cf = lathe_on_axis(cap, 8, T + d * 0.9, d, 13.0, jitter=0.15, rng=rng)
    parts.add((cv, cf), "EnvCanvas", "pitch")
    # ragged rag tails hanging from under the lowest pitch band, a little outward (round-2 review)
    low = T + d * (-9.6)
    for k, (ang, L) in enumerate(((35.0, 7.5), (150.0, 5.5), (250.0, 8.0), (318.0, 6.0))):
        a = math.radians(ang)
        rd = u * math.cos(a) + w * math.sin(a)
        p0 = low + rd * 2.9 + d * 0.4
        p1 = p0 - Z * (0.45 * L) + rd * 1.0
        p2 = p0 - Z * L + rd * 2.0 + u * rng.uniform(-0.6, 0.6)
        tn = rot_matrix(d, 28.0) @ rd                         # turned off the bands' facets (no parallel faces)
        tv, tf = bar([p0, p1, p2], [tn, tn, tn], 0.28, [1.35, 1.05, 0.25])
        parts.add((tv, tf), "EnvCanvas", "tail")
    # the fire: ONE soft teardrop tongue (6 sides, widest 9 cm at 30 %, spine bent ~12 degrees, big facets) with two
    # 5 cm side tongues whose roots sit inside the main tongue's base ring, so the head reads as one flame mass
    head_top = T + d * 2.6
    frng = np.random.default_rng(4302)
    flames = [((0.0, 0.0, -2.2), 20.0, 9.5, (0.3, -1.0), 13.0, 0.5, 0.137),
              ((-2.0, 0.4, -0.6), 12.0, 5.2, (-1.0, 0.25), 22.0, 0.7, 0.583),
              ((2.6, -0.6, -0.5), 10.5, 5.0, (1.0, -0.2), 30.0, 0.75, 0.861)]
    mid = None
    for off, h, wd, lean, bend, curl, fid in flames:
        base = head_top + np.array(off)
        fv, ft, fh = tongue(base, h, wd, frng, lean=lean, bend_deg=bend, curl=curl, rings=SOFT_RINGS)
        parts.add((fv, ft), "EnvFlame", "flame", fid=fid, fh=fh)
        if mid is None:
            mid = base + np.array([0.0, 0.0, 0.4 * h])
    obj = parts.build("TorchSconce_A_Mars_SM")
    iron, iron_l, wood, wood_d, canvas = P("EnvIron"), P("EnvIronLight"), P("EnvWood"), P("EnvWoodDark"), P("EnvCanvas")
    prng = np.random.default_rng(4303)
    pitch = lerp(canvas * 0.18, wood_d * 0.35, 0.5)

    def fn(i, tag, g, c, nrm):
        if tag == "flame":
            return np.ones(3)
        if tag in ("rag",):
            k = prng.uniform()
            return lerp(pitch, canvas * 0.45, 0.35 if k > 0.7 else 0.08)
        if tag == "tail":
            return lerp(pitch, canvas * 0.55, prng.uniform(0.25, 0.5))
        if tag == "pitch":
            return pitch * prng.uniform(0.7, 1.0)
        if tag == "stick":
            col = wood if prng.uniform() > 0.45 else lerp(wood, wood_d, 0.7)
            top = float(np.clip((np.dot(c - C, d) - 10.0) / 10.0, 0.0, 1.0))
            return lerp(col, wood_d * 0.45, top)                               # scorched toward the head
        if tag == "rivet":
            return iron_col(nrm, prng) * 1.3
        return iron_col(nrm, prng)

    alpha = ep.vertex_alpha(obj, parts, open_tags=("flame",))
    ep.paint_parts(obj, parts, fn, variation=0.06, seed=4304, cavity_darken=0.35, alpha=alpha)
    ep.set_face_colours(obj, [t == "flame" for t in parts.tag], (1.0, 1.0, 1.0, 1.0))
    fc.smart_uv(obj)
    main_id = flames[0][4]
    ep.write_uv1(obj, CANDLE_UV, [parts.fid[i] if parts.tag[i] == "flame" else main_id for i in range(len(parts.tag))],
                 np.concatenate(parts.fh))
    ep.add_socket(obj, "Flame", mid)
    info = {"torch_tilt_deg": 14.0, "flame_ids": [f[4] for f in flames], "flame_heights_cm": [f[1] for f in flames],
            "flame_socket_cm": [round(float(x), 2) for x in mid * fc.UE_MIRROR]}
    return obj, parts, info


# ================================================================ wall lantern
def lantern_cage(parts, axis_xy, z_top, z_bot, half, post_h, band_h, rng, sides=4, phase=45.0, band_w=0.5,
                 band_inset=1.4, bar_h=0.25, bar_w=0.3):
    """Corner posts, top and bottom bands and a bar down the middle of each side, with >= 2.5 mm between the outer
    faces of posts, bands and bars so nothing z-fights where they cross."""
    cx, cy = axis_xy
    R = half / math.cos(math.pi / sides)                      # corner radius
    corners = []
    for k in range(sides):
        a = math.radians(phase + 360.0 * k / sides)
        corners.append(np.array([cx + R * math.cos(a), cy + R * math.sin(a)]))
    for c2 in corners:
        rd = _n(np.array([c2[0] - cx, c2[1] - cy, 0.0]))
        parts.add(bar([(c2[0], c2[1], z_top), (c2[0], c2[1], z_bot)], [rd, rd], post_h, post_h), "EnvIron", "post")
    for zb in (z_top - band_inset, z_bot + band_inset):
        for k in range(sides):
            a, b = corners[k], corners[(k + 1) % sides]
            mid = 0.5 * (a + b)
            nrm = _n(np.array([mid[0] - cx, mid[1] - cy, 0.0]))
            parts.add(bar([(a[0], a[1], zb), (b[0], b[1], zb)], [nrm, nrm], band_h, band_w), "EnvIron", "band")
    for k in range(sides):
        a, b = corners[k], corners[(k + 1) % sides]
        mid = 0.5 * (a + b)
        nrm = _n(np.array([mid[0] - cx, mid[1] - cy, 0.0]))
        p = np.array([mid[0], mid[1], 0.0]) - nrm * band_h
        parts.add(bar([(p[0], p[1], z_top - band_inset), (p[0], p[1], z_bot + band_inset)], [nrm, nrm], bar_h, bar_w),
                  "EnvIron", "bar")
    return corners


def build_wall_lantern():
    """Round 2: the cage is ~24 x 24 cm with a 36 cm body (ring to base point), 2.5 cm corner posts, the arm reaches
    45 cm; a 10 cm candle under a small rounded glow core (6 cm wide, EnvGlowWarm); the brace scroll rests against
    the back plate instead of curling free below it."""
    rng = np.random.default_rng(4401)
    parts = Parts(("EnvIron", "EnvGlowWarm", "EnvWax"))
    ch = 1.6
    hx, hz = 5.0, 13.0
    outline = np.array([(-hx + ch, hz), (hx - ch, hz), (hx, hz - ch), (hx, -hz + ch), (hx - ch, -hz),
                        (-hx + ch, -hz), (-hx, -hz + ch), (-hx, hz - ch)])
    parts.add(extrude_outline(outline, 0.0, -2.0, bevel=0.75, y_bevel=-1.3), "EnvIron", "plate")
    for x in (-2.8, 2.8):
        for zz in (9.6, -9.6):
            parts.add(rivet((x, -2.0, zz), -Y, rng, r=0.75, h=0.55), "EnvIron", "rivet")
    AX, AY = 0.0, -45.0
    ARM_Z, ARM_H = 6.0, 0.55
    HR = 2.0                                                  # the J hook's radius
    straight = np.array([(0.0, -1.4 - 38.6 * k / 12.0, ARM_Z) for k in range(13)])
    nrm = twisted_normals(straight, Z, 360.0)                 # a whole turn: the section meets the hook square again
    j_c = np.array([0.0, AY, -1.2])
    bend = [np.array([0.0, -41.6, 5.4]), np.array([0.0, -42.7, 3.9])]
    down = [np.array([0.0, AY + HR, z]) for z in (2.0, 0.0)]
    arc = [j_c + np.array([0.0, HR * math.cos(a), HR * math.sin(a)]) for a in np.radians(np.linspace(-15, -180, 7))]
    tail = [np.array([0.0, AY - HR, j_c[2] + 1.0])]
    hook = np.array(bend + down + arc + tail)
    pts = np.concatenate([straight, hook])
    hook_n = [np.cross(_n(pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]), X) for i in range(len(straight), len(pts))]
    nrm = np.concatenate([nrm, np.array(hook_n)])
    parts.add(bar(pts, nrm, ARM_H, ARM_H), "EnvIron", "arm")
    # brace: a scroll lying against the plate's front, sweeping out and up into the arm
    curl_c = np.array([0.0, -4.6, -6.8])
    curl = [curl_c + np.array([0.0, 2.5 * math.cos(a), 2.5 * math.sin(a)]) * (0.55 + 0.45 * k / 8.0)
            for k, a in enumerate(np.radians(np.linspace(-60.0, -330.0, 9)))]
    # it meets the arm rising at ~30 degrees, so no brace face lies parallel to an arm face
    sweep = bezier(curl[-1], curl[-1] + np.array([0.0, -7.0, 0.6]), (0.0, -22.0, 1.2), (0.0, -28.5, ARM_Z - 0.35), 8)[1:]
    brace = np.concatenate([[np.array([0.0, -1.6, -8.9])], np.array(curl), sweep])
    parts.add(bar(brace, [X] * len(brace), 0.26, 0.55), "EnvIron", "scroll")
    # the lantern's hanging ring through the J (ring in the XZ plane, its inside top resting on the hook bottom)
    hook_bottom = j_c[2] - HR - ARM_H
    RR, Rr = 2.0, 0.38
    zc = hook_bottom - (RR - Rr) + 0.12
    parts.add(hoop((AX, AY, zc), Y, RR, Rr, 0.45, 12), "EnvIron", "ring")
    ring_bot = zc - RR - Rr
    z_eave = ring_bot - 8.0
    roof = [(0.0, ring_bot + 0.45), (1.5, ring_bot), (1.3, ring_bot - 0.9), (3.4, ring_bot - 1.5), (21.0, z_eave),
            (21.0, z_eave - 1.1), (18.3, z_eave - 1.6), (0.0, z_eave - 1.6)]
    rv, rf = lathe(roof, 4, 45.0)
    parts.add((rv + np.array([AX, AY, 0.0]), rf), "EnvIron", "roof")
    z_top = z_eave - 0.9
    z_bot = z_top - 22.0
    lantern_cage(parts, (AX, AY), z_top, z_bot, 12.0, 1.25, 0.6, rng, band_w=0.8, band_inset=2.0, bar_h=0.35,
                 bar_w=0.4)
    base = [(0.0, z_bot + 0.5), (18.6, z_bot + 0.5), (18.6, z_bot - 1.5), (15.0, z_bot - 2.8), (6.0, z_bot - 3.4),
            (2.2, z_bot - 5.8), (0.0, z_bot - 7.2)]
    bv_, bf_ = lathe(base, 4, 45.0)
    parts.add((bv_ + np.array([AX, AY, 0.0]), bf_), "EnvIron", "base")
    # a 10 cm candle, its wick, and a small rounded glow core over it
    zb = z_bot + 0.3
    stub = [(0.0, zb), (2.5, zb), (2.55, zb + 8.4), (2.2, zb + 9.8), (0.0, zb + 10.0)]
    stv, stf = lathe(stub, 7, 0.0, jitter=0.06, rng=rng)
    parts.add((stv + np.array([AX, AY, 0.0]), stf), "EnvWax", "stub")
    parts.add(bar([(AX + 0.05, AY, zb + 9.6), (AX - 0.1, AY + 0.05, zb + 10.9)], [X, X], 0.18, 0.18), "EnvIron", "wick")
    z0 = zb + 10.5
    core = [(0.0, z0), (1.9, z0 + 0.6), (2.9, z0 + 1.8), (3.0, z0 + 3.0), (2.5, z0 + 4.7), (1.5, z0 + 6.3),
            (0.55, z0 + 7.6), (0.0, z0 + 8.1)]
    cv, cf = lathe(core, 8, 22.5, jitter=0.05, rng=rng)
    parts.add((cv + np.array([AX, AY, 0.0]), cf), "EnvGlowWarm", "core")
    obj = parts.build("WallLantern_A_Mars_SM")
    glow, wax = P("EnvGlowWarm"), P("EnvWax")
    prng = np.random.default_rng(4402)

    def fn(i, tag, g, c, nrm):
        if tag == "core":
            return glow * (1.0 + 0.12 * float(np.clip(nrm[2], 0.0, 1.0))) * prng.uniform(0.92, 1.0)
        if tag == "stub":
            return wax * prng.uniform(0.9, 1.0)
        if tag == "wick":
            return np.array([0.012, 0.010, 0.009])
        if tag == "rivet":
            return iron_col(nrm, prng) * 1.3
        return iron_col(nrm, prng)

    alpha = ep.vertex_alpha(obj, parts, open_tags=("core",))
    ep.paint_parts(obj, parts, fn, variation=0.03, seed=4403, cavity_darken=0.3, alpha=alpha)
    fc.smart_uv(obj)
    light = (AX, AY, z0 + 3.2)
    ep.add_socket(obj, "Light", light)
    info = {"arm_reach_cm": round(-AY + HR + ARM_H, 1), "lantern_axis_cm": [AX, -AY, 0.0],
            "cage_cm": [24.0, 24.0, round(zc + RR + Rr - (z_bot - 7.2), 1)],
            "light_socket_cm": [AX, -AY, round(light[2], 2)],
            "glow": "EnvGlowWarm core; the blue look is a material swap of that slot"}
    return obj, parts, info


# ================================================================ spirit lantern on a post
def build_spirit_lantern():
    rng = np.random.default_rng(4501)
    parts = Parts(("EnvIron", "EnvGlowSpirit"))
    # an octagonal flared foot (concept 2's cup base), a turned shaft, a collar under the head
    foot = [(0.0, 0.0), (21.0, 0.0), (21.0, 2.2), (19.4, 3.7), (14.0, 6.3), (9.6, 9.0), (7.3, 12.0), (6.4, 14.0),
            (0.0, 14.0)]
    bv_, bf_ = lathe(foot, 8, 22.5, jitter=0.15, rng=rng)
    bv_[bv_[:, 2] < 1e-6, 2] = 0.0
    parts.add((bv_, bf_), "EnvIron", "plinth")
    shaft = [(0.0, 13.5), (5.4, 13.5), (4.6, 15.5), (4.1, 34.0), (4.4, 46.5), (5.0, 49.6), (9.4, 53.4), (9.9, 55.4),
             (0.0, 55.4)]
    sv, sf = lathe(shaft, 8, 22.5, jitter=0.08, rng=rng)
    parts.add((sv, sf), "EnvIron", "shaft")
    parts.add(lathe_closed([(4.0, 45.6), (7.6, 45.6), (8.1, 46.9), (7.6, 48.2), (4.0, 48.2)], 8, 0.0), "EnvIron",
              "collar")
    for zc_, rr_ in ((22.0, 4.25), (38.0, 4.3)):
        parts.add(lathe_closed([(3.6, zc_ - 0.8), (rr_ + 0.9, zc_ - 0.8), (rr_ + 0.9, zc_ + 0.8), (3.6, zc_ + 0.8)], 8,
                               22.5), "EnvIron", "collar")
    plate = [(0.0, 55.0), (10.6, 55.0), (10.6, 56.5), (9.4, 57.3), (0.0, 57.3)]
    pv, pf = lathe(plate, 6, 0.0)
    parts.add((pv, pf), "EnvIron", "plate")
    # an iron dish the spirit flame visibly rests in
    dish = [(0.0, 56.8), (1.6, 56.8), (1.8, 57.6), (4.0, 58.6), (4.3, 59.7), (3.6, 59.9), (1.5, 59.0), (0.0, 59.0)]
    uv_, uf_ = lathe(dish, 8, 0.0)
    parts.add((uv_, uf_), "EnvIron", "dish")
    # hexagonal cage (posts at the corners, bands along the edges)
    R = 8.6
    corners = [np.array([R * math.cos(math.radians(60.0 * k)), R * math.sin(math.radians(60.0 * k))]) for k in range(6)]
    for c2 in corners:
        rd = _n(np.array([c2[0], c2[1], 0.0]))
        parts.add(bar([(c2[0], c2[1], 56.6), (c2[0], c2[1], 78.6)], [rd, rd], 0.6, 0.6), "EnvIron", "post")
    for zb in (58.6, 76.6):
        for k in range(6):
            a, b = corners[k], corners[(k + 1) % 6]
            mid = 0.5 * (a + b)
            nrm = _n(np.array([mid[0], mid[1], 0.0]))
            parts.add(bar([(a[0], a[1], zb), (b[0], b[1], zb)], [nrm, nrm], 0.32, 0.55), "EnvIron", "band")
    # a pointed arch of bars on every side (the gothic tracery of concept 2), set inside the bands
    for k in range(6):
        a, b = corners[k], corners[(k + 1) % 6]
        mid = 0.5 * (a + b)
        nrm = _n(np.array([mid[0], mid[1], 0.0]))
        tang = _n(np.array([b[0] - a[0], b[1] - a[1], 0.0]))
        inset = np.array([mid[0], mid[1], 0.0]) - nrm * 0.45      # its outer face sinks into the bands
        arch = [inset + tang * 2.6 * math.cos(t) + Z * (70.0 + 4.6 * math.sin(t)) for t in np.linspace(0.0, math.pi, 7)]
        arch = [inset + tang * 2.6 + Z * 58.8] + arch + [inset - tang * 2.6 + Z * 58.8]
        parts.add(bar(arch, [nrm] * len(arch), 0.22, 0.26), "EnvIron", "tracery")
    # a blue flame: the wall lantern's teardrop x1.4 (widest r 4.2 at 30 % of 12.6 cm), standing in a small iron cup
    core = [(0.0, 58.7), (2.2, 59.5), (3.6, 60.9), (3.9, 62.3), (3.4, 64.3), (2.4, 66.5), (1.2, 68.5), (0.0, 70.4)]
    cv, cf = lathe(core, 6, 30.0, jitter=0.06, rng=rng)
    parts.add((cv, cf), "EnvGlowSpirit", "core")
    roof = [(0.0, 77.9), (11.6, 77.9), (12.8, 79.2), (12.0, 80.1), (7.2, 84.4), (3.1, 89.2), (1.6, 91.2), (0.0, 91.6)]
    rv, rf = lathe(roof, 6, 0.0)
    parts.add((rv, rf), "EnvIron", "roof")
    fin = [(0.0, 91.0), (1.6, 91.6), (2.2, 93.2), (1.6, 94.8), (0.7, 95.4), (0.55, 97.6), (0.0, 100.0)]
    fv, ff = lathe(fin, 6, 30.0)
    parts.add((fv, ff), "EnvIron", "finial")
    obj = parts.build("SpiritLantern_Post_Mars_SM")
    iron, iron_l, glow = P("EnvIron"), P("EnvIronLight"), P("EnvGlowSpirit")
    prng = np.random.default_rng(4502)

    def fn(i, tag, g, c, nrm):
        if tag == "core":
            return glow * (1.0 + 0.15 * float(np.clip(nrm[2], 0.0, 1.0))) * prng.uniform(0.92, 1.0)
        return iron_col(nrm, prng, lift_dir=(0.0, 0.0, 1.0)) * (1.1 if tag in ("collar", "dish") else 1.0)

    alpha = ep.vertex_alpha(obj, parts, open_tags=("core",))
    ep.paint_parts(obj, parts, fn, variation=0.03, seed=4503, cavity_darken=0.3, alpha=alpha)
    fc.smart_uv(obj)
    ep.add_socket(obj, "Light", (0.0, 0.0, 63.0))
    info = {"height_cm": 100.0, "foot_cm": 42.0, "light_socket_cm": [0.0, 0.0, 63.0]}
    return obj, parts, info


# ================================================================ brazier
RIM = 84.0
BOWL = [(0.0, 72.0), (14.0, 72.4), (22.0, 74.6), (27.4, 79.0), (29.4, 82.6), (30.0, RIM), (32.4, RIM), (33.4, 83.0),
        (32.6, 81.8), (30.8, 81.2), (29.6, 77.0), (25.6, 71.0), (18.0, 67.0), (9.0, 65.6), (0.0, 65.4)]
BOWL_TAGS = ["bowl_in"] * 5 + ["rim"] * 3 + ["lip"] * 2 + ["bowl_out"] * 4
# the coal bed: a dome hidden under the heap (it only shows as dark ember in the gaps between the lumps)
MOUND = [(0.0, 89.0), (8.0, 88.0), (15.0, 85.0), (21.0, 80.4), (25.6, 78.0), (24.0, 74.6), (14.0, 72.2), (0.0, 71.8)]


FOOT_PAD_H = 2.4                      # the foot pad's top
SCROLL_HN = 0.55                      # the foot scroll's half thickness (radial-vertical plane)
FOOT_Z0 = FOOT_PAD_H + SCROLL_HN - 0.2  # the scroll's centre line where it lies on the pad (sunk 2 mm into it)
FOOT_R = 36.0                         # radial position of the scroll's centre
SCROLL_R = 3.9                        # the scroll's outer radius (1.3x round 1)


def bed_h(x, y, segments=10, phase_deg=9.0):
    """Height of the lathed (polygonal) bed at (x, y): a point between two spokes lies on the chord of a smaller ring."""
    r = math.hypot(x, y)
    th = math.atan2(y, x) - math.radians(phase_deg)
    sector = TAU / segments
    off = (th % sector) - 0.5 * sector
    return mound_h(r * math.cos(off) / math.cos(0.5 * sector))


def mound_h(r):
    top = MOUND[:4]
    return float(np.interp(r, [p[0] for p in top], [p[1] for p in top]))


SOFT_RINGS = ((0.12, 0.8), (0.33, 1.0), (0.66, 0.64))      # a fuller teardrop: widest low, a soft shoulder


def coal_chunk(center, size, rng):
    """A chunky, irregular faceted coal: the convex hull of 11 jittered points on an ellipsoid (~18 triangles, big
    uneven planes, never a regular icosahedron), turned at random."""
    k = np.arange(11) + 0.5
    phi = np.arccos(1.0 - 2.0 * k / 11.0)
    th = math.pi * (1.0 + 5 ** 0.5) * k
    d = np.column_stack([np.sin(phi) * np.cos(th), np.sin(phi) * np.sin(th), np.cos(phi)])
    d = d + rng.uniform(-0.28, 0.28, d.shape)
    d = d / np.linalg.norm(d, axis=1, keepdims=True) * rng.uniform(0.78, 1.0, (11, 1))
    v, f = ep.hull(d * (np.asarray(size, float) * 0.5), dissolve_deg=4.0)
    return rot_z(v, rng.uniform(0, 360)) + np.asarray(center, float), f


def build_brazier():
    """Round 2: chunky legs (~4 cm, tapering into the feet), a 3 cm stretcher ring, 1.3x foot scrolls; 21 chunky
    6-10 cm coals heaped into a dome ~8 cm over the rim (the bed only shows between them); FOUR fire tongues with
    12-17 cm wide bases that overlap in one root mass, leaning out 18-22 degrees with the tips curling back, the
    tallest tip ~30 cm over the rim (~114 cm overall)."""
    rng = np.random.default_rng(4601)
    parts = Parts(("EnvIron", "EnvGlowWarm", "EnvFlame"))
    seg = 14
    v, f = lathe(BOWL, seg, 0.0, jitter=0.16, rng=rng)
    parts.add((v, f), "EnvIron", [BOWL_TAGS[min(i // seg, len(BOWL_TAGS) - 1)] for i in range(len(f))])

    def wall_r(z):
        return 25.6 + (z - 71.0) * (4.0 / 6.0)
    band = [(wall_r(72.6) - 0.4, 72.6), (wall_r(72.6) + 0.75, 72.6), (wall_r(75.8) + 0.75, 75.8),
            (wall_r(75.8) - 0.4, 75.8)]
    parts.add(lathe_closed(band, seg, 360.0 / seg * 0.5), "EnvIron", "band")
    nrm_wall = _n(np.array([6.0, -4.0]))
    for k in range(12):
        a = math.radians(30.0 * k + 15.0)
        dr = np.array([math.cos(a), math.sin(a), 0.0])
        zc = 74.2
        p = dr * (wall_r(zc) + 0.75) + np.array([0.0, 0.0, zc])
        parts.add(rivet(p, dr * nrm_wall[0] + Z * nrm_wall[1], rng, r=0.7, h=0.5), "EnvIron", "rivet")
    # three chunky scrolled legs (~4 cm at the bowl, 2.2 cm at the foot), a 3 cm stretcher ring and foot pads
    for k in range(3):
        a = math.radians(90.0 + 120.0 * k)
        dr = np.array([math.cos(a), math.sin(a), 0.0])
        tg = np.array([-math.sin(a), math.cos(a), 0.0])
        rz1 = bezier((19.0, 67.6), (28.0, 60.0), (34.0, 40.0), (30.5, 22.0), 7)
        rz2 = bezier((30.5, 22.0), (28.75, 13.0), (29.8, FOOT_Z0), (FOOT_R, FOOT_Z0), 6)[1:]
        rz = np.concatenate([rz1, rz2])
        pts = np.array([dr * r + Z * z for r, z in rz])
        nr = [np.cross(tg, _n(pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)])) for i in range(len(pts))]
        taper = np.linspace(0.0, 1.0, len(pts))
        parts.add(bar(pts, nr, 2.0 - 1.1 * taper, 2.0 - 1.0 * taper), "EnvIron", "leg")
        # the leg runs out along the pad and rolls up into a flat 1.5-turn scroll standing on the pad
        sp = []
        for q in range(28):
            t = q / 27.0
            ang = -0.5 * math.pi + t * 3.0 * math.pi
            rad = SCROLL_R * (1.0 - 0.66 * t)
            sp.append((FOOT_R + rad * math.cos(ang), FOOT_Z0 + SCROLL_R + rad * math.sin(ang)))
        foot = np.array([dr * r + Z * z for r, z in sp])
        nr2 = [np.cross(tg, _n(foot[min(i + 1, len(foot) - 1)] - foot[max(i - 1, 0)])) for i in range(len(foot))]
        parts.add(bar(foot, nr2, SCROLL_HN, 0.8), "EnvIron", "scroll")
        pv, pf = chamfer_box(dr * (FOOT_R + 0.6) + Z * (FOOT_PAD_H * 0.5), (11.5, 6.0, FOOT_PAD_H), 0.5,
                             yaw_deg=math.degrees(a))
        pv[pv[:, 2] < 0.5, 2] = 0.0
        parts.add((pv, pf), "EnvIron", "foot")
    parts.add(hoop((0.0, 0.0, 22.0), Z, 30.5, 1.5, 1.5, 15, 12.0), "EnvIron", "stretcher")
    # the coal bed (hidden) and the heap: three rings of chunky icosahedral coals stacked into a dome
    mv, mf = lathe(MOUND, 10, 9.0)
    ring_of = np.repeat(np.arange(len(MOUND)), [1 if p[0] < 1e-6 else 10 for p in MOUND])
    m = (ring_of >= 1) & (ring_of <= 3)
    mv[m, 2] += rng.uniform(-0.3, 0.3, int(m.sum()))
    parts.add((mv, mf), "EnvGlowWarm", "bed")
    placed = []
    for ring_r, count, (s0, s1), lift, phase in ((21.2, 12, (11.0, 12.6), 0.0, 0.0), (12.4, 7, (11.0, 12.8), 2.6, 17.0),
                                                 (4.3, 3, (10.0, 11.5), 4.8, 40.0)):
        for q in range(count):
            ang = math.radians(phase + 360.0 * q / count + rng.uniform(-9.0, 9.0))
            r = ring_r + rng.uniform(-1.2, 1.2)
            sx = rng.uniform(s0, s1)
            size = np.array([sx, sx * rng.uniform(0.78, 0.95), sx * rng.uniform(0.5, 0.62)])     # flat chunks, 6-8 cm high
            cpos = np.array([r * math.cos(ang), r * math.sin(ang), mound_h(r) + size[2] * 0.2 + lift])
            lv, lf = coal_chunk(cpos, size, rng)
            over = np.hypot(lv[:, 0], lv[:, 1]).max() - 27.2
            if over > 0.0:                                             # keep it inside the bowl wall
                lv[:, :2] -= np.array([math.cos(ang), math.sin(ang)]) * over
            # drop it onto the heap: the support under each corner is the bed or the dome of a coal already placed
            # (the lathed bed sags between its spokes); it sinks 1 cm into whatever it lands on
            def support(x, y):
                h = bed_h(x, y)
                for (qc, qr, qh, qt) in (placed if lift > 0.0 else ()):
                    d = math.hypot(x - qc[0], y - qc[1]) / qr
                    if d < 1.0:
                        h = max(h, qt - qh * (1.0 - math.sqrt(1.0 - d * d)))
                return h
            gap = min(lv[q, 2] - support(lv[q, 0], lv[q, 1]) for q in range(len(lv)))
            lv[:, 2] -= gap + (1.5 if lift > 0.0 else 0.8)
            top = float(lv[:, 2].max())
            placed.append((lv[:, :2].mean(axis=0), 0.36 * sx, 0.5 * (top - lv[:, 2].min()), top))
            parts.add((lv, lf), "EnvGlowWarm", "coal")
    # four soft tongues: a tall centre one and three leaning out, their wide bases overlapping in the middle
    frng = np.random.default_rng(4602)
    flames = [((0.0, 0.0), 26.0, 17.0, (0.3, -1.0), 8.0, 0.5, 0.211)]
    for k, (h, wd, bend, fid) in enumerate(((21.0, 14.0, 24.0, 0.433), (18.0, 13.0, 22.0, 0.652),
                                            (15.0, 12.0, 20.0, 0.874))):
        a = math.radians(-30.0 + 120.0 * k)
        flames.append(((6.0 * math.cos(a), 6.0 * math.sin(a)), h, wd, (math.cos(a), math.sin(a)), bend, 0.85, fid))
    for (fx, fy), h, wd, lean, bend, curl, fid in flames:
        base = np.array([fx, fy, mound_h(math.hypot(fx, fy)) - 1.0])
        fv, ft, fh = tongue(base, h, wd, frng, lean=lean, bend_deg=bend, curl=curl, rings=SOFT_RINGS)
        parts.add((fv, ft), "EnvFlame", "flame", fid=fid, fh=fh)
    obj = parts.build("Brazier_A_Mars_SM")
    glow = P("EnvGlowWarm")
    hot = glow
    ember = fc.srgb(214, 74, 22)
    char = fc.srgb(30, 24, 22)
    prng = np.random.default_rng(4603)
    tone = {g: prng.uniform(0.0, 1.0) for g in set(parts.group)}

    def fn(i, tag, g, c, nrm):
        if tag == "flame":
            return np.ones(3)
        if tag == "coal":
            k = tone[g]
            if k < 0.3:
                col = lerp(char, ember, 0.25 + k / 0.3 * 0.4)
            elif k < 0.75:
                col = lerp(ember, hot, (k - 0.3) / 0.45 * 0.7)
            else:
                col = hot
            up = float(np.clip(nrm[2], 0.0, 1.0))
            return col * (0.6 + 0.45 * up) * prng.uniform(0.88, 1.08)
        if tag == "bed":
            return lerp(ember * 0.35, char, 0.5) * prng.uniform(0.8, 1.1)
        if tag == "bowl_in":
            heat = float(np.clip((82.0 - c[2]) / 8.0, 0.0, 1.0))
            return lerp(iron_col(nrm, prng) * 0.75, char, 0.4 * heat)
        if tag in ("rim", "lip", "rivet"):
            return iron_col(nrm, prng, lift_dir=(0.0, 0.0, 1.0)) * 1.25
        return iron_col(nrm, prng, lift_dir=(0.0, 0.0, 1.0))

    alpha = ep.vertex_alpha(obj, parts, open_tags=("flame", "coal"))
    ep.paint_parts(obj, parts, fn, variation=0.03, seed=4604, cavity_darken=0.3, alpha=alpha)
    ep.set_face_colours(obj, [t == "flame" for t in parts.tag], (1.0, 1.0, 1.0, 1.0))
    fc.smart_uv(obj)
    main_id = flames[0][6]
    ep.write_uv1(obj, CANDLE_UV, [parts.fid[i] if parts.tag[i] == "flame" else main_id for i in range(len(parts.tag))],
                 np.concatenate(parts.fh))
    sock = (0.0, 0.0, mound_h(0.0) + 12.0)
    ep.add_socket(obj, "Fire", sock)
    info = {"rim_height_cm": RIM, "bowl_diameter_cm": 2 * 33.4, "coals": len(placed),
            "coal_dome_over_rim_cm": round(max(p_[3] for p_ in placed) - RIM, 1),
            "fire_top_over_rim_cm": round(max(float(vv[:, 2].max()) for vv in parts.v) - RIM, 1),
            "flame_ids": [f[6] for f in flames], "flame_heights_cm": [f[1] for f in flames],
            "fire_socket_cm": list(sock)}
    return obj, parts, info


# ================================================================ candle ledges (prism candles + surface-nets spill)
def sd_ledge(y, z):
    """Signed distance to the ledge solid {y > 0, z < 0} (negative inside)."""
    qy, qz = -y, z
    return np.sqrt(np.maximum(qy, 0.0) ** 2 + np.maximum(qz, 0.0) ** 2) + np.minimum(np.maximum(qy, qz), 0.0)


class Spill:
    """Wax that ran from one candle's pool to the edge: a runner on the top, a thick rolled lip over the edge (~2 cm
    proud, the full spill width), a short sheet on the face and a few short, fat drips, each narrowing to a neck and
    ending in a rounded bead (concepts 1 and 6)."""

    def __init__(self, owner, c, hw, sheet, drips):
        self.owner = owner
        self.xm, self.y_from, self.hw = c.x, c.y, hw
        self.sheet = sheet
        self.drips = drips              # (x, length, neck radius, bead radius, sway)

    def sdf(self, x, y, z):
        y_hi = self.y_from
        runner = ep.sd_round_box(x, y, z, (self.xm, 0.5 * (y_hi - 0.5), 0.0), (self.hw, 0.5 * (y_hi + 0.5), 0.75), 0.5)
        lip = ep.sd_capsule(x, y, z, (self.xm - self.hw, -0.75, -0.7), (self.xm + self.hw, -0.75, -0.7), 1.25, 1.25,
                            squash_y=1.05)
        d = cg._smin(runner, lip, 1.0)
        sh = ep.sd_round_box(x, y, z, (self.xm, -0.25, 0.5 * (0.3 - self.sheet)),
                             (self.hw * 0.9, 0.85, 0.5 * (0.3 + self.sheet)), 0.6)
        d = cg._smin(d, sh, 1.0)
        for xd, length, rn, rb, sway in self.drips:
            end = np.array([xd + sway, -0.5, -length + rb])
            neck = ep.sd_capsule(x, y, z, (xd, -0.55, -1.0), end, rn * 1.3, rn, power=0.7, squash_y=1.3)
            bead = ep.sd_capsule(x, y, z, end, end + np.array([0.0, 0.0, -0.15]), rb, rb, squash_y=1.25)
            d = cg._smin(d, cg._smin(neck, bead, 0.6), 0.9)
        return d

    def reach(self):
        return max(l for _, l, *_ in self.drips) if self.drips else self.sheet


class LCandle:
    """One ledge candle (cm, Blender axes): an n-sided hand-cut prism with a sagging, dished top."""

    def __init__(self, index, x, y, r, h, cid, colour):
        self.index, self.x, self.y, self.radius, self.height, self.id, self.color = index, x, y, r, h, cid, colour
        self.spill = (0.0, -1.0)


CANDLE_FOOT_Z = 0.4          # the prisms stand 4 mm up, inside their wax pool (no face coplanar with the pool's floor)


def candle_prism(c, rng):
    """Round 2: a 7/8-sided prism (jittered radius per corner, a slumped foot ring, the rim sagging toward the spill
    side), a raised rim lip and a dished top round the wick: ~12 n triangles. Returns verts, faces, tags, columns
    (the body rings, for laying drip ribbons on its facets) and the dish floor height."""
    n = 8 if c.radius >= 3.0 else 7
    H, r = c.height, c.radius
    phase = rng.uniform(0.0, TAU / n)
    angs = phase + TAU * np.arange(n) / n + rng.uniform(-0.1, 0.1, n)
    sp_ang = math.atan2(c.spill[1], c.spill[0])
    sag = min(0.12 * H, 1.6) * rng.uniform(0.7, 1.0)
    rim = np.array([H - sag * smoothstep(-0.2, 1.0, math.cos(a - sp_ang)) ** 1.4 - rng.uniform(0.0, 0.3) for a in angs])
    jit = rng.uniform(-0.07, 0.07, n)
    rings = []
    for z, k in ((CANDLE_FOOT_Z, 1.06), (CANDLE_FOOT_Z + 0.3 * (H - CANDLE_FOOT_Z), 1.0),
                 (CANDLE_FOOT_Z + 0.7 * (H - CANDLE_FOOT_Z), 0.99)):
        rr = r * k * (1.0 + jit + rng.uniform(-0.025, 0.025, n))
        rings.append(np.column_stack([c.x + rr * np.cos(angs), c.y + rr * np.sin(angs), np.full(n, z)]))
    rr = r * 0.97 * (1.0 + jit)
    rings.append(np.column_stack([c.x + rr * np.cos(angs), c.y + rr * np.sin(angs), rim]))
    rl = r * 0.8 * (1.0 + jit)
    rings.append(np.column_stack([c.x + rl * np.cos(angs), c.y + rl * np.sin(angs), rim + 0.18]))
    dish = float(rim.min()) - 0.55
    rd = r * 0.48
    a2 = angs + rng.uniform(-0.15, 0.15, n)
    rings.append(np.column_stack([c.x + rd * np.cos(a2), c.y + rd * np.sin(a2), np.full(n, dish) +
                                  rng.uniform(-0.1, 0.1, n)]))
    verts = np.concatenate(rings + [np.array([[c.x, c.y, dish - 0.35]])])
    faces, tags = [], []
    for i in range(len(rings) - 1):
        a, b = i * n, (i + 1) * n
        for s in range(n):
            s2 = (s + 1) % n
            faces.append([a + s, a + s2, b + s2, b + s])
            tags.append("body" if i < 3 else ("top" if i == 3 else "dish"))
    pole = len(verts) - 1
    last = (len(rings) - 1) * n
    for s in range(n):
        faces.append([last + s, last + (s + 1) % n, pole])
        tags.append("dish")
    faces.append(list(range(n - 1, -1, -1)))
    tags.append("bottom")
    return verts, faces, tags, rings[:4], dish


def drip_ribbon(c, cols, k, s, length, rng):
    """A drip of wax run down facet k (between corner columns k and k+1) as a triangular-section strip: its base sunk
    3.5 mm into the candle, its ridge 3-8 mm proud, widening into a bead at the bottom. ~20 triangles."""
    n = len(cols[0])
    k2 = (k + 1) % n

    def surf(z):
        out = []
        for col in (k, k2):
            zz = np.array([ring[col, 2] for ring in cols])
            pp = np.array([ring[col] for ring in cols])
            i = int(np.clip(np.searchsorted(zz, z) - 1, 0, len(zz) - 2))
            t = float(np.clip((z - zz[i]) / max(zz[i + 1] - zz[i], 1e-6), 0.0, 1.0))
            out.append(lerp(pp[i], pp[i + 1], t))
        return lerp(out[0], out[1], s), out[1] - out[0]

    z_top = min(cols[3][k, 2], cols[3][k2, 2]) - 0.25
    z_end = max(z_top - length, CANDLE_FOOT_Z + 1.0)
    rings = []
    for q, z in enumerate(np.linspace(z_top, z_end, 4)):
        p, edge = surf(z)
        nrm = _n(np.array([p[0] - c.x, p[1] - c.y, 0.0]))
        tg = _n(edge - np.dot(edge, nrm) * nrm)
        f = q / 3.0
        hw = 0.45 + 0.3 * f ** 2 + rng.uniform(-0.05, 0.05)
        bulge = 0.35 + 0.45 * f ** 2
        rings.append(np.array([p - nrm * 0.35 - tg * hw, p - nrm * 0.35 + tg * hw, p + nrm * bulge]))
    return fc.loft(rings)


def ledge_spill_field(candles, spills):
    pools = []
    for c in candles:
        pr = c.radius * 1.35 + 1.0
        ph = 0.9 + 0.08 * c.radius
        ox, oy = c.x + 0.25 * c.radius * c.spill[0], c.y + 0.25 * c.radius * c.spill[1]
        pools.append((ox, oy, pr, ph))

    def wax(x, y, z):
        d = None
        for ox, oy, pr, ph in pools:
            e = ep.sd_ellipsoid(x - ox, y - oy, z, pr, pr * 0.92, ph)
            d = e if d is None else cg._smin(d, e, 1.2)
        for s in spills:
            d = cg._smin(d, s.sdf(x, y, z), 1.1)
        return d

    def at(x, y, z):
        return np.maximum(wax(x, y, z), -sd_ledge(y, z))
    return at, wax, pools


def build_candle_ledge(name, layout, spill_cfg, spill_tris, seed):
    """Round 2: every candle is a hand-cut prism with 2-3 drip ribbons (big planes, ~200 triangles with its wick and
    flame); the surface-nets field (decimated to ~spill_tris) only makes the wax pools round the feet, the runners to
    the edge, the rolled lip over the edge and the drips down the face. layout: (x, y, radius, height) per candle,
    spill_cfg: candle index -> dict(hw, sheet, drips=((x fraction of hw, length), ...))."""
    rng = np.random.default_rng(seed)
    pal = cg.PALETTES["cream"]
    w_ = np.array([t[0] for t in pal])
    ids = rng.permutation((np.arange(len(layout)) + rng.uniform(0.2, 0.8, len(layout))) / len(layout))
    candles = []
    for i, (x, y, r, h) in enumerate(layout):
        col = np.array(fc.srgb(*pal[rng.choice(len(pal), p=w_ / w_.sum())][1])) * rng.uniform(0.95, 1.04)
        c = LCandle(i, x, y, r, h, float(ids[i]), np.clip(col, 0.0, 1.0))
        a = -math.pi / 2.0 + rng.uniform(-0.45, 0.45)
        c.spill = (math.cos(a), math.sin(a))
        candles.append(c)
    spills = []
    for i, cfg in spill_cfg.items():
        c = candles[i]
        cap = min(18.0, 0.9 * c.height)                 # a drip never runs further than its candle is tall
        drips = []
        for (fx, length) in cfg["drips"]:
            rn = rng.uniform(0.9, 1.1)
            drips.append((c.x + fx * cfg["hw"], min(length, cap), rn, rn * rng.uniform(1.3, 1.6),
                          rng.uniform(-0.35, 0.35)))
        spills.append(Spill(i, c, cfg["hw"], min(cfg["sheet"], 0.6 * cap), drips))
    field, wax, pools = ledge_spill_field(candles, spills)
    voxel = 0.4
    lo = np.array([min(min(p[0] - p[2] for p in pools), min(s.xm - s.hw for s in spills)) - 3.0, -4.2,
                   -max(s.reach() for s in spills) - 3.0])
    hi = np.array([max(max(p[0] + p[2] for p in pools), max(s.xm + s.hw for s in spills)) + 3.0,
                   max(p[1] + p[2] for p in pools) + 2.0, 4.0])
    vals, origin = ep.sample_grid(field, lo, hi, voxel)
    hv, ht, full = ep.sdf_to_mesh(vals, origin, voxel, spill_tris)
    eps = 0.3 * voxel
    v = hv.copy()
    top = (np.abs(v[:, 2]) < eps) & (v[:, 1] > -eps)
    v[top, 2] = 0.0
    face = (np.abs(v[:, 1]) < eps) & (v[:, 2] < eps)
    v[face, 1] = 0.0
    inside = (v[:, 1] > 0.0) & (v[:, 2] < 0.0)
    to_top = inside & (-v[:, 2] <= v[:, 1])
    v[to_top, 2] = 0.0
    v[inside & ~to_top, 1] = 0.0
    sv, st = ep.clean_closed(v, ht)
    parts = Parts(("EnvWax", "EnvIron", "EnvFlame"))

    def glow_of(c, pts):
        below = (c.rim_min - pts[:, 2])
        side = np.hypot(pts[:, 0] - c.x, pts[:, 1] - c.y) - c.radius
        return (1.0 - smoothstep(0.0, cg.GLOW_FALLOFF_CM, below)) * \
            (1.0 - smoothstep(cg.GLOW_RADIAL_CM[0], cg.GLOW_RADIAL_CM[1], side))

    flame_mid = []
    frng = np.random.default_rng(seed + 3)
    for c in candles:
        crng = np.random.default_rng(seed * 31 + c.index)
        cv_, cf_, ctags, cols, dish = candle_prism(c, crng)
        c.rim_min = float(cols[3][:, 2].min())
        c.dish = dish
        parts.add((cv_, cf_), "EnvWax", ctags, fid=c.id, fh=glow_of(c, cv_))
        n = len(cols[0])
        sp_ang = math.atan2(c.spill[1], c.spill[0])
        facet_ang = [math.atan2(*(0.5 * (cols[3][k, :2] + cols[3][(k + 1) % n, :2]) - (c.x, c.y))[::-1])
                     for k in range(n)]
        front = int(np.argmax([math.cos(a - sp_ang) for a in facet_ang]))
        picks = [front, (front + int(crng.integers(2, n - 1))) % n]
        if c.height > 12.0:
            third = (front + n // 2 + int(crng.integers(-1, 2))) % n
            if third not in picks:
                picks.append(third)
        for q, k in enumerate(picks):
            L = c.height * crng.uniform(0.35, 0.75) if q else c.height * crng.uniform(0.55, 0.85)
            rv_, rf_ = drip_ribbon(c, cols, k, crng.uniform(0.3, 0.7), L, crng)
            parts.add((rv_, rf_), "EnvWax", "drip", fid=c.id, fh=glow_of(c, rv_))
        # wick + flame (candle_gen's contract: u = the candle's id, v = height along the flame)
        wx, wy = c.x + crng.uniform(-0.15, 0.15), c.y + crng.uniform(-0.15, 0.15)
        tip = np.array([wx + crng.uniform(-0.15, 0.15), wy + crng.uniform(-0.15, 0.15), dish + 1.25])
        wv, wf = bar([(c.x, c.y, dish - 0.5), (wx, wy, dish + 0.6), tip], [X, X, X], 0.16, 0.16)
        parts.add((wv, wf), "EnvIron", "wick", fid=c.id)
        girth = float(np.clip((c.radius - 1.2) / 3.3, 0.0, 1.0))
        fh_, fw_ = 4.4 + 2.0 * girth + frng.uniform(-0.3, 0.3), 1.9 + 0.6 * girth
        base = tip - np.array([0.0, 0.0, 0.3])
        fv, ft, fhv = tongue(base, fh_, fw_, frng, lean=(frng.uniform(-1, 1), frng.uniform(-1, 1)), bend_deg=6.0,
                             curl=0.6)
        parts.add((fv, ft), "EnvFlame", "flame", fid=c.id, fh=fhv)
        flame_mid.append(base + np.array([0.0, 0.0, 0.45 * fh_]))
    # the spill shell: each face owned by the nearest candle (u), glow v from that candle
    scen = sv[st].mean(axis=1)
    dist = np.stack([np.hypot(scen[:, 0] - c.x, scen[:, 1] - c.y) - c.radius for c in candles])
    s_owner = np.argmin(dist, axis=0)
    vd = np.stack([np.hypot(sv[:, 0] - c.x, sv[:, 1] - c.y) - c.radius for c in candles])
    v_owner = np.argmin(vd, axis=0)
    sglow = np.zeros(len(sv))
    for k, c in enumerate(candles):
        m = v_owner == k
        sglow[m] = glow_of(c, sv[m])
    parts.add((sv, st.tolist()), "EnvWax", "spill", fid=[candles[k].id for k in s_owner], fh=sglow)
    # x centre the piece on its bounding box (the edge stays at y = 0, z = 0)
    allv = parts.verts()
    xshift = 0.5 * (allv[:, 0].min() + allv[:, 0].max())
    parts.v = [vv - np.array([xshift, 0.0, 0.0]) for vv in parts.v]
    for c in candles:
        c.x -= xshift
    flame_mid = [m - np.array([xshift, 0.0, 0.0]) for m in flame_mid]
    owner_of = {c.id: c for c in candles}
    obj = parts.build(name + "_Mars_SM")
    prng = np.random.default_rng(seed + 9)
    warm = np.array([1.0, 0.95, 0.84])

    def fn(i, tag, g, cc, nrm):
        if tag == "flame":
            return np.ones(3)
        if tag == "wick":
            return np.array([0.012, 0.010, 0.009])
        base = owner_of[parts.fid[i]].color
        if tag == "body":
            return base * prng.uniform(0.88, 1.04)
        if tag == "top":
            return base * warm * prng.uniform(0.92, 1.02)
        if tag == "dish":
            return base * warm * 0.78 * prng.uniform(0.95, 1.03)
        if tag == "drip":
            return base * 1.04 * prng.uniform(0.97, 1.03)
        if tag == "spill":
            up = float(np.clip(nrm[2], 0.0, 1.0))
            return base * (0.86 + 0.14 * up) * prng.uniform(0.95, 1.04)
        return base * 0.8

    alpha = ep.vertex_alpha(obj, parts, open_tags=("flame", "wick"))
    ep.paint_parts(obj, parts, fn, variation=0.02, seed=seed + 7, cavity_darken=0.3, alpha=alpha)
    slot = np.array(parts.slot)
    ep.set_face_colours(obj, slot == 2, (1.0, 1.0, 1.0, 1.0))
    ep.set_face_colours(obj, slot == 1, (0.012, 0.010, 0.009, 1.0))
    fc.smart_uv(obj)
    ep.write_uv1(obj, CANDLE_UV, parts.fid, np.concatenate(parts.fh))
    for c, mid in zip(candles, flame_mid):
        ep.add_socket(obj, "Flame_%02d" % c.index, mid)
    v_now = fc.verts_cm(obj)
    lo_, hi_ = v_now.min(axis=0), v_now.max(axis=0)
    table = [{"index": c.index, "id": round(c.id, 6), "radius_cm": round(c.radius, 2), "height_cm": round(c.height, 2),
              "base_cm": [round(float(c.x), 2), round(float(-c.y), 2), 0.0], "wax_top_cm": round(c.dish, 2),
              "flame_socket": "Flame_%02d" % c.index,
              "flame_center_cm": [round(float(x), 3) for x in mid * fc.UE_MIRROR]} for c, mid in zip(candles, flame_mid)]
    spill_n = int(len(st))
    info = {"candles": table, "surface_nets_tris": int(full), "spill_tris": spill_n, "voxel_cm": voxel,
            "drip_reach_cm": round(float(-lo_[2]), 2), "overhang_cm": round(float(-lo_[1]), 2),
            "span_x_cm": round(float(hi_[0] - lo_[0]), 1),
            "glow": "CandleData.v on EnvWax = candle_gen glow (1 at the rim -> 0 %.0f cm below, faded %.1f-%.1f cm "
                    "beyond the girth); drips down the face are ~0" % (cg.GLOW_FALLOFF_CM, cg.GLOW_RADIAL_CM[0],
                                                                    cg.GLOW_RADIAL_CM[1])}
    return obj, parts, info


def candle_ledge_a():
    """Concept 1: six candles spread over ~45 cm of ledge, 8.5-30 cm tall, the short ones at the front (y 4-5) and
    the tall ones behind (y 8-12), so every flame shows from the room; four of them spill over the edge."""
    layout = [(-20.0, 4.6, 3.0, 11.0), (-12.0, 10.5, 3.8, 26.0), (-4.5, 5.0, 3.2, 15.0), (3.5, 11.5, 4.2, 30.0),
              (11.5, 4.1, 2.8, 8.5), (19.0, 8.0, 3.4, 20.0)]
    spill = {0: dict(hw=2.6, sheet=2.6, drips=((-0.5, 9.0), (0.45, 5.0))),
             2: dict(hw=3.0, sheet=3.4, drips=((-0.6, 13.0), (0.1, 6.0), (0.65, 9.0))),
             4: dict(hw=2.4, sheet=2.2, drips=((0.0, 7.0),)),
             5: dict(hw=2.6, sheet=2.8, drips=((-0.4, 15.0), (0.5, 6.0)))}
    return build_candle_ledge("CandleLedge_A", layout, spill, 650, 4702)


def candle_ledge_b():
    """Concept 6: a fat candle, a stub and a thin one; the fat one pours heavily over the edge."""
    layout = [(-4.0, 6.0, 4.6, 16.0), (5.5, 4.4, 3.2, 6.5), (-12.5, 11.5, 2.4, 9.5)]
    spill = {0: dict(hw=4.4, sheet=4.2, drips=((-0.62, 14.0), (-0.02, 8.0), (0.6, 11.0))),
             1: dict(hw=2.4, sheet=2.4, drips=((0.1, 6.0),))}
    return build_candle_ledge("CandleLedge_B", layout, spill, 520, 4712)


def candle_ledge_c():
    """Concept 1's long run: seven candles along ~58 cm of ledge, 9-29 cm tall, staggered in depth."""
    layout = [(-27.0, 5.0, 2.6, 9.0), (-19.0, 11.0, 3.6, 24.0), (-10.0, 4.5, 3.0, 13.0), (-1.0, 9.5, 4.4, 29.0),
              (8.5, 4.0, 3.0, 10.0), (16.0, 11.5, 3.6, 21.0), (24.5, 5.5, 3.2, 15.0)]
    spill = {0: dict(hw=2.4, sheet=2.4, drips=((0.2, 7.0),)),
             2: dict(hw=2.8, sheet=3.0, drips=((-0.55, 11.0), (0.5, 6.0))),
             3: dict(hw=3.4, sheet=3.6, drips=((-0.5, 17.0), (0.2, 9.0), (0.7, 12.0))),
             4: dict(hw=2.4, sheet=2.2, drips=((0.0, 8.0),)),
             6: dict(hw=2.8, sheet=2.8, drips=((-0.45, 12.0), (0.55, 5.0)))}
    return build_candle_ledge("CandleLedge_C", layout, spill, 760, 4722)


# ================================================================ wood goods (concepts 2 and 4; not yet in ENV_KIT)
def obox(center, axes, size, ch, rng=None, jitter=0.0, chips=(), chip=2.4):
    """A chamfered box with its local x / y / z along the columns of axes (a rotation), size = full extents. chips:
    corners (sx, sy, sz in -1 / 1) cut back by `chip` instead of ch (a knocked-off corner)."""
    h = np.asarray(size, float) * 0.5
    pts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                corner = np.array([sx * h[0], sy * h[1], sz * h[2]])
                cc = chip if (sx, sy, sz) in chips else ch
                for ax in range(3):
                    q = corner.copy()
                    q[ax] -= np.sign(corner[ax]) * min(cc, h[ax] * 0.9)
                    pts.append(q)
    pts = np.array(pts)
    if rng is not None and jitter:
        pts = pts + rng.uniform(-jitter, jitter, pts.shape)
    return ep.hull(pts @ np.asarray(axes, float).T + np.asarray(center, float))


def floor_snap(vf, tol=0.5):
    """Put the jittered underside of a floor-standing box back on z = 0."""
    v = np.array(vf[0], float)
    v[v[:, 2] < tol, 2] = 0.0
    return v, vf[1]


def wood_paint(parts, seed, extra=None):
    """Round 2: every board / stave / plank its own hand-painted value (+-15 %) and warmth (EnvWood .. EnvWoodDark),
    end grain and undersides darker, iron the warm dark grey of iron_col."""
    wood, wood_d = P("EnvWood"), P("EnvWoodDark")
    prng = np.random.default_rng(seed)
    light = wood * 1.38
    gt = {g: (prng.uniform(0.0, 1.0), prng.uniform(0.88, 1.12)) for g in sorted(set(parts.group))}

    def fn(i, tag, g, c, nrm):
        if extra is not None:
            col = extra(i, tag, g, c, nrm)
            if col is not None:
                return col
        if tag in ("hoop", "nail", "bolt"):
            return iron_col(nrm, prng, lift_dir=(0.0, 0.0, 1.0)) * (1.25 if tag != "hoop" else 1.0)
        if tag == "core":
            return wood_d * 0.4
        mix, val = gt[g]
        col = (lerp(light, wood, mix / 0.45) if mix < 0.45 else lerp(wood, wood_d, (mix - 0.45) / 0.55)) * val
        if tag in ("end", "chip"):
            col = col * 0.78
        if nrm[2] < -0.5:
            col = col * 0.72
        elif nrm[2] > 0.6:
            col = col * 1.1
        return col * prng.uniform(0.95, 1.05)

    return fn


BARREL_H = 82.0


def barrel_r(z):
    return 24.6 + 4.6 * (1.0 - ((z - 0.5 * BARREL_H) / (0.5 * BARREL_H)) ** 2)


def build_barrel():
    """A coopered barrel, 82 cm tall, belly ~60 cm (round 2: hand-cut): 14 staves of uneven width (+-13 %), each its
    own radial offset, top height (-1.8 .. +0.4 cm) and foot (some lifted ~1 cm), three with a chipped top edge; four
    conical iron hoops each tilted 1-2 degrees; a recessed head of three planks with a bung."""
    rng = np.random.default_rng(4801)
    parts = Parts(("EnvWood", "EnvIron"))
    n = 14
    zs = np.array([0.0, 7.0, 18.0, 30.0, 41.0, 52.0, 64.0, 75.0, BARREL_H])
    phase = rng.uniform(0.0, TAU / n)
    bounds = phase + TAU * np.arange(n + 1) / n
    bounds[1:-1] += rng.uniform(-0.065, 0.065, n - 1) * (TAU / n) * 2.0
    bounds[-1] = bounds[0] + TAU
    chipped = set(int(x) for x in rng.choice(n, 3, replace=False))
    for k in range(n):
        a0, a1 = bounds[k], bounds[k + 1]
        dr = rng.uniform(-0.4, 0.4)
        top = BARREL_H + rng.uniform(-1.8, 0.4)
        foot = 0.0 if k % 3 else rng.uniform(0.6, 1.3)
        rings = []
        for z in zs:
            zz = top if z == BARREL_H else (foot if z == 0.0 else z)
            r = barrel_r(z) + dr
            ri = r - 2.3
            ring = np.array([(r * math.cos(a0), r * math.sin(a0), zz), (r * math.cos(a1), r * math.sin(a1), zz),
                             (ri * math.cos(a1), ri * math.sin(a1), zz), (ri * math.cos(a0), ri * math.sin(a0), zz)])
            if z == BARREL_H and k in chipped:
                ring[0, 2] -= rng.uniform(1.2, 1.8)                  # a knocked outer top edge
                ring[1, 2] -= rng.uniform(0.3, 0.9)
            rings.append(ring)
        sv, sf = fc.loft(rings)
        g = parts.new_group()
        tags = ["stave"] * (len(sf) - 2) + ["end", "end"]
        parts.add((sv, sf), "EnvWood", tags, group=g)
    # hoops follow the staves' slope (conical bands), 0.75 cm proud of the stave corners, each tilted 1-2 degrees
    hoop_g = parts.new_group()
    for zc in (6.0, 21.0, 61.0, 76.0):
        z0, z1 = zc - 1.9, zc + 1.9
        # corner radius so the hoop's FACETS clear the outermost stave by >= 0.75 cm (the stave seams are jittered)
        ko = 1.0 / math.cos(math.pi / n)
        prof = [(barrel_r(z0) - 0.9, z0), ((barrel_r(z0) + 1.15) * ko, z0), ((barrel_r(z1) + 1.15) * ko, z1),
                (barrel_r(z1) - 0.9, z1)]
        hv, hf = ep.lathe_closed(prof, n, math.degrees(phase))
        b = rng.uniform(0.0, TAU)
        tilt = rng.uniform(1.0, 2.0) * (1 if rng.uniform() > 0.5 else -1)
        if zc < 10.0:
            tilt = 0.5 * tilt                                         # the foot hoop stays clear of the floor
        R = rot_matrix((math.cos(b), math.sin(b), 0.0), tilt)
        o = np.array([0.0, 0.0, zc])
        parts.add(((hv - o) @ R.T + o, hf), "EnvIron", "hoop", group=hoop_g)
        for m in range(3):
            a = phase + TAU * (m * 4 + 2.5) / n
            dr_ = np.array([math.cos(a), math.sin(a), 0.0])
            r_out = barrel_r(zc) + 1.15                                   # the hoop facet, not its corner
            p = dr_ * r_out + Z * zc
            parts.add(rivet((p - o) @ R.T + o, R @ dr_, rng, r=0.6, h=0.42), "EnvIron", "nail", group=hoop_g)
    # the head: three planks recessed 3 cm below the stave tops, sunk into the staves; a bung on the middle one
    zt = BARREL_H - 3.0
    rh = barrel_r(zt) - 2.3 + 0.6
    for j, (x0, x1) in enumerate(((-rh, -rh / 3.0 - 1.2), (-rh / 3.0 - 0.7, rh / 3.0 + 1.0), (rh / 3.0 + 1.5, rh))):
        xs_ = np.linspace(x0, x1, 4)
        pts = [(x, -math.sqrt(max(rh * rh - x * x, 0.0))) for x in xs_] + \
              [(x, math.sqrt(max(rh * rh - x * x, 0.0))) for x in xs_[::-1]]
        pts = np.array(pts)
        keep = [0]
        for q in range(1, len(pts)):
            if np.linalg.norm(pts[q] - pts[keep[-1]]) > 1e-3:
                keep.append(q)
        pts = pts[keep]
        if np.linalg.norm(pts[0] - pts[-1]) < 1e-3:
            pts = pts[:-1]
        dz = (0.0, 0.35, -0.3)[j]
        ring_lo = np.column_stack([pts, np.full(len(pts), zt - 2.4)])
        ring_hi = np.column_stack([pts, np.full(len(pts), zt + dz)])
        pv, pf = fc.loft([ring_lo, ring_hi])
        parts.add((pv, pf), "EnvWood", "head")
    bv_, bf_ = lathe([(0.0, zt - 0.3), (2.2, zt - 0.3), (2.3, zt + 1.0), (1.9, zt + 1.6), (0.0, zt + 1.7)], 7, 10.0)
    parts.add((bv_ + np.array([0.0, 4.0, 0.0]), bf_), "EnvWood", "bung")
    obj = parts.build("Barrel_A_Mars_SM")

    def extra(i, tag, g, c, nrm):
        if tag == "bung":
            return P("EnvWoodDark") * 0.9
        return None

    alpha = ep.vertex_alpha(obj, parts)
    ep.paint_parts(obj, parts, wood_paint(parts, 4802, extra), variation=0.03, seed=4803, cavity_darken=0.35,
                   alpha=alpha)
    fc.smart_uv(obj)
    info = {"height_cm": BARREL_H, "belly_diameter_cm": round(2 * (barrel_r(41.0) + 0.4), 1), "staves": n,
            "chipped_staves": sorted(chipped)}
    return obj, parts, info


def split_widths(total, fracs, rng, jit=0.12):
    f = np.asarray(fracs, float) * (1.0 + rng.uniform(-jit, jit, len(fracs)))
    return total * f / f.sum()


def build_crate(name="Crate_A", W=62.0, D=58.0, H=56.0, seed=4901, lid=True):
    """A battened crate (round 2: hand-cut): twelve edge battens (each set recessed a little so no two outer faces are
    coplanar), 2-3 of them with a knocked-off corner, side planks of uneven height with dark gaps, a lid of uneven
    boards with one shoved 1.5 cm out of line (or, lid=False, an open top over a dark hold), a diagonal brace front and
    back, nails."""
    rng = np.random.default_rng(seed)
    parts = Parts(("EnvWood", "EnvIron"))
    b = 5.0
    I3 = np.eye(3)
    if lid:
        parts.add(chamfer_box((0.0, 0.0, H * 0.5), (W - 6.0, D - 6.0, H - 6.0), 0.3), "EnvWood", "core")
    else:
        hold = H - 9.0                                             # the open crate's dark hold floor
        parts.add(chamfer_box((0.0, 0.0, 0.5 * (3.0 + hold)), (W - 6.0, D - 6.0, hold - 3.0), 0.3), "EnvWood", "core")
    corners = [(sx, sy, sz) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    chip_ids = set(int(x) for x in rng.choice(12, 3, replace=False))
    chip_cm = 3.4
    batten = 0

    def chips_for():
        nonlocal batten
        out = ()
        if batten in chip_ids:
            out = (corners[int(rng.integers(len(corners)))],)
        batten += 1
        return out
    # x battens flush with the bounds (they carry the flat underside)
    for sy in (-1, 1):
        for zc in (b * 0.5, H - b * 0.5):
            bx = floor_snap(obox((0.0, sy * (D * 0.5 - b * 0.5), zc), I3, (W - 1.4, b, b), 0.45, rng, 0.1,
                                 chips=chips_for(), chip=chip_cm))
            parts.add(bx, "EnvWood", "batten")
    # y battens 0.4 inside on x and z
    for sx in (-1, 1):
        for zc in (b * 0.5 + 0.4, H - b * 0.5 - 0.4):
            parts.add(obox((sx * (W * 0.5 - b * 0.5 - 0.4), 0.0, zc), I3, (b, D - 2.0 * b + 1.6, b), 0.45, rng, 0.1,
                           chips=chips_for(), chip=chip_cm), "EnvWood", "batten")
    # vertical battens between the x battens, 0.5 inside on y
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.add(obox((sx * (W * 0.5 - b * 0.5), sy * (D * 0.5 - b * 0.5 - 0.5), H * 0.5), I3,
                           (b, b, H - 2.0 * b + 2.0), 0.45, rng, 0.1, chips=chips_for(), chip=chip_cm),
                      "EnvWood", "batten")
    # side planks: three per side of uneven height, 0.8 cm gaps, outer face 1.6 - 1.9 cm inside the bounds
    gap = 0.8
    zlo, zhi = b - 0.6, H - b + 0.6
    for axis in ("y", "x"):
        for sgn in (-1, 1):
            hs = split_widths(zhi - zlo - 2.0 * gap, (0.38, 0.29, 0.33), rng)
            z = zlo
            for k, ph in enumerate(hs):
                zc = z + 0.5 * ph
                z += ph + gap
                out = rng.uniform(-0.15, 0.15)
                if axis == "y":
                    c = (0.0, sgn * (D * 0.5 - 1.6 - 1.0 + out), zc)
                    size = (W - 2.0 * b + 1.6, 2.0, ph)
                else:
                    c = (sgn * (W * 0.5 - 1.9 - 1.0 + out), 0.0, zc)
                    size = (2.0, D - 2.0 * b - 0.4, ph)
                parts.add(obox(c, I3, size, 0.35, rng, 0.1), "EnvWood", "plank")
    if lid:
        ws = split_widths(D - 2.0 * b + 1.0 - 3.0 * gap, (0.3, 0.22, 0.27, 0.21), rng)
        y = -(D * 0.5 - b + 0.5)
        shove = int(rng.integers(4))
        for k, pw in enumerate(ws):
            yc = y + 0.5 * pw
            y += pw + gap
            xo = 1.5 if k == shove else rng.uniform(-0.2, 0.2)
            zt = H - 1.5 - 1.0 + rng.uniform(-0.25, 0.25)
            parts.add(obox((xo, yc, zt), I3, (W - 2.0 * b - 0.4, pw, 2.0), 0.35, rng, 0.1), "EnvWood", "plank")
    # a diagonal brace across the planks, front and back
    for sy in (-1, 1):
        p0 = np.array([-(W * 0.5 - b), 0.0, b])
        p1 = np.array([W * 0.5 - b, 0.0, H - b])
        ax = _n(p1 - p0)
        ny = np.array([0.0, float(sy), 0.0])
        R = np.column_stack([ax, ny, np.cross(ax, ny)])
        L = float(np.linalg.norm(p1 - p0)) + 4.0
        c = 0.5 * (p0 + p1) + ny * (D * 0.5 - 0.25 - 0.9)
        parts.add(obox(c, R, (L, 1.8, 8.0), 0.35, rng, 0.08), "EnvWood", "brace")
    # nails at the batten ends
    for sy in (-1, 1):
        for sx in (-1, 1):
            for zc in (b * 0.5, H - b * 0.5):
                parts.add(rivet((sx * (W * 0.5 - 2.5 - 3.6), sy * D * 0.5, zc), Y * sy, rng, r=0.55, h=0.38),
                          "EnvIron", "nail")
    obj = parts.build(name + "_Mars_SM")
    alpha = ep.vertex_alpha(obj, parts)
    ep.paint_parts(obj, parts, wood_paint(parts, seed + 1), variation=0.03, seed=seed + 2, cavity_darken=0.4,
                   alpha=alpha)
    fc.smart_uv(obj)
    info = {"crate_size_cm": [W, D, H], "lid": lid, "chipped_battens": sorted(chip_ids)}
    return obj, parts, info


RAIL_SPAN = 200.0
POST = 16.0
POST_TOP = 100.5               # the post's top, sunk 5 mm into the top rail laid on it
RAIL_Z = 100.0                 # the top rail's underside
TOP_RAIL = [(-6.0, 0.0), (6.0, 0.0), (6.0, 8.2), (4.4, 10.0), (-4.4, 10.0), (-6.0, 8.2)]     # 12 W x 10 H, chamfered
MID_RAIL = [(-4.0, -4.0), (4.0, -4.0), (4.0, 3.0), (3.0, 4.0), (-3.0, 4.0), (-4.0, 3.0)]      # 8 x 8
MID_Z = 55.0


def beam(xs, ys, zs, section):
    """A beam along +X through (xs, ys, zs) with a constant (y, z) section, capped."""
    rings = [np.array([(x, y + sy, z + sz) for sy, sz in section]) for x, y, z in zip(xs, ys, zs)]
    return fc.loft(rings)


def railing_post(parts, rng, x):
    chips = tuple((sx, sy, 1) for sx, sy in ((1, -1), (-1, 1)) if rng.uniform() > 0.3)
    parts.add(floor_snap(obox((x, 0.0, POST_TOP * 0.5), np.eye(3), (POST, POST, POST_TOP), 1.2, rng, 0.25,
                              chips=chips, chip=2.6)), "EnvWood", "post")
    # the saddle block over the post: the top rail's section a touch bigger, x -8..8 (it hides the rail joint)
    sec = [(sy * 1.07, sz * 1.06 - 0.3) for sy, sz in TOP_RAIL]
    xs = np.array([x - 8.4, x + 8.4])
    parts.add(beam(xs, [0.0, 0.0], [RAIL_Z, RAIL_Z], sec), "EnvWood", "saddle")


def build_railing(post_only=False):
    """Concept 2's chunky corridor railing (round 2). Railing_A: a 16 x 16 cm post at the origin with a saddle block,
    a 12 x 10 chamfered top rail laid on the posts from x 0 to 200 (the next segment's saddle hides the joint) and an
    8 x 8 mid rail between the post faces, both sagging / skewed 1-2 cm along their length. RailingPost_A: the end
    post (with its saddle) that closes a run. Pivot: the post's footprint centre, z = 0."""
    rng = np.random.default_rng(5011 if post_only else 5001)
    parts = Parts(("EnvWood",) if post_only else ("EnvWood", "EnvIron"))
    railing_post(parts, rng, 0.0)
    if not post_only:
        t = np.linspace(0.0, 1.0, 7)
        xs = t * RAIL_SPAN
        sag, skew = rng.uniform(1.2, 1.8), rng.uniform(-1.2, 1.2)
        parts.add(beam(xs, skew * np.sin(math.pi * t), RAIL_Z - sag * np.sin(math.pi * t), TOP_RAIL), "EnvWood",
                  "rail")
        xs2 = POST * 0.5 - 1.0 + t * (RAIL_SPAN - POST + 2.0)
        sag2, skew2 = rng.uniform(0.8, 1.4), rng.uniform(-1.0, 1.0)
        parts.add(beam(xs2, skew2 * np.sin(math.pi * t), MID_Z - sag2 * np.sin(math.pi * t), MID_RAIL), "EnvWood",
                  "rail")
        parts.add(rivet((0.0, -6.4 * 1.07 - 0.05, RAIL_Z + 4.5), -Y, rng, r=1.0, h=0.6), "EnvIron", "bolt")
        parts.add(rivet((POST * 0.5 + 3.5, -4.0, MID_Z), -Y, rng, r=0.9, h=0.55), "EnvIron", "bolt")
    obj = parts.build(("RailingPost_A" if post_only else "Railing_A") + "_Mars_SM")
    alpha = ep.vertex_alpha(obj, parts)
    ep.paint_parts(obj, parts, wood_paint(parts, 5002), variation=0.03, seed=5003, cavity_darken=0.4, alpha=alpha)
    fc.smart_uv(obj)
    info = {"post_cm": [POST, POST, POST_TOP], "top_rail_cm": [12.0, 10.0], "mid_rail_cm": [8.0, 8.0],
            "chain_step_cm": RAIL_SPAN,
            "chain_note": "Railing_A segments snap every 200 cm along +X (each post's saddle block hides the rail "
                          "joint); finish the run with RailingPost_A at the end"}
    return obj, parts, info


# ================================================================ review
def lights_sheet_objects(built):
    return [built[k][0] for k in ("TorchSconce_A", "WallLantern_A", "SpiritLantern_Post", "Brazier_A") if k in built]


def ledge_block(name, width, depth=24.0, height=40.0):
    return ep.painted_box(name, (0.0, depth * 0.5, -height * 0.5), (width, depth, height), fc.srgb(112, 106, 100))


def render_sheets(built):
    sheets = []
    rd = spec.REVIEW_DIR
    groups = (("clutter_sacks", ("Sack_A", "Sack_B", "SackPile_A", "Sack_C"), ("iso", "front", "top")),
              ("clutter_banners", ("Banner_A", "Banner_B"), ("front", "iso", "side")),
              ("clutter_lights", ("TorchSconce_A", "WallLantern_A", "SpiritLantern_Post", "Brazier_A"),
               ("iso", "front", "side")),
              ("clutter_candleledges", ("CandleLedge_A", "CandleLedge_B", "CandleLedge_C"), ("iso", "front", "side")),
              ("clutter_woodgoods", ("Barrel_A", "Crate_A", "Crate_B", "Railing_A", "RailingPost_A"),
               ("iso", "front", "top")))
    for stem, keys, views in groups:
        objs = [built[k][0] for k in keys if k in built]
        if not objs:
            continue
        copies = [ep.review_copy(o) for o in objs]
        sheets.append(ec.review(copies, stem, views=views))
        for c in copies:
            ep.remove_object(c)
    paths = []

    def shot(objs, stem, view, **kw):
        path = os.path.join(rd, "%s.png" % stem)
        paths.append(ep.render_view(objs, path, view, **kw))
        return path

    # close-ups of the hero pieces
    if "Banner_A" in built:
        b = built["Banner_A"][0]
        a = shot([b], "clutter_banner_emblem_front", (0.0, -1.0, 0.0), size=(1000, 1200), target_cm=(0.0, -6.0, -115.0),
                 half_cm=62.0)
        c = shot([b], "clutter_banner_emblem_iso", (0.9, -1.0, 0.35), size=(1000, 1200), target_cm=(0.0, -6.0, -120.0),
                 half_cm=70.0, shadows=True)
        d = shot([b], "clutter_banner_top_iso", (0.9, -1.0, 0.45), size=(1000, 1200), target_cm=(55.0, -6.0, -10.0),
                 half_cm=22.0)
        e = shot([b], "clutter_banner_hem_iso", (0.6, -1.0, -0.15), size=(1000, 1200), target_cm=(0.0, -6.0, -270.0),
                 half_cm=50.0)
        sheets.append(fc.tile_images([a, c, d, e], os.path.join(rd, "clutter_banner_close_sheet.png"), cols=4))
    if "Banner_B" in built:
        b = built["Banner_B"][0]
        a = shot([b], "clutter_bannerB_hem_front", (0.0, -1.0, 0.0), size=(1000, 1200), target_cm=(0.0, -6.0, -270.0),
                 half_cm=70.0)
        c = shot([b], "clutter_bannerB_iso", (0.9, -1.0, 0.25), size=(1000, 1200), shadows=True)
        sheets.append(fc.tile_images([a, c], os.path.join(rd, "clutter_bannerB_close_sheet.png"), cols=2))
    if "TorchSconce_A" in built:
        t = built["TorchSconce_A"][0]
        a = shot([t], "clutter_torch_iso", (1.0, -1.0, 0.4), size=(1000, 1200))
        c = shot([t], "clutter_torch_side", (1.0, 0.0, 0.05), size=(1000, 1200))
        d = shot([t], "clutter_torch_head", (0.7, -1.0, 0.6), size=(1000, 1200), target_cm=(0.0, -20.0, 22.0),
                 half_cm=14.0)
        sheets.append(fc.tile_images([a, c, d], os.path.join(rd, "clutter_torch_close_sheet.png"), cols=3))
    if "WallLantern_A" in built:
        t = built["WallLantern_A"][0]
        a = shot([t], "clutter_lantern_iso", (1.0, -1.0, 0.35), size=(1000, 1200))
        c = shot([t], "clutter_lantern_side", (1.0, 0.0, 0.05), size=(1000, 1200))
        d = shot([t], "clutter_lantern_hook", (1.0, -0.4, 0.3), size=(1000, 1200), target_cm=(0.0, -45.0, -5.0),
                 half_cm=9.0)
        sheets.append(fc.tile_images([a, c, d], os.path.join(rd, "clutter_lantern_close_sheet.png"), cols=3))
    if "Brazier_A" in built:
        t = built["Brazier_A"][0]
        a = shot([t], "clutter_brazier_iso", (1.0, -1.0, 0.5), size=(1000, 1200), shadows=True)
        c = shot([t], "clutter_brazier_top", (0.25, -0.5, 1.0), size=(1000, 1200), target_cm=(0.0, 0.0, 82.0),
                 half_cm=40.0)
        a210 = math.radians(210.0)                                   # the front-left leg's pad and scroll
        d = shot([t], "clutter_brazier_foot", (-0.55, -0.95, 0.3), size=(1000, 1200),
                 target_cm=(36.6 * math.cos(a210), 36.6 * math.sin(a210), 3.6), half_cm=8.5)
        sheets.append(fc.tile_images([a, c, d], os.path.join(rd, "clutter_brazier_close_sheet.png"), cols=3))
    if "SpiritLantern_Post" in built:
        t = built["SpiritLantern_Post"][0]
        a = shot([t], "clutter_spirit_iso", (1.0, -1.0, 0.3), size=(1000, 1200), shadows=True)
        c = shot([t], "clutter_spirit_head", (1.0, -1.0, 0.2), size=(1000, 1200), target_cm=(0.0, 0.0, 74.0),
                 half_cm=22.0)
        sheets.append(fc.tile_images([a, c], os.path.join(rd, "clutter_spirit_close_sheet.png"), cols=2))
    ledges = [k for k in ("CandleLedge_A", "CandleLedge_B", "CandleLedge_C") if k in built]
    if ledges:
        tmp, imgs = [], []
        for k in ledges:
            o = built[k][0]
            lo, hi = fc.bounds_cm(o)
            blk = ledge_block("_Ledge_" + k, hi[0] - lo[0] + 24.0)
            tmp.append(blk)
            half = max(32.0, 0.62 * float(hi[0] - lo[0]))
            imgs.append(shot([o, blk], "clutter_%s_low" % k.lower(), (0.55, -1.0, 0.18), size=(1000, 1200),
                             target_cm=(0.0, 0.0, 2.0), half_cm=half, shadows=True))
            imgs.append(shot([o, blk], "clutter_%s_front" % k.lower(), (0.0, -1.0, 0.22), size=(1000, 1200),
                             target_cm=(0.0, 0.0, 6.0), half_cm=half, shadows=True))
            imgs.append(shot([o], "clutter_%s_side" % k.lower(), (1.0, 0.0, 0.0), size=(1000, 1200)))
        sheets.append(fc.tile_images(imgs, os.path.join(rd, "clutter_candleledge_close_sheet.png"), cols=3))
        for o in tmp:
            ep.remove_object(o)
    goods = [k for k in ("Barrel_A", "Crate_A", "Crate_B", "Railing_A") if k in built]
    if goods:
        imgs = [shot([built[k][0]], "clutter_%s_low" % k.lower(), (0.8, -1.0, 0.35), size=(1000, 1000), shadows=True)
                for k in goods]
        sheets.append(fc.tile_images(imgs, os.path.join(rd, "clutter_woodgoods_close_sheet.png"), cols=len(imgs)))
    for sack in ("Sack_A", "Sack_B", "SackPile_A", "Sack_C"):
        if sack in built:
            o = built[sack][0]
            a = shot([o], "clutter_%s_low" % sack.lower(), (0.8, -1.0, 0.3), size=(1200, 1000), shadows=True)
            sheets.append(a)
    sheets.append(lineup(built))
    for pth in paths:
        if pth not in sheets and os.path.exists(pth):
            pass
    return sheets


def lineup(built):
    """Everything at true scale against a 3.5 m wall and a 150 cm chef box: wall props at their usual heights."""
    tmp = []
    place = {"Sack_A": (-450.0, -60.0, 0.0), "Sack_B": (-370.0, -70.0, 0.0), "SackPile_A": (-250.0, -70.0, 0.0),
             "Sack_C": (-170.0, -60.0, 0.0), "Crate_B": (-700.0, -50.0, 0.0),
             "Barrel_A": (-560.0, -60.0, 0.0), "Crate_A": (-640.0, -70.0, 0.0), "Railing_A": (-520.0, -200.0, 0.0),
             "RailingPost_A": (-320.0, -200.0, 0.0),
             "SpiritLantern_Post": (130.0, -60.0, 0.0), "Brazier_A": (240.0, -90.0, 0.0),
             "Banner_A": (360.0, 0.0, 320.0), "Banner_B": (470.0, 0.0, 330.0),
             "TorchSconce_A": (550.0, 0.0, 180.0), "WallLantern_A": (610.0, 0.0, 200.0),
             "CandleLedge_A": (-60.0, -50.0, 95.0), "CandleLedge_B": (5.0, -50.0, 95.0),
             "CandleLedge_C": (60.0, -50.0, 95.0)}
    for k, off in place.items():
        if k in built:
            tmp.append(ep.copy_mesh(built[k][0], offset=off, name="_Line_" + k))
    tmp.append(ep.painted_box("_Chef150", (-150.0, -150.0, 75.0), (45.0, 30.0, 150.0), fc.srgb(226, 222, 210)))
    tmp.append(ep.painted_box("_Wall", (0.0, 10.0, 175.0), (1400.0, 20.0, 350.0), fc.srgb(96, 92, 90)))
    tmp.append(ep.painted_box("_Floor", (0.0, -140.0, -5.0), (1400.0, 300.0, 10.0), fc.srgb(80, 76, 74)))
    tmp.append(ep.painted_box("_Shelf", (0.0, -25.0, 92.5), (240.0, 50.0, 5.0), fc.srgb(118, 110, 102)))
    path = ep.render_view(tmp, os.path.join(spec.REVIEW_DIR, "clutter_lineup_scale.png"), None, size=(2600, 1100),
                          target_cm=(0.0, 0.0, 170.0), eye_cm=(0.0, -1650.0, 260.0), lens=30.0, shadows=True)
    for o in tmp:
        ep.remove_object(o)
    return path


# ================================================================ re-import
def reimport(path, rule):
    stem = os.path.splitext(os.path.basename(path))[0]
    parked = []
    for o in list(bpy.data.objects):
        if o.name == stem or o.name.startswith("SOCKET_"):
            parked.append((o, o.name))
            o.name = "_parked_" + o.name
    before = set(bpy.data.objects)
    before_mesh, before_mat = set(bpy.data.meshes), set(bpy.data.materials)
    bpy.ops.import_scene.fbx(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH" and not o.name.startswith("UCX_")]
    ucx = [o for o in new if o.name.startswith("UCX_")]
    empties = sorted(o.name for o in new if o.type == "EMPTY")
    problems = []
    with open(os.path.splitext(path)[0] + ".json") as fh:
        meta = json.load(fh)
    if len(meshes) != 1:
        problems.append("%d meshes" % len(meshes))
    else:
        m = meshes[0].data
        uvs = [u.name for u in m.uv_layers]
        want = ["UVMap"] + ([rule["uv1"]] if rule.get("uv1") else [])
        if uvs != want:
            problems.append("uv %s" % uvs)
        if "Col" not in [c.name for c in m.color_attributes]:
            problems.append("no Col")
        if not fc._is_flat(m):
            problems.append("not flat")
        if fc.tri_count(meshes[0]) != meta["tris"]:
            problems.append("tris %d != sidecar %d" % (fc.tri_count(meshes[0]), meta["tris"]))
        slots = [mt.name.split(".")[0] for mt in m.materials if mt]
        if slots != list(rule["slots"]):
            problems.append("slots %s" % slots)
        if rule.get("uv1") == CANDLE_UV:
            r = cg.data_ranges(m).get("EnvFlame")
            if not r or abs(r["value"][0]) > 1e-4 or abs(r["value"][1] - 1.0) > 1e-4:
                problems.append("flame height range %s" % (r and r["value"]))
    want_e = sorted("SOCKET_" + s for s in rule.get("sockets", ()))
    if empties != want_e:
        problems.append("empties %s != %s" % (empties, want_e))
    if ucx:
        problems.append("%d UCX pieces" % len(ucx))
    if sorted(meta.get("sockets", {})) != sorted(rule.get("sockets", ())):
        problems.append("sidecar sockets %s" % sorted(meta.get("sockets", {})))
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    for m in [m for m in bpy.data.meshes if m not in before_mesh]:
        bpy.data.meshes.remove(m)
    for m in [m for m in bpy.data.materials if m not in before_mat]:
        bpy.data.materials.remove(m)
    for o, n in parked:
        o.name = n
    print("REIMPORT %-28s tris %s  %s" % (stem, meta["tris"], "ok" if not problems else "FAIL " + "; ".join(problems)))
    return ["%s reimport: %s" % (stem, "; ".join(problems))] if problems else []


# ================================================================ main
BUILDERS = {"Sack_A": sack_a, "Sack_B": sack_b, "SackPile_A": sack_pile, "Sack_C": sack_c, "Banner_A": banner_a,
            "Banner_B": banner_b, "TorchSconce_A": build_torch, "WallLantern_A": build_wall_lantern,
            "SpiritLantern_Post": build_spirit_lantern, "Brazier_A": build_brazier,
            "CandleLedge_A": candle_ledge_a, "CandleLedge_B": candle_ledge_b, "CandleLedge_C": candle_ledge_c,
            "Barrel_A": build_barrel, "Crate_A": build_crate,
            "Crate_B": lambda: build_crate("Crate_B", 46.0, 40.0, 38.0, 4911, lid=False),
            "Railing_A": build_railing, "RailingPost_A": lambda: build_railing(post_only=True)}


def finish(key, res):
    """Common tail: UV0 (+ the banner's EnvData) for the builders that leave it to here."""
    obj, parts, info = res[0], res[1], res[2]
    mesh = obj.data
    if "UVMap" not in mesh.uv_layers:
        fc.smart_uv(obj)
    if key.startswith("Banner"):
        u = np.full(len(parts.tag), {"Banner_A": 0.31, "Banner_B": 0.68}[key])
        ep.write_uv1(obj, DATA_UV, u, np.concatenate(parts.flex))
    return obj, parts, info


def main():
    args = fc.cli_args({"export": False, "save": False, "sheets": False, "only": ""})
    t0 = time.time()
    fc.ensure_dirs()
    fc.clear_scene()
    bpy.context.scene.view_settings.view_transform = "Standard"
    only = [n for n in str(args["only"]).split(",") if n] if args["only"] else list(NAMES)
    unknown = [n for n in only if n not in NAMES]
    if unknown:
        raise SystemExit("unknown mesh(es) %s; choose from %s" % (unknown, NAMES))
    fails, built, exported, table = [], {}, {}, []
    for key in NAMES:
        if key not in only:
            continue
        t1 = time.time()
        res = BUILDERS[key]()
        obj, parts, info = finish(key, res)
        rule = RULES[key]
        built[key] = (obj, parts, info)
        problems, stats = ep.check_mesh(obj, parts, rule, rule["anchor"])
        lo, hi = fc.bounds_cm(obj)
        socks = sorted(o["env_socket"] for o in bpy.data.objects if o.parent is obj and o.get("env_socket"))
        row = dict(name=obj.name, tris=stats["tris"], budget=spec.TRIS[rule["cat"]], size=[round(float(x), 1) for x in
                   (hi - lo)], slots=[m.name for m in obj.data.materials], sockets=socks, ucx=0,
                   components=stats["components"])
        table.append(row)
        print("%-28s tris %5d / %5d  size %s cm  comps %3d  slots %s  sockets %s  (%.1fs)%s" % (
            obj.name, row["tris"], row["budget"], row["size"], row["components"], row["slots"], socks,
            time.time() - t1, "" if not problems else "\n    PROBLEMS: " + "\n              ".join(problems)))
        fails += ["%s: %s" % (key, p) for p in problems]
        if args["export"]:
            if problems:
                print("  NOT exported (checks failed): %s" % key)
                continue
            ep.claim_sockets(obj)
            extra = dict(family=FAMILY, builder="build_env_clutter.py", category=rule["cat"],
                         tris_budget=spec.TRIS[rule["cat"]], pivot=PIVOT_NOTE[rule["pivot"]],
                         ucx_note="no UCX: ENV_KIT asks for none in the clutter family", **info)
            if rule.get("uv1") == CANDLE_UV:
                extra["data_uv"] = {"layer": CANDLE_UV, "channel": 1,
                                    "u": "flame id 0..1, constant per flame tongue (other faces: the nearest flame's / "
                                         "owning candle's id)",
                                    "v_unreal": "EnvFlame: height along the flame 0 base .. 1 tip; EnvWax: candle_gen "
                                                "glow; everything else 0",
                                    "v_blender": "1 - value (the FBX -> Unreal import flips V)",
                                    "ranges": cg.data_ranges(obj.data)}
            elif rule.get("uv1") == DATA_UV:
                extra["data_uv"] = {"layer": DATA_UV, "channel": 1, "u": "piece id", "v_unreal":
                                    "flex 0 at the rod .. 1 at the hem (cloth and its gold decals); rod, brackets, "
                                    "finials 0", "v_blender": "1 - value"}
            exported[key] = ec.export(obj, FAMILY, extra=extra)
    sheets = []
    if args["sheets"]:
        sheets = render_sheets(built)
        for m in list(bpy.data.materials):
            if m.users == 0:
                bpy.data.materials.remove(m)
    # determinism: the SDF path rebuilt from its seed gives the same mesh
    if "Sack_A" in built:
        again = sack_a()
        if fc.tri_count(again[0]) != fc.tri_count(built["Sack_A"][0]) or not np.allclose(
                fc.verts_cm(again[0]), fc.verts_cm(built["Sack_A"][0]), atol=1e-4):
            fails.append("Sack_A is not reproducible from its seed")
        ep.remove_object(again[0])
    if args["save"]:
        x = 0.0
        for key, (obj, *_r) in built.items():
            lo, hi = fc.bounds_cm(obj)
            obj.location = ((x - lo[0]) * 0.01, 0.0, 0.0)
            x += (hi[0] - lo[0]) + 30.0
        for coll in (bpy.data.materials, bpy.data.meshes, bpy.data.cameras, bpy.data.curves):
            for d in list(coll):
                if d.users == 0:
                    coll.remove(d)
        ec.save_family_blend(FAMILY)
        print("saved", os.path.join(spec.BLEND_DIR, spec.FAMILIES[FAMILY][1]))
        for key, (obj, *_r) in built.items():
            obj.location = (0.0, 0.0, 0.0)
    for key, path in exported.items():
        fails += reimport(path, RULES[key])
    print("\nTABLE " + json.dumps(table))
    print("\nsheets:", *sheets, sep="\n  ")
    print("exported:", *exported.values(), sep="\n  ")
    print("total %.1fs" % (time.time() - t0))
    if fails:
        print("ENV_CLUTTER_FAIL", *fails, sep="\n  ")
    elif len(only) != len(NAMES):
        print("ENV_CLUTTER_PARTIAL (only %s)" % ",".join(only))
    else:
        print("ENV_CLUTTER_OK")


main()
