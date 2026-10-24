# Opt-in gate material binding

Source implementation complete; compile, serialized-map application, and PIE appearance remain for the main integration thread. No Unreal calls, asset writes, build, or automation run were made by this worker.

## Anchor candidate extension

Main confirmed that the Larder patch belongs to a dynamically resolved anchor candidate, so author the **anchor spawner**, not a direct gate spawner. The opt-in field is `GateMaterialOverride`; it is appended to the base anchor's ExposeOnSpawn properties, defaults null, and is inherited by the existing Warrens Route placeable. No table assets or family defaults change.

Confirmed data path:

1. `Mars_Anchor_Presets.as:176-178,203`: serialized placeable field -> `FMars_Anchor_Spec.GateMaterialOverride`.
2. `Script/ECS/Anchor/Mars_Anchor_Feature.as:196-198,260-261` and `Mars_Anchor_Utils.as:22`: transient raw-interface Spec -> weak Params field. The new getter at `:66-67` follows existing getters.
3. `Script/ECS/AnchorResolver/Mars_AnchorResolver_Processor_Requests.as:79`: the existing context copier reads that getter, alongside the existing span/crawl fields. It changes no row selection, ledger, role, channels, or resolve ordering.
4. `Mars_Anchor_Feature.as:134-136`: Context stores a weak material reference because Context is retained in resolve request fragments. This follows existing weak-object assignment and `.Get()` idioms in `Script/ECS/BodyProbe/Mars_BodyProbe_Feature.as:24-35`. Raw UObject references in fragments are prohibited by the existing schema contract (for example `Script/ECS/WorldItem/Mars_WorldItem_Feature.as:546`). The serialized placeable remains the strong material owner; no global retention is added.
5. `Mars_Anchor_Candidates.as:73,107,205`: each of Rubble, LeverGate, and OneSidedLeverGate copies the Context weak reference to the existing gate `MaterialOverride` spawn field. Gate frame and leaf use the prior null-safe material selection.
6. `Mars_Anchor_Candidates.as:13-24,43-45,69,103,202`: side fillers and the crawl plug receive the same override, with the original ProtoGrid fallback when unset/invalid. The filler helper appends an optional raw-interface argument defaulting null, so the existing three-argument Shortcut caller remains compatible. One-sided candidates still do not create a crawl plug.

All five newly edited source files had no pre-existing diff. No indicator, lever, prompt, tint, geometry, collision, eligibility, control, table, or source/sink behavior is edited. Existing direct-gate `MaterialOverride` remains a separate opt-in; this extension does not modify that source file further.

```python
import unreal

# anchor_spawner is the explicitly resolved, owned Variant C Route anchor.
script = anchor_spawner.get_editor_property('_EntityScript')
assert script
material = unreal.load_asset(
    '/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX01')
assert isinstance(material, unreal.MaterialInterface)
anchor_spawner.modify()
script.modify()
script.set_editor_property('GateMaterialOverride', material)
assert script.get_editor_property('GateMaterialOverride') == material
# Main saves only this anchor's owned Variant C tile, then reconstructs/re-enters PIE.
```

This snippet was not executed. Set only identified Variant C anchor placements; reset that property to `None` and save/reconstruct to restore the old material. Existing levels remain null. Do not set a class default or attempt to persist a spawned candidate's runtime component. A cleared/resolved candidate obtains the material again through the existing resolver Context path; there is no new update mechanism for already-resolved children.

Focused verification for main: Toolbox build plus fresh final AS/codegen and schema logs; Anchor composition/resolution and Gate suites, particularly `Anchor_ComposeAddsTagAndParams`, `AnchorResolver_LateAnchorResolves`, `AnchorResolver_SameSeedSameLedger`, `AnchorCandidate_RubbleStaysClosed`, `AnchorCandidate_LeverGateOpensOnChannel`, `AnchorCandidate_OneSidedLeverGateOpensFromItsSide`, and `AnchorCandidate_WarrensScoutLatchSupportsSequentialAccess`. These existing tests exercise default/control paths, not proof that the new material reaches every component. In PIE, compare null and opt-in anchor placements for all three candidate classes: frame/solid leaf or bars/rails, both fillers, and crawl plug where present must share the requested material; lever indicator/tint feedback must retain its existing material and state. Confirm the one-sided crawl stays open, latching and occupied-threshold behavior remain unchanged, and save/reopen plus a new PIE run retains the authored property. Capture the actual resolved Larder gate afterward.

## Confirmed source contract

