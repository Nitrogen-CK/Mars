// The cellar bat rig: a bat spawned through its real entity script without visuals, hanging under a roost entity 500 uu
// over a runtime static Jolt floor (3000 x 3000 uu, top at _Origin.Z), inside a flight volume over the floor that bakes
// once every static the test placed is in the Jolt world. A hostile target (team One, Health 100, a 70 x 70 x 180 box
// hurtbox, TAG_MarsCombatTarget) can be placed on the floor. Each test sets _Origin to an isolated spot: the Mars autotest
// map has no floor of its own there.
//
// Steps a test gets from Add_WorldSteps: the statics are in -> the bake is requested -> the bake is done -> the bat is
// spawned -> the bat is composed and its roost claim is held.
UCLASS(Abstract)
class UMars_AutoTestRig_Bat : UCk_AutoTest_Base
{
    // A flight or a whole cycle: generous, the bake and the flight take real frames.
    protected const float k_FlightSeconds = 25.0f;

    protected FVector _Origin;
    protected FCk_Handle _Self;
    protected FCk_Handle_Bat _Bat;
    protected FCk_Handle _Roost;
    protected FCk_Handle_VoxelNavVolume _Volume;
    protected TArray<FCk_Handle_JoltBody> _Statics;

    protected FCk_Handle_Transform _TargetRoot;
    protected FCk_Handle_Health _TargetHealth;

    // What the bat and the target reported.
    protected int32 _TargetDamaged = 0;
    protected TArray<EMars_Bat_Phase> _Phases;
    protected TArray<FCk_Handle_HitZone> _Landed;
    protected TArray<EMars_Bat_SwoopCancel> _Cancels;
    protected TArray<EMars_Bat_RouteOutcome> _Outcomes;
    protected int32 _PerchLost = 0;
    protected bool _BuildSucceeded = false;
    protected int32 _BuildCompletions = 0;

    // The bat's spec: tests change it before Add_WorldSteps' spawn step runs.
    protected FMars_Bat_Spec _Spec;

    //----------------------------------------------------------------------------------------------------------------------
    // Geometry
    //----------------------------------------------------------------------------------------------------------------------

    protected FVector Get_RoostAnchor() const
    {
        return _Origin + FVector(0.0, 0.0, 580.0);
    }

    protected FVector Get_HangPoint() const
    {
        return Get_RoostAnchor() + FMars_Bat_Roost().HangOffset;
    }

    protected FVector Get_TargetLocation(FVector InOffset) const
    {
        return _Origin + InOffset + FVector(0.0, 0.0, 90.0);
    }

