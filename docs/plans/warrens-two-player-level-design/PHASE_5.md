# Phase 5 — distinctive rooms, readable darkness and positional sound

Take V0's complete coherent checkpoint before the first mutation of each district batch, while retaining the phase-entry checkpoint for full rollback.

**Entry:** Phases 2–4's current gates pass; required Phase 1 asset/API receipts for the next district batch are complete. Missing sound/material content blocks only that presentation batch, not earlier local design work. Recheck source/map/collision hashes and static validator. Capture a comparable first-person “before” image per area with camera, exposure and light state recorded.

**Change paths:** v7 geometry/presentation metadata and `build_warrens.py`; generated plan/map/Jolt set; new owned material/audio assets under `Content/Mars/Environment/Warrens/`; Bellkeeper composer only if its already-planned local one-shot audio needs final asset assignment. No station, player, crawler, session or framework behavior changes.

1. Implement the smallest data-driven rendering addition. New v7 presentation metadata names district bounds, material object paths and explicit dressing items. Preserve existing `kind` for geometry interpretation; optional per-box `material` and `collision` fields affect emission only. `apply()` groups instances by `(kind, effective material path, effective collision profile)` rather than kind alone, with old MATERIALS/COLLISION defaults when fields are absent. Existing main geometry keeps its collision. New decorative parts explicitly use NoCollision unless named as support/structural in AREA_SPEC. District overrides use authored nonoverlapping regions and kind allowlists; ambiguous boundary pieces retain neutral material. Do not rewrite rasterization, lighting or collision architecture.

   Native positional sound emitters use the Phase 1 verified editor API and existing `actor()` ownership tags/folders; deleting/rebuilding the owned scene removes them. Emit only actual supplied sounds. Ambient loops attenuate within their area; clues do not rely solely on sound. Bellkeeper's fixed action sounds follow its owned component lifetime. **Gate:** v6 without new metadata emits the same effective material/collision assignments; v7 has no unknown assets or ambiguous regions; repeated apply does not duplicate audio. **Pass → continue; API/content mismatch → STOP the batch and record the missing property/object path.**

2. Work in these bounded checkpoints; finish and record each before starting the next:

   | Batch | Areas and required results |
   |---|---|
   | A — home and revelation | 1 kitchen, 2 Well, 3 Court, 4 Ossuary: soot hood/work pools; empty depth/one great root; three Court profiles; vertical stacks/empty cross-aisle. |
   | B — upper ritual/service | 5 Bridge/Reliquary/Mourner, 6 galleries, 7 Chime/Bellkeeper, 8 waterworks: legible three-glyph view; thin repaired maintenance silhouette; great hanging instrument/dial panel with no answer marks; three distinct industrial room profiles. |
   | C — descent and return | 9 Cistern/Drowned, 10 spiral/overlook, 11 Grotto/recess, 12 Pit/Vault/closet: waterline/dry edge; distinct stair core; asymmetrical crown/two entrances; clear arena/perimeter/closet seam. |

   Per batch change **one axis at a time**: first replace materials/add large dressing; inspect matched views; then tune local light; inspect again; finally place sound and listen at threshold, centre and adjacent room. Keep working outputs/screenshots, not only a mood description. Use actual first-person field of view and darkest intended light state. Every AREA_SPEC row must have its geometry, dressing, light and sound/intentional-quiet check recorded.

   **Expected after each axis:** area's silhouette strengthens; next action/edge/exit remains readable; adjacent room retains a distinct auditory/visual identity. **Pass → next axis/batch; one weak area → change its single failing axis once and reobserve; persistent failure → STOP that batch, record two attempted changes and measured contradiction.** Do not increase global ambient fill to hide a local black navigation problem.

3. After each batch, rerun the static validator and builder editor audit from the coherent map/Jolt checkpoint procedure in Phase 2. Walk all altered cargo routes and control mounts; particle/audio dressing must not mask important cues. Listen with two people speaking normally where possible; record if Bellkeeper feedback or partner speech becomes indistinct. **Expected:** no new collision/route failures; twelve-area gallery eventually complete; no missing textures/sounds; no claimed alarm/drain/sanctuary behavior from decorative cues. **Pass → exit after C; failure → restore the offending batch before diagnosing.**

If only Python/assets changed and emitted AS is identical, no source build is required. If Bellkeeper source/AS plan changes, run V3's build+affected tests on final files before acceptance. No full suite after those pass.

**Exit:** 12/12 area records contain matched view(s), actual material/dressing implementation, local light settings and sound/quiet observations; all structural/local gameplay observations remain valid. Color differences alone do not satisfy identity. Record any human recognition results separately from author judgment.

**Rollback:** restore just the failing district's data/assets and coherent map/Jolt checkpoint. Preserve previous accepted batches; never restore map alone while leaving mismatched collision. Final tunable values live in v7 presentation metadata, not undocumented editor-only overrides.
