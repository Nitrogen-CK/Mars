class UMars_AutoTest_AnchorResolver_SolveDeterministic : UMars_AutoTestRig_AnchorResolverPure
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the same seed gives the same run and a well-formed result", n"Step_Same");
        Add_Step("different seeds pick different entrances, even consecutive ones", n"Step_Variety");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Same(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Plan = utils_anchor_resolver::Plan_Warrens();
        const auto First = Solve_Seed(Plan, 7);
        const auto Second = Solve_Seed(Plan, 7);
        Assert_True(First.Entrance == Second.Entrance, "same entrance");
        Assert_True(First.Quarry == Second.Quarry, "same quarry");
        Assert_True(First.Closed == Second.Closed, "same closures");
        Assert_True(First.WalkedLinks == Second.WalkedLinks, "same walked links");
        Assert_Equals_Float(First.Divergence, Second.Divergence, 0.0001f, "same divergence");

        Assert_Equals_Int(First.Roles.Num(), 15, "15 planned anchors get a role");
        Assert_True(First.Closed.Num() <= 3, "at most 3 route anchors close");
        for (const auto& Id : First.Closed)
        { Assert_True(First.Get_Role(Id) == EMars_Anchor_Role::Closed, f"{Id.ToString()} is in Closed and has role Closed"); }

        auto Quarries = 0;
        auto OpenEntrances = 0;
        for (const auto& Entrance : Plan.Entrances)
        {
            if (First.Get_Role(Entrance.AnchorId) == EMars_Anchor_Role::Open)
            { ++OpenEntrances; }
        }
        for (const auto& Court : Plan.Courts)
        {
            if (First.Get_Role(Court.AnchorId) == EMars_Anchor_Role::Quarry)
            { ++Quarries; }
        }
        Assert_Equals_Int(Quarries, 1, "exactly one quarry court");
        Assert_Equals_Int(OpenEntrances, 1, "exactly one open entrance");
        Assert_True(First.Get_Role(First.Entrance) == EMars_Anchor_Role::Open, "the chosen entrance is the open one");
    }

    UFUNCTION()
    private void Step_Variety(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Plan = utils_anchor_resolver::Plan_Warrens();
        auto Entrances = TArray<FGameplayTag>();
        for (int32 Seed = 1; Seed <= 10; ++Seed)
        { Entrances.AddUnique(Solve_Seed(Plan, Seed).Entrance); }

        Assert_True(Entrances.Num() >= 2, f"seeds 1..10 use {Entrances.Num()} distinct entrances");

        // A raw FRandomStream seed gave Warrens.S2 for seeds 1..4 (its first draw barely moves between consecutive seeds).
        auto Consecutive = TArray<FGameplayTag>();
        for (int32 Seed = 1; Seed <= 4; ++Seed)
        { Consecutive.AddUnique(Solve_Seed(Plan, Seed).Entrance); }

        Assert_True(Consecutive.Num() >= 2, f"consecutive seeds 1..4 use {Consecutive.Num()} distinct entrances");
    }
}
