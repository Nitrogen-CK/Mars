# Hero render review

Reviewed 2026-10-24 against `model_catalog.json`, `generators/heroes.py`, native MODEL02/03/04/06/11/23/36/37 references and the actual 512px WVC previews. No Blender or Unreal was run for this review. Main thread owns exports, imports and placement.

Contact sheet: [hero_contact_sheet.png](/D:/Repositories/CkRepos/Orion/Tools/WarrensVariantCKit/Output/Reports/hero_contact_sheet.png). All fifteen original previews were also inspected individually. These are neutral isolated model views, not live-level acceptance.

The reviewed export manifest SHA256 was `8209e7dae8ec8566b16b49423e79485409d71678bbc143fb3ff335db86081a19`. The contact sheet reproduces those existing renders. Three approved source corrections below postdate these exports; affected outputs require the main thread's planned rebuild.

## Findings and source fixes

1. **Confirmed contact defect, WVC016 / H04 HoistHook.** The preview shows a fine separation between suspension eye and stem. Source calculation confirms it: eye bottom `0.89*0.8 - 0.19*0.45 = 0.6265m`, old stem top `0.78*0.8 = 0.624m`, leaving 2.5mm raw separation. Approved fix extends the two stem-top vertices to `0.81*h`: 21.5mm overlap with the eye. This stays below the eye's inner opening and preserves the outer asset envelope and suspension-eye socket. **Source fixed; current PNG/FBX still pre-fix.** See [heroes.py:227](/D:/Repositories/CkRepos/Orion/Tools/WarrensVariantCKit/generators/heroes.py:227).
2. **Confirmed stale pivot metadata, WVC021 / H09 BellClapper.** Current catalog production pivot is `center`, and exported `flags.sockets_m.hinge_center.z` is approximately `0.804m`. Legacy scalar metadata said `-1.704m` under a bottom-center assumption. Approved correction removes those scalar fields and changes the contract to align the final transformed hinge socket. **Metadata fixed; export pending.** The required consumer path is `row['flags']['sockets_m']`, not a top-level `row['sockets_m']`. See [heroes.py:301](/D:/Repositories/CkRepos/Orion/Tools/WarrensVariantCKit/generators/heroes.py:301).
3. **Inferred assembly interference corrected before assembly review, WVC020 / H08 BellYoke.** Previous raw `bell_attachment.z=+0.112m` was above the centered axle, whose radius is 0.096m. Direct crown-to-attachment alignment would put the bell's upper dome around that axle. Approved socket change is `-0.112m`, placing the crown attachment 16mm below the axle's lowest surface before any placement offsets. This is a socket-only correction; it does not change isolated model pixels. **Source socket corrected; final assembled clearance still needs verification after export.** See [heroes.py:289](/D:/Repositories/CkRepos/Orion/Tools/WarrensVariantCKit/generators/heroes.py:289).

## Pixel review by asset

