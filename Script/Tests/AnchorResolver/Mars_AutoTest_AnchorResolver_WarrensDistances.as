// Expected values: docs/plans/anchor-slice/fixtures/warrens_expected.json (computed from the frozen data's integer link
// costs). They change only if Tools/LevelDesign/anchor_plans/data/warrens.json changes.
class UMars_AutoTest_AnchorResolver_WarrensDistances : UMars_AutoTestRig_AnchorResolverPure
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("open-map walk distances from every entrance match the expected centimetres", n"Step_Distances");
        Run_Steps(InHandle);
    }

    private void Expect_Row(const FMars_AnchorGraph& InGraph, FName InFrom, const TArray<float32>& InExpected)
    {
        const auto Paths = utils_anchor_resolver::Get_ShortestPaths(InGraph, FMars_AnchorGraph_Query(InFrom, TArray<FGameplayTag>()));
        auto Targets = TArray<FName>();
        Targets.Add(n"K");
        Targets.Add(n"H1");
        Targets.Add(n"H2");
        Targets.Add(n"RS");
        for (int32 Index = 0; Index < Targets.Num(); ++Index)
        {
            const auto Distance = utils_anchor_resolver::Get_Distance(InGraph, Paths, Targets[Index]);
            Assert_True(Distance.IsSet(), f"{InFrom.ToString()} reaches {Targets[Index].ToString()}");
            Assert_Equals_Float(Distance.Get(-1.0f), InExpected[Index], 1.0f,
                f"{InFrom.ToString()} -> {Targets[Index].ToString()} walks {InExpected[Index]} cm");
        }
    }

    private TArray<float32> Make_Row(float32 InHearth, float32 InH1, float32 InH2, float32 InRs) const
    {
        auto Row = TArray<float32>();
        Row.Add(InHearth);
        Row.Add(InH1);
        Row.Add(InH2);
        Row.Add(InRs);
        return Row;
    }

    UFUNCTION()
    private void Step_Distances(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Graph = utils_anchor_resolver::Make_Graph(utils_anchor_resolver::Plan_Warrens());
        Assert_Equals_Int(Graph.LinkA.Num(), 29, "the graph keeps all 29 links");
        Expect_Row(Graph, n"S1", Make_Row(5582.0f, 2470.0f, 7993.0f, 8953.0f));
        Expect_Row(Graph, n"S2", Make_Row(5829.0f, 6470.0f, 7319.0f, 3956.0f));
        Expect_Row(Graph, n"S3", Make_Row(7176.0f, 10288.0f, 7168.0f, 3805.0f));
        Expect_Row(Graph, n"S4", Make_Row(6044.0f, 8402.0f, 4899.0f, 5678.0f));
        Expect_Row(Graph, n"S5", Make_Row(6390.0f, 4918.0f, 8024.0f, 9761.0f));
    }
}
