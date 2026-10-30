// The fishing station's control layer: its own state machine (FMars_Station_Spec.MinigameStateClass =
// UMars_SmState_Fishing_Idle). It runs on the STATION entity (context = the station, which also carries the Fishing feature)
// and reads the station's operator; it only issues Fishing requests and registers the operator's legend rows. It owns no
// simulation clock: the bait's flight, the bite, the hook window, the runs, the tension and the landing are the kernel's.
// Its only clocks are working state (the cast's charge, the snapped line's beat), kept on the tasks.
//
//   Idle      ->Operated [StationIsOperated]
//   Operated  ->Idle     [StationIsNotOperated]   tasks: Fishing_Engage, Fishing_OperatorInput (Tick: look turns the rod;
//                                                  Primary by the kernel's phase: Idle charges and casts, Bite strikes,
//                                                  the fight reels while held), Fishing_OperatorHints, Fishing_Phases
//     Aiming   ->Casting  [FishingIsCasting]
//     Casting  ->Waiting  [FishingIsWaiting]
//     Waiting  ->Bite     [FishingIsBite]
//     Bite     ->Fighting [FishingIsFighting]
//              ->Waiting  [FishingIsWaiting]       (the window closed)
//     Fighting ->Landing  [FishingIsLanded]
//              ->Snapped  [FishingIsSnapped]
//     Landing  ->Aiming   [FishingIsIdle]          Fishing_Land (Tick): once the fling arrives, the catch goes to the
//                                                  operator's hotbar (or the floor) and the spot is collected
//     Snapped  ->Aiming   [FishingIsIdle]          Fishing_SnapBeat (Tick): a beat, then the line is re-rigged
//     every one of them ->Aiming [FishingIsIdle]   (a reset from elsewhere)
//
// The player's Operating state owns the pose, the camera (Free inside the cast's yaw fence, so the operator looks where
// the cast goes), the glove grips and the Leave intent. The conditions on the station are the shared ones
// (Mars_Station_SmConditions.as).

class UMars_SmState_Fishing_Idle : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToOperated = AddTransition(InHandle, UMars_SmState_Fishing_Operated);
        AddCondition(ToOperated, UMars_SmCondition_StationIsOperated);
    }
}

class UMars_SmState_Fishing_Operated : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToIdle = AddTransition(InHandle, UMars_SmState_Fishing_Idle);
        AddCondition(ToIdle, UMars_SmCondition_StationIsNotOperated);

        AddTask(InHandle, UMars_SmTask_Fishing_Engage);
        AddTask(InHandle, UMars_SmTask_Fishing_OperatorInput);
        AddTask(InHandle, UMars_SmTask_Fishing_OperatorHints);
        AddTask(InHandle, UMars_SmTask_Fishing_Phases);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Conditions on the context's Fishing
//--------------------------------------------------------------------------------------------------------------------------

// Polled on the context entity's Fishing: its phase is _Phase. False without one.
UCLASS(Abstract)
class UMars_SmCondition_FishingPhaseIs : UCk_SmCondition_Polled
{
    EMars_Fishing_Phase _Phase = EMars_Fishing_Phase::Idle;

    UFUNCTION(BlueprintOverride)
    bool DoEvaluate(FCk_Handle_SmCondition InHandle, FCk_Time InDeltaT) const
    {
        auto Fishing = ck::Ctx(InHandle).As_Fishing(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Fishing))
        { return false; }

        return Fishing.Get_Phase() == _Phase;
    }
}

class UMars_SmCondition_FishingIsIdle : UMars_SmCondition_FishingPhaseIs
{
    default _Phase = EMars_Fishing_Phase::Idle;
}

class UMars_SmCondition_FishingIsCasting : UMars_SmCondition_FishingPhaseIs
{
    default _Phase = EMars_Fishing_Phase::Casting;
}

class UMars_SmCondition_FishingIsWaiting : UMars_SmCondition_FishingPhaseIs
{
    default _Phase = EMars_Fishing_Phase::Waiting;
}

