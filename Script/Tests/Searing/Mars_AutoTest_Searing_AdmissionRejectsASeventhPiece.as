// At the default Supply.MaxPieces (6), seven different pieces released in one drain: the first six are Accepted, the
// seventh is Rejected with a reason naming the limit. Six bodies, six pieces on the books, the seventh left as it was.
class UMars_AutoTest_Searing_AdmissionRejectsASeventhPiece : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 8.0f;

    private const int32 k_Released = 7;
    // The six admitted pieces sit in a ring this far from the pan's centre (inside the flat base), 60 degrees apart; the
    // seventh is released over the centre.
    private const float64 k_RingRadius = 14.0;
    private const float64 k_ReleaseZ = 8.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_Pieces(k_Released);

        Add_Step_WaitUntil("the pan body is in the simulation", n"Check_PanBodyAdded", k_SlowPolls, 0);
        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", k_SlowPolls, 0);
        Add_Step("release seven different pieces", n"Step_ReleaseSeven");
        Add_Step_WaitUntil("every release was answered", n"Check_AllAnswered", 0, 0);
        Add_Step_WaitFrames("anything made would show", 2);
        Add_Step("six are accepted, the seventh rejected", n"Step_AssertLimit");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_ReleaseSeven(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (int32 Index = 0; Index < k_Released - 1; ++Index)
        {
            const auto Angle = Math::DegreesToRadians(60.0 * float64(Index));
            AddPieceAt(FVector(Math::Cos(Angle) * k_RingRadius, Math::Sin(Angle) * k_RingRadius, k_ReleaseZ));
        }

        AddPieceAt(FVector(0.0, 0.0, k_ReleaseZ));
    }

    UFUNCTION()
    private void Check_AllAnswered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Admissions.Num() >= k_Released);
    }

    UFUNCTION()
    private void Step_AssertLimit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Spec.Supply.MaxPieces, k_Released - 1, "the default supply holds six pieces");
        Assert_Equals_Int(_Admissions.Num(), k_Released, "one answer per release");
        if (_Admissions.Num() < k_Released)
        { return; }

        for (int32 Index = 0; Index < k_Released - 1; ++Index)
        { Assert_True(_Admissions[Index] == EMars_CookingFeed_Admission::Accepted, f"piece {Index} is accepted"); }

        const auto Last = k_Released - 1;
        Assert_True(_Admissions[Last] == EMars_CookingFeed_Admission::Rejected, "the seventh piece is rejected");
        Assert_True(_AdmissionReasons[Last].Contains("MaxPieces"), f"the rejection names the limit (got {_AdmissionReasons[Last]})");
        Assert_True(_AdmissionIds[Last].Get_IsSame(FMars_CookingFeed_PieceId(k_Generation, Last)), "the rejection names the seventh Id");
        Assert_Equals_Int(_Added.Num(), k_Released - 1, "six OnPieceAdded");
        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), k_Released - 1, "six pieces on the books");
        Assert_False(_Searing.Get_HasPiece(_AdmissionIds[Last]), "the seventh is not on the books");
    }
}

class AMars_AutoTest_Searing_AdmissionRejectsASeventhPiece_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 8.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_AdmissionRejectsASeventhPiece;
}
