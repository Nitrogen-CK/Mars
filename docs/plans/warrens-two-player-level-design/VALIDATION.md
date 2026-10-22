# Validation and evidence boundaries

All commands below run from `D:/Repositories/CkRepos/Orion` unless stated. Read the current [canonical Toolbox skill](../../../CkAuto/.claude/skills/build-test/SKILL.md) before engine work. No engine command is part of this planning turn.

## Latest CkUSF material amendment - 2026-10-22 UTC

The user-requested map-wide greybox appearance cleanup is separate from finishing BatchB/C presentation. [Amendment and evidence](PHASE_5_CKUSF_MATERIAL_AMENDMENT.md). Existing opaque-lit CkUSF Displace parent, all ten owned MIs' scalar/RGBA/parent save/reload readbacks exact; all three motion parameters0, static solid albedo. Full v6 manifest/summary/3,875 complete assignments exact; all4,149 v7 nonmaterial assignments, entities/labels/lights/dressing exact; current generator matches JSON after tuple/list normalization and fresh AS emission identical. Canonical final process actual exit0,131checks/320graph/5negative rejections completed before apply; [full static artifact](evidence/phase-5/ckusf-20261022/final-static.json), [compact source gate](evidence/phase-5/ckusf-20261022/final-source-gate.json).

Native complete mesh/kind/material/collision/world-transform multiset matches finalmanifest4,149/4,149; ProtoGrid0 on all authored environment and18dressing.14dressing use owned CkUSF,4 keep authored kit textures. Shared runtime grid gameplay props remain; current separate snapshot365components, earlier snapshot372, no population-cause claim.28HISM groups/215actors reflect one material-bucket merge; original instances unchanged. All42lights/exposure,15unowned and18dressing bounds/profiles exact. Native898/0missing,20starts,6crawls,lowTunnelBlocked0,Jolttrue. [Native coverage](evidence/phase-5/ckusf-20261022/native-material-coverage.json), [closing state](evidence/phase-5/ckusf-20261022/closing-editor-state.json).

Sixteen matched actual-player material views, exact angles/FOV90, <1mm eye settling, same lighting/no lantern. Independent scoped pixel review passed retained routes/edges/roof supports/niches and complete P4 phrase/cost. B/C finished darkness/identity remain unaccepted (Pit12 dark); Well02 parapet is limited, use22 framing. No further gameplay or capture campaign. [26-artifact identity](evidence/phase-5/ckusf-20261022/applied-identity.json) follows actual cook05:51:57.664, map `6e5a611f8976f77c4fd3b110cc859b4065ed5381a88a8dd24be5932a10ed3ad2`. No build/automation rerun for Python/assets-only identical AS. Sound/human boundaries below unchanged.

## Earlier Phase5 A axis evidence - 2026-10-22 UTC

The authorized visual axes passed independent local review; BatchA/Phase5 remain incomplete at missing sound content. [Evidence dossier](evidence/phase-5/entry-20261022/PRESENTATION_A.md), [current progress](PROGRESS.md).

