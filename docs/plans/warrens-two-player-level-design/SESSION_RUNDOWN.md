# Warrens session rundown

**Later material correction:** the flat Displace amendment was rejected in play and replaced by [readable CkUSF blockout treatments](MATERIAL_REPAIR_20261022.md), verified in 16 matched PIE views. That repair and the subsequent orange stair/ramp landmarks are committed locally; nothing is pushed. See the repair record for the later scope and evidence.

2026-10-22, America/Toronto. Scope: this conversation's review, implementation plan, Phases1-5, physical/readability corrections, authorized local pack-loading repair and requested CkUSF material amendment. Layout and intention for two players; no multiplayer engineering. Session work is committed locally; nothing is pushed. See [commit record](COMMIT_RECORD.md) for boundaries and remaining unrelated changes.

## Current outcome

Phases1-3 are complete within their recorded local evidence limits. Phase4 is implemented and locally exercised, with normal heard audio still unaccepted. Phase5 BatchA's material/dressing/local-light work and bounded approaches passed author review; its four missing sound deliveries block batch completion. BatchB/C presentation and Phase6 unfamiliar-pair acceptance remain unstarted. The requested CkUSF material amendment is now complete locally, as recorded below.

This is a better authored test map for two people, with useful passing/reunion positions and voluntary scout/carrier or reader/operator roles. It is not evidence that two unfamiliar humans have completed a run together.

## Review and implementation plan

- Audited the actual map graph, entrance closures, optional crawls, ladders, puzzle channels, route choices, rewards and return paths. Separated existing mechanics from proposed drain/alarm/sanctuary/harvest behavior.
- Converted the review into six phases with explicit source, geometry, runtime, visual and human-observation gates. The user's layout/intention correction removed MP engineering from the implementation scope.
- Preserved the existing51-node/59-link main graph and footprint; all64 legal route-closure sets times5entrances remain connected in320 static cases. Connectivity is structural proof, not a complete gameplay run.
- Defined the spatial progression as working kitchen -> shared Well revelation -> optional scout/information split -> exposed lower acquisition -> useful loaded return -> kitchen relief. Roles can be swapped and essential progress remains sequentially possible by one active chef.

Evidence: [plan](PROMPT.md), [original review](../../reviews/2026-10-20-warrens-two-player/LEVEL_DESIGN_REVIEW.md), [original source/route inventory](../../reviews/2026-10-20-warrens-two-player/ROUTES_AND_UNLOCKS.md). The original review describes v6 and is historical; current implementation records below supersede it.

## Phase1: measured contracts and baseline

- Captured source/map/collision identities, manually placed actor inventory, graph gates, asset availability and installed editor APIs before implementation.
- Measured the chef capsule, actual backpack, station tables and dock/operator/camera envelopes. The chef is78cm across; the measured backpack spans about116cm; both station tables are80x160cm. These measurements governed cargo lanes and waiting positions.
- Authored passing/staging, ladder waiting/retrieval and optional-drop recovery contracts. Used2.4m passing/staging candidates rather than treating a1.8m lane as sufficient for two loaded people.
- Inventoried actual mesh/material/audio content and recorded specific missing environmental-sound briefs instead of claiming generic effects meet the intended soundscape.

Evidence: [contracts](evidence/phase-1/contracts.json), [measured and source inventory](evidence/phase-1/resume-20261021/assets.json), [placement diagram](evidence/phase-1/resume-20261021/kitchen-envelope.png).

## Phase2: layout, architecture and physical readability

- Added a reproducible v7 authoring layer over frozen v6, with its own geometry data and focused validator. Default v6 behavior remains invariant.
- Added/protected cargo staging, passing and reunion spaces, ladder mount/dismount/waiting positions and recoverable landings at optional drops. Kept the kitchen roof sealed, both useful ladders, the service spiral and both Grotto approaches.
- Authored structural identities across all12 area groups:

| Area | Structural result |
|---|---|
| Kitchen | Sealed low working volume, hearth/hood, utensil rail and visible crank-drive supports. |
| Well | Multi-level negative space, hoist/post/ceiling attachments and root relationship to the lower larder. |
| Court | Sunken arena/stairs, processional seating, tall monument and lower service profile. |
| Ossuary | Interrupted stepped burial masses/end markers with an empty transverse aisle. |
| Bridge/Reliquary/Mourner | Pause/read positions, ordered plinths and an identifiable optional barred mouth. |
| Upper galleries | Repeated suspended maintenance ties, rails and useful ladder waiting positions. |
| Chime/Bellkeeper | Large suspended stepped instrument/canopy, roof-connected strands and perimeter room. |
| Pump/Cellar/Sluice | Tall pump mass, open drying-rack tiers and visibly hollow supported conduits. |
| Cistern/Drowned | Rib/crown silhouette, dry approach and two preserved crossing routes. |
| Spiral/overlook | Actual treads/balustrade, outer mineral framing and optional inspection drop/recovery. |
| Grotto/recess | Root crown attached at the shelf, two approaches and an optional listening pocket. |
| Pit/Vault/closet | Feeding-floor scars/root base, clear arena/perimeter and connected closet header/shaft. |

