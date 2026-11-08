# PHASE 5 BRIEF - R02 into the engine: import, asset swap, look fixes, story re-captured on the new rat

Executor brief (Opus). Planner: the Fable session that owns `docs/art/pantry-rat-dens-production-r01/PROGRESS.md`. You own the
Phase 5 section you append to `Tools/Blender/mars_monsters/pantry_rat_r02/PROGRESS.md` (every claim **confirmed** with evidence
named or **inferred**; deviations D5-n) and the files named below. Read first: this brief; `R02_BRIEF.md` and the R02 `PROGRESS.md`
(what was built, the final measured table, the socket offsets in `export/PantryRat_R02_Manifest.json`); the Phase 4 section at the
end of `Tools/Blender/mars_monsters/pantry_rat_r01/PROGRESS.md` (what the rat entity script now does, `Rebuild_Body`, the court
director `Script/WorldObjects/Monsters/Mars_PantryRatReview.as`, the capture script `scripts/pantry_rat_court_ue.py`, findings
F4-1..F4-5, deviations D4-1..D4-9); the Phase 2 import script `pantry_rat_r01/scripts/pantry_rat_import_ue.py` and its R02 copy
`pantry_rat_r02/scripts/pantry_rat_import_ue.py` (prepared, never run); the project `CLAUDE.md`; `CkAuto/.claude/skills/build-test/SKILL.md`.

## Environment and ownership (unchanged from Phases 3/4)
- Branch dev, HEAD 2154da26. No git write commands. The sibling session's dirty files untouched (Crawler, Cookbook, Sandbox map, Jolt
  cells, ScreamingTurnip, PaleCrawler, CellarBat, the three dirty plugin submodules). Nothing under `Plugins/` edited. No production
  map edited. BusterBlock read-only.
- The live MarsEditor is open: never close, restart or Save-All it. Monolith MCP is the only route in (check schemas with
  `monolith_discover` / `describe_query` first). Forbidden: console level loads, deleting / force-deleting / reloading loaded assets,
  raw `add_socket`, `unload_packages`, PIE while minimised, PIE with a dirty broken Blueprint in memory. Check
  `editor_query get_dirty_content_packages` before any PIE and before any save; save only assets you created, by name.
- Toolbox only, through the detached wrapper in `Saved/Logs/PantryRatValidation/` (one run dir per pattern, read `Toolbox.log` +
  `Exit.json`). **Focused patterns only: `PantryRat`, `RatDen`, `PantryRaid`, then `Eyes`, `CargoSlot`, `WorldItem`, `Monster`.
  Do NOT run the full gate** - the tree's full gate is red for reasons outside this campaign (71 new failures proven unrelated to
  the rat lanes, logged in the package PROGRESS); the maintainer owns that baseline.
- Evidence lines: copy every lane-log line you cite into `Saved/Logs/PantryRatValidation/phase5-evidence-lanelines.txt` at once.

## Steps (gated; stop a gate with evidence rather than working around it)
1. **Import R02 to `/Game/ArtCandidates/PantryRat/R02/...`** (same sub-folders and naming as R01 with `R02` in place of `R01`):
   skeletal mesh + skeleton, 34 clips, the three statics, the five slot MIs on the two rat masters (`MarsPantryRatSurface` body
   slots, raw `MarsPantryRatEyePlate` on slot 5). Hard-edge check is a GATE: read back the imported mesh's normals or render a
   close crop under a hard light and confirm faceted shading like the Blender compare renders (the R01 import was faceted; the
   R02 FBX carries face normals, Blender-side proof only). Sockets `Carry_Mouth` / `Carry_Drag` on `jaw` at the manifest's
   offsets, read back to <= 0.1 cm. Eye-plate base colour: set the plate master's base/patch colour parameter to #5A3F4D (the
   Blender preview value) and record what parameter you set and where. Save the new assets by name. Do not touch the R01 assets.
