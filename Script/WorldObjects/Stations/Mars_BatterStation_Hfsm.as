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

// The operator's input: Interact_Primary going down dips the bowl's pieces and coming up lifts them (Interact_Secondary is
// StationFeed_TakeOutInput's). A release and a press between two polls send both (the kernel drains Lift before Dip).
class UMars_SmTask_Batter_OperatorInput : UMars_SmTask_StationOperatorInput
{
    private FCk_Handle_Batter _Batter;
    private FMars_IntentEdge _Primary;

    protected void Bind(FCk_Handle InStation) override
    {
        _Batter = InStation.As_Batter();
    }

    protected void Seed() override
    {
        _Primary.Seed(_Intents, GameplayTags::Mars_Intent_Interact_Primary);
    }

    protected void Poll() override
    {
        if (ck::Is_NOT_Valid(_Batter))
        { return; }

        const auto Edge = _Primary.Advance(_Intents, GameplayTags::Mars_Intent_Interact_Primary);
        if (utils_station::Get_HasRelease(Edge))
        { _Batter.Request_Lift(FMars_Request_Batter_Lift()); }

        if (utils_station::Get_HasPress(Edge))
        { _Batter.Request_Dip(FMars_Request_Batter_Dip()); }
    }

    protected void Unbind() override
    {
        _Batter = FCk_Handle_Batter();
        _Primary = FMars_IntentEdge();
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

// The shared add-food input, gated by the bowl's load refusal (room in it, nothing in flight). A gated press is the feed's StationGate refusal (the label says why);
// nothing is queued. Which pieces the bowl takes (whole, batterable, not battered yet) is the kernel's admission: one it
// refuses goes back to the raw platter.
class UMars_SmTask_BatterFeed_OperatorInput : UMars_SmTask_StationFeed_OperatorInput
{
    private FCk_Handle_Batter _Batter;

    protected void Bind(FCk_Handle InStation) override
    {
        Super::Bind(InStation);
        _Batter = InStation.As_Batter();
    }

    protected void Unbind() override
    {
        Super::Unbind();
        _Batter = FCk_Handle_Batter();
    }

    protected bool Get_CanBeginTransfer() const override
    {
        return ck::IsValid(_Batter) && _Batter.TryGet_LoadRefusal().IsSet() == false;
    }
}

// The operator's dip row while operating (IA_Interact_Primary), re-texted on every bowl edge: "hold to dip" while resting,
// "release to lift" while dipped. The batch's coats are the station's world label, not a row.
class UMars_SmTask_Batter_OperatorHints : UMars_SmTask_StationOperatorHints
{
    private const int32 k_PrimarySortOrder = 8;

    private FCk_Handle_Batter _Batter;
    private FCk_Handle_ActionHintRow _PrimaryRow;

    protected FName Get_OwnerKey() const override
    {
        return n"Batter";
    }

    protected void Register_Rows() override
    {
        _Batter = _Station.As_Batter();
        _PrimaryRow = Show_Row(_PrimaryRow, Make_Row(mars::Mars_IA_Interact_Primary, Get_PrimaryText(_Batter.Get_Bowl()), k_PrimarySortOrder));
        _Batter.BindTo_OnBowlChanged(FMars_Delegate_Batter_OnBowlChanged(this, n"OnBowlChanged"));
    }

    protected void Unregister_Rows() override
    {
        if (ck::IsValid(_Batter))
        { _Batter.UnbindFrom_OnBowlChanged(FMars_Delegate_Batter_OnBowlChanged(this, n"OnBowlChanged")); }

        _Batter = FCk_Handle_Batter();
        _PrimaryRow = FCk_Handle_ActionHintRow();
    }

    UFUNCTION()
    private void OnBowlChanged(FCk_Handle_Batter InBatter, EMars_Batter_Bowl InBowl)
    {
        Retext_Row(_PrimaryRow, Get_PrimaryText(InBowl));
    }

    private FString Get_PrimaryText(EMars_Batter_Bowl InBowl) const
    {
        if (InBowl == EMars_Batter_Bowl::Dipped)
        { return "release to lift"; }

        return "hold to dip in the batter";
    }
}
