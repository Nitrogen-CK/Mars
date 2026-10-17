class UMars_AutoTest_AnchorResolver_WarrensPlanValidates : UMars_AutoTestRig_AnchorResolverPure
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the emitted Warrens plan validates and has the frozen shape", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Plan = utils_anchor_resolver::Plan_Warrens();
        Assert_True(ck::IsValid(Plan), "the Warrens plan asset resolves");
        const auto Validation = Plan.Validate();
        Assert_True(Validation.IsValid(), f"the Warrens plan validates: {Validation.Get_Error()}");
        Assert_Equals_Int(Plan.Nodes.Num(), 23, "23 nodes");
        Assert_Equals_Int(Plan.Links.Num(), 29, "29 links");
        Assert_Equals_Int(Plan.Entrances.Num(), 5, "5 entrances");
        Assert_Equals_Int(Plan.Courts.Num(), 3, "3 courts");
        Assert_Equals_Int(Plan.Groups.Num(), 1, "one closure group");
        Assert_Equals_Int(Plan.Groups[0].AnchorIds.Num(), 7, "7 route anchors in the group");
        Assert_Equals_Int(Plan.Groups[0].MaxClosed, 3, "at most 3 close per run");
    }
}