2. **Swap the script references.** `Script/WorldObjects/Monsters/Mars_PantryRat_EntityScript.as` (mesh path line ~57, clip path
   line ~377), `Mars_RatDen_EntityScript.as` (den + eye plate, lines ~28/32), `Script/Items/Mars_Item_PantryIngredients.as` (cheese,
   line ~10), and the two Phase 2 tests `Mars_AutoTest_PantryRat_{LookMastersResolve,CandidateAssetsReload}.as` (root path, the
   manifest they read). Keep the R01 clip table (same names, frame counts and loop flags). Update `utils_pantry_rat::k_MouthRest`
   and `k_DragRest` (`Script/ECS/PantryRat/Mars_PantryRat_Utils.as`) from the R02 manifest's socket rest frames, by the same
   derivation Phase 3 documented (D3-7/D3-8) with the 18 cm clearance; then re-derive any R01-tuned numbers: `k_AgentRadius` 25
   vs the 30.7 cm nose reach (decide: raise to the half-length that keeps the den passable, or keep and document the wall-clip
   risk), the hurtbox extents (R02 body 31 wide, 35 tall), the withers/readback bands in tests, the court markers. Each number
   changed is a line in PROGRESS with the R01 value, the R02 value and why.
3. **Two Phase 4 findings that block a real level, fixed in the kernel/assembly, not worked around in the court:**
   - F4-3: the den shell's BlockAll collision bakes into the ground field and strands the rat at the portal stands ("NoSurface"
     loop). Make the shell's default profile one the ground-nav bake ignores (or mark the shell as a nav-ignored body the way the
     project's other props do; cite the pattern you copy), so a den placed in any level works without the court's NoCollision
     override. Test: a headless RatDen/PantryRaid test that bakes a field with a den present and proves the portal stands are on
     the field.
   - F4-5: the empty-return dither runs 48 cm outside the den mouth; the spec is crouch-in THEN fade inside the mouth. Move the
     crouch/fade start to the den's Entry portal (the rat is inside the arch when FadeAlpha starts dropping). Test: extend
     `EmptyReturnFadesHidesThenEmergesSolid` to assert the rat's location at fade start is within the arch footprint.
   F4-4 (emerge/return churn when the work point is unreachable) is NOT in scope; record it as a follow-up with the log line.
4. **Lanes green on the swapped sources:** `PantryRat` (all 18+), `RatDen`, `PantryRaid`, `Eyes` (the two listed reds stay listed),
   `CargoSlot`, `WorldItem`, `Monster`. Hash the final sources before the last batch and `md5sum -c` after it.
5. **Story re-captured on R02** with the Phase 4 court director and capture script (editor not minimised, dirty packages checked):
   the full court story (story) and the empty return (return) once each, plus the look crops the maintainer rejected on R01:
   a hero three-quarter close-up of the live rat in PIE, a front close-up with the eyes lit, a side close-up of the mouth carry
   with the mushroom, a corpse crop with the X eyes visible (frame the camera so the head is NOT under the chef this time), a
   mid-dither crop at about alpha 0.5 under the same light as the solid frame. Deliver `review/phase5/pie/<run>/frame_*.png`,
   strips, crops, the log excerpt with the phase transitions, and the beat table. Look at every crop you cite and write what you
   see (faceted or smooth, eye colour, patch colour, carry position vs the Blender carry pose) - the planner compares them to the
   sheets.
6. **Reload proof:** `CandidateAssetsReload` on the R02 paths in a fresh headless editor (part of step 4's PantryRat lane).

## Reporting back
Phase 5 section in the R02 `PROGRESS.md`: files changed; every R01->R02 number changed (table); the parameter set for the eye-plate
colour; the hard-edge readback; socket readbacks; F4-3 / F4-5 fixes with their tests; Toolbox run dirs and exits with named results
(known reds by name); the story beat table and crop paths with what you saw; what stays unverified; the one claim you would most
expect to be wrong. Same content in your final message. Nothing committed, nothing pushed, no production map or plugin touched, no
full gate.
