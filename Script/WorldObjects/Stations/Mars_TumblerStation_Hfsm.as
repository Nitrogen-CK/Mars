// The tumbler station's control layer: its own state machine (FMars_Station_Spec.MinigameStateClass =
// UMars_SmState_Tumbler_Idle). It runs on the STATION entity (context = the station, which also carries the Tumbler feature
// and the platter's CookingFeed) and reads the station's operator; it only issues Tumbler and CookingFeed requests and
// registers the operator's legend rows. The feed tasks are the shared ones (Mars_StationFeed_SmTasks.as).
//
//   Idle      ->Operated [StationIsOperated]      tasks: StationFeed_Source, StationFeed_Bridge (a release in flight lands; no
//                                                 reset: the batch, its coverage and the feed's attempt persist across a
//                                                 leave and a re-enter)
//   Operated  ->Idle     [StationIsNotOperated]   tasks: Tumbler_OperatorInput (Tick), Tumbler_FeedGate, Tumbler_CancelOnExit,
//                                                 StationFeed_Source, TumblerFeed_OperatorInput (Tick), StationFeed_Bridge,
//                                                 StationFeed_OperatorHints, Tumbler_OperatorHints
//
// The conditions are the shared station ones (Mars_Station_SmConditions.as). The player's Operating state owns the pose,
// the camera (Captured: the view stays still, the look delta is ours), the glove grips and the Leave intent.

class UMars_SmState_Tumbler_Idle : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToOperated = AddTransition(InHandle, UMars_SmState_Tumbler_Operated);
        AddCondition(ToOperated, UMars_SmCondition_StationIsOperated);

        AddTask(InHandle, UMars_SmTask_StationFeed_Source);
        AddTask(InHandle, UMars_SmTask_StationFeed_Bridge);
    }
}

class UMars_SmState_Tumbler_Operated : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToIdle = AddTransition(InHandle, UMars_SmState_Tumbler_Idle);
        AddCondition(ToIdle, UMars_SmCondition_StationIsNotOperated);

        AddTask(InHandle, UMars_SmTask_Tumbler_OperatorInput);
        AddTask(InHandle, UMars_SmTask_Tumbler_FeedGate);
        AddTask(InHandle, UMars_SmTask_Tumbler_CancelOnExit);
        AddTask(InHandle, UMars_SmTask_StationFeed_Source);
        AddTask(InHandle, UMars_SmTask_TumblerFeed_OperatorInput);
        AddTask(InHandle, UMars_SmTask_StationFeed_Bridge);
        AddTask(InHandle, UMars_SmTask_StationFeed_OperatorHints);
        AddTask(InHandle, UMars_SmTask_Tumbler_OperatorHints);
    }
}

// The operator's input, read off its InputIntents: one look per drained look delta (degrees; X yaw right+, Y pitch down+),
// which moves the free hand or rocks the gripped lever; Interact_Use going down is a press and coming up a release. Both
// are seeded on enter, so a delta or a hold from before the station was taken never counts. No operator intents
// (headless) = nothing to read.
class UMars_SmTask_Tumbler_OperatorInput : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle_Tumbler _Tumbler;
    private FCk_Handle_InputIntents _Intents;
    private int32 _SeenLookSequence = 0;
    // The activation frame of the Interact_Use hold last seen; unset while it is not held.
    private TOptional<int32> _SeenUseFrame;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto StationEntity = ck::Ctx(InHandle);
        _Tumbler = StationEntity.As_Tumbler();
        _Intents = FCk_Handle_InputIntents();

        auto Station = StationEntity.As_Station();
        auto Operator = Station.Get_Operator();
        _Intents = Operator.As_InputIntents(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Intents))
        { return; }

        _SeenLookSequence = _Intents.Get_LookDeltaSequence();
        _SeenUseFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Use);
    }

    // Must return Running every frame: a Succeeded/Failed result would end the task while Operated is still active.
    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Tumbler) || ck::Is_NOT_Valid(_Intents))
        { return ECk_SmTaskResult::Running; }

        const auto Sequence = _Intents.Get_LookDeltaSequence();
        if (Sequence != _SeenLookSequence)
        {
            _SeenLookSequence = Sequence;
            _Tumbler.Request_Look(FMars_Request_Tumbler_Look(_Intents.Get_LookDelta()));
        }

        const auto UseFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Use);
        if (UseFrame == _SeenUseFrame)
        { return ECk_SmTaskResult::Running; }

        // A new activation frame while one was already seen is a release and a press between two ticks: both are sent (the
        // kernel drains Release before Press).
        if (_SeenUseFrame.IsSet())
        { _Tumbler.Request_Release(FMars_Request_Tumbler_Release()); }

        if (UseFrame.IsSet())
        { _Tumbler.Request_Press(FMars_Request_Tumbler_Press()); }

        _SeenUseFrame = UseFrame;
        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Tumbler = FCk_Handle_Tumbler();
        _Intents = FCk_Handle_InputIntents();
        _SeenLookSequence = 0;
        _SeenUseFrame.Reset();
    }
}

