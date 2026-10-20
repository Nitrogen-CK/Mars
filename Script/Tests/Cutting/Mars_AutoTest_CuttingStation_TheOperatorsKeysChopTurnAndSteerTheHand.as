// The cutting station's control layer on the operator's own keys. The operator rig's carrier holds Interact_Primary before
// it takes the real cutting station through its Use interaction: once the station's chop row is on the carrier's legend
// (the Operated tasks entered), no chop was started, as a hold from before the take is no press, and the empty board
// shows no turn row. A look to the right then slides the cleaver's hand along the board by the station's centimetres per
// look degree; a fresh Interact_Primary press lands exactly one chop; a Drop press turns the board exactly once, a
// quarter turn. Isolated origin (204000, -82000, -30000).
class UMars_AutoTest_CuttingStation_TheOperatorsKeysChopTurnAndSteerTheHand : UMars_AutoTestRig_HeatOperator
{
    private const FVector k_Origin = FVector(204000.0, -82000.0, -30000.0);
    // Behind the stand, facing the board.
    private const FVector k_CarrierLocal = FVector(-100.0, 0.0, 0.0);
    private const float64 k_LookYawDegrees = 4.0;
    // A poll budget, not a ceiling: the station composes and a chop strikes and recovers over a few frames.
    private const int32 k_SlowPolls = 900;

    private int32 _ChopsLanded = 0;
    private TArray<float32> _Turns;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_HeatOperator(InHandle, EMars_AutoTest_HeatStation::Cutting, k_Origin, k_CarrierLocal);

        Add_Steps_UntilReady();
        Add_Step_WaitUntil("the station composed its Cutting, board, feed and docks", n"Check_HeatStationReady", k_SlowPolls, 0);
        Add_Step("watch the cleaver's chops and the board's turns", n"Step_Watch");
        Add_Step("hold Interact_Primary before taking the station", n"Step_PressPrimary");
        Add_Step_WaitUntil("Interact_Primary is held", n"Check_PrimaryHeld", 0, 0);
        Add_Steps_TakeTheStationThroughUse();
        Add_Step_WaitUntil("the station is Operated and the chop row is on the legend", n"Check_OperatedWithTheChopRow", 0, 0);
        Add_Step("the hold from before the take started no chop", n"Step_AssertNoChop");
        Add_Step("release Interact_Primary and look to the right", n"Step_ReleaseAndLook");
        Add_Step_WaitUntil("the hand slid along the board", n"Check_HandMoved", k_SlowPolls, 0);
        Add_Step("the hand slid by the look's yaw at the station's rate", n"Step_AssertHand");
        Add_Step("press Interact_Primary", n"Step_PressPrimary");
        Add_Step_WaitUntil("one chop landed and the cleaver is idle again", n"Check_ChopLanded", k_SlowPolls, 0);
        Add_Step("release Interact_Primary and press Drop", n"Step_ReleaseAndPressDrop");
        Add_Step_WaitUntil("the board turned", n"Check_Turned", k_SlowPolls, 0);
        Add_Step("release Drop", n"Step_ReleaseDrop");
        Add_Step("one chop, one quarter turn", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Watch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Cutting.BindTo_OnChopLanded(FMars_Delegate_Cutting_OnChopLanded(this, n"OnChopLanded"));
        _Board.BindTo_OnTurned(FMars_Delegate_FoodBoard_OnTurned(this, n"OnTurned"));
    }

    UFUNCTION()
    private void Step_PressPrimary(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Press_Row(GameplayTags::Mars_Intent_Interact_Primary);
    }

    UFUNCTION()
    private void Check_PrimaryHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsRowHeld(GameplayTags::Mars_Intent_Interact_Primary));
    }

    UFUNCTION()
    private void Check_OperatedWithTheChopRow(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsStationOperated() && Get_HasHint("chop") && Get_HasHint("move hand"));
    }

    UFUNCTION()
    private void Step_AssertNoChop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsRowHeld(GameplayTags::Mars_Intent_Interact_Primary), "Interact_Primary is still held");
        Assert_False(_Cutting.Get_IsChopping(), "no chop started");
        Assert_Equals_Int(_ChopsLanded, 0, "no chop landed");
        Assert_False(Get_HasHint("turn"), "the empty board shows no turn row");
        Assert_True(Math::Abs(_Cutting.Get_HandLateral()) < 0.0001f, "the hand is at the board's centre");
    }

    UFUNCTION()
    private void Step_ReleaseAndLook(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Release_Row(GameplayTags::Mars_Intent_Interact_Primary);
        Add_LookDelta(FVector(k_LookYawDegrees, 0.0, 0.0));
    }

    UFUNCTION()
    private void Check_HandMoved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::Abs(_Cutting.Get_HandLateral()) > 0.0001f && Get_IsRowHeld(GameplayTags::Mars_Intent_Interact_Primary) == false);
    }

    UFUNCTION()
    private void Step_AssertHand(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Expected = Math::Min(float32(k_LookYawDegrees) * utils_cutting::k_LateralCmPerLookDegree, _Cutting.Get_Spec().BoardHalfWidth);
        const auto Lateral = _Cutting.Get_HandLateral();
        Assert_True(Math::Abs(Lateral - Expected) < 0.001f, f"the hand slid {Lateral} cm (expected {Expected})");
        Assert_Equals_Int(_ChopsLanded, 0, "the release started no chop");
    }

    UFUNCTION()
    private void Check_ChopLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ChopsLanded == 1 && _Cutting.Get_IsChopping() == false);
    }

    UFUNCTION()
    private void Step_ReleaseAndPressDrop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Release_Row(GameplayTags::Mars_Intent_Interact_Primary);
        Press_Row(GameplayTags::Mars_Intent_Drop);
    }

    UFUNCTION()
    private void Check_Turned(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Turns.Num() >= 1);
    }

    UFUNCTION()
    private void Step_ReleaseDrop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Release_Row(GameplayTags::Mars_Intent_Drop);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_ChopsLanded, 1, "one press landed one chop");
        Assert_Equals_Int(_Turns.Num(), 1, "one Drop press turned the board once");
        Assert_True(_Turns.Num() == 1 && Math::Abs(_Turns[0] - utils_cutting::k_TurnDegrees) < 0.001f, "the turn is a quarter turn");
        Assert_True(_Station.Get_IsOperatedBy(_Carrier), "the carrier still operates the station");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnChopLanded(FCk_Handle_Cutting InCutting)
    {
        _ChopsLanded += 1;
    }

    UFUNCTION()
    private void OnTurned(FCk_Handle_FoodBoard InBoard, float32 InYawDegrees)
    {
        _Turns.Add(InYawDegrees);
    }
}
