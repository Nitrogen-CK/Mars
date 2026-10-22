# Phase 1 — baseline and contract freeze

**Entry:** implementation is separately authorized; read PROMPT, AREA_SPEC, VALIDATION and current PROGRESS. No implementation changes precede this gate. This phase records evidence and the concrete fixture/asset decisions; it does not build the level.

**Allowed writes:** this package's `PROGRESS.md` and NEW `evidence/phase-1/` receipts only. No map/source/asset edits. No engine tests are required for this documentation/baseline phase.

1. Capture current HEAD, UTC, owned-file hashes/mtimes and dirty paths. Run from repository root:

   ```powershell
   git rev-parse HEAD
   git status --short --ignore-submodules=all
   $receipt = Get-Content 'docs/reviews/2026-10-20-warrens-two-player/SOURCE_RECEIPT.json' -Raw | ConvertFrom-Json
   $receipt.files | ForEach-Object { Get-FileHash -LiteralPath $_.path -Algorithm SHA256 }
   ```

   Compare against the dated review receipt, not an old README. `--ignore-submodules=all` does not establish clean submodules; inspect any submodule that would become relevant without changing it. **If source hashes match → continue. If only known unrelated dirt differs → list/preserve it and continue. Any changed relevant contract → STOP and record the changed paths/diff before adopting this plan.** Never stash, reset or overwrite another session's work.

2. Run VALIDATION V1/V2 read-only. Expect **320 cases, zero disconnected cases; manifest 3875/40/7/9/25/6/31 and empty five error arrays** at the unchanged baseline. Capture raw output and exit codes. **If matched → continue. If a count changed with an understood relevant source change → STOP for baseline reconciliation; if an error exists → STOP with exact error.** Do not run the generator just to get a green baseline; it writes live data.

3. Save `evidence/phase-1/contracts.json`: all12 area IDs, graph/footprint, staging/landing rectangles, station operating/camera/dock envelopes and gate/reward table. Inventory manual map actors read-only; measure actual pack/station bounds. **If clearances fit or use AREA_SPEC's bounded station adjustment → continue; otherwise STOP with annotated dimensions.** Do not shrink gameplay collision.

4. Save `evidence/phase-1/assets.json`: actual material/master/mesh/USoundBase paths, uses, loop/one-shot status and license/source for supplied files. Read-only inspect installed Python support for native sound actors, assignment, attenuation and ownership tags; verify material parameters. **Present → continue. Missing content → exact asset brief and blocked Phase 5 batch, without blocking Phases 2–4. Missing API → STOP that presentation decision for a bounded amendment.** This is not an audio-framework task.

5. Lock Pit-return, Grotto and Bellkeeper/gallery scenarios. Record genuine resolved seed, revision, roles/rows, closures and caches using existing facilities. `PinnedRow` normally stays role-compatible; any intentional contradiction is a labelled **diagnostic override**, requires checking the resulting graph, and cannot prove progression. **Compatible seed → lock it; unavailable → tabletop scenario only until existing setup is demonstrated.** No invented solver receipt or new profile system.

**Exit:** baseline receipts saved; graph and generated geometry accounted for; scenario evidence mode explicit; geometry envelopes frozen; Phase 5 content gaps named individually; all unrelated dirty paths recorded. Update PROGRESS with exact observations, accepted contracts and next phase. Record no gameplay pass here.

**Rollback:** remove only new phase-1 receipts if abandoned; preserve original review and all live files. No git operation is needed. A missing presentation asset is not a reason to reopen network work.
