# Warrens v6r1: routes, unlocks and two-chef implications

Read-only source audit, 2026-10-20. Root HEAD supplied by lead: `3f075ca7fd9eac0b67d78c6b9c36b7290f2d0d47`. The current working files, rather than HEAD alone, are the reviewed inputs. This audit writes only this document and `route-audit.json`; it does not mutate the live map, run Unreal, build, test, commit or push.

## Result and evidence boundary

**Confirmed statically:** the current `warrens.json` is `v6r1`, 51 nodes / 59 links. All 64 allowed closure subsets (R1–R7, at most three closed) keep **every one of all 51 nodes** reachable from each of five entrances: 320 entrance/closure cases, zero disconnected nodes. Every case offers at least one court at or beyond the 50 m quarry minimum. Fresh Python recomputation used undirected links, integer `costCm`, and Dijkstra, independent of the AngelScript solver. The complete results and source hashes are in `route-audit.json`.

Fresh `build_warrens.manifest(write=False)` reproduces 3,875 boxes, 20 starts, 40 anchors, 6 nav fields, 5 entrance packs, 2 ladders, 7 fixed gates, 9 fixed mechanisms, 25 pockets, 6 crawls, and 31 lights. `gateLeaks`, `walkBreaks`, `ladderErrors`, `capErrors` and `connectorErrors` are empty. `crawlBypasses` is R2/R6/R5/R3, as intended for one-sided gate candidates. These are current static checks, **not** fresh collision, input, rendering, multiplayer or gameplay observations. G2's saved 19/19 resolver tests and PIE seeds are historical evidence only.

**Confirmed contract distinction:** the graph proves structural eventual connectivity. Its `Open` route role includes closed, operable gates, while the graph treats the kitchen cargo edge as an ordinary walk. It contains no control duration, possession, body clearance, lock state, quarry aggression, upper gallery, crawl or drop simulation. Unselected foyer mouth rubble is also outside the R1–R7 edge-closure model: the all-node result does not prove access to other foyer supplies. The graph result cannot establish that two players can execute a whole run or operate a kitchen. Source: `design_warrens_v6.py:45–76`, `Mars_Anchor_Presets.as:7–14`, `Mars_Gate_Feature.as:36`, `Mars_AnchorResolver_Solve.as:387–405,724–727`.

## Exact traversal shape

Coordinates below are design metres `(x,y,z)`, not Unreal world coordinates. The builder transforms to `((x-70),(y-55),z)*100` (`build_warrens.py:17`, `1536`). The appendices list every node and link exactly.

| Region | Graph nodes and floor | How it connects |
|---|---|---|
| Lamp Chapel / kitchen | K (0); aW/aS/aE/aN aisle (0); kn/ks door sills (0) | Public aisle ring connects west Court via R1, north Ossuary via stair kn–o0, south Pump via stair ks–p1, and east Well via aE–wW. K has only graph edge aE–K, through east cargo shutter. |
| Charnel Court | H1/p0/p3/ps (-1.5), h0/c3/s0/c1/c2 (0) | Three stairs into arena. S1 enters north. c2–o1 climbs to Ossuary; c1–ci2 descends toward Cistern via R6; c1–sp1 reaches west service spiral. |
| Ossuary / Bridge / Reliquary | O/o0/o1/BR/RQ/rq1 (+2.5) | O–BR is R5, BR–RQ is low but walkable, RQ–rq1–ch0 descends to Chime. S2 enters Reliquary. Ossuary also has upper gallery stair. |
| Well rim | wW/wN/wE/wS (0) | Four-segment ring; R4 closes only southwest segment, leaving other way round. R2 east connects Chime. R7 south starts descent toward Pit. |
| Chime Hall | CH/ch0/ch1/ch2 (0) | S3 enters east. ch1–d4 descends to Pit; ch2–sl1 descends toward Sluice. P5 ladder closes upper return loop after its gallery-side lever. |
| Southern service circuit | PU/p1/CE/SL/sl1/CI/ci1/ci2 (-2.5) | S4 enters Pump, S5 Cistern. PU–CE is R3. CE–SL–sl1–ch2 joins Chime; PU–CI joins Cistern; CI–ci2–c1 joins Court. CI–ci1–dg descends toward Drowned Gallery. |
| Undercroft / Pit | H2/d2/d4/dg (-5) | H2 reached by R7 sump stair and long d2 tunnel, or unrestricted Chime ch1–d4 stair and long east tunnel. dg dead-ends in graph; P2 opens its extra connection into Pit. Closet ladder and Vault are outside graph. |
| Root Grotto / Old Service Spiral | gE/gN/sp0 (-2.5), sp1 (0) | CI–gE is unconditional loaded east route; gE–gN crosses Grotto; gN–sp0 low tunnel reaches 18-tread spiral to sp1; sp1–c1 corridor joins Court. Overlook spur/drop and Root Listener recess are outside graph. |

