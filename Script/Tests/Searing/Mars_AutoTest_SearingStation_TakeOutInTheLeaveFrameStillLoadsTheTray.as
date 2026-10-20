// A take-out pressed in the frame the operator leaves still lands on the tray. The meat platter docks as raw (its slab's
// ledger seared on all six faces, so the pan admits it Ready) and an empty one as the tray; the operator rig's carrier
// takes the station through its Use interaction and one add-food press puts the slab on the pan. Then, in one step, the
// carrier presses the take-out key and Back: the station's take-out reader sees the press while the station is still
// Operated, the station goes Idle, and the hand-back lands whichever state the station is in by then. The slab rides the
// tray (a scene-node child of its root, Kinematic) and the pan holds nothing. Isolated origin (200000, -82000, -30000).
class UMars_AutoTest_SearingStation_TakeOutInTheLeaveFrameStillLoadsTheTray : UMars_AutoTestRig_HeatOperator
{
    private const FVector k_Origin = FVector(200000.0, -82000.0, -30000.0);
    // Behind the stand, facing the table.
    private const FVector k_CarrierLocal = FVector(-100.0, 0.0, 0.0);
    private const FVector k_RawOffset = FVector(0.0, -300.0, 0.0);
    private const FVector k_TrayOffset = FVector(0.0, 300.0, 0.0);
    // A poll budget, not a ceiling: platters construct and settle, and a transfer carries for seconds.
    private const int32 k_SlowPolls = 900;

    private FCk_Handle _Raw;
    private FCk_Handle _Tray;
    private FCk_Handle_FoodPiece _Slab;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_HeatOperator(InHandle, EMars_AutoTest_HeatStation::Searing, k_Origin, k_CarrierLocal);
        _Raw = Spawn_Platter(InHandle, k_RawOffset, mars_items::Food_MeatSlab());
        _Tray = Spawn_Platter(InHandle, k_TrayOffset, nullptr);

        Add_Steps_UntilReady();
        Add_Step_WaitUntil("the station composed its Searing, feed and docks", n"Check_HeatStationReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("both platters are constructed and the slab landed on the raw one", n"Check_PlattersReady", k_SlowPolls, 0);
        Add_Step("sear the slab's ledger on every face and dock both platters", n"Step_SearAndDock");
        Add_Step_WaitUntil("both platters are docked and arrived and the slab's ledger is seared", n"Check_Docked", k_SlowPolls, 0);
        Add_Steps_TakeTheStationThroughUse();
        Add_Step_WaitUntil("the station's state machine is Operated and the feed draws from the raw platter", n"Check_OperatedAndSourced", 0, 0);
        Add_Step("press the add-food key", n"Step_PressAddFood");
        Add_Step_WaitUntil("the pan admitted the slab and lists it ready to take out", n"Check_AdmittedReady", k_SlowPolls, 0);
        Add_Step("release the add-food key", n"Step_ReleaseAddFood");
        Add_Step_WaitUntil("the add-food key is released and the feed is idle", n"Check_FeedIdle", k_SlowPolls, 0);
        Add_Step("press the take-out key and Back in the same step", n"Step_TakeOutAndLeave");
        Add_Step_WaitUntil("the station is Idle and the slab landed on the tray", n"Check_IdleAndOnTray", k_SlowPolls, 0);
        Add_Step_WaitUntil("the slab rides the tray, a Kinematic scene-node child of its root", n"Check_SlabRidesTheTray", k_SlowPolls, 0);
        Add_Step("release both keys", n"Step_ReleaseKeys");
        Add_Step("the slab rides the tray; the pan holds nothing", n"Step_Assert");
        Run_Steps(InHandle);
    }

    private FCk_Handle_Transform Get_Parent(FCk_Handle_FoodPiece InPiece) const
    {
        FCk_Handle Entity = InPiece;
        auto Node = Entity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return FCk_Handle_Transform(); }

