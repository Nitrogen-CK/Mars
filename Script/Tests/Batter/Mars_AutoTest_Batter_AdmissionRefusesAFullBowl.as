// The bowl holds Bowl.Capacity pieces (3): four whole batterable pieces and piece 0 again (under a new Id) are released in
// one drain; the first three are accepted into distinct slots, the fourth is refused Full (its reason naming the capacity)
// and the duplicate is refused Duplicate; the bowl cannot load.
class UMars_AutoTest_Batter_AdmissionRefusesAFullBowl : UMars_AutoTestRig_Batter
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_FoodPieces(4, mars::Food_TestBatterableBox_Mars);

        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", k_SlowPolls, 0);
        Add_Step("release four pieces and piece 0 again", n"Step_Admit");
        Add_Step_WaitUntil("five releases are answered", n"Check_Answered5", 0, 0);
        Add_Step("three in, the fourth refused Full, the duplicate refused Duplicate", n"Step_AssertFull");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Admit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (int32 Slot = 0; Slot < 4; ++Slot)
        { Admit(Slot); }

        Admit_Piece(9, _Pieces[0]);
    }

    UFUNCTION()
    private void Check_Answered5(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 5);
    }

    UFUNCTION()
    private void Step_AssertFull(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (int32 Index = 0; Index < 3; ++Index)
        { Assert_True(_Admissions[Index] == EMars_CookingFeed_Admission::Accepted, f"piece {Index} is accepted (reason: {_AdmissionReasons[Index]})"); }

        Assert_True(_Admissions[3] == EMars_CookingFeed_Admission::Rejected, "the fourth is rejected");
        Assert_True(_AdmissionReasons[3].Contains("Capacity"), f"its reason names the capacity (got {_AdmissionReasons[3]})");
        Assert_True(_Admissions[4] == EMars_CookingFeed_Admission::Rejected, "piece 0 again is rejected");
        Assert_True(_Refusals.Num() == 2 && _Refusals[0] == EMars_Batter_AdmissionRefusal::Full
            && _Refusals[1] == EMars_Batter_AdmissionRefusal::Duplicate, "refused Full, then Duplicate");

        Assert_Equals_Int(_Batter.Get_PieceCount(), _Spec.Bowl.Capacity, "the bowl is full");
        Assert_False(_Batter.Get_CanLoad(), "a full bowl cannot load");
        Assert_False(ck::IsValid(_Pieces[3].TryGet_Holder()), "nothing holds the refused fourth");

        TArray<int32> Slots;
        for (int32 Index = 0; Index < 3; ++Index)
        { Slots.AddUnique(_Batter.Get_PieceState(Make_Id(Index)).Slot); }

        Assert_Equals_Int(Slots.Num(), 3, "the three pieces sit in distinct slots");
    }
}
