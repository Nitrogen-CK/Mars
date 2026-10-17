# Enemy attack authoring

An attack definition describes one clip, exact required anatomy, preparation bounds, sphere emitters, cooldowns and a cue profile. A loadout supplies stable attack tags, priorities, selection policy and common procedural-player support/return/sampling policy. The crawler owns one executor, receipt stream and per-attempt damage ledger.

Game-level identities are gameplay tags registered in `Config/DefaultGameplayTags.ini`: an attack is `Attack.Mars.<Name>`, an anatomy role `AttackRole.Mars.<Name>`, a hit emitter `AttackEmitter.Mars.<Name>` and a cue profile `AttackCue.Mars.<Name>` (`*.Mars.Test.*` tags exist only for the automation). Clip phases, windows, slots and limb ids stay `FName`: they are the procedural action framework's own identifiers. The three reference creatures are `EMars_Crawler_AttackPreset` (`Crawler4`, `Crawler6`, `Spider6`; `Script/WorldObjects/Monsters/Mars_Crawler_AttackPresets.as`), which the console commands parse from text.

## Create or extend an attack

1. Create an owned procedural action clip and edit its solved preview on the intended rig. Use three phases in the configured Windup/Strike/Recover order. Keep the lifecycle Offense window across the entire clip.
2. Create a `UMars_AttackDefinition_Data`. Assign the clip and map every declared slot to an anatomy role tag. Claimed slots imply required parts; add separate prerequisites only for parts the attack needs without controlling them.
3. Configure Body or LimbEndpoint sphere emitters. Body centres are relative to accepted body presentation. Endpoint centres use the exact claimed slot's accepted endpoint and require zero local offset. Emitter tags are unique within a definition and provide deterministic contact tie-breaking (by tag name).
4. Give each emitter a Damage window contained in Strike. An empty emitter ObstructionWindow inherits the definition's full Offense window. Endpoint reference clips use ClawSweep (late Windup through early Recover), excluding grounded lift-off/replanting. Damage must lie inside the emitter's obstruction window. Floors and other obstacles are queried normally.
5. Add the definition to a loadout under a unique attack tag (register a new one in the tags ini first). Larger priorities win; equal priorities prefer the least recently accepted start, then tag name order. A synthetic fourth attack uses the same schema and requires no selector branch.
6. Bind the crawler's anatomy roles to exact rig IDs. Crawler4 uses FrontRight=Leg0/FrontLeft=Leg3; Crawler6 and Spider6 use Leg0/Leg5. Body has no limb ID. Runtime composition derives locomotor classification from the actual crawler rig.
7. Assign the loadout to `Spec.Combat.Loadout`, leaving legacy JabClip/PincerClip unset. Validate and reconstruct the creature to apply authored edits.

UseCreatureFrontRange explicitly derives the start maximum from the creature's body half length plus CreatureFrontRangeMargin (reference default 70 cm). A Body emitter's UseCreatureFrontCenter explicitly derives its centre from that creature's front face. False flags preserve literal authored values, including a zero Body centre. Resolution writes only per-creature copies, clears these flags and validates the resulting numbers. Actual entity construction uses loaded-look geometry; the console validator's anatomy presets use declared 40/55 cm box half lengths and do not prove a custom look's dimensions.

## Selection and lifetime

Unavailable means anatomy/capacity cannot perform the attack. Waiting means the attack is capable but control, stance, range, facing, cooldown or other temporary checks prevent starting. Ready means all admission checks currently pass. Every applicable blocker remains in the report.

PreferAvailable skips another controller, Returning and Unplanted when selecting a preferred attack. Ordinary gait swing remains a stance wait. WaitPreferred holds the preferred capable attack; UseReadyAlternative permits the best ready alternative after a preparation grace period. The 0.25 s reference grace starts with PrepareAttack, not Approach. Target-only StartAttack performs fresh selection; explicit tag/generation starts reject unknown, stale or currently unpermitted choices.

A valid PendingAdmission action has not yet acquired its channels. The first accepted receipt charges entry reuse cooldown and accepted-start history. A rejected acquisition charges neither. The committed plan freezes definition values, exact bindings and a publicly built transient clip copy, held strongly by the EntityScript. Changes to source assets affect newly constructed creatures.

Processed severance, depletion, disabling and wrong ownership cancel an active attack before collision/commit. Own-action Controlled limbs are valid continuation. Cancellation closes damage and returns surviving claims; native terminal failure and subsequent autonomous cleanup remain separate diagnostic outcomes. One attempt emits at most one damage request across all its emitters.

## Reference content and commands

`Mars.Attack.ValidateLoadout <LoadoutObjectPath> <Crawler4|Crawler6|Spider6>` uses the same resolver and structured validation as construction. It prints entry/role/slot bindings and reason code, field, expected and actual. It loads assets and makes transient frozen copies; it does not edit or save asset packages.

`Mars.Attack.SeedReferenceLoadouts` preflights all six reference graphs before creating packages. It creates only missing clips, definitions and loadouts. Existing named loadouts skip their entire graph; existing child assets in a missing graph are loaded and validated, never overwritten or saved. An invalid graph stops creation. If a persistence operation fails, inspect the named created paths; partial NEW assets may exist. This command does not call the older clip seeder's metadata-update branch.