Rooms/pockets outside graph are materially relevant: Vault (-5), kitchen roof recovery (+2.9 to +1.45), loft / west / north / east galleries (+5), Root Listener's Recess (-2.5), Sealed Burial (0), and the optional Mourner/Bellkeeper/Porter cache pockets. The 23 `rooms` rows include retired PumpTrap/CellarVents shells. The 25 pocket anchors are separate from graph nodes.

### Vertical, crawl and body restrictions

| Path | Restriction and return contract | Evidence |
|---|---|---|
| Six authored crawls | All `packFits=false`, 1.5 m wide / 1.3 m high. Unloaded crouch body 1.05 m, worn-pack crouch 1.40 m. Physical clearance enforces this; it is not an inventory prohibition. | `design_warrens_v5.py:150–156`; `design_warrens_v6.py:89–92`; `build_warrens.py:65–66`; `Mars_PlayerCharacter_Assets.as:79–84` |
| R2 crawl | Well rim → Chime side, z 0; optional scout reaches lever, carrier follows gate. | v5 `CRAWLS` / `LEVER_NODE` |
| R3 crawl | Pump → Salt Cellar side, z -2.5; carrier waits in Pump. | same |
| R5 crawl | Ossuary → Bridge side, z +2.5; carrier waits in Ossuary. | same |
| R6 crawl | Court southeast at z 0 → a 2.5 m one-way drop into Cistern. Scout can reach gate's Cistern-side lever; pack descends stair after release. Do not describe this crawl as bidirectional. | `design_warrens_v5.py:154` |
| Sealed Burial crawl | Only entrance to this optional random cache pocket; no gate/stair or required cargo route. | `design_warrens_v5.py:155` |
| Root Listener crawl | Optional small discovery pocket, no required ingredient or second exit; unloaded player returns through same squeeze. | `design_warrens_v6.py:89–92`; geometry JSON:55–68 |
| West kitchen service opening | Additional 1.5 × 1.3 m packless opening, initially shuttered, shares PK unlock. It is **not** one of the six crawl rows and is not a bypass of initial kitchen lock. | geometry JSON:666–682; builder:1291–1306 |
| Low ordinary links | BR–RQ, d4–H2 and PU–CI have 2.2 m low roof; dg–H2 entry remains in low-link metadata but dg–H2 is not a plan link. New sp0–gN has 2.2 m clear tunnel. These accommodate standing body/pack; low roof is not automatically crawl. | v5:214–215; v6:98 |
| Closet ladder | 5 m climb from Pit to chapel closet, worn pack allowed. SC2 still bars exit to public Chapel until opened from closet side. | v5:197–202; `Mars_Climber_Processor_Requests.as:102–141` has no pack refusal |
| Chime ladder | 5 m to east gallery; barred foot until P5 lever above. Pack intended to ride after unlock. | v5:201–203; builder:1219–1227 |
| Upper gallery access | Ossuary stair (+2.5 → +5), landing→loft→west gallery and ring around Well to east gallery. Return via west-gallery or east-gallery drops, or unlocked Chime ladder. | v5 `UPPER`, `EXTRA_RAMPS` |
| Loft drop / kitchen roof | Old loft descent now lands on continuous solid kitchen roof at +2.9 rather than entering K. Recovery ledge north at +1.45 returns to public floor. Physical clearance / fall damage needs observation. | geometry JSON:158–173, 212–229 |
| Grotto overlook | Court-side spur at 0 to deck; 1.4 × 1.4 m floor hole drops 2.5 m to Grotto. Optional scout route; return by spiral or Cistern, not ascent through hole. Worn-pack clearance explicitly unproven. | geometry JSON:704–718; v6:94–97 |
| Service spiral | 18 horizontal treads through 270°, 2.5 m width / 2.5 m rise, ~0.139 m risers, 2.2 m declared headroom. Intended loaded route; turn clearance needs real observation. | geometry JSON:744–871 |
| Water | Cistern basin and Drowned Gallery are sunk floors beneath collision-free dressing sheets. They do not slow or drain, despite older notes saying otherwise. | builder:106; v5 `WATER` |