| ID / source | Verified from actual pixels | Remaining fit/axis evidence |
|---|---|---|
| WVC013 / H01 | Four slender legs, open central load space, paired upper headers and diagonal knee braces. No baked pulley, drum, cage or rope. Tall narrow silhouette agrees with 1.6x1.6x7.5m source envelope. | Geometry gives only 0.96m clear width/depth between legs; a full-size WVC017 cage does not fit. Use a measured smaller cage instance or omit it. |
| WVC014 / H02 | Low-sided wood/iron sheave, broad six spokes and visible spaces between spokes. | Local Y axle is source/manifest-confirmed, not inferable from this single view. Rope must follow groove tangents in assembly. |
| WVC015 / H03 | Broad drum flanges, separate axle end and readable barrel ridges. | No rope is baked; any rope line must meet a plausible tangent. Cosmetic static part until an existing owner supplies motion. |
| WVC016 / H04 | J-shaped open throat and separate open suspension eye are visible. | The source contact correction above needs a refreshed PNG and FBX. No physics/grip claim. |
| WVC017 / H05 | Empty cage interior, bars, wood floor/rails, upper suspension braces and eye. No solid central wall. | Its 1.4m footprint exceeds the frame's 0.96m load gap. A uniform scale no greater than about 0.685 fits nominal width only; use approximately 0.65 or a measured alternative for margin. This is fit arithmetic, not a collision observation. |
| WVC018 / H06 | Four open arch sides, corner piers and an open center. No whole tower or solid roof/floor cap is baked into the module. | Crown/yoke/bell fit must be checked assembled; this 4m module is not proof of a correct 22m tower placement. |
| WVC019 / H07 | Low-poly flared bell exterior and broad lower lip; no yoke/clapper baked into this asset. | **Underside is not visible in this preview.** Hollow cavity is confirmed by source geometry, but open-mouth pixel acceptance is outstanding. Require underside and assembled clapper views. |
| WVC020 / H08 | Bowed timber yoke, end straps and centered axle detail are visible. | Axle is local Y per source. Use the corrected transformed bell-attachment socket; do not derive the attachment from a bounding-box center. |
| WVC021 / H09 | Separate clapper eye, long shank and faceted striker are visible. | Current output has center production pivot. Align transformed hinge socket, not old bottom-center scalar. Check its striker against inner bell wall/lip in assembly. |
| WVC022 / H10 | Blunt brow, nose wedge, recessed eye areas and broad jaw; no tooth field or glyphs. | Interpretation: very abstract, with harder block separation than MODEL04. This is a visual tuning option, not a confirmed correctness defect; no unsolicited redesign applied. |
| WVC023 / H11 | Horizontal faceted grinding drum with visible axle bore and timber clamps. No chute baked into it. | Follows MODEL06 horizontal form. MODEL37 depicts a vertical alternate; source/catalog footprint and the main assembly must choose orientation consistently. Separate axle is an assembly responsibility. |
| WVC024 / H12 | Open sloping channel, side lips, salt insert and lower support. | Static visual chute; support contact against source station and route clearance need placement review. |
| WVC025 / H14 | Faceless bowed hood, two robe planes with a central split, feet and plinth. Reads as an abstract upright Mourner rather than a single cylinder. | Hood/robe separation is verified in this view; back/side thickness and player-height silhouette need assembled views. |
| WVC026 / H15 | Open tomb cavity, inner wall faces and rim; no lid covering it. | Use `lid_seat` socket for WVC081. The interior bottom is partly occluded by this camera, so a steep top/section view would supplement it. |
| WVC081 / H15_Lid | Separate broad stone slab with raised face; no handle, glyph or body baked into it. | Match underside socket to tomb seat for the closed recipe; Catacomb's open recipe may lean the same separate lid. Preserve source tomb envelope while deciding the closed assembly height. |

The dark neutral setup reduces contrast on iron/wood pieces, especially WVC013–017 and WVC020–021. Silhouettes remain legible in the inspected originals, but these images do not establish dark gameplay-camera readability.

## Recommended checks for the main rebuild

- Render WVC019 from below, looking through the mouth toward its inner crown, plus a near-lip oblique view. Render one assembled H08/H07/H09 view from below and from the side. These are necessary additions because the present camera cannot see the bell cavity.
- In the saved mesh, identify the bell's annular lip faces and require no polygon spanning the mouth interior at lip height. Cast rays from a small grid just below the mouth through its interior: rays near the central opening should reach the upper inner ceiling, not a lip-level disc. Test several radii so a small central hole cannot masquerade as a hollow bell. Supplement with an inner-wall normal/thickness check. Source mesh watertightness alone does not prove an open mouth.
- After affine normalization, require finite `flags.sockets_m` coordinates; align clapper hinge to the bell hinge socket and bell crown to the yoke's corrected attachment. Compare transformed clapper striker bounds/triangles to the bell inner wall and lip. Report actual minimum clearance, not just matching socket positions.
- Recheck WVC016 eye/stem connected contact in a fresh close render and source/bounds query. Meshes may remain separate joined islands; the intended visual overlap must be positive and the suspension eye's inner opening must stay open.
- Assemble the optional cage at the chosen scale and check bars/suspension braces against all four hoist legs and headers. Compare actual placed bounds, not only nominal catalog dimensions.
- Align WVC081 underside to WVC026 lid seat, then render open and closed recipes. Body remains open when the lid is removed. Source contract, not a decorative screenshot, decides whether the lid is closed or leaned.
- Keep the original preview/hash record for this review. After rebuild, verify the corrected exported hook and socket metadata rather than reusing this pre-fix contact sheet as final acceptance.

## Verification scope

Confirmed this turn: all fifteen PNGs inspected, contact sheet inspected, current manifest/catalog fields read, hook gap and new overlap calculated, edited Python source compiles. No Blender rerender, FBX reload/import, runtime attachment, collision, interaction or player-camera test was performed. No other generator, placement, map or importer was edited.
