# Warrens: two-person level-design implementation handoff

**Planning package, 2026-10-20. Implementation has not started.** Improve the existing compact Warrens so two people can understand, explore, solve, carry and return together. The governing user correction is: **“We don't want to tackle MP specific issues but more so the layout and intention being fit for 2 players.”**

This package supersedes the review's proposed implementation priority, including its network/recovery-first recommendation. Keep that review as historical analysis. No replication, RPC, authority, client-combat parity, host migration, reconnect, session-flow or network-test work belongs here, including as a prerequisite. Record such faults only as observation confounds. Likewise exclude a game-wide death/revive system, new monster AI, bait systems, service grading and a new cooking campaign.

## Executable specification: scored design rubric

Score each row **0 = missing/contradicted; 1 = authored and supported by static or staged observation; 2 = demonstrated by unfamiliar people in the applicable walkthrough**. Mark the evidence mode beside every score. A solo run cannot earn a two-human gameplay claim. **Authored-design acceptance requires every row at least 1 and all hard gates below.** The separate observational target is **at least 16/20, no zero**, after three unfamiliar pairs. Unobserved human rows remain pending evidence; they do not block completion of local authoring or trigger network work. These are project targets, not externally validated standards.

| Criterion | Evidence needed for 2 |
|---|---|
| Orientation | Each of three unfamiliar pairs identifies kitchen, Well and return direction without a designer instruction. |
| Consequential routes | Each pair explains one route choice through information, access or cargo cost; “the only open way” alone does not count. |
| Paired agency | Both people perform consequential actions; no required stationary waiting over 15 seconds. Watching a changing hazard or communicating a clue counts; standing idle does not. |
| Separation/reunion | A voluntary scout trip buys information/access, has a visible reunion point, and can be completed sequentially by one active chef. |
| Cargo movement | Both roles traverse ports, ladders and approaches; actual pack/food tests reveal no unrecoverable obstruction or dropped-cargo trap. |
| Mechanism literacy | Players correctly predict PK, P2, P3 and scout-latch effects; Bellkeeper dials show what is set but no correctness before the chain is pulled. |
| Reward honesty | Optional costs reveal their payoff/stakes; P1 and Mourner always offer authored fuel, Bellkeeper explicitly preserves its last pickup. |
| Area identity | From unlabelled first-person views, people distinguish at least 9 of the 12 groups by shape/object arrangement, not only color. |
| Horror progression | Each person identifies anticipation, exposure and release at intended spatial beats; essential actions remain readable in darkness. |
| Learned return | On repetition the pair uses a discovered shortcut and can explain why its loaded return differs from its outward route. |

**Hard gates:** the 64 legal closure sets × five entrances stay connected; mandatory objectives never depend on a simultaneous two-person hold; cargo has a recoverable destination after every authored drop; the Well remains visible from its existing vertical layers; no essential route is hidden behind Bellkeeper; no visual/audio cue falsely promises an unimplemented drain, alarm, sanctuary or rescue rule.

## Chosen approach and decisions

Use **a new v7 authoring layer**: `design_warrens_v7.py` deep-copies `design_warrens_v6.build()` and applies explicit deltas. Its paired `design_warrens_v7_geometry.json` is a copied, independently owned geometry source. Emit `data/warrens.json` as `v7r1`. Do not mutate imported v5/v6 tables or edit their frozen source. The shared builder gains opt-in data handling; absence of the new fields preserves v6 output. This follows the existing v6-on-v5 history without making the old revision silently change.

Keep footprint `[-29,-3,104,88]`, the 51-node/59-link main graph, Well heights, both Grotto approaches, kitchen aisle and both useful ladders. Adjust local walkable envelopes and furnishings inside that footprint. Do not add another district, obligatory all-map circuit or travel padding.

The spatial story is **a monastery whose kitchen, processional courts, ossuary, brine works and maintenance passages now feed the lower larder**. Reuse a small flat-shaded kit but change composition and silhouette. Amber marks inhabited work; cool light exposes distant depth; local contrast preserves actions. The horror arc is welcome/work → shared Well revelation → optional information/access split → exposed acquisition/commitment → loaded return → task relief. Kitchen relief is an editorial beat; this package does not invent a guaranteed threat sanctuary.

