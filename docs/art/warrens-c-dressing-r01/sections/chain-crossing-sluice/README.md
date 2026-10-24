# Chain Crossing and Sluice / complete model-reference kit

88 component/model entries in 23 modeling sheets, plus four assembly/readability sheets. Repeated links, boards, bolts and bays are instances of shared components. Optional entries are explicitly optional. These are concepts and Blender briefs, not finished meshes.

## Authored extent

- Fixed causeway centerline [66,26,-2.5] to [96,24,-2.5]m: 30.067m long, 2.5m source width. Do not change its walk surface or turn it into a new moving bridge.
- Pump-side gate [67,26,-2.5]m; source shortcut mouth span250cm. Current gate component has 200x220cm clear opening, 20cm posts, 40cm frame depth and 220cm upward leaf travel. The art must retain those distinctions; a 250cm mouth is not a 250cm gate opening.
- Sluice design control at [122,12,-2.5]m inside the [114,8]-[130,22]m room. Salt Cellar is [96,12]-[110,26]m. Source chain proxy at [110,20,-2.5]m has24x0.4x0.2m envelope; it is an art tell, not an exact continuous routing spline.
- Source deep canal depth2m and retained deep-water rail1m. Water body owns actual water level. Never infer a walkable bed from a material preview.
- Keep Pump-rest niche[66,28]-[70,31]m and all nearby authored routes/ports. Do not invent extra stairs, stepping stones, ladders, boats or docks.

## Important integration finding

The written design calls for a Sluice handwheel. Current source builder selects its wheel branch only for a P2 kind beginning `sluice grate`; the present P2 label does not match. ChainCrossing is also spawned as a `Mars_Shortcut_EntityScript`, which owns a side lever and latched rising Bars gate. This dossier does not repair that gameplay mismatch. CCS21-39 show the intended wheel/gate art; CCS40-41 document compatibility with the existing lever path. Do not install both as competing player controls. Resolve control/channel ownership in the later gameplay integration pass and verify it in PIE.

Read-only MCP confirmed the editor currently has Variant C open. Top-level actor-label inspection did not resolve nested mechanism actors, so no runtime wheel presence, gate activation or movement is claimed.

## Build order and reuse

1. Fit floor, wall, arch, roof and bank rock skins to retained geometry. Make the empty path read before dressing it.
2. Build repeating deck bay, bank edge and rail kit; trim end closures to source angle. The approximately30m crossing needs repeated bays, not a single giant bespoke mesh. Suggested2m longitudinal bays require15 repeats plus a fitted remainder; quantities are proposals until actor fitting.
3. Skin static gate frame separately from moving leaf. Preserve the full leaf travel volume and current moving-node origin/collision.
4. Build the modest50cm wheel body, axle, mount, drum, one chain link and guide hardware. Preserve actual grip sockets, actor local +X wheel axis, probe and source/sink channel ownership during the later integration.
5. Fit flat water surface and sparse edge cards. Water is a material/carrier setup, not a solid geometry volume. Output of this dossier is not a Niagara system, fluid simulation or working sluice water-level mechanic.
6. Reuse existing fixture/lantern actors. One source dim Sluice light is authored at[122,15,0.1]m; fixture artwork does not justify adding lights to every post. Calibrate eventual intensity and reach from the actual player camera.
7. Add closed-wall storage and one maintenance story cluster; keep the chain tell, hand space, gate opening and retreat route clear. Optional FX/decals come last.

## Materials and graphic inputs

Use the parent [Blender material library](../../blender/WarrensC_MaterialLibrary.blend) and [material guide](../../MATERIAL_GUIDE.md). Stone:TX01/TX02/TX03, rock:TX04/TX17, wood:TX07/TX08, iron:TX09, muted copper:TX11, cloth:TX12, rope:TX14, glass:TX15, parchment:TX16, water:FX_Water. Shared technical maps are in ../../textures. No amber/teal light baked into albedo. Apply broad face colors and low-poly geometry before detail maps.

The Sluice plaque must use a wheel-and-chain mark. The generic P30 CuringStopPlaque is a shape/material-family reference only: do not put its vat/curing emblem at the Sluice. Use blank notice and route backing; authored text/arrows are a later verified placement task, and no random lock glyphs belong here.

## Distant context is reused

The far Well/hoist and Bell Tower can appear in player mood shots. They are shared landmarks, not new local copies. Parent MODEL02/03/23/36 cover the hoist, tower and bell. Keep their actual district positions and original sightlines; do not move them closer to match a painting.

## Modeling contract

Blender units metres, transforms applied, local Z up. Catalog dimensions are cm. Shared-family references are starting points: do not duplicate an asset merely because it occurs in more than one section. Each row states envelope, role, shared family, material IDs, pivot and copying brief. Ordinary static dress/carriers defaultNoCollision; keep existing source walk collision, actor colliders, grip frames and sweeps. Make one named collection per component; split moving/static meshes. One/two quiet material slots; use shared palette/trim/tiling UVs. Simple thumbnail views do not override the written dimensional contract.

## Later Unreal acceptance

No live map, gameplay script, imported prop or light has been changed. Future acceptance must exercise Pump-side blocked view, intended Sluice activation, latched open state and two-way return; pack crossing; gate travel/threshold; floor-chain visibility; bank rails; carried-lantern readability; existing water behavior; nearby Undercroft routes and protected distant views. Use appropriate CkAuto tests after actual integration. Concept sheets cannot establish any of those outcomes.
