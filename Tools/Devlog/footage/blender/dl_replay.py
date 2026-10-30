"""Replaying the crypt kit's procedural builders step by step (read-only monkeypatches, nothing written to the kit).

Piece builds
------------
Every crypt piece is built by a function `fn(b)` taking a `geo.Builder`; every primitive it adds (`blk` / `flat` ->
`Builder.box`, `quad` -> `Builder.mesh`, `yz_prism` / voussoirs / spandrels -> `Builder.prism`, lathes, tubes ...)
ends in ONE call: `Builder.emit(src_bmesh, cat, matrix, ...)`, which appends that primitive's faces to the shared
bmesh.  `build()` wraps `Builder.emit` for the duration of one `crypt.build_piece()` call and records
`len(b.bm.faces)` after each emit.  `bm.to_mesh`, the trim mapper (trimmap.map_object) and the surface pass all keep
the face order, so face i of the finished mesh belongs to step k = the first emit whose running face count passes i.
That step is written into a FACE float attribute `reveal`; the DL_Reveal geometry-nodes modifier (dl_scene) deletes
faces with reveal > threshold and drops the newest ones in from above, so animating the threshold replays the build
primitive by primitive.

The "raw" (blockout) build is the same build with `Builder.box / chunk / prism / lathe / rock` wrapped to force
bevel = 0, and the builder's RNG swapped for a proxy whose `uniform()` still advances the real generator but returns
the range midpoint (0 for the tilt `wobble` and vertex `jit` draws).  The random draws happen in the same order, so
course widths, piece choices and emit order are identical to the finished build; only bevels, tilt and vertex
wobble are gone.  Raw and finished builds therefore have the same step count, which lets one threshold sweep swap
raw blocks for finished ones step by step ("bevel / wobble applied").

Atlas generation
----------------
`atlas_replay()` re-runs builder._generate's loop for MISE_ATLAS (Bellfold theme, seed 1) at 256 px/m (1024 px
square, the size it is shown at) and snapshots the canvas after `mise_paint.mortar_bed` and after every
`mise_paint.block` call (both wrapped for the replay; block_tiles / paver_tiles / course look them up as module
globals), then after each strip's build; then computes the map passes exactly as _generate does (normal, horizon
AO, cavity, the per-strip paint pass) and returns them as stage images.
"""

import inspect
import time

import numpy as np

import dl_scene as ds


# ------------------------------------------------------------------ piece builds
class _MidRng:
    """RNG proxy: advances the real generator on uniform() but returns the midpoint (no tilt / jitter)."""

    def __init__(self, real):
        self._real = real

    def uniform(self, a, b):
        self._real.uniform(a, b)
        return (a + b) * 0.5

    def __getattr__(self, k):
        return getattr(self._real, k)


_RAW = {"on": False}
_PATCHED = {}


def _install(geo):
    if _PATCHED:
        return
    for name in ("box", "chunk", "prism", "lathe", "rock"):
        orig = getattr(geo.Builder, name)
        sig = inspect.signature(orig)

        def wrap(self, *a, _orig=orig, _sig=sig, **kw):
            if not _RAW["on"]:
                return _orig(self, *a, **kw)
            ba = _sig.bind(self, *a, **kw)
            ba.apply_defaults()
            if "bevel" in ba.arguments:
                ba.arguments["bevel"] = 0.0
            real = self.rng
            self.rng = _MidRng(real)
            try:
                return _orig(*ba.args, **ba.kwargs)
            finally:
                self.rng = real
        _PATCHED[name] = orig
        setattr(geo.Builder, name, wrap)


def build(pid, raw=False, do_map=True, name=None):
    """Build piece `pid` through crypt.build_piece with the emit recorder on.  Returns (object, steps) where steps is
    [(face_count_after, category)] per primitive; the mesh gets the FACE float `reveal` = step index, and its UCX
    collision children are deleted."""
    import bpy
    kc, geo = ds.kit()
    _install(geo)
    marks = []
    orig_emit = geo.Builder.emit

    def emit(self, src, cat, *a, **kw):
        r = orig_emit(self, src, cat, *a, **kw)
        marks.append((len(self.bm.faces), cat))
        return r
    geo.Builder.emit = emit
    _RAW["on"] = raw
    t0 = time.perf_counter()
    try:
        ob = kc.build_piece(pid, seed=1, do_map=do_map, name=name or ("DL_%s_%s" % ("RAW" if raw else "FIN", pid)))
    finally:
        geo.Builder.emit = orig_emit
        _RAW["on"] = False
    secs = time.perf_counter() - t0
    for c in list(ob.children):
        me = c.data
        bpy.data.objects.remove(c, do_unlink=True)
        if me is not None and me.users == 0:
            bpy.data.meshes.remove(me)
    me = ob.data
    n = len(me.polygons)
    step = np.zeros(n, np.float32)
    prev = 0
    for k, (cnt, _) in enumerate(marks):
        step[prev:cnt] = k
        prev = cnt
    assert prev == n, (pid, prev, n)
    ds.set_face_float(me, "reveal", step)
    ob["dl_build_seconds"] = secs
    return ob, marks


