// A rejected Add adds nothing. On a carrier with HeldItemUse, Add with StepsPerSegment = 0 ensures and returns an invalid
// handle, leaving no ThrowPreview feature; on an entity with HeldItem but no HeldItemUse, Add with a valid Spec ensures the
// same way. Both rejections are required errors of the hand-authored wrapper at the bottom of the file.
// Isolated origin (264000, -40000, -30000).
class UMars_AutoTest_ThrowPreview_ARejectedSpecAddsNothing : UMars_AutoTestRig_Carrier
{
    private FCk_Handle _NoUse;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, FVector(264000.0, -40000.0, -30000.0));
        Add_Hotbar(_Carrier, 2);
        _HeldItem = utils_held_item::Add(_Carrier);
        utils_held_item_use::Add(_Carrier);

        _NoUse = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(_NoUse, FTransform(FRotator::ZeroRotator, FVector(264000.0, -40200.0, -30000.0)), ECk_Replication::DoesNotReplicate);

        Add_Step("a zero StepsPerSegment, and a missing HeldItemUse, are each rejected", n"Step_AssertRejected");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertRejected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto BadSpec = FMars_ThrowPreview_Spec();
        BadSpec.StepsPerSegment = 0;
        Assert_False(BadSpec.Validate().IsValid(), "Validate rejects StepsPerSegment = 0");

        const auto Rejected = utils_throw_preview::Add(_Carrier, BadSpec);
        Assert_False(ck::IsValid(Rejected), "Add with StepsPerSegment = 0 returns an invalid handle");
        Assert_False(_Carrier.Has_Fragment(FMars_Feature_ThrowPreview), "Add with StepsPerSegment = 0 adds no ThrowPreview");
        Assert_False(_Carrier.Has_Fragment(FMars_Fragment_ThrowPreview_Params), "Add with StepsPerSegment = 0 adds no params");

        Assert_True(FMars_ThrowPreview_Spec().Validate().IsValid(), "the default Spec is valid");

        const auto NoUse = utils_throw_preview::Add(_NoUse, FMars_ThrowPreview_Spec());
        Assert_False(ck::IsValid(NoUse), "Add before HeldItemUse returns an invalid handle");
        Assert_False(_NoUse.Has_Fragment(FMars_Feature_ThrowPreview), "Add before HeldItemUse adds no ThrowPreview");
    }
}

// Hand-authored so the two rejections' ensures are required errors rather than failures: each pinned to its own wording,
// so any other error still fails the test.
class AMars_AutoTest_ThrowPreview_ARejectedSpecAddsNothing_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_ThrowPreview_ARejectedSpecAddsNothing;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_RequiredLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("rejected the spec: StepsPerSegment must be at least 1");
        Out.Add("needs HeldItemUse before ThrowPreview");
        return Out;
    }
}
