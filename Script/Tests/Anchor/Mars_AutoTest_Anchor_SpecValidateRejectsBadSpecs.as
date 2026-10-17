class UMars_AutoTest_Anchor_SpecValidateRejectsBadSpecs : UMars_AutoTestRig_Anchor
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("a valid spec passes and each broken one fails with its exact message", n"Step_Validate");
        Run_Steps(InHandle);
    }

    private FMars_Anchor_Spec Make_ValidSpec() const
    {
        auto Spec = FMars_Anchor_Spec();
        Spec.AnchorId = n"V";
        Spec.Table = TSoftObjectPtr<UMars_AnchorTable_Def>(utils_anchor::Table_Test());
        Spec.Channel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Anchor.Test.A");
        return Spec;
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Make_ValidSpec().Validate().IsValid(), f"the valid spec passes: {Make_ValidSpec().Validate().Get_Error()}");

        auto NoId = Make_ValidSpec();
        NoId.AnchorId = NAME_None;
        Assert_Equals_String(NoId.Validate().Get_Error(), "anchor id must be set", "a missing id is rejected");

        auto NoTable = Make_ValidSpec();
        NoTable.Table = TSoftObjectPtr<UMars_AnchorTable_Def>();
        Assert_Equals_String(NoTable.Validate().Get_Error(), "anchor table must be set", "a missing table is rejected");

        auto NoSpan = Make_ValidSpec();
        NoSpan.SpanCm = 0.0f;
        Assert_Equals_String(NoSpan.Validate().Get_Error(), "anchor span and home radius must be positive", "a zero span is rejected");

        auto NegativePin = Make_ValidSpec();
        NegativePin.PinnedRow = TOptional<int32>(-1);
        Assert_Equals_String(NegativePin.Validate().Get_Error(), "a pinned row cannot be negative", "a negative pin is rejected");

        auto NoChannel = Make_ValidSpec();
        NoChannel.Channel = FGameplayTag();
        Assert_Equals_String(NoChannel.Validate().Get_Error(), "a route anchor needs a channel", "a route anchor without a channel is rejected");
    }
}