- Fixed the floating-looking Sluice bars as hollow split conduits with skins, break rims, saddles and roof hangers. Rebuilt two drying racks with legs, open slats and bearing rails within their existing envelope.
- Checked analogous attachments: kitchen utensil rail, Well hoist, gallery beams, Chime strands and closet header/return joist. The all-area contact audit covered198 area pieces; geometric contact and rendered readability were recorded separately.
- Reworked the Cistern crossing after a lower-ramp obstruction and a rejected correction that removed upper support: a guarded3m upper bridge preserves both upper branches; the local descent reaches-5m before passing underneath. The descent is about29.75degrees. Graph nodes/channels remain unchanged.
- Exercised both role arrangements with measured body/pack stand-ins, both ladders in both directions, loaded approach/return circuits,20 cargo bays per role and four real item-drop recoveries. Stand-ins and APawn movement followers are explicitly distinguished from two-human play and hardware-input feel.

Evidence: [final physical acceptance](evidence/phase-2/cistern-crossing-20261021/PHYSICAL_ACCEPTANCE.md), [all12 structural views](evidence/phase-2/cistern-crossing-20261021/STRUCTURAL_CHECKPOINTS.md), [pipe/rack correction history](evidence/phase-2/readability-fix-20261021/FINAL_STATE.md). That last document retains an earlier STOP; final crossing acceptance supersedes it.

## Phase3: purposeful routes, dependable rewards and a functional kitchen

- Added a Warrens-only route table: open arch, closed rubble or eligible far-side scout latch. Removed the ordinary two-sided lever tax from this map's new route table while preserving generic tables and the role solver. All7v7 route sockets use the map-specific table.
- Added one Pan to each entrance kit so the selected entrance supplies an existing foraging tool. Retained the shared pack/lantern/tallow setup.
- Added an existing mushroom bed to Grotto's reachable dry shelf apron. Observed an actual Pan strike, mushroom pickup, Pocket1 loading and loaded-pack recovery; did not invent a crown-harvest or bait mechanic.
- Added one fixed tallow at Mourner and two at Vault on separated, supported rests visible before paying their access cost. Retained optional cache behavior and the existing RedKey/lock.
- Clarified PK/P2/P3 cues: shutters latch, Sluice opens remote bars without draining water, and Mourner requires one occupancy rather than a two-player hold.
- Replaced the two matching kitchen blockout fixtures with the real Cutting and Searing stations. Added large/small receiving platters on two rests. Final station positions are Cutting(37.8,48) and Searing(41.2,48), facing oppositely.
- Moved only Searing0.5m west from its measured initial placement after the real worn-pack envelope intersected the retained rack. Final measured rack gap is15.84cm.
- Demonstrated slab->two cut halves->output platter, normal hand/quarter-turn controls, and one fully seared face using the real Searing station. One chef sequentially operated both stations; paired work positions were checked with alternating stand-ins. Complete meal/service/ready-takeout is not claimed.

### Authorized pack-loading physics repair

The user explicitly expanded scope after a stationary dropped pack moved when loaded with a mushroom. This was a local physics defect, not MP work.

- Confirmed QueryOnly/non-Block collision signatures were being treated as solid Jolt contacts: a mounted kinematic mushroom could push its dropped dynamic pack.
- Corrected contact response at both Added and Persisted while retaining query/contact reporting and sensor identity.
- Preserved platter support by introducing the explicit QueryAndPhysics `Mars_PlatterPhysical` profile. Small/large platters, rims and mounted food opt into it; ordinary mounted items retain their QueryOnly default.
- WorldItem retains the selected mounted profile for request/acknowledgement and restores the original profile on release. No timing, settling, recipe or cooking overhaul.
- Added discriminating regressions for QueryOnly response, runtime profile changes and mushroom cargo driving a dropped pack; extended existing platter/profile lifecycle checks.
- Final affected set:123 unique tests passed (125 observations because two names overlap). The baseline had120 existing passes plus3 new behavioral reds. The real pack then stayed motionless through loading and normal pickup, with the same mushroom retained.

