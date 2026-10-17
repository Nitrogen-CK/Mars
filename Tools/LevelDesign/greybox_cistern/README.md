# Cistern / grid study 01

Open **cistern-greybox.html** directly in a desktop browser. It is a portable offline file with Three.js bundled inside; no server, install or internet connection is required. `THREE-LICENSE.txt` retains the bundled library's MIT license.

This is a proposed redesign of Cistern, the smallest of the existing four expedition envelopes (180 × 160 m). It is not an export of the current Unreal map. Its compact 96 × 80 m footprint uses a 4 m structural grid, two playable levels (0 / +4 m), an unwalkable recessed basin, two side courts, a continuous upper circuit, and a puzzle bridge. The Unreal assets have not changed.

## Controls

- Orbit: left drag to rotate, right/Shift drag to pan, wheel to zoom. Click a floor or area name to inspect/focus it.
- Plan: orthographic north-up view. Drag to pan; use the level selector to isolate elevations.
- Walk: WASD movement, drag or arrow keys to look, Shift for faster movement, E for nearby interactions, Escape for orbit. Buttons A–D choose valid entrances; Random chooses one of the four. Collision and stair traversal are active.
- Ceiling: a real opaque roof, beams, bearing columns and enclosing perimeter walls. Walk enables it automatically. Cutaway walls are an inspection view.
- Export layout: downloads the source layout JSON. Home / Reset view restores the overview.

The grey station blocks, ingredient pickups and humanoids are functional-location proxies. Combat and physics cooking are not simulated. Collect the three ingredient proxies and return to the kitchen to exercise the route. This is not a measured 15–20 minute run.

## Why this topology

The arrival court presents both banks. The west harvesting court and east hunt court each lead directly to an 8 m stair; both stairs reach a continuous +4 m north gallery, whose seasoning destination gives the climb a purpose. The kitchen and courts have broad thresholds rather than diagonal connector ribbons. Every branch rejoins the outer circuit.

The bridge shortens travel between upper banks. On its west side, E places the pack on the PACK plate; walking onto CHEF latches the gate. E recovers the pack. A return-side release avoids a one-way trap. Either chain opens the east gate for eight seconds. A closing gate waits while the player occupies the threshold. All bridge landings remain 8 m wide; a narrower first draft was rejected after a real walking test blocked at its mouth.

## Metrics and source

- `layout.json`: all floor rectangles, structural coordinates, stairs, entrances, area purposes and route-guide points. Change this to adjust the layout.
- `viewer.template.html`: renderer, controls, world collision and interaction proxies; neutral grey materials. The primary orbit camera radius is 115 m. No CDN requests occur at runtime.
- `build.py`: grid/alignment and abstract connectivity checks, then builds the standalone HTML from the template/data/bundled library. Run `python Tools/LevelDesign/greybox_cistern/build.py`.
- Two 8 × 8 m stairs: 24 treads, 167 mm rise / 333 mm going, 4 m total rise. Walk speed 4.2 m/s; eye height 1.7 m; body reference 1.8 m; collision radius 0.4 m. Kitchen counter rows leave a 6 m aisle and its threshold is 8 m wide. Both bridge gates are optional; the outer loop works with both shut.

## Observed verification

Final build: 246 connected floor/stair cells; all floor rectangle limits and elevation datums on the 4 m grid. Browser renderer has 238 unique floor cells plus eight abstract stair cells. The continuous outer circuit was sampled every 0.1 m against the actual browser floor/collision functions, without changing player or gate state.

Actual keyboard traversal completed the kitchen threshold, west court, west stair up, north stores, east stair down, hunt through-route and kitchen return. It also completed the widened bridge approach, pack placement, second-plate latch, pack recovery, chain pull, timed crossing, waiting through timer expiry while inside the gate, and safe closure after leaving it. Four entrance collision checks passed. The recorded page errors and runtime HTTP requests are both empty.

`verification.json` retains the observed checks. The verification process exited 1 only after those desktop checks, when its additional mobile check attempted to click Reset after the narrow-screen CSS had hidden that desktop control. The harness has been corrected to reset before resizing but has **not** been rerun. Do not claim a green complete harness or verified mobile presentation. Further in-app browser inspection was blocked by browser security policy; no alternate browser inspection was attempted after that denial.

`overview.png`, `plan.png`, `ceiling.png`, `walk-kitchen.png` and `walk-bridge.png` are screenshots from the actual rendered page. No Unreal code, map assets, builds or gameplay tests were changed or run for this HTML-only mockup. Nothing committed or pushed.
