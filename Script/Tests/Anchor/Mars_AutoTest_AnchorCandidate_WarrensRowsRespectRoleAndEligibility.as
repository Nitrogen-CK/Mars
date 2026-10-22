// Read the actual placeable's table; no diagnostic pins or duplicate candidate implementations.
class UMars_AutoTest_AnchorCandidate_WarrensRowsRespectRoleAndEligibility : UMars_AutoTestRig_Anchor
{
    private FCk_Handle _Anchor;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Params = FMars_TESTONLY_AnchorSpawnParams();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Base);
        Params.AnchorId = GameplayTags::Anchor_Mars_Test_A;
        Params.Channel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Anchor.Test.A");
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Warrens_Anchor_Route_EntityScript, Params);
        _Anchor = Pending.Get_EntityUnderConstruction();

        Add_Step_WaitUntil("the Warrens route placeable composes its anchor", n"Check_Ready");
        Add_Step("the table contains exactly arch, rubble and eligible scout latch", n"Step_Rows");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsAnchorReady(_Anchor));
    }

    UFUNCTION()
    private void Step_Rows(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Table = _Anchor.As_Anchor().Get_Table();
        Assert_True(ck::IsValid(Table), "the map-specific table resolves from the instantiated route");
        if (ck::Is_NOT_Valid(Table))
        { return; }

        Assert_Equals_Int(Table.Rows.Num(), 3, "Warrens has three route rows");
        if (Table.Rows.Num() != 3)
        { return; }

        Assert_True(Table.Rows[0].Script == nullptr && Table.Rows[0].Role == EMars_Anchor_Role::Open, "row 0 is the open arch");
        Assert_True(Table.Rows[1].Script == UMars_Anchor_Rubble_EntityScript && Table.Rows[1].Role == EMars_Anchor_Role::Closed, "row 1 is closed rubble");
        Assert_True(Table.Rows[2].Script == UMars_Anchor_OneSidedLeverGate_EntityScript && Table.Rows[2].Need == EMars_AnchorRow_Need::LeverSide, "row 2 is the eligible far-side latch");
        Assert_Equals_Float(Table.Rows[0].Weight, 6.0f, 0.001f, "arch weight");
        Assert_Equals_Float(Table.Rows[1].Weight, 2.0f, 0.001f, "rubble weight");
        Assert_Equals_Float(Table.Rows[2].Weight, 4.0f, 0.001f, "scout latch weight");

        auto SawArch = false;
        auto SawLatch = false;
        auto Query = FMars_AnchorRow_Query();
        Query.AnchorId = GameplayTags::Anchor_Mars_Test_A;
        for (int32 Seed = 1; Seed <= 64; ++Seed)
        {
            Query.RunSeed = Seed;
            Query.Role = EMars_Anchor_Role::Closed;
            Query.HasLeverSide = false;
            Assert_Equals_Int(utils_anchor_resolver::Pick_Row(Table, Query).RowIndex.Get(-1), 1, f"seed {Seed}: Closed draws rubble");

            Query.Role = EMars_Anchor_Role::Open;
            Assert_Equals_Int(utils_anchor_resolver::Pick_Row(Table, Query).RowIndex.Get(-1), 0, f"seed {Seed}: no lever side draws an arch");

            Query.HasLeverSide = true;
            const auto Pick = utils_anchor_resolver::Pick_Row(Table, Query);
            const auto Row = Pick.RowIndex.Get(-1);
            Assert_True(Row == 0 || Row == 2, f"seed {Seed}: eligible Open draws only arch or scout latch");
            Assert_False(Pick.Pinned || Pick.RoleMismatch, "the role solver remains authoritative");
            SawArch = SawArch || Row == 0;
            SawLatch = SawLatch || Row == 2;
        }
        Assert_True(SawArch && SawLatch, "eligible routes draw both open semantics over seeds 1..64");

        Query.Role = EMars_Anchor_Role::Other;
        Assert_False(utils_anchor_resolver::Pick_Row(Table, Query).RowIndex.IsSet(), "an incompatible role draws no row");
    }
}
