// MaxReleasedPieces 2. Two boxes released fill the ring; a third released destroys the oldest; two more released in one
// sweep destroy the two before them. Released always holds the newest two, oldest first, and only the pushed-out pieces are
// destroyed.
class UMars_AutoTest_FoodBoard_ReleasedRingDestroysOldest : UMars_AutoTestRig_FoodBoard
{
    private FCk_Handle_FoodBoard _Board;
    private TArray<FCk_Handle_FoodPiece> _Pieces;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Tuners = Make_Tuners();
        Tuners.MaxReleasedPieces = 2;
        _Board = Build_Board(InHandle, FTransform(FRotator(0.0, 90.0, 0.0), FVector(6000.0, 3000.0, -42000.0)), Tuners);
        for (int32 Index = 0; Index < 5; ++Index)
        { _Pieces.Add(Build_BoxOn(_Board, FTransform(FRotator::ZeroRotator, FVector(15.0 * Index, 0.0, 0.0)), 0.4)); }

        Add_Step_WaitUntil("all five boxes are Ready", n"Check_AllReady");
        Add_Step("place and release the first two", n"Step_ReleaseFirstTwo");
        Add_Step_WaitUntil("both are released", n"Check_TwoReleased");
        Add_Step("the ring is full; place and release the third", n"Step_ReleaseThird");
        Add_Step_WaitUntil("the third is released and the oldest destroyed", n"Check_ThirdReleased");
        Add_Step("the oldest left; place the last two and release them in one sweep", n"Step_ReleaseLastTwo");
        Add_Step_WaitUntil("the last two are released and the two before them destroyed", n"Check_LastTwoReleased");
        Add_Step("the ring holds the newest two", n"Step_AssertLast");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_AllReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        for (const auto& Piece : _Pieces)
        {
            if (Get_HasReadied(Piece) == false)
            {
                Res.Set(false);
                return;
            }
        }

        Res.Set(true);
    }

    UFUNCTION()
    private void Step_ReleaseFirstTwo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Place(_Board, _Pieces[0]);
        Place(_Board, _Pieces[1]);
        Release();
    }

    UFUNCTION()
    private void Check_TwoReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_ReleasedEvents(_Board).Num() >= 2);
    }

    UFUNCTION()
    private void Step_ReleaseThird(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsSameOrder(_Board.Get_Released(), Range(0, 2)), "the first two fill the ring");
        Assert_True(ck::IsValid(_Pieces[0]) && ck::IsValid(_Pieces[1]), "a full ring destroys nothing");

        Place(_Board, _Pieces[2]);
        Release();
    }

    UFUNCTION()
    private void Check_ThirdReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_ReleasedEvents(_Board).Num() >= 3 && ck::Is_NOT_Valid(_Pieces[0]));
    }

    UFUNCTION()
    private void Step_ReleaseLastTwo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsSameOrder(_Board.Get_Released(), Range(1, 3)), "the ring holds the second and third, oldest first");
        Assert_True(ck::IsValid(_Pieces[1]) && ck::IsValid(_Pieces[2]), "only the oldest was destroyed");

        Place(_Board, _Pieces[3]);
        Place(_Board, _Pieces[4]);
        Release();
    }

    UFUNCTION()
    private void Check_LastTwoReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_ReleasedEvents(_Board).Num() >= 5 && ck::Is_NOT_Valid(_Pieces[1]) && ck::Is_NOT_Valid(_Pieces[2]));
    }

    UFUNCTION()
    private void Step_AssertLast(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsSameOrder(_Board.Get_Released(), Range(3, 5)), "the ring holds the last two, oldest first");
        Assert_True(ck::IsValid(_Pieces[3]) && ck::IsValid(_Pieces[4]), "the newest two live");
        Assert_Equals_Int(_Board.Get_HeldCount(), 0, "nothing is held");
    }

    private void Release()
    {
        auto Board = _Board;
        Board.Request_Release(FMars_Request_FoodBoard_Release());
    }

    // _Pieces[InFirst, InEnd).
    private TArray<FCk_Handle_FoodPiece> Range(int32 InFirst, int32 InEnd) const
    {
        TArray<FCk_Handle_FoodPiece> Pieces;
        for (int32 Index = InFirst; Index < InEnd; ++Index)
        { Pieces.Add(_Pieces[Index]); }

        return Pieces;
    }
}
