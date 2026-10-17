class UMars_AutoTest_AnchorResolver_QuarryRespectsMinWalk : UMars_AutoTestRig_AnchorResolverPure
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the quarry court is at least the plan's QuarryMinWalkCm from the entrance under the run's closures", n"Step_MinWalk");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_MinWalk(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Plan = utils_anchor_resolver::Plan_Warrens();
        const auto Graph = utils_anchor_resolver::Make_Graph(Plan);
        for (int32 Seed = 1; Seed <= 20; ++Seed)
        {
            const auto Result = Solve_Seed(Plan, Seed);
            const auto From = Get_EntranceNode(Plan, Result.Entrance);
            const auto Paths = utils_anchor_resolver::Get_ShortestPaths(Graph, FMars_AnchorGraph_Query(From, Result.Closed));
            const auto Distance = utils_anchor_resolver::Get_Distance(Graph, Paths, Get_CourtNode(Plan, Result.Quarry)).Get(-1.0f);
            Assert_True(Distance >= Plan.QuarryMinWalkCm,
                f"seed {Seed}: {Result.Entrance.ToString()} -> {Result.Quarry.ToString()} walks {Distance} cm, below {Plan.QuarryMinWalkCm}");
        }
    }
}