class UMars_SmCondition_FishingIsBite : UMars_SmCondition_FishingPhaseIs
{
    default _Phase = EMars_Fishing_Phase::Bite;
}

class UMars_SmCondition_FishingIsLanded : UMars_SmCondition_FishingPhaseIs
{
    default _Phase = EMars_Fishing_Phase::Landed;
}

class UMars_SmCondition_FishingIsSnapped : UMars_SmCondition_FishingPhaseIs
{
    default _Phase = EMars_Fishing_Phase::Snapped;
}

// A fish is on: the hook is setting or the reel is in play.
class UMars_SmCondition_FishingIsFighting : UCk_SmCondition_Polled
{
    UFUNCTION(BlueprintOverride)
    bool DoEvaluate(FCk_Handle_SmCondition InHandle, FCk_Time InDeltaT) const
    {
        auto Fishing = ck::Ctx(InHandle).As_Fishing(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Fishing))
        { return false; }

        const auto Phase = Fishing.Get_Phase();
        return Phase == EMars_Fishing_Phase::Hooked || Phase == EMars_Fishing_Phase::Reeling;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Operated
//--------------------------------------------------------------------------------------------------------------------------

// The spot's clocks run exactly as long as the Operated state: taking the station engages it, leaving pulls the line in.
// No Fishing on the context (a composition that failed and already ensured) = nothing to do.
class UMars_SmTask_Fishing_Engage : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Fishing = ck::Ctx(InHandle).As_Fishing(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Fishing))
        { Fishing.Request_Engage(FMars_Request_Fishing_Engage()); }
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Fishing = ck::Ctx(InHandle).As_Fishing(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Fishing))
        { Fishing.Request_Disengage(FMars_Request_Fishing_Disengage()); }
    }
}

// The phases, one state each, following the kernel's phase.
class UMars_SmTask_Fishing_Phases : UCk_SmTask_SubStateMachine
{
    default _InitialStateClass = UMars_SmState_Fishing_Aiming;
    default _CompletionBehavior = ECk_SmTask_SubSm_CompletionBehavior::KeepRunning;
}

class UMars_SmState_Fishing_Aiming : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToCasting = AddTransition(InHandle, UMars_SmState_Fishing_Casting);
        AddCondition(ToCasting, UMars_SmCondition_FishingIsCasting);
    }
}

class UMars_SmState_Fishing_Casting : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToWaiting = AddTransition(InHandle, UMars_SmState_Fishing_Waiting);
        AddCondition(ToWaiting, UMars_SmCondition_FishingIsWaiting);

        auto ToAiming = AddTransition(InHandle, UMars_SmState_Fishing_Aiming);
        AddCondition(ToAiming, UMars_SmCondition_FishingIsIdle);
    }
}

class UMars_SmState_Fishing_Waiting : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToBite = AddTransition(InHandle, UMars_SmState_Fishing_Bite);
        AddCondition(ToBite, UMars_SmCondition_FishingIsBite);

        auto ToAiming = AddTransition(InHandle, UMars_SmState_Fishing_Aiming);
        AddCondition(ToAiming, UMars_SmCondition_FishingIsIdle);
    }
}

class UMars_SmState_Fishing_Bite : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToFighting = AddTransition(InHandle, UMars_SmState_Fishing_Fighting);
        AddCondition(ToFighting, UMars_SmCondition_FishingIsFighting);

        auto ToWaiting = AddTransition(InHandle, UMars_SmState_Fishing_Waiting);
        AddCondition(ToWaiting, UMars_SmCondition_FishingIsWaiting);

        auto ToAiming = AddTransition(InHandle, UMars_SmState_Fishing_Aiming);
        AddCondition(ToAiming, UMars_SmCondition_FishingIsIdle);
    }
}