Evidence: [Phase3 complete review](../../superpowers/reviews/2026-10-21-warrens-phase-3-review-package.md), [physical operations](evidence/phase-3/kitchen-20261021/PHYSICAL_ACCEPTANCE.md). Production repair spans CkFoundation/CkJolt, explicit project collision config and local WorldItem/Platter presentation contracts; it must not be described as map-only work.

## Phase4: Bellkeeper and readable consequences

- Reconciled concurrent Control/Dial/Bellkeeper work and retained opt-in grip-and-drag dial interaction. Levers/chains and the shared Sequence implementation keep their existing contracts.
- Integrated three visible six-position dials, three stake candles, bell/chain commit, a dedicated local vent consequence and physical reward rests. The displayed attempt persists after a failed guess; there is no per-dial correctness hint.
- One authoritative phrase drives clue and answer: Diamond -> Triangle -> Cross. It is readable from the Bridge and unavailable from the panel; players may split reader/operator or travel sequentially.
- Wrong commits keep the entered dials, vent locally and lose Cleaver then Tenderizer on the first two failures. Further failures still vent; Ration remains. The vent is push-only; it does not gain damage.
- Correct commit locks the dials, latches the optional gate and pays the remaining physical rewards once. Demonstrated exactly one Ration after three failures and no duplicate payout on repeated solved commit. A separate zero-failure solve demonstrated all three reward rests.
- Removed Bellkeeper from the random-cache pool while retaining the niche: four anchors become three, maxActive remains two. No required main route is locked behind this encounter.
- Lowered the vent0.35m for a supported landing, tuned only the clue light, and repaired clue/cost contrast. Dark clue discs and P4-only unlit dark lettering make the full warning readable: WRONG RINGS LOSE TOOLS / THE LAST RATION REMAINS.
- Exercised all dial positions, wrong pushes, supported worn-pack landings, solve/pickup and solo panel->Bridge->panel movement. Literal human read-memory and normal heard audio remain unaccepted.

Evidence: [Phase4 physical evidence](evidence/phase-4/physical-20261022/PHYSICAL_ACCEPTANCE.md), [review](../../superpowers/reviews/2026-10-21-warrens-phase-4-review-package.md). Focused source gate52->57 passes; later contrast source has its own build+Bellkeeper10/10. Those are separate source snapshots, not one invented final full-suite run.

## What opens what now

| Mechanism | Action and result | Two-person intention |
|---|---|---|
| PK kitchen | Hold the existing crank for2seconds; both shutters latch open. East cargo entry, optional west packless service opening. | One opens while the other stages cargo; no maintained holder. |
| P1 Vault | Gallery RedKey/lock opens Vault; two fixed fuel rewards. | Optional useful detour with visible payoff. |
| P2 Drowned Gallery | Sluice wheel opens remote bars; water stays cosmetic. | One operates while the other reads the destination/handles cargo, then both leave. |
| P3 Mourner | Single chef or pack occupancy latches access; one fixed fuel plus the retained optional cache. | One-person occupancy symbol; leaving the plate does not strand the operator. |
| P4 Bellkeeper | Set three dials, then pull chain; optional latch and remaining Cleaver/Tenderizer/Ration rewards. | Voluntary reader/operator split, visible attempts and cost; sequential solo access remains possible. |
| P5 Chime ladder | Gallery-side release opens the barred ladder foot. | Useful loaded vertical return with separate waiting/landing space. |
| SC2 closet | Open from the closet side after the Pit ladder ascent. | Learned lower-larder return to the Chapel. |
| R-route scout latch | Eligible far-side lever reached through the optional scout route opens for the carrier. | Short voluntary split followed by reunion; no compulsory simultaneous hold. |

## Phase5 before the CkUSF amendment

- Added opt-in presentation metadata and material/collision-aware HISM grouping without changing original mesh/kind/collision/transforms. Frozen v6 defaults remain exact.
- BatchA only:7owned palette material instances,18NoCollision dressing actors and293 targeted material assignments. Kitchen toolboard/soot hood; Well hook/6joined links; Court rubble/split front; four inward Ossuary niche facades and3small supported vessels.
- Corrected four backwards-facing niche facades after inspecting the actual imported mesh face. Pivot compensation preserves their exact world bounds and clearances. These are recessed niches, not demonstrated bone-filled shelves.
- Reduced2existing hotspot lights and added9local work/depth/raking lights. Native lights33->42; global ambient/district fills/exposure remain unchanged.
- Matched player-camera views establish room profiles, attached chain, split monument, supported rubble and vessels, plus preserved P4 clue/cost wording. Rejected a low-eye rubble fixture and replaced it with a supported real-walk arrival.
- Final bounded input check:9walks,22waypoints,291samples with an empty worn pack; both station mounts enter/exit, relevant crank/Well/Court/plate approaches clear. Explicit per-area setup placements are not end-to-end traversal.
- Four approved environmental sounds remain absent: HearthCooling, WellDripChain, CourtLooseStone and OssuaryDryTick. No generic substitutes, new ambient audio system or quiet relabel. B/C's distinct presentation work remains unstarted.

