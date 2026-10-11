// A fully coated piece leaves the bowl battered and lands on the tray. A whole batterable piece is admitted and dipped until
// its coat completes; while it is still under, the readout lists nothing and a take-out is refused StillInTheBatter. Lifted
// back to rest, the station's take-out readout lists it, and a take-out onto an empty platter hands it back
// (OnPieceTakenOut names it) and it lands on the platter: its ledger is battered (Battered = 1, every other channel as it
// came), the platter is its holder, the bowl is empty and the readout lists nothing.
class UMars_AutoTest_Batter_ATakeOutWritesBatteredAndTheTrayReceivesIt : UMars_AutoTestRig_Batter
{
    private FCk_Handle _Tray;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_FoodPieces(1, mars::Food_TestBatterableBox_Mars);
        _Tray = Spawn_Tray(InHandle);

        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("the tray is constructed", n"Check_TrayReady", k_SlowPolls, 0);
        Add_Step("release the piece", n"Step_Admit");
        Add_Step_WaitUntil("it is in the bowl", n"Check_Answered1", 0, 0);
        Add_Step("dip", n"Step_Dip");
        Add_Step_WaitUntil("the coat completes", n"Check_FirstCoated", k_SlowPolls, 0);
        Add_Step("take out while it is still under", n"Step_TakeOutWhileDipped");
        Add_Step_WaitUntil("it is refused", n"Check_Refused1", 0, 0);
        Add_Step("refused StillInTheBatter; lift", n"Step_AssertStillInTheBatterAndLift");
        Add_Step_WaitUntil("it rose back to rest", n"Check_FirstAtRest", k_SlowPolls, 0);
        Add_Step_WaitFrames("the readout follows", 2);
        Add_Step("the readout lists it; take out onto the tray", n"Step_TakeOut");
        Add_Step_WaitUntil("it landed on the tray", n"Check_OnTray", k_SlowPolls, 0);
        Add_Step("it is battered and the tray holds it", n"Step_AssertOnTray");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_TrayReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsTrayReady(_Tray, 0));
    }

    UFUNCTION()
    private void Step_Admit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Admit(0);
    }

    UFUNCTION()
    private void Step_TakeOutWhileDipped(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(utils_cooking_feed::Get_Takeable(_StationEntity).Num(), 0, "a coated piece still under is not takeable");
        TakeOut(_Tray.As_Platter(), 4);
    }

    UFUNCTION()
    private void Check_Refused1(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_TakeOutRefusals.Num() >= 1);
    }

    UFUNCTION()
    private void Step_AssertStillInTheBatterAndLift(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_TakeOutRefusals[0] == EMars_Batter_TakeOutRefusal::StillInTheBatter, "refused StillInTheBatter");
        Assert_True(_Batter.Get_HasPiece(Make_Id(0)), "the bowl keeps the piece");
        Lift();
    }

    UFUNCTION()
    private void Step_TakeOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Takeable = utils_cooking_feed::Get_Takeable(_StationEntity);
        Assert_True(Takeable.Num() == 1 && Takeable[0] == _Pieces[0], "the readout lists the coated piece");
        TakeOut(_Tray.As_Platter(), 4);
    }

    UFUNCTION()
    private void Check_OnTray(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsTrayReady(_Tray, 1));
    }

    UFUNCTION()
    private void Step_AssertOnTray(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Piece = _Pieces[0];
        Assert_True(_TakenOut.Num() == 1 && _TakenOut[0] == Piece, f"the take-out handed back the piece ({_TakenOut.Num()} handed back)");
        Assert_Equals_Int(_TakeOutRefusals.Num(), 1, "only the take-out while dipped was refused");

        const auto CookState = Piece.Get_CookState();
        Assert_Equals_Float(CookState.Battered, 1.0, 0.0, "the ledger is battered");
        Assert_Equals_Float(CookState.Crumb, 0.0, 0.0, "the crumb is as it came");
        Assert_Equals_Float(CookState.OilCoat, 0.0, 0.0, "the oil coat is as it came");

        Assert_True(Piece.TryGet_Platter() == _Tray.As_Platter(), "the piece is on the tray");
        Assert_True(Piece.TryGet_Holder() == _Tray, "the tray holds the piece");
        Assert_Equals_Int(_Batter.Get_PieceCount(), 0, "the bowl is empty");
        Assert_Equals_Int(utils_cooking_feed::Get_Takeable(_StationEntity).Num(), 0, "the readout lists nothing");
    }
}
