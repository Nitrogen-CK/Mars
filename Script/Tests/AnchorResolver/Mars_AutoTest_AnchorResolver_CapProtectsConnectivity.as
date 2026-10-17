class UMars_AutoTest_AnchorResolver_CapProtectsConnectivity : UMars_AutoTestRig_AnchorResolverPure
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the cap of 1 excludes the closure that cuts the hearth", n"Step_Cap");
        Add_Step("no reachable court at the minimum walk falls back to an open map", n"Step_Fallback");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Cap(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Plan = Make_FixturePlan();
        const auto Graph = utils_anchor_resolver::Make_Graph(Plan);
        Assert_Equals_Int(utils_anchor_resolver::Get_LegalClosureSets(Plan).Num(), 3, "legal sets are {}, {X1}, {X2}");

        const auto Both = FMars_AnchorConnectivity_Query(n"E", Make_Names(n"X1", n"X2"), Make_Names(n"K"));
        Assert_False(utils_anchor_resolver::Get_KeepsConnected(Graph, Both), "closing X1 and X2 cuts E from K");

        const auto One = FMars_AnchorConnectivity_Query(n"E", Make_Names(n"X1"), Make_Names(n"K"));
        Assert_True(utils_anchor_resolver::Get_KeepsConnected(Graph, One), "closing X1 alone keeps K");

        const auto Paths = utils_anchor_resolver::Get_ShortestPaths(Graph, FMars_AnchorGraph_Query(n"E", Make_Names(n"X1")));
        Assert_Equals_Float(utils_anchor_resolver::Get_Distance(Graph, Paths, n"K").Get(-1.0f), 3000.0f, 0.5f,
            "with X1 closed E reaches K the long way, 3000 cm");

        for (int32 Seed = 1; Seed <= 20; ++Seed)
        {
            const auto Result = Solve_Seed(Plan, Seed);
            Assert_True(Result.Closed.Num() <= 1, f"seed {Seed} closes at most one of X1/X2 ({Get_NamesText(Result.Closed)})");
        }
    }

    UFUNCTION()
    private void Step_Fallback(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Plan = Make_FixturePlan();
        Plan.QuarryMinWalkCm = 999999.0f;
        const auto Result = Solve_Seed(Plan, 5);
        Assert_True(Result.UsedFallback, "no court is far enough, so the solve falls back");
        Assert_Equals_Int(Result.Closed.Num(), 0, "the fallback closes nothing");
        Assert_True(Result.Quarry == n"FX-H", "the fallback quarry is the farthest court");
    }
}