class UMars_SmState_Fishing_Fighting : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToLanding = AddTransition(InHandle, UMars_SmState_Fishing_Landing);
        AddCondition(ToLanding, UMars_SmCondition_FishingIsLanded);

        auto ToSnapped = AddTransition(InHandle, UMars_SmState_Fishing_Snapped);
        AddCondition(ToSnapped, UMars_SmCondition_FishingIsSnapped);

        auto ToAiming = AddTransition(InHandle, UMars_SmState_Fishing_Aiming);
        AddCondition(ToAiming, UMars_SmCondition_FishingIsIdle);
    }
}

class UMars_SmState_Fishing_Landing : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToAiming = AddTransition(InHandle, UMars_SmState_Fishing_Aiming);
        AddCondition(ToAiming, UMars_SmCondition_FishingIsIdle);

        AddTask(InHandle, UMars_SmTask_Fishing_Land);
    }
}

class UMars_SmState_Fishing_Snapped : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToAiming = AddTransition(InHandle, UMars_SmState_Fishing_Aiming);
        AddCondition(ToAiming, UMars_SmCondition_FishingIsIdle);

        AddTask(InHandle, UMars_SmTask_Fishing_SnapBeat);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Input tasks
//--------------------------------------------------------------------------------------------------------------------------

namespace constants_fishing_station
{
    // Seconds of holding Primary that charge a full-distance cast; a tap casts k_ChargeMinPower of the range.
    const float32 k_ChargeFullSeconds = 1.0f;
    const float32 k_ChargeMinPower = 0.15f;

    // How long a snapped line is shown before it is re-rigged.
    const float32 k_SnapBeatSeconds = 1.2f;
}

// The operator's input, one reader for the whole Operated state so no edge falls between two states: every drained look
// delta (degrees; X yaw right+, Y pitch down+) turns the rod (the kernel clamps the aim to the cast's fence); the
// Interact_Primary edges go by the kernel's phase. Idle: going down starts the charge, coming up casts with the charge's
// power. Bite: going down strikes the hook, and the hold it leaves reels as soon as the fish is on. Hooked and Reeling:
// held reels, released eases (a release and a fresh press between two polls send both: the kernel drains Release before
// Hold), and the fight's end releases. The aim starts from the kernel's, so a re-taken station keeps where the rod pointed.
class UMars_SmTask_Fishing_OperatorInput : UMars_SmTask_StationOperatorInput
{
    private FCk_Handle_Fishing _Fishing;
    private FMars_LookCursor _Look;
    private FMars_IntentEdge _Primary;
    private float32 _YawDeg = 0.0f;
    private float32 _PitchDeg = 0.0f;
    // Game seconds the charge started at; unset while Primary is up or the spot is not Idle.
    private TOptional<float32> _ChargeStart;
    // The fish was on at the last poll.
    private bool _WasFighting = false;

    protected void Bind(FCk_Handle InStation) override
    {
        _Fishing = InStation.As_Fishing(ECk_SanityCheck::UnChecked);
        _WasFighting = false;
        if (ck::IsValid(_Fishing))
        {
            const auto Aim = _Fishing.Get_Aim();
            _YawDeg = Aim.YawDeg;
            _PitchDeg = Aim.PitchDeg;
        }
    }

    protected void Seed() override
    {
        _Look.Seed(_Intents);
        _Primary.Seed(_Intents, GameplayTags::Mars_Intent_Interact_Primary);
    }

