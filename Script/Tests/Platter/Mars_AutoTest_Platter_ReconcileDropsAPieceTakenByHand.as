// Something that knows nothing of platters takes a frozen piece off the root (a hand picking it up: here a plain scene-node
// detach). Within 2 frames the platter's reconcile notices: OnUnloaded fires for that piece, its membership is gone and the
// occupancy drops by one; the piece left behind settles again.
class UMars_AutoTest_Platter_ReconcileDropsAPieceTakenByHand : UMars_AutoTestRig_Platter
{
    private const FVector k_Origin = FVector(14000.0, -21000.0, -30000.0);

    private FCk_Handle_Platter _Platter;
    private FCk_Handle_FoodPiece _P;
    private FCk_Handle_FoodPiece _Q;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Platter = Build_Platter(InHandle, FTransform(FRotator::ZeroRotator, k_Origin), Make_PlatterSpec(2));
        _P = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 0.0, 0.0)), 0.5);
        _Q = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 30.0, 0.0)), 0.5);

        Add_Step_WaitUntil("P and Q are Ready", n"Check_Ready");
        Add_Step("load P and Q", n"Step_Load");
        Add_Step_WaitUntil("both froze into the pile", n"Check_BothHeld");
        Add_Step("take P off the root behind the platter's back", n"Step_DetachP");
        Add_Step_WaitFrames("the reconcile runs", 2);
        Add_Step("P left the ledger with OnUnloaded; Q is still the platter's", n"Step_Assert");
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
    private void Check_BothHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Platter.Get_HeldCount() == 2 || Get_AllRefusalCount(_Platter) > 0);
    }

    UFUNCTION()
    private void Step_DetachP(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Platter.Get_Occupancy(), 2, "P and Q are on the platter");

        FCk_Handle PEntity = _P;
        utils_scene_node::Request_Detach(PEntity.As_SceneNode());
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_UnloadedCount(_Platter), 1, "OnUnloaded fired once");
        Assert_True(_Unloaded.Num() == 1 && _Unloaded[0].Piece == _P, "the unload named P");
        Assert_True(ck::Is_NOT_Valid(_P.TryGet_Platter()), "P names no platter");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 1, "the occupancy dropped to one");
        Assert_False(_Platter.Get_Held().Contains(_P), "P is not held");
        Assert_True(_Q.TryGet_Platter() == _Platter, "Q is still the platter's");
    }
}
