// A food without a battered variant is refused NotBatterable: a whole piece of the meat slab's food (no battered mesh) and
// a bare piece (no food at all) are released over the bowl in one drain; both are rejected NotBatterable and the bowl
// stays empty.
class UMars_AutoTest_Batter_AdmissionRefusesANonBatterableFood : UMars_AutoTestRig_Batter
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_FoodPieces(1, mars::Food_MeatSlab_Mars);
        _Pieces.Add(Build_Piece(Get_BoxMesh(), FTransform(k_Origin + k_ParkLocal - FVector(0.0, 40.0, 0.0)), Make_Spec(k_PieceMassKg)));

        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", k_SlowPolls, 0);
        Add_Step("release the slab piece and the bare piece", n"Step_Admit");
        Add_Step_WaitUntil("both releases are answered", n"Check_Answered2", 0, 0);
        Add_Step("both refused NotBatterable", n"Step_AssertRefused");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Admit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(mars::Food_MeatSlab_Mars.Get_IsBatterable(), "the slab's food has no battered variant");
        Admit(0);
        Admit(1);
    }

    UFUNCTION()
    private void Check_Answered2(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 2);
    }

    UFUNCTION()
    private void Step_AssertRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Refusals.Num(), 2, "two refusals");
        for (int32 Index = 0; Index < _Admissions.Num(); ++Index)
        {
            Assert_True(_Admissions[Index] == EMars_CookingFeed_Admission::Rejected, f"release {Index} is rejected");
            if (_Refusals.IsValidIndex(Index))
            {
                Assert_True(_Refusals[Index] == EMars_Batter_AdmissionRefusal::NotBatterable,
                    f"release {Index} refused NotBatterable (reason: {_AdmissionReasons[Index]})");
            }
        }

        Assert_Equals_Int(_Batter.Get_PieceCount(), 0, "the bowl is empty");
    }
}