- `Script/WorldObjects/Mechanisms/Mars_Gate_EntityScript.as:39-41` appends `UPROPERTY(ExposeOnSpawn) UMaterialInterface MaterialOverride = nullptr` after existing spawn properties. Existing serialized gates default to the old ProtoGrid fallback.
- Only `AddFrame` and `AddLeaf` material locals change (`:87-89`, `:111-113`). A valid override feeds all three static frame pieces and the solid leaf or all bars/rails. Invalid/unset uses `assets::load::ProtoGrid_Wall_Mars_MI()` exactly as before.
- Gate spec, transforms, source/sink, threshold, moving node, geometry, collision profiles and construction order are unchanged in the diff. This is source evidence, not runtime regression proof.
- `Script/WorldObjects/Mars_MeshPart.as:68-74` creates a component archetype and sets slot 0 from the supplied material before instancing. Its tint/paint helpers at `:80-91`, `:101-123` are unchanged. This gate supplies no `PrimaryColor` and calls no paint helper. Material parameters on other mechanisms remain untouched.
- Existing nullable-material idiom: `Script/WorldObjects/Forage/Mars_ForageDebris_EntityScript.as:33-35`; `UMaterialInterface` mesh-part property: `Script/WorldObjects/Mars_MeshPart.as:23-24`. Explicit interface-typed local inference plus ordinary assignment avoids requiring ternary common-base resolution with the fallback's `UMaterialInstanceConstant` return type (`Script/Generated/MarsAssets.as:5515`).
- The generated gate spawn struct now contains `MaterialOverride` (`Script/Generated/Mars_EntitySpawnParams.as:12282-12293`), observed read-only after the source edit. No generated file was manually edited. Current authored gate callers in `Mars_Anchor_Candidates.as:67,100,197` and `Mars_Shortcut_EntityScript.as:46` use zero-argument `Params()` and leave the override unset. The generated positional overload changes arity; unsearched external callers require review.

## Author a direct gate placement from Python

The spawner owns a serialized instanced `_EntityScript` (`Plugins/CkFoundation/Source/CkEntitySpawner/Public/CkEntitySpawner/CkEntitySpawner_Actor.h:129-132`). The existing map builder edits that object using `get_editor_property('_EntityScript')` and `script.set_editor_property(key, coerced)` (`Tools/LevelDesign/anchor_plans/build_warrens.py:2748-2755`). Apply the same operation to an explicitly selected Variant C **direct gate spawner**, before PIE/construction:

```python
import unreal

# gate_spawner is the already-resolved Variant C UMars_Gate_EntityScript spawner.
script = gate_spawner.get_editor_property('_EntityScript')
assert script
material = unreal.load_asset(
    '/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX01')
assert isinstance(material, unreal.MaterialInterface)
gate_spawner.modify()
script.modify()
script.set_editor_property('MaterialOverride', material)
assert script.get_editor_property('MaterialOverride') == material
# Main integration saves only the explicitly owned Variant C tile package.
```

The asset path follows existing `Tools/WarrensVariantCKit/main_shell.py:40` material loading. `TX01` is an example selection; main owns the final art material choice and must inspect the runtime cube UV result. The code above is a proposed application, not executed proof of the saved round trip. Resolve the existing actor by identity, not nearest location or a global class-wide sweep.

Reset `MaterialOverride` to `None`, mark/save that same owned tile, and reconstruct/re-enter PIE to roll back the opt-in. Editing an already constructed mesh component alone does not establish the persisted spawn contract. `Mars_Shortcut_EntityScript` retains its existing null fallback. Anchor-spawned child gates now receive the separate `GateMaterialOverride` placement property through the extension above.

## Exact AngelScript diff