- Fresh final static gate: actual exit0,131/131 checks,320 graph cases,5 negative rejections, source hashes/mtime frozen through launch/apply. It completed BEFORE the local-light apply. [Receipt](evidence/phase-5/entry-20261022/light-source-invariance.json). Full frozen-v6 manifest/summary/3,875 effective assignments exact; current4,149 original instances' mesh/collision/transforms exact. EmittedAS remains `5759a5949ce78c5382a60362bb192c8b29b54364f3a9015677af1ac6955f04ac`; no build or automation rerun for Python/assets-only scope.
- Final native:898 support samples/0missing,20starts clear,6crawls,lowTunnelBlocked0,Jolttrue.216actors,42lights,29HISM groups/4,149instances,18NoCollision dressing and exact15unowned. Global ambient/fills/exposure exact; only two original scales and nine added local lights differ. [Final native audit](evidence/phase-5/entry-20261022/closing-native-audit.json), [independent native/light comparison](evidence/phase-5/lead-applied-light-gate.json).
- Four before/after pairs have exact angles/FOV90 and less than0.2mm eye settling. Actual original pixels establish the joined chain, split monument, recessed niches, supported vessels, room profiles and preserved P4 phrase/cost. The old service-rubble detail32 has a low settled eye and is rejected as rim proof; supported mapped-input arrival replaces it. [Pixel review](evidence/phase-5/lead-pixel-A-gate.json).
- Actual mapped-input pass:9shortwalks/22waypoints/291samples,44steps, errornull, empty worn pack retained, health100. Both kitchen mounts enter/exit; crank/Well/Court/Ossuary approaches observed. All setup placements are explicitly separated from movement; no mid-walk transform. [Independent route review](evidence/phase-5/lead-route-A-gate.json). First wrong Q exit stopped at guard; source-confirmed Back=Tab resumed the same mount. This is not filled-cargo, two-human, hardware-feel or multiplayer proof.
- [23-artifact saved identity](evidence/phase-5/entry-20261022/applied-light-identity.json) follows actual async Jolt cook completion04:28:35.063; mapSHA `23b6886dc9de7b65777240bae97304759bc6fd3a1ffbe7294aa44587906a2348`. Final editor Warrens/PIEoff/dirty0. Prior A4 apply sequencing violation is retained; later completed executor+independent static gates verified frozen hashes. Do not relabel that earlier apply as pre-gated.

STOP at four absent approved A sound assets: HearthCooling_Mars_SND, WellDripChain_Mars_SND, CourtLooseStone_Mars_SND, OssuaryDryTick_Mars_SND under `/Game/Mars/Environment/Warrens/Audio/`. No audio emission, generic replacement or quiet relabel. B/C and Phase6 unstarted; Phase4 normal heard audio/human memory/pair evidence remains pending. No commit/push.

## V0 — coherent checkpoint, before mutation

At each phase/batch entry capture HEAD, dirty paths, exact owned-source copies/hash/mtime, live `data/warrens.json`, emitted `Script/ECS/AnchorResolver/Plans/Mars_AnchorPlan_Warrens.as`, relevant config, `Content/Mars/Maps/Warrens_Mars_MAP.umap` and **every file under `Content/CkJoltData/Mars/Maps/Warrens_Mars_MAP/`**. Save a relative-path/hash manifest, including files absent at entry. Keep the phase-entry checkpoint even after creating later pre-apply checkpoints. No actual backup is required merely to author this plan.

Before replacement, establish that the checkpoint captures saved work and no other owner's unsaved actors/source will be discarded. If unclear, STOP that mutation and record it. Rollback restores this coherent set and identifies newly generated cells from the manifest; never mix old map with new collision/AS. Verify absolute targets stay inside the named workspace/owned checkpoint before any recursive move/delete. No blanket git reset/clean/stash, no overwriting unrelated dirt.

## V1 — graph proof, read-only

```powershell
@'
import heapq, itertools, json
from pathlib import Path
d=json.loads(Path('Tools/LevelDesign/anchor_plans/data/warrens.json').read_text(encoding='utf-8'))
assert len(d['groups']) == 1
g=d['groups'][0]; cases=0; failures=[]
for count in range(g['maxClosed']+1):
    for closed in itertools.combinations(g['anchorIds'],count):
        adj={n:[] for n in d['nodes']}
        for e in d['links']:
            if e.get('closedBy') in closed: continue
            adj[e['a']].append((e['b'],e['costCm']))
            adj[e['b']].append((e['a'],e['costCm']))
        for start in d['entrances']:
            dist={start['node']:0}; q=[(0,start['node'])]
            while q:
                cost,node=heapq.heappop(q)
                if cost != dist[node]: continue
                for nxt,w in adj[node]:
                    nc=cost+w
                    if nc < dist.get(nxt,float('inf')):
                        dist[nxt]=nc; heapq.heappush(q,(nc,nxt))
            cases+=1
            missing=sorted(set(adj)-set(dist))
            eligible=any(dist.get(c['node'],-1)>=d['quarryMinWalkCm'] for c in d['courts'])
            if missing or not eligible: failures.append((closed,start['node'],missing,eligible))
print(json.dumps({'nodes':len(d['nodes']),'links':len(d['links']),'cases':cases,'failures':failures}))
assert cases == 320 and not failures
'@ | python -B -
```

