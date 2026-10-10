// An operator feeds the searing pan through its add-food key. A meat platter docks on the real searing station's raw dock
// and an empty one on the finished tray's; the operator rig's carrier takes the station through its Use interaction. Its
// StationAddFood row is then pressed on the carrier's own key stack: the station's add-food reader (seeded on enter, so
// only a fresh press counts) asks the feed for a transfer, the feed's hand carries the slab off the raw platter and the
// pan admits it. The add-food row is the station's feed press; Interact_Primary is the fry's dip and drives nothing here.
// Isolated origin (172000, -70000, -30000).
class UMars_AutoTest_SearingStation_AnOperatorFeedsThroughTheIntentReader : UMars_AutoTestRig_HeatOperator
{
    private const FVector k_Origin = FVector(172000.0, -70000.0, -30000.0);
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
        Add_Step_WaitUntil("the station composed its Searing, feed and docks", n"Check_HeatStationReady", 0, 0);
        Add_Step_WaitUntil("both platters are constructed and the slab landed on the raw one", n"Check_PlattersReady", k_SlowPolls, 0);
        Add_Step("dock the meat platter as raw and the empty one as the tray", n"Step_Dock");
        Add_Step_WaitUntil("both platters are docked and arrived", n"Check_Docked", k_SlowPolls, 0);
        Add_Steps_TakeTheStationThroughUse();
        Add_Step_WaitUntil("the station's state machine is Operated and the feed draws from the raw platter", n"Check_OperatedAndSourced", 0, 0);
        Add_Step("press the add-food key", n"Step_PressAddFood");
        Add_Step_WaitUntil("the add-food row is held", n"Check_AddFoodHeld", 0, 0);
        Add_Step_WaitUntil("the pan admitted the slab and the raw platter is empty", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step("release the add-food key", n"Step_ReleaseAddFood");
        Add_Step("the press carried the slab into the pan", n"Step_AssertAdmitted");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_PlattersReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsPlatterReady(_Raw, 1) && Get_IsPlatterReady(_Tray, 0));
    }

    UFUNCTION()
    private void Step_Dock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Track_Held(_Raw);
        _Slab = _Raw.As_Platter().Get_Held()[0];
        Dock(_InputDock, _Raw);
        Dock(_OutputDock, _Tray);
    }

    UFUNCTION()
    private void Check_Docked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsDocked(_InputDock, _Raw) && Get_IsDocked(_OutputDock, _Tray));
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
        Assert_True(Get_PieceIds().Num() == 0 && _Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, "nothing was fed before the press");
        Press_Row(GameplayTags::Mars_Intent_StationAddFood);
    }

    UFUNCTION()
    private void Check_AddFoodHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsRowHeld(GameplayTags::Mars_Intent_StationAddFood));
    }

    UFUNCTION()
    private void Check_Admitted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PieceIds().Num() == 1 && _Raw.As_Platter().Get_Occupancy() == 0);
    }

    UFUNCTION()
    private void Step_ReleaseAddFood(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Release_Row(GameplayTags::Mars_Intent_StationAddFood);
    }

    UFUNCTION()
    private void Step_AssertAdmitted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto PieceIds = Get_PieceIds();
        Assert_True(PieceIds.Num() == 1 && _Searing.Get_PieceHandle(PieceIds[0]) == _Slab, "the pan holds the slab from the raw platter");
        Assert_Equals_Int(Get_SettleCount(EMars_CookingFeed_Settle::Admitted), 1, "the feed settled one transfer, admitted");
        Assert_Equals_Int(_Feed.Get_Admitted(), 1, "the feed counts one admission");
        Assert_True(_Station.Get_IsOperatedBy(_Carrier), "the carrier still operates the station");
    }
}

class AMars_AutoTest_SearingStation_AnOperatorFeedsThroughTheIntentReader_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 60.0f;
    default _TestEntityScriptClass = UMars_AutoTest_SearingStation_AnOperatorFeedsThroughTheIntentReader;
}
