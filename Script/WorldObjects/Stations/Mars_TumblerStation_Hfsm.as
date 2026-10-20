// The tumbler station's control layer: its own state machine (FMars_Station_Spec.MinigameStateClass =
// UMars_SmState_Tumbler_Idle). It runs on the STATION entity (context = the station, which also carries the Tumbler feature
// and the raw platter's CookingFeed; its two platter docks are lifetime children of it) and reads the station's operator;
// it only issues Tumbler and CookingFeed requests and registers the operator's legend rows. The feed tasks are the shared
// ones (Mars_StationFeed_SmTasks.as).
//
//   Idle      ->Operated [StationIsOperated]      tasks: StationFeed_Source, StationFeed_Bridge (a release in flight lands; no
//                                                 reset: the batch, its coverage and the feed's attempt persist across a
//                                                 leave and a re-enter)
//   Operated  ->Idle     [StationIsNotOperated]   tasks: Tumbler_OperatorInput (Tick), Tumbler_CancelOnExit,
//                                                 StationFeed_Source, TumblerFeed_OperatorInput (Tick), StationFeed_Bridge,
//                                                 StationFeed_OperatorHints, Tumbler_OperatorHints, StationFeed_TakeOutInput
//                                                 (Tick)
//
// A piece the drum hands back lands on the finished tray through the kernel's own landing, whoever operates. The
// conditions are the shared station ones (Mars_Station_SmConditions.as). The player's Operating state owns the pose, the
// camera (Captured: the view stays still, the look delta is ours), the glove grips and the Leave intent.

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
        AddTask(InHandle, UMars_SmTask_Tumbler_CancelOnExit);
        AddTask(InHandle, UMars_SmTask_StationFeed_Source);
        AddTask(InHandle, UMars_SmTask_TumblerFeed_OperatorInput);
        AddTask(InHandle, UMars_SmTask_StationFeed_Bridge);
        AddTask(InHandle, UMars_SmTask_StationFeed_OperatorHints);
        AddTask(InHandle, UMars_SmTask_Tumbler_OperatorHints);
        AddTask(InHandle, UMars_SmTask_StationFeed_TakeOutInput);
    }
}

// The operator's input: one look per drained look delta (degrees; X yaw right+, Y pitch down+), which moves the free hand
// or rocks the gripped lever; Interact_Use going down is a press and coming up a release. A release and a press between
// two polls send both (the kernel drains Release before Press).
class UMars_SmTask_Tumbler_OperatorInput : UMars_SmTask_StationOperatorInput
{
    private FCk_Handle_Tumbler _Tumbler;
    private FMars_LookCursor _Look;
    private FMars_IntentEdge _Use;

    protected void Bind(FCk_Handle InStation) override
    {
        _Tumbler = InStation.As_Tumbler();
    }

    protected void Seed() override
    {
        _Look.Seed(_Intents);
        _Use.Seed(_Intents, GameplayTags::Mars_Intent_Interact_Use);
    }

    protected void Poll() override
    {
        if (ck::Is_NOT_Valid(_Tumbler))
        { return; }

        if (_Look.Advance(_Intents))
        { _Tumbler.Request_Look(FMars_Request_Tumbler_Look(_Intents.Get_LookDelta())); }

        const auto Edge = _Use.Advance(_Intents, GameplayTags::Mars_Intent_Interact_Use);
        if (utils_station::Get_HasRelease(Edge))
        { _Tumbler.Request_Release(FMars_Request_Tumbler_Release()); }

        if (utils_station::Get_HasPress(Edge))
        { _Tumbler.Request_Press(FMars_Request_Tumbler_Press()); }
    }