Role assignments are temporary: carrier, scout, light bearer, reader and operator. Reunions occur at gate mouths, staging bays, ladder landings and the kitchen receiving area. Every essential action is sequentially possible by one active chef; a partner improves information, handling or throughput. No new two-person hard lock.

Lock the interaction contract:

| Element | Result to implement |
|---|---|
| R routes | Warrens-specific route table: ordinary open arch, closed rubble, or eligible far-side scout latch. Remove the ordinary two-sided lever tax from this map's new table; preserve generic tables and existing role solver. |
| PK | Existing west exterior or inside 2-second wheel releases both shutters permanently for the run. East cargo port remains the loaded entrance; west service port remains optional packless access. |
| P2 | Existing Sluice wheel releases the distant Drowned Gallery bars. Repeated emblem/pipe path and visible latch movement communicate this. Water does not drain. |
| P3 | Existing single chef **or** pack occupancy latches Mourner open. Show one occupancy mark, never two-player symbols. One fixed tallow supplements the existing optional cache anchor. |
| P1 | Existing gallery key opens Vault. Two fixed tallow on separate rests make the detour useful. No required tool or objective behind it. |
| P5 / SC2 | Existing persistent Chime ladder release / closet return shortcut; protect loaded landings and sightlines. |
| P4 | Bellkeeper dial lock (amends C1/C3, 2026-10-20): three dials × six glyphs (216 combinations), no per-dial feedback, pull-chain commit rings the bell, clue from Bridge; each failed commit fires a local steam vent (push only) and the first two lose Cleaver then Tenderizer; Ration remains. Local only. |

The selected entry retains one shared pack, lantern and two tallow and gains **one Pan**, an existing foraging tool. Do not give portable Cleaver/Tenderizer at entry or kitchen. Reused stations include their own station implements; that does not award those portable items. Ration currently has a timed consume action, not an established healing effect; its guaranteed presence is a content promise, not proof of meaningful value. Record if players regard it or duplicate random weapons as worthless. Changing its mechanics is outside this plan.

Remove Bellkeeper from the random cache pool: **four → three anchors, maximum active remains two**. Keep Mourner's cache anchor and place its fixed tallow separately. Do not lower a test's minimum-cache assertion to hide an accidental second removal. Random tools may duplicate Bellkeeper rewards; observe the resulting valuation rather than claiming all seeds have identical stakes.

## Phase order

1. [Baseline and contracts](PHASE_1.md): freeze receipts, fixture scenarios, asset/API preflight and measured placement envelopes.
2. [Spatial revision](PHASE_2.md): v7 geometry, cargo/reunion affordances and all twelve structural identities.
3. [Local routes and fixtures](PHASE_3.md): honest route/gate vocabulary, dependable rewards and bounded kitchen reuse.
4. [Bellkeeper](PHASE_4.md): Dial and Bellkeeper kernels and the authored dial-lock encounter; Sequence untouched.
5. [Presentation](PHASE_5.md): three bounded district batches of materials, dressing, local light and positional sound.
6. [Design acceptance](PHASE_6.md): paired, role-swapped scenarios, rubric and one bounded correction pass.

Run one phase per executor session. Phase 5 may resume between its three district checkpoints; its state lives only in PROGRESS. On a failed gate STOP and record expected/actual evidence and ownership. After two failed attempts at a symptom, stop tuning and return a bounded decision; do not expand scope.

## Evidence and source map

Planning baseline is HEAD `3f075ca7fd9eac0b67d78c6b9c36b7290f2d0d47`. The fresh read-only manifest had 3,875 boxes, 40 anchors, seven gates, nine mechanisms, 25 pockets, six crawls and 31 lights; five geometry-error arrays were empty. The independent graph audit had 320/320 connected cases. These prove source/static properties, not physical traversal. No build, automation or Warrens play session was run for this planning package.