        return utils_scene_node::Get_Parent(Node);
    }

    private bool Get_IsKinematic(FCk_Handle_FoodPiece InPiece) const
    {
        FCk_Handle Entity = InPiece;
        return Entity.Is_JoltBody() && utils_jolt_body::Get_MotionType(Entity.As_JoltBody()) == ECk_MotionType::Kinematic;
    }

    private bool Get_IsLedgerSeared() const
    {
        const auto Sear = _Slab.Get_CookState().Sear;
        if (Sear.Num() != utils_foodpiece::k_FaceCount)
        { return false; }

        for (const auto Face : Sear)
        {
            if (Face < 1.0f)
            { return false; }
        }

        return true;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Check_PlattersReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsPlatterReady(_Raw, 1) && Get_IsPlatterReady(_Tray, 0));
    }

    UFUNCTION()
    private void Step_SearAndDock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Track_Held(_Raw);
        _Slab = _Raw.As_Platter().Get_Held()[0];

        auto CookState = _Slab.Get_CookState();
        CookState.Sear.Empty();
        for (int32 Index = 0; Index < utils_foodpiece::k_FaceCount; ++Index)
        { CookState.Sear.Add(1.0f); }

        _Slab.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(CookState));
        Dock(_InputDock, _Raw);
        Dock(_OutputDock, _Tray);
    }

    UFUNCTION()
    private void Check_Docked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsDocked(_InputDock, _Raw) && Get_IsDocked(_OutputDock, _Tray) && Get_IsLedgerSeared());
    }

    UFUNCTION()
    private void Check_OperatedAndSourced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsStationOperated() && _Feed.Get_Source() == _Raw.As_Platter() && _Feed.Get_Available() == 1);
    }

    UFUNCTION()
    private void Step_PressAddFood(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Press_Row(GameplayTags::Mars_Intent_StationAddFood);
    }

    UFUNCTION()
    private void Check_AdmittedReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        FCk_Handle Station = _Station;
        const auto PieceIds = Get_PieceIds();
        auto Res = OutResult;
        Res.Set(PieceIds.Num() == 1 && _Searing.Get_PieceHandle(PieceIds[0]) == _Slab
            && _Searing.Get_PieceStatus(PieceIds[0]) == EMars_Searing_PieceStatus::Ready
            && utils_cooking_feed::Get_Takeable(Station).Num() == 1);
    }

    UFUNCTION()
    private void Step_ReleaseAddFood(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Release_Row(GameplayTags::Mars_Intent_StationAddFood);
    }

    UFUNCTION()
    private void Check_FeedIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle && Get_IsRowHeld(GameplayTags::Mars_Intent_StationAddFood) == false);
    }

    UFUNCTION()
    private void Step_TakeOutAndLeave(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsStationOperated(), "the station is still Operated when the take-out is pressed");
        Assert_Equals_Int(_TakenOut.Num(), 0, "nothing was taken out before the press");
        Press_Row(GameplayTags::Mars_Intent_Interact_Secondary);
        Press_Row(GameplayTags::Mars_Intent_Back);
    }

    UFUNCTION()
    private void Check_IdleAndOnTray(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsStationIdle() && _Tray.As_Platter().Get_HeldCount() == 1);
    }

    // The tray's freeze parents the slab under its root and asks its body for Kinematic.
    UFUNCTION()
    private void Check_SlabRidesTheTray(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Slab.TryGet_Platter() == _Tray.As_Platter() && Get_Parent(_Slab) == _Tray.As_Transform() && Get_IsKinematic(_Slab));
    }

    UFUNCTION()
    private void Step_ReleaseKeys(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Release_Row(GameplayTags::Mars_Intent_Interact_Secondary);
        Release_Row(GameplayTags::Mars_Intent_Back);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_TakenOut.Num(), 1, "the kernel handed one piece back");
        Assert_True(_TakenOut.Num() == 1 && _TakenOut[0] == _Slab, "the piece handed back is the slab");
        Assert_True(_Slab.TryGet_Platter() == _Tray.As_Platter(), "the slab is on the tray");
        Assert_Equals_Int(Get_PieceIds().Num(), 0, "the pan holds nothing");
        Assert_True(Get_IsStationIdle(), "the station is Idle");
        Assert_False(_Station.Get_IsOperated(), "nobody operates the station");
    }
}

class AMars_AutoTest_SearingStation_TakeOutInTheLeaveFrameStillLoadsTheTray_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 60.0f;
    default _TestEntityScriptClass = UMars_AutoTest_SearingStation_TakeOutInTheLeaveFrameStillLoadsTheTray;
}
