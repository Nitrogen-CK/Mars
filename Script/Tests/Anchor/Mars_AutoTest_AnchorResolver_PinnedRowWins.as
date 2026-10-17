// Test (d) of the anchor slice: a pinned row beats the solved role, the ledger says so, and nothing warns (the harness
// fails the test on any Warning or Error line).
class UMars_AutoTest_AnchorResolver_PinnedRowWins : UMars_AutoTestRig_Anchor
{
    default _TimeoutSeconds = 15.0f;

    private FCk_Handle _Resolver;
    private FCk_Handle _Anchor;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Resolver = Spawn_Resolver(InHandle, Make_Result(7));
        _Anchor = Spawn_Anchor(InHandle, n"T-A", FVector(0.0, 4000.0, 0.0), TOptional<int32>(1));
        Add_Step_WaitUntil("the pinned anchor resolves", n"Check_Resolved");
        Add_Step("the pin won and the ledger marks it", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Resolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsResolverReady(_Resolver) && Get_IsSpawned(_Anchor) && _Resolver.As_AnchorResolver().TryGet_LedgerEntry(n"T-A").IsSet());
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Entry = _Resolver.As_AnchorResolver().TryGet_LedgerEntry(n"T-A").GetValue();
        Assert_True(Entry.Role == EMars_Anchor_Role::Open, "the solved role was Open");
        Assert_Equals_Int(Entry.RowIndex, 1, "the pinned row 1 was used");
        Assert_True(Entry.Pinned, "the ledger marks the pin");
        Assert_True(Entry.RoleMismatch, "the ledger marks that row 1 (Closed) contradicts the role");
        Assert_Equals_Int(Get_OwnedTagged(_Anchor, n"TAG_MarsTestAnchorCandidateB").Num(), 1, "the anchor spawned candidate B");
    }
}