### Random route closures and gate candidates

At run solve, one entrance is open and other four spawn mouths get rubble; one court gets quarry. R1–R7 draw a closure subset of cardinality 0–3 subject to connectivity. Closed routes always draw rubble. Remaining routes are `Open` role and draw an arch, a two-sided lever gate, or (R2/R3/R5/R6 only) a one-sided lever gate. The `Closed` ledger means permanently blocked route, not temporarily closed gate. Source: `Mars_AnchorResolver_Solve.as:597–758` and `Mars_Anchor_Presets.as:7–14,75–86`.

| Route | Exact edge | Placement from fresh manifest | One-sided lever side / scout alternative |
|---|---|---|---|
| R1 | aW–h0 (Chapel–Court Nave) | (30.1,43.7,0) | None; arch, two-sided gate or rubble |
| R2 | wE–CH (Well–Chime) | (72,46,0) | Chime CH; crawl-r2 |
| R3 | CE–PU (Salt Cellar–Pump) | (59,17,-2.5) | Salt Cellar CE; crawl-r3 |
| R4 | wS–wW (southwest Well rim) | (51.95,38,0) | None; other three rim segments always remain |
| R5 | O–BR (Ossuary–Bridge) | (50,66,+2.5) | Bridge BR; crawl-r5 |
| R6 | c1–ci2 (Court–Cistern stair) | (16.1601,25.4401,-1.5385) | Cistern ci2; crawl-r6, one-way drop |
| R7 | wS–d2 (sump stair to Pit) | (60,34.5,0) | None; alternative Chime stair remains available |

Important detail: plain open arch row has no entity, so does not call the crawl-plug helper. Rubble and two-sided gate candidates plug the associated crawl; one-sided candidates leave it open. A visible open crawl therefore does not uniquely tell players that a one-sided gate exists; an arch can also leave it open. `Mars_Anchor_Presets.as:10–13`; `Mars_Anchor_Candidates.as:31–45,65,97,193–204`.

Two-sided and one-sided candidate levers use **manual grip + look pull**, not a simple timed Use. Pull crosses default `EngageAlpha=0.85`; each gate latches. All gates begin closed (`StartOpen=false`). `Open` role does not mean a raised gate at spawn. This corrects the literal claim in historical `G2_PROGRESS.md` that a role-Open gate is a raised gate with no job. Source: candidates:79–128,173–219; Control Feature:61; Gate Feature:36.

## Fixed mechanisms: what actually unlocks what

All fixed gates below start shut and latch after their source succeeds. Latch is retained runtime entity state, not a cross-run save; the sink processor keeps powered true once powered (`Mars_MechanismSink_Processor_Requests.as:38–40`). No authored fixed gate here requires someone to keep holding a control. No fixed puzzle requires simultaneous contributions from both chefs.

