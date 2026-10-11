// The batter station's control layer: its own state machine (FMars_Station_Spec.MinigameStateClass =
// UMars_SmState_Batter_Idle). It runs on the STATION entity (context = the station, which also carries the Batter feature
// and the raw platter's CookingFeed; its two platter docks are lifetime children of it) and reads the station's operator;
// it only issues Batter and CookingFeed requests and registers the operator's legend rows. The feed tasks are the shared
// ones (Mars_StationFeed_SmTasks.as). It owns no clock: the coat clock and the dip's ease are the kernel's.
//
//   Idle      ->Operated [StationIsOperated]      tasks: StationFeed_Source, StationFeed_Bridge (a release in flight lands; no
//                                                 reset: the batch and its coats persist across a leave and a re-enter)
//   Operated  ->Idle     [StationIsNotOperated]   tasks: Batter_OperatorInput (Tick), Batter_LiftOnExit, StationFeed_Source,
//                                                 BatterFeed_OperatorInput (Tick), StationFeed_Bridge,
//                                                 StationFeed_OperatorHints, Batter_OperatorHints, StationFeed_TakeOutInput
//                                                 (Tick)
//
// A piece the bowl hands back lands on the finished tray through the kernel's own landing, whoever operates. The conditions
// are the shared station ones (Mars_Station_SmConditions.as). The player's Operating state owns the pose, the camera, the
// glove grips and the Leave intent.

class UMars_SmState_Batter_Idle : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToOperated = AddTransition(InHandle, UMars_SmState_Batter_Operated);
        AddCondition(ToOperated, UMars_SmCondition_StationIsOperated);

        AddTask(InHandle, UMars_SmTask_StationFeed_Source);
        AddTask(InHandle, UMars_SmTask_StationFeed_Bridge);
    }
}

class UMars_SmState_Batter_Operated : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToIdle = AddTransition(InHandle, UMars_SmState_Batter_Idle);
        AddCondition(ToIdle, UMars_SmCondition_StationIsNotOperated);

        AddTask(InHandle, UMars_SmTask_Batter_OperatorInput);
        AddTask(InHandle, UMars_SmTask_Batter_LiftOnExit);
        AddTask(InHandle, UMars_SmTask_StationFeed_Source);
        AddTask(InHandle, UMars_SmTask_BatterFeed_OperatorInput);
        AddTask(InHandle, UMars_SmTask_StationFeed_Bridge);
        AddTask(InHandle, UMars_SmTask_StationFeed_OperatorHints);
        AddTask(InHandle, UMars_SmTask_Batter_OperatorHints);
        AddTask(InHandle, UMars_SmTask_StationFeed_TakeOutInput);
    }
}

// The operator's input, read off its InputIntents: Interact_Primary going down dips the bowl's pieces and coming up lifts
// them (Interact_Secondary is StationFeed_TakeOutInput's). Seeded on enter, so a hold from before the station was taken
// never counts. No operator intents (headless) = nothing to read.
class UMars_SmTask_Batter_OperatorInput : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle_Batter _Batter;
    private FCk_Handle_InputIntents _Intents;
    // The activation frame of the Interact_Primary hold last seen; unset while it is not held.
    private TOptional<int32> _SeenPrimaryFrame;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto StationEntity = ck::Ctx(InHandle);
        _Batter = StationEntity.As_Batter();
        _Intents = FCk_Handle_InputIntents();

        auto Station = StationEntity.As_Station();
        auto Operator = Station.Get_Operator();
        _Intents = Operator.As_InputIntents(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Intents))
        { return; }

        _SeenPrimaryFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Primary);
    }

    // Must return Running every frame: a Succeeded/Failed result would end the task while Operated is still active.
    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Batter) || ck::Is_NOT_Valid(_Intents))
        { return ECk_SmTaskResult::Running; }

        const auto PrimaryFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Primary);
        if (PrimaryFrame == _SeenPrimaryFrame)
        { return ECk_SmTaskResult::Running; }

        // A new activation frame while one was already seen is a release and a press between two ticks: both are sent (the
        // kernel drains Lift before Dip).
        if (_SeenPrimaryFrame.IsSet())
        { _Batter.Request_Lift(FMars_Request_Batter_Lift()); }

        if (PrimaryFrame.IsSet())
        { _Batter.Request_Dip(FMars_Request_Batter_Dip()); }

        _SeenPrimaryFrame = PrimaryFrame;
        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Batter = FCk_Handle_Batter();
        _Intents = FCk_Handle_InputIntents();
        _SeenPrimaryFrame.Reset();
    }
}