Expected current baseline: 51 nodes, 59 links, 320 cases, empty failures, exit 0. This excludes fixed-puzzle state, optional crawls/upper links and physical foyer rubble. It is not a usable-kitchen or packed-player proof. If output differs, STOP with actual output; do not suppress a case.

## V2 — generated geometry, read-only

```powershell
Push-Location 'Tools/LevelDesign/anchor_plans'
python -B -c "import json,build_warrens; m,s=build_warrens.manifest(write=False); print(json.dumps(s)); assert all(not s[k] for k in ['gateLeaks','walkBreaks','ladderErrors','capErrors','connectorErrors'])"
Pop-Location
```

Read the Python exit before any later command obscures it. Baseline summary: 3875 boxes,40 anchors,7 gates,9 mechanisms,25 pockets,6 crawls,31 lights; named errors empty. After edits counts change intentionally; errors and contracts may not. From Phase 2 onward also run the new `validate_warrens_two_player.py`. Pass → continue; any failure → STOP/PROGRESS. Builder `audit()` is a separate editor observation with fresh Jolt/collision evidence.

## V3 — source build and focused automation

Capture the targeted family baseline immediately before editing; historical counts are only discovery expectations. Close this project's editor cleanly before `--build`; do not force an override or kill unsaved work. From repository root, choose the phase's first family:

```powershell
# Phase 2: emitted AS plan changed.
./CkAuto/UnrealToolbox.exe --build --test --no-live --discover-fresh --test-pattern Mars_AutoTest_AnchorResolver_
# Phase 3: source changes plus route candidate behavior.
./CkAuto/UnrealToolbox.exe --build --test --no-live --discover-fresh --test-pattern Mars_AutoTest_AnchorCandidate_
# Phase 4A: the new Dial kernel.
./CkAuto/UnrealToolbox.exe --build --test --no-live --discover-fresh --test-pattern Mars_AutoTest_Dial_
# Phase 4B: final feature and generated plan/config changes.
./CkAuto/UnrealToolbox.exe --build --test --no-live --discover-fresh --test-pattern Mars_AutoTest_Bellkeeper_
```

These are phase alternatives, not four mandatory runs each time. Additional affected families get **separate invocations** after that final build:

```powershell
./CkAuto/UnrealToolbox.exe --test --no-live --discover-fresh --test-pattern Mars_AutoTest_AnchorResolver_
./CkAuto/UnrealToolbox.exe --test --no-live --discover-fresh --test-pattern Mars_AutoTest_Gate_
./CkAuto/UnrealToolbox.exe --test --no-live --discover-fresh --test-pattern Mars_AutoTest_KeyLock_
```

Phase 3 uses those three; Phase 4B uses AnchorResolver and Dial (substitute `Mars_AutoTest_Dial_`); Sequence is untouched since the dial amendment and needs no run. One `--test-pattern` is an AND filter, not regex-OR/comma syntax. Precise stems avoid unrelated NetworkGate/PhaseSequence names. Expected counts: Dial3 (new), Gate2, KeyLock6; discovery wins over historical resolver19. Route tests add2; Bellkeeper adds6. Zero discovery, new failures, stale binaries, unexpected ensures or secondary-process evidence → STOP. Read actual exit/log/per-test verdicts and compare baseline names; no full suite after relevant gates pass.