The same operations expose `Get_LoadoutValidation` and a `Seed_ReferenceLoadouts(OutReport)` overload for automation. Validation returns the exact shared resolver report and the construction's strong object pins. The seed report names created/skipped paths, type counts, save-call count and failure stage; the operation returns success only after all persistence stages finish.

Reference loadouts live in `/Game/Mars/Gameplay/Monsters/Crawler/AttackCatalog/`. Each Crawler4/Crawler6/Spider6 preset has a ParityLoadout and an EndpointDemoLoadout. Parity contains Pincer/Jab at priorities 100/0, body spheres and WaitPreferred. Endpoint demos contain Pincer 100, SwipeRight/SwipeLeft 50 and Jab 0, with UseReadyAlternative and 0.25 s grace. Endpoint spheres use radius 12 cm and a 16 cm accepted-travel budget. Their public sampling reference uses maximum advance 1/60 s, one qualified sample and the legacy native joint allowance of 180 degrees; support hold is 6 s and limb return timeout 3 s.

The 180-degree limit governs native chain segment admission. A zero-offset sphere's rotation does not move its centre or change its occupied geometry, so that limit does not relax the game's 16 cm accepted position chord. Endpoint frames still retain full pose provenance and must match actual current presentation. Native solver joint swivels remain a visual acceptance risk. The crawler adapter rejects endpoint-emitter loadouts whose MaxSamples is not exactly one with EndpointPublicationSampling. Native refinement poses are predictions followed by one physical publication; using one sample makes settled-motion validation compare to the previous actual pose. The recorded P3 single-publication diagnostic completed with 81 accepted rows and a maximum physical chord of 15.830606 cm. That focused result does not prove every shipped rig/clip, hitch condition or visual experience.

The original four source clips and their preview assets remain unchanged. Parity references their source paths. New endpoint-pincer and swipe clips have separate names and current-rig preview subjects. Parity preserves the original body hit/preparation/cooldown values, with support hold equal to the longest enabled clip plus the original cancellation duration.

Existing Room 5 crawler classes use the parity loadouts. For the endpoint examples, place `UMars_Demo_EndpointCrawler4_EntityScript`, `UMars_Demo_EndpointCrawler6_EntityScript` or `UMars_Demo_EndpointSpider6_EntityScript` in Room 5, with `UMars_Demo_EndpointAggressionLever_EntityScript`. They use the room's existing aggression channel and bounds, and enable accepted attack drawing. Both front limbs permit Pincer; right-only permits SwipeRight, left-only SwipeLeft, and neither falls back to Jab when body/support readiness permits. The existing Room 5 lever also controls these demos.

New reference clips retain their embedded preview rig/gait through game-owned `UMars_AttackPreviewPins` asset user data attached before their first save. These hard references make the nested objects reachable by serialization; the preview's normal soft references keep their existing API. This metadata lives in the clip's editor-only user-data array and does not alter runtime motion. Seeding continues to skip existing clips and loadouts.

## Debug and verify

Inspect stored candidate evaluations and blockers, Preferred/ReadyChoice/Selected, committed AttackId/plan, accepted admission stamp, reuse clocks, native result, cleanup result and the last 16 chronological history events. Debug drawing must use stored accepted emitter segments and radii rather than requested solver targets. An empty cue profile emits no cue batches; configured profiles follow accepted events and completion/interruption.

Collision sweeps cover chords between settled accepted endpoints. Evaluated refinement poses are not physical contact evidence. Historical receipt pages are processed chronologically; compare current presentation only after HasMore is false and the true latest accepted record is known. Missing source, stale/gapped evidence and oversized travel fail closed. Do not increase travel limits to hide a bad reference or a hitch.

Run the relevant automation through `CkAuto/UnrealToolbox.exe`. Headless tests do not prove solved preview quality, temporal contact alignment, limb fallback readability, authoring usability or real input feel. Complete the recorded editor observation gates on each supported rig and frame/hitch setting before claiming experience acceptance.

Persistence runs outside PIE: `Mars.Attack.SeedReferenceLoadouts` rejects play mode before asset operations. The game-owned `Ck.Mars.AttackCatalog.EditorSeedReferenceGraphs` editor automation invokes that same command, verifies the exact 33 new packages and repeats it while checking file bytes and timestamps. Run it through Unreal Toolbox. The PIE `AttackCatalog.SeedReferenceGraphs` test checks clip-only preview ownership through a later GC step and reads the already-persisted inventory; it never creates or saves packages. `AttackCatalog.ShippedReferenceGraphs` checks six graph constructions and nine preview subjects through GC after a fresh editor boot. AS assertions compare exposed legacy source values; the main verification gate separately compares the original 16 asset/export byte hashes and timestamps with the recorded baseline. Same-process preview ownership alone does not prove saved metadata reload.

## Extension and compatibility

Add attack tags, clips, bindings, required-part ceilings, preparation bounds, priorities, cooldowns, windows and supported sphere emitters through data. Another morphology needs an observation/composition adapter using the same copied evaluation surface. Another geometry source or collision shape needs an explicit adapter and acceptance tests. Multiplayer transport, combos, random selection, root lunges and hot asset replacement are outside this contract.

Legacy JabClip/PincerClip, target-only requests and source-clip getters remain compatibility adapters. Get_AttackId/Get_AttackPlan/Get_AttackFrozenPlayedClip identify actual committed execution; custom tags do not become Jab. Retire compatibility fields only after serialized assets and all source callers migrate in a separately approved cleanup.
