# CCS22 / WheelAxleStub

Generate CCS22 WheelAxleStub for the Chain Crossing / Sluice in Mise en Monstre. Ultra-low-poly, chunky flat-shaded primitives with at most one broad bevel and quiet matte surfaces. Envelope W/D/H [12.0, 30.0, 12.0]cm; source actor: 30cm mount-to-wheel distance and 12cm stub section. Pivot: wheel/drum axle center; source Unreal axis is local +X, mesh adapter must preserve it. Materials TX09. 30cm from mounting surface to wheel center in existing actor local +X; one continuous axis, no eccentric wheel. Visual skin/carrier defaults NoCollision; retain current greybox and gameplay-actor collision, traces, grip frames and movement sweeps. Keep moving and static components separate. UV0 uses the shared palette/trim or tiling scale from materials.json. Apply object scale, name collection CCS22_WheelAxleStub, provide front/side/three-quarter views. No collision, lights, gameplay or finished FX system automatically. Reference: art/CS06-r02.png.

[Visual reference](../art/CS06-r02.png)

Shared family: I04. Use shared family as shape/material starting point; section dimensions and source contract win. This is not a request to duplicate an existing mesh.
