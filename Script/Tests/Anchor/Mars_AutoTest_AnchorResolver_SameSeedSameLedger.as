// Test (a) of the anchor slice: the resolver driver turns one result into the same ledger and the same candidates every
// time, whoever composes first.
class UMars_AutoTest_AnchorResolver_SameSeedSameLedger : UMars_AutoTestRig_Anchor
{
    default _TimeoutSeconds = 20.0f;

    private FCk_Handle _Resolver;
    private TArray<FCk_Handle> _Anchors;
    private TArray<FString> _FirstLedger;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("spawn a resolver for seed 42 and anchors T-A, T-B, T-C", n"Step_Spawn");
        Add_Step_WaitUntil("all three anchors resolve", n"Check_AllResolved");
        Add_Step("record the ledger and check the candidates", n"Step_RecordFirst");
        Add_Step("destroy the resolver and the anchors", n"Step_Destroy");
        Add_Step_WaitUntil("nothing of the first pass remains", n"Check_Gone");
        Add_Step("spawn the same setup again", n"Step_Spawn");
        Add_Step_WaitUntil("all three anchors resolve again", n"Check_AllResolved");
        Add_Step("the second ledger is identical", n"Step_Compare");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Spawn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Owner = InHandle;
        _Anchors.Reset();
        // Three placements, three channels: the resolver ensures on anchors that share one.
        _Anchors.Add(Spawn_Anchor(Owner, Make_AnchorParams(n"T-A", FVector(0.0, 0.0, 0.0), n"Mechanism.Channel.Anchor.Test.A")));
        _Anchors.Add(Spawn_Anchor(Owner, Make_AnchorParams(n"T-B", FVector(500.0, 0.0, 0.0), n"Mechanism.Channel.Anchor.Test.B")));
        _Anchors.Add(Spawn_Anchor(Owner, Make_AnchorParams(n"T-C", FVector(1000.0, 0.0, 0.0), n"Mechanism.Channel.Anchor.Test.C")));
        _Resolver = Spawn_Resolver(Owner, Make_Result(42));
    }

    private FMars_TESTONLY_AnchorSpawnParams Make_AnchorParams(FName InId, FVector InOffset, FName InChannel) const
    {
        auto Params = FMars_TESTONLY_AnchorSpawnParams();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Base + InOffset);
        Params.AnchorId = InId;
        Params.Channel = GameplayTags::ResolveGameplayTag(InChannel);
        return Params;
    }

    UFUNCTION()
    private void Check_AllResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Ready = Get_IsResolverReady(_Resolver) && _Resolver.As_AnchorResolver().Get_Ledger().Num() == 3;
        for (const auto& Anchor : _Anchors)
        { Ready = Ready && Get_IsSpawned(Anchor); }

        auto Res = OutResult;
        Res.Set(Ready);
    }

    private TArray<FString> Describe_Ledger() const
    {
        auto Lines = TArray<FString>();
        for (const auto& Entry : _Resolver.As_AnchorResolver().Get_Ledger())
        { Lines.Add(f"{Entry.AnchorId.ToString()}:{Entry.RowIndex}:{Entry.ScriptName}"); }

        return Lines;
    }

    UFUNCTION()
    private void Step_RecordFirst(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _FirstLedger = Describe_Ledger();
        const auto Resolver = _Resolver.As_AnchorResolver();
        const auto EntryB = Resolver.TryGet_LedgerEntry(n"T-B");
        Assert_True(EntryB.IsSet() && EntryB.GetValue().RowIndex == 1, "T-B (Closed) resolved to row 1");
        Assert_True(EntryB.IsSet() && EntryB.GetValue().ScriptName.Contains("CandidateB"), "T-B's ledger names candidate B");
        Assert_Equals_Int(Count_Tagged(InHandle, n"TAG_MarsTestAnchorCandidateB"), 1, "exactly one candidate B exists");
        Assert_Equals_Int(Resolver.Get_UnmatchedPlannedIds().Num(), 0, "every planned id resolved");
    }

    UFUNCTION()
    private void Step_Destroy(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (const auto& Anchor : _Anchors)
        { utils_entity_lifetime::Request_DestroyEntity(Anchor); }

        utils_entity_lifetime::Request_DestroyEntity(_Resolver);
    }

    UFUNCTION()
    private void Check_Gone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Count_Tagged(InHandle, n"TAG_MarsAnchorResolver") == 0 && Count_Tagged(InHandle, n"TAG_MarsAnchor") == 0
            && Count_Tagged(InHandle, n"TAG_MarsTestAnchorCandidateA") == 0 && Count_Tagged(InHandle, n"TAG_MarsTestAnchorCandidateB") == 0);
    }

    UFUNCTION()
    private void Step_Compare(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Second = Describe_Ledger();
        Assert_Equals_Int(Second.Num(), _FirstLedger.Num(), "both ledgers have three rows");
        for (int32 Index = 0; Index < Math::Min(Second.Num(), _FirstLedger.Num()); ++Index)
        { Assert_Equals_String(Second[Index], _FirstLedger[Index], f"ledger row {Index} is identical"); }
    }
}
