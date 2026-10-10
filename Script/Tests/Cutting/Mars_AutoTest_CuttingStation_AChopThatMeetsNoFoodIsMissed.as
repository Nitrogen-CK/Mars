// A chop on an empty board meets no food: the cleaver lands once, the cut bridge still cuts the board along the blade, and
// the board's answer is a knock (nothing straddled the plane, nothing was cut). That answer is what the station's
// assembly reads to spark or not.
class UMars_AutoTest_CuttingStation_AChopThatMeetsNoFoodIsMissed : UMars_AutoTestRig_CuttingStation
{
    private const FVector k_Origin = FVector(16800.0, -15000.0, -30000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);

        Add_Step_WaitUntil("the station composed its Cutting, FoodBoard and docks", n"Check_StationReady", 0, 5.0f);
        Add_Step("an operator takes the station", n"Step_Take");
        Add_Step_WaitUntil("the station's state machine is Operated", n"Check_Operated", 0, 2.0f);
        Add_Step("chop on the empty board", n"Step_Chop");
        Add_Step_WaitUntil("the chop landed, the cleaver is back up and the board answered", n"Check_Answered", 0, 3.0f);
        Add_Step_WaitFrames("a late cut or a second answer would show by now", 5);
        Add_Step("one landing, one knock, nothing cut", n"Step_AssertMissed");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Chop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Board.Get_HeldCount(), 0, "the board is empty");
        Chop();
    }

    UFUNCTION()
    private void Check_Answered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ChopsLanded == _ChopsIssued && _Cutting.Get_IsChopping() == false && _Issues.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertMissed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_ChopsLanded, 1, "OnChopLanded fired once");
        Assert_Equals_Int(_Issues.Num(), 1, "the board answered the chop once");
        if (_Issues.Num() == 1)
        {
            Assert_Equals_Int(_Issues[0].Straddling, 0, "nothing straddled the blade: the chop missed");
            Assert_Equals_Int(_Issues[0].Issued, 0, "no cut was issued");
        }

        Assert_Equals_Int(_PieceCuts, 0, "no OnPieceCut");
        Assert_Equals_Int(_Board.Get_HeldCount(), 0, "the board is still empty");
    }
}