| ID / target | Control and real emitted location | Action / persistence / reset | Effect and cargo significance |
|---|---|---|---|
| P1 Vault door (73,59,-5) | Red key on east gallery plinth (68.3,42,5.3), key lock (72,57.3,-5) | Insert Red key; lock keeps it (`Release=Kept`), door sink latches. Both sides of door are not separately operable; the lock is on Pit side. No authored timer/reset. | Opens optional Vault access from Pit. Key acquisition travels up Ossuary gallery stair and around upper ring. P1 does not connect a required graph route. |
| P2 Drowned Gallery grate (51.3333,27.75,-5) | Wall-mounted wheel in Sluice (84,10.1,-1.4), not the schematic `needsAt=(84,13,-2.5)` | Timed Use 2 s, wheel toggles source, grate latches. No ongoing hold; subsequent source changes do not close it. | Adds Cistern stair/dg ↔ Pit return option, absent from plan graph. Water neither drains nor slows. Loaded traversability depends on physical tunnel, not water mechanics. |
| P3 Mourner cache gate (79,74.25,+2.5) | Pressure plate (44,72,+2.5), Ossuary | Detects **Player OR Backpack**, `RequiredCount=1`, release delay 0.5 s; gate latches first occupancy. Plate itself releases; gate does not. No maintained split and no real pack requirement. | Optional cache room 35 m away. Cache may be dormant; opening gate does not guarantee a pickup. Solo player can step on plate and then walk to gate. |
| P4 Bellkeeper gate (89,58.25,0) | Square seal (87,57.98,1.2), Triangle (91,57.98,1.2); sequence pedestal inside niche (89,60,0) | Instant seal presses pulse 0.4 s. Square then Triangle auto-completes sequence; wrong input resets sequence; no step timeout; sequence and gate latch. No bell commit, candles or attrition. | Opens optional **random** cache room. Current clue is a plain box; successful order is in logic, not readable world glyph. Pedestal shares niche centre with cache anchor. |
| P5 Chime ladder foot (75.25,50,0) | Lever on east gallery (71,50,+5) | Default lever uses Instant Use (unlike manual route/SC2 grip levers); gate latches. Only authored control is above. | After initial Ossuary→galleries traversal, opens loaded Chime↔gallery access and west-drop home loop. Door is not a kickable ladder. |
| P6 / SC2 closet exit (46,35,0) | Single manual grip lever on closet side; shortcut local Behind, yaw 90° | Climb from Pit to closet at (50,33), then pull with grip/look. Bars latch. Cannot initially operate from public Chapel side. No hold/reset. | Loaded Pit→closet ladder→public Chapel→east kitchen cargo port home loop. **v6 still requires PK** to use kitchen; old v5 '17 m to hearth' note does not include kitchen wall/entry detour. There is no SC1 row in current data. |
| PK kitchen cargo (45,44,0), service (34.8,47.8,0) | Exterior west wheel (34.875,49.2,1.1), inside emergency release (35.125,49.2,1.1) | Either wheel: timed Use 2 s, toggles own source; both gates share PK channel and latch. Neither requires tool. Interior wheel is only usable after entry/recovery, not prerequisite to initial unlock. | Opens both shutters once for run. East 2 × 2.2 m port carries pack; west 1.5 × 1.3 m port is unloaded-only. Initial required action is outside on west wall; cargo entry remains on east side. |

Authoritative wiring: `build_warrens.py:1219–1306`; locations above were regenerated with `manifest(write=False)` on current data. Prefab semantics: `Mars_SandboxKeys.as:9–14,61–68`; `Mars_KeyLock_EntityScript.as:17`; `Mars_HandWheel_EntityScript.as:14–15`; `Mars_Lever_EntityScript.as` Control defaults; `Mars_Seal_EntityScript.as:21–24`; `Mars_Sequence_Feature.as:21–32`; `Mars_Shortcut_EntityScript.as:49–66`.

## Practical loaded returns and recovery

| Starting area | Initial broad return | Reward after unlock / alternate recovery |
|---|---|---|
| Pit | Sump tunnel→R7 stair→Well, or east tunnel→Chime stair→Well/upper circuit. Closure-safe but long in some sets. | Closet ladder→SC2→Chapel aisle→east cargo port. P2 adds Drowned Gallery→Cistern→Pump/Chapel or Court route. |
| Chime / Reliquary | Chime→R2→Well; if R2 rubble, northern wing via R5 or southern service circuit. | P5 ladder→east gallery→north/west gallery→west drop→public Chapel aisle→cargo. Pack allowed on ladder by current implementation; actual turns/drop observation still needed. |
| Grotto | East tunnel→CI→PU→p1→ks→Chapel aisle; this remains available for every closure set. | North low tunnel→service spiral→Court→Chapel, using alternate Court exits when R1 rubble. Optional overlook drop is not a required cargo path. |
| Root Listener / Sealed Burial | Leave pack outside, take optional pickup/discovery, exit same crawl. | No cargo-only back exit. A dropped pack or incapacitated chef inside these pockets needs physical recovery behavior; graph never models them. |
| Kitchen roof | Roof recovery ledge at north edge→public floor. | Roof is sealed; do not assume old loft hole enters kitchen. |

Open graph court→K distances are H1 49.98 m, H2 73.16 m, CH 60.03 m, measured along graph polylines. They omit shortcut unlocks, cargo handling and control actions. Grotto gE→K is 94.95 m open graph. Detailed per-entrance extrema are in `route-audit.json`; do not turn those lengths into completion-time estimates without observed speed/interaction data.

## Proposal-i versus current gameplay

