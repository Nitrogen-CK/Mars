// The fry station's control layer: its own state machine (FMars_Station_Spec.MinigameStateClass = UMars_SmState_Fry_Idle).
// It runs on the STATION entity (context = the station, which also carries the Fry feature and the platter's CookingFeed)
// and reads the station's operator; it only issues Fry and CookingFeed requests and registers the operator's legend rows.
// The feed tasks are the shared ones (Mars_StationFeed_SmTasks.as).
//
//   Idle      ->Operated [StationIsOperated]      tasks: StationFeed_ResetOnEnter (a full platter, a new generation),
//                                                 Fry_ResetOnEnter (an empty pot, the skimmer parked and idle)
//   Operated  ->Idle     [StationIsNotOperated]   tasks: Fry_DriveOnEnter (the skimmer is in hand), Fry_OperatorInput (Tick),
//                                                 Fry_OperatorHints, StationFeed_OperatorInput (Tick), StationFeed_Bridge,
//                                                 StationFeed_OperatorHints
//
// The conditions are the shared station ones (Mars_Station_SmConditions.as). The player's Operating state owns the pose,
// the camera (Captured: the view stays still, the look delta is ours), the glove grips and the Leave intent.

class UMars_SmState_Fry_Idle : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToOperated = AddTransition(InHandle, UMars_SmState_Fry_Operated);
        AddCondition(ToOperated, UMars_SmCondition_StationIsOperated);

        AddTask(InHandle, UMars_SmTask_StationFeed_ResetOnEnter);
        AddTask(InHandle, UMars_SmTask_Fry_ResetOnEnter);
    }
}

class UMars_SmState_Fry_Operated : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToIdle = AddTransition(InHandle, UMars_SmState_Fry_Idle);
        AddCondition(ToIdle, UMars_SmCondition_StationIsNotOperated);

        AddTask(InHandle, UMars_SmTask_Fry_DriveOnEnter);
        AddTask(InHandle, UMars_SmTask_Fry_OperatorInput);
        AddTask(InHandle, UMars_SmTask_Fry_OperatorHints);
        AddTask(InHandle, UMars_SmTask_StationFeed_OperatorInput);
        AddTask(InHandle, UMars_SmTask_StationFeed_Bridge);
        AddTask(InHandle, UMars_SmTask_StationFeed_OperatorHints);
    }
}

// Destroys every piece (in the oil, on the scoop, in the basket or lost), parks, levels and idles the skimmer and zeroes
// the tally; the pot stays empty until the feed admits a piece. Added after the feed's reset, so the generation bump comes
// first. No Fry on the context yet (the SM can enter before the entity script composes it) = nothing to reset.
class UMars_SmTask_Fry_ResetOnEnter : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Fry = ck::Ctx(InHandle).As_Fry(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Fry))
        { return; }

        Fry.Request_Reset(FMars_Request_Fry_Reset());
    }
}

// Taking the station puts the skimmer in the operator's right hand: it is driven from the first frame (there is no tool to
// pick). Leaving resets (Idle), which idles it.
class UMars_SmTask_Fry_DriveOnEnter : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Fry = ck::Ctx(InHandle).As_Fry();
        Fry.Request_SetDrive(FMars_Request_Fry_SetDrive(EMars_Implement_Drive::Driven));
    }
}

