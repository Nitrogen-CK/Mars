# Phase 3b brief - three targeted fidelity fixes before animation (wrap cloak, membrane palette, ears)

Phase 3 is accepted for topology, rig, LODs, skinning and round trip (read `PROGRESS.md` Phase 3, keep every number
there green). Three visible gaps against the sheets remain; fix exactly these, one per round, with a concept crop
beside each lit render (`review/phase3b/`), and rerun build -> export -> round trip at the end. Look at
`docs/art/flying-units-r01/03-wing-rig-and-expressions-v2.png` (WRAPPED, HANG - FOOT CONTACT, and the big face) and
`02-model-turnaround-v2.png` (FRONT) with the Read tool before starting.

1. **Wrap must cloak the torso** (`review/phase3/wrap_sheet.png`, `hang_sheet.png` show the problem: forearms crossed
   on the chest, fans hanging as side curtains, shingles visible between the arms; in the hang the back is bare and the
   fan tips point toward the feet). Target, from the WRAPPED panel: the elbows tuck at the flanks, the forearms run up
   the sides of the chest with the wrists near the shoulders/chin, the closed finger fans lie FLAT against the body
   following its curvature (front and sides), left over right at the front with 1-2 cm of layering, membranes covering
   the chest and belly so only the head, feet and a sliver of lower belly show; the ribs read as diagonals across the
   front. From the HANG panel: the same wrap inverted, membrane hem near the head, feet clamped on the bar. Achieve it
   with the fold control's solved targets (re-solve; the finger bones may need per-finger curl so the fan hugs the
   torso cylinder) - no scaling, no hiding, no detaching, zero body/left-right intersection at every LOD, pleat
   contacts reported. If the fan cannot hug the torso with the current finger lengths, the smallest justified change
   is allowed (record it as a deviation; the span stays 75 cm).
2. **Membrane and rib palette** (`review/phase3/ref_eevee_sheet.png` reads bright pink-magenta; the sheets are a deep
   muted oxblood #713B46-ish with warm pale-grey ribs #B7A18A). Tune the vertex colours and the EEVEE material
   roughness/spec so the lit front view sits next to the sheet's FRONT without a hue jump; keep the two-sided membrane
   slightly translucent-looking only through colour (no transmission). Also tone the body fur toward #433831 if it
   drifted. Render the palette sheet under the neutral and the amber/teal rigs.
3. **Ears**: broad triangles with a thick brown rim and a cupped, slightly lighter inner face, bases overlapping the
   hood, base-to-tip still 10 cm; they must not read as thin flat fins from the side.

Keep the export contract (42 bones, slot order, recipe) and the control rig unchanged apart from the fold solve.
Update `PROGRESS.md` (Phase 3b section) with the before/after intersection table, the palette values, and the
side-by-side sheets to look at. Scripts/background Blender only; nothing outside this folder; no git state changes.
Report: files, commands, the three items with their evidence, what still differs from the sheets.
