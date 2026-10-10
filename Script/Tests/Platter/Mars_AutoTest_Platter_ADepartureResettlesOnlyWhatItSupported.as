// A piece that leaves the pile leaves a hole only under what froze after it: those let go and settle again, the pieces
// frozen before it stay put. Three pieces freeze into a pile; unloading the second one frozen leaves the first frozen,
// Kinematic and a child of the root in the frame after the unload drains, while the third lets go (it is the platter's,
// settling, not held); within Settle.MaxSeconds the third re-freezes and Held is the first then the third, with no second
// landing. Isolated origin (186000, -70000, -30000).
class UMars_AutoTest_Platter_ADepartureResettlesOnlyWhatItSupported : UMars_AutoTestRig_Platter
{
    private const FVector k_Origin = FVector(186000.0, -70000.0, -30000.0);
    private const int32 k_SlowPolls = 900;

    private FCk_Handle_Platter _Platter;
    private TArray<FCk_Handle_FoodPiece> _Pieces;
    // Held in freeze order before the unload.
    private TArray<FCk_Handle_FoodPiece> _Frozen;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Platter = Build_Platter(InHandle, FTransform(FRotator(0.0, 10.0, 0.0), k_Origin), Make_PlatterSpec(3));
        for (int32 Index = 0; Index < 3; ++Index)
        { _Pieces.Add(Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 30.0 * Index, 0.0)), 0.5)); }

        Add_Step_WaitUntil("the three boxes are Ready", n"Check_Ready", k_SlowPolls, 0);
        Add_Step("load all three", n"Step_Load");
        Add_Step_WaitUntil("all three froze into the pile", n"Check_AllHeld", k_SlowPolls, 0);
        Add_Step("unload the second one frozen", n"Step_UnloadSecond");
        Add_Step_WaitUntil("the unload drained", n"Check_Unloaded", 0, 0);
        Add_Step("the first stays frozen, the third settles again", n"Step_AssertOnlyTheThirdLetGo");
        Add_Step_WaitUntil("the third re-froze", n"Check_TwoHeld", k_SlowPolls, 0);
        Add_Step("the first, then the third, and no second landing", n"Step_AssertRefrozen");
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
    private void Step_Load(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (const auto& Piece : _Pieces)
        { Load(_Platter, Piece); }
    }

    UFUNCTION()
    private void Check_AllHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Platter.Get_HeldCount() == 3 || Get_AllRefusalCount(_Platter) > 0);
    }

    UFUNCTION()
    private void Step_UnloadSecond(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_AllRefusalCount(_Platter), 0, "nothing was refused");
        _Frozen = _Platter.Get_Held();
        Unload(_Platter, _Frozen[1]);
    }

    UFUNCTION()
    private void Check_Unloaded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_UnloadedCount(_Platter) >= 1);
    }

    UFUNCTION()
    private void Step_AssertOnlyTheThirdLetGo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Held = _Platter.Get_Held();
        Assert_True(Held.Num() == 1 && Held[0] == _Frozen[0], f"only the first frozen is still held (held {Held.Num()})");
        Assert_True(Get_IsFrozenOn(_Platter, _Frozen[0]), "the first frozen is still Kinematic on the root");
        Assert_Equals_Int(_Platter.Get_PendingCount(), 1, "the third frozen settles again");
        Assert_True(_Frozen[2].TryGet_Platter() == _Platter, "the third is still the platter's");
        Assert_False(Get_IsSceneNode(_Frozen[2]), "the third let go of the root");
    }

    UFUNCTION()
    private void Check_TwoHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Platter.Get_HeldCount() == 2 && _Platter.Get_PendingCount() == 0);
    }

    UFUNCTION()
    private void Step_AssertRefrozen(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Held = _Platter.Get_Held();
        Assert_True(Held.Num() == 2 && Held[0] == _Frozen[0] && Held[1] == _Frozen[2], "held: the first, then the third");
        Assert_Equals_Int(Get_LoadedCount(_Platter), 3, "three landings, none again");
    }
}
