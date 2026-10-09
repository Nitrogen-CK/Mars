// A platter ends the pieces it holds. Clearing A announces OnCleared once and destroys both its pieces, leaving it empty;
// destroying B's entity destroys both of its pieces with it.
class UMars_AutoTest_Platter_ClearAndDestroyEndHeldPieces : UMars_AutoTestRig_Platter
{
    private const FVector k_Origin = FVector(14000.0, -12000.0, -30000.0);

    private FCk_Handle_Platter _PlatterA;
    private FCk_Handle_Platter _PlatterB;
    private TArray<FCk_Handle_FoodPiece> _PiecesA;
    private TArray<FCk_Handle_FoodPiece> _PiecesB;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _PlatterA = Build_Platter(InHandle, FTransform(FRotator::ZeroRotator, k_Origin), Make_PlatterSpec(2, 0.0f));
        _PlatterB = Build_Platter(InHandle, FTransform(FRotator(0.0, 90.0, 0.0), k_Origin + FVector(0.0, 200.0, 0.0)), Make_PlatterSpec(2, 0.0f));
        for (int32 Index = 0; Index < 2; ++Index)
        {
            _PiecesA.Add(Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 30.0 * Index, 0.0)), 0.5));
            _PiecesB.Add(Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 200.0 + 30.0 * Index, 0.0)), 0.5));
        }

        Add_Step_WaitUntil("the boxes are Ready", n"Check_Ready");
        Add_Step("load two pieces on each platter", n"Step_Load");
        Add_Step_WaitUntil("all four landed", n"Check_Landed");
        Add_Step("clear A", n"Step_ClearA");
        Add_Step_WaitFrames("the clear drains and its destroys begin", 2);
        Add_Step("A's pieces are ending; destroy B", n"Step_AssertClearedAndDestroyB");
        Add_Step_WaitFrames("B's destruction ends its pieces", 2);
        Add_Step("B's pieces are ending", n"Step_AssertDestroyed");
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
    private void Step_ClearA(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Clear(_PlatterA);
    }

    UFUNCTION()
    private void Step_AssertClearedAndDestroyB(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_ClearedCount(_PlatterA), 1, "A announced OnCleared once");
        Assert_Equals_Int(_PlatterA.Get_HeldCount(), 0, "A holds nothing");
        Assert_Equals_Int(_PlatterA.Get_Occupancy(), 0, "A has no pending load either");
        for (const auto& Piece : _PiecesA)
        { Assert_True(Get_IsEnding(Piece), f"A's piece [{Piece.ToString()}] is being destroyed"); }

        for (const auto& Piece : _PiecesB)
        { Assert_False(Get_IsEnding(Piece), f"B's piece [{Piece.ToString()}] is untouched by A's clear"); }

        utils_entity_lifetime::Request_DestroyEntity(_PlatterB);
    }

    UFUNCTION()
    private void Step_AssertDestroyed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (const auto& Piece : _PiecesB)
        { Assert_True(Get_IsEnding(Piece), f"B's piece [{Piece.ToString()}] is being destroyed with B"); }

        Assert_Equals_Int(Get_ClearedCount(_PlatterB), 0, "B's destruction is not a clear");
    }
}
