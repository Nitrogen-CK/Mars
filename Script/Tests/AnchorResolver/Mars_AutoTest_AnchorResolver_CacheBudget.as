// The cache budget: every seeded Warrens solve marks exactly MaxActiveCaches of the plan's cache anchors Active and the
// rest Dormant, the budget draws after the route solve (so a seed's entrance, closures and quarry are what they were
// without caches), and a row that needs a lever side is never drawn for an anchor without one.
class UMars_AutoTest_AnchorResolver_CacheBudget : UMars_AutoTestRig_AnchorResolverPure
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("seeds 1..20 keep exactly the budget of caches active", n"Step_Budget");
        Add_Step("the budget never moves the entrance, the closures or the quarry", n"Step_AfterRoute");
        Add_Step("a lever-side row is drawn only for an anchor with a lever side", n"Step_Need");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Budget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Plan = utils_anchor_resolver::Plan_Warrens();
        Assert_True(Plan.Caches.Num() >= 3, "the Warrens plan budgets at least three cache anchors");
        for (int32 Seed = 1; Seed <= 20; ++Seed)
        {
            const auto Result = Solve_Seed(Plan, Seed);
            auto Active = 0;
            auto Dormant = 0;
            for (const auto& Cache : Plan.Caches)
            {
                const auto Role = Result.Get_Role(Cache);
                if (Role == EMars_Anchor_Role::Active)
                { ++Active; }
                else if (Role == EMars_Anchor_Role::Dormant)
                { ++Dormant; }
            }
            Assert_True(Active == Plan.MaxActiveCaches, f"seed {Seed}: {Active} active caches (budget {Plan.MaxActiveCaches})");
            Assert_True(Active + Dormant == Plan.Caches.Num(), f"seed {Seed}: every cache has a role");
        }
    }

    UFUNCTION()
    private void Step_AfterRoute(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Plan = utils_anchor_resolver::Plan_Warrens();
        auto Stripped = Cast<UMars_AnchorPlan_Def>(NewObject(this, UMars_AnchorPlan_Def));
        Stripped.MapName = Plan.MapName;
        Stripped.Hearth = Plan.Hearth;
        Stripped.QuarryMinWalkCm = Plan.QuarryMinWalkCm;
        Stripped.Candidates = Plan.Candidates;
        Stripped.HistoryDepth = Plan.HistoryDepth;
        Stripped.Nodes = Plan.Nodes;
        Stripped.Links = Plan.Links;
        Stripped.Entrances = Plan.Entrances;
        Stripped.Courts = Plan.Courts;
        Stripped.Groups = Plan.Groups;
        _Plans.Add(Stripped);
        for (int32 Seed = 1; Seed <= 20; ++Seed)
        {
            const auto With = Solve_Seed(Plan, Seed);
            const auto Without = Solve_Seed(Stripped, Seed);
            Assert_True(With.Entrance == Without.Entrance, f"seed {Seed}: the entrance ignores the caches");
            Assert_True(With.Quarry == Without.Quarry, f"seed {Seed}: the quarry ignores the caches");
            Assert_True(With.Closed == Without.Closed, f"seed {Seed}: the closures ignore the caches");
        }
    }

    UFUNCTION()
    private void Step_Need(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Route = utils_anchor::Table_Route();
        auto NeedRow = -1;
        for (int32 Index = 0; Index < Route.Rows.Num(); ++Index)
        {
            if (Route.Rows[Index].Need == EMars_AnchorRow_Need::LeverSide)
            { NeedRow = Index; }
        }
        Assert_True(NeedRow >= 0, "the Route table has a row that needs a lever side");

        auto Query = FMars_AnchorRow_Query();
        Query.Role = EMars_Anchor_Role::Open;
        Query.AnchorId = GameplayTags::Anchor_Mars_Warrens_R1;
        Query.HasLeverSide = false;
        auto DrawnNeedRow = 0;
        auto DrawnNeedRowWithSide = 0;
        for (int32 Seed = 1; Seed <= 200; ++Seed)
        {
            Query.RunSeed = Seed;
            const auto Pick = utils_anchor_resolver::Pick_Row(Route, Query);
            Assert_True(Pick.RowIndex.IsSet(), f"seed {Seed}: an Open row exists without a lever side");
            if (Pick.RowIndex.Get(-1) == NeedRow)
            { ++DrawnNeedRow; }

            Query.HasLeverSide = true;
            const auto PickWithSide = utils_anchor_resolver::Pick_Row(Route, Query);
            if (PickWithSide.RowIndex.Get(-1) == NeedRow)
            { ++DrawnNeedRowWithSide; }

            Query.HasLeverSide = false;
        }
        Assert_True(DrawnNeedRow == 0, "an anchor without a lever side never draws the one-sided gate");
        Assert_True(DrawnNeedRowWithSide > 0, "an anchor with a lever side sometimes draws the one-sided gate");
    }
}
