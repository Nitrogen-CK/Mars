# Spire PIE acceptance

**Passed after the roof collision fix.** All four source Level Instances were
tested in the isolated acceptance map with their persistent collision proxies.

| Check | Final result |
|---|---|
| Normal chef, full spirals and all BW yokes | 18/18 passed |
| 110 x 220 cm clearance gauge, ascents and BW yokes | 9/9 passed |
| Real chef pressed into representative inner/outer rails | 16/16 passed |
| Runtime rail / doorway / ceiling capsule sweeps | 769/769 passed |
| Recorded stair waypoints across final traversal cases | 1080 |
| Recorded movement frames | 39700, all Walking |
| Focused Unreal Toolbox CkJolt automation | 40 passed, 0 failed/contaminated |

Hearthscrew, Rootwinder and Hanging Larder passed descent and ascent. Braided
Well passed descent and ascent on both helices, plus both directions across
all four cross-yokes. No stair stalls, falls or clearance defects were found
in these cases. The actual chef capsule remained 78 x 150 cm; the larger
gauge was an explicit separate test and did not alter the class defaults.

The discovered defect was missing main-roof collision in all four variants.
The same four failing baseline ceiling checks now hit the new shared roof
proxies, with no initial overlaps. The other 765 safety checks remained green.

Machine-readable rollup: `Output/Reports/pie_acceptance.json`. Individual
frame samples, waypoint events and actual PIE screenshots are in
`Output/PIE/final-chef`, `Output/PIE/final-gauge` and `Output/PIE/final`.
`pie_report.py` verifies those reports and binds them to the asset manifest.

## Confirmed baseline

`Output/PIE/baseline-chef/suite.json`: ten successful continuous pawn walks.
Hearthscrew, Rootwinder and Hanging Larder each descended and ascended. Braided
Well routes A and B each descended and ascended, including their top/bottom
cross-yoke connections. The possessed `Mars_PlayerCharacter` used its actual
39 cm radius / 75 cm half-height capsule and `Mars_CharacterMovementComponent`.
Movement was driven through AddMovementInput, with normal gravity and step
handling. No jumping, flying, route teleporting or obstruction bypass was used.
Each run records every waypoint and frame samples, with PIE screenshots.

`Output/PIE/baseline/geometry_sweeps.json`: 741 rail capsule sweeps and 24
110 x 220 cm doorway gauge sweeps passed. Four main-ceiling sweeps failed:
the visible shaft roofs had no collision proxy. This is separate from the
visual Level Instance NoCollision contract; the persistent proxy set was
missing those roofs too.

## Fix implemented

`production.py` generates `COL_R600_Roof` and `COL_R700_Roof` and instances
twelve roof sectors per assembly in the persistent collision recipe. The
two assets are shared by all four concepts. The kit now contains 105 meshes,
29 collision assets and 516 imported convex hulls. All 105 native bounds,
material and collision-count checks passed after import. Fresh Blender checks
also passed: 405 surface/bore rays, 1167 sampled headroom rays and manifold
collision-proxy surfaces. The saved scene snapshots, canonical Asset Browser
library, FBXs and CSV catalog include the new meshes.

## Reusable final acceptance run

Use the editor Python console, outside PIE, with unrelated changes saved:

```python
import sys
sys.path.insert(0, 'D:/Repositories/CkRepos/Orion/Tools/SpireConnectorKit')
import pie_acceptance as qa
qa.save_dirty_owned_maps()
```

Run map switching in a subsequent console invocation. Never keep a Package
or World wrapper in the caller while switching levels. The helper returns
strings rather than UObject wrappers:

```python
qa.build_harness()
```

This creates/reuses
`/Game/Mars/Environment/SpireConnectorKit/Maps/Spire_PIEAcceptance_R02_Mars_MAP`.
It contains the four actual visual Level Instances, their persistent collision
proxies, eight test approach pads and the normal gameplay GameMode. The
original baseline harness remains separately saved. An existing harness with
a stale manifest is rejected; use a fresh owned map path for a new revision.

Start normal PIE, then:

```python
import pie_geometry_audit as geometry
geometry.run('final')
qa.start_suite('final-chef', include_yokes=True)
```

The chef suite has 18 cases: ten full spiral traversals and both directions
across each of the four BW yokes. Each case has one explicit setup relocation;
all movement along its route uses the real movement component. A fall, stall
or unexpected capsule-size change stops the suite and records the failing
position. Call `qa.suite_status()` for progress. Do not reload the module
while a callback is active.

After that suite finishes, run the larger design clearance envelope:

```python
qa.start_suite('final-gauge', gauge=True, directions=('up',), include_yokes=True)
```

These nine ascent/cross-yoke cases temporarily use a 55 cm radius / 110 cm
half-height capsule on the same possessed chef. This is the design clearance
gauge, not a claim that wearing a gameplay backpack changes the standing
capsule to that size. The driver verifies the capsule dimensions every frame.

## Editor recovery recorded

After the baseline runs, saving scoped packages and switching maps in the
same Python invocation retained a Package wrapper in the caller. Unreal's
NewLevel GC guard reported `World Memory Leaks: 1` and closed the editor.
The maps were saved first. `save_dirty_owned_maps` now scopes and releases
the wrappers before any world switch. See
`Output/PIE/crash-20261027-193521.txt` and the raw crash directory it names.

The editor was restarted through Unreal Toolbox. The user dismissed its
startup “This asset editor has no docked tabs” dialog, and all final runs
then completed. Subsequent map switches succeeded after the wrapper cleanup.

## Limits

These checks concern single-player PIE geometry and collision. They do not
establish packaged CkJolt lookup, co-op passing space or subjective keyboard
feel. Keep collision in the persistent integration map; the current CkJolt
cooker still rejects transient Level Instance lookup identities.

