// Mars_AnchorTable_Test: row 0 A (Open), row 1 B (Closed), row 2 Nothing (Open), row 3 A (Other).
class UMars_AutoTest_AnchorResolver_PickRow : UMars_AutoTestRig_Anchor
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("rows are drawn only from the solved role, deterministically", n"Step_Roles");
        Add_Step("a pin wins, is marked, and reports a role mismatch; an out-of-range pin is ignored", n"Step_Pins");
        Run_Steps(InHandle);
    }

    private FMars_AnchorRow_Pick Pick(EMars_Anchor_Role InRole, int32 InSeed, TOptional<int32> InPin) const
    {
        auto Query = FMars_AnchorRow_Query();
        Query.Role = InRole;
        Query.RunSeed = InSeed;
        Query.AnchorId = n"P";
        Query.PinnedRow = InPin;
        return utils_anchor_resolver::Pick_Row(utils_anchor::Table_Test(), Query);
    }

    UFUNCTION()
    private void Step_Roles(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (int32 Seed = 1; Seed <= 20; ++Seed)
        { Assert_Equals_Int(Pick(EMars_Anchor_Role::Closed, Seed, TOptional<int32>()).RowIndex.Get(-1), 1, f"seed {Seed}: Closed draws row 1"); }

        auto SawZero = false;
        auto SawTwo = false;
        for (int32 Seed = 1; Seed <= 40; ++Seed)
        {
            const auto Row = Pick(EMars_Anchor_Role::Open, Seed, TOptional<int32>()).RowIndex.Get(-1);
            Assert_True(Row == 0 || Row == 2, f"seed {Seed}: Open draws only rows 0 or 2 (got {Row})");
            SawZero = SawZero || Row == 0;
            SawTwo = SawTwo || Row == 2;
        }
        Assert_True(SawZero && SawTwo, "both Open rows are drawn over seeds 1..40");

        Assert_Equals_Int(Pick(EMars_Anchor_Role::None, 3, TOptional<int32>()).RowIndex.Get(-1), 3, "an unplanned anchor draws the Other row");

        const auto First = Pick(EMars_Anchor_Role::Open, 11, TOptional<int32>()).RowIndex.Get(-1);
        const auto Second = Pick(EMars_Anchor_Role::Open, 11, TOptional<int32>()).RowIndex.Get(-1);
        Assert_Equals_Int(First, Second, "the same query draws the same row");
    }

    UFUNCTION()
    private void Step_Pins(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Pinned = Pick(EMars_Anchor_Role::Open, 5, TOptional<int32>(1));
        Assert_Equals_Int(Pinned.RowIndex.Get(-1), 1, "the pinned row wins");
        Assert_True(Pinned.Pinned, "the pick is marked pinned");
        Assert_True(Pinned.RoleMismatch, "row 1 is Closed, so the pin contradicts the Open role");

        const auto OutOfRange = Pick(EMars_Anchor_Role::Closed, 5, TOptional<int32>(9));
        Assert_False(OutOfRange.Pinned, "an out-of-range pin is ignored");
        Assert_Equals_Int(OutOfRange.RowIndex.Get(-1), 1, "and the role draw applies");
    }
}
