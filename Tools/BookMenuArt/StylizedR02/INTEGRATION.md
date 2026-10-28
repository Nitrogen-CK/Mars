# Unreal cookbook item

Implemented and observed in local gameplay PIE using gpt-6.1-sol / high effort.

## Try it

Open Sandbox and find `Item_Cookbook` at (-450, 0, 50), between the rock and ration. Look at the book and click LMB to pick it up. `Mars_SpawnCookbook` remains an optional debug spawn.

| Input | Action |
|---|---|
| LMB while equipped | Open / close |
| Q while open | Previous spread |
| E while open | Next spread |
| R tap | Drop |
| R hold then release | Throw |

Focused world prompts retain existing LMB priority. Stow, drop, throw or leaving free-roam closes the book. Q consumes paging while the book is open; the emote wheel resumes when closed.

The item definition is `mars_items::Cookbook()` / `Mars_ItemDef_Cookbook`. The physical assembly is `UMars_Cookbook_EntityScript`; use the existing WorldItem spawn/placement path. The Sandbox map contains one persistent cookbook; the map builder also includes it in future rebuilds. The initial loadout is unchanged.

## Main files

- `Script/Items/Mars_Item_Cookbook.as`: item definition, physical proxy, grip, use and throwable traits.
- `Script/WorldObjects/Items/Mars_Cookbook_EntityScript.as`: persistent physical assembly and visual child.
- `Script/Items/Presentation/Mars_CookbookPresentationComponent.as`: skeletal clips, reversible cover state, page widgets/materials and cleanup.
- `Script/PlayerCharacter/HFSM/Mars_PlayerCharacter_Hfsm_Cookbook.as`: scoped Q/E and reading hold; closes/unbinds on lifecycle changes.
- Input actions/profile and `Config/Tags/Mars_CookbookTags.ini`: mappable controls.
- `Script/ECS/FPHands/Mars_FPHands_Feature.as` and requests processor: opt-in geometry override. Ordinary item hold requests retain their prior behavior.
- `Script/Tests/Cookbook/` plus one FPHands contract test: focused input, priority, lifecycle, native reading geometry, animation clock/reversal and page bounds.

## Pages and pose

Assets are under `/Game/Mars/Gameplay/PlayerCookbook/StylizedR02`. The six widget classes form index, sample recipe and notes spreads. Change `LeftPages` / `RightPages` on the presentation component to replace content; the recipe art remains illustrative.

The new 12-bone rig uses its own single-node presentation and six imported clips. The original BookMenu rig/AnimBP is incompatible. All six pages derive from `UCk_UserWidget_UE`. CkWidgets rasterizes them to cached `UTexture2D` pages; no BookMenu runtime calls or live-asset references remain. See `DependencyCleanup/README.md` before removing the project plugin, because older prototype assets still reference it.

`ReadingHandOffset` in `Script/Items/Presentation/Mars_CookbookPresentationComponent.as` is (-25, 0, 18) cm; `ReadingGripBelowCentre` is 16 cm. Those are the reading-position knobs.

## Evidence

Native build exit 0. Cookbook 5/5, Item 60/60 (baseline 59), Player 32/32 (baseline 31), Emote 5/5, FPHands 27/27 (baseline 26). All final processes exit 0 with zero failures/contamination. Test groups overlap; the population increases are expected new tests. Presentation material cleanup has a fresh five-test gate plus rendered release/reopen observation after the shared-system gates.

See `unreal_gameplay_report.json` for log paths, source hashes and actual raw-input PIE captures. `PREVIEW.html` shows the gameplay output alongside the model/rig evidence.

Hardware keyboard/Slate focus, remote multiplayer and packaged runtime are unverified. The changes are uncommitted and unpushed; unrelated work was preserved. Latest PIE is stopped; the Warrens_VariantC map that was open before the final check is restored.

## 20% size and reading-pose revision

`Presentation.Visual.MeshScale` in `Script/Items/Mars_Item_Cookbook.as` is (1.2, 1.2, 1.2). Static proxy, Jolt collision, pickup fit and native skeletal visual share that scale; held pivot compensation and open grips scale with it. The Blender/FBX authoring files retain their original dimensions. The physical runtime page size is now 20.4 x 27.6 cm.

Opening retains the 25cm approach, adds 4cm of lift (18cm total) and moves gloves to 16cm below the book centre. Native same-view captures are in `Resize20/COMPARE.html`; `Resize20/REPORT.json` contains the new focused gate (5/5, exit0), native scale checks and matched camera metadata. The previous shared-system gates above predate this item-specific revision.

## Sandbox, speed and gutter correction

The three deleted-map services were removed from the catalog; CampSession passed4/4. `GlobalAnimRateScale` is1.5 (opening~0.522s, turning~1.189s). Forward/reverse completion retains the actual final pose. The moving leaf now rotates about the spine centre, correcting the1.1424cm runtime gutter error. Four evaluated endpoint alignment checks and12 FBX checks pass; final Cookbook5/5, exit0. See `GutterFix/REPORT.json` and `GutterFix/COMPARE.html`. Native animation assets, both Blender files, FBXs and motion preview are current.

## Ck widgets and dependency cleanup

Latest cookbook gate5/5 with `-DisablePlugins=BookMenu`, exit0 and zero skipped/contaminated. All6 page Blueprints compile under Ck_UserWidget_UE without errors/warnings;50 active assets have no BookMenu references. Actual renderer/GC/release/reopen checks and script guideline review: `DependencyCleanup/REPORT.json`. Nine older prototype assets outside StylizedR02 still reference the plugin; the project plugin entry remains enabled.
