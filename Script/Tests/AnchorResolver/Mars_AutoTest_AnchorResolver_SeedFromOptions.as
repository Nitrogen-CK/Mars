class UMars_AutoTest_AnchorResolver_SeedFromOptions : UMars_AutoTestRig_AnchorResolverPure
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("a travel URL's ?seed= option is read, and its absence leaves the seed unset", n"Step_Parse");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Parse(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(utils_anchor_resolver::Get_SeedFromOptions("?seed=7").Get(-1), 7, "?seed=7 reads 7");
        Assert_False(utils_anchor_resolver::Get_SeedFromOptions("").IsSet(), "no options, no seed");
        Assert_Equals_Int(utils_anchor_resolver::Get_SeedFromOptions("?listen?seed=12?x=1").Get(-1), 12, "the seed is found among other options");
        const auto Zero = utils_anchor_resolver::Get_SeedFromOptions("?seed=0");
        Assert_True(Zero.IsSet() && Zero.GetValue() == 0, "?seed=0 is a set seed of 0");
    }
}