Evidence: [Phase5 review](../../superpowers/reviews/2026-10-21-warrens-phase-5-review-package.md), [pre-amendment before/after](evidence/phase-5/entry-20261022/batch-A-before-after.png), [current progress](PROGRESS.md).

## Requested CkUSF material amendment

COMPLETE LOCALLY. The prototype grids already derived from CkUSF; their prototype appearance has now been replaced with a different existing lit CkUSF look. The Displace master uses Amplitude/Frequency/Speed all0: no vertex deformation, animation or grid. The7owned district palette instances were reparented, and3new neutral floor/wall/roof instances complete the environment coverage. Native persisted parent/color/zero-parameter readbacks passed for all10.

All4,149 authored environment instances now have the non-grid CkUSF parent. All18dressing pieces are grid-free:14use the owned CkUSF materials, and the toolboard/3vessels retain their authored nongrid kit materials. Shared runtime gameplay props retain their existing prototype materials; this does not claim every runtime actor is grid-free.

Only the builder's optional material fallback and the geometry/live-JSON material metadata changed, plus the10owned material assets and generated map/allJolt. Frozen v6 remains identical. Meshes, geometry, collision,42lights/exposure, labels, entities, mechanisms, AS and shader/plugin source remain unchanged. One material bucket merges:29->28HISM groups and216->215actors, with all4,149instances retained.

Sixteen matching before/after player-camera pairs retain angles/FOV90 and no held lantern, with less than1mm eye settling. Root reviewed the twelve-area atlas and critical original frames: room forms, stairs/edges and complete P4 clue/cost remain legible within this material pass. BatchB/C final lighting/identity is still unaccepted; the Pit near field remains dark. No extra gameplay campaign was repeated for unchanged layout/source.

Final gates retain131static checks/320graph cases/5negative rejections and898native support samples/0missing,20clear starts,6crawls,Joltvalid. Root independently checked126current/checkpoint copies,1,270protected sources and26applied artifacts with zero drift. Final saved map SHA256 is6e5a611f8976f77c4fd3b110cc859b4065ed5381a88a8dd24be5932a10ed3ad2; editor is Warrens/PIEoff/dirty0.

Evidence: [material amendment](PHASE_5_CKUSF_MATERIAL_AMENDMENT.md), [all12before/after](evidence/phase-5/ckusf-20261022/twelve-areas-before-after.png), [independent closing check](evidence/phase-5/ckusf-20261022/lead-closing-gate.json). Palette and fallback tuning live in `presentation.materials` and `presentation.defaultMaterials` in `Tools/LevelDesign/anchor_plans/design_warrens_v7_geometry.json`.

## Verification and remaining work

- Current baseline before the material amendment: static131/131,320graph cases,5negative rejections; native898samples/0missing support,20clear starts,6crawls,valid Jolt. Counts are scoped evidence, not a full regression or AI-readiness claim.
- Phases2/3 contain real loaded/local gameplay observations and measured stand-ins; Phase5's final short approaches used an empty worn pack. No simultaneous two-human session is claimed.
- Phase4 normal heard audio remains pending; the user could not listen. Diagnostic app-volume bypass clips do not establish normal sound acceptance.
- Missing Phase5 sound deliveries, B/C presentation and Phase6 unfamiliar-pair rubric/recognition remain open. Global death/revive, networking/session/authority/replication, AI/hearing, draining water and kitchen sanctuary mechanics were not added.
- Historical GPU crash/modal and stale-runtime episodes interrupted verification. They were recovered or explicitly rejected; no engine kill/competing-instance shortcut or unsupported success claim substitutes for final evidence.
- No commits or pushes by this session. Current HEAD remains72d2f9592b854fd9948d0f7ec4aacc64e17b3fb3; shared/unrelated dirt is retained. Coherent checkpoints pair map, all Jolt collision files, generated inputs/source and owned assets for rollback.
