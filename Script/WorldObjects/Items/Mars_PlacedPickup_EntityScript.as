enum EMars_PlacedPickup_State
{
    Waiting,
    Dispatched,
    Failed
}

// Opt-in startup proxy for persistent-level placed supplies. Author the WHOLE initial body clear of its support in the
// placement preflight. This small predicate only waits for five authored floor witnesses; it is not a placement solver.
// The proxy must live in persistent Main for the entire world: its original WorldItem/Backpack child keeps that lifetime
// through pickup, cargo and drop. Never place this owner in an unloadable Level Instance.
class UMars_PlacedPickup_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FName FixtureId;

    UPROPERTY(ExposeOnSpawn)
    TSoftObjectPtr<UCk_InventoryItem_Definition> Definition;

    // Expected world Z = SpawnTransform.location.Z + this offset, irrespective of the spawn rotation.
    UPROPERTY(ExposeOnSpawn)
    float64 SupportHeightOffsetCm = -20.0;

    // World-axis X/Y half extents around SpawnTransform.location.XY: centre plus all four footprint corners.
    // Author per fixture inside its actual support; a large backpack must not inherit a tiny key footprint.
    UPROPERTY(ExposeOnSpawn)
    FVector2D SupportHalfExtentsCm = FVector2D(10.0, 10.0);

    UPROPERTY(ExposeOnSpawn)
    float64 ProbeHalfRangeCm = 5.0;

    UPROPERTY(ExposeOnSpawn)
    float64 SupportToleranceCm = 2.0;

    private FCk_Handle _Owner;
    private FCk_Handle_Timer _Timer;
    private FCk_Handle _SpawnedEntity;
    private UCk_InventoryItem_Definition _ResolvedDefinition;
    private EMars_PlacedPickup_State _State = EMars_PlacedPickup_State::Waiting;
    private FString _Failure;
    private int32 _LastSupportMask = 0;
    private TArray<float64> _LastHitHeights;
    private float64 _DispatchTimeSeconds = -1.0;

    UFUNCTION(BlueprintPure)
    EMars_PlacedPickup_State Get_State() const
    { return _State; }

    UFUNCTION(BlueprintPure)
    FCk_Handle Get_SpawnedEntity() const
    { return _SpawnedEntity; }

    UFUNCTION(BlueprintPure)
    FString Get_Failure() const
    { return _Failure; }

    UFUNCTION(BlueprintPure)
    int32 Get_LastSupportMask() const
    { return _LastSupportMask; }

    // Mask bit i means the hit matches the authored plane; an absent hit has a default zero height entry.
    UFUNCTION(BlueprintPure)
    TArray<float64> Get_LastHitHeights() const
    { return _LastHitHeights; }

    UFUNCTION(BlueprintPure)
    float64 Get_DispatchTimeSeconds() const
    { return _DispatchTimeSeconds; }

    UFUNCTION(BlueprintPure)
    TArray<FVector> Get_ExpectedWitnesses() const
    {
        const auto Origin = SpawnTransform.GetLocation();
        const auto Centre = FVector(Origin.X, Origin.Y, Origin.Z + SupportHeightOffsetCm);
        TArray<FVector> Witnesses;
        Witnesses.Add(Centre);
        Witnesses.Add(Centre + FVector(-SupportHalfExtentsCm.X, -SupportHalfExtentsCm.Y, 0.0));
        Witnesses.Add(Centre + FVector(-SupportHalfExtentsCm.X, SupportHalfExtentsCm.Y, 0.0));
        Witnesses.Add(Centre + FVector(SupportHalfExtentsCm.X, -SupportHalfExtentsCm.Y, 0.0));
        Witnesses.Add(Centre + FVector(SupportHalfExtentsCm.X, SupportHalfExtentsCm.Y, 0.0));
        return Witnesses;
    }

    // A returned pending handle is not completion. This getter observes the actual seeded original WorldItem and body.
    UFUNCTION(BlueprintPure)
    bool Get_IsSpawnedItemReady() const
    {
        if (ck::Is_NOT_Valid(_SpawnedEntity) || _SpawnedEntity.Is_WorldItem() == false)
        { return false; }
        const auto Item = _SpawnedEntity.As_WorldItem();
        const auto Body = Item.Get_Body();
        auto SeededItem = Item.Get_Item();
        if (ck::Is_NOT_Valid(SeededItem))
        { SeededItem = Item.Get_HeldItem(); }
        return ck::IsValid(SeededItem) && ck::IsValid(Body) && Body.Get_IsBodyAdded();
    }

    FMars_Validation Get_Validation() const
    {
        if (FixtureId.IsNone())
        { return FMars_Validation("FixtureId must name the authored fixture"); }
        if (SpawnTransform.ContainsNaN() || SpawnTransform.GetScale3D().Equals(FVector::OneVector, 0.0001) == false)
        { return FMars_Validation("SpawnTransform must be finite and unit scale"); }
        if (Definition.IsNull())
        { return FMars_Validation("Definition must reference the original item definition"); }
        if (Math::IsFinite(SupportHeightOffsetCm) == false
            || Math::IsFinite(SupportHalfExtentsCm.X) == false || Math::IsFinite(SupportHalfExtentsCm.Y) == false
            || SupportHalfExtentsCm.X <= 0.0 || SupportHalfExtentsCm.Y <= 0.0)
        { return FMars_Validation("Support plane and positive footprint half extents must be finite"); }
        if (Math::IsFinite(ProbeHalfRangeCm) == false || ProbeHalfRangeCm <= 0.0 || ProbeHalfRangeCm > 10.0
            || Math::IsFinite(SupportToleranceCm) == false || SupportToleranceCm <= 0.0
            || SupportToleranceCm > 2.0 || SupportToleranceCm > ProbeHalfRangeCm)
        { return FMars_Validation("ProbeHalfRangeCm must be in (0,10]; SupportToleranceCm in (0,min(2,range)]"); }
        for (const auto Witness : Get_ExpectedWitnesses())
        {
            if (Witness.ContainsNaN())
            { return FMars_Validation("Computed support witnesses must be finite"); }
        }
        return FMars_Validation();
    }

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        _Owner = InHandle;
        utils_entity_tag::Add(InHandle, n"TAG_MarsPlacedPickup");
        const auto Validation = Get_Validation();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[PlacedPickup] [{FixtureId.ToString()}] rejected fixture: {Validation.Get_Error()}"))
        { Set_Failed(Validation.Get_Error()); return ECk_EntityScript_ConstructionFlow::Finished; }
        _ResolvedDefinition = Definition.Get();
        if (ck::Is_NOT_Valid(_ResolvedDefinition))
        { _ResolvedDefinition = System::LoadAsset_Blocking(Definition); }
        if (ck::EnsureIfNot(ck::IsValid(_ResolvedDefinition), f"[PlacedPickup] [{FixtureId.ToString()}] Definition does not resolve"))
        { Set_Failed("Definition does not resolve"); return ECk_EntityScript_ConstructionFlow::Finished; }
        utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsPlacedPickupWaiting");
        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (_State != EMars_PlacedPickup_State::Waiting)
        { return; }
        auto Spec = FCk_Timer_Spec(FCk_Time(0.05f));
        Spec.Set_StartingState(ECk_Timer_State::Running).Set_Behavior(ECk_Timer_Behavior::ResetOnDone);
        _Timer = utils_timer::Add(InHandle, Spec);
        if (ck::EnsureIfNot(ck::IsValid(_Timer), f"[PlacedPickup] [{FixtureId.ToString()}] readiness timer was not created"))
        { Set_Failed("Readiness timer was not created"); return; }
        auto TimerEntity = _Timer.H();
        utils_entity_tag::Add(TimerEntity, n"TAG_MarsPlacedPickupTimer");
        _Timer.BindTo_OnDone(FCk_Delegate_Timer(this, n"OnCheckSupport"));
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    { Stop_Timer(); }

    private bool Get_HasSupport()
    {
        _LastSupportMask = 0;
        _LastHitHeights.Empty();
        const auto Witnesses = Get_ExpectedWitnesses();
        for (int32 Index = 0; Index < Witnesses.Num(); ++Index)
        {
            const auto Point = Witnesses[Index];
            const auto Hit = utils_jolt_static_world::Get_RayCastStaticWorld(
                Point + FVector(0.0, 0.0, ProbeHalfRangeCm), Point - FVector(0.0, 0.0, ProbeHalfRangeCm));
            _LastHitHeights.Add(Hit.Get_HasHit() ? Hit.Get_Position().Z : 0.0);
            if (Hit.Get_HasHit() && Math::Abs(Hit.Get_Position().Z - Point.Z) <= SupportToleranceCm)
            { _LastSupportMask |= (1 << Index); }
        }
        return _LastSupportMask == 31;
    }

    UFUNCTION()
    private void OnCheckSupport(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_Owner) || _State != EMars_PlacedPickup_State::Waiting || Get_HasSupport() == false)
        { return; }
        // Claim the one-shot before issuing any spawn request. A later empty/destroyed item never re-arms this proxy.
        _State = EMars_PlacedPickup_State::Dispatched;
        _DispatchTimeSeconds = System::GetGameTimeInSeconds();
        Stop_Timer();
        _SpawnedEntity = utils_world_item::Request_SpawnWorld(_Owner, FMars_WorldItem_WorldSpec(Definition, SpawnTransform));
        if (ck::EnsureIfNot(ck::IsValid(_SpawnedEntity), f"[PlacedPickup] [{FixtureId.ToString()}] original world-item dispatch returned no pending entity"))
        { Set_Failed("Original world-item dispatch returned no pending entity"); return; }
        utils_entity_tag::Request_TryRemove(_Owner, n"TAG_MarsPlacedPickupWaiting");
        utils_entity_tag::Add(_Owner, n"TAG_MarsPlacedPickupDispatched");
        Print(f"[PlacedPickup] fixture={FixtureId.ToString()} state=Dispatched time={_DispatchTimeSeconds} pending={_SpawnedEntity.ToString()} origin={SpawnTransform.GetLocation()} supportMask={_LastSupportMask}", 0.0f);
    }

    private void Set_Failed(const FString& InReason)
    {
        _State = EMars_PlacedPickup_State::Failed;
        _Failure = InReason;
        Stop_Timer();
        if (ck::IsValid(_Owner))
        {
            utils_entity_tag::Request_TryRemove(_Owner, n"TAG_MarsPlacedPickupWaiting");
            utils_entity_tag::Add(_Owner, n"TAG_MarsPlacedPickupFailed");
        }
        Print(f"[PlacedPickup] fixture={FixtureId.ToString()} state=Failed reason={InReason}", 0.0f);
    }

    private void Stop_Timer()
    {
        if (ck::IsValid(_Timer))
        {
            _Timer.UnbindFrom_OnDone(FCk_Delegate_Timer(this, n"OnCheckSupport"));
            utils_entity_lifetime::Request_DestroyEntity(_Timer.H());
        }
        _Timer = FCk_Handle_Timer();
    }
}