Read [the review](../../reviews/2026-10-20-warrens-two-player/LEVEL_DESIGN_REVIEW.md), [route inventory](../../reviews/2026-10-20-warrens-two-player/ROUTES_AND_UNLOCKS.md), [source receipt](../../reviews/2026-10-20-warrens-two-player/SOURCE_RECEIPT.json) and [static results](../../reviews/2026-10-20-warrens-two-player/route-audit.json). The builder README and pre-G2 protected hashes are stale. Current v6 generator/data and fresh source outrank them.

| Read/reference path, relative to repository | Why it matters / ownership |
|---|---|
| `Tools/LevelDesign/anchor_plans/design_warrens_v6.py:7–22,45–80,145–174` | Frozen spatial baseline and live emission shape; read only. |
| `Tools/LevelDesign/anchor_plans/design_warrens_v6_geometry.json` | Frozen kitchen/spiral/deck geometry and prop positions; read only. |
| `Tools/LevelDesign/anchor_plans/design_warrens_v5.py:63–197,296` | Inherited node, ladder, puzzle and cache contracts; read only. |
| `Tools/LevelDesign/anchor_plans/build_warrens.py:292,941–967,1219–1330,1540–1684` | Modify only scoped v7 geometry/fixture/presentation emission; existing box, gate, control and entity-spawn patterns. |
| `Tools/LevelDesign/anchor_plans/data/warrens.json` | Generated live consumer; regenerate from v7, never hand-edit. |
| `Tools/LevelDesign/anchor_plans/emit_plan.py`; `Script/ECS/AnchorResolver/Plans/Mars_AnchorPlan_Warrens.as` | Read-only emitter; emitted AS plan is regenerated in Phases 2/3/4 and tested whenever it changes. |
| `Content/Mars/Maps/Warrens_Mars_MAP.umap` | Future generated scene; checkpoint before rebuilding because apply replaces owned actors. |
| `Content/CkJoltData/Mars/Maps/Warrens_Mars_MAP/` | Generated collision cells/index: checkpoint and restore with the map, never independently. |
| `Script/WorldObjects/Anchors/Mars_Anchor_Presets.as:7–35,137–214` | Read-only table and protected virtual `Get_Table()` exemplar. |
| `Script/WorldObjects/Anchors/Mars_Anchor_Candidates.as:79–120,180–220` | Read-only candidate gate/source composition; reuse existing classes. |
| `Script/ECS/Sequence/Mars_Sequence_{Feature,Utils,Processor_Setup,Processor_Requests}.as` | Read-only since the dial amendment; feature-quartet exemplar for Phase 4's new Dial and Bellkeeper kernels. |
| `Script/WorldObjects/Mechanisms/Mars_SequenceNode_EntityScript.as` | Read-only existing node (sink + source on one entity); Warrens P4 stops using it, other consumers stay unchanged. |
| `Script/WorldObjects/Mechanisms/Mars_Seal_EntityScript.as`, `Mars_PullChain_EntityScript.as`, `Mars_Vent_EntityScript.as` | Read-only glyph-mesh/Control exemplar, release-to-rearm commit control, and the powered steam vent reused as the failed-commit consequence. |
| `Script/WorldObjects/Stations/Mars_CuttingStation_EntityScript.as`, `Mars_SearingStation_EntityScript.as`, `Mars_Station_EntityScript.as` | Read-only existing functional station dimensions, grips/camera and audio ownership. |
| `Script/Editor/Mars_SandboxMapBuilder.as:576–594,680–683`; `Script/Editor/Mars_WarrensMapBuilder.as` | Read-only station/platter placement and existing entrance lantern fixture. |
| `Script/WorldObjects/Items/Mars_SandboxItems.as:9–24`; `Script/Items/Mars_Item_Sandbox.as:10–23` | Existing Pan/tallow/ration class and limited consume semantics. |
| `Script/Tests/Sequence/Mars_AutoTestRig_Sequence.as` | Read-only rig exemplar; Phase 4 adds its own Dial and Bellkeeper rigs. |
| `Config/DefaultGameplayTags.ini:1218–1221` | Phase 4 adds `P4.Commit` and `P4.Vent`, retains the P4 output, retires `P4.SealA`/`P4.SealB` once unused. |
| `docs/design/warrens-expansion-r02/PROPOSAL_I.md`, `proposal.json:bellkeeperEncounter` | Approved C1/C3 clue location and reward rests; its seal/slot semantics are superseded by the dial amendment. Historical static evidence only. |
| `docs/concepts/mise-en-monstre/VISUAL_BOARD.md:9–13` | Flat-shaded material/graphic food style; older prohibition on distinct architecture is superseded. |

