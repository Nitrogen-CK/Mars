// The searing station's control layer: its own state machine (FMars_Station_Spec.MinigameStateClass =
// UMars_SmState_Searing_Idle). It runs on the STATION entity (context = the station, which also carries the Searing
// feature and the raw platter's CookingFeed; its two platter docks are lifetime children of it) and reads the station's
// operator; it only issues Searing, CookingFeed and Platter requests and registers the operator's legend rows. The feed
// tasks are the shared ones (Mars_StationFeed_SmTasks.as).
//
//   Idle      ->Operated [StationIsOperated]      tasks: StationFeed_Source,
//                                                 StationFeed_Bridge (a release in flight lands: a transfer past its
//                                                 grasp is committed, the feed's own rule),
//                                                 Searing_ResetOnEnter (a level, cold pan; the pieces stay on it)
//   Operated  ->Idle     [StationIsNotOperated]   tasks: Searing_HeatOnEnter, Searing_OperatorInput (Tick), Searing_OperatorHints,
//                                                 StationFeed_Source, StationFeed_OperatorInput (Tick), StationFeed_Bridge,
//                                                 StationFeed_OperatorHints, StationFeed_TakeOutInput (Tick)
//
// A piece the pan hands back lands on the finished tray through the station's assembly (UMars_FeedStation_EntityScript),
// whoever operates.
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

        AddTask(InHandle, UMars_SmTask_StationFeed_Source);
        AddTask(InHandle, UMars_SmTask_StationFeed_Bridge);
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
        AddTask(InHandle, UMars_SmTask_StationFeed_Source);
        AddTask(InHandle, UMars_SmTask_StationFeed_OperatorInput);
        AddTask(InHandle, UMars_SmTask_StationFeed_Bridge);
        AddTask(InHandle, UMars_SmTask_StationFeed_OperatorHints);
        AddTask(InHandle, UMars_SmTask_StationFeed_TakeOutInput);
    }
}

// Levels and idles the pan and chills it; the pieces stay on it with their sear (the player's food is theirs). The feed is
// not reset with it: a transfer the last operator committed lands, and only a new source starts a new attempt. No Searing
// on the context (a composition that failed and already ensured) = nothing to reset.
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

// The operator's input: one look per drained look delta (degrees; X yaw right+, Y pitch down+), which tilts the pan and,
// fast and upward, tosses it.
class UMars_SmTask_Searing_OperatorInput : UMars_SmTask_StationOperatorInput
{
    private FCk_Handle_Searing _Searing;
    private FMars_LookCursor _Look;

    protected void Bind(FCk_Handle InStation) override
    {
        _Searing = InStation.As_Searing();
    }

    protected void Seed() override
    {
        _Look.Seed(_Intents);
    }

    protected void Poll() override
    {
        if (ck::IsValid(_Searing) && _Look.Advance(_Intents))
        { _Searing.Request_Look(FMars_Request_Searing_Look(_Intents.Get_LookDelta())); }
    }

    protected void Unbind() override
    {
        _Searing = FCk_Handle_Searing();
        _Look = FMars_LookCursor();
    }
}

// The operator's legend row while operating: "tilt the pan, flick up to toss" (IA_Look). The pieces' state is the
// station's world label, not a row.
class UMars_SmTask_Searing_OperatorHints : UMars_SmTask_StationOperatorHints
{
    private const int32 k_TiltSortOrder = 7;

    protected FName Get_OwnerKey() const override
    {
        return n"Searing";
    }

    protected void Register_Rows() override
    {
        Show_Row(FCk_Handle_ActionHintRow(), Make_Row(mars::Mars_IA_Look, "tilt the pan, flick up to toss", k_TiltSortOrder));
    }
}
