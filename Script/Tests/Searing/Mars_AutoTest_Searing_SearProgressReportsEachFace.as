// OnSearProgress follows the face on the pan, not only the tenth: a tumble onto a face at the same tenth is reported at
// once. A piece arrives with its -Z and +X faces both seared to 0.55 (the same tenth, 0.5) on a hot, slow pan (60 s a
// face, so a tenth takes 6 s). Landing flat it reports -Z at 0.5. Turned +X down on the pan without leaving it, it reports
// +X at 0.5 straight away, long before +X reaches its next tenth.
class UMars_AutoTest_Searing_SearProgressReportsEachFace : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 20.0f;

    // Slow enough that neither face leaves its tenth while the test turns the piece.
    private const float32 k_SecondsPerFace = 60.0f;
    private const float32 k_SeededSear = 0.55f;
    private const float32 k_SeededTenth = 0.5f;
    // The clearance the turned piece is placed with over the cooking surface: within its Resting's grace.
    private const float64 k_TurnClearance = 0.1;

    private FMars_CookingFeed_PieceId _PieceId;
    // The contact edges recorded before the turn: the turn must not lift the piece off the pan (a landing resets the step).
    private int32 _ContactEdgesAtTurn = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        Spec.Cook.SecondsPerFace = k_SecondsPerFace;
        BuildStation(InHandle, Spec);
        Build_Pieces(1);

        Add_Step_WaitUntil("the pan body is in the simulation", n"Check_PanBodyAdded", k_SlowPolls, 0);
        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", k_SlowPolls, 0);
        Add_Step("seed -Z and +X at the same tenth", n"Step_Seed");
        Add_Step_WaitUntil("the seed is applied", n"Check_Seeded", 0, 0);
        Add_Step("heat the pan and add the piece", n"Step_HeatAndAdd");
        Add_Step_WaitUntil("-Z on the pan reported its tenth", n"Check_NegZReported", k_SlowPolls, 0);
        Add_Step("turn the piece +X down on the pan", n"Step_TurnPosXDown");
        Add_Step_WaitUntil("+X reported", n"Check_PosXReported", k_SlowPolls, 0);
        Add_Step("+X reported at the same tenth, without leaving the pan", n"Step_AssertPosXReport");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Seed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto CookState = FMars_FoodPiece_CookState();
        CookState.Sear[int32(EMars_FoodPiece_Face::NegZ)] = k_SeededSear;
        CookState.Sear[int32(EMars_FoodPiece_Face::PosX)] = k_SeededSear;
        auto Piece = _Pieces[0];
        Piece.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(CookState));
    }

    UFUNCTION()
    private void Check_Seeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Sear = _Pieces[0].Get_CookState().Sear;
        auto Res = OutResult;
        Res.Set(Sear.Num() == utils_searing::k_FaceCount && Sear[int32(EMars_FoodPiece_Face::PosX)] >= k_SeededSear);
    }

    UFUNCTION()
    private void Step_HeatAndAdd(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Heat();
        _PieceId = AddPiece();
    }

    UFUNCTION()
    private void Check_NegZReported(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Find_Report(EMars_FoodPiece_Face::NegZ) >= 0);
    }

    UFUNCTION()
    private void Step_TurnPosXDown(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto NegZ = Find_Report(EMars_FoodPiece_Face::NegZ);
        Assert_Equals_Float(_ProgressAlphas[NegZ], k_SeededTenth, 0.0001, "-Z reported its seeded tenth");
        Assert_Equals_Int(Find_Report(EMars_FoodPiece_Face::PosX), -1, "+X has not been reported yet");

        _ContactEdgesAtTurn = _Contacts.Num();
        const auto HalfExtents = _Searing.Get_PieceHalfExtents(_PieceId);
        Teleport_Piece(_PieceId, FVector(0.0, 0.0, utils_searing::k_PanSurfaceZ + HalfExtents.X + k_TurnClearance),
            utils_foodpiece::Make_FaceDownRotation(EMars_FoodPiece_Face::PosX));
    }

    UFUNCTION()
    private void Check_PosXReported(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Find_Report(EMars_FoodPiece_Face::PosX) >= 0);
    }

    UFUNCTION()
    private void Step_AssertPosXReport(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Contacts.Num(), _ContactEdgesAtTurn,
            "the turned piece never left the pan (a landing would reset the step and prove nothing)");

        const auto PosX = Find_Report(EMars_FoodPiece_Face::PosX);
        Assert_Equals_Float(_ProgressAlphas[PosX], k_SeededTenth, 0.0001,
            "+X is reported at the tenth it shares with -Z, not only once it reaches the next");

        const auto Sear = _Searing.Get_FaceSear(_PieceId, EMars_FoodPiece_Face::PosX);
        Assert_True(Sear >= k_SeededSear && Sear < k_SeededTenth + 0.1f, f"+X is still within its seeded tenth (sear {Sear})");
    }

    // The first OnSearProgress for the piece's InFace; -1 = none.
    private int32 Find_Report(EMars_FoodPiece_Face InFace) const
    {
        for (int32 Index = 0; Index < _ProgressFaces.Num(); ++Index)
        {
            if (_ProgressIds[Index].Get_IsSame(_PieceId) && _ProgressFaces[Index] == InFace)
            { return Index; }
        }

        return -1;
    }
}

class AMars_AutoTest_Searing_SearProgressReportsEachFace_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 20.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_SearProgressReportsEachFace;
}
