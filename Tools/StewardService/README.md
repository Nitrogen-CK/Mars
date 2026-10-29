# Steward service integration

Revision 3 implements the expanded parchment menu, softer floor drape, menu focus suppression and the original camp arch correction. Runtime input/gate checks and 22 focused tests passed. Continuous route, mission travel and final visual review passed; details are recorded in [PROGRESS.md](PROGRESS.md).

[Current editor demo](Output/Steward_Service_Editor_Demo.mp4) · [Full reading view](Output/Runtime/02_Steward_Reading.png) · [Closed original arch](Output/Runtime/01_Gate_Closed.png) · [Open original arch](Output/Runtime/04_Gate_Open.png) · [Physical passage](Output/Runtime/05_Open_Gate_Passage.png)

The camp-only Steward mesh uses the existing skeleton and a separate six-second/181-frame holding loop. Original mesh/skeleton and source Spire kit assets remain unchanged. The procedural parchment has an 80 x 90 cm flat reading face, a forward drape, floor apron and partly unrolled lower curl. Its 800 x 900 world-space widget remains visible before and after interaction. This is authored static draping; cloth simulation is not enabled.

Existing catalog, controller RPCs and replicated party state own missions. Preview never opens the gate. Confirm commits the dish and opens the single mission gate at the original camp arch, (1220,0,0). Contracts uses CkCamera/CampMenu; prompt, outline and interaction targets clear while reading and return on Back. The taller camera framing includes Confirm and Back.

The original arch had two overlapping closing meshes. Placement removes only their surveyed instances and inserts an owned open frame, preserving stone/threshold collision and shared source assets. The mission gate fits its 240 x 300 cm opening with 12 bars. Camp integration contains 60 owned groups; source Spire assemblies remain instanced.

Review: Play Camp as ListenServer → LMB Steward → select/Back/reopen/confirm → walk through the original arch → descend Spire → Depart at lower post.

Tuners: `Script/Camp/Mars_StewardService_Config.as`; `Tools/StewardService/ui/parchment_specs.py`; `Tools/StewardService/place_camp.py` (world plane and camera); `Tools/StewardService/art/build_service.py` (`DRAPE_*`). Art can rebuild using `--parchment-only`; `import_assets.run(prop_only=True)` preserves the character/animation assets.

All builds/tests use UnrealToolbox. Local logical commits requested; no push. Remote multiplayer, packaged behavior and separate loose-Jolt contact remain unobserved; Gauntlet is blocked by inherited plugin AngelScript boot errors. Injected pointer input is distinct from an OS hardware-mouse test.
