// The dicing station's own state machine (FMars_Station_Spec.MinigameStateClass = UMars_SmState_Dicing_Idle). It runs on
// the STATION entity (context = the station, which also carries the Dicing feature) and reads the station's operator; it
// only issues Dicing requests and registers the operator's legend rows.
//
//   Idle      ->Operated [StationIsOperated]      task: Dicing_ResetOnEnter (a fresh pile for the next operator)
//   Operated  ->Idle     [StationIsNotOperated]   tasks: Dicing_OperatorInput (Tick), Dicing_OperatorHints
//
// The player's Operating state owns the pose, the camera (Captured: the view stays still, the look delta is ours), the
// glove grip and the Leave intent.

// Polled on the context entity's Station; false without one.
class UMars_SmCondition_StationIsOperated : UCk_SmCondition_Polled
{
    UFUNCTION(BlueprintOverride)
    bool DoEvaluate(FCk_Handle_SmCondition InHandle, FCk_Time InDeltaT) const
    {
        auto Station = ck::Ctx(InHandle).As_Station(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Station))
        { return false; }

        return Station.Get_IsOperated();
    }
}

class UMars_SmCondition_StationIsNotOperated : UMars_SmCondition_StationIsOperated
{
    default _NegateResult = true;
}

class UMars_SmState_Dicing_Idle : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToOperated = AddTransition(InHandle, UMars_SmState_Dicing_Operated);
        AddCondition(ToOperated, UMars_SmCondition_StationIsOperated);

        AddTask(InHandle, UMars_SmTask_Dicing_ResetOnEnter);
    }
}

class UMars_SmState_Dicing_Operated : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToIdle = AddTransition(InHandle, UMars_SmState_Dicing_Idle);
        AddCondition(ToIdle, UMars_SmCondition_StationIsNotOperated);

        AddTask(InHandle, UMars_SmTask_Dicing_OperatorInput);
        AddTask(InHandle, UMars_SmTask_Dicing_OperatorHints);
    }
}

// A fresh pile, band and hand. No Dicing on the context yet (the SM can enter before the entity script composes it) =
// nothing to reset.
class UMars_SmTask_Dicing_ResetOnEnter : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Dicing = ck::Ctx(InHandle).As_Dicing(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Dicing))
        { return; }

        Dicing.Request_Reset(FMars_Request_Dicing_Reset());
    }
}

// The operator's input, read off its InputIntents: one nudge per drained look delta (its horizontal component, degrees;
// positive = mouse right = the board's +Y, the operator's right), and one chop per rising edge of Interact_Primary. Both
// are seeded on enter, so a delta or a press from before the station was taken does not count. No operator intents
// (headless) = nothing to read.
class UMars_SmTask_Dicing_OperatorInput : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle_Dicing _Dicing;
    private FCk_Handle_InputIntents _Intents;
    private int32 _SeenLookSequence = 0;
    // The activation frame of the Interact_Primary hold last seen; unset while it is not held.
    private TOptional<int32> _SeenChopFrame;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto StationEntity = ck::Ctx(InHandle);
        _Dicing = StationEntity.As_Dicing();
        _Intents = FCk_Handle_InputIntents();

        auto Station = StationEntity.As_Station();
        auto Operator = Station.Get_Operator();
        _Intents = Operator.As_InputIntents(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Intents))
        { return; }

        _SeenLookSequence = _Intents.Get_LookDeltaSequence();
        _SeenChopFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Primary);
    }

    // Must return Running every frame: a Succeeded/Failed result would end the task while Operated is still active.
    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Dicing) || ck::Is_NOT_Valid(_Intents))
        { return ECk_SmTaskResult::Running; }

        const auto Sequence = _Intents.Get_LookDeltaSequence();
        if (Sequence != _SeenLookSequence)
        {
            _SeenLookSequence = Sequence;
            _Dicing.Request_Nudge(FMars_Request_Dicing_Nudge(float32(_Intents.Get_LookDelta().X)));
        }

        const auto ChopFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Primary);
        if (ChopFrame != _SeenChopFrame)
        {
            _SeenChopFrame = ChopFrame;
            if (ChopFrame.IsSet())
            { _Dicing.Request_Chop(FMars_Request_Dicing_Chop()); }
        }

        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Dicing = FCk_Handle_Dicing();
        _Intents = FCk_Handle_InputIntents();
        _SeenLookSequence = 0;
        _SeenChopFrame.Reset();
    }
}

// The operator's legend rows while operating, under owner key k_OwnerKey: "move hand" (IA_Look) and "chop"
// (IA_Interact_Primary). The pile's state is the station's world label, not a row: a legend row without an InputAction
// does not render. An operator without a display (headless) gets no rows.
class UMars_SmTask_Dicing_OperatorHints : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private const FName k_OwnerKey = n"Dicing";
    private const int32 k_MoveHandSortOrder = 7;
    private const int32 k_ChopSortOrder = 8;

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

        _Display.Request_RegisterHint(FMars_ActionHint_Spec(mars::Mars_IA_Look, FText::FromString("move hand"), k_MoveHandSortOrder, k_OwnerKey));
        _Display.Request_RegisterHint(FMars_ActionHint_Spec(mars::Mars_IA_Interact_Primary, FText::FromString("chop"), k_ChopSortOrder, k_OwnerKey));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Display))
        { _Display.Request_UnregisterHintsByOwner(FMars_Request_ActionHintDisplay_UnregisterByOwner(k_OwnerKey)); }

        _Display = FCk_Handle_ActionHintDisplay();
    }
}