    protected void Poll() override
    {
        if (ck::Is_NOT_Valid(_Fishing))
        { return; }

        if (_Look.Advance(_Intents))
        {
            const auto Delta = _Intents.Get_LookDelta();
            _YawDeg += float32(Delta.X);
            _PitchDeg -= float32(Delta.Y);
            _Fishing.Request_Aim(FMars_Request_Fishing_Aim(_YawDeg, _PitchDeg));
            const auto Fence = _Fishing.Get_Spec().Launch;
            _YawDeg = Math::Clamp(_YawDeg, -Fence.YawHalfAngleDeg, Fence.YawHalfAngleDeg);
            _PitchDeg = Math::Clamp(_PitchDeg, -Fence.PitchRangeDeg, Fence.PitchRangeDeg);
        }

        const auto Phase = _Fishing.Get_Phase();
        const auto IsFighting = Phase == EMars_Fishing_Phase::Hooked || Phase == EMars_Fishing_Phase::Reeling;
        const auto IsHeld = _Intents.Get_IsIntentActive(GameplayTags::Mars_Intent_Interact_Primary);
        if (IsFighting && _WasFighting == false && IsHeld)
        { _Fishing.Request_ReelHold(FMars_Request_Fishing_ReelHold()); }
        else if (IsFighting == false && _WasFighting)
        { _Fishing.Request_ReelRelease(FMars_Request_Fishing_ReelRelease()); }

        _WasFighting = IsFighting;

        const auto Edge = _Primary.Advance(_Intents, GameplayTags::Mars_Intent_Interact_Primary);
        if (Phase == EMars_Fishing_Phase::Idle)
        {
            if (utils_station::Get_HasRelease(Edge) && _ChargeStart.IsSet())
            {
                const auto Held = float32(System::GetGameTimeInSeconds()) - _ChargeStart.GetValue();
                const auto Power = Math::Clamp(Held / constants_fishing_station::k_ChargeFullSeconds, constants_fishing_station::k_ChargeMinPower, 1.0f);
                _ChargeStart = TOptional<float32>();
                _Fishing.Request_Cast(FMars_Request_Fishing_Cast(Power));
            }

            if (utils_station::Get_HasPress(Edge))
            { _ChargeStart = TOptional<float32>(float32(System::GetGameTimeInSeconds())); }

            return;
        }

        _ChargeStart = TOptional<float32>();
        if (Phase == EMars_Fishing_Phase::Bite)
        {
            if (utils_station::Get_HasPress(Edge))
            { _Fishing.Request_Hook(FMars_Request_Fishing_Hook()); }

            return;
        }

        if (IsFighting == false)
        { return; }

        if (utils_station::Get_HasRelease(Edge))
        { _Fishing.Request_ReelRelease(FMars_Request_Fishing_ReelRelease()); }

        if (utils_station::Get_HasPress(Edge))
        { _Fishing.Request_ReelHold(FMars_Request_Fishing_ReelHold()); }
    }

    protected void Unbind() override
    {
        if (ck::IsValid(_Fishing) && _WasFighting)
        { _Fishing.Request_ReelRelease(FMars_Request_Fishing_ReelRelease()); }

        _Fishing = FCk_Handle_Fishing();
        _Look = FMars_LookCursor();
        _Primary = FMars_IntentEdge();
        _ChargeStart = TOptional<float32>();
        _WasFighting = false;
    }
}

// The landing: once the fling has arrived, the catch lands on the bank as a World-mode food item at the catch point (a
// whole food is its own world item, picked up by hand, never conjured into a hotbar) and the spot is collected. Once per
// landing.
class UMars_SmTask_Fishing_Land : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle _Station;
    private FCk_Handle_Fishing _Fishing;
    private bool _Granted = false;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Station = ck::Ctx(InHandle);
        _Fishing = _Station.As_Fishing(ECk_SanityCheck::UnChecked);
        _Granted = false;
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (_Granted || ck::Is_NOT_Valid(_Fishing) || _Fishing.Get_Phase() != EMars_Fishing_Phase::Landed)
        { return ECk_SmTaskResult::Running; }

        if (_Fishing.Get_FlingAlpha() < 1.0f)
        { return ECk_SmTaskResult::Running; }

        _Granted = true;
        utils_fishing_station::Land_Catch(_Fishing.Get_Catch(), _Fishing.Get_CatchWorld());
        _Fishing.Request_Collect(FMars_Request_Fishing_Collect());
        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Station = FCk_Handle();
        _Fishing = FCk_Handle_Fishing();
    }
}

