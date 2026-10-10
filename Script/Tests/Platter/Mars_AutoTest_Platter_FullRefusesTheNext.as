// A platter of capacity 2 asked to load three pieces in one step accepts two and refuses the third Full at the drain, before
// either accepted piece has dropped: a queued piece counts against the capacity. The two accepted pieces then land.
class UMars_AutoTest_Platter_FullRefusesTheNext : UMars_AutoTestRig_Platter
{
    private const FVector k_Origin = FVector(14000.0, -19000.0, -30000.0);

    private FCk_Handle_Platter _Platter;
    private TArray<FCk_Handle_FoodPiece> _Pieces;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Platter = Build_Platter(InHandle, FTransform(FRotator::ZeroRotator, k_Origin), Make_PlatterSpec(2));
        for (int32 Index = 0; Index < 3; ++Index)
        { _Pieces.Add(Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 30.0 * Index, 0.0)), 0.5)); }

        Add_Step_WaitUntil("the three boxes are Ready", n"Check_Ready");
        Add_Step("load all three in one step", n"Step_LoadThree");
        Add_Step_WaitFrames("the loads drain", 2);
        Add_Step("the third is refused Full before anything dropped", n"Step_AssertRefused");
        Add_Step_WaitUntil("the two accepted pieces landed", n"Check_TwoLanded");
        Add_Step("two held, the third never loaded", n"Step_AssertLanded");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto IsReady = true;
        for (const auto& Piece : _Pieces)
        { IsReady = IsReady && Get_HasReadied(Piece); }

        auto Res = OutResult;
        Res.Set(IsReady);
    }

    UFUNCTION()
    private void Step_LoadThree(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (const auto& Piece : _Pieces)
        { Load(_Platter, Piece); }
    }

    UFUNCTION()
    private void Step_AssertRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_RefusalCount(_Platter, EMars_Platter_LoadRefusal::Full), 1, "one load was refused Full");
        Assert_Equals_Int(Get_AllRefusalCount(_Platter), 1, "nothing else was refused");
        Assert_True(_Refused.Num() == 1 && _Refused[0].Piece == _Pieces[2], "the refused piece is the third");
        Assert_Equals_Int(_Platter.Get_HeldCount(), 0, "nothing has landed yet: the refusal did not wait for a drop");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 2, "the two accepted pieces fill the platter");
        Assert_True(_Platter.Get_IsFull() && _Platter.Get_FreeCount() == 0, "the platter is full");
        Assert_True(ck::Is_NOT_Valid(_Pieces[2].TryGet_Platter()), "the refused piece names no platter");
    }

    UFUNCTION()
    private void Check_TwoLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Platter.Get_HeldCount() == 2);
    }

    UFUNCTION()
    private void Step_AssertLanded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsFrozenOn(_Platter, _Pieces[0]) && Get_IsFrozenOn(_Platter, _Pieces[1]), "the two accepted pieces are frozen on the root");
        Assert_False(TryGet_Loaded(_Pieces[2]).IsSet(), "the refused piece never landed");
        Assert_False(Get_IsSceneNode(_Pieces[2]), "the refused piece rides nothing");
    }
}
