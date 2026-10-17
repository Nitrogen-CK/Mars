class UMars_AutoTest_AnchorResolver_PlanRejectsBadData : UMars_AutoTestRig_AnchorResolverPure
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the fixture validates and each broken copy fails with its exact message", n"Step_Reject");
        Run_Steps(InHandle);
    }

    private void Expect_Error(UMars_AnchorPlan_Def InPlan, FString InExpected)
    { Assert_Equals_String(InPlan.Validate().Get_Error(), InExpected, f"rejected with: {InExpected}"); }

    UFUNCTION()
    private void Step_Reject(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Make_FixturePlan().Validate().IsValid(), "the unmodified fixture validates");

        auto BadHearth = Make_FixturePlan();
        BadHearth.Hearth = n"Nope";
        Expect_Error(BadHearth, "the hearth is not a node");

        auto BadEndpoint = Make_FixturePlan();
        BadEndpoint.Links.Add(FMars_AnchorPlan_Link(n"K", n"Nope", 100.0f, FGameplayTag()));
        Expect_Error(BadEndpoint, "a link names an unknown node");

        auto BadCost = Make_FixturePlan();
        BadCost.Links[1].CostCm = 0.0f;
        Expect_Error(BadCost, "a link cost must be positive");

        auto Ungrouped = Make_FixturePlan();
        Ungrouped.Links.Add(FMars_AnchorPlan_Link(n"E", n"K", 5000.0f, GameplayTags::Anchor_Mars_Test_C));
        Expect_Error(Ungrouped, "a closable link's anchor is in no group");

        auto BadCap = Make_FixturePlan();
        BadCap.Groups[0].MaxClosed = 3;
        Expect_Error(BadCap, "a group cap is out of range");
    }
}