// A snapped line is shown for k_SnapBeatSeconds, then re-rigged.
class UMars_SmTask_Fishing_SnapBeat : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle_Fishing _Fishing;
    private float32 _SecondsLeft = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Fishing = ck::Ctx(InHandle).As_Fishing(ECk_SanityCheck::UnChecked);
        _SecondsLeft = constants_fishing_station::k_SnapBeatSeconds;
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (_SecondsLeft <= 0.0f || ck::Is_NOT_Valid(_Fishing))
        { return ECk_SmTaskResult::Running; }

        _SecondsLeft -= float32(InDeltaT.Get_Seconds());
        if (_SecondsLeft <= 0.0f)
        { _Fishing.Request_Reset(FMars_Request_Fishing_Reset()); }

        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Fishing = FCk_Handle_Fishing();
    }
}

namespace utils_fishing_station
{
    // InCatch as a World-mode item at InCatchWorld, loose under the world's transient entity (it outlives the spot), dropped
    // from the fling's end so it settles on the bank. Returns the entity under construction.
    FCk_Handle Land_Catch(const FMars_Fishing_Catch& InCatch, FVector InCatchWorld)
    {
        auto Owner = ck::TransientEntity();
        return utils_world_item::Request_SpawnWorld(Owner, FMars_WorldItem_WorldSpec(InCatch.Item, FTransform(FRotator::ZeroRotator, InCatchWorld)));
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Hints
//--------------------------------------------------------------------------------------------------------------------------

// The operator's legend rows while operating, re-read on every phase: the rod's row (IA_Interact_Primary: "hold to charge,
// let go to cast" while aiming, "strike!" on a bite, "hold to reel, let go to ease" in the fight) and the aim row (IA_Look)
// while aiming.
class UMars_SmTask_Fishing_OperatorHints : UMars_SmTask_StationOperatorHints
{
    private const int32 k_RodSortOrder = 5;
    private const int32 k_AimSortOrder = 6;

    private FCk_Handle_Fishing _Fishing;
    private FCk_Handle_ActionHintRow _RodRow;
    private FCk_Handle_ActionHintRow _AimRow;

    protected FName Get_OwnerKey() const override
    {
        return n"Fishing";
    }

    protected void Register_Rows() override
    {
        _Fishing = _Station.As_Fishing(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Fishing))
        { return; }

        _Fishing.BindTo_OnPhaseChanged(FMars_Delegate_Fishing_OnPhaseChanged(this, n"OnPhaseChanged"));
        Refresh_Rows(_Fishing.Get_Phase());
    }

    protected void Unregister_Rows() override
    {
        if (ck::IsValid(_Fishing))
        { _Fishing.UnbindFrom_OnPhaseChanged(FMars_Delegate_Fishing_OnPhaseChanged(this, n"OnPhaseChanged")); }

        _Fishing = FCk_Handle_Fishing();
        _RodRow = FCk_Handle_ActionHintRow();
        _AimRow = FCk_Handle_ActionHintRow();
    }

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_Fishing InFishing, EMars_Fishing_Phase InPhase)
    {
        Refresh_Rows(InPhase);
    }

    private void Refresh_Rows(EMars_Fishing_Phase InPhase)
    {
        FString RodText = "";
        switch (InPhase)
        {
            case EMars_Fishing_Phase::Idle: RodText = "hold to charge, let go to cast"; break;
            case EMars_Fishing_Phase::Waiting: RodText = "wait for the dip"; break;
            case EMars_Fishing_Phase::Bite: RodText = "strike!"; break;
            case EMars_Fishing_Phase::Hooked:
            case EMars_Fishing_Phase::Reeling: RodText = "hold to reel, let go to ease"; break;
            case EMars_Fishing_Phase::Landed: RodText = "caught"; break;
            case EMars_Fishing_Phase::Snapped: RodText = "the line snapped"; break;
            default: break;
        }

        if (RodText.IsEmpty())
        { _RodRow = Clear_Row(_RodRow); }
        else
        { _RodRow = Show_Row(_RodRow, Make_Row(mars::Mars_IA_Interact_Primary, RodText, k_RodSortOrder)); }

        if (InPhase == EMars_Fishing_Phase::Idle)
        { _AimRow = Show_Row(_AimRow, Make_Row(mars::Mars_IA_Look, "aim", k_AimSortOrder)); }
        else
        { _AimRow = Clear_Row(_AimRow); }
    }
}
