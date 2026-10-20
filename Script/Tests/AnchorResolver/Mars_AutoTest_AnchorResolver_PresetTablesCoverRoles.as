// Every role the Warrens solve can assign has a row to draw in its family's preset table, so a placed Warrens anchor
// can never hit the resolver's "no row for role" ensure.
class UMars_AutoTest_AnchorResolver_PresetTablesCoverRoles : UMars_AutoTestRig_AnchorResolverPure
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("each preset table covers its family's roles with positive weights", n"Step_Tables");
        Add_Step("every role solved for Warrens over seeds 1..20 has an eligible row", n"Step_Solved");
        Run_Steps(InHandle);
    }

    private bool Has_Role(UMars_AnchorTable_Def InTable, EMars_Anchor_Role InRole) const
    {
        for (const auto& Row : InTable.Rows)
        {
            if (Row.Role == InRole)
            { return true; }
        }
        return false;
    }

    UFUNCTION()
    private void Step_Tables(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Route = utils_anchor::Table_Route();
        auto Hunt = utils_anchor::Table_Hunt();
        auto Spawn = utils_anchor::Table_Spawn();
        Assert_True(Has_Role(Route, EMars_Anchor_Role::Open) && Has_Role(Route, EMars_Anchor_Role::Closed), "Route has Open and Closed rows");
        Assert_True(Has_Role(Hunt, EMars_Anchor_Role::Quarry) && Has_Role(Hunt, EMars_Anchor_Role::Other), "Hunt has Quarry and Other rows");
        Assert_True(Has_Role(Spawn, EMars_Anchor_Role::Open) && Has_Role(Spawn, EMars_Anchor_Role::Closed), "Spawn has Open and Closed rows");

        auto Tables = TArray<UMars_AnchorTable_Def>();
        Tables.Add(Route);
        Tables.Add(Hunt);
        Tables.Add(Spawn);
        for (auto Table : Tables)
        {
            for (int32 Index = 0; Index < Table.Rows.Num(); ++Index)
            { Assert_True(Table.Rows[Index].Weight > 0.0f, f"{Table.GetName()} row {Index} has a positive weight"); }
        }

        Assert_True(Route.Rows[1].Script == UMars_Anchor_LeverGate_EntityScript, "Route row 1 is the lever-gate candidate");
        Assert_True(Route.Rows[2].Script == UMars_Anchor_Rubble_EntityScript, "Route row 2 is the rubble candidate");
        Assert_True(Route.Rows[3].Script == UMars_Anchor_OneSidedLeverGate_EntityScript && Route.Rows[3].Need == EMars_AnchorRow_Need::LeverSide,
            "Route row 3 is the one-sided lever gate and needs a lever side");

        // The pocket families: every table has an Other row (an unplanned anchor's draw), the cache table Active and
        // Dormant rows instead, and every weight is positive.
        const auto Pockets = utils_anchor::Get_PocketTables();
        Assert_True(Pockets.Num() == 7, "seven pocket tables");
        for (auto Table : Pockets)
        {
            if (Table.Family == EMars_Anchor_Family::Cache)
            { Assert_True(Has_Role(Table, EMars_Anchor_Role::Active) && Has_Role(Table, EMars_Anchor_Role::Dormant), "Cache has Active and Dormant rows"); }
            else
            { Assert_True(Has_Role(Table, EMars_Anchor_Role::Other), f"{Table.GetName()} has an Other row"); }

            for (int32 Index = 0; Index < Table.Rows.Num(); ++Index)
            { Assert_True(Table.Rows[Index].Weight > 0.0f, f"{Table.GetName()} row {Index} has a positive weight"); }
        }
    }

    UFUNCTION()
    private void Step_Solved(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Plan = utils_anchor_resolver::Plan_Warrens();
        for (int32 Seed = 1; Seed <= 20; ++Seed)
        {
            const auto Result = Solve_Seed(Plan, Seed);
            for (const auto& Entrance : Plan.Entrances)
            { Assert_True(Has_Role(utils_anchor::Table_Spawn(), Result.Get_Role(Entrance.AnchorId)), f"seed {Seed}: {Entrance.AnchorId.ToString()} has a Spawn row"); }

            for (const auto& Id : Plan.Groups[0].AnchorIds)
            { Assert_True(Has_Role(utils_anchor::Table_Route(), Result.Get_Role(Id)), f"seed {Seed}: {Id.ToString()} has a Route row"); }

            for (const auto& Court : Plan.Courts)
            { Assert_True(Has_Role(utils_anchor::Table_Hunt(), Result.Get_Role(Court.AnchorId)), f"seed {Seed}: {Court.AnchorId.ToString()} has a Hunt row"); }
        }
    }
}
