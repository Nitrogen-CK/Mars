// The fry station's control layer: its own state machine (FMars_Station_Spec.MinigameStateClass = UMars_SmState_Fry_Idle).
// It runs on the STATION entity (context = the station, which also carries the Fry feature and the raw platter's
// CookingFeed; its two platter docks are lifetime children of it) and reads the station's operator; it only issues Fry,
// CookingFeed and Platter requests and registers the operator's legend rows.
// The feed tasks are the shared ones (Mars_StationFeed_SmTasks.as).
//
//   Idle      ->Operated [StationIsOperated]      tasks: StationFeed_Source,
//                                                 StationFeed_Bridge (a release in flight lands: a transfer past its
//                                                 grasp is committed, the feed's own rule), Fry_ResetOnEnter
//                                                 (the skimmer parked and idle; the pieces stay in play)
//   Operated  ->Idle     [StationIsNotOperated]   tasks: Fry_DriveOnEnter (the skimmer is in hand), Fry_OperatorInput (Tick),
//                                                 Fry_OperatorHints, StationFeed_Source, FryFeed_OperatorInput (Tick),
//                                                 StationFeed_Bridge, FryFeed_OperatorHints,
//                                                 StationFeed_TakeOutInput (Tick)
//
// The fryer fries only battered pieces (the batter station's take-out writes the dip): the add-food press is gated shut and
// its row reads "batter it first" while the docked raw platter has nothing battered on it, and the kernel refuses an
// unbattered piece that still reaches it (the label says so).
//
// A piece the fryer hands back lands on the finished tray through the station's assembly (UMars_FeedStation_EntityScript),
// whoever operates.
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

        AddTask(InHandle, UMars_SmTask_StationFeed_Source);
        AddTask(InHandle, UMars_SmTask_StationFeed_Bridge);
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
        AddTask(InHandle, UMars_SmTask_StationFeed_Source);
        AddTask(InHandle, UMars_SmTask_FryFeed_OperatorInput);
        AddTask(InHandle, UMars_SmTask_StationFeed_Bridge);
        AddTask(InHandle, UMars_SmTask_FryFeed_OperatorHints);
        AddTask(InHandle, UMars_SmTask_StationFeed_TakeOutInput);
    }
}

// Parks, levels and idles the skimmer and zeroes the tally; the pieces stay where they are with their heat (the player's
// food is theirs). The feed is not reset with it: a transfer the last operator committed lands, and only a new source
// starts a new attempt. No Fry on the context (a composition that failed and already ensured) = nothing to reset.
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

// The operator's input: one look per drained look delta (degrees; X yaw right+, Y pitch down+), which moves the skimmer;
// Interact_Primary going down asks for a dip (the kernel pours instead over the basket, and refuses it in the corridor)
// and coming up carries (Interact_Secondary is StationFeed_TakeOutInput's).
class UMars_SmTask_Fry_OperatorInput : UMars_SmTask_StationOperatorInput
{
    private FCk_Handle_Fry _Fry;
    private FMars_LookCursor _Look;
    private FMars_IntentEdge _Primary;

    protected void Bind(FCk_Handle InStation) override
    {
        _Fry = InStation.As_Fry();
    }

    protected void Seed() override
    {
        _Look.Seed(_Intents);
        _Primary.Seed(_Intents, GameplayTags::Mars_Intent_Interact_Primary);
    }

    protected void Poll() override
    {
        if (ck::Is_NOT_Valid(_Fry))
        { return; }

        if (_Look.Advance(_Intents))
        { _Fry.Request_Look(FMars_Request_Fry_Look(_Intents.Get_LookDelta())); }

        const auto Edge = _Primary.Advance(_Intents, GameplayTags::Mars_Intent_Interact_Primary);
        if (Edge == EMars_IntentEdge::None)
        { return; }

        const auto Skim = utils_station::Get_HasPress(Edge) ? EMars_Fry_Skim::Dip : EMars_Fry_Skim::Carry;
        _Fry.Request_Skim(FMars_Request_Fry_Skim(Skim));
    }

