// The anchor solve without a world: plans, graphs and seeded solves only.
UCLASS(Abstract)
class UMars_AutoTestRig_AnchorResolverPure : UCk_AutoTest_Base
{
    default _AutoStageOriginField = false;

    UPROPERTY()
    protected TArray<UMars_AnchorPlan_Def> _Plans;

    // The negative control: two routes from E to K, each closable, under one cap of 1. Closing both cuts the hearth.
    //   E -1000- A -1000- K -1000- Q
    //   E -1500- B -1500- K
    protected UMars_AnchorPlan_Def Make_FixturePlan()
    {
        auto Plan = Cast<UMars_AnchorPlan_Def>(NewObject(this, UMars_AnchorPlan_Def));
        Plan.MapName = n"Fixture";
        Plan.Hearth = n"K";
        Plan.QuarryMinWalkCm = 0.0f;
        Plan.Nodes.Add(FMars_AnchorPlan_Node(n"E", FVector(0.0, 0.0, 0.0)));
        Plan.Nodes.Add(FMars_AnchorPlan_Node(n"A", FVector(1000.0, 0.0, 0.0)));
        Plan.Nodes.Add(FMars_AnchorPlan_Node(n"B", FVector(0.0, 1500.0, 0.0)));
        Plan.Nodes.Add(FMars_AnchorPlan_Node(n"K", FVector(2000.0, 0.0, 0.0)));
        Plan.Nodes.Add(FMars_AnchorPlan_Node(n"Q", FVector(3000.0, 0.0, 0.0)));
        Plan.Links.Add(FMars_AnchorPlan_Link(n"E", n"A", 1000.0f, GameplayTags::Anchor_Mars_Test_Fixture_X1));
        Plan.Links.Add(FMars_AnchorPlan_Link(n"A", n"K", 1000.0f, FGameplayTag()));
        Plan.Links.Add(FMars_AnchorPlan_Link(n"E", n"B", 1500.0f, GameplayTags::Anchor_Mars_Test_Fixture_X2));
        Plan.Links.Add(FMars_AnchorPlan_Link(n"B", n"K", 1500.0f, FGameplayTag()));
        Plan.Links.Add(FMars_AnchorPlan_Link(n"K", n"Q", 1000.0f, FGameplayTag()));
        Plan.Entrances.Add(FMars_AnchorPlan_Entrance(GameplayTags::Anchor_Mars_Test_Fixture_Entrance, n"Fixture.Entrance", n"E"));
        Plan.Courts.Add(FMars_AnchorPlan_Court(GameplayTags::Anchor_Mars_Test_Fixture_Court, n"Q"));
        auto Group = FMars_AnchorPlan_Group(n"G", 1);
        Group.AnchorIds.Add(GameplayTags::Anchor_Mars_Test_Fixture_X1);
        Group.AnchorIds.Add(GameplayTags::Anchor_Mars_Test_Fixture_X2);
        Plan.Groups.Add(Group);
        _Plans.Add(Plan);
        return Plan;
    }

    protected TArray<FName> Make_Names(FName InA, FName InB = NAME_None) const
    {
        auto Names = TArray<FName>();
        if (InA.IsNone() == false)
        { Names.Add(InA); }

        if (InB.IsNone() == false)
        { Names.Add(InB); }

        return Names;
    }

    protected TArray<FGameplayTag> Make_Tags(FGameplayTag InA, FGameplayTag InB = FGameplayTag()) const
    {
        auto Tags = TArray<FGameplayTag>();
        if (InA.IsValid())
        { Tags.Add(InA); }

        if (InB.IsValid())
        { Tags.Add(InB); }

        return Tags;
    }

    protected FString Get_TagsText(const TArray<FGameplayTag>& InTags) const
    {
        auto Text = "";
        for (const auto& Each : InTags)
        { Text = f"{Text}{Each.ToString()} "; }

        return Text;
    }

    protected FMars_AnchorRun_Result Solve_Seed(UMars_AnchorPlan_Def InPlan, int32 InSeed) const
    {
        auto Input = FMars_AnchorRun_Input();
        Input.Seed = InSeed;
        return utils_anchor_resolver::Solve(InPlan, Input);
    }

    protected FName Get_EntranceNode(UMars_AnchorPlan_Def InPlan, FGameplayTag InEntrance) const
    {
        for (const auto& Entrance : InPlan.Entrances)
        {
            if (Entrance.AnchorId == InEntrance)
            { return Entrance.Node; }
        }
        return NAME_None;
    }

    protected FName Get_CourtNode(UMars_AnchorPlan_Def InPlan, FGameplayTag InCourt) const
    {
        for (const auto& Court : InPlan.Courts)
        {
            if (Court.AnchorId == InCourt)
            { return Court.Node; }
        }
        return NAME_None;
    }
}
