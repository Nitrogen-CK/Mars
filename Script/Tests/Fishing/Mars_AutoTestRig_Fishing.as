// The fishing rig: a Fishing kernel on a bare entity, nothing drawn, with three scene-node entities for its frame (the
// origin, facing +X), its anchor (120 cm up, the rod tip) and its catch point. The water is the Z = 0 plane. The timing is
// slow and wide (a fixed half-second bite wait, a 2 s hook window, a fast reel, no runs) so a poll lands deep inside or
// well outside every window whatever the frame rate. The handlers count the signals; the steps engage, cast, hook, hold
// and release.
UCLASS(Abstract)
class UMars_AutoTestRig_Fishing : UCk_AutoTest_Base
{
    protected const FVector k_Origin = FVector(0.0, 0.0, 0.0);
    protected const FVector k_AnchorLocal = FVector(0.0, 0.0, 120.0);
    protected const FVector k_CatchLocal = FVector(-60.0, 0.0, 110.0);

    protected FCk_Handle_Fishing _Fishing;
    protected FCk_Handle_Transform _Frame;
    protected FCk_Handle_Transform _Anchor;
    protected FCk_Handle_Transform _Catch;

    protected int32 _Casts = 0;
    protected int32 _BaitLandings = 0;
    protected int32 _Bites = 0;
    protected int32 _BitesHooked = 0;
    protected int32 _BitesMissed = 0;
    protected int32 _RunStarts = 0;
    protected int32 _RunEnds = 0;
    protected int32 _Snaps = 0;
    protected int32 _Lands = 0;
    protected int32 _Collects = 0;
    protected int32 _PresenceChanges = 0;
    protected TArray<EMars_Fishing_Phase> _PhasesSeen;

    protected FVector _LastLaunchVelocity;
    protected FVector _LastLandingPoint;
    protected FMars_Fishing_Catch _LastLandedCatch;
    protected FMars_Fishing_Catch _LastCollectedCatch;
    protected EMars_Fishing_Presence _LastPresence = EMars_Fishing_Presence::Open;

    // Game seconds at the last bait landing and the last bite.
    protected float32 _BaitLandedAtSeconds = 0.0f;
    protected float32 _BiteAtSeconds = 0.0f;

    protected FMars_Fishing_Spec Make_Spec() const
    {
        auto Spec = FMars_Fishing_Spec();
        Spec.Launch.MaxDistanceCm = 600.0f;
        Spec.Launch.MinDistanceCm = 100.0f;
        Spec.Bite.MinWaitSeconds = 0.5f;
        Spec.Bite.MaxWaitSeconds = 0.5f;
        Spec.Bite.HookWindowSeconds = 2.0f;
        Spec.Bite.MissPenaltySeconds = 0.25f;
        Spec.Reel.ReelSpeedCmPerS = 400.0f;
        Spec.Reel.HookSetSeconds = 0.1f;
        Spec.Run.MinGapSeconds = 100.0f;
        Spec.Run.MaxGapSeconds = 100.0f;
        Spec.Run.MinRunSeconds = 0.5f;
        Spec.Run.MaxRunSeconds = 0.5f;
        Spec.Run.PullCmPerS = 0.0f;
        Spec.Fish.Table.Add(FMars_Fishing_FishEntry(mars_items::Food_MeatSlab(), 1.0f, 1.0f));
        Spec.Fish.LandFlingSeconds = 0.3f;
        Spec.Water.SurfaceZ = 0.0;
        Spec.Seed = 7;
        return Spec;
    }

    // The three nodes the spec carries. Call before BuildFishing, or let it.
    protected void BuildNodes(FCk_Handle InHandle)
    {
        if (ck::IsValid(_Frame))
        { return; }

        auto FrameEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Frame = utils_transform::Add(FrameEntity, FTransform(FRotator::ZeroRotator, k_Origin), ECk_Replication::DoesNotReplicate);

        auto AnchorEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Anchor = utils_transform::Add(AnchorEntity, FTransform(FRotator::ZeroRotator, k_Origin + k_AnchorLocal), ECk_Replication::DoesNotReplicate);

        auto CatchEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Catch = utils_transform::Add(CatchEntity, FTransform(FRotator::ZeroRotator, k_Origin + k_CatchLocal), ECk_Replication::DoesNotReplicate);
    }