    protected void Unbind() override
    {
        _Fry = FCk_Handle_Fry();
        _Look = FMars_LookCursor();
        _Primary = FMars_IntentEdge();
    }
}

// The operator's legend rows while operating: "move the skimmer" (IA_Look) and the dip row (IA_Interact_Primary),
// re-texted on every skim edge: "hold to dip - press over the basket to pour" while carrying, "release to lift" while
// dipped, "pouring - release to level" while pouring. The batch's state is the station's world label, not a row.
class UMars_SmTask_Fry_OperatorHints : UMars_SmTask_StationOperatorHints
{
    private const int32 k_LookSortOrder = 7;
    private const int32 k_PrimarySortOrder = 8;

    private FCk_Handle_Fry _Fry;
    private FCk_Handle_ActionHintRow _PrimaryRow;

    protected FName Get_OwnerKey() const override
    {
        return n"Fry";
    }

    protected void Register_Rows() override
    {
        _Fry = _Station.As_Fry();
        Show_Row(FCk_Handle_ActionHintRow(), Make_Row(mars::Mars_IA_Look, "move the skimmer", k_LookSortOrder));
        _PrimaryRow = Show_Row(_PrimaryRow, Make_Row(mars::Mars_IA_Interact_Primary, Get_PrimaryText(_Fry.Get_Skim()), k_PrimarySortOrder));
        _Fry.BindTo_OnSkimChanged(FMars_Delegate_Fry_OnSkimChanged(this, n"OnSkimChanged"));
    }

    protected void Unregister_Rows() override
    {
        if (ck::IsValid(_Fry))
        { _Fry.UnbindFrom_OnSkimChanged(FMars_Delegate_Fry_OnSkimChanged(this, n"OnSkimChanged")); }

        _Fry = FCk_Handle_Fry();
        _PrimaryRow = FCk_Handle_ActionHintRow();
    }

    UFUNCTION()
    private void OnSkimChanged(FCk_Handle_Fry InFry, EMars_Fry_Skim InSkim)
    {
        Retext_Row(_PrimaryRow, Get_PrimaryText(InSkim));
    }

    private FString Get_PrimaryText(EMars_Fry_Skim InSkim) const
    {
        if (InSkim == EMars_Fry_Skim::Dip)
        { return "release to lift"; }

        if (InSkim == EMars_Fry_Skim::Pour)
        { return "pouring - release to level"; }

        return "hold to dip - press over the basket to pour";
    }
}

// The shared add-food input, gated by the fryer: a sourced platter with nothing battered on it has nothing the fryer would
// admit, so the press is the feed's StationGate refusal (the label says why); nothing is queued. An unsourced feed refuses
// on its own.
class UMars_SmTask_FryFeed_OperatorInput : UMars_SmTask_StationFeed_OperatorInput
{
    protected bool Get_CanBeginTransfer() const override
    {
        if (ck::Is_NOT_Valid(_Feed) || _Feed.Get_IsSourced() == false)
        { return true; }

        return utils_batter::Get_HasBatteredPiece(_Feed.Get_Source());
    }
}

// The shared add-food row, reading "batter it first" while the docked raw platter holds pieces but nothing battered (the
// fryer's gate), re-texted on the feed's stock and phase edges (the shared row's own).
class UMars_SmTask_FryFeed_OperatorHints : UMars_SmTask_StationFeed_OperatorHints
{
    protected TOptional<FString> TryGet_StationRefusal() const override
    {
        if (ck::Is_NOT_Valid(_Feed) || _Feed.Get_IsSourced() == false || _Feed.Get_Available() <= 0)
        { return TOptional<FString>(); }

        if (utils_batter::Get_HasBatteredPiece(_Feed.Get_Source()))
        { return TOptional<FString>(); }

        const FString Refusal = "not battered: batter it first";
        return TOptional<FString>(Refusal);
    }
}
