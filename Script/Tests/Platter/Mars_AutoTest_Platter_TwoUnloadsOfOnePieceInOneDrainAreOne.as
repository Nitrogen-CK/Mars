// Two controls may each ask for the same piece across a state change: two Unloads of one landed piece queued in one step
// drain as one. The piece comes off once (one OnUnloaded), it names no platter, and nothing ensures. A second piece stays
// on the platter (it re-settles over the hole).
class UMars_AutoTest_Platter_TwoUnloadsOfOnePieceInOneDrainAreOne : UMars_AutoTestRig_Platter
{
    private const FVector k_Origin = FVector(14000.0, -17000.0, -30000.0);

    private FCk_Handle_Platter _Platter;
    private FCk_Handle_FoodPiece _P;
    private FCk_Handle_FoodPiece _Q;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Platter = Build_Platter(InHandle, FTransform(FRotator(0.0, 25.0, 0.0), k_Origin), Make_PlatterSpec(2));
        _P = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 0.0, 0.0)), 0.5);
        _Q = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 50.0, 0.0)), 0.5);

        Add_Step_WaitUntil("P and Q are Ready", n"Check_Ready");
        Add_Step("load P and Q", n"Step_Load");
        Add_Step_WaitUntil("both landed", n"Check_Landed");
        Add_Step("unload P twice in one step", n"Step_UnloadTwice");
        Add_Step_WaitUntil("P was unloaded", n"Check_Unloaded");
        Add_Step_WaitFrames("a second unload would have drained by now", 3);
        Add_Step("P came off once; Q stays", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_P) && Get_HasReadied(_Q));
    }

    UFUNCTION()
    private void Step_Load(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Load(_Platter, _P);
        Load(_Platter, _Q);
    }

    UFUNCTION()
    private void Check_Landed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_LoadedCount(_Platter) >= 2 || Get_AllRefusalCount(_Platter) > 0);
    }

    UFUNCTION()
    private void Step_UnloadTwice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Platter.Get_HeldCount(), 2, "P and Q are on the platter");
        Unload(_Platter, _P);
        Unload(_Platter, _P);
    }

    UFUNCTION()
    private void Check_Unloaded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_UnloadedCount(_Platter) >= 1);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_AllRefusalCount(_Platter), 0, "nothing was refused");
        Assert_Equals_Int(Get_UnloadedCount(_Platter), 1, "one OnUnloaded for the two requests");
        Assert_True(_Unloaded.Num() == 1 && _Unloaded[0].Piece == _P, "the unload named P");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 1, "only Q is on the platter");
        Assert_True(ck::Is_NOT_Valid(_P.TryGet_Platter()), "P names no platter");
        Assert_False(Get_IsSceneNode(_P), "P no longer rides the platter");
        Assert_True(_Q.TryGet_Platter() == _Platter, "Q is still on the platter");
    }
}
