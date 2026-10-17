class UMars_AutoTest_Anchor_ComposeAddsTagAndParams : UMars_AutoTestRig_Anchor
{
    default _TimeoutSeconds = 10.0f;

    private FCk_Handle _Anchor;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Anchor = Spawn_Anchor(InHandle, GameplayTags::Anchor_Mars_Test_A, FVector::ZeroVector, TOptional<int32>());
        Add_Step_WaitUntil("the placed anchor composes and is discoverable by its tag", n"Check_Discoverable");
        Add_Step("its params hold the spawn values and it waits idle for a resolver", n"Step_Params");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Discoverable(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsAnchorReady(_Anchor) && utils_entity_tag::ForEach_Entity(InHandle, n"TAG_MarsAnchor").Contains(_Anchor));
    }

    UFUNCTION()
    private void Step_Params(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Anchor = _Anchor.As_Anchor();
        Assert_True(Anchor.Get_AnchorId() == GameplayTags::Anchor_Mars_Test_A, "the id is the spawn value");
        Assert_True(Anchor.Get_Family() == EMars_Anchor_Family::Route, "the test anchor is a Route anchor");
        Assert_True(Anchor.Get_Channel() == GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Anchor.Test.A"), "the placed channel tag reaches the spec");
        Assert_Equals_Float(Anchor.Get_SpanCm(), 400.0f, 0.01f, "the default span is 400 cm");
        Assert_True(Anchor.Get_Table() == utils_anchor::Table_Test(), "the table is the test table");
        Assert_True(Anchor.Get_State() == EMars_Anchor_State::Idle, "no resolver, so the anchor stays idle");
        Assert_False(Anchor.Get_PinnedRow().IsSet(), "nothing pinned");
    }
}