Regeneration uses `python -B Tools/LevelDesign/anchor_plans/emit_plan.py warrens`. Run it after Phase 4's cache removal as well as Phases 2/3. Restart before strict apply after tag changes. The sole hand-maintained generated registry exceptions are Phase 4's two new typed-handle entries (Dial, Bellkeeper); all AS wrappers/Params remain generated.

## V4 — observable acceptance

Phase4 execution uses the approved [reconciliation](PHASE_4_RECONCILIATION.md): captured unchanged52/52 across Control19/Dial4/Bellkeeper5/Sequence3/AnchorResolver19/Trap2. The final serial focused gate covers those same families plus five new Bellkeeper observations (expected57 total; discovery and actual names govern). Use `--parallel 1 --known-reds off --no-live`; first invocation also builds and discovers fresh. The corrected actual-panel construction/lifetime gate is10/10, Toolbox/engine exits0, skipped0/contaminated0; this does not replace Warrens physical acceptance. Retain original legacy-powered red evidence separately from the dedicated-topology green.

Before any owned actor replacement, resolve new classes, coerce every new Params field/reward soft reference with the installed public API, and read values back without touching the map. Before each apply capture saved map/allJolt/data/source together and exact15 unowned transforms. After tag changes use a fresh editor. Audio proof requires actual listener-output WAV capture/listening, not `SpawnSoundAttached` source presence. Record normal camera and real input boundaries separately from direct requests, stand-ins and static sweeps.

Use Phase 2/3/4/5 observations and Phase 6 scenarios as written. Every receipt names camera/start/seed, final source+map+Jolt hashes, actual loaded item, action, expected/actual result and one mode: **static**, **tabletop with two people**, **alternating local traversal**, **two-person staged observation**, or **simultaneous gameplay**. Never promote between modes.

The original phase surface is AngelScript/local placed content. The user subsequently authorized the local pack-loading mechanism correction: internal CkJolt contact response plus explicit existing platter collision contracts. No new C++/Blueprint extension API was introduced; API-extension tests remain N/A. Focused native/AS behavior regressions, affected-family gates and actual Warrens recovery cover that authorized expansion. “Three environments” is not an invitation to add network phases.

Area coverage: Phase 2 structures all12; Phase 5 presents all12; Phase 3 activates kitchen1, gate/rewards5/8/9/12 and fixed forage11; Phase 4 activates Bellkeeper7 and clue5; Phase 6 observes all groups, including optional galleries6/overlook10. Art-only Court/Well/Ossuary dressing never silently becomes a new gameplay feature.

**Done for this package's implementation scope:** every phase's authored gate passes, all10 rubric rows≥1, hard spatial gates pass, final evidence/limitations published locally, unrelated dirt preserved. Separately report the ≥16/20 human observational target and whether true simultaneous gameplay was demonstrated or remains pending. Missing multiplayer evidence does not authorize repairs or block accepted local authoring. No commit/push/deployment is implied.

## Recorded Phase4 current gate — 2026-10-22 UTC

