// A take-out hands back only fully coated pieces, and says why it handed back none. With the bowl empty, a take-out onto an
// empty platter is refused Empty. A whole batterable piece is admitted and dipped part way: a take-out with no tray is
// refused NoRoom, one onto the platter is refused CoatIncomplete; the bowl keeps the piece, the platter stays empty, the
// readout lists nothing and the piece's ledger is not battered.
class UMars_AutoTest_Batter_TakeOutBeforeTheCoatIsCompleteIsRefused : UMars_AutoTestRig_Batter
{
    private const float32 k_PartialCoat = 0.3f;

    private FCk_Handle _Tray;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_FoodPieces(1, mars::Food_TestBatterableBox_Mars);
        _Tray = Spawn_Tray(InHandle);

        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("the tray is constructed", n"Check_TrayReady", k_SlowPolls, 0);
        Add_Step("take out of the empty bowl", n"Step_TakeOutOntoTray");
        Add_Step_WaitUntil("it is refused", n"Check_Refused1", 0, 0);
        Add_Step("release the piece", n"Step_Admit");
        Add_Step_WaitUntil("it is in the bowl", n"Check_Answered1", 0, 0);
        Add_Step("dip", n"Step_Dip");
        Add_Step_WaitUntil("the coat is partial", n"Check_PartlyCoated", k_SlowPolls, 0);
        Add_Step("lift", n"Step_Lift");
        Add_Step_WaitUntil("it rose back to rest", n"Check_FirstAtRest", k_SlowPolls, 0);
        Add_Step("take out with no tray, then onto the tray", n"Step_TakeOutBoth");
        Add_Step_WaitUntil("both are refused", n"Check_Refused3", 0, 0);
        Add_Step_WaitFrames("any landing would settle", 10);
        Add_Step("Empty, NoRoom, CoatIncomplete; the bowl keeps the piece", n"Step_AssertRefused");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_TrayReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsTrayReady(_Tray, 0));
    }

    UFUNCTION()
    private void Step_TakeOutOntoTray(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        TakeOut(_Tray.As_Platter(), 4);
    }

    UFUNCTION()
    private void Check_Refused1(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_TakeOutRefusals.Num() >= 1);
    }

    UFUNCTION()
    private void Step_Admit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Admit(0);
    }

    UFUNCTION()
    private void Check_PartlyCoated(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Batter.Get_HasPiece(Make_Id(0)) && _Batter.Get_PieceCoat(Make_Id(0)) >= k_PartialCoat);
    }

    UFUNCTION()
    private void Step_TakeOutBoth(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Batter.Get_PieceCoat(Make_Id(0)) < 1.0f, "the coat is not complete");
        TakeOut(FCk_Handle_Platter(), 4);
        TakeOut(_Tray.As_Platter(), 4);
    }

    UFUNCTION()
    private void Check_Refused3(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_TakeOutRefusals.Num() >= 3);
    }

    UFUNCTION()
    private void Step_AssertRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_TakeOutRefusals[0] == EMars_Batter_TakeOutRefusal::Empty, "the empty bowl's take-out is refused Empty");
        Assert_True(_TakeOutRefusals[1] == EMars_Batter_TakeOutRefusal::NoRoom, "a take-out with no tray is refused NoRoom");
        Assert_True(_TakeOutRefusals[2] == EMars_Batter_TakeOutRefusal::CoatIncomplete, "a partial coat is refused CoatIncomplete");
        Assert_Equals_Int(_TakenOut.Num(), 0, "nothing was handed back");
        Assert_True(_Batter.Get_HasPiece(Make_Id(0)), "the bowl keeps the piece");
        Assert_Equals_Int(_Tray.As_Platter().Get_Occupancy(), 0, "the tray is empty");
        Assert_Equals_Int(utils_cooking_feed::Get_Takeable(_StationEntity).Num(), 0, "the readout lists nothing");
        Assert_False(utils_batter::Get_IsBattered(_Pieces[0].Get_CookState()), "the ledger is not battered");
    }
}
