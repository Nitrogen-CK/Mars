#if EDITOR
// Geometry metadata acceptance only: this does not establish rendered appearance or attack feel.
class UMars_TESTONLY_CrawlerSpiderLookProvider : UMars_Sandbox_Crawler6_EntityScript
{
    FMars_Crawler_Look Get_TestLook() const
    { return Get_PresetLook(); }
}

// Use the actual base EntityScript construction without the sandbox's Room 5 spec overrides.
// Both visual and no-visual instances receive the same complete shipped spider look.
class UMars_TESTONLY_CrawlerLoadedLook_EntityScript : UMars_Crawler_EntityScript
{
    UPROPERTY()
    private UMars_TESTONLY_CrawlerSpiderLookProvider _LookProvider;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        _LookProvider = Cast<UMars_TESTONLY_CrawlerSpiderLookProvider>(NewObject(this, UMars_TESTONLY_CrawlerSpiderLookProvider));
        Look = _LookProvider.Get_TestLook();
        return Super::DoConstruct(InHandle);
    }
}

class UMars_AutoTest_AttackCatalog_LoadedLookCreatureDefaults : UMars_AutoTestRig_CrawlerAttackCatalog
{
    default _TimeoutSeconds = 90.0f;
    default _Origin = FVector(-620000.0, -270000.0, 600.0);

    UPROPERTY()
    private UMars_TESTONLY_CrawlerSpiderLookProvider _LookProvider;
    UPROPERTY()
    private UStaticMesh _BodyMesh;
    UPROPERTY()
    private FMars_Crawler_LookMeshes _LoadedLook;

    private FCk_Handle_Crawler _VisualCrawler;
    private FCk_Handle_Crawler _NoLookCrawler;
    private float32 _ExpectedMeshHalfX = 0.0f;
    private FMars_Attack_Definition _JabBefore;
    private FMars_Attack_Definition _PincerBefore;
    private FMars_Attack_ResolvedLoadout _VisualBefore;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("load the actual complete six-leg spider look and create one shared authored graph", n"Step_Source");
        Add_Step("compose a visual spider through the actual crawler EntityScript", n"Step_SpawnVisual");
        Add_Step_WaitUntil("the visual spider exposes its constructed crawler spec", n"Check_VisualConstructed", k_SlowPolls, 0);
        Add_Step("assert mesh-bound creature defaults and preserve the first resolved copy", n"Step_VisualGeometry");
        Add_Step("compose the same graph with visuals disabled", n"Step_SpawnNoLook");
        Add_Step_WaitUntil("the no-look spider exposes its constructed crawler spec", n"Check_NoLookConstructed", k_SlowPolls, 0);
        Add_Step("assert independent 55/125 box defaults, unchanged source and first instance", n"Step_Isolation");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Source(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _LookProvider = Cast<UMars_TESTONLY_CrawlerSpiderLookProvider>(NewObject(this, UMars_TESTONLY_CrawlerSpiderLookProvider));
        const auto Look = _LookProvider.Get_TestLook();
        Assert_Equals_Int(Look.Legs.Num(), 6, "the real sandbox spider look has six leg pairs");
        _BodyMesh = System::LoadAsset_Blocking(Look.Body);
        _LoadedLook.Body = _BodyMesh;
        _LoadedLook.Foot = System::LoadAsset_Blocking(Look.Foot);
        _LoadedLook.Fang = System::LoadAsset_Blocking(Look.Fang);
        for (const auto& Leg : Look.Legs)
        {
            auto Meshes = FMars_Crawler_LegMeshes();
            Meshes.Upper = System::LoadAsset_Blocking(Leg.Upper);
            Meshes.Lower = System::LoadAsset_Blocking(Leg.Lower);
            _LoadedLook.Legs.Add(Meshes);
        }
        if (_LoadedLook.Get_IsComplete() == false || Look.Legs.Num() != 6)
        { FinishFailure("the actual shipped spider look must load completely; box fallback cannot prove this gate"); return; }
        const auto Bounds = _BodyMesh.GetBoundingBox();
        _ExpectedMeshHalfX = float32(Math::Max(Math::Abs(Bounds.Min.X), Math::Abs(Bounds.Max.X)));
        Assert_True(_ExpectedMeshHalfX > 0.0f, "actual body mesh has a positive front extent");
        Assert_True(Math::Abs(_ExpectedMeshHalfX - 55.0f) > 0.001f,
            "the actual mesh differentiates visual construction from the no-look 55 cm fallback");
        _CatalogSpec = Make_CatalogSpec(false);
        Set_CreatureDefaultFlags(_CatalogJab);
        Set_CreatureDefaultFlags(_CatalogPincer);
        _JabBefore = _CatalogJab.Def;
        _PincerBefore = _CatalogPincer.Def;
        Assert_True(_CatalogSpec.Layout == EMars_Crawler_Layout::Spider && _CatalogSpec.LegCount == 6,
            "the submitted creature uses the real six-leg spider rig");
    }