// The operator's input, read off its InputIntents: one look per drained look delta (degrees; X yaw right+, Y pitch down+),
// which moves the skimmer; Interact_Primary's rising edge asks for a dip (the kernel pours instead over the basket, and
// ignores it in the corridor) and its falling edge carries. Interact_Secondary is not read. Both are seeded on enter, so a
// delta or a hold from before the station was taken does not count. No operator intents (headless) = nothing to read.
class UMars_SmTask_Fry_OperatorInput : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle_Fry _Fry;
    private FCk_Handle_InputIntents _Intents;
    private int32 _SeenLookSequence = 0;
    // The activation frame of the Interact_Primary hold last seen; unset while it is not held.
    private TOptional<int32> _SeenPrimaryFrame;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto StationEntity = ck::Ctx(InHandle);
        _Fry = StationEntity.As_Fry();
        _Intents = FCk_Handle_InputIntents();

        auto Station = StationEntity.As_Station();
        auto Operator = Station.Get_Operator();
        _Intents = Operator.As_InputIntents(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Intents))
        { return; }

        _SeenLookSequence = _Intents.Get_LookDeltaSequence();
        _SeenPrimaryFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Primary);
    }

    // Must return Running every frame: a Succeeded/Failed result would end the task while Operated is still active.
    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Fry) || ck::Is_NOT_Valid(_Intents))
        { return ECk_SmTaskResult::Running; }

        const auto Sequence = _Intents.Get_LookDeltaSequence();
        if (Sequence != _SeenLookSequence)
        {
            _SeenLookSequence = Sequence;
            const auto Delta = _Intents.Get_LookDelta();
            ck::Trace(f"[Fry] operator look {Delta}");
            _Fry.Request_Look(FMars_Request_Fry_Look(Delta));
        }

        const auto PrimaryFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Primary);
        if (PrimaryFrame != _SeenPrimaryFrame)
        {
            _SeenPrimaryFrame = PrimaryFrame;
            const auto Skim = PrimaryFrame.IsSet() ? EMars_Fry_Skim::Dip : EMars_Fry_Skim::Carry;
            _Fry.Request_Skim(FMars_Request_Fry_Skim(Skim));
        }

        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Fry = FCk_Handle_Fry();
        _Intents = FCk_Handle_InputIntents();
        _SeenLookSequence = 0;
        _SeenPrimaryFrame.Reset();
    }
}

// The operator's legend rows while operating, under owner key k_OwnerKey: "move the skimmer" (IA_Look) and the dip row
// (IA_Interact_Primary), re-texted on every skim edge: "hold to dip · press over the basket to pour" while carrying,
// "release to lift" while dipped, "pouring · release to level" while pouring. Registered once on enter (the display drains
// registers before unregisters, so the rows are re-texted, never re-registered). The batch's state is the station's world
// label, not a row. An operator without a display (headless) gets no rows.
class UMars_SmTask_Fry_OperatorHints : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private const FName k_OwnerKey = n"Fry";
    private const int32 k_LookSortOrder = 7;
    private const int32 k_PrimarySortOrder = 8;

    private FCk_Handle_Fry _Fry;
    private FCk_Handle_ActionHintDisplay _Display;
    private FCk_Handle_ActionHintRow _PrimaryRow;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Display = FCk_Handle_ActionHintDisplay();

        auto StationEntity = ck::Ctx(InHandle);
        auto Station = StationEntity.As_Station();
        auto Operator = Station.Get_Operator();
        _Display = Operator.As_ActionHintDisplay(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Display))
        { return; }

        _Fry = StationEntity.As_Fry();
        _Display.Request_RegisterHint(FMars_ActionHint_Spec(mars::Mars_IA_Look, FText::FromString("move the skimmer"), k_LookSortOrder, k_OwnerKey));
        _PrimaryRow = _Display.Request_RegisterHint(
            FMars_ActionHint_Spec(mars::Mars_IA_Interact_Primary, Get_PrimaryText(_Fry.Get_Skim()), k_PrimarySortOrder, k_OwnerKey));
        _Fry.BindTo_OnSkimChanged(FMars_Delegate_Fry_OnSkimChanged(this, n"OnSkimChanged"));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Fry))
        { _Fry.UnbindFrom_OnSkimChanged(FMars_Delegate_Fry_OnSkimChanged(this, n"OnSkimChanged")); }

        if (ck::IsValid(_Display))
        { _Display.Request_UnregisterHintsByOwner(FMars_Request_ActionHintDisplay_UnregisterByOwner(k_OwnerKey)); }

        _Fry = FCk_Handle_Fry();
        _Display = FCk_Handle_ActionHintDisplay();
        _PrimaryRow = FCk_Handle_ActionHintRow();
    }

    UFUNCTION()
    private void OnSkimChanged(FCk_Handle_Fry InFry, EMars_Fry_Skim InSkim)
    {
        if (ck::Is_NOT_Valid(_Display) || ck::Is_NOT_Valid(_PrimaryRow))
        { return; }

        _Display.Request_UpdateHint(FMars_Request_ActionHintDisplay_Update(_PrimaryRow, Get_PrimaryText(InSkim)));
    }

    private FText Get_PrimaryText(EMars_Fry_Skim InSkim) const
    {
        if (InSkim == EMars_Fry_Skim::Dip)
        { return FText::FromString("release to lift"); }

        if (InSkim == EMars_Fry_Skim::Pour)
        { return FText::FromString("pouring · release to level"); }

        return FText::FromString("hold to dip · press over the basket to pour");
    }
}