    protected void Unbind() override
    {
        _Tumbler = FCk_Handle_Tumbler();
        _Look = FMars_LookCursor();
        _Use = FMars_IntentEdge();
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

// The shared add-food input, gated by the tumbler's load refusal (room in the drum, the hatch Open, the drum Home, nothing
// in flight). A gated press is the feed's StationGate refusal (the label says why); nothing is queued.
class UMars_SmTask_TumblerFeed_OperatorInput : UMars_SmTask_StationFeed_OperatorInput
{
    private FCk_Handle_Tumbler _Tumbler;

    protected void Bind(FCk_Handle InStation) override
    {
        Super::Bind(InStation);
        _Tumbler = InStation.As_Tumbler();
    }

    protected void Unbind() override
    {
        Super::Unbind();
        _Tumbler = FCk_Handle_Tumbler();
    }

    protected bool Get_CanBeginTransfer() const override
    {
        return ck::IsValid(_Tumbler) && _Tumbler.TryGet_LoadRefusal().IsSet() == false;
    }
}

// The operator's legend rows while operating: "move the hand" (IA_Look) and one Use row (IA_Interact_Use) re-texted on
// every hover, hand, hatch and drum edge with what a press does now: open or close the hovered hatch, grip the hovered
// lever, let go of it, or wait for the drum to come home. The batch's state is the station's world label, not a row.
class UMars_SmTask_Tumbler_OperatorHints : UMars_SmTask_StationOperatorHints
{
    private const int32 k_LookSortOrder = 7;
    private const int32 k_UseSortOrder = 8;

    private FCk_Handle_Tumbler _Tumbler;
    private FCk_Handle_ActionHintRow _UseRow;

    protected FName Get_OwnerKey() const override
    {
        return n"Tumbler";
    }

    protected void Register_Rows() override
    {
        _Tumbler = _Station.As_Tumbler();
        Show_Row(FCk_Handle_ActionHintRow(), Make_Row(mars::Mars_IA_Look, "move the hand", k_LookSortOrder));
        _UseRow = Show_Row(_UseRow, Make_Row(mars::Mars_IA_Interact_Use, Get_UseText(), k_UseSortOrder));
        _Tumbler.BindTo_OnHoverChanged(FMars_Delegate_Tumbler_OnHoverChanged(this, n"OnHoverChanged"));
        _Tumbler.BindTo_OnHandModeChanged(FMars_Delegate_Tumbler_OnHandModeChanged(this, n"OnHandModeChanged"));
        _Tumbler.BindTo_OnHatchChanged(FMars_Delegate_Tumbler_OnHatchChanged(this, n"OnHatchChanged"));
        _Tumbler.BindTo_OnDrumChanged(FMars_Delegate_Tumbler_OnDrumChanged(this, n"OnDrumChanged"));
    }

    protected void Unregister_Rows() override
    {
        if (ck::IsValid(_Tumbler))
        {
            _Tumbler.UnbindFrom_OnHoverChanged(FMars_Delegate_Tumbler_OnHoverChanged(this, n"OnHoverChanged"));
            _Tumbler.UnbindFrom_OnHandModeChanged(FMars_Delegate_Tumbler_OnHandModeChanged(this, n"OnHandModeChanged"));
            _Tumbler.UnbindFrom_OnHatchChanged(FMars_Delegate_Tumbler_OnHatchChanged(this, n"OnHatchChanged"));
            _Tumbler.UnbindFrom_OnDrumChanged(FMars_Delegate_Tumbler_OnDrumChanged(this, n"OnDrumChanged"));
        }

        _Tumbler = FCk_Handle_Tumbler();
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
        if (ck::IsValid(_Tumbler))
        { Retext_Row(_UseRow, Get_UseText()); }
    }

    // What a press does now, read from the kernel (its signals broadcast after the whole tick applied). A regrip while the
    // drum returns is allowed, so the lever row does not wait for home; the hatch does.
    private FString Get_UseText() const
    {
        if (_Tumbler.Get_HandMode() != EMars_Tumbler_HandMode::Free)
        { return "release to let go"; }

        const auto Hovered = _Tumbler.Get_Hovered();
        if (Hovered == EMars_Tumbler_Target::Lever)
        { return "hold to grip the lever"; }

        if (_Tumbler.Get_Drum() != EMars_Tumbler_Drum::Home)
        { return "wait for home"; }

        if (Hovered == EMars_Tumbler_Target::Hatch)
        {
            const auto Hatch = _Tumbler.Get_Hatch();
            const auto IsOpenOrOpening = Hatch == EMars_Tumbler_Hatch::Open || Hatch == EMars_Tumbler_Hatch::Opening;
            return IsOpenOrOpening ? "close the hatch" : "open the hatch";
        }

        return "point at the hatch or the lever";
    }
}
