class UMars_AutoTest_AnchorResolver_WarrensChannelsDeclared : UMars_AutoTestRig_AnchorResolverPure
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the seven Warrens route-anchor channels are registered gameplay tags", n"Step_Tags");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Tags(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (int32 Index = 1; Index <= 7; ++Index)
        {
            const auto TagName = FName(f"Mechanism.Channel.Anchor.Warrens.R{Index}");
            Assert_True(GameplayTags::ResolveGameplayTag(TagName).IsValid(), f"{TagName.ToString()} is declared in DefaultGameplayTags.ini");
        }
    }
}
