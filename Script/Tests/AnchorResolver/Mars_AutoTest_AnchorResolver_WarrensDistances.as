// Expected values: Dijkstra over the frozen data's integer link costs (Tools/LevelDesign/anchor_plans/data/warrens.json,
// Warrens v5 "The Well", written by design_warrens_v5.py). They change only if that data changes. The hunt courts are
// H1 (node H1, the Charnel Court arena), H2 (node H2, the Pit) and H3 (node CH, the Chime Hall).
// docs/plans/anchor-slice/fixtures/warrens_expected.json still holds the v3 numbers.
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
        Targets.Add(n"CH");
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
        Assert_Equals_Int(Graph.LinkA.Num(), 49, "the graph keeps all 49 links");
        Expect_Row(Graph, n"S1", Make_Row(5023.0f, 2627.0f, 12339.0f, 10769.0f));
        Expect_Row(Graph, n"S2", Make_Row(7529.0f, 9916.0f, 10735.0f, 3866.0f));
        Expect_Row(Graph, n"S3", Make_Row(8339.0f, 10788.0f, 9205.0f, 2336.0f));
        Expect_Row(Graph, n"S4", Make_Row(4376.0f, 6825.0f, 11692.0f, 7812.0f));
        Expect_Row(Graph, n"S5", Make_Row(6397.0f, 6010.0f, 13713.0f, 9833.0f));
    }
}