```diff
diff --git a/Script/WorldObjects/Mechanisms/Mars_Gate_EntityScript.as b/Script/WorldObjects/Mechanisms/Mars_Gate_EntityScript.as
index 9e4e2cb..bf479a2 100644
--- a/Script/WorldObjects/Mechanisms/Mars_Gate_EntityScript.as
+++ b/Script/WorldObjects/Mechanisms/Mars_Gate_EntityScript.as
@@ -36,6 +36,10 @@ class UMars_Gate_EntityScript : UCk_GenericEntityScript_UE
     UPROPERTY(ExposeOnSpawn)
     bool WaitsForClearThreshold = false;
 
+    // Optional presentation override for the frame and leaf; unset keeps the prototype material.
+    UPROPERTY(ExposeOnSpawn)
+    UMaterialInterface MaterialOverride = nullptr;
+
     // Engine cube is 100 uu, pivot at its center. The opening spans local Y (width) and Z (height).
     private const float64 k_OpeningWidth = 200.0;
     private const float64 k_OpeningHeight = 220.0;
@@ -80,7 +84,9 @@ class UMars_Gate_EntityScript : UCk_GenericEntityScript_UE
     private void AddFrame(FCk_Handle_Transform& InRoot)
     {
         auto CubeMesh = engine::load::Cube();
-        auto WallMaterial = assets::load::ProtoGrid_Wall_Mars_MI();
+        auto WallMaterial = MaterialOverride;
+        if (ck::Is_NOT_Valid(WallMaterial))
+        { WallMaterial = assets::load::ProtoGrid_Wall_Mars_MI(); }
 
         const float64 FrameThickness = 20.0;
         const float64 FrameDepth = 40.0;
@@ -102,7 +108,9 @@ class UMars_Gate_EntityScript : UCk_GenericEntityScript_UE
     private void AddLeaf(FCk_Handle_Gate InGate)
     {
         auto CubeMesh = engine::load::Cube();
-        auto WallMaterial = assets::load::ProtoGrid_Wall_Mars_MI();
+        auto WallMaterial = MaterialOverride;
+        if (ck::Is_NOT_Valid(WallMaterial))
+        { WallMaterial = assets::load::ProtoGrid_Wall_Mars_MI(); }
 
         auto MovingTransform = InGate.Get_MovingNode().As_Transform();
         if (Leaf == EMars_Gate_Leaf::Bars)
```

## Verification and remaining gate

Baseline: the owned AngelScript file had no pre-existing diff. Final `git diff --check -- Script/WorldObjects/Mechanisms/Mars_Gate_EntityScript.as` exits 0; diff is 10 additions and 2 removals. An inverse-edit source comparison confirms no other changes to the gate script. Other worktree dirt is left for its owners.

Main must run the required Toolbox build and focused Gate automation, read the fresh final AS/codegen log, then verify both solid and barred leaves in PIE: null retains ProtoGrid; the serialized override reaches frame plus leaf; opening/closing and occupied-threshold behavior still match. Save/reopen the owned tile and re-enter PIE to prove persistence. Capture the actual Larder gate after its override to confirm the blue grid patch is removed. No passing compile, test, save, or runtime claim is made here.

## Exact anchor extension diff

Static checks: diff-check exits 0; inverse-edit comparison against HEAD passes for all five files, confirming only the declared material fields, propagation, getter, and material lookups changed. No compile/runtime check was run.