// Leaving lifts the pieces out of the batter: their coats and the batch stay for the next operator.
class UMars_SmTask_Batter_LiftOnExit : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Batter = ck::Ctx(InHandle).As_Batter(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Batter))
        { return; }

        Batter.Request_Lift(FMars_Request_Batter_Lift());
    }
}

// The shared add-food input, gated by the bowl: it can load only with room in it and nothing in flight. A gated press is the
// feed's StationGate refusal (the label says why); nothing is queued. Which pieces the bowl takes (whole, batterable, not
// battered yet) is the kernel's admission: one it refuses goes back to the raw platter.
class UMars_SmTask_BatterFeed_OperatorInput : UMars_SmTask_StationFeed_OperatorInput
{
    private FCk_Handle_Batter _Batter;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Super::DoEnterTask(InHandle, InNetContext);
        _Batter = ck::Ctx(InHandle).As_Batter();
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Super::DoExitTask(InHandle, InNetContext);
        _Batter = FCk_Handle_Batter();
    }

    protected bool Get_CanBeginTransfer() const override
    {
        return ck::IsValid(_Batter) && _Batter.Get_CanLoad();
    }
}

// The operator's dip row while operating, under owner key k_OwnerKey (IA_Interact_Primary), re-texted on every bowl edge:
// "hold to dip" while resting, "release to lift" while dipped. Registered once on enter (the display drains registers before
// unregisters, so the row is re-texted, never re-registered). The batch's coats are the station's world label, not a row.
// An operator without a display (headless) gets no rows.
class UMars_SmTask_Batter_OperatorHints : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private const FName k_OwnerKey = n"Batter";
    private const int32 k_PrimarySortOrder = 8;

    private FCk_Handle_Batter _Batter;
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

        _Batter = StationEntity.As_Batter();
        _PrimaryRow = _Display.Request_RegisterHint(
            FMars_ActionHint_Spec(mars::Mars_IA_Interact_Primary, Get_PrimaryText(_Batter.Get_Bowl()), k_PrimarySortOrder, k_OwnerKey));
        _Batter.BindTo_OnBowlChanged(FMars_Delegate_Batter_OnBowlChanged(this, n"OnBowlChanged"));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Batter))
        { _Batter.UnbindFrom_OnBowlChanged(FMars_Delegate_Batter_OnBowlChanged(this, n"OnBowlChanged")); }

        if (ck::IsValid(_Display))
        { _Display.Request_UnregisterHintsByOwner(FMars_Request_ActionHintDisplay_UnregisterByOwner(k_OwnerKey)); }

        _Batter = FCk_Handle_Batter();
        _Display = FCk_Handle_ActionHintDisplay();
        _PrimaryRow = FCk_Handle_ActionHintRow();
    }

    UFUNCTION()
    private void OnBowlChanged(FCk_Handle_Batter InBatter, EMars_Batter_Bowl InBowl)
    {
        if (ck::Is_NOT_Valid(_Display) || ck::Is_NOT_Valid(_PrimaryRow))
        { return; }

        _Display.Request_UpdateHint(FMars_Request_ActionHintDisplay_Update(_PrimaryRow, Get_PrimaryText(InBowl)));
    }

    private FText Get_PrimaryText(EMars_Batter_Bowl InBowl) const
    {
        if (InBowl == EMars_Batter_Bowl::Dipped)
        { return FText::FromString("release to lift"); }

        return FText::FromString("hold to dip in the batter");
    }
}
