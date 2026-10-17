class UMars_AutoTest_AnchorResolver_LateAnchorResolves : UMars_AutoTestRig_Anchor
{
    default _TimeoutSeconds = 15.0f;

    private FCk_Handle _Resolver;
    private FCk_Handle _Anchor;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Resolver = Spawn_Resolver(InHandle, Make_Result(9));
        Add_Step_WaitUntil("the resolver is up before any anchor exists", n"Check_ResolverReady");
        Add_Step_WaitFrames("let the resolver's query run with no anchors", 10);
        Add_Step("an anchor appears late", n"Step_SpawnLate");
        Add_Step_WaitUntil("the late anchor still resolves", n"Check_Resolved");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_ResolverReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsResolverReady(_Resolver));
    }

    UFUNCTION()
    private void Step_SpawnLate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Owner = InHandle;
        _Anchor = Spawn_Anchor(Owner, n"T-A", FVector(0.0, 2000.0, 0.0), TOptional<int32>());
    }

    UFUNCTION()
    private void Check_Resolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsSpawned(_Anchor) && _Resolver.As_AnchorResolver().TryGet_LedgerEntry(n"T-A").IsSet());
    }
}
