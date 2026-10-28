# Resize baseline

Base c665086cb3adf57479ba540e07fbb2a2cdd0bd9e. Prior integration source SHA256 hashes match current files before resize (checked this turn).

Cookbook prior final gate: 5/5, zero fail/skip/contamination, exit 0, Saved/Logs/Cookbook-Final-MaterialCleanup.log (2026-10-23 05:55:53 UTC). No intervening source edits. Shared dirty paths captured in ../resize20-baseline-dirty.txt; none staged or reset.

Actual fresh same-view pre-change capture: 01-before-open-recipe.png/json. Camera position x=-600,y=-225, pitch=-45.5,yaw=0.527247. Camera Z has idle breathing (~0.5 cm); comparison will fix that camera sample for both images if possible.

Change scope: cookbook item definition, visual child scale, reading hold geometry and geometry assertions; reading offset up 4cm and grips lower. Existing world-item MeshScale already controls static proxy, collision shape scale and pickup fit. No native plugin or art-source changes needed.

Gate: fresh focused Cookbook group plus native matched-view and physical pickup/drop/throw checks. Existing unrelated dirty files left for their owning session.
