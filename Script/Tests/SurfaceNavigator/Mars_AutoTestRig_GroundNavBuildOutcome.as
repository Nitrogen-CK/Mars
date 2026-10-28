UCLASS(Abstract)
class UMars_AutoTestRig_GroundNavBuildOutcome : UMars_AutoTestRig_SurfaceNavigator
{
    default _AutoStageOriginField = false;
    default _TimeoutSeconds = 45.0f;

    protected FCk_Handle _Self;
    protected FCk_Handle _VolumeOwner;
    protected FCk_Handle_GroundNavVolume _Volume;
    protected FCk_Handle_JoltBody _Floor;
    protected TArray<FCk_Handle> _Owned;
    protected TArray<FCk_GroundNavVolume_BuildOutcome> _Outcomes;
    protected TArray<ECk_Request_OperationResult> _GenericResults;
    protected TArray<FCk_GroundNav_ProfileVariant> _ProfileVariants;
    protected bool _DestroyOnGeneric = false;

    protected void Arrange(FCk_Handle InHandle, int32 InMaxColumns = 262144)
    {
        _Self = InHandle;
        auto FloorEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Owned.Add(FloorEntity);
        Track_ForCleanup(FloorEntity);
        utils_transform::Add(FloorEntity,
            FTransform(FRotator::ZeroRotator, _Origin - FVector(0.0, 0.0, 10.0)), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(1500.0, 1500.0, 10.0));
        auto FloorSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        FloorSpec.Set_ShapeDimensions(Shape).Set_MotionType(ECk_MotionType::Static);
        _Floor = utils_jolt_body::Add(FloorEntity, FloorSpec);
        ComposeVolume(InHandle, InMaxColumns);
    }

    protected void ComposeVolume(FCk_Handle InHandle, int32 InMaxColumns = 262144)
    {
        _VolumeOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _VolumeOwner.Request_OverrideToSelf();
        _Owned.Add(_VolumeOwner);
        Track_ForCleanup(_VolumeOwner);
        auto Config = FCk_GroundNav_BakeConfig(25.0f, 10.0f);
        Config.Set_TileSizeUu(200.0f).Set_MaxColumnsPerTile(InMaxColumns);
        auto Profile = FCk_GroundNav_AgentProfile(
            utils_shapes::Make_Capsule(FCk_ShapeCapsule_Dimensions(40.0f, 40.0f)));
        Profile.Set_LedgeSensitivity(0.0f);
        auto Spec = FCk_GroundNavVolume_Spec(
            FBox(_Origin - FVector(600.0, 600.0, 50.0), _Origin + FVector(600.0, 600.0, 200.0)), Config, Profile);
        Spec.Set_AutoBuildOnSetup(ECk_EnableDisable::Disable).Set_ProbeBudgetPerTick(1);
        Spec.Set_ProfileVariants(_ProfileVariants);
        _Volume = utils_ground_nav_volume::Add(_VolumeOwner, Spec);
        Assert_Valid(_Volume, "owned volume composed through public Add");
    }

    protected void RequestBuild(int64 InSequence, bool InForce = false)
    {
        auto Request = FCk_Request_GroundNavVolume_Build();
        Request.Set_RequestSequence(InSequence);
        Request.Set_OnBuildResolved(FCk_Delegate_GroundNavVolume_OnBuildResolved(this, n"OnResolved"));
        if (InForce)
        { Request.Set_ForceRestart(ECk_EnableDisable::Enable); }
        utils_ground_nav_volume::Request_Build(_Volume, Request,
            FCk_Delegate_Request_OnCompleted(this, n"OnGeneric"));
    }

    protected int32 CountOutcome(int64 InSequence) const
    {
        int32 Count = 0;
        for (const auto Outcome : _Outcomes)
        { if (Outcome.Get_RequestSequence() == InSequence) { ++Count; } }
        return Count;
    }

    protected FCk_GroundNavVolume_BuildOutcome FindOutcome(int64 InSequence) const
    {
        for (const auto Outcome : _Outcomes)
        { if (Outcome.Get_RequestSequence() == InSequence) { return Outcome; } }
        return FCk_GroundNavVolume_BuildOutcome();
    }

    UFUNCTION()
    protected void OnGeneric(FCk_Handle InOwner, ECk_Request_OperationResult InResult)
    {
        _GenericResults.Add(InResult);
        if (_DestroyOnGeneric && ck::IsValid(InOwner))
        { utils_entity_lifetime::Request_DestroyEntity(InOwner); }
    }

    UFUNCTION()
    protected void OnResolved(FCk_Handle_GroundNavVolume InVolume, const FCk_GroundNavVolume_BuildOutcome&in InOutcome)
    {
        Assert_Equals_Int(_GenericResults.Num(), _Outcomes.Num() + 1, "generic precedes its typed notification");
        Assert_True(_GenericResults.Last() == InOutcome.Get_OperationResult(), "typed and generic result agree");
        _Outcomes.Add(InOutcome);
        HandleOutcome(InVolume, InOutcome);
    }

    protected void HandleOutcome(FCk_Handle_GroundNavVolume InVolume, const FCk_GroundNavVolume_BuildOutcome& InOutcome)
    { }

    UFUNCTION()
    protected void Check_FloorReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    { auto Result = OutResult; Result.Set(ck::IsValid(_Floor) && utils_jolt_body::Get_IsBodyAdded(_Floor)); }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        for (auto Owner : _Owned)
        { if (ck::IsValid(Owner)) { utils_entity_lifetime::Request_DestroyEntity(Owner); } }
    }
}