- [Fresh unchanged baseline](evidence/phase-4/entry-20261022/fresh-focused-baseline.json)52/52 → [final focused](evidence/phase-4/final-focused-20261022/final-focused-results.json)57/57, baseline names retained plus five Bellkeeper tests; every serial Toolbox/engine exit0, skipped0/contaminated0/errors0. Earlier two behavioral reds remain separate evidence. No claim that dedicated wiring repairs the legacy topology.
- [Fresh contrast build/Bellkeeper](evidence/phase-4/contrast-20261022/contrast-source-results.json)10/10 verifies the later clue AS change. Actual execution raw is `Bellkeeper-test-raw-Mars.log` copied from its engine backup; `Bellkeeper-raw-Mars.log` is later renderer discovery with zero execution verdicts. The earlier57 is not relabelled as fresh after this change; its69 untouched frozen files remain byte-identical.
- Final static131/131 and320graph, full frozen-v6 manifest/summary invariant; final post-PIE audit898samples/0missing,20clearstarts,6crawls,lowTunnelBlocked0,Jolttrue. [Closing identity](evidence/phase-4/closing-20261022/final-applied-identity.json) couples map/all10Jolt/data/emittedAS; [cleanup](evidence/phase-4/closing-20261022/cleanup.json) confirms exact15unowned,173actors,PIEoff/dirty0/CVar0. Initial apply hashes preceded queued editor auto-cook; closing hashes supersede their Jolt identities. [Raw cook/stop receipt](evidence/phase-4/closing-20261022/post-input-drain-and-jolt-log-receipt.json). Geometry/transforms/rewards/routes preserve the observed corrected scene; approved cue color/material metadata are the later data deltas.
- [Physical evidence index](evidence/phase-4/physical-20261022/PHYSICAL_ACCEPTANCE.md) distinguishes normal input, camera pixels, native envelope queries and fixture teleports. Final Bridge phrase and complete pre-cost cue PASS two independent original-pixel reviews. P4-only existing UnlitText fixes the observed lit-material washout with current color/lighting/placement held fixed; no AS changed for this final material comparison. Actual wrong3 preserves attempts/stakes2/1/1 with three supported push landings; correct3/2/4 locks/latched gate/pays exactly one physical Ration after three failures, normal pickup succeeds, repeated solve duplicates0. Separate zero-failure solve observes all three actual reward rests.
- [Normal foreground audio audition](evidence/phase-4/physical-20261022/normal-foreground-audition.json):37 public-input steps, actual wrong1 then correct,24.0898gameplay seconds,errornull,CVar0 throughout. [PCM](evidence/phase-4/physical-20261022/normal-foreground-audition-pcm.json) remains zero; diagnostic bypass clips remain diagnostic. The user cannot check now; normal heard loudness remains an acceptance blocker. [Solo normal-input route](evidence/phase-4/physical-20261022/solo-read-return.json) completes14/14waypoints/443samples/24.9844s without mid-route transforms. End callback records nonzero velocity before input drains; a separate later raw observation confirms zero. Reject its raced arrival photo as phrase/read-memory evidence; independent reader-camera phrase PASS and movement PASS remain separate. No human-pair/MP/full-suite/commit/push claim.

## Recorded Phase3 exit — 2026-10-22 UTC

- Fresh serial entry30/30 → final32/32, actual exits0: candidate5, resolver19, gate2, keylock6. [Exact names/verdicts](evidence/phase-3/kitchen-20261021/final-route-gates.json); [independent gate audit](evidence/phase-3/lead-final-route-gate-audit.json).
- Authorized local correction:125 observations /123unique tests; exact baseline123-name set (120existing pass+3new reds) → all123pass. Two filter overlaps are retained explicitly. Additional isolated profile-transition test confirms global Persisted counters0. [Final gate](evidence/phase-3/local-cargo-20261021/final-focused-gates.json); [independent exact-set audit](evidence/phase-3/lead-local-cargo-baseline-set-audit.json).
- Final actual reservation static gate124/124,320graph cases; editor898/0missing,20starts,6crawls,Jolttrue. Searing placement is finalX41.2 after the bounded0.5m correction; reservation metadata follows it. No source bytes changed after the final32gate; no123rerun for map-only changes.
- [Physical acceptance](evidence/phase-3/kitchen-20261021/PHYSICAL_ACCEPTANCE.md) records actual output, solo operations, alternating proxies, reward/recovery receipts and four native portal-envelope queries. No full meal, human-pair, MP, native movement/input-feel or full-suite inference.
- [Final identity](evidence/phase-3/kitchen-20261021/final-applied-identity.json), [coherent copies](evidence/phase-3/kitchen-20261021/final-closing-manifest.json), [independent final audit](evidence/phase-3/lead-final-physical-audit.json). Temporary food removed; saved editor/PIEoff/dirty0;15unowned actors preserved.