// Forwards the feed's busy edges to the kernel (InFlight from BeginTransfer until the glove is back, Idle otherwise): the
// hatch never shuts on a piece in flight and the lever is never gripped mid-transfer. Seeded on enter; exit sends Idle (the
// bridge cancels a transfer in flight on the same exit). A station without a feed has nothing to forward.
class UMars_SmTask_Tumbler_FeedGate : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle_Tumbler _Tumbler;
    private FCk_Handle_CookingFeed _Feed;
    private EMars_Tumbler_Loading _SentLoading = EMars_Tumbler_Loading::Idle;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto StationEntity = ck::Ctx(InHandle);
        _Tumbler = StationEntity.As_Tumbler();
        _Feed = StationEntity.As_CookingFeed(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Feed))
        { return; }

        _Feed.BindTo_OnPhaseChanged(FMars_Delegate_CookingFeed_OnPhaseChanged(this, n"OnPhaseChanged"));
        Send(_Feed.Get_IsBusy() ? EMars_Tumbler_Loading::InFlight : EMars_Tumbler_Loading::Idle);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Feed))
        { _Feed.UnbindFrom_OnPhaseChanged(FMars_Delegate_CookingFeed_OnPhaseChanged(this, n"OnPhaseChanged")); }

        if (ck::IsValid(_Tumbler))
        { _Tumbler.Request_SetLoading(FMars_Request_Tumbler_SetLoading(EMars_Tumbler_Loading::Idle)); }

        _Tumbler = FCk_Handle_Tumbler();
        _Feed = FCk_Handle_CookingFeed();
        _SentLoading = EMars_Tumbler_Loading::Idle;
    }

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_CookingFeed InFeed, EMars_CookingFeed_Phase InPhase)
    {
        const auto Loading = InPhase == EMars_CookingFeed_Phase::Idle ? EMars_Tumbler_Loading::Idle : EMars_Tumbler_Loading::InFlight;
        if (Loading == _SentLoading)
        { return; }

        Send(Loading);
    }

    private void Send(EMars_Tumbler_Loading InLoading)
    {
        if (ck::Is_NOT_Valid(_Tumbler))
        { return; }

        _Tumbler.Request_SetLoading(FMars_Request_Tumbler_SetLoading(InLoading));
        _SentLoading = InLoading;
    }
}

// Leaving lets go: a grip ends (the drum returns home) or a reach stops, and the hand is Free. The pieces and their
// coverage stay for the next operator.
class UMars_SmTask_Tumbler_CancelOnExit : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Tumbler = ck::Ctx(InHandle).As_Tumbler(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Tumbler))
        { return; }

        Tumbler.Request_Cancel(FMars_Request_Tumbler_Cancel());
    }
}

// The shared add-food input, refused by the tumbler unless it can load (the hatch Open, the drum Home, nothing in flight and
// room in the drum): a refused edge is consumed before BeginTransfer, so nothing is queued.
class UMars_SmTask_TumblerFeed_OperatorInput : UMars_SmTask_StationFeed_OperatorInput
{
    private FCk_Handle_Tumbler _Tumbler;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Super::DoEnterTask(InHandle, InNetContext);
        _Tumbler = ck::Ctx(InHandle).As_Tumbler();
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Super::DoExitTask(InHandle, InNetContext);
        _Tumbler = FCk_Handle_Tumbler();
    }

    protected bool Get_CanBeginTransfer() const override
    {
        return ck::IsValid(_Tumbler) && _Tumbler.Get_CanLoad();
    }
}