New files are named by phase: v7 generator/geometry/validator, Warrens route preset, Dial and Bellkeeper kernels, the Bellkeeper panel/clue/glyph composers and focused tests. Assets stay under `Content/Mars/Environment/Warrens/`. Generated AS is never hand-written; Phase 4 names the root-guidance exception for two `DynamicHandleTypes.json` registrations (Dial, Bellkeeper). No submodule edits.

## Rejected approaches and fences

- Expand the map or mandate every district per run: existing distance and alternatives need purpose, not more area.
- Gate progress on mandatory simultaneous occupancy: strands one active player and produces waiting rather than agency.
- Change generic route-table weights: spills a map-specific decision into other maps; use a dedicated subclass/table.
- Implement Bellkeeper with pressed seals, either through old per-step callbacks (timing-dependent partial resets, leaks correctness) or a commit-mode Sequence extension (an invisible entry buffer, and a misclick wipes the entry): dials keep the attempt visible, make every commit a full guess and leave Sequence untouched.
- Give a failed commit per-dial or Mastermind-style feedback: makes the clue optional and turns the lock back into safecracking.
- Use debug `PinnedRow` as a shipping solver: pins can contradict solved roles. Diagnostic pins must be labelled and the resulting actual graph checked.
- Turn color/blackness into the entire art pass: each district gets its own silhouette, threshold, object arrangement and sound source.
- Treat warm kitchen lights as creature protection: current ward requires a held lantern; no sanctuary rule is added here.

## Skills and execution protocol

At entry read applicable `AGENTS.md`/`CLAUDE.md`, [ck-methodology](C:/Users/Adam/.codex/skills/ck-methodology/SKILL.md), [ck-change-control](C:/Users/Adam/.codex/skills/ck-change-control/SKILL.md) and PROGRESS. Before source changes read [ck-game-angelscript-gameplay](C:/Users/Adam/.codex/skills/ck-game-angelscript-gameplay/SKILL.md), its prerequisites, `Plugins/CkFoundation/Script/AGENTS.md` / `ARCHITECTURE.md`, and [ck-tests-authoring-and-running](C:/Users/Adam/.codex/skills/ck-tests-authoring-and-running/SKILL.md); Phase 4B also needs [ck-game-feature-recipe](C:/Users/Adam/.codex/skills/ck-game-feature-recipe/SKILL.md). Use the actual [canonical Toolbox skill](../../../CkAuto/.claude/skills/build-test/SKILL.md); the old `.Codex` path is absent.

This planning work is documentation-only. Geometry/art execution needs static checks and real editor/player-camera observations. Any AngelScript/C++ change needs **both build and scoped automation through Toolbox**, even where a skill otherwise allows an AS-only test shortcut. Do not run a broad suite after relevant checks pass. No external publishing or commit/push is included.

**Glossary:** K = hearth/kitchen; H1/H2/H3 = Court/Pit/Chime quarry sites; S1–S5 = selected entrance candidates; R1–R7 = seeded route sockets; P1–P5/PK = fixed puzzles; SC2 = closet return door; C1/C3 = approved Bellkeeper clue/commit and reward-attrition design, not crawl IDs (its input amended to the dial lock on 2026-10-20); loaded = actual worn pack/cargo, not a capsule surrogate; staging = reachable floor/bench where cargo can be put down and retrieved; design walkthrough = labelled proxy evidence, distinct from two-human gameplay.
