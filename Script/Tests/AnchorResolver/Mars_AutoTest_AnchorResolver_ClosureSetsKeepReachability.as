class UMars_AutoTest_AnchorResolver_ClosureSetsKeepReachability : UMars_AutoTestRig_AnchorResolverPure
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("all 64 legal Warrens closure sets keep every entrance connected to the hearth and every court", n"Step_Sets");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Sets(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Plan = utils_anchor_resolver::Plan_Warrens();
        const auto Graph = utils_anchor_resolver::Make_Graph(Plan);
        const auto Sets = utils_anchor_resolver::Get_LegalClosureSets(Plan);
        Assert_Equals_Int(Sets.Num(), 64, "sizes 0..3 of 7 route anchors give 1 + 7 + 21 + 35 sets");

        auto MustReach = TArray<FName>();
        MustReach.Add(Plan.Hearth);
        for (const auto& Court : Plan.Courts)
        { MustReach.Add(Court.Node); }

        auto Failures = 0;
        auto FirstFailure = "";
        for (const auto& Set : Sets)
        {
            for (const auto& Entrance : Plan.Entrances)
            {
                const auto Query = FMars_AnchorConnectivity_Query(Entrance.Node, Set.Closed, MustReach);
                if (utils_anchor_resolver::Get_KeepsConnected(Graph, Query))
                { continue; }

                if (Failures == 0)
                { FirstFailure = f"{Entrance.AnchorId.ToString()} with [{Get_NamesText(Set.Closed)}] closed"; }
                ++Failures;
            }
        }
        Assert_Equals_Int(Failures, 0, f"every legal set keeps everything reachable (first failure: {FirstFailure})");
    }
}