| Proposal | Current confirmed status |
|---|---|
| Four-glyph Triangle, Square, Triangle, Circle, neutral four-slot panel, bell-chain commit, 3 candles, wrong-ring reward attrition | **Not implemented by current builder.** P4 still two seals Square→Triangle, default sequence pedestal, no commit and no stakes. `PROPOSAL_I.md:1–28`; builder:1273–1290. |
| Readable environmental clue seen from Bridge | **Not present in current builder:** plain box stand-in; order only in sequence node. Current cold Pit lamp scaled 0.1, and v6 comment says clue needs its own light when G4 lands. builder:107; v6:120–124. |
| Authored three-item Bellkeeper reward, removed from random cache pool | **Not implemented.** Live data still has four cache anchors including Bellkeeper; `MaxActiveCaches=2`. Two Active entries chosen per run; other two Dormant/null. Active cache yields one Tenderizer, Cleaver or Ration. v5:296; Presets:30–37; Solve:745–759. |
| Mourner active; Sealed Burial / Porter spent pocket policy | **Not implemented.** Cache budget is generic shuffle and no pocket-specific policies are supplied. Proposal itself flags missing resolver mechanism (`PROPOSAL_I.md:63–64`). |
| Grotto crown harvest, bait for intact quarry harvest, vent contest, quality receipt and shared prep | **Proposed G6 work.** Current geometry has shelf/cover shapes, no corresponding mission dependency in reviewed map builder/plan. G2 execution explicitly excludes these (`G2_EXECUTION_PLAN.md:7–9`). |
| Expanded operational kitchen, readable contract and required tools | **Not operational in builder-generated content.** Kitchen bench/station props are boxes (`prop_boxes`:941–962, called1136–1138); fresh manifest contains zero Station entity rows. No readable contract/tool grant is emitted there. Separate manually placed actors need a live-map inventory. |

## Starting resources and missing reward promises

**Confirmed in generated source:** the party uses separate start slots in the same selected foyer (`Mars_Expedition_GameMode.as:28–54`), which has one backpack, not one per chef (`build_warrens.py:1327`). The other four packs lie at their other foyer pads beyond closed spawn mouths. Court/Chime/Pit pack anchors create dry slab plinths only, not more packs (`Mars_Anchor_Candidates.as:264–283`). After builder apply, `Mars.Warrens.PlaceLantern` places one lantern plus two tallow per entrance backpack (`build_warrens.py:1684`; `Mars_WarrensMapBuilder.as:4–8,54–59`). Thus the selected foyer offers a shared light/fuel/cargo kit. Actual saved-map duplicates, previous manual grants or changed inventory require runtime inventory; manifest alone does not include the editor-added lantern set.

Player construction adds an empty hotbar (`Mars_PlayerCharacter.as:346–348`; `Mars_Hotbar_Utils.as:64–111`); its slots contain no default Cleaver, Tenderizer or cooking implement. No tool grant was found in reviewed PlayerCharacter/GameMode initialization. Cache pickups and explicit cheat grants are separate paths. This source result does not claim a fresh runtime hotbar was observed.

**Confirmed in fresh generated manifest:** inside and immediately around Vault (x72..84, y54..64, z<-3), the only entity rows are Red door and Red lock. There is no Vault pickup, reward or cache anchor; the four live cache anchors are Mourner/Bellkeeper/SealedBurial/Porter. The key route currently unlocks a generated empty room. A separate hand-placed map reward remains an explicit unknown, so call this absence in builder-generated content, not proof every saved-map actor is empty.

## Ranked findings and uncertainties