// The operator's legend rows while operating, under owner key k_OwnerKey: "move the hand" (IA_Look) and one Use row
// (IA_Interact_Use) re-texted on every hover, hand, hatch and drum edge with what a press does now: open or close the
// hovered hatch, grip the hovered lever, let go of it, or wait for the drum to come home. Registered once on enter (the
// display drains registers before unregisters, so the rows are re-texted, never re-registered). The batch's state is the
// station's world label, not a row. An operator without a display (headless) gets no rows.
class UMars_SmTask_Tumbler_OperatorHints : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private const FName k_OwnerKey = n"Tumbler";
    private const int32 k_LookSortOrder = 7;
    private const int32 k_UseSortOrder = 8;

    private FCk_Handle_Tumbler _Tumbler;
    private FCk_Handle_ActionHintDisplay _Display;
    private FCk_Handle_ActionHintRow _UseRow;

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

        _Tumbler = StationEntity.As_Tumbler();
        _Display.Request_RegisterHint(FMars_ActionHint_Spec(mars::Mars_IA_Look, FText::FromString("move the hand"), k_LookSortOrder, k_OwnerKey));
        _UseRow = _Display.Request_RegisterHint(FMars_ActionHint_Spec(mars::Mars_IA_Interact_Use, Get_UseText(), k_UseSortOrder, k_OwnerKey));
        _Tumbler.BindTo_OnHoverChanged(FMars_Delegate_Tumbler_OnHoverChanged(this, n"OnHoverChanged"));
        _Tumbler.BindTo_OnHandModeChanged(FMars_Delegate_Tumbler_OnHandModeChanged(this, n"OnHandModeChanged"));
        _Tumbler.BindTo_OnHatchChanged(FMars_Delegate_Tumbler_OnHatchChanged(this, n"OnHatchChanged"));
        _Tumbler.BindTo_OnDrumChanged(FMars_Delegate_Tumbler_OnDrumChanged(this, n"OnDrumChanged"));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Tumbler))
        {
            _Tumbler.UnbindFrom_OnHoverChanged(FMars_Delegate_Tumbler_OnHoverChanged(this, n"OnHoverChanged"));
            _Tumbler.UnbindFrom_OnHandModeChanged(FMars_Delegate_Tumbler_OnHandModeChanged(this, n"OnHandModeChanged"));
            _Tumbler.UnbindFrom_OnHatchChanged(FMars_Delegate_Tumbler_OnHatchChanged(this, n"OnHatchChanged"));
            _Tumbler.UnbindFrom_OnDrumChanged(FMars_Delegate_Tumbler_OnDrumChanged(this, n"OnDrumChanged"));
        }

        if (ck::IsValid(_Display))
        { _Display.Request_UnregisterHintsByOwner(FMars_Request_ActionHintDisplay_UnregisterByOwner(k_OwnerKey)); }

        _Tumbler = FCk_Handle_Tumbler();
        _Display = FCk_Handle_ActionHintDisplay();
        _UseRow = FCk_Handle_ActionHintRow();
    }

    UFUNCTION()
    private void OnHoverChanged(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_Target InTarget)
    {
        Refresh_UseRow();
    }

    UFUNCTION()
    private void OnHandModeChanged(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_HandMode InHandMode)
    {
        Refresh_UseRow();
    }

    UFUNCTION()
    private void OnHatchChanged(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_Hatch InHatch)
    {
        Refresh_UseRow();
    }

    UFUNCTION()
    private void OnDrumChanged(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_Drum InDrum)
    {
        Refresh_UseRow();
    }

    private void Refresh_UseRow()
    {
        if (ck::Is_NOT_Valid(_Display) || ck::Is_NOT_Valid(_UseRow) || ck::Is_NOT_Valid(_Tumbler))
        { return; }

        _Display.Request_UpdateHint(FMars_Request_ActionHintDisplay_Update(_UseRow, Get_UseText()));
    }

    // What a press does now, read from the kernel (its signals broadcast after the whole tick applied). A regrip while the
    // drum returns is allowed, so the lever row does not wait for home; the hatch does.
    private FText Get_UseText() const
    {
        if (_Tumbler.Get_HandMode() != EMars_Tumbler_HandMode::Free)
        { return FText::FromString("release to let go"); }

        const auto Hovered = _Tumbler.Get_Hovered();
        if (Hovered == EMars_Tumbler_Target::Lever)
        { return FText::FromString("hold to grip the lever"); }

        if (_Tumbler.Get_Drum() != EMars_Tumbler_Drum::Home)
        { return FText::FromString("wait for home"); }

        if (Hovered == EMars_Tumbler_Target::Hatch)
        {
            const auto Hatch = _Tumbler.Get_Hatch();
            const auto IsOpenOrOpening = Hatch == EMars_Tumbler_Hatch::Open || Hatch == EMars_Tumbler_Hatch::Opening;
            return FText::FromString(IsOpenOrOpening ? "close the hatch" : "open the hatch");
        }

        return FText::FromString("point at the hatch or the lever");
    }
}