```diff
diff --git a/Script/ECS/Anchor/Mars_Anchor_Feature.as b/Script/ECS/Anchor/Mars_Anchor_Feature.as
index b393051..740ddd1 100644
--- a/Script/ECS/Anchor/Mars_Anchor_Feature.as
+++ b/Script/ECS/Anchor/Mars_Anchor_Feature.as
@@ -130,6 +130,10 @@ struct FMars_Anchor_Context
 
     UPROPERTY()
     TOptional<FVector2D> CrawlOffsetCm;
+
+    // Weak: the context is retained in resolve request fragments.
+    UPROPERTY()
+    TWeakObjectPtr<UMaterialInterface> GateMaterialOverride;
 }
 
 // Spawn params passed to every candidate. Injection matches by property name; an AngelScript class ignores a field it
@@ -188,6 +192,10 @@ struct FMars_Anchor_Spec
     // Debug: always wins over the resolver's draw; the ledger marks it.
     UPROPERTY()
     TOptional<int32> PinnedRow;
+
+    // Optional presentation only; unset preserves the prototype gate material.
+    UPROPERTY()
+    UMaterialInterface GateMaterialOverride = nullptr;
 }
 
 mixin FMars_Validation Validate(const FMars_Anchor_Spec& Self)
@@ -248,6 +256,9 @@ struct FMars_Fragment_Anchor_Params
 
     UPROPERTY()
     TOptional<int32> PinnedRow;
+
+    UPROPERTY()
+    TWeakObjectPtr<UMaterialInterface> GateMaterialOverride;
 }
 
 //--------------------------------------------------------------------------------------------------------------------------
diff --git a/Script/ECS/Anchor/Mars_Anchor_Utils.as b/Script/ECS/Anchor/Mars_Anchor_Utils.as
index a13d9c5..c8c47d0 100644
--- a/Script/ECS/Anchor/Mars_Anchor_Utils.as
+++ b/Script/ECS/Anchor/Mars_Anchor_Utils.as
@@ -19,6 +19,7 @@ namespace utils_anchor
         Params.LeverSide = InSpec.LeverSide;
         Params.CrawlOffsetCm = InSpec.CrawlOffsetCm;
         Params.PinnedRow = InSpec.PinnedRow;
+        Params.GateMaterialOverride = InSpec.GateMaterialOverride;
 
         InHandle.Add_Fragment(FMars_Feature_Anchor());
         InHandle.Add_Fragment(Params);
@@ -62,6 +63,9 @@ mixin EMars_Anchor_LeverSide Get_LeverSide(const FCk_Handle_Anchor& Self)
 mixin TOptional<FVector2D> Get_CrawlOffsetCm(const FCk_Handle_Anchor& Self)
 { return Self.Get_Fragment(FMars_Fragment_Anchor_Params).CrawlOffsetCm; }
 
+mixin UMaterialInterface Get_GateMaterialOverride(const FCk_Handle_Anchor& Self)
+{ return Self.Get_Fragment(FMars_Fragment_Anchor_Params).GateMaterialOverride.Get(); }
+
 mixin EMars_Anchor_State Get_State(const FCk_Handle_Anchor& Self)
 { return Self.Get_Fragment(FMars_Fragment_Anchor).State; }
 
diff --git a/Script/ECS/AnchorResolver/Mars_AnchorResolver_Processor_Requests.as b/Script/ECS/AnchorResolver/Mars_AnchorResolver_Processor_Requests.as
index 48159f6..858a467 100644
--- a/Script/ECS/AnchorResolver/Mars_AnchorResolver_Processor_Requests.as
+++ b/Script/ECS/AnchorResolver/Mars_AnchorResolver_Processor_Requests.as
@@ -76,6 +76,7 @@ class UMars_Processor_AnchorResolver_HandleRequests : UCk_Processor_Script_Base_
             Context.RunSeed = Result.Seed;
             Context.LeverSide = Anchor.Get_LeverSide();
             Context.CrawlOffsetCm = Anchor.Get_CrawlOffsetCm();
+            Context.GateMaterialOverride = Anchor.Get_GateMaterialOverride();
             Anchor.Request_Resolve(FMars_Request_Anchor_Resolve(RowIndex, Role, Context));
 
             auto Entry = FMars_AnchorLedger_Entry();
diff --git a/Script/WorldObjects/Anchors/Mars_Anchor_Candidates.as b/Script/WorldObjects/Anchors/Mars_Anchor_Candidates.as
index 81e96ae..f42ba73 100644
--- a/Script/WorldObjects/Anchors/Mars_Anchor_Candidates.as
+++ b/Script/WorldObjects/Anchors/Mars_Anchor_Candidates.as
@@ -10,14 +10,16 @@ namespace utils_anchor
     const float64 k_CandidateFillerHeight = 260.0;
 
     // Two blocking walls that close the rest of the street beside a 2 m gate frame.
-    void Add_CandidateSideFillers(UCk_EntityScript_UE InOuter, FCk_Handle_Transform& InRoot, float32 InSpanCm)
+    void Add_CandidateSideFillers(UCk_EntityScript_UE InOuter, FCk_Handle_Transform& InRoot, float32 InSpanCm, UMaterialInterface InMaterialOverride = nullptr)
     {
         const auto FillerWidth = (float64(InSpanCm) - k_CandidateFrameWidth) * 0.5;
         if (FillerWidth <= 0.0)
         { return; }
 
         auto CubeMesh = engine::load::Cube();
-        auto WallMaterial = assets::load::ProtoGrid_Wall_Mars_MI();
+        auto WallMaterial = InMaterialOverride;
+        if (ck::Is_NOT_Valid(WallMaterial))
+        { WallMaterial = assets::load::ProtoGrid_Wall_Mars_MI(); }
         const auto CentreY = k_CandidateFrameWidth * 0.5 + FillerWidth * 0.5;
         const auto Scale = FVector(k_CandidateFillerDepth, FillerWidth, k_CandidateFillerHeight) * 0.01;
         InRoot.Add_MeshPart(InOuter, FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector(0.0, -CentreY, k_CandidateFillerHeight * 0.5), Scale),
@@ -38,10 +40,13 @@ namespace utils_anchor
         { return; }
 
         const auto Offset = InAnchor.CrawlOffsetCm.GetValue();
+        auto WallMaterial = InAnchor.GateMaterialOverride.Get();
+        if (ck::Is_NOT_Valid(WallMaterial))
+        { WallMaterial = assets::load::ProtoGrid_Wall_Mars_MI(); }
         const auto Scale = FVector(k_CrawlPlugSize, k_CrawlPlugSize, k_CrawlPlugHeight) * 0.01;
         InRoot.Add_MeshPart(InOuter, FMars_MeshPart(
             FTransform(FRotator::ZeroRotator, FVector(Offset.X, Offset.Y, k_CrawlPlugHeight * 0.5), Scale),
-            engine::load::Cube(), assets::load::ProtoGrid_Wall_Mars_MI(), collision::profile::BlockAll, n"AnchorCrawlPlug"));
+            engine::load::Cube(), WallMaterial, collision::profile::BlockAll, n"AnchorCrawlPlug"));
     }
 }
 
@@ -61,10 +66,11 @@ class UMars_Anchor_Rubble_EntityScript : UCk_GenericEntityScript_UE
     ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
     {
         auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
-        utils_anchor::Add_CandidateSideFillers(this, Root, Anchor.SpanCm);
+        utils_anchor::Add_CandidateSideFillers(this, Root, Anchor.SpanCm, Anchor.GateMaterialOverride.Get());
         utils_anchor::Add_CandidateCrawlPlug(this, Root, Anchor);
 
         auto GateParams = UMars_Gate_EntityScript::Params();
+        GateParams.MaterialOverride = Anchor.GateMaterialOverride;
         GateParams.SpawnTransform = SpawnTransform;
         GateParams.Leaf = EMars_Gate_Leaf::Solid;
         GateParams.Gate.StartOpen = false;
@@ -94,10 +100,11 @@ class UMars_Anchor_LeverGate_EntityScript : UCk_GenericEntityScript_UE
     ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
     {
         auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
-        utils_anchor::Add_CandidateSideFillers(this, Root, Anchor.SpanCm);
+        utils_anchor::Add_CandidateSideFillers(this, Root, Anchor.SpanCm, Anchor.GateMaterialOverride.Get());
         utils_anchor::Add_CandidateCrawlPlug(this, Root, Anchor);
 
         auto GateParams = UMars_Gate_EntityScript::Params();
+        GateParams.MaterialOverride = Anchor.GateMaterialOverride;
         GateParams.SpawnTransform = SpawnTransform;
         GateParams.Leaf = EMars_Gate_Leaf::Bars;
         GateParams.Sink.InputChannels.Add(Anchor.Channel);
@@ -192,9 +199,10 @@ class UMars_Anchor_OneSidedLeverGate_EntityScript : UCk_GenericEntityScript_UE
         { return ECk_EntityScript_ConstructionFlow::Finished; }
 
         auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
-        utils_anchor::Add_CandidateSideFillers(this, Root, Anchor.SpanCm);
+        utils_anchor::Add_CandidateSideFillers(this, Root, Anchor.SpanCm, Anchor.GateMaterialOverride.Get());
 
         auto GateParams = UMars_Gate_EntityScript::Params();
+        GateParams.MaterialOverride = Anchor.GateMaterialOverride;
         GateParams.SpawnTransform = SpawnTransform;
         GateParams.Leaf = EMars_Gate_Leaf::Bars;
         GateParams.Sink.InputChannels.Add(Anchor.Channel);
diff --git a/Script/WorldObjects/Anchors/Mars_Anchor_Presets.as b/Script/WorldObjects/Anchors/Mars_Anchor_Presets.as
index 900e08b..7d0f6bd 100644
--- a/Script/WorldObjects/Anchors/Mars_Anchor_Presets.as
+++ b/Script/WorldObjects/Anchors/Mars_Anchor_Presets.as
@@ -173,6 +173,10 @@ class UMars_Anchor_EntityScript : UCk_GenericEntityScript_UE
     UPROPERTY(ExposeOnSpawn)
     TOptional<int32> PinnedRow;
 
+    // Optional gate/frame/filler presentation for this placement; unset keeps the prototype material.
+    UPROPERTY(ExposeOnSpawn)
+    UMaterialInterface GateMaterialOverride = nullptr;
+
     protected EMars_Anchor_Family Get_Family() const
     { return EMars_Anchor_Family::Route; }
 
@@ -196,6 +200,7 @@ class UMars_Anchor_EntityScript : UCk_GenericEntityScript_UE
         if (HasCrawl)
         { Spec.CrawlOffsetCm = TOptional<FVector2D>(FVector2D(CrawlAlongCm, CrawlOffsetCm)); }
         Spec.PinnedRow = PinnedRow;
+        Spec.GateMaterialOverride = GateMaterialOverride;
         utils_anchor::Add(InHandle, Spec);
 
         return ECk_EntityScript_ConstructionFlow::Finished;
```
