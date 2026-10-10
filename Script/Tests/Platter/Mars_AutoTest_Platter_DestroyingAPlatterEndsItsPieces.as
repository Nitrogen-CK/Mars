// A platter ends the pieces it holds: destroying its entity destroys both of its pieces with it, and a second platter's
// pieces are untouched by it.
class UMars_AutoTest_Platter_DestroyingAPlatterEndsItsPieces : UMars_AutoTestRig_Platter
{
    private const FVector k_Origin = FVector(14000.0, -12000.0, -30000.0);
    // Physics settles and mount arrivals outrun the harness's default poll budget at lane frame rate.
    private const int32 k_SlowPolls = 900;

    private FCk_Handle_Platter _PlatterA;
    private FCk_Handle_Platter _PlatterB;
    private TArray<FCk_Handle_FoodPiece> _PiecesA;
    private TArray<FCk_Handle_FoodPiece> _PiecesB;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _PlatterA = Build_Platter(InHandle, FTransform(FRotator::ZeroRotator, k_Origin), Make_PlatterSpec(2));
        _PlatterB = Build_Platter(InHandle, FTransform(FRotator(0.0, 90.0, 0.0), k_Origin + FVector(0.0, 200.0, 0.0)), Make_PlatterSpec(2));
        for (int32 Index = 0; Index < 2; ++Index)
        {
            _PiecesA.Add(Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 30.0 * Index, 0.0)), 0.5));
            _PiecesB.Add(Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 200.0 + 30.0 * Index, 0.0)), 0.5));
        }

        Add_Step_WaitUntil("the boxes are Ready", n"Check_Ready");
        Add_Step("load two pieces on each platter", n"Step_Load");
        Add_Step_WaitUntil("all four landed", n"Check_Landed", k_SlowPolls, 0);
        Add_Step("destroy B", n"Step_DestroyB");
        Add_Step_WaitFrames("B's destruction ends its pieces", 2);
        Add_Step("B's pieces are ending; A's are not", n"Step_AssertDestroyed");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        auto IsReady = true;
        for (int32 Index = 0; Index < 2; ++Index)
        { IsReady = IsReady && Get_HasReadied(_PiecesA[Index]) && Get_HasReadied(_PiecesB[Index]); }

        Res.Set(IsReady);
    }

    UFUNCTION()
    private void Step_Load(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (int32 Index = 0; Index < 2; ++Index)
        {
            Load(_PlatterA, _PiecesA[Index]);
            Load(_PlatterB, _PiecesB[Index]);
        }
    }

    UFUNCTION()
    private void Check_Landed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_PlatterA.Get_HeldCount() == 2 && _PlatterB.Get_HeldCount() == 2);
    }

    UFUNCTION()
    private void Step_DestroyB(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_entity_lifetime::Request_DestroyEntity(_PlatterB);
    }

    UFUNCTION()
    private void Step_AssertDestroyed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (const auto& Piece : _PiecesB)
        { Assert_True(Get_IsEnding(Piece), f"B's piece [{Piece.ToString()}] is being destroyed with B"); }

        Assert_Equals_Int(_PlatterA.Get_HeldCount(), 2, "A still holds its two pieces");
        for (const auto& Piece : _PiecesA)
        { Assert_False(Get_IsEnding(Piece), f"A's piece [{Piece.ToString()}] is untouched by B's destruction"); }
    }
}