# ------------------------------------------------------------------ atlas
def _hillshade(h, px, light=(-0.55, 0.6, 0.58)):
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) / (2.0 * px)
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) / (2.0 * px)
    n = np.stack([-gx * 1.5, -gy * 1.5, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    lv = np.array(light, np.float32)
    lv /= np.linalg.norm(lv)
    return np.clip(n @ lv, 0.0, 1.0)


def atlas_replay(ppm=256, seed=1, variant="Bellfold", log=print):
    """Returns dict: rows (strip layout), snaps [(label, strip_id, uint8 HxWx3 top-row-first)], stage images
    {height, normal, ao, cavity, final} (uint8, top row first) and the generation seconds."""
    ds.kit()
    import sys
    sheets = sys.modules.get("vns_trim_sheet.sheets") or __import__("vns_trim_sheet.sheets", fromlist=["x"])
    from vns_trim_sheet import maps, themes, mise_paint
    from vns_trim_sheet.field import Field
    sheet = sheets.SHEETS["MISE_ATLAS"]
    theme = sheet.variants[variant]
    snaps = []
    t0 = time.perf_counter()
    with themes.use(theme):
        pad = sheets.pad_px(sheet, ppm, 4)
        nx, ny, rows = sheets.layout(sheet, ppm, pad)
        F = Field(sheet.width, sheet.height, nx, ny, np.random.default_rng(seed))
        px = sheet.width / nx
        started = np.zeros(ny, bool)
        cur = {"strip": None, "row": None}

        def snap(label):
            alb = F.alb
            shade = _hillshade(F.h, px)
            img = alb * (0.62 + 0.5 * shade[..., None])
            empty = np.array(ds_hex("#24242c"), np.float32)
            out = np.where(started[:, None, None], img, empty[None, None, :])
            snaps.append((label, cur["strip"], (np.clip(out[::-1], 0, 1) * 255).astype(np.uint8)))
        o_block, o_bed = mise_paint.block, mise_paint.mortar_bed

        def block(*a, **kw):
            r = o_block(*a, **kw)
            snap("block")
            return r

        def mortar_bed(*a, **kw):
            r = o_bed(*a, **kw)
            snap("mortar")
            return r
        mise_paint.block, mise_paint.mortar_bed = block, mortar_bed
        try:
            snap("empty")
            for r, strip in zip(rows, sheet.strips):
                cur["strip"] = strip.id
                started[r["row0"]:r["row1"]] = True
                rng = np.random.default_rng(sheets.strip_seed(sheet, strip, seed))
                v = F.view(r["row0"], r["row1"], rng)
                v.tiles = sheets.tile_layout(sheet, strip, seed)
                strip.build(v)
                snap("strip")
                log("  atlas strip %-12s done (%d snapshots)" % (strip.id, len(snaps)))
        finally:
            mise_paint.block, mise_paint.mortar_bed = o_block, o_bed
        h = F.h
        nrm = maps.normal_map(h, px, 1.0, directx=True)
        ao = maps.ao_horizon(h, px, dirs=8, max_m=0.10, strength=1.0)
        cav = maps.cavity(F, h, 0.004)
        cavb = maps.cavity(F, h, max(0.012, px * 3))
        alb = np.empty_like(F.alb)
        for r, strip in zip(rows, sheet.strips):
            sl = slice(r["row0"], r["row1"])
            kw = dict(themes.T()["paint"])
            kw.update(strip.paint or {})
            alb[sl], _ = maps.paint_pass(F.alb[sl], F.rough[sl], cavb[sl], ao[sl], **kw)
    secs = time.perf_counter() - t0
    hn = (h - h.min()) / max(float(h.max() - h.min()), 1e-9)

    def u8(a):
        a = np.asarray(a, np.float32)
        if a.ndim == 2:
            a = np.repeat(a[..., None], 3, -1)
        return (np.clip(a[::-1], 0, 1) * 255).astype(np.uint8)
    stages = {"height": u8(hn), "normal": u8(nrm), "ao": u8(ao), "cavity": u8(0.5 + 0.5 * cav),
              "authored": u8(F.alb), "final": u8(alb)}
    return {"rows": rows, "snaps": snaps, "stages": stages, "seconds": secs, "nx": nx, "ny": ny}


def ds_hex(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
