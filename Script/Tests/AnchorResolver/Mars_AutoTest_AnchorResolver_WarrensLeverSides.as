// The Warrens plan authors a lever node on every route gate that has a crawl beside it, and only there: a lever node is
// an end of its closable link, the four crawl gates (R2, R3, R5, R6) have one, the three others (R1, R4, R7) none.
class UMars_AutoTest_AnchorResolver_WarrensLeverSides : UMars_AutoTestRig_AnchorResolverPure
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("every lever node is an end of a closable link", n"Step_Ends");
        Add_Step("the crawl gates have a lever node and the others do not", n"Step_Which");
        Run_Steps(InHandle);
    }

    private TOptional<FName> Find_LeverNode(const UMars_AnchorPlan_Def InPlan, FGameplayTag InAnchorId) const
    {
        for (const auto& Link : InPlan.Links)
        {
            if (Link.ClosedBy == InAnchorId)
            { return Link.LeverNode.IsNone() ? TOptional<FName>() : TOptional<FName>(Link.LeverNode); }
        }
        return TOptional<FName>();
    }

    UFUNCTION()
    private void Step_Ends(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Plan = utils_anchor_resolver::Plan_Warrens();
        Assert_True(Plan.Validate().IsValid(), "the Warrens plan validates with its lever nodes");
        for (const auto& Link : Plan.Links)
        {
            if (Link.LeverNode.IsNone())
            { continue; }

            Assert_True(Link.ClosedBy.IsValid(), f"{Link.A}-{Link.B}: a lever node belongs to a closable link");
            Assert_True(Link.LeverNode == Link.A || Link.LeverNode == Link.B, f"{Link.A}-{Link.B}: the lever node is one of its ends");
        }
    }

    UFUNCTION()
    private void Step_Which(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Plan = utils_anchor_resolver::Plan_Warrens();
        Assert_True(Find_LeverNode(Plan, GameplayTags::Anchor_Mars_Warrens_R2).Get(NAME_None) == n"CH", "R2's lever is on the Chime Hall side");
        Assert_True(Find_LeverNode(Plan, GameplayTags::Anchor_Mars_Warrens_R3).Get(NAME_None) == n"CE", "R3's lever is in the Salt Cellar");
        Assert_True(Find_LeverNode(Plan, GameplayTags::Anchor_Mars_Warrens_R5).Get(NAME_None) == n"BR", "R5's lever is on the Bridge");
        Assert_True(Find_LeverNode(Plan, GameplayTags::Anchor_Mars_Warrens_R6).Get(NAME_None) == n"ci2", "R6's lever is on the Cistern side");
        Assert_False(Find_LeverNode(Plan, GameplayTags::Anchor_Mars_Warrens_R1).IsSet(), "R1 has no crawl and no lever node");
        Assert_False(Find_LeverNode(Plan, GameplayTags::Anchor_Mars_Warrens_R4).IsSet(), "R4 has no crawl and no lever node");
        Assert_False(Find_LeverNode(Plan, GameplayTags::Anchor_Mars_Warrens_R7).IsSet(), "R7 has no crawl and no lever node");
    }
}
