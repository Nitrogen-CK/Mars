// Seven different pieces released in one drain into a kernel of Supply.MaxPieces 6 (the default): the first six are
// Accepted (six bodies), the seventh is Rejected with a reason naming the limit and left as it was.
class UMars_AutoTest_Fry_AdmissionRejectsASeventhPiece : UMars_AutoTestRig_Fry
{
    default _TimeoutSeconds = 8.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_Pieces(7);

        Add_Step_WaitUntil("the scoop and basket bodies are in the simulation", n"Check_BodiesAdded", 0, 3.0f);
        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", 0, 3.0f);
        Add_Step("release seven different pieces over the oil", n"Step_ReleaseSeven");
        Add_Step_WaitUntil("all seven releases were answered", n"Check_Answered7", 0, 1.0f);
        Add_Step_WaitFrames("anything made would show", 2);
        Add_Step("six accepted, the seventh rejected", n"Step_AssertLimit");
        Run_Steps(InHandle);
    }

    // Spots over the oil, apart from each other and from the parked scoop.
    UFUNCTION()
    private void Step_ReleaseSeven(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        TArray<FVector2D> Spots;
        Spots.Add(FVector2D(-30.0, 0.0));
        Spots.Add(FVector2D(-20.0, -20.0));
        Spots.Add(FVector2D(0.0, -30.0));
        Spots.Add(FVector2D(-10.0, 10.0));
        Spots.Add(FVector2D(10.0, -15.0));
        Spots.Add(FVector2D(-30.0, 20.0));
        Spots.Add(FVector2D(0.0, 25.0));

        const auto Z = float64(_Spec.Oil.SurfaceZ) + Get_BoxHalfExtents().Z + 1.0;
        for (const auto& Spot : Spots)
        { AddPiece(FVector(Spot.X, Spot.Y, Z)); }
    }

    UFUNCTION()
    private void Check_Answered7(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= 7);
    }

    UFUNCTION()
    private void Step_AssertLimit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Admissions.Num(), 7, "seven answers");
        if (_Admissions.Num() < 7)
        { return; }

        for (int32 Index = 0; Index < 6; ++Index)
        { Assert_True(_Admissions[Index] == EMars_CookingFeed_Admission::Accepted, f"release {Index} is accepted"); }

        Assert_True(_Admissions[6] == EMars_CookingFeed_Admission::Rejected, "the seventh is rejected");
        Assert_True(_AdmissionReasons[6].Contains("MaxPieces"), f"the rejection names the limit (got {_AdmissionReasons[6]})");
        Log(f"[Mars_AutoTest_Fry_AdmissionRejectsASeventhPiece] seventh rejected: {_AdmissionReasons[6]}");

        Assert_Equals_Int(_Added.Num(), 6, "six OnPieceAdded");
        Assert_Equals_Int(_Fry.Get_PieceIds().Num(), 6, "six pieces in play");
        Assert_Equals_Int(_Fry.Get_Summary().Admitted, 6, "the summary admits six");
    }
}
