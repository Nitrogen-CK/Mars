// Warrens 3D mockup viewer. Reads window.MARS_LAYOUTS (layouts.js, made by make_layouts.py from data/*.json) and
// rebuilds each level the way build_warrens.py does: rasterize at 0.5 m (rooms, foyer pads and links walkable, the
// rest solid), then draws floors, walls, roofs, ramps, rails, crawl lintels, grates, ladders, lights and anchors.
// Metres in the data; three.js axes: x = east, y = up, z = south (so north is -z).
//
// Beyond build_warrens.py, every cell carries its own floor height, so a room, pocket or basin may sit at any z and
// an extraRamp lerps the height along its run (drawn as 0.5 m treads). The builder knows none of the additions below;
// they are proposals for it:
//   rooms[].poly   : [[x,y],...] polygon footprint instead of rect
//   rooms[].top    : ceiling height for this room (default mainTop / U.top for tallRooms)
//   rooms[].z      : any height; a room between the levels is drawn on the nearest level's grid
//   niches[]       : {id, rect|poly, z, family, note} dead-end pockets = sockets for flavour anchors (F, C, O, T, X, N, P)
//   extraRamps[]   : {id, a:[x,y,z], b:[x,y,z], width} sloped walk outside the plan graph
//   water[]        : {id, rect|poly, z, depth} a wade basin sunk `depth` below z (walkable, slow)
//   props[]        : {kind, at:[x,y,z], size:[sx,sy,sz], yaw, note} landmark dressing: pillar, stack, statue, root,
//                    sarcophagus, chimes, candles, plinth, bench, station
//   holes[].level  : 'main' | 'upper' | 'deep'
// v8 variant fields (all optional; drawn as overlays and summarised in the metrics, never rasterized):
//   instances[]    : {id, label, asset, z, rect|poly, ports:[{id, at:[x,y,z], width, kind}], note} proposed Level Instance tiles
//   views[]        : {id, from:[x,y,z], to:[x,y,z], label} sightlines to the landmark ("Well windows"); Walk can jump to one
//   transitions[]  : {id, at:[x,y,z], kind, label} the authored beat between two spaces
//   landmark       : {id, label, at:[x,y,z], faces:[{dir:'N'|'E'|'S'|'W', label}]}
//   notes          : {thesis, principles:[], changes:[], risks:[]} shown under "Variant notes"
//   shortcuts[].oneWay (default true), ladders[].oneWay (default false; labelled only when present)
//   links[].kind 'ladder' | 'lift' | 'drop' | 'ramp' : graph-only (costCm counts, nothing is stamped; a ramp's treads come from extraRamps[]); rooms from z -10 to +10
(function () {
  'use strict';
  const CELL = 0.5, SLAB = 0.4, DEEP_Z = -5.0, RAMP_START = 2.0, FOYER = 8.0, CRAWL_WIDTH = 1.5, CRAWL_HEIGHT = 1.3;
  const WALK = 4.2, SPRINT = 7.0, CROUCH = 2.2, EYE = 1.1, EYE_CROUCH = 0.75, STEP = 0.6;
  const LANTERN_HELD = 7.0, LANTERN_WORLD = 9.0;
  const COLORS = {
    floorMain: 0x4a565a, floorDeep: 0x2c3a40, floorUpper: 0x66706c, floorLow: 0x3f4a4e, floorCrawl: 0x5a4a3a, grate: 0x7d8a8f,
    wall: 0x232f36, ledge: 0x303d44, roof: 0x1a2328, ramp: 0x5d6b6f, rail: 0x8b9a9c, water: 0x2a6f86, hearth: 0xffb84a,
    spawn: 0xf2efe6, hunt: 0xd1352a, route: 0x557aa5, shortcut: 0x1fb8c9, forage: 0x3f8f3a, cache: 0xc49a25, omen: 0x8159b0,
    trav: 0x2f93ab, rest: 0x1f9a86, threat: 0xa54a35, trap: 0xe07b2f, pack: 0xd8c08a, lock: 0xe3c03a, crack: 0x6e5b48,
    prop: 0x6f7a7c, root: 0x6b4f2e, candles: 0xffd37a, station: 0xb08a5a, stack: 0xa89b84,
  };
  const LIGHT_KINDS = { // intensity, distance (gameplay radius), colour
    hearth: [45, 13, 0xffa84f], foyer: [14, 7, 0xffa060], dim: [10, 6.5, 0xffa66a], cold: [22, 16, 0x8cb3ff], shaft: [60, 20, 0xb3d9ff],
  };
  const GRAPH_ONLY = ['ladder', 'lift', 'drop', 'ramp'], LINK_KINDS = ['walk', 'stair', 'spiral'].concat(GRAPH_ONLY), V8_KEYS = ['instances', 'views', 'transitions', 'landmark', 'notes'];
  const FAMILY_NAMES = { S: 'spawn', H: 'hunt', R: 'route', F: 'forage', C: 'cache', O: 'omen', T: 'threat', X: 'trap', N: 'rest', L: 'trav', P: 'pack' };

  // ------------------------------------------------------------------ geometry helpers (ports of build_warrens.py)
  function dist(a, b) { return Math.hypot(a[0] - b[0], a[1] - b[1]); }
  function segParam(p, a, b) { const dx = b[0] - a[0], dy = b[1] - a[1], l2 = dx * dx + dy * dy; return l2 === 0 ? 0 : ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / l2; }
  function segDist(p, a, b) { const dx = b[0] - a[0], dy = b[1] - a[1], l2 = dx * dx + dy * dy; const t = l2 === 0 ? 0 : Math.max(0, Math.min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / l2)); return Math.hypot(p[0] - (a[0] + t * dx), p[1] - (a[1] + t * dy)); }
  function pointInPoly(p, poly) { let inside = false; for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) { const xi = poly[i][0], yi = poly[i][1], xj = poly[j][0], yj = poly[j][1]; if (((yi > p[1]) !== (yj > p[1])) && (p[0] < (xj - xi) * (p[1] - yi) / (yj - yi) + xi)) inside = !inside; } return inside; }
  function polyline(d, link) { const n = d.nodes; return [n[link.a].slice(0, 2)].concat((link.via || []).map(p => p.slice(0, 2)), [n[link.b].slice(0, 2)]); }
  function shapeContains(shape, p) { return shape.poly ? pointInPoly(p, shape.poly) : (shape.rect[0] <= p[0] && p[0] <= shape.rect[2] && shape.rect[1] <= p[1] && p[1] <= shape.rect[3]); }
  function shapeBounds(shape) { if (shape.rect) return shape.rect; const xs = shape.poly.map(p => p[0]), ys = shape.poly.map(p => p[1]); return [Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys)]; }
  function shapeCentre(shape) { const b = shapeBounds(shape); return [(b[0] + b[2]) / 2, (b[1] + b[3]) / 2]; }
  const levelOfZ = (z, U) => (z < -2.5 ? 'deep' : (U && z > 2.5 ? 'upper' : 'main'));

  class Grid {
    constructor(rect, fill, z) { this.x0 = rect[0]; this.y0 = rect[1]; this.nx = Math.round((rect[2] - rect[0]) / CELL); this.ny = Math.round((rect[3] - rect[1]) / CELL); this.c = new Array(this.nx * this.ny).fill(fill); this.top = new Float32Array(this.nx * this.ny); this.zf = new Float32Array(this.nx * this.ny).fill(z); this.z = z; }
    idx(i, j) { return j * this.nx + i; }
    centre(i, j) { return [this.x0 + (i + 0.5) * CELL, this.y0 + (j + 0.5) * CELL]; }
    get(i, j) { return (i < 0 || j < 0 || i >= this.nx || j >= this.ny) ? 'outside' : this.c[this.idx(i, j)]; }
    zAt(i, j) { return (i < 0 || j < 0 || i >= this.nx || j >= this.ny) ? this.z : this.zf[this.idx(i, j)]; }
    cellOf(p) { return [Math.floor((p[0] - this.x0) / CELL), Math.floor((p[1] - this.y0) / CELL)]; }
    at(p) { const [i, j] = this.cellOf(p); return this.get(i, j); }
    zOf(p) { const [i, j] = this.cellOf(p); return this.zAt(i, j); }
    set(i, j, value, z) { const k = this.idx(i, j); this.c[k] = value; if (z != null) this.zf[k] = z; }
    stampSegment(a, b, half, value, only, square, zfn) {
      const xa = Math.min(a[0], b[0]) - half, xb = Math.max(a[0], b[0]) + half, ya = Math.min(a[1], b[1]) - half, yb = Math.max(a[1], b[1]) + half;
      for (let j = Math.max(0, Math.floor((ya - this.y0) / CELL)); j < Math.min(this.ny, Math.floor((yb - this.y0) / CELL) + 1); j++)
        for (let i = Math.max(0, Math.floor((xa - this.x0) / CELL)); i < Math.min(this.nx, Math.floor((xb - this.x0) / CELL) + 1); i++) {
          const p = this.centre(i, j); const t = segParam(p, a, b);
          if (square && (t < 0 || t > 1)) continue;
          if (segDist(p, a, b) <= half && (!only || only.includes(this.c[this.idx(i, j)]))) this.set(i, j, value, zfn ? zfn(Math.max(0, Math.min(1, t))) : undefined);
        }
    }
    stampShape(shape, value, only, z) {
      const b = shapeBounds(shape);
      for (let j = Math.max(0, Math.floor((b[1] - this.y0) / CELL)); j < Math.min(this.ny, Math.floor((b[3] - this.y0) / CELL) + 1); j++)
        for (let i = Math.max(0, Math.floor((b[0] - this.x0) / CELL)); i < Math.min(this.nx, Math.floor((b[2] - this.x0) / CELL) + 1); i++) {
          if (shapeContains(shape, this.centre(i, j)) && (!only || only.includes(this.c[this.idx(i, j)]))) this.set(i, j, value, z);
        }
    }
    rects(pred) { // greedy merge of cells where pred(i,j) holds; returns [x0,y0,x1,y1] metres
      const used = new Uint8Array(this.nx * this.ny), out = [];
      for (let j = 0; j < this.ny; j++) for (let i = 0; i < this.nx; i++) {
        if (used[this.idx(i, j)] || !pred(i, j)) continue;
        let w = 1; while (i + w < this.nx && !used[this.idx(i + w, j)] && pred(i + w, j)) w++;
        let h = 1; outer: while (j + h < this.ny) { for (let k = 0; k < w; k++) if (used[this.idx(i + k, j + h)] || !pred(i + k, j + h)) break outer; h++; }
        for (let jj = j; jj < j + h; jj++) for (let ii = i; ii < i + w; ii++) used[this.idx(ii, jj)] = 1;
        out.push([this.x0 + i * CELL, this.y0 + j * CELL, this.x0 + (i + w) * CELL, this.y0 + (j + h) * CELL]);
      }
      return out;
    }
    rectsByZ(classes) { // {z: rects} for walkable classes, merged per floor height
      const keys = new Set(); for (let k = 0; k < this.c.length; k++) if (classes.includes(this.c[k])) keys.add(Math.round(this.zf[k] * 100) / 100);
      const out = {}; for (const z of keys) out[z] = this.rects((i, j) => classes.includes(this.c[this.idx(i, j)]) && Math.abs(this.zf[this.idx(i, j)] - z) < 0.005);
      return out;
    }
  }

  function rampsOf(d) {
    const out = [];
    for (const link of d.links) {
      if (link.kind !== 'stair') continue;
      const a = d.nodes[link.a], b = d.nodes[link.b];
      if ((a[2] < -2.5) === (b[2] < -2.5) && (a[2] > 2.5) === (b[2] > 2.5)) continue; // same level: treads, not a dive
      const [upper, lower] = a[2] > b[2] ? [a, b] : [b, a];
      const dx = lower[0] - upper[0], dy = lower[1] - upper[1], run = Math.hypot(dx, dy), ux = dx / run, uy = dy / run;
      const start = [upper[0] + ux * RAMP_START, upper[1] + uy * RAMP_START];
      const roof = d.rampRoofZ;
      const frac = roof == null ? 1 : Math.min(1, (upper[2] - roof) / (upper[2] - lower[2]) + 0.5 / (run - RAMP_START));
      const openEnd = [start[0] + (lower[0] - start[0]) * frac, start[1] + (lower[1] - start[1]) * frac];
      out.push({ id: link.a + '-' + link.b, upper: [upper[0], upper[1]], start, openEnd, end: [lower[0], lower[1]], top: upper[2], bottom: lower[2], width: link.width, yaw: Math.atan2(dy, dx), closedBy: link.closedBy });
    }
    return out;
  }

  // Rasterize every level. Returns {levels: {main, deep, upper}, ramps}
  function rasterize(d) {
    const U = d.upper, mainTop = U ? U.mainTop : 4.0, nodes = d.nodes, ramps = rampsOf(d);
    const fp = d.footprint;
    const grids = { main: new Grid(fp, 'solid', 0), deep: new Grid(d.deep, 'solid', DEEP_Z), upper: U ? new Grid(fp, 'solid', U.z) : null };
    const G = z => grids[levelOfZ(z, U)];
    const main = grids.main, deep = grids.deep, upper = grids.upper;
    if (U) for (const r of d.rooms) if (U.tallRooms.includes(r.id)) grids.upper.stampShape(r, 'void');
    const low = new Set((d.lowLinks || []).map(p => p.slice().sort().join('|')));
    // 1. plan walk links (a room, pocket, basin or foyer stamped later wins, so a link ending at an interior node never cuts a causeway)
    for (const link of d.links) {
      const za = nodes[link.a][2], zb = nodes[link.b][2];
      if (link.kind !== 'walk' || Math.abs(za - zb) > 0.01) continue;
      const g = G(za); if (!g) continue;
      const pts = polyline(d, link), isLow = low.has([link.a, link.b].sort().join('|'));
      for (let i = 1; i < pts.length; i++) g.stampSegment(pts[i - 1], pts[i], link.width / 2, isLow ? 'low' : 'floor', isLow ? ['solid', 'low'] : null, false, () => za);
    }
    // 2. rooms, pockets, water, foyer pads
    for (const r of d.rooms) { const g = G(r.z); if (g) g.stampShape(r, 'floor', null, r.z); }
    for (const n of (d.niches || [])) { const g = G(n.z || 0); if (g) g.stampShape(n, 'floor', null, n.z || 0); }
    const drained = new URLSearchParams(location.search).get('drained') === '1';
    for (const w of (d.water || [])) { const g = G(w.z || 0); const depth = (w.drainedBy && drained) ? 0.3 : (w.depth || 0.5); if (g) g.stampShape(w, 'floor', null, (w.z || 0) - depth); }
    for (const e of d.entrances) { const s = nodes[e.node]; const g = G(s[2]) || main; g.stampShape({ rect: [Math.max(fp[0], s[0] - FOYER / 2), Math.max(fp[1], s[1] - FOYER / 2), Math.min(fp[2], s[0] + FOYER / 2), Math.min(fp[3], s[1] + FOYER / 2)] }, 'floor', null, s[2]); }
    // 3. stairs inside one level: treads, stamped last so they cut the step down into a sunken room
    for (const link of d.links) {
      const za = nodes[link.a][2], zb = nodes[link.b][2];
      if (link.kind !== 'stair' || levelOfZ(za, U) !== levelOfZ(zb, U)) continue;
      const g = G(za); const pts = polyline(d, link); const total = pts.slice(1).reduce((s, q, i) => s + dist(pts[i], q), 0); let done = 0;
      for (let i = 1; i < pts.length; i++) { const seg = dist(pts[i - 1], pts[i]), d0 = done; g.stampSegment(pts[i - 1], pts[i], link.width / 2, 'floor', null, true, t => za + (zb - za) * (d0 + t * seg) / total); done += seg; }
    }
    for (const r of ramps) {
      main.stampSegment(r.upper, r.start, r.width / 2, 'floor', null, false, () => r.top);
      main.stampSegment(r.start, r.openEnd, r.width / 2, 'void', null, true);
      deep.stampSegment(r.upper, r.end, r.width / 2, 'floor', null, false, () => r.bottom);
    }
    for (const r of (d.extraRamps || [])) { // treads: the cell height lerps along the run on the level of its lower end
      const [hi, lo] = r.a[2] > r.b[2] ? [r.a, r.b] : [r.b, r.a];
      const g = G(lo[2]) || main; const gh = G(hi[2]);
      g.stampSegment(hi, lo, r.width / 2, 'floor', null, true, t => hi[2] + (lo[2] - hi[2]) * t);
      if (gh && gh !== g) gh.stampSegment(hi, lo, r.width / 2, 'void', null, true);
    }
    for (const c of d.crawls) { const g = G(c.z || 0) || main; g.stampSegment(c.a, c.b, CRAWL_WIDTH / 2, 'crawl', ['solid'], false, () => c.z || 0); }
    for (const w of (d.extraWalks || [])) {
      const g = grids[w.level || 'main']; if (!g) continue;
      if (w.rect) g.stampShape(w, 'floor', null, g.z); else for (let i = 1; i < w.pts.length; i++) g.stampSegment(w.pts[i - 1], w.pts[i], w.width / 2, 'floor', null, false, () => g.z);
    }
    for (const c of (d.cracks || [])) main.stampSegment(c.a, c.b, c.width / 2, 'crack', ['solid']);
    for (const h of (d.holes || [])) { const g = grids[h.level]; if (g) g.stampShape(h, h.kind === 'grate' ? 'grate' : 'void'); }
    if (U) { for (const p of U.platforms) upper.stampShape(p, 'floor', null, U.z); for (const w of U.walkways) for (let i = 1; i < w.pts.length; i++) upper.stampSegment(w.pts[i - 1], w.pts[i], w.width / 2, 'floor', null, false, () => U.z); for (const h of (d.holes || [])) if (h.level === 'upper') upper.stampShape(h, 'void'); }
    for (const p of (d.pillars || [])) { const g = grids[p.level]; if (g) g.stampShape(p, 'solid'); }

    // Ceiling height per cell.
    const tall = U ? d.rooms.filter(r => U.tallRooms.includes(r.id)) : [];
    for (let j = 0; j < main.ny; j++) for (let i = 0; i < main.nx; i++) {
      const k = main.idx(i, j), c = main.c[k], p = main.centre(i, j);
      let t = main.zf[k] + mainTop;
      for (const r of d.rooms) if (levelOfZ(r.z, U) === 'main' && r.top != null && shapeContains(r, p)) t = r.top;
      for (const r of tall) if (shapeContains(r, p)) t = U.top;
      if (c === 'low') t = main.zf[k] + (d.lowRoof || 2.2); if (c === 'crawl') t = main.zf[k] + CRAWL_HEIGHT;
      main.top[k] = t;
    }
    if (upper) for (let k = 0; k < upper.c.length; k++) upper.top[k] = upper.zf[k] > U.z + 1.0 ? Math.max(U.top, upper.zf[k] + U.top - U.z) : U.top; // a room above the Rafters keeps their headroom
    if (upper) for (const r of d.rooms) if (levelOfZ(r.z, U) === 'upper' && r.top != null) for (let k = 0; k < upper.c.length; k++) if (upper.c[k] === 'floor' && shapeContains(r, upper.centre(k % upper.nx, Math.floor(k / upper.nx)))) upper.top[k] = r.top;
    for (let k = 0; k < deep.c.length; k++) { const c = deep.c[k]; deep.top[k] = deep.zf[k] < DEEP_Z - 1.0 ? deep.zf[k] - SLAB - DEEP_Z : -SLAB; /* below the Undercroft: its headroom */ if (c === 'floor') { const [i, j] = [k % deep.nx, Math.floor(k / deep.nx)]; const p = deep.centre(i, j); const above = main.at(p); if (above === 'void') deep.top[k] = main.top[main.idx(...main.cellOf(p))] || mainTop; } }
    return { levels: { main: { grid: main, z: 0, name: 'Main floor' }, deep: { grid: deep, z: DEEP_Z, name: 'Undercroft' }, upper: upper ? { grid: upper, z: U.z, name: 'Rafters' } : null }, ramps, mainTop, warnings: renderWarnings(d, grids) };
  }

  // What the rasterizer cannot draw (it would otherwise drop it silently).
  function renderWarnings(d, grids) {
    const U = d.upper, out = [], rectOf = g => [g.x0, g.y0, g.x0 + g.nx * CELL, g.y0 + g.ny * CELL];
    const clipped = (shape, z, what) => {
      const lv = levelOfZ(z, U), g = grids[lv]; if (!g) { out.push(`${what} at z ${z}: no ${lv} grid`); return; }
      const b = shapeBounds(shape), r = rectOf(g);
      if (b[0] < r[0] - 0.01 || b[1] < r[1] - 0.01 || b[2] > r[2] + 0.01 || b[3] > r[3] + 0.01) out.push(`${what} at z ${z} runs outside the ${lv === 'deep' ? 'deep rect' : 'footprint'} [${r.join(', ')}]: clipped`);
    };
    for (const r of d.rooms) { if (Math.abs(r.z) > 10) out.push(`room ${r.id} at z ${r.z}: beyond ±10 m`); clipped(r, r.z, 'room ' + r.id); }
    for (const n of (d.niches || [])) clipped(n, n.z || 0, 'pocket ' + n.id);
    for (const l of d.links) {
      const a = d.nodes[l.a], b = d.nodes[l.b];
      if (!a || !b) { out.push(`link ${l.a}-${l.b}: missing node`); continue; }
      if (!LINK_KINDS.includes(l.kind)) out.push(`link ${l.a}-${l.b}: unknown kind '${l.kind}', not drawn`);
      else if (l.kind === 'walk' && Math.abs(a[2] - b[2]) > 0.01) out.push(`walk link ${l.a}-${l.b} climbs ${a[2]} → ${b[2]}: not drawn (make it a stair)`);
      if (GRAPH_ONLY.includes(l.kind) && l.costCm == null) out.push(`${l.kind} link ${l.a}-${l.b}: no costCm`);
    }
    return out;
  }

  // ------------------------------------------------------------------ metrics (port of the offline checker)
  function metrics(d) {
    const N = d.nodes, L = d.links;
    const rooms = d.rooms;
    const inRoom = (p, z) => rooms.find(r => Math.abs(r.z - z) < 2.6 && shapeContains(r, p));
    let tot = 0, corr = 0; const runs = [], spans = [];
    for (const l of L) {
      if (GRAPH_ONLY.includes(l.kind)) continue; // ladders, lifts, drops: graph links, not floor
      const z = N[l.a][2], zb = N[l.b][2], p = polyline(d, l); let run = 0, out = 0;
      for (let s = 1; s < p.length; s++) {
        const a = p[s - 1], b = p[s], n = 100, dl = dist(a, b) / n;
        for (let k = 0; k < n; k++) {
          const q = [a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n]; tot += dl;
          if (!inRoom(q, z) && !inRoom(q, zb)) { corr += dl; run += dl; out += dl; } else if (run > 0) { runs.push({ m: run, link: l.a + '-' + l.b }); run = 0; }
        }
      }
      if (run > 0) runs.push({ m: run, link: l.a + '-' + l.b });
      const ra = inRoom(N[l.a].slice(0, 2), z), rb = inRoom(N[l.b].slice(0, 2), zb);
      if (ra && rb && ra !== rb) spans.push({ m: out, link: l.a + '-' + l.b, rooms: [ra.label || ra.id, rb.label || rb.id] });
    }
    const adj = {};
    for (const l of L) { (adj[l.a] = adj[l.a] || []).push([l.b, l.costCm / 100, l]); (adj[l.b] = adj[l.b] || []).push([l.a, l.costCm / 100, l]); }
    const dij = (src, closed) => {
      const D = { [src]: 0 }, pq = [[0, src]];
      while (pq.length) { pq.sort((a, b) => a[0] - b[0]); const [c, u] = pq.shift(); if (c > D[u]) continue; for (const [v, w, l] of (adj[u] || [])) { if (closed && closed.includes(l.closedBy)) continue; if (c + w < (D[v] ?? 1e9)) { D[v] = c + w; pq.push([c + w, v]); } } }
      return D;
    };
    const targets = ['K'].concat(d.courts.map(c => c.node));
    const perEntrance = d.entrances.map(e => { const D = dij(e.node); return { id: e.anchorId, node: e.node, toK: D.K, toCourts: d.courts.map(c => ({ id: c.anchorId, m: D[c.node] })) }; });
    const ids = (d.groups[0] || { anchorIds: [] }).anchorIds, cap = (d.groups[0] || { maxClosed: 0 }).maxClosed;
    let combos = 0, valid = 0;
    const comb = (arr, k, start, cur) => { if (cur.length === k) { combos++; const ok = d.entrances.every(e => { const D = dij(e.node, cur); return targets.every(t => D[t] != null); }); if (ok) valid++; return; } for (let i = start; i < arr.length; i++) comb(arr, k, i + 1, cur.concat([arr[i]])); };
    for (let k = 0; k <= cap; k++) comb(ids, k, 0, []);
    const deg = {}; for (const l of L) { deg[l.a] = (deg[l.a] || 0) + 1; deg[l.b] = (deg[l.b] || 0) + 1; }
    const deadEnds = Object.keys(N).filter(k => (deg[k] || 0) === 1);
    const fp = d.footprint, area = (fp[2] - fp[0]) * (fp[3] - fp[1]);
    const roomArea = rooms.filter(r => Math.abs(r.z) < 2.5).reduce((s, r) => { const b = shapeBounds(r); return s + (b[2] - b[0]) * (b[3] - b[1]); }, 0);
    const wide = rooms.filter(r => { const b = shapeBounds(r); return Math.min(b[2] - b[0], b[3] - b[1]) > 2 * LANTERN_HELD; });
    const niches = d.niches || [];
    const byFamily = {}; for (const n of niches) byFamily[n.family] = (byFamily[n.family] || 0) + 1;
    const heights = new Set(rooms.map(r => r.z).concat(niches.map(n => n.z || 0), (d.water || []).map(w => (w.z || 0) - (w.depth || 0.5)), d.upper ? [d.upper.z] : []));
    // v8 variant summaries
    const views = d.views || [], beats = {}; for (const t of (d.transitions || [])) beats[t.kind] = (beats[t.kind] || 0) + 1;
    const facing = [...new Set(views.map(v => inRoom(v.from.slice(0, 2), v.from[2] || 0)).filter(Boolean))].map(r => r.label || r.id);
    const ways = { one: 0, two: 0 };
    for (const s of (d.shortcuts || [])) ways[s.oneWay === false ? 'two' : 'one']++;
    for (const l of (d.ladders || [])) ways[l.oneWay ? 'one' : 'two']++;
    for (const l of L) if (['drop', 'ladder', 'lift'].includes(l.kind)) ways[(l.oneWay != null ? l.oneWay : l.kind === 'drop') ? 'one' : 'two']++;
    const span = spans.length ? { n: spans.length, mean: spans.reduce((s, x) => s + x.m, 0) / spans.length, min: spans.reduce((a, b) => (b.m < a.m ? b : a)) } : null;
    const instances = d.instances || [];
    const v8 = { hasV8: V8_KEYS.some(k => d[k] != null), facing, beats, ways, spans, span, instances: instances.length, ports: instances.reduce((s, i) => s + (i.ports || []).length, 0), graphOnly: L.filter(l => GRAPH_ONLY.includes(l.kind)).length };
    return { v8, walked: tot, corridor: corr, share: corr / tot, runs: runs.filter(r => r.m > 12).sort((a, b) => b.m - a.m), perEntrance, combos, valid, deadEnds, area, roomShare: roomArea / area, rooms: rooms.length, wide, niches: niches.length, byFamily, heights: [...heights].sort((a, b) => a - b), footprint: [fp[2] - fp[0], fp[3] - fp[1]], props: (d.props || []).length, water: (d.water || []).length, ramps: (d.extraRamps || []).length };
  }

  // ------------------------------------------------------------------ scene build
  function start(THREE) {
    const layouts = window.MARS_LAYOUTS || [];
    const el = id => document.getElementById(id);
    const canvas = el('view');
    const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, preserveDrawingBuffer: true }); // headless screenshots read the buffer back
    renderer.setPixelRatio(Math.min(2, window.devicePixelRatio));
    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0x0b0d0e);
    const camera = new THREE.PerspectiveCamera(70, 1, 0.05, 600);
    const orthoCam = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 400);
    const hemi = new THREE.HemisphereLight(0x9fb6c2, 0x2a2420, 1.4);
    const amb = new THREE.AmbientLight(0xffffff, 0.35);
    scene.add(hemi, amb);
    const lantern = new THREE.PointLight(0xffb060, 0, LANTERN_HELD, 2);
    scene.add(lantern);
    const V = (x, y, z) => new THREE.Vector3(x, z, -y);

    const state = { layout: 0, mode: 'orbit', lighting: 'work', showRoofs: false, showLabels: true, showUpper: true, showDeep: true, showMain: true, showAnchors: true, showNiches: true, showProps: true, showInstances: true, showViews: true, showBeats: true, plan: false, lanternOnly: false, crouch: false };
    const orbit = { target: new THREE.Vector3(48, 0, -40), theta: -0.6, phi: 0.95, r: 110 };
    const fp = { pos: new THREE.Vector3(48, EYE, -40), yaw: Math.PI, pitch: 0, walked: 0 };
    const keys = {};
    let built = null, labels = [], placedLights = [];
    const world = new THREE.Group(); scene.add(world);

    const mat = {};
    const M = (color, opts) => new THREE.MeshLambertMaterial(Object.assign({ color }, opts || {}));
    for (const [k, c] of Object.entries(COLORS)) mat[k] = M(c);
    mat.roof = M(COLORS.roof, { side: THREE.DoubleSide });
    mat.water = new THREE.MeshLambertMaterial({ color: COLORS.water, transparent: true, opacity: 0.55 });
    mat.radius = new THREE.MeshBasicMaterial({ color: 0xffb060, transparent: true, opacity: 0.12, side: THREE.DoubleSide, depthWrite: false });

    function boxMesh(material, cx, cy, cz, sx, sy, sz, yaw) { const m = new THREE.Mesh(new THREE.BoxGeometry(sx, sz, sy), material); m.position.set(cx, cz, -cy); if (yaw) m.rotation.y = yaw; return m; }
    function mergeGeos(geos) {
      const flat = geos.map(g => g.index ? g.toNonIndexed() : g);
      let total = 0; for (const g of flat) total += g.attributes.position.count;
      const pos = new Float32Array(total * 3), nor = new Float32Array(total * 3);
      let off = 0;
      for (const ng of flat) { pos.set(ng.attributes.position.array, off * 3); nor.set(ng.attributes.normal.array, off * 3); off += ng.attributes.position.count; }
      const out = new THREE.BufferGeometry();
      out.setAttribute('position', new THREE.BufferAttribute(pos, 3)); out.setAttribute('normal', new THREE.BufferAttribute(nor, 3));
      return out;
    }
    function slabRects(group, material, rects, z0, z1) {
      const geos = [];
      for (const [x0, y0, x1, y1] of rects) { const g = new THREE.BoxGeometry(x1 - x0, z1 - z0, y1 - y0); g.translate((x0 + x1) / 2, (z0 + z1) / 2, -(y0 + y1) / 2); geos.push(g); }
      if (geos.length) group.add(new THREE.Mesh(mergeGeos(geos), material));
    }
    function slabByZ(group, material, byZ, thickness) { for (const [z, rects] of Object.entries(byZ)) slabRects(group, material, rects, +z - thickness, +z); }
    // Walls: for every walkable cell, a vertical quad against each blocking neighbour (floor to ceiling) and a ledge face
    // against a walkable neighbour that stands higher.
    function wallsOf(grid, walkable, blocking, ledgeMat) {
      const geos = [], ledges = [];
      const quad = (list, ax, ay, bx, by, z0, z1, di, dj) => { const h = z1 - z0; if (h <= 0.001) return; const g = new THREE.PlaneGeometry(CELL, h); if (dj !== 0) { g.rotateY(dj > 0 ? Math.PI : 0); g.translate((ax + bx) / 2, z0 + h / 2, -ay); } else { g.rotateY(di > 0 ? -Math.PI / 2 : Math.PI / 2); g.translate(ax, z0 + h / 2, -(ay + by) / 2); } list.push(g); };
      for (let j = 0; j < grid.ny; j++) for (let i = 0; i < grid.nx; i++) {
        const k = grid.idx(i, j), c = grid.c[k]; if (!walkable.includes(c)) continue;
        const z = grid.zf[k], top = grid.top[k], x0 = grid.x0 + i * CELL, y0 = grid.y0 + j * CELL;
        for (const [di, dj, ax, ay, bx, by] of [[0, -1, x0, y0, x0 + CELL, y0], [0, 1, x0, y0 + CELL, x0 + CELL, y0 + CELL], [-1, 0, x0, y0, x0, y0 + CELL], [1, 0, x0 + CELL, y0, x0 + CELL, y0 + CELL]]) {
          const n = grid.get(i + di, j + dj);
          if (blocking.includes(n)) quad(geos, ax, ay, bx, by, z, top, di, dj);
          else if (walkable.includes(n)) { const zn = grid.zAt(i + di, j + dj); if (zn > z + 0.02) quad(ledges, ax, ay, bx, by, z, zn, di, dj); }
        }
      }
      return [geos.length ? mergeGeos(geos) : null, ledges.length ? mergeGeos(ledges) : null];
    }
    function label(text, x, y, z, color, size) {
      const c = document.createElement('canvas'); const ctx = c.getContext('2d');
      const font = (size || 28) + 'px system-ui, sans-serif'; ctx.font = font;
      const w = Math.ceil(ctx.measureText(text).width) + 16; c.width = w; c.height = (size || 28) + 14;
      ctx.font = font; ctx.fillStyle = 'rgba(11,13,14,0.7)'; ctx.fillRect(0, 0, c.width, c.height);
      ctx.fillStyle = color || '#e3e5df'; ctx.textBaseline = 'middle'; ctx.fillText(text, 8, c.height / 2);
      const tex = new THREE.CanvasTexture(c); tex.minFilter = THREE.LinearFilter;
      const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, depthTest: false, transparent: true }));
      const k = 0.03 * ((size || 28) / 28);
      s.scale.set(c.width * k, c.height * k, 1); s.position.set(x, z, -y);
      s.userData.base = c.height * k; s.userData.aspect = c.width / c.height; s.userData.kind = size >= 30 ? 'room' : 'detail'; return s;
    }
    const hex = c => '#' + c.toString(16).padStart(6, '0');

    function build(d) {
      while (world.children.length) world.remove(world.children[0]);
      for (const l of placedLights) scene.remove(l); placedLights = []; labels = [];
      const R = rasterize(d); built = { d, R, groups: {} };
      const U = d.upper, nodes = d.nodes;
      const G = name => { const g = new THREE.Group(); g.name = name; world.add(g); built.groups[name] = g; return g; };
      const gMain = G('main'), gDeep = G('deep'), gUpper = G('upper'), gRoof = G('roof'), gAnch = G('anchors'), gNiche = G('niches'), gProps = G('props'), gLab = G('labels');
      const main = R.levels.main.grid, deep = R.levels.deep.grid, upper = R.levels.upper ? R.levels.upper.grid : null;
      // main floor (per height), low tunnels, crawls, lintels
      slabByZ(gMain, mat.floorMain, main.rectsByZ(['floor', 'grate']), SLAB);
      slabByZ(gMain, mat.floorLow, main.rectsByZ(['low']), SLAB);
      slabByZ(gMain, mat.floorCrawl, main.rectsByZ(['crawl']), SLAB);
      for (const [z, rects] of Object.entries(main.rectsByZ(['low']))) slabRects(gMain, mat.wall, rects, +z + (d.lowRoof || 2.2), +z + R.mainTop);
      for (const [z, rects] of Object.entries(main.rectsByZ(['crawl']))) slabRects(gMain, mat.wall, rects, +z + CRAWL_HEIGHT, +z + R.mainTop);
      const cr = (d.cracks || [])[0];
      if (cr) { const rects = main.rects((i, j) => main.c[main.idx(i, j)] === 'crack'); slabRects(gMain, mat.crack, rects, -SLAB, cr.sill); slabRects(gMain, mat.crack, rects, cr.head, R.mainTop); }
      let [wm, lm] = wallsOf(main, ['floor', 'low', 'crawl', 'grate'], ['solid', 'outside', 'crack']);
      if (wm) gMain.add(new THREE.Mesh(wm, mat.wall)); if (lm) gMain.add(new THREE.Mesh(lm, mat.ledge));
      for (const h of (d.holes || [])) if (h.kind === 'grate') { const [x0, y0, x1, y1] = h.rect, z = h.level === 'deep' ? DEEP_Z : (h.level === 'upper' ? U.z : 0); const n = Math.round((x1 - x0) / 0.25); for (let k = 0; k <= n; k++) gMain.add(boxMesh(mat.grate, x0 + k * (x1 - x0) / n, (y0 + y1) / 2, z - 0.05, 0.06, y1 - y0, 0.1)); for (const y of [y0, y1]) gMain.add(boxMesh(mat.grate, (x0 + x1) / 2, y, z - 0.05, x1 - x0, 0.06, 0.1)); }
      // roofs over the main floor, by ceiling height
      const tops = new Set(); for (let k = 0; k < main.c.length; k++) if (['floor', 'grate'].includes(main.c[k])) tops.add(main.top[k]);
      for (const t of tops) slabRects(gRoof, mat.roof, main.rects((i, j) => ['floor', 'grate'].includes(main.c[main.idx(i, j)]) && main.top[main.idx(i, j)] === t), t, t + 0.3);
      // deep
      slabByZ(gDeep, mat.floorDeep, deep.rectsByZ(['floor', 'grate']), SLAB);
      const [wd, ld] = wallsOf(deep, ['floor', 'grate'], ['solid', 'outside']);
      if (wd) gDeep.add(new THREE.Mesh(wd, mat.wall)); if (ld) gDeep.add(new THREE.Mesh(ld, mat.ledge));
      slabRects(gRoof, mat.roof, deep.rects((i, j) => deep.c[deep.idx(i, j)] === 'floor' && deep.top[deep.idx(i, j)] === -SLAB), -SLAB - 0.001, -SLAB + 0.2);
      const sunk = new Set(); for (let k = 0; k < deep.c.length; k++) if (deep.c[k] === 'floor' && deep.zf[k] < DEEP_Z - 1.0) sunk.add(deep.top[k]);
      for (const t of sunk) slabRects(gRoof, mat.roof, deep.rects((i, j) => deep.c[deep.idx(i, j)] === 'floor' && deep.zf[deep.idx(i, j)] < DEEP_Z - 1.0 && deep.top[deep.idx(i, j)] === t), t, t + 0.3);
      // trench walls: the main floor's edge down to the deep where a main cell is void over the deep
      const voidWalls = []; for (let j = 0; j < main.ny; j++) for (let i = 0; i < main.nx; i++) { if (main.c[main.idx(i, j)] !== 'void') continue; const x0 = main.x0 + i * CELL, y0 = main.y0 + j * CELL; for (const [di, dj, ax, ay, bx, by] of [[0, -1, x0, y0, x0 + CELL, y0], [0, 1, x0, y0 + CELL, x0 + CELL, y0 + CELL], [-1, 0, x0, y0, x0, y0 + CELL], [1, 0, x0 + CELL, y0, x0 + CELL, y0 + CELL]]) { const n = main.get(i + di, j + dj); if (n === 'void') continue; const zTop = ['floor', 'low', 'grate', 'crawl'].includes(n) ? main.zAt(i + di, j + dj) : 0; const p = main.centre(i, j); const zBot = deep.at(p) === 'floor' ? deep.zOf(p) : DEEP_Z; const g = new THREE.PlaneGeometry(CELL, zTop - zBot); if (dj !== 0) { g.rotateY(dj > 0 ? Math.PI : 0); g.translate((ax + bx) / 2, (zTop + zBot) / 2, -ay); } else { g.rotateY(di > 0 ? -Math.PI / 2 : Math.PI / 2); g.translate(ax, (zTop + zBot) / 2, -(ay + by) / 2); } voidWalls.push(g); } }
      if (voidWalls.length) gDeep.add(new THREE.Mesh(mergeGeos(voidWalls), mat.wall));
      // upper
      if (upper) {
        slabByZ(gUpper, mat.floorUpper, upper.rectsByZ(['floor']), U.z - R.mainTop);
        const [wu] = wallsOf(upper, ['floor'], ['solid', 'outside']); if (wu) gUpper.add(new THREE.Mesh(wu, mat.wall));
        const tallWalls = []; for (let j = 0; j < upper.ny; j++) for (let i = 0; i < upper.nx; i++) { if (upper.c[upper.idx(i, j)] !== 'void') continue; const x0 = upper.x0 + i * CELL, y0 = upper.y0 + j * CELL; for (const [di, dj, ax, ay, bx, by] of [[0, -1, x0, y0, x0 + CELL, y0], [0, 1, x0, y0 + CELL, x0 + CELL, y0 + CELL], [-1, 0, x0, y0, x0, y0 + CELL], [1, 0, x0 + CELL, y0, x0 + CELL, y0 + CELL]]) { const n = upper.get(i + di, j + dj); if (n !== 'solid' && n !== 'outside') continue; const g = new THREE.PlaneGeometry(CELL, U.top - R.mainTop); if (dj !== 0) { g.rotateY(dj > 0 ? Math.PI : 0); g.translate((ax + bx) / 2, (U.top + R.mainTop) / 2, -ay); } else { g.rotateY(di > 0 ? -Math.PI / 2 : Math.PI / 2); g.translate(ax, (U.top + R.mainTop) / 2, -(ay + by) / 2); } tallWalls.push(g); } }
        if (tallWalls.length) gUpper.add(new THREE.Mesh(mergeGeos(tallWalls), mat.wall));
        const heads = (d.ladders || []).filter(l => Math.abs(l.baseZ + l.height - U.z) < 0.01).map(l => l.at);
        const gaps = (U.railGaps || []).map(g => [g.a, g.b]);
        const rg = [];
        for (let j = 0; j < upper.ny; j++) for (let i = 0; i < upper.nx; i++) {
          if (upper.c[upper.idx(i, j)] !== 'floor') continue;
          const x0 = upper.x0 + i * CELL, y0 = upper.y0 + j * CELL;
          for (const [di, dj, mx, my, sx, sy] of [[0, -1, x0 + CELL / 2, y0, CELL, 0.1], [0, 1, x0 + CELL / 2, y0 + CELL, CELL, 0.1], [-1, 0, x0, y0 + CELL / 2, 0.1, CELL], [1, 0, x0 + CELL, y0 + CELL / 2, 0.1, CELL]]) {
            if (upper.get(i + di, j + dj) !== 'void') continue;
            if (heads.some(h => Math.hypot(mx - h[0], my - h[1]) < 0.9) || gaps.some(([a, b]) => segDist([mx, my], a, b) < 0.3)) continue;
            const g = new THREE.BoxGeometry(sx, 1.0, sy); g.translate(mx, U.z + 0.5, -my); rg.push(g);
          }
        }
        if (rg.length) gUpper.add(new THREE.Mesh(mergeGeos(rg), mat.rail));
        slabRects(gRoof, mat.roof, upper.rects((i, j) => upper.c[upper.idx(i, j)] !== 'solid' && upper.top[upper.idx(i, j)] === U.top), U.top, U.top + 0.3);
        const raised = new Set(); for (let k = 0; k < upper.c.length; k++) if (upper.c[k] !== 'solid' && upper.top[k] !== U.top) raised.add(upper.top[k]);
        for (const t of raised) slabRects(gRoof, mat.roof, upper.rects((i, j) => upper.c[upper.idx(i, j)] !== 'solid' && upper.top[upper.idx(i, j)] === t), t, t + 0.3);
      }
      // rails round a main-floor hole (a well) and round a sunken edge deeper than a step
      const wellRails = []; for (let j = 0; j < main.ny; j++) for (let i = 0; i < main.nx; i++) { if (main.c[main.idx(i, j)] !== 'floor') continue; const x0 = main.x0 + i * CELL, y0 = main.y0 + j * CELL; for (const [di, dj, mx, my, sx, sy] of [[0, -1, x0 + CELL / 2, y0, CELL, 0.1], [0, 1, x0 + CELL / 2, y0 + CELL, CELL, 0.1], [-1, 0, x0, y0 + CELL / 2, 0.1, CELL], [1, 0, x0 + CELL, y0 + CELL / 2, 0.1, CELL]]) { const n = main.get(i + di, j + dj); const hole = (d.holes || []).find(h => h.level === 'main' && h.kind !== 'grate' && shapeContains(h, [mx + di * 0.25, my + dj * 0.25])); if (n !== 'void' || !hole) continue; const rh = hole.rail != null ? hole.rail : 1.0; const g = new THREE.BoxGeometry(sx, rh, sy); g.translate(mx, main.zAt(i, j) + rh / 2, -my); wellRails.push(g); } }
      if (wellRails.length) gMain.add(new THREE.Mesh(mergeGeos(wellRails), mat.rail));
      // ramps (plan stairs)
      for (const r of R.ramps) {
        const length = dist(r.start, r.end), drop = r.top - r.bottom, run = Math.hypot(length, drop);
        const m = boxMesh(mat.ramp, (r.start[0] + r.end[0]) / 2, (r.start[1] + r.end[1]) / 2, (r.top + r.bottom) / 2 - SLAB / 2, run, r.width, SLAB);
        m.rotation.set(0, -r.yaw, 0); m.rotateZ(Math.atan2(drop, length)); gDeep.add(m);
      }
      // ladders
      for (const l of (d.ladders || [])) { const g = new THREE.Group(); const a = l.yaw * Math.PI / 180; for (let k = 0; k <= l.height / 0.4; k++) g.add(boxMesh(mat.trav, 0, 0, k * 0.4, 0.08, 0.9, 0.06)); g.add(boxMesh(mat.trav, 0, -0.45, l.height / 2, 0.08, 0.08, l.height)); g.add(boxMesh(mat.trav, 0, 0.45, l.height / 2, 0.08, 0.08, l.height)); g.position.set(l.at[0], l.baseZ, -l.at[1]); g.rotation.y = -a; gAnch.add(g); labels.push(label('ladder' + (l.oneWay == null ? '' : (l.oneWay ? ' one-way' : ' two-way')) + (l.kind === 'kick' ? ' (raised until kicked)' : '') + ': ' + (l.purpose || l.note || l.id), l.at[0], l.at[1], l.baseZ + l.height + 0.5, l.kind === 'kick' ? '#ff7ad9' : hex(COLORS.trav), 20)); }
      // hearth
      const k = nodes[d.hearth]; gMain.add(boxMesh(mat.hearth, k[0], k[1], k[2] + 0.5, 1.5, 1.5, 1.0));
      const hl = new THREE.PointLight(0xffa84f, LIGHT_KINDS.hearth[0], 13, 2); hl.position.copy(V(k[0], k[1], k[2] + 2)); scene.add(hl); placedLights.push(hl);
      labels.push(label('K hearth', k[0], k[1], k[2] + 3.2, hex(COLORS.hearth)));
      // water surfaces
      for (const w of (d.water || [])) { const b = shapeBounds(w); const z = (w.z || 0) - 0.1; const m = new THREE.Mesh(new THREE.PlaneGeometry(b[2] - b[0], b[3] - b[1]), mat.water); m.rotation.x = -Math.PI / 2; m.position.set((b[0] + b[2]) / 2, z, -(b[1] + b[3]) / 2); gMain.add(m); labels.push(label('water ' + (w.note || w.id) + ' (' + ((w.depth || 0.5) > 1 ? 'IMPASSABLE ' : 'wade ') + (w.depth || 0.5) + ' m' + (w.drainedBy ? ', drained by ' + w.drainedBy : '') + ')', (b[0] + b[2]) / 2, (b[1] + b[3]) / 2, (w.z || 0) + 1.2, '#7fc4d8', 20)); }
      // lights
      for (const lt of d.lights) { const [I, D, C] = LIGHT_KINDS[lt.kind] || LIGHT_KINDS.dim; const pl = new THREE.PointLight(C, I, D, 2); pl.position.copy(V(lt.at[0], lt.at[1], lt.at[2])); scene.add(pl); placedLights.push(pl); const s = new THREE.Mesh(new THREE.SphereGeometry(0.2, 8, 6), new THREE.MeshBasicMaterial({ color: C })); s.position.copy(pl.position); gAnch.add(s); }
      for (const e of d.entrances) { const s = nodes[e.node]; const pl = new THREE.PointLight(0xffa060, LIGHT_KINDS.foyer[0], 7, 2); pl.position.copy(V(s[0], s[1], s[2] + 2.6)); scene.add(pl); placedLights.push(pl); }
      // anchors: S (foyer: 4 capsules + pack), H (court disc + home radius), R (bars at the anchor position)
      const closers = {}; for (const l of d.links) if (l.closedBy) closers[l.closedBy] = l;
      const rampOf = {}; for (const r of R.ramps) if (r.closedBy) rampOf[r.closedBy] = r;
      for (const a of d.anchors) {
        if (a.family === 'R') {
          const link = closers[a.id]; if (!link) continue;
          let at = a.at, yaw, z = nodes[link.a][2];
          if (rampOf[a.id]) { const r = rampOf[a.id]; at = r.start; yaw = r.yaw; z = r.top; }
          else { const pts = polyline(d, link); let best = null, bd = 1e9; for (let s = 1; s < pts.length; s++) { const dd = segDist(a.at, pts[s - 1], pts[s]); if (dd < bd) { bd = dd; best = [pts[s - 1], pts[s]]; } } yaw = Math.atan2(best[1][1] - best[0][1], best[1][0] - best[0][0]); }
          const bars = new THREE.Group(); const span = link.width;
          for (let b = -span / 2 + 0.25; b <= span / 2; b += 0.5) bars.add(boxMesh(mat.route, 0, b, 1.5, 0.1, 0.1, 3.0));
          bars.add(boxMesh(mat.route, 0, 0, 3.0, 0.12, span, 0.12));
          bars.position.set(at[0], z, -at[1]); bars.rotation.y = -yaw; gAnch.add(bars);
          labels.push(label(a.id + ' gate', at[0], at[1], z + 3.6, hex(COLORS.route), 22));
        } else if (a.family === 'H') {
          const n = nodes[a.node]; const disc = new THREE.Mesh(new THREE.CircleGeometry(10, 48), new THREE.MeshBasicMaterial({ color: COLORS.hunt, transparent: true, opacity: 0.12, depthWrite: false })); disc.rotation.x = -Math.PI / 2; disc.position.set(n[0], n[2] + 0.03, -n[1]); gAnch.add(disc);
          gAnch.add(boxMesh(mat.hunt, n[0], n[1], n[2] + 0.6, 1.2, 1.2, 1.2)); labels.push(label(a.id + ' hunt court (home 10 m)', n[0], n[1], n[2] + 2.4, hex(COLORS.hunt), 24));
        } else if (a.family === 'S') {
          const n = nodes[a.node]; for (const [ox, oy] of [[-1.2, -1.2], [1.2, -1.2], [-1.2, 1.2], [1.2, 1.2]]) { const c = new THREE.Mesh(new THREE.CapsuleGeometry(0.39, 0.72, 4, 8), mat.spawn); c.position.set(n[0] + ox, n[2] + 0.75, -(n[1] + oy)); gAnch.add(c); }
          gAnch.add(boxMesh(mat.pack, n[0] - 2.8, n[1], n[2] + 0.5, 0.8, 0.6, 1.0)); labels.push(label(a.id + ' entrance', n[0], n[1], n[2] + 3, hex(COLORS.spawn), 24));
        }
      }
      for (const sc of (d.shortcuts || [])) { const bars = new THREE.Group(); const span = sc.spanCm / 100; for (let b = -span / 2 + 0.25; b <= span / 2; b += 0.5) bars.add(boxMesh(mat.shortcut, 0, b, 1.5, 0.1, 0.1, 3.0)); bars.add(boxMesh(mat.shortcut, sc.leverSide * 1.2, span / 2 + 0.3, 1.0, 0.2, 0.2, 1.2)); bars.position.set(sc.at[0], 0, -sc.at[1]); bars.rotation.y = -sc.yaw * Math.PI / 180; gAnch.add(bars); labels.push(label(sc.id + (sc.oneWay === false ? ' two-way' : ' one-way') + ' (lever ' + (sc.leverSide > 0 ? 'ahead' : 'behind') + ')', sc.at[0], sc.at[1], 3.6, hex(COLORS.shortcut), 22)); }
      for (const lk of (d.locks || [])) { const dz = lk.door.level === 'deep' ? DEEP_Z : 0; const bars = new THREE.Group(); const span = lk.door.spanCm / 100; for (let b = -span / 2 + 0.25; b <= span / 2; b += 0.5) bars.add(boxMesh(mat.lock, 0, b, 1.5, 0.1, 0.1, 3.0)); bars.position.set(lk.door.at[0], dz, -lk.door.at[1]); bars.rotation.y = -lk.door.yaw * Math.PI / 180; gAnch.add(bars); labels.push(label(lk.id + ' door (' + lk.key + ' key)', lk.door.at[0], lk.door.at[1], dz + 3.6, hex(COLORS.lock), 22)); gAnch.add(boxMesh(mat.lock, lk.keyAt[0], lk.keyAt[1], lk.keyAt[2] + 0.2, 0.5, 0.3, 0.2)); labels.push(label(lk.key + ' key', lk.keyAt[0], lk.keyAt[1], lk.keyAt[2] + 1.2, hex(COLORS.lock), 22)); }
      for (const c of d.crawls) { const m = [(c.a[0] + c.b[0]) / 2, (c.a[1] + c.b[1]) / 2]; labels.push(label('crawl 1.3 m' + (c.packFits === false ? ' (no pack)' : '') + (c.purpose ? ': ' + c.purpose : ''), m[0], m[1], (c.z || 0) + 2.0, hex(COLORS.floorCrawl), 20)); }
      for (const g of (U ? (U.railGaps || []) : [])) labels.push(label('drop', (g.a[0] + g.b[0]) / 2, (g.a[1] + g.b[1]) / 2, U.z + 1.6, '#ff8a7a', 20));
      for (const r of d.rooms) { if (r.label === '') continue; const c = shapeCentre(r); labels.push(label(r.label || r.id, c[0], c[1], r.z + 3.2, '#e3e5df', 30)); }
      for (const n of (d.niches || [])) { const fam = FAMILY_NAMES[n.family] || 'prop'; const c = shapeCentre(n); const z = n.z || 0; const m = new THREE.Mesh(new THREE.CylinderGeometry(0.5, 0.5, 0.4, 12), mat[fam] || mat.prop); m.position.set(c[0], z + 0.2, -c[1]); gNiche.add(m); labels.push(label((n.family || '?') + ' ' + (n.note || n.id), c[0], c[1], z + 1.6, hex(COLORS[fam] || COLORS.prop), 20)); const b = shapeBounds(n); const pad = new THREE.Mesh(new THREE.PlaneGeometry(b[2] - b[0], b[3] - b[1]), new THREE.MeshBasicMaterial({ color: COLORS[fam] || COLORS.prop, transparent: true, opacity: 0.18, depthWrite: false })); pad.rotation.x = -Math.PI / 2; pad.position.set((b[0] + b[2]) / 2, z + 0.02, -(b[1] + b[3]) / 2); gNiche.add(pad); }
      for (const p of (d.props || [])) {
        const s = p.size || [1, 1, 2], z = p.at[2] || 0, yaw = (p.yaw || 0) * Math.PI / 180;
        let m;
        if (p.kind === 'root') { m = new THREE.Mesh(new THREE.CylinderGeometry(s[0] / 2 * 0.5, s[0] / 2, s[2], 7), mat.root); m.position.set(p.at[0], z + s[2] / 2, -p.at[1]); }
        else if (p.kind === 'candles') { m = new THREE.Mesh(new THREE.CylinderGeometry(s[0] / 2, s[0] / 2, s[2], 8), new THREE.MeshBasicMaterial({ color: COLORS.candles })); m.position.set(p.at[0], z + s[2] / 2, -p.at[1]); } // unlit glow, no point light: the software renderer used for screenshots fails past ~16 lights
        else if (p.kind === 'statue') { m = new THREE.Group(); m.add(boxMesh(mat.prop, 0, 0, s[2] * 0.25, s[0], s[1], s[2] * 0.5)); const h = new THREE.Mesh(new THREE.ConeGeometry(s[0] * 0.35, s[2] * 0.5, 6), mat.prop); h.position.y = s[2] * 0.75; m.add(h); m.position.set(p.at[0], z, -p.at[1]); m.rotation.y = -yaw; }
        else if (p.kind === 'chimes') { m = new THREE.Group(); for (let i = -1; i <= 1; i++) { const c = boxMesh(mat.trap, i * s[0] / 3, 0, s[2] * 0.55, 0.15, 0.15, s[2] * 0.6); m.add(c); } m.add(boxMesh(mat.trap, 0, 0, s[2], s[0], 0.1, 0.1)); m.position.set(p.at[0], z, -p.at[1]); m.rotation.y = -yaw; }
        else { const mm = { pillar: mat.prop, stack: mat.stack, sarcophagus: mat.prop, plinth: mat.pack, bench: mat.station, station: mat.station }[p.kind] || mat.prop; m = boxMesh(mm, p.at[0], p.at[1], z + s[2] / 2, s[0], s[1], s[2], -yaw); }
        gProps.add(m);
        if (p.note) labels.push(label(p.kind + ': ' + p.note, p.at[0], p.at[1], z + s[2] + 0.6, '#c9d0cc', 18));
      }
      for (const pz of (d.puzzles || [])) { // {id, kind, at:[x,y,z], needsAt:[x,y,z], note}: the thing and what it needs, elsewhere
        const col = 0xff7ad9; const m1 = boxMesh(new THREE.MeshBasicMaterial({ color: col }), pz.at[0], pz.at[1], pz.at[2] + 0.8, 0.5, 0.5, 1.6); gNiche.add(m1);
        labels.push(label('LOCK ' + pz.id + ': ' + pz.kind, pz.at[0], pz.at[1], pz.at[2] + 2.6, '#ff7ad9', 22));
        if (pz.needsAt) { const m2 = new THREE.Mesh(new THREE.OctahedronGeometry(0.5), new THREE.MeshBasicMaterial({ color: col })); m2.position.set(pz.needsAt[0], pz.needsAt[2] + 1.0, -pz.needsAt[1]); gNiche.add(m2); labels.push(label('KEY ' + pz.id + (pz.needsNote ? ': ' + pz.needsNote : ''), pz.needsAt[0], pz.needsAt[1], pz.needsAt[2] + 2.4, '#ff7ad9', 22));
          const geo = new THREE.BufferGeometry().setFromPoints([V(pz.at[0], pz.at[1], pz.at[2] + 1.6), V(pz.needsAt[0], pz.needsAt[1], pz.needsAt[2] + 1.6)]); gNiche.add(new THREE.Line(geo, new THREE.LineDashedMaterial({ color: col, dashSize: 1, gapSize: 0.6 }))); gNiche.children[gNiche.children.length - 1].computeLineDistances(); }
      }
      for (const l of labels) gLab.add(l);
      overlays(d, G('instances'), G('views'), G('beats'));
      built.ring = new THREE.Mesh(new THREE.RingGeometry(LANTERN_HELD - 0.08, LANTERN_HELD, 64), mat.radius); built.ring.rotation.x = -Math.PI / 2; built.ring.visible = false; world.add(built.ring);
      applyToggles(); updateMetrics(d); placeCameraForLayout(d);
    }

    // v8 overlays: Level Instance tiles + ports, Well-window sightlines, transition beats, the landmark and its faces.
    // Lines ignore depth so a tile or a sightline under a floor still reads in Plan; their labels follow the labels toggle too.
    function overlays(d, gInst, gViews, gBeats) {
      const olabel = (group, text, x, y, z, color, size) => { const s = label(text, x, y, z, color, size); s.userData.overlay = true; labels.push(s); group.add(s); return s; };
      const line = (group, pts, color, dashed) => { const g = new THREE.BufferGeometry().setFromPoints(pts.map(p => V(...p))); const m = dashed ? new THREE.LineDashedMaterial({ color, dashSize: 1.2, gapSize: 0.7, depthTest: false, transparent: true }) : new THREE.LineBasicMaterial({ color, depthTest: false, transparent: true }); const o = new (dashed === 'loop' ? THREE.LineLoop : THREE.Line)(g, m); if (dashed) o.computeLineDistances(); o.renderOrder = 5; group.add(o); return o; };
      (d.instances || []).forEach((inst, i) => {
        const col = new THREE.Color().setHSL((i * 0.618 + 0.08) % 1, 0.7, 0.62), z = inst.z || 0, pts = inst.poly || [[inst.rect[0], inst.rect[1]], [inst.rect[2], inst.rect[1]], [inst.rect[2], inst.rect[3]], [inst.rect[0], inst.rect[3]]];
        line(gInst, pts.map(p => [p[0], p[1], z + 0.08]), col, 'loop');
        const fill = new THREE.Mesh(new THREE.ShapeGeometry(new THREE.Shape(pts.map(p => new THREE.Vector2(p[0], p[1])))), new THREE.MeshBasicMaterial({ color: col, transparent: true, opacity: 0.1, depthWrite: false, side: THREE.DoubleSide }));
        fill.rotation.x = -Math.PI / 2; fill.position.y = z + 0.05; gInst.add(fill);
        const c = shapeCentre(inst); olabel(gInst, (inst.label || inst.id) + (inst.asset && inst.asset !== (inst.label || inst.id) ? ' · ' + inst.asset : '') + ' (z ' + z + ')', c[0], c[1], z + 2.2, '#' + col.getHexString(), 24);
        for (const pt of (inst.ports || [])) { const w = Math.max(0.6, Math.min(2, (pt.width || 2) / 2)); gInst.add(boxMesh(new THREE.MeshBasicMaterial({ color: col }), pt.at[0], pt.at[1], (pt.at[2] || 0) + 0.15, w, w, 0.3)); olabel(gInst, pt.id + (pt.kind ? ' ' + pt.kind : ''), pt.at[0], pt.at[1], (pt.at[2] || 0) + 1.0, '#' + col.getHexString(), 16); }
      });
      const cyan = 0xa8eef5;
      for (const v of (d.views || [])) {
        const a = [v.from[0], v.from[1], (v.from[2] || 0) + EYE], b = v.to.slice(0, 2).concat([v.to[2] || 0]);
        line(gViews, [a, b], cyan, true);
        const dir = V(...b).sub(V(...a)).normalize(), cone = new THREE.Mesh(new THREE.ConeGeometry(0.45, 1.4, 10), new THREE.MeshBasicMaterial({ color: cyan, depthTest: false, transparent: true }));
        cone.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir); cone.position.copy(V(...b)).addScaledVector(dir, -0.7); cone.renderOrder = 5; gViews.add(cone);
        gViews.add(boxMesh(new THREE.MeshBasicMaterial({ color: cyan }), a[0], a[1], a[2] - 0.2, 0.4, 0.4, 0.4));
        olabel(gViews, 'view ' + v.id + (v.label ? ': ' + v.label : ''), a[0], a[1], a[2] + 1.0, '#a8eef5', 20);
      }
      const BEAT = { turn: 0xd9c27a, stair: 0xdc8139, squeeze: 0xd17fb8, bridge: 0x9fd07a, reveal: 0xffe08a, drop: 0xff8a7a, lift: 0x8cb3ff, ladder: 0x2f93ab };
      for (const t of (d.transitions || [])) {
        const col = BEAT[t.kind] || 0xe3e5df, z = t.at[2] || 0, m = new THREE.Mesh(new THREE.OctahedronGeometry(0.55), new THREE.MeshBasicMaterial({ color: col }));
        m.scale.set(1, 1.5, 1); m.position.copy(V(t.at[0], t.at[1], z + 0.9)); gBeats.add(m);
        olabel(gBeats, t.kind + (t.label ? ': ' + t.label : ''), t.at[0], t.at[1], z + 2.1, hex(col), 18);
      }
      const lm = d.landmark;
      if (lm) {
        const z = lm.at[2] || 0, OFF = { N: [0, 8], E: [8, 0], S: [0, -8], W: [-8, 0] };
        labels.push(label('★ ' + (lm.label || lm.id), lm.at[0], lm.at[1], z + 5, '#ffd27a', 34)); built.groups.labels.add(labels[labels.length - 1]);
        for (const f of (lm.faces || [])) { const o = OFF[f.dir]; if (!o) continue; const s = label(f.dir + ' face: ' + f.label, lm.at[0] + o[0], lm.at[1] + o[1], z + 3, '#ffd27a', 22); labels.push(s); built.groups.labels.add(s); }
      }
    }

    function placeCameraForLayout(d) { const f = d.footprint; orbit.target.set((f[0] + f[2]) / 2, 0, -(f[1] + f[3]) / 2); orbit.r = Math.max(f[2] - f[0], f[3] - f[1]) * 1.2; const k = d.nodes[d.hearth]; fp.pos.set(k[0] + 3, EYE, -k[1]); fp.yaw = Math.PI; fp.walked = 0; }
    function applyToggles() {
      if (!built) return; const g = built.groups;
      g.main.visible = state.showMain; g.deep.visible = state.showDeep; g.upper.visible = state.showUpper; g.roof.visible = state.showRoofs; g.labels.visible = state.showLabels; g.anchors.visible = state.showAnchors; g.niches.visible = state.showNiches; g.props.visible = state.showProps; g.instances.visible = state.showInstances && state.mode !== 'fp'; g.views.visible = state.showViews; g.beats.visible = state.showBeats;
      const expedition = state.lighting === 'expedition';
      hemi.intensity = expedition ? 0.0 : 1.4; amb.intensity = expedition ? 0.02 : 0.35;
      for (const l of placedLights) l.visible = !(expedition && state.lanternOnly) || l === placedLights[0];
      lantern.intensity = expedition ? 28 : 0; lantern.distance = state.mode === 'fp' ? LANTERN_HELD : LANTERN_WORLD;
      scene.background.set(expedition ? 0x020304 : 0x0b0d0e);
      built.ring.visible = state.mode === 'fp';
      for (const l of labels) l.visible = (state.mode !== 'fp' || l.userData.kind === 'room') && (!l.userData.overlay || state.showLabels);
    }

    // ------------------------------------------------------------------ floor query for first person
    function floorAt(x, y, zNow) {
      const R = built.R; let best = null;
      for (const r of R.ramps) { const t = segParam([x, y], r.start, r.end); if (t >= -0.05 && t <= 1.05 && segDist([x, y], r.start, r.end) <= r.width / 2) { const z = r.top + (r.bottom - r.top) * Math.max(0, Math.min(1, t)); if (zNow + 1.5 >= z && (best == null || z > best.z)) best = { z, kind: 'ramp' }; } }
      for (const lv of [R.levels.upper, R.levels.main, R.levels.deep].filter(Boolean)) {
        const c = lv.grid.at([x, y]); const z = lv.grid.zOf([x, y]);
        if (z > zNow + 1.2) continue;
        if (['floor', 'low', 'crawl', 'grate'].includes(c)) { if (best == null || z > best.z) best = { z, kind: c, level: lv }; break; }
        if (c === 'solid' || c === 'crack') { if (best) break; return { blocked: true }; }
      }
      return best || { blocked: true };
    }
    function roomAt(x, y, z) { const d = built.d; for (const n of (d.niches || [])) if (shapeContains(n, [x, y]) && Math.abs((n.z || 0) - z) < 2.6) return 'pocket: ' + (n.note || n.id); for (const r of d.rooms) if (Math.abs(r.z - z) < 2.6 && shapeContains(r, [x, y])) return r.label || r.id; return ''; }

    // ------------------------------------------------------------------ controls
    let dragging = false, dragBtn = 0, lastX = 0, lastY = 0;
    canvas.addEventListener('contextmenu', e => e.preventDefault());
    canvas.addEventListener('mousedown', e => { if (state.mode === 'fp') { canvas.requestPointerLock(); return; } dragging = true; dragBtn = e.button; lastX = e.clientX; lastY = e.clientY; });
    window.addEventListener('mouseup', () => dragging = false);
    window.addEventListener('mousemove', e => {
      if (state.mode === 'fp') { if (document.pointerLockElement === canvas) { fp.yaw -= e.movementX * 0.0025; fp.pitch = Math.max(-1.4, Math.min(1.4, fp.pitch - e.movementY * 0.0025)); } return; }
      if (!dragging) return; const dx = e.clientX - lastX, dy = e.clientY - lastY; lastX = e.clientX; lastY = e.clientY;
      if (dragBtn === 0 && !state.plan) { orbit.theta -= dx * 0.005; orbit.phi = Math.max(0.05, Math.min(1.55, orbit.phi - dy * 0.005)); }
      else { const s = (state.plan ? (orthoCam.right - orthoCam.left) : orbit.r) / canvas.clientWidth; const right = new THREE.Vector3(Math.cos(orbit.theta), 0, -Math.sin(orbit.theta)); const fwd = new THREE.Vector3(-Math.sin(orbit.theta), 0, -Math.cos(orbit.theta)); orbit.target.addScaledVector(right, -dx * s).addScaledVector(fwd, dy * s); }
    });
    canvas.addEventListener('wheel', e => { e.preventDefault(); if (state.mode === 'fp') return; orbit.r = Math.max(5, Math.min(400, orbit.r * (1 + e.deltaY * 0.001))); }, { passive: false });
    window.addEventListener('keydown', e => { keys[e.code] = true; if (e.code === 'KeyC' && state.mode === 'fp') state.crouch = !state.crouch; if (e.code === 'Escape' && state.mode === 'fp') setMode('orbit'); if (e.code === 'KeyH' && state.mode !== 'fp') document.getElementById('app').classList.toggle('nopanel'); });
    window.addEventListener('keyup', e => keys[e.code] = false);

    function setMode(m) { state.mode = m; el('mode-orbit').classList.toggle('on', m === 'orbit' && !state.plan); el('mode-plan').classList.toggle('on', state.plan); el('mode-fp').classList.toggle('on', m === 'fp'); el('hud').style.display = m === 'fp' ? 'block' : 'none'; if (m !== 'fp' && document.pointerLockElement === canvas) document.exitPointerLock(); applyToggles(); }

    let last = performance.now();
    function tick(now) {
      const dt = Math.min(0.05, (now - last) / 1000); last = now;
      const w = canvas.clientWidth, h = canvas.clientHeight;
      if (w > 0 && h > 0 && (canvas.width !== Math.floor(w * renderer.getPixelRatio()) || canvas.height !== Math.floor(h * renderer.getPixelRatio()))) { renderer.setSize(w, h, false); camera.aspect = w / h; camera.updateProjectionMatrix(); }
      let cam = camera;
      if (state.mode === 'fp' && built) {
        const speed = state.crouch ? CROUCH : (keys.ShiftLeft || keys.ShiftRight ? SPRINT : WALK);
        const fwd = new THREE.Vector3(-Math.sin(fp.yaw), 0, -Math.cos(fp.yaw)), right = new THREE.Vector3(Math.cos(fp.yaw), 0, -Math.sin(fp.yaw));
        const mv = new THREE.Vector3();
        if (keys.KeyW || keys.ArrowUp) mv.add(fwd); if (keys.KeyS || keys.ArrowDown) mv.sub(fwd); if (keys.KeyD || keys.ArrowRight) mv.add(right); if (keys.KeyA || keys.ArrowLeft) mv.sub(right);
        const eye = state.crouch ? EYE_CROUCH : EYE;
        if (mv.lengthSq() > 0) {
          mv.normalize().multiplyScalar(speed * dt);
          const zFloor = fp.pos.y - eye;
          const tryMove = (dx, dz) => { const nx = fp.pos.x + dx, nz = fp.pos.z + dz; const f = floorAt(nx, -nz, zFloor); if (f.blocked || f.z > zFloor + STEP) return false; if (f.kind === 'crawl' && !state.crouch) return false; fp.pos.x = nx; fp.pos.z = nz; fp.pos.y = f.z + eye; fp.walked += Math.hypot(dx, dz); return true; };
          if (!tryMove(mv.x, mv.z)) { if (!tryMove(mv.x, 0)) tryMove(0, mv.z); }
        } else { const f = floorAt(fp.pos.x, -fp.pos.z, fp.pos.y - eye); if (!f.blocked) fp.pos.y = f.z + eye; }
        camera.position.copy(fp.pos); camera.rotation.set(0, 0, 0, 'YXZ'); camera.rotation.y = fp.yaw; camera.rotation.x = fp.pitch; camera.fov = 90; camera.updateProjectionMatrix();
        lantern.position.copy(fp.pos).add(new THREE.Vector3(right.x * 0.3, -0.2, right.z * 0.3));
        built.ring.position.set(fp.pos.x, fp.pos.y - eye + 0.05, fp.pos.z);
        el('hud').textContent = `${roomAt(fp.pos.x, -fp.pos.z, fp.pos.y - eye) || '-'}   x ${fp.pos.x.toFixed(1)}  y ${(-fp.pos.z).toFixed(1)}  z ${(fp.pos.y - eye).toFixed(1)}   walked ${fp.walked.toFixed(0)} m = ${(fp.walked / WALK).toFixed(0)} s   ${state.crouch ? 'CROUCHED' : ''}   (WASD, Shift sprint, C crouch, Esc)`;
      } else if (state.plan) {
        const span = orbit.r * 0.6, asp = w / h; orthoCam.left = -span * asp; orthoCam.right = span * asp; orthoCam.top = span; orthoCam.bottom = -span; orthoCam.updateProjectionMatrix();
        orthoCam.position.set(orbit.target.x, 150, orbit.target.z); orthoCam.up.set(0, 0, -1); orthoCam.lookAt(orbit.target); cam = orthoCam;
        lantern.position.set(0, -100, 0);
      } else {
        camera.fov = 55; camera.updateProjectionMatrix();
        camera.position.set(orbit.target.x + orbit.r * Math.sin(orbit.theta) * Math.cos(orbit.phi), orbit.target.y + orbit.r * Math.sin(orbit.phi), orbit.target.z + orbit.r * Math.cos(orbit.theta) * Math.cos(orbit.phi));
        camera.up.set(0, 1, 0); camera.lookAt(orbit.target);
        lantern.position.copy(orbit.target).add(new THREE.Vector3(0, 2, 0));
      }
      for (const l of labels) { if (!l.visible) continue; const dd = cam.position.distanceTo(l.position); const k = cam === orthoCam ? Math.max(0.6, orbit.r / 110) : Math.max(0.4, Math.min(2.5, dd / 60)); l.scale.set(l.userData.aspect * l.userData.base * k, l.userData.base * k, 1); }
      renderer.render(scene, cam);
      requestAnimationFrame(tick);
    }

    // ------------------------------------------------------------------ UI
    function updateMetrics(d) {
      const m = metrics(d);
      const row = (k, v) => `<tr><td>${k}</td><td>${v}</td></tr>`;
      const ent = m.perEntrance.map(e => `${e.id}: K ${Math.round(e.toK)} m` + e.toCourts.map(c => `, ${c.id} ${Math.round(c.m)}`).join('')).join('<br>');
      el('metrics').innerHTML = `<table>` +
        row('Revision', `${d.revision} <span class="muted">(${d._file})</span>`) +
        row('Footprint', `${m.footprint[0]} × ${m.footprint[1]} m, ${m.rooms} rooms, floor heights ${m.heights.map(h => h.toFixed(1)).join(' / ')}`) +
        row('Main rooms / footprint', `${Math.round(m.roomShare * 100)} %`) +
        row('Plan walked', `${Math.round(m.walked)} m, corridor ${Math.round(m.corridor)} m (${Math.round(m.share * 100)} %)`) +
        row('Corridor runs > 12 m', m.runs.length ? m.runs.map(r => `${r.link} ${r.m.toFixed(1)}`).join(', ') : 'none') +
        row('Rooms wider than 2 × lantern (14 m)', m.wide.length ? m.wide.map(r => r.label || r.id).join(', ') : 'none') +
        row('Dead ends on the plan graph', m.deadEnds.join(', ')) +
        row('Pockets (off-graph sockets)', m.niches ? `${m.niches}: ` + Object.entries(m.byFamily).map(([f, n]) => `${f}×${n}`).join(' ') : '<b>none</b>') +
        row('Props / water / extra ramps', `${m.props} / ${m.water} / ${m.ramps}`) +
        row('Puzzle dependencies', (d.puzzles || []).length ? (d.puzzles || []).map(p => `${p.id} ${p.kind}`).join(', ') : 'none') +
        row('Crawls / ladders with a stated purpose', `${(d.crawls || []).filter(c => c.purpose).length}/${(d.crawls || []).length} / ${(d.ladders || []).filter(l => l.purpose).length}/${(d.ladders || []).length}`) +
        row('Closure sets ≤ cap', `${m.valid} / ${m.combos} keep every entrance → hearth + courts`) +
        row('Entrance walks', ent) +
        (m.v8.hasV8 ? v8Rows(m, row) : '') +
        (built.R.warnings.length ? row('<b>Cannot render</b>', built.R.warnings.map(esc).join('<br>')) : '') +
        `</table>`;
      el('pitch').textContent = d.source || '';
      if (el('v8-toggles')) el('v8-toggles').style.display = m.v8.hasV8 ? '' : 'none';
      const n = d.notes, list = (t, xs) => (xs && xs.length ? `<div class="muted">${t}</div><ul>${xs.map(x => `<li>${esc(x)}</li>`).join('')}</ul>` : '');
      if (el('notes')) { el('notes').innerHTML = n ? (n.thesis ? `<p>${esc(n.thesis)}</p>` : '') + list('Principles', n.principles) + list('Changes', n.changes) + list('Risks', n.risks) : ''; el('notes-h').style.display = n ? '' : 'none'; }
    }
    const esc = t => String(t).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
    function v8Rows(m, row) {
      const v = m.v8;
      return row('Well-facing rooms', v.facing.length ? `${v.facing.length}: ${v.facing.map(esc).join(', ')}` : '<b>none</b>') +
        row('Transition beats', Object.keys(v.beats).length ? Object.entries(v.beats).map(([k, n]) => `${k}×${n}`).join(' ') : 'none') +
        row('Shortcuts (+ ladders, drops, lifts)', `${v.ways.one} one-way / ${v.ways.two} two-way`) +
        row('Transition lengths (room to room, outside rooms)', v.span ? `mean ${v.span.mean.toFixed(1)} m, min ${v.span.min.m.toFixed(1)} m (${v.span.min.link}) over ${v.span.n} links` : 'no link joins two rooms') +
        row('Instances', `${v.instances}, ${v.ports} ports`);
    }
    const sel = el('layout'); layouts.forEach((d, i) => { const o = document.createElement('option'); o.value = i; o.textContent = `${d.map} ${d.revision} — ${d._file}`; sel.appendChild(o); });
    sel.addEventListener('change', () => { state.layout = +sel.value; build(layouts[state.layout]); fillGoto(layouts[state.layout]); });
    for (const [id, key] of [['t-instances', 'showInstances'], ['t-views', 'showViews'], ['t-beats', 'showBeats'], ['t-main', 'showMain'], ['t-deep', 'showDeep'], ['t-upper', 'showUpper'], ['t-roof', 'showRoofs'], ['t-labels', 'showLabels'], ['t-anchors', 'showAnchors'], ['t-niches', 'showNiches'], ['t-props', 'showProps'], ['t-lanternonly', 'lanternOnly']]) { const cb = el(id); if (!cb) continue; cb.checked = state[key]; cb.addEventListener('change', () => { state[key] = cb.checked; applyToggles(); }); }
    el('mode-orbit').addEventListener('click', () => { state.plan = false; setMode('orbit'); });
    el('mode-plan').addEventListener('click', () => { state.plan = true; setMode('orbit'); });
    el('mode-fp').addEventListener('click', () => { state.plan = false; if (!state.showRoofs) { state.showRoofs = true; el('t-roof').checked = true; } setMode('fp'); });
    el('light-work').addEventListener('click', () => { state.lighting = 'work'; el('light-work').classList.add('on'); el('light-exp').classList.remove('on'); applyToggles(); });
    el('light-exp').addEventListener('click', () => { state.lighting = 'expedition'; el('light-exp').classList.add('on'); el('light-work').classList.remove('on'); applyToggles(); });
    el('goto').addEventListener('change', () => { const n = built.d.nodes[el('goto').value]; if (!n) return; fp.pos.set(n[0], n[2] + EYE, -n[1]); orbit.target.set(n[0], n[2], -n[1]); orbit.r = 30; });
    function fillGoto(d) { const g = el('goto'); g.innerHTML = '<option value="">go to node…</option>'; for (const k of Object.keys(d.nodes).sort()) { const o = document.createElement('option'); o.value = k; o.textContent = k; g.appendChild(o); }
      const gv = el('gotoview'); if (!gv) return; gv.innerHTML = '<option value="">go to view…</option>'; gv.style.display = (d.views || []).length ? '' : 'none';
      for (const v of (d.views || [])) { const o = document.createElement('option'); o.value = v.id; o.textContent = v.id + (v.label ? ': ' + v.label : ''); gv.appendChild(o); } }
    function gotoView(id) { // first person at `from` (eye = z + 1.1), looking at `to`
      const v = (built.d.views || []).find(x => x.id === id); if (!v) return;
      const z = v.from[2] || 0, dx = v.to[0] - v.from[0], dy = v.to[1] - v.from[1];
      fp.pos.set(v.from[0], z + EYE, -v.from[1]); fp.yaw = Math.atan2(-dx, dy); fp.pitch = Math.max(-1.4, Math.min(1.4, Math.atan2((v.to[2] || 0) - z - EYE, Math.hypot(dx, dy)))); state.crouch = false;
      orbit.target.set(v.from[0], z, -v.from[1]); if (state.mode !== 'fp') el('mode-fp').click();
    }
    if (el('gotoview')) el('gotoview').addEventListener('change', () => gotoView(el('gotoview').value));

    // URL state, so a view is reproducible (and scriptable for headless screenshots):
    //   ?layout=v4&view=orbit|plan|fp&light=exp&panel=0&roofs=1&labels=0&pos=x,y,z&yaw=deg&pitch=deg&target=x,y&r=80&theta=deg&phi=deg
    const params = new URLSearchParams(location.search); const want = params.get('layout'); if (want) { const i = layouts.findIndex(d => d._file.includes(want) || String(d.revision) === want); if (i >= 0) { state.layout = i; sel.value = i; } }
    if (params.get('panel') === '0') { document.getElementById('app').classList.add('nopanel'); el('help').style.display = 'none'; }
    if (layouts.length) { build(layouts[state.layout]); fillGoto(layouts[state.layout]); } else el('metrics').textContent = 'No layouts: run python make_layouts.py';
    for (const [p, id, key] of [['roofs', 't-roof', 'showRoofs'], ['labels', 't-labels', 'showLabels'], ['anchors', 't-anchors', 'showAnchors'], ['pockets', 't-niches', 'showNiches'], ['props', 't-props', 'showProps'], ['upper', 't-upper', 'showUpper'], ['deep', 't-deep', 'showDeep'], ['main', 't-main', 'showMain'], ['lanternonly', 't-lanternonly', 'lanternOnly'], ['instances', 't-instances', 'showInstances'], ['views', 't-views', 'showViews'], ['beats', 't-beats', 'showBeats']]) { const v = params.get(p); if (v != null) { state[key] = v !== '0'; if (el(id)) el(id).checked = state[key]; } }
    if (params.get('light') === 'exp') el('light-exp').click();
    const num = (k, dflt) => params.get(k) == null ? dflt : +params.get(k);
    if (params.get('target')) { const t = params.get('target').split(',').map(Number); orbit.target.set(t[0], t[2] || 0, -t[1]); }
    orbit.r = num('r', orbit.r); orbit.theta = num('theta', orbit.theta * 180 / Math.PI) * Math.PI / 180; orbit.phi = num('phi', orbit.phi * 180 / Math.PI) * Math.PI / 180;
    if (params.get('pos')) { const p = params.get('pos').split(',').map(Number); fp.pos.set(p[0], (p[2] || 0) + EYE, -p[1]); }
    fp.yaw = num('yaw', fp.yaw * 180 / Math.PI) * Math.PI / 180; fp.pitch = num('pitch', 0) * Math.PI / 180;
    if (params.get('view') === 'plan') { state.plan = true; } if (params.get('view') === 'fp') { state.showRoofs = params.get('roofs') !== '0'; el('t-roof').checked = state.showRoofs; }
    setMode(params.get('view') === 'fp' ? 'fp' : 'orbit');
    if (params.get('goview') && built) gotoView(params.get('goview')); // ?goview=<views[].id>: Walk from that Well window
    tick(performance.now()); // one synchronous frame, so a headless --screenshot has something to capture
    if (params.get('debug')) { const gl = renderer.getContext(); const dbg = gl.getExtension('WEBGL_debug_renderer_info'); el('pitch').textContent += ' | gl: ' + (dbg ? gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER)) + ' | canvas ' + canvas.width + 'x' + canvas.height; }
    window.MarsViewerDebug = { state, THREE, scene, camera, fp, metrics: () => metrics(built.d), rasterize: () => built.R, snapshot: () => canvas.toDataURL('image/jpeg', 0.6), gotoView };
  }
  window.MarsViewer = { start, metrics, rasterize };
})();
