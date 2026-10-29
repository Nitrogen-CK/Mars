# Steward service art

Run `./Tools/StewardService/art/Build.ps1`. Requires Blender 5.2 and the existing
`Output/Art/Steward_Source.fbx` exported from the current Unreal mesh.
Optional `Steward_BaseColor.tga` supplies its review body texture. Input files are
read only. `-ValidateOnly` independently reimports the existing output FBXs.

Products are `Steward_Present_Mars_AS.fbx`, `ServiceParchment_Mars_SM.fbx`,
`art_manifest.json`, `export_validation.json`, the editable review `.blend`, and
front/three-quarter PNGs. The animation is a six-second planted holding loop,
not a raise/lower transition. Import it **as animation on the existing skeleton**;
do not replace its skeleton or reference pose. Animation-only FBX default node
transforms describe the holding pose. Actual source rest matrices are preserved
inside the Blender build, and exported hierarchy/limb lengths are verified.

Static mesh identity import scale is 1. Local +X is the paper reading normal;
the flat reading area is 80 x 90 cm, local Z -65 to +25 cm. For the existing body mesh's yaw -90
offset, parchment root-relative location is `(55,0,175)` cm with identity rotation.
The manifest also gives body-mesh-component-relative placement. Extended paper
ends in its lower curl, without a roll crossing the middle of a continuing sheet.

The widget uses the flat centre only: local location `(0.25,0,0)` cm, draw size
760 x 475, component scale 0.1. The curls/tail carry no interactive widget pixels.
Generated material slots are `ServiceParchment_Mars_M` and `ServiceSeal_Mars_M`.
Use opaque cream parchment and muted red wax materials when importing. The mesh
needs no collision; the interaction owner should provide the intended hit shape.

Validation checks immutable input hash, unchanged source skeleton rest matrices,
closed solid mesh islands, exported hierarchy/arm lengths, identity prop size,
181 exported animation frames, stationary wrist targets, and loop closure.
Blender previews do not establish Unreal skeleton import, game lighting, world
widget readability, actual interaction, multiplayer, or runtime hand contact.

Dimensions live together at the top of `build_service.py`. The manifest and fresh
FBX validator derive from these constants: 84 cm outer roll width, 80 x 50 cm flat
reading centre, 76 x 47.5 cm safe widget, root wrists `(55,+/-50,196)` cm, and
a forward bow, floor apron and lower curl within 1.003 cm of the ground. No rig rest bones are moved.
The top roll's centre is one radius above the reading top; its connecting sheet
and complete return arc remain at or above that boundary. `TopCurl` tags this
geometry in the editable blend so the saved-source audit checks every vertex.

The grip revision exports an optional NEW `Steward_Service_Mars_SK.fbx` variant,
for camp use on the existing skeleton. Source auto-rig hand/finger weights leaked
onto seven isolated skirt/apron panels, pulling them through the paper when the
fingers closed. Only those proven garment surfaces are corrected: 363 vertices
lose inappropriate hand/finger weights and retain normalized leg/pelvis weights.
All other vertex weights, including hands, stay unchanged. Full per-vertex before,
removed, and after weights are in `garment_weight_correction.json`. Original input
FBX remains read-only. The new variant exports canonical M_Steward/M_EyePlate slots.

The previous wrist aim bent both wrists over 106 degrees and pointed the fingers
down. The new pose uses two landmark axes to control palm orientation and roll,
flexes all three finger joints around the upper roll, and opposes the thumb.
Front, true side, three-quarter and grip detail renders show the result. The
181-frame audit rejects downward palms and wrist bend over 65 degrees.

The lower profile is a smooth Bezier drape into a floor apron and partly unrolled curl. This is static authored geometry, not runtime cloth. Tune DRAPE_CONTROL_1/2, DRAPE_FLOOR_START, DRAPE_APRON_END, DRAPE_CURL_RADIUS and DRAPE_EDGE_WAVE at the top of build_service.py. Use --parchment-only to avoid reauthoring the character or animation, then import_assets.run(prop_only=True).