    // A static Jolt box at InTransform, BlockAll.
    protected FCk_Handle_JoltBody SpawnStaticBox(FCk_Handle InHandle, FTransform InTransform, FVector InHalfExtents)
    {
        auto Box = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(Box, InTransform, ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(InHalfExtents);
        auto BoxSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BoxSpec.Set_ShapeDimensions(Shape);
        BoxSpec.Set_MotionType(ECk_MotionType::Static);
        BoxSpec.Set_CollisionProfileName(n"BlockAll");
        auto Body = utils_jolt_body::Add(Box, BoxSpec);
        _Statics.Add(Body);
        return Body;
    }

    // The floor, the roost and the volume (which waits for Step_RequestBuild). Call SpawnStaticBox for any extra geometry
    // before Add_WorldSteps.
    protected void Build_World(FCk_Handle InHandle)
    {
        _Self = InHandle;
        _Spec = FMars_Bat_Spec();
        SpawnStaticBox(InHandle, FTransform(FRotator::ZeroRotator, _Origin - FVector(0.0, 0.0, 10.0)), FVector(1500.0, 1500.0, 10.0));

        _Roost = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(_Roost, FTransform(FRotator::ZeroRotator, Get_RoostAnchor()), ECk_Replication::DoesNotReplicate);
        utils_bat::Add_Roost(_Roost);

        auto VolumeOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(VolumeOwner, FTransform(FRotator::ZeroRotator, _Origin), ECk_Replication::DoesNotReplicate);
        const auto Bounds = FBox(_Origin + FVector(-1200.0, -1200.0, -40.0), _Origin + FVector(1200.0, 1200.0, 760.0));
        _Volume = utils_bat::Add_FlightVolume(VolumeOwner, FMars_Bat_FlightVolume_Spec(Bounds, 40.0f, _Spec.Flight.AgentRadius, ECk_EnableDisable::Disable));
    }

    protected void Add_WorldSteps()
    {
        Add_Step_WaitUntil("every static is in the Jolt world", n"Check_StaticsAdded");
        Add_Step("the flight volume bakes", n"Step_RequestBuild");
        Add_Step_WaitUntil("the bake is done", n"Check_Built", 0, 20.0f);
        Add_Step("the bat is spawned under its roost", n"Step_SpawnBat");
        Add_Step_WaitUntil("the bat is composed and holds its roost", n"Check_BatReady", 0, 5.0f);
    }

    // A target InOffset from the origin (its root 90 up) on team One (Hostile to the bat on Two).
    protected FCk_Handle_Health SpawnTarget(FCk_Handle InHandle, FVector InOffset)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _TargetRoot = utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, Get_TargetLocation(InOffset)), ECk_Replication::DoesNotReplicate);
        utils_team::Add(Entity, ECk_Team_ID::One, ECk_Replication::DoesNotReplicate);
        _TargetHealth = utils_health::Add(Entity, FMars_Health_Spec(100.0f));
        auto Zone = utils_hit_zone::Add(Entity, utils_hit_zone::Make_FleshZoneSpec(GameplayTags::HitZone_Mars_Body, 1.0f));
        utils_hit_zone::AddHurtbox_Box(Zone, _TargetRoot, FMars_HitZone_Hurtbox(FVector(35.0, 35.0, 90.0), FTransform::Identity));
        utils_entity_tag::Add(Entity, n"TAG_MarsCombatTarget");
        _TargetHealth.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnTargetDamaged"));
        return _TargetHealth;
    }

    protected void MoveTarget(FVector InOffset)
    {
        utils_transform::Request_SetLocation(_TargetRoot, FCk_Request_Transform_SetLocation(Get_TargetLocation(InOffset)));
    }

    protected void DestroyTarget()
    {
        FCk_Handle Entity = _TargetRoot;
        utils_entity_lifetime::Request_DestroyEntity(Entity);
    }

    protected bool Get_SawPhase(EMars_Bat_Phase InPhase) const
    {
        return _Phases.Contains(InPhase);
    }

    // InExpected appears in _Phases in this order (other phases may come between).
    protected bool Get_SawInOrder(const TArray<EMars_Bat_Phase>& InExpected) const
    {
        auto Next = 0;
        for (auto Phase : _Phases)
        {
            if (Next < InExpected.Num() && Phase == InExpected[Next])
            { ++Next; }
        }

        return Next == InExpected.Num();
    }

    protected FString Get_PhaseTrail() const
    {
        FString Trail;
        for (auto Phase : _Phases)
        { Trail += f"{Phase} "; }

        return Trail;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Check_StaticsAdded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        auto AllIn = true;
        for (auto Body : _Statics)
        {
            if (ck::Is_NOT_Valid(Body) || utils_jolt_body::Get_IsBodyAdded(Body) == false)
            { AllIn = false; }
        }

        Res.Set(AllIn);
    }

    UFUNCTION()
    protected void Step_RequestBuild(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_voxel_nav_volume::Request_Build(_Volume, FCk_Request_VoxelNavVolume_Build(),
            FCk_Delegate_Request_OnCompleted(this, n"OnBuildCompleted"));
    }

    UFUNCTION()
    protected void Check_Built(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_BuildCompletions > 0 && _BuildSucceeded == false)
        {
            FinishFailure("the flight volume's bake failed");
            Res.Set(false);
            return;
        }

        Res.Set(_BuildSucceeded && utils_voxel_nav_volume::Get_IsBuilt(_Volume));
    }

    UFUNCTION()
    protected void Step_SpawnBat(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Spec = _Spec;
        Spec.Volume = _Volume;
        Spec.Roost.PerchOwner = _Roost;

        auto SpawnParams = UMars_CellarBat_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, Get_HangPoint());
        SpawnParams.Spec = Spec;
        SpawnParams.WithVisuals = false;
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_CellarBat_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnBatConstructed"));
    }

    UFUNCTION()
    protected void Check_BatReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Bat) && _Bat.Get_RoostClaim() == EMars_Bat_RoostClaim::Held);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Signals
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void OnBuildCompleted(FCk_Handle InRequestOwner, ECk_Request_OperationResult InResult)
    {
        _BuildCompletions += 1;
        _BuildSucceeded = InResult == ECk_Request_OperationResult::Succeeded;
    }

    UFUNCTION()
    protected void OnBatConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _Bat = InEntityScriptHandle.As_Bat();
        _Phases.Add(_Bat.Get_Phase());
        _Bat.BindTo_OnPhaseChanged(FMars_Delegate_Bat_OnPhaseChanged(this, n"OnPhaseChanged"));
        _Bat.BindTo_OnSwoopLanded(FMars_Delegate_Bat_OnSwoopLanded(this, n"OnSwoopLanded"));
        _Bat.BindTo_OnSwoopCancelled(FMars_Delegate_Bat_OnSwoopCancelled(this, n"OnSwoopCancelled"));
        _Bat.BindTo_OnRouteOutcome(FMars_Delegate_Bat_OnRouteOutcome(this, n"OnRouteOutcome"));
        _Bat.BindTo_OnPerchLost(FMars_Delegate_Bat_OnPerchLost(this, n"OnPerchLost"));
    }

    UFUNCTION()
    protected void OnPhaseChanged(FCk_Handle_Bat InBat, EMars_Bat_Phase InFrom, EMars_Bat_Phase InTo)
    {
        _Phases.Add(InTo);
    }

    UFUNCTION()
    protected void OnSwoopLanded(FCk_Handle_Bat InBat, int32 InGeneration, FCk_Handle_HitZone InZone)
    {
        _Landed.Add(InZone);
    }

    UFUNCTION()
    protected void OnSwoopCancelled(FCk_Handle_Bat InBat, int32 InGeneration, EMars_Bat_SwoopCancel InReason)
    {
        _Cancels.Add(InReason);
    }

    UFUNCTION()
    protected void OnRouteOutcome(FCk_Handle_Bat InBat, int32 InGeneration, EMars_Bat_RouteOutcome InOutcome)
    {
        _Outcomes.Add(InOutcome);
    }

    UFUNCTION()
    protected void OnPerchLost(FCk_Handle_Bat InBat, FCk_Handle InOwner)
    {
        _PerchLost += 1;
    }

    UFUNCTION()
    protected void OnTargetDamaged(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InRemaining)
    {
        _TargetDamaged += 1;
    }
}
