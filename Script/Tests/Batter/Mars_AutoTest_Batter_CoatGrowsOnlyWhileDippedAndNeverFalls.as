// The coat clock runs only while the bowl is dipped, and never runs back. A whole batterable piece is admitted and left
// resting for k_RestFrames frames: its coat stays 0. A dip sinks it (its immersion reaches 1) and coats it past a third;
// a lift stops the coat where it is and the piece rises back to rest; k_RestFrames frames later the coat has not moved. A
// second dip completes it. Its stage was reported Coating once and Coated once, and every reported coat value is
// monotonic.
class UMars_AutoTest_Batter_CoatGrowsOnlyWhileDippedAndNeverFalls : UMars_AutoTestRig_Batter
{
    private const int32 k_RestFrames = 20;
    private const float32 k_PartialCoat = 0.35f;

    private float32 _CoatAtLift = 0.0f;
    private TArray<float32> _Polled;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_FoodPieces(1, mars::Food_TestBatterableBox_Mars);

        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", k_SlowPolls, 0);
        Add_Step("release the piece", n"Step_Admit");
        Add_Step_WaitUntil("it is in the bowl", n"Check_Answered1", 0, 0);
        Add_Step_WaitFrames("it rests", k_RestFrames);
        Add_Step("resting coats nothing", n"Step_AssertBare");
        Add_Step("dip", n"Step_Dip");
        Add_Step_WaitUntil("the coat passes a third", n"Check_PartlyCoated", k_SlowPolls, 0);
        Add_Step("lift", n"Step_LiftAndRecord");
        Add_Step_WaitUntil("it rose back to rest", n"Check_FirstAtRest", k_SlowPolls, 0);
        Add_Step("record the coat the lift left", n"Step_RecordAtRest");
        Add_Step_WaitFrames("it rests", k_RestFrames);
        Add_Step("the coat held where the lift left it", n"Step_AssertHeld");
        Add_Step("dip again", n"Step_Dip");
        Add_Step_WaitUntil("the coat completes", n"Check_FirstCoated", k_SlowPolls, 0);
        Add_Step("one Coating and one Coated edge, a monotonic coat", n"Step_AssertEdges");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Admit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Admit(0);
    }

    UFUNCTION()
    private void Step_AssertBare(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Batter.Get_HasPiece(Make_Id(0)), "the bowl holds the piece");
        if (_Batter.Get_HasPiece(Make_Id(0)) == false)
        { return; }

        Assert_Equals_Float(_Batter.Get_PieceCoat(Make_Id(0)), 0.0, 0.0, "no coat while resting");
        Assert_Equals_Float(_Batter.Get_PieceImmersion(Make_Id(0)), 0.0, 0.0, "not immersed while resting");
    }

    UFUNCTION()
    private void Check_PartlyCoated(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Coat = _Batter.Get_PieceCoat(Make_Id(0));
        _Polled.Add(Coat);
        auto Res = OutResult;
        Res.Set(Coat >= k_PartialCoat);
    }

    UFUNCTION()
    private void Step_LiftAndRecord(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Batter.Get_PieceImmersion(Make_Id(0)) >= 1.0f, "the dipped piece is fully under");
        Assert_True(_Batter.Get_PieceCoat(Make_Id(0)) < 1.0f, "the coat is not complete yet");
        Lift();
    }

    // The lift lands in the next drain: the coat it leaves is read once the piece is back at rest.
    UFUNCTION()
    private void Step_RecordAtRest(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _CoatAtLift = _Batter.Get_PieceCoat(Make_Id(0));
        Assert_True(_CoatAtLift >= k_PartialCoat && _CoatAtLift < 1.0f, f"the lift kept a partial coat ({_CoatAtLift :.3})");
        Assert_True(_Batter.Get_Bowl() == EMars_Batter_Bowl::Resting, "the bowl rests");

        const auto Last = _Polled.Num() > 0 ? _Polled.Last() : 0.0f;
        Assert_True(_CoatAtLift >= Last, f"the coat never ran back ({Last :.3} -> {_CoatAtLift :.3})");
        _Polled.Add(_CoatAtLift);
    }

    UFUNCTION()
    private void Step_AssertHeld(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Coat = _Batter.Get_PieceCoat(Make_Id(0));
        Assert_Equals_Float(Coat, _CoatAtLift, 0.0, f"resting moved the coat ({_CoatAtLift :.3} -> {Coat :.3})");
        Assert_Equals_Float(_Batter.Get_PieceImmersion(Make_Id(0)), 0.0, 0.0, "the piece rests above the batter");
    }

    UFUNCTION()
    private void Step_AssertEdges(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Count_Stages(Make_Id(0), EMars_Batter_CoatStage::Coating), 1, "one Coating edge");
        Assert_Equals_Int(Count_Stages(Make_Id(0), EMars_Batter_CoatStage::Coated), 1, "one Coated edge");
        Assert_Equals_Int(Count_Stages(Make_Id(0), EMars_Batter_CoatStage::Bare), 0, "never back to Bare");

        auto Last = 0.0f;
        for (const auto Coat : _Polled)
        {
            Assert_True(Coat >= Last, f"the coat never ran back ({Last :.3} -> {Coat :.3})");
            Last = Coat;
        }

        Assert_Equals_Float(_Batter.Get_PieceCoat(Make_Id(0)), 1.0, 0.0, "the coat completed at exactly 1");
        Assert_True(_Bowls.Num() >= 3 && _Bowls[0] == EMars_Batter_Bowl::Dipped && _Bowls[1] == EMars_Batter_Bowl::Resting
            && _Bowls[2] == EMars_Batter_Bowl::Dipped, "the bowl reported dip, lift, dip");
    }
}