1. **High, confirmed composition limit:** combat explicitly supports Standalone/ListenServer only, excludes clients and dedicated server (`Script/Common/Mars_LocalSession.as:3–12`). Player health/hurtbox receiver additionally requires local control, so joined remote players are excluded from receiver composition (`Script/PlayerCharacter/Mars_PlayerCharacter.as:374–389`). Crawler arming shares this fence (`Script/ECS/Crawler/Mars_Crawler_Utils.as:104–105`). This is a confirmed source limit, not merely a missing test. Actual two-process symptoms still require observation.
2. **High, confirmed architecture asymmetry; runtime consequence inferred:** random route/quarry/cache resolution is spawned only where an anchored GameMode exists; the subsystem explicitly returns on clients (`Mars_AnchorResolver_Subsystem.as:1–2,23–25`). Resolver, anchors and candidates use `DoesNotReplicate` (`Mars_AnchorResolver_EntityScript.as:7`; Presets:139; Candidates:52,82,176), with candidate spawning only on resolve (`Mars_Anchor_Processor_Requests.as:50–57`). This gives no evident client population path for server-resolved geometry and rewards. A remote chef may see different traversability or absent candidates. A two-process listen-server/remote-client walk must confirm actual symptom; no multiplayer success can be claimed from static connectivity.
3. **High for intended puzzle, confirmed missing implementation:** P4 has no readable clue or proposal-i stakes. It is currently a two-button sequence with four possible two-press strings, no time pressure and no loss; a second chef need not report a clue from elsewhere. The proposed cooperative memory task is not the live experience. Remedy should follow approved G4, not silently assess its future form as shipped.
4. **Medium, confirmed cooperation structure:** all gates latch, P3 accepts one chef, wheels are local one-person actions, and route gates are solvable sequentially. Two players can choose scout/carrier roles, but no fixed puzzle forces either maintained separation or simultaneous action. This can be a deliberate accessibility choice; it cannot support a claim of mandatory cooperation.
5. **Medium, confirmed graph abstraction:** K is graph-reachable before any PK action; graph quarry min-distance and home-distance do not include finding crank, two-second turn, east cargo walk, optional ladder returns, or real cargo. Static closure proof is necessary but insufficient for both chefs completing extraction.
6. **Medium uncertainty, grounded in code:** packless gates rely on capsule height. `Mars_PlayerCharacter_Hfsm_Inventory.as:187–190` explicitly says equipping a backpack while already crouched resizes from **next** crouch; line 239 only updates `SetCrouchedHalfHeight`. Inference: equip-after-entry may bypass intended pack exclusion. Reproduce before calling exploit confirmed. No gameplay patch belongs in this review.
7. **Medium acceptance gaps:** loaded spiral turns; 1.4 m overlook hole with worn pack; kitchen roof descent/fall damage; both kitchen shutters actually lifting/remaining clear; dropped/disabled partner retrieval; manual grip prompt disengagement. G2 explicitly leaves these real-input walk checks open (`G2_PROGRESS.md:100–111`).
8. **Low, confirmed semantic drift in old notes:** water does not drain/slow, role-Open gate begins closed, old v5 direct-to-hearth distances no longer describe sealed v6 kitchen, and SC1 is absent. Use current source table above when briefing players.

Potential adjacent issue, left untouched: P4's default sequence pedestal and random cache anchor share the niche centre (89,60,0). Collision/reward accessibility depends on spawned pickup geometry and requires observation; do not call it blocked from co-location alone.

## Reproduction

Read-only Python, from project root: load `warrens.json`, enumerate `itertools.combinations(R1..R7, n)` for n=0..3; treat every unclosed JSON link as undirected with integer `costCm`; Dijkstra from S1..S5; assert all 51 nodes finite and at least one court distance >=5000 cm. Independently import builder under `python -B` and call `manifest(write=False)`; this code path returns manifest/summary without writing `Saved/AnchorPlans` (`build_warrens.py:1527–1533`). Exact current audit output and input SHA-256 values are saved alongside this document.

Memory was consulted only to identify historical Warrens context; all load-bearing map/mechanism statements above were refreshed from current source. Relevant memory registry: `MEMORY.md:120–132`; historical v5 evidence must not be promoted to v6 runtime proof.


## Appendix A: every graph node