    protected FMars_Fishing_Spec Make_SpecWithNodes(FCk_Handle InHandle)
    {
        BuildNodes(InHandle);
        auto Spec = Make_Spec();
        Spec.Setup.Frame = _Frame;
        Spec.Setup.Anchor = _Anchor;
        Spec.Setup.Catch = _Catch;
        return Spec;
    }

    protected void BuildFishing(FCk_Handle InHandle, FMars_Fishing_Spec InSpec)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Fishing = utils_fishing::Add(Entity, InSpec);
        Assert_True(ck::IsValid(_Fishing), "the fishing spot composed");

        _Fishing.BindTo_OnPhaseChanged(FMars_Delegate_Fishing_OnPhaseChanged(this, n"OnPhaseChanged"));
        _Fishing.BindTo_OnPresenceChanged(FMars_Delegate_Fishing_OnPresenceChanged(this, n"OnPresenceChanged"));
        _Fishing.BindTo_OnCast(FMars_Delegate_Fishing_OnCast(this, n"OnCast"));
        _Fishing.BindTo_OnBaitLanded(FMars_Delegate_Fishing_OnBaitLanded(this, n"OnBaitLanded"));
        _Fishing.BindTo_OnBite(FMars_Delegate_Fishing_OnBite(this, n"OnBite"));
        _Fishing.BindTo_OnBiteEnded(FMars_Delegate_Fishing_OnBiteEnded(this, n"OnBiteEnded"));
        _Fishing.BindTo_OnRun(FMars_Delegate_Fishing_OnRun(this, n"OnRun"));
        _Fishing.BindTo_OnSnapped(FMars_Delegate_Fishing_OnSnapped(this, n"OnSnapped"));
        _Fishing.BindTo_OnLanded(FMars_Delegate_Fishing_OnLanded(this, n"OnLanded"));
        _Fishing.BindTo_OnCollected(FMars_Delegate_Fishing_OnCollected(this, n"OnCollected"));
    }

    protected float32 Get_BaitHorizontalDistance() const
    {
        const auto Out = _Fishing.Get_Bait().Position - (k_Origin + k_AnchorLocal);
        return float32(FVector(Out.X, Out.Y, 0.0).Size());
    }

    protected int32 Count_PhaseSeen(EMars_Fishing_Phase InPhase) const
    {
        int32 Count = 0;
        for (const auto& Phase : _PhasesSeen)
        {
            if (Phase == InPhase)
            { ++Count; }
        }
        return Count;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void OnPhaseChanged(FCk_Handle_Fishing InFishing, EMars_Fishing_Phase InPhase)
    {
        _PhasesSeen.Add(InPhase);
    }

    UFUNCTION()
    protected void OnPresenceChanged(FCk_Handle_Fishing InFishing, EMars_Fishing_Presence InPresence)
    {
        ++_PresenceChanges;
        _LastPresence = InPresence;
    }

    UFUNCTION()
    protected void OnCast(FCk_Handle_Fishing InFishing, FVector InLaunchVelocity)
    {
        ++_Casts;
        _LastLaunchVelocity = InLaunchVelocity;
    }

    UFUNCTION()
    protected void OnBaitLanded(FCk_Handle_Fishing InFishing, FVector InPoint)
    {
        ++_BaitLandings;
        _LastLandingPoint = InPoint;
        _BaitLandedAtSeconds = float32(System::GetGameTimeInSeconds());
    }

    UFUNCTION()
    protected void OnBite(FCk_Handle_Fishing InFishing)
    {
        ++_Bites;
        _BiteAtSeconds = float32(System::GetGameTimeInSeconds());
    }

    UFUNCTION()
    protected void OnBiteEnded(FCk_Handle_Fishing InFishing, EMars_Fishing_BiteResult InResult)
    {
        if (InResult == EMars_Fishing_BiteResult::Hooked)
        { ++_BitesHooked; }
        else
        { ++_BitesMissed; }
    }

    UFUNCTION()
    protected void OnRun(FCk_Handle_Fishing InFishing, bool InStarted)
    {
        if (InStarted)
        { ++_RunStarts; }
        else
        { ++_RunEnds; }
    }

    UFUNCTION()
    protected void OnSnapped(FCk_Handle_Fishing InFishing)
    {
        ++_Snaps;
    }

    UFUNCTION()
    protected void OnLanded(FCk_Handle_Fishing InFishing, FMars_Fishing_Catch InCatch)
    {
        ++_Lands;
        _LastLandedCatch = InCatch;
    }

    UFUNCTION()
    protected void OnCollected(FCk_Handle_Fishing InFishing, FMars_Fishing_Catch InCatch)
    {
        ++_Collects;
        _LastCollectedCatch = InCatch;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Step_Engage(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Fishing.Request_Engage(FMars_Request_Fishing_Engage());
    }

    UFUNCTION()
    protected void Step_Disengage(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Fishing.Request_Disengage(FMars_Request_Fishing_Disengage());
    }

    // A full-power cast straight down the frame's X.
    UFUNCTION()
    protected void Step_CastFull(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Fishing.Request_Aim(FMars_Request_Fishing_Aim(0.0f, 0.0f));
        _Fishing.Request_Cast(FMars_Request_Fishing_Cast(1.0f));
    }

    UFUNCTION()
    protected void Step_Hook(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Fishing.Request_Hook(FMars_Request_Fishing_Hook());
    }

    UFUNCTION()
    protected void Step_Hold(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Fishing.Request_ReelHold(FMars_Request_Fishing_ReelHold());
    }

    UFUNCTION()
    protected void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Fishing.Request_ReelRelease(FMars_Request_Fishing_ReelRelease());
    }

    UFUNCTION()
    protected void Step_Collect(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Fishing.Request_Collect(FMars_Request_Fishing_Collect());
    }

    UFUNCTION()
    protected void Step_Reset(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Fishing.Request_Reset(FMars_Request_Fishing_Reset());
    }

    UFUNCTION()
    protected void Step_Leave(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Fishing.Request_Leave(FMars_Request_Fishing_Leave());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Predicates
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Check_Engaged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fishing.Get_IsEngaged());
    }

    UFUNCTION()
    protected void Check_Disengaged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fishing.Get_IsEngaged() == false);
    }

    UFUNCTION()
    protected void Check_Idle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fishing.Get_Phase() == EMars_Fishing_Phase::Idle);
    }

    UFUNCTION()
    protected void Check_Waiting(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fishing.Get_Phase() == EMars_Fishing_Phase::Waiting);
    }

    UFUNCTION()
    protected void Check_Bite(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fishing.Get_Phase() == EMars_Fishing_Phase::Bite);
    }

    UFUNCTION()
    protected void Check_Reeling(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fishing.Get_Phase() == EMars_Fishing_Phase::Reeling);
    }

    UFUNCTION()
    protected void Check_Landed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fishing.Get_Phase() == EMars_Fishing_Phase::Landed);
    }

    UFUNCTION()
    protected void Check_Snapped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fishing.Get_Phase() == EMars_Fishing_Phase::Snapped);
    }

    UFUNCTION()
    protected void Check_FlingDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fishing.Get_Phase() == EMars_Fishing_Phase::Landed && _Fishing.Get_FlingAlpha() >= 1.0f);
    }

    UFUNCTION()
    protected void Check_Open(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fishing.Get_Presence() == EMars_Fishing_Presence::Open);
    }

    UFUNCTION()
    protected void Check_Gone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fishing.Get_Presence() == EMars_Fishing_Presence::Gone);
    }
}
