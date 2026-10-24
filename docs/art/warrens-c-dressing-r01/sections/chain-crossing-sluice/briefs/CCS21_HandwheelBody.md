# CCS21 / HandwheelBody

Generate CCS21 HandwheelBody for the Chain Crossing / Sluice in Mise en Monstre. Ultra-low-poly, chunky flat-shaded primitives with at most one broad bevel and quiet matte surfaces. Envelope W/D/H [50.0, 5.0, 50.0]cm; source mesh contract: 50cm diameter and 5cm thickness (Mars_HandWheel_EntityScript.as). Pivot: wheel/drum axle center; source Unreal axis is local +X, mesh adapter must preserve it. Materials TX09. 50cm diameter, 5cm thick visible rim and broad spokes; source HandWheel mesh contract; rotating part only, preserve Grip_L and Grip_R. Visual skin/carrier defaults NoCollision; retain current greybox and gameplay-actor collision, traces, grip frames and movement sweeps. Keep moving and static components separate. UV0 uses the shared palette/trim or tiling scale from materials.json. Apply object scale, name collection CCS21_HandwheelBody, provide front/side/three-quarter views. No collision, lights, gameplay or finished FX system automatically. Reference: art/CS06-r02.png.

[Visual reference](../art/CS06-r02.png)

Shared family: I03. Use shared family as shape/material starting point; section dimensions and source contract win. This is not a request to duplicate an existing mesh.
