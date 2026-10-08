// The searing station's control layer: its own state machine (FMars_Station_Spec.MinigameStateClass =
// UMars_SmState_Searing_Idle). It runs on the STATION entity (context = the station, which also carries the Searing
// feature and the platter's CookingFeed) and reads the station's operator; it only issues Searing and CookingFeed requests
// and registers the operator's legend rows. The feed tasks are the shared ones (Mars_StationFeed_SmTasks.as).
//
//   Idle      ->Operated [StationIsOperated]      tasks: StationFeed_ResetOnEnter (a full platter, a new generation),
//                                                 Searing_ResetOnEnter (an empty, cold pan for the next operator)
//   Operated  ->Idle     [StationIsNotOperated]   tasks: Searing_HeatOnEnter, Searing_OperatorInput (Tick), Searing_OperatorHints,
//                                                 StationFeed_OperatorInput (Tick), StationFeed_Bridge, StationFeed_OperatorHints
//
// The conditions are the shared station ones (Mars_Station_SmConditions.as). The player's Operating state owns the pose,
// the camera (Captured: the view stays still, the look delta is ours), the glove grip and the Leave intent.

class UMars_SmState_Searing_Idle : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToOperated = AddTransition(InHandle, UMars_SmState_Searing_Operated);
        AddCondition(ToOperated, UMars_SmCondition_StationIsOperated);

        AddTask(InHandle, UMars_SmTask_StationFeed_ResetOnEnter);
        AddTask(InHandle, UMars_SmTask_Searing_ResetOnEnter);
    }
}

class UMars_SmState_Searing_Operated : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToIdle = AddTransition(InHandle, UMars_SmState_Searing_Idle);
        AddCondition(ToIdle, UMars_SmCondition_StationIsNotOperated);

        AddTask(InHandle, UMars_SmTask_Searing_HeatOnEnter);
        AddTask(InHandle, UMars_SmTask_Searing_OperatorInput);
        AddTask(InHandle, UMars_SmTask_Searing_OperatorHints);
        AddTask(InHandle, UMars_SmTask_StationFeed_OperatorInput);
        AddTask(InHandle, UMars_SmTask_StationFeed_Bridge);
        AddTask(InHandle, UMars_SmTask_StationFeed_OperatorHints);
    }
}

// Destroys every piece, levels and idles the pan and chills it; the pan stays empty until the feed admits a piece. Added
// after the feed's reset, so the generation bump comes first. No Searing on the context yet (the SM can enter before the
// entity script composes it) = nothing to reset.
class UMars_SmTask_Searing_ResetOnEnter : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Searing = ck::Ctx(InHandle).As_Searing(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Searing))
        { return; }

        Searing.Request_Reset(FMars_Request_Searing_Reset());
    }
}

// The operator lights the burner by taking the station; leaving it resets (Idle) and so chills it.
class UMars_SmTask_Searing_HeatOnEnter : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Searing = ck::Ctx(InHandle).As_Searing();
        Searing.Request_SetHeat(FMars_Request_Searing_SetHeat(EMars_Searing_Heat::Hot));
    }
}

// The operator's input, read off its InputIntents: one look per drained look delta (degrees; X yaw right+, Y pitch down+),
// which tilts the pan and, fast and upward, tosses it. Seeded on enter, so a delta from before the station was taken does
// not count. No operator intents (headless) = nothing to read.
class UMars_SmTask_Searing_OperatorInput : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle_Searing _Searing;
    private FCk_Handle_InputIntents _Intents;
    private int32 _SeenLookSequence = 0;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto StationEntity = ck::Ctx(InHandle);
        _Searing = StationEntity.As_Searing();
        _Intents = FCk_Handle_InputIntents();

        auto Station = StationEntity.As_Station();
        auto Operator = Station.Get_Operator();
        _Intents = Operator.As_InputIntents(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Intents))
        { return; }

        _SeenLookSequence = _Intents.Get_LookDeltaSequence();
    }

    // Must return Running every frame: a Succeeded/Failed result would end the task while Operated is still active.
    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Searing) || ck::Is_NOT_Valid(_Intents))
        { return ECk_SmTaskResult::Running; }

        const auto Sequence = _Intents.Get_LookDeltaSequence();
        if (Sequence != _SeenLookSequence)
        {
            _SeenLookSequence = Sequence;
            const auto Delta = _Intents.Get_LookDelta();
            ck::Trace(f"[Searing] operator look {Delta}");
            _Searing.Request_Look(FMars_Request_Searing_Look(Delta));
        }

        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Searing = FCk_Handle_Searing();
        _Intents = FCk_Handle_InputIntents();
        _SeenLookSequence = 0;
    }
}

// The operator's legend row while operating, under owner key k_OwnerKey: "tilt the pan, flick up to toss" (IA_Look). The
// pieces' state is the station's world label, not a row. An operator without a display (headless) gets no rows.
class UMars_SmTask_Searing_OperatorHints : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private const FName k_OwnerKey = n"Searing";
    private const int32 k_TiltSortOrder = 7;

    private FCk_Handle_ActionHintDisplay _Display;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Display = FCk_Handle_ActionHintDisplay();

        auto Station = ck::Ctx(InHandle).As_Station();
        auto Operator = Station.Get_Operator();
        _Display = Operator.As_ActionHintDisplay(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Display))
        { return; }

        _Display.Request_RegisterHint(FMars_ActionHint_Spec(mars::Mars_IA_Look, FText::FromString("tilt the pan, flick up to toss"), k_TiltSortOrder, k_OwnerKey));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Display))
        { _Display.Request_UnregisterHintsByOwner(FMars_Request_ActionHintDisplay_UnregisterByOwner(k_OwnerKey)); }

        _Display = FCk_Handle_ActionHintDisplay();
    }
}