    private void Set_CreatureDefaultFlags(UMars_AttackDefinition_Data InDefinition)
    {
        InDefinition.Def.Prepare.UseCreatureFrontRange = true;
        InDefinition.Def.Prepare.CreatureFrontRangeMargin = 70.0f;
        InDefinition.Def.Prepare.MaxDistance = 80.0f;
        for (auto& Emitter : InDefinition.Def.Hit.Emitters)
        {
            Emitter.UseCreatureFrontCenter = true;
            Emitter.LocalCenter = FVector::ZeroVector;
        }
    }

    private void Spawn_MetadataFloor(FCk_Handle InHandle, FVector InOrigin)
    {
        auto Floor = utils_entity_lifetime::Request_CreateEntity(InHandle);
        Track_ForCleanup(Floor);
        utils_transform::Add(Floor, FTransform(FRotator::ZeroRotator, InOrigin - FVector(0.0, 0.0, 10.0)), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(1500.0, 1500.0, 10.0));
        auto FloorSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        FloorSpec.Set_ShapeDimensions(Shape);
        FloorSpec.Set_MotionType(ECk_MotionType::Static);
        FloorSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Floor, FloorSpec);
    }

    UFUNCTION()
    private void Step_SpawnVisual(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Spawn_MetadataFloor(InHandle, _Origin);
        // This subclass adds no exposed properties; native injection matches inherited properties by name.
        auto Params = UMars_Crawler_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Origin + FVector(0.0, 0.0, 65.0));
        Params.Spec = _CatalogSpec;
        Params.WithVisuals = true;
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_TESTONLY_CrawlerLoadedLook_EntityScript, Params);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnVisualConstructed"));
    }

    UFUNCTION()
    private void Step_SpawnNoLook(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Origin = _Origin + FVector(4000.0, 0.0, 0.0);
        Spawn_MetadataFloor(InHandle, Origin);
        auto Params = UMars_Crawler_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, Origin + FVector(0.0, 0.0, 65.0));
        Params.Spec = _CatalogSpec;
        Params.WithVisuals = false;
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_TESTONLY_CrawlerLoadedLook_EntityScript, Params);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnNoLookConstructed"));
    }

    UFUNCTION()
    private void OnVisualConstructed(FCk_Handle_EntityScript InEntity)
    {
        Track_ForCleanup(InEntity);
        _VisualCrawler = InEntity.As_Crawler();
    }

    UFUNCTION()
    private void OnNoLookConstructed(FCk_Handle_EntityScript InEntity)
    {
        Track_ForCleanup(InEntity);
        _NoLookCrawler = InEntity.As_Crawler();
    }

    UFUNCTION()
    private void Check_VisualConstructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    { auto Result = OutResult; Result.Set(ck::IsValid(_VisualCrawler)); }

    UFUNCTION()
    private void Check_NoLookConstructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    { auto Result = OutResult; Result.Set(ck::IsValid(_NoLookCrawler)); }

    private void Assert_ResolvedGeometry(FCk_Handle_Crawler InCrawler, float32 InExpectedHalfX)
    {
        const auto Spec = InCrawler.Get_Spec();
        Assert_True(InCrawler.Get_IsCombatArmed(), "the real entity construction accepts the shared catalogue graph");
        Assert_Equals_Float(float32(Spec.Rig.BodyHalfExtents.X), InExpectedHalfX, 0.001f, "rig front extent comes from the construction's actual geometry path");
        Assert_Equals_Int(Spec.ResolvedAttacks.Entries.Num(), 2, "both enabled shared definitions resolve");
        for (const auto& Entry : Spec.ResolvedAttacks.Entries)
        {
            Assert_True(Entry.Definition.Prepare.UseCreatureFrontRange == false, "frozen range derivation flag is cleared");
            Assert_Equals_Float(Entry.Definition.Prepare.MaxDistance, InExpectedHalfX + 70.0f, 0.001f, "resolved range uses actual front extent plus authored margin");
            Assert_Equals_Int(Entry.Definition.Hit.Emitters.Num(), 1, "the parity definition retains exactly its Body emitter");
            for (const auto& Emitter : Entry.Definition.Hit.Emitters)
            {
                Assert_True(Emitter.Source == EMars_Attack_EmitterSource::Body && Emitter.UseCreatureFrontCenter == false,
                    "frozen Body emitter derivation flag is cleared");
                Assert_True(Emitter.LocalCenter.Equals(FVector(InExpectedHalfX, 0.0, 0.0), 0.001), "resolved Body centre uses actual creature front geometry");
            }
        }
        Assert_True(utils_attack::Validate_ResolvedLoadout(Spec.ResolvedAttacks).Get_IsValid(), "the final copied numeric graph passes resolved validation");
    }

    private void Assert_SourceUnchanged(UMars_AttackDefinition_Data InAsset, const FMars_Attack_Definition& InBefore)
    {
        const auto Now = InAsset.Def;
        Assert_True(Now.Prepare.UseCreatureFrontRange && Now.Prepare.UseCreatureFrontRange == InBefore.Prepare.UseCreatureFrontRange &&
            Now.Prepare.MaxDistance == InBefore.Prepare.MaxDistance && Now.Prepare.CreatureFrontRangeMargin == InBefore.Prepare.CreatureFrontRangeMargin,
            "shared source range flags and numbers remain authored after real entity construction");
        Assert_Equals_Int(Now.Hit.Emitters.Num(), InBefore.Hit.Emitters.Num(), "source emitter count remains unchanged");
        if (Now.Hit.Emitters.Num() != InBefore.Hit.Emitters.Num()) { return; }
        for (int32 Index = 0; Index < Now.Hit.Emitters.Num(); ++Index)
        {
            Assert_True(Now.Hit.Emitters[Index].UseCreatureFrontCenter &&
                Now.Hit.Emitters[Index].UseCreatureFrontCenter == InBefore.Hit.Emitters[Index].UseCreatureFrontCenter &&
                Now.Hit.Emitters[Index].LocalCenter == InBefore.Hit.Emitters[Index].LocalCenter,
                "shared source Body centre flags and numbers remain authored after real entity construction");
        }
    }

    UFUNCTION()
    private void Step_VisualGeometry(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_ResolvedGeometry(_VisualCrawler, _ExpectedMeshHalfX);
        _VisualBefore = _VisualCrawler.Get_Spec().ResolvedAttacks;
        Assert_SourceUnchanged(_CatalogJab, _JabBefore);
        Assert_SourceUnchanged(_CatalogPincer, _PincerBefore);
    }

    UFUNCTION()
    private void Step_Isolation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_ResolvedGeometry(_NoLookCrawler, 55.0f);
        Assert_ResolvedGeometry(_VisualCrawler, _ExpectedMeshHalfX);
        const auto VisualNow = _VisualCrawler.Get_Spec().ResolvedAttacks;
        Assert_Equals_Int(VisualNow.Entries.Num(), _VisualBefore.Entries.Num(), "second construction preserves first resolved graph shape");
        if (VisualNow.Entries.Num() != _VisualBefore.Entries.Num()) { return; }
        for (int32 Index = 0; Index < VisualNow.Entries.Num(); ++Index)
        {
            Assert_True(VisualNow.Entries[Index].Identity.Id == _VisualBefore.Entries[Index].Identity.Id &&
                VisualNow.Entries[Index].Definition.Clip.Get() == _VisualBefore.Entries[Index].Definition.Clip.Get(),
                "second creature does not replace the first creature's identity or pinned frozen clip");
        }
        Assert_SourceUnchanged(_CatalogJab, _JabBefore);
        Assert_SourceUnchanged(_CatalogPincer, _PincerBefore);
        Print(f"[AttackCatalog.LoadedLookCreatureDefaults] shipped body mesh front {_ExpectedMeshHalfX}, visual range {_ExpectedMeshHalfX + 70.0f}, no-look half/range 55/125; geometry metadata only");
    }
}
#endif
