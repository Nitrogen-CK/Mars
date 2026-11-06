# Phase C2 brief - reimport the B3 mesh, statics and 16 clips; prove morph targets and curves in Unreal

You are the Opus executor for Phase C2. Read first: `PROGRESS.md` (Phase C section: the importer's stages, the
readback table and how it was evidenced; Phase B2b/B3 sections: shape keys `Inhale`/`Scream`, DEV-13, the widened
hull, MouthCue 4.136, the new clip `ROOT_AnticipateTired`; the audits), `PHASE_C_BRIEF.md`, the refreshed manifest
`export/ScreamingTurnip_R01_Manifest.json` (its `phase_c_readback` block is your assertion list), `export/anims/clips.json`,
`expected_anims.json`, and the importer `scripts/screaming_turnip_import_ue.py` (yours to extend).

Route and rules exactly as Phase C: Monolith `editor_query run_python` (mode `execute_file`, unattended), preflight
each stage (project path, PIE off, dirty packages before/after - refuse to save if a foreign package is dirty),
writes only under `/Game/ArtCandidates/ScreamingTurnip/R01/`, `save_loaded_asset` per owned asset, never Save All,
flags restored in a `finally`, no git, no `Script/` edits, no level load through `run_console_command`, never
`unload_packages`, no deleting/reloading loaded Blueprints. The editor is shared: check the `Mars.log` tail for a
pending "Full Reload is required" and that no PIE is running before each stage.

## Deliverables

1. `reimport` of the SK (`replace_existing`, SKEL reused, `import_morph_targets=True`, `FBXNIM_IMPORT_NORMALS`), the
   three statics (the widened hull: collision regenerated, `Grip_L/Grip_R` sockets re-asserted at (0, -/+3.94, 4.0)),
   the 15 existing clips and the NEW `Animation/ScreamingTurnip_R01_ROOT_AnticipateTired_Mars_ANIM`. Bounds extension
   from the new envelope (21.20 x 14.21 x 13.90) + 2 cm. Sockets re-read from the manifest (MouthCue moved to
   (4.136, 0, 6.4) root-relative).
2. `readback` extended with the manifest's `phase_c_readback` assertions: morph target names on the SK ==
   `[Inhale, Scream]`; per clip `get_sequence_info` curve names include `Inhale` and `Scream` with the authored peak
   values at the authored frames (ROOT_Inhale 1.0 at the last frame, ROOT_Scream 1.0 at f3..f18, ROOT_Recover's
   table, 0 everywhere on QuietIdle / SRC_*); tris 3188; 17 tracks; root identity; loop seams; the new cut numbers
   (RecoveryIdle f0 -> AnticipateTired f0 <= 0.1 cm / 1 deg at the bone level) - and record the morph-normal
   situation (does the import log warn about morph normals with IMPORT_NORMALS? read the log lines and quote them).
3. **Single-node playback proof**: in the editor world (no PIE), spawn a transient `SkeletalMeshActor` or use a
   review display actor's component, `PlayAnimation(ROOT_Scream, false)`, `SetPosition(0.4)`, tick/refresh the
   component the way Monolith's capture path does NOT (it stays at bind pose per the bat record), and read the
   morph target weight on the component (`GetMorphTarget("Scream")`) and one lip vertex position / the component's
   bounds at 0.4 s vs 0.0 s. If the component cannot be made to evaluate outside PIE, say so with the evidence; the
   PIE pass in Phase H is the fallback proof.
4. Reimport proof (`reimport` twice -> identical readback, 28 owned assets, no `_1`), `export/unreal_readback_final.json`
   updated (`reimport_b3`, `readback_b3`), `review/phaseC2/` captures: Monolith `capture_scene_preview` of the new
   SK front / mouth close-up / three-quarter (bind pose), and the review room from the PlayerStart.
5. `PROGRESS.md` Phase C2 section: readback table (expected / got / PASS), morph proof, incidents, not verified.

Reporting back: the table, the morph/curve/playback proof with exact numbers and log quotes, captures to look at,
what remains unverified, confirmed vs inferred on every claim.