| Node | Design (x,y,z) m |
|---|---|
| `K` | (40, 44, 0) |
| `kn` | (40, 52.5, 0) |
| `ks` | (42, 35.5, 0) |
| `H1` | (16, 42, -1.5) |
| `p0` | (24, 43, -1.5) |
| `p3` | (12, 49.5, -1.5) |
| `ps` | (18, 34, -1.5) |
| `h0` | (28, 43, 0) |
| `c3` | (12, 55, 0) |
| `s0` | (18, 30.5, 0) |
| `c1` | (13, 30, 0) |
| `c2` | (24, 55, 0) |
| `O` | (41, 67, 2.5) |
| `o0` | (40, 61, 2.5) |
| `o1` | (34, 63, 2.5) |
| `BR` | (60, 60, 2.5) |
| `RQ` | (73, 68, 2.5) |
| `rq1` | (78, 62, 2.5) |
| `wW` | (52, 44, 0) |
| `wN` | (60, 51.5, 0) |
| `wE` | (68, 44, 0) |
| `wS` | (60, 36.5, 0) |
| `CH` | (84, 48, 0) |
| `ch0` | (84, 56, 0) |
| `ch1` | (73, 39, 0) |
| `ch2` | (84, 38, 0) |
| `PU` | (51, 17, -2.5) |
| `p1` | (46, 24, -2.5) |
| `CE` | (65, 14, -2.5) |
| `SL` | (79, 16, -2.5) |
| `sl1` | (84, 23, -2.5) |
| `CI` | (34, 19, -2.5) |
| `ci1` | (38, 16, -2.5) |
| `ci2` | (18, 22.5, -2.5) |
| `H2` | (60, 44, -5) |
| `d2` | (60, 19, -5) |
| `d4` | (70, 24, -5) |
| `dg` | (48, 22, -5) |
| `S1` | (4, 62, 0) |
| `S2` | (73, 82, 2.5) |
| `S3` | (100, 34, 0) |
| `S4` | (51, 3, -2.5) |
| `S5` | (34, 3, -2.5) |
| `aW` | (33, 45.6, 0) |
| `aS` | (42, 39.5, 0) |
| `aE` | (47, 44, 0) |
| `aN` | (40, 51.5, 0) |
| `gE` | (0, 15, -2.5) |
| `gN` | (-6, 24, -2.5) |
| `sp0` | (-4.5, 43, -2.5) |
| `sp1` | (-8, 39.5, 0) |

## Appendix B: every undirected graph link

Costs are authored centreline metres; these do not add control time, doorway detours or optional routes.

| # | Endpoints | Kind | Closure | Lever node | Cost m |
|---|---|---|---|---|---|
| 0 | `S1` ↔ `c3` | walk | — | — | 12.07 |
| 1 | `S2` ↔ `RQ` | walk | — | — | 14.00 |
| 2 | `S3` ↔ `CH` | walk | — | — | 23.36 |
| 3 | `S4` ↔ `PU` | walk | — | — | 14.00 |
| 4 | `S5` ↔ `CI` | walk | — | — | 16.00 |
| 5 | `kn` ↔ `o0` | stair | — | — | 8.86 |
| 6 | `o0` ↔ `O` | walk | — | — | 6.08 |
| 7 | `ks` ↔ `p1` | stair | — | — | 12.43 |
| 8 | `wW` ↔ `wN` | walk | — | — | 15.50 |
| 9 | `wN` ↔ `wE` | walk | — | — | 15.50 |
| 10 | `wE` ↔ `wS` | walk | — | — | 15.50 |
| 11 | `wS` ↔ `wW` | walk | R4 | — | 15.50 |
| 12 | `wE` ↔ `CH` | walk | R2 | CH | 17.03 |
| 13 | `wS` ↔ `d2` | stair | R7 | — | 18.20 |
| 14 | `h0` ↔ `p0` | stair | — | — | 4.27 |
| 15 | `c3` ↔ `p3` | stair | — | — | 5.70 |
| 16 | `s0` ↔ `ps` | stair | — | — | 3.81 |
| 17 | `p0` ↔ `H1` | walk | — | — | 8.06 |
| 18 | `p3` ↔ `H1` | walk | — | — | 8.50 |
| 19 | `ps` ↔ `H1` | walk | — | — | 8.25 |
| 20 | `h0` ↔ `c2` | walk | — | — | 14.00 |
| 21 | `c3` ↔ `c2` | walk | — | — | 12.00 |
| 22 | `s0` ↔ `c1` | walk | — | — | 5.02 |
| 23 | `c1` ↔ `ci2` | stair | R6 | ci2 | 9.35 |
| 24 | `c2` ↔ `o1` | stair | — | — | 13.05 |
| 25 | `o1` ↔ `O` | walk | — | — | 8.06 |
| 26 | `O` ↔ `BR` | walk | R5 | BR | 21.67 |
| 27 | `BR` ↔ `RQ` | walk | — | — | 16.18 |
| 28 | `RQ` ↔ `rq1` | walk | — | — | 7.81 |
| 29 | `rq1` ↔ `ch0` | stair | — | — | 8.85 |
| 30 | `ch0` ↔ `CH` | walk | — | — | 8.00 |
| 31 | `CH` ↔ `ch1` | walk | — | — | 14.24 |
| 32 | `CH` ↔ `ch2` | walk | — | — | 10.00 |
| 33 | `ch1` ↔ `d4` | stair | — | — | 16.09 |
| 34 | `ch2` ↔ `sl1` | stair | — | — | 15.21 |
| 35 | `sl1` ↔ `SL` | walk | — | — | 8.60 |
| 36 | `SL` ↔ `CE` | walk | — | — | 15.07 |
| 37 | `CE` ↔ `PU` | walk | R3 | CE | 15.24 |
| 38 | `PU` ↔ `p1` | walk | — | — | 8.60 |
| 39 | `PU` ↔ `CI` | walk | — | — | 18.21 |
| 40 | `CI` ↔ `ci2` | walk | — | — | 17.67 |
| 41 | `CI` ↔ `ci1` | walk | — | — | 5.00 |
| 42 | `ci1` ↔ `dg` | stair | — | — | 11.93 |
| 43 | `d2` ↔ `H2` | walk | — | — | 27.46 |
| 44 | `d4` ↔ `H2` | walk | — | — | 38.36 |
| 45 | `aW` ↔ `h0` | walk | R1 | — | 6.05 |
| 46 | `aW` ↔ `aS` | walk | — | — | 15.10 |
| 47 | `aS` ↔ `aE` | walk | — | — | 9.50 |
| 48 | `aS` ↔ `ks` | walk | — | — | 4.00 |
| 49 | `aW` ↔ `aN` | walk | — | — | 12.90 |
| 50 | `aN` ↔ `aE` | walk | — | — | 14.50 |
| 51 | `aN` ↔ `kn` | walk | — | — | 1.00 |
| 52 | `aE` ↔ `wW` | walk | — | — | 5.00 |
| 53 | `aE` ↔ `K` | walk | — | — | 7.00 |
| 54 | `CI` ↔ `gE` | walk | — | — | 35.21 |
| 55 | `gE` ↔ `gN` | walk | — | — | 11.79 |
| 56 | `c1` ↔ `sp1` | walk | — | — | 25.13 |
| 57 | `sp1` ↔ `sp0` | spiral | — | — | 16.68 |
| 58 | `sp0` ↔ `gN` | walk | — | — | 22.39 |

