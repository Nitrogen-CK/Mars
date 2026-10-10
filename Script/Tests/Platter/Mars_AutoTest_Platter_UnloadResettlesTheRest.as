// Three pieces frozen into a pile; unloading the first one frozen (the bottom) leaves a hole, so the other two let go and
// settle again: they are Dynamic and off Held in the frame after the unload, and within 3 s both re-freeze, still inside the
// walls, Held has two and nothing loads again (a re-settle is silent).
class UMars_AutoTest_Platter_UnloadResettlesTheRest : UMars_AutoTestRig_Platter
{
    private const FVector k_Origin = FVector(14000.0, -20000.0, -30000.0);

    private FCk_Handle_Platter _Platter;
    private TArray<FCk_Handle_FoodPiece> _Pieces;
    private FCk_Handle_FoodPiece _First;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Platter = Build_Platter(InHandle, FTransform(FRotator(0.0, -15.0, 0.0), k_Origin), Make_PlatterSpec(3));
        for (int32 Index = 0; Index < 3; ++Index)
        { _Pieces.Add(Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 30.0 * Index, 0.0)), 0.5)); }

        Add_Step_WaitUntil("the three boxes are Ready", n"Check_Ready");
        Add_Step("load all three", n"Step_Load");
        Add_Step_WaitUntil("all three froze into the pile", n"Check_AllHeld");
        Add_Step("unload the first one frozen", n"Step_UnloadFirst");
        Add_Step_WaitUntil("the unload drained", n"Check_Unloaded");
        Add_Step("the other two let go and settle again", n"Step_AssertResettling");
        Add_Step_WaitUntil("the two re-froze within 3 s", n"Check_TwoHeld", 0, 3.0f);
        Add_Step_WaitFrames("the attach composes the world pose", 2);
        Add_Step("two held, inside the walls, no second landing", n"Step_AssertRefrozen");
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
    private void Step_UnloadFirst(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_AllRefusalCount(_Platter), 0, "nothing was refused");
        Assert_Equals_Int(Get_LoadedCount(_Platter), 3, "three landings");

        _First = _Platter.Get_Held()[0];
        Unload(_Platter, _First);
    }

    UFUNCTION()
    private void Check_Unloaded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_UnloadedCount(_Platter) >= 1);
    }

    UFUNCTION()
    private void Step_AssertResettling(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Unloaded.Num() == 1 && _Unloaded[0].Piece == _First, "the unload named the first frozen piece");
        Assert_True(ck::Is_NOT_Valid(_First.TryGet_Platter()), "the unloaded piece names no platter");
        Assert_Equals_Int(_Platter.Get_HeldCount(), 0, "nothing stays frozen over the hole");
        Assert_Equals_Int(_Platter.Get_PendingCount(), 2, "the other two are settling again");
        for (const auto& Piece : _Pieces)
        {
            if (Piece == _First)
            { continue; }

            Assert_True(Piece.TryGet_Platter() == _Platter, f"[{Piece.ToString()}] is still the platter's");
            Assert_False(Get_IsSceneNode(Piece), f"[{Piece.ToString()}] let go of the root");
        }
    }

    UFUNCTION()
    private void Check_TwoHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Platter.Get_HeldCount() == 2);
    }

    UFUNCTION()
    private void Step_AssertRefrozen(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Platter.Get_Held().Num(), 2, "Get_Held has the two");
        Assert_Equals_Int(_Platter.Get_PendingCount(), 0, "nothing is settling");
        for (const auto& Piece : _Pieces)
        {
            if (Piece == _First)
            { continue; }

            Assert_True(Get_IsFrozenOn(_Platter, Piece), f"[{Piece.ToString()}] froze on the root again");
            Assert_True(Get_IsInsideWalls(_Platter, Piece), f"[{Piece.ToString()}] is still inside the walls");
        }

        Assert_Equals_Int(Get_LoadedCount(_Platter), 3, "the re-settle loaded nothing again");
        Assert_Equals_Int(Get_UnloadedCount(_Platter), 1, "one unload");
    }
}