## Appendix C: all pocket anchors

| Pocket | Anchor | Family | Position m |
|---|---|---|---|
| court-pack | CourtPack | P | (10.0, 57.5, 0) |
| court-forage | CourtForage | F | (4.0, 38.0, 0) |
| court-omen | CourtOmen | O | (29.0, 51.0, 0) |
| court-threat | CourtThreat | T | (22.0, 28.0, 0) |
| ossuary-husk | OssuaryHusk | F | (38.0, 74.5, 2.5) |
| ossuary-rest | OssuaryRest | N | (32.0, 65.5, 2.5) |
| bridge-omen | BridgeOmen | O | (60.0, 65.0, 2.5) |
| mourner | Mourner | C | (79.0, 76.0, 2.5) |
| reliquary-omen | ReliquaryOmen | O | (81.0, 68.0, 2.5) |
| reliquary-rest | ReliquaryRest | N | (68.0, 75.5, 2.5) |
| bellkeeper | Bellkeeper | C | (89.0, 60.0, 0) |
| chime-threat | ChimeThreat | T | (88.0, 36.0, 0) |
| chime-pack | ChimePack | P | (92.0, 36.0, 0) |
| chime-rest | ChimeRest | N | (95.5, 51.5, 0) |
| sealed-burial | SealedBurial | C | (100.5, 59.0, 0) |
| cellar-salt | CellarSalt | F | (64.0, 21.5, -2.5) |
| porter | Porter | C | (90.0, 13.0, -2.5) |
| sluice-rest | SluiceRest | N | (74.0, 23.5, -2.5) |
| sluice-threat | SluiceThreat | T | (78.0, 8.0, -2.5) |
| pump-omen | PumpOmen | O | (42.0, 13.5, -2.5) |
| pit-pack | PitPack | P | (46.0, 30.0, -5) |
| cistern-forage | CisternForage | F | (20.0, 12.0, -2.5) |
| pit-rest | PitRest | N | (46.0, 42.0, -5) |
| pit-forage | PitForage | F | (74.0, 36.0, -5) |
| pit-omen | PitOmen | O | (57.0, 59.0, -5) |
