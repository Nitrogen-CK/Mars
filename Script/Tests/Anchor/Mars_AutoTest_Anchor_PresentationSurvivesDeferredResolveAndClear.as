// An isolated test table, never a production seed/table override. Exercises real forage placement and inherited
// Anchor injection into a real Censer, then clears its child and resolves again through a fresh resolver.
asset Mars_ForagePresentation_Test of UMars_ForagePresentation_Def
{
    Censer.CeilingHeightCm = 460.0f;
}

class UMars_TESTONLY_CenserPresentation_EntityScript : UMars_ForageCenser_EntityScript
{
    default _ShowInPlaceActors = false;
    default WithVisuals = false;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);
        if (Anchor.ForagePresentation.Get() == Mars_ForagePresentation_Test
            && Anchor.RunSeed == 73 && Anchor.AnchorId == GameplayTags::Anchor_Mars_Test_A)
        { utils_entity_tag::Add(InHandle, n"TAG_MarsTestCenserPresentationReceived"); }
        return Flow;
    }
}

asset Mars_AnchorTable_PresentationTest of UMars_AnchorTable_Def
{
    Family = EMars_Anchor_Family::Forage;
    Rows.Add(FMars_AnchorTable_Row(UMars_TESTONLY_CenserPresentation_EntityScript, 1.0f, EMars_Anchor_Role::Open));
}

class UMars_TESTONLY_ForagePresentationAnchor_EntityScript : UMars_Anchor_Forage_EntityScript
{
    default _ShowInPlaceActors = false;
    default ForagePresentation = Mars_ForagePresentation_Test;

    protected UMars_AnchorTable_Def Get_Table() const override
    { return Mars_AnchorTable_PresentationTest; }
}

class UMars_AutoTest_Anchor_PresentationSurvivesDeferredResolveAndClear : UMars_AutoTestRig_Anchor
{
    default _TimeoutSeconds = 20.0f;

    private FCk_Handle _Anchor;
    private FCk_Handle _Resolver;
    private FCk_Handle _FirstCandidate;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Params = FMars_TESTONLY_AnchorSpawnParams();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Base + FVector(0.0, 6000.0, 0.0));
        Params.AnchorId = GameplayTags::Anchor_Mars_Test_A;
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_TESTONLY_ForagePresentationAnchor_EntityScript, Params);
        _Anchor = Pending.Get_EntityUnderConstruction();
        _Resolver = Spawn_Resolver(InHandle, Make_Result(73));

        Add_Step_WaitUntil("the real censer receives the inherited optional context", n"Check_Received");
        Add_Step("the anchor retains the presentation and owns the candidate", n"Step_AssertOwner");
        Add_Step("clear the candidate and retire the resolver", n"Step_Clear");
        Add_Step_WaitUntil("the old child is gone but the placed profile remains", n"Check_Cleared");
        Add_Step("resolve the same placed anchor again", n"Step_ResolveAgain");
        Add_Step_WaitUntil("the replacement receives the same presentation", n"Check_Received");
        Add_Step("the replacement has the same owner and no duplicate", n"Step_AssertOwner");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Received(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (Get_IsSpawned(_Anchor) == false)
        { Res.Set(false); return; }

        const auto Child = _Anchor.As_Anchor().Get_Spawned();
        Res.Set(ck::IsValid(Child) && utils_entity_tag::ForEach_Entity(InHandle, n"TAG_MarsTestCenserPresentationReceived").Contains(Child));
    }

    UFUNCTION()
    private void Step_AssertOwner(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Anchor = _Anchor.As_Anchor();
        const auto Child = Anchor.Get_Spawned();
        Assert_True(Anchor.Get_ForagePresentation() == Mars_ForagePresentation_Test, "profile reaches weak fragment params");
        Assert_True(Child.Get_LifetimeOwner() == _Anchor, "the candidate remains owned by the placed anchor");
        Assert_Equals_Int(Count_Tagged(InHandle, n"TAG_MarsTestCenserPresentationReceived"), 1, "one presented candidate exists");
        Assert_True(Child.Is_Forage() && Child.Is_HitZone(), "presentation forwarding retains the real Censer composition");
    }

    UFUNCTION()
    private void Step_Clear(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Anchor = _Anchor.As_Anchor();
        _FirstCandidate = Anchor.Get_Spawned();
        Anchor.Request_Clear(FMars_Request_Anchor_Clear());
        utils_entity_lifetime::Request_DestroyEntity(_Resolver);
    }

    UFUNCTION()
    private void Check_Cleared(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_FirstCandidate) && ck::Is_NOT_Valid(_Resolver)
            && _Anchor.As_Anchor().Get_State() == EMars_Anchor_State::Cleared
            && _Anchor.As_Anchor().Get_ForagePresentation() == Mars_ForagePresentation_Test
            && Count_Tagged(InHandle, n"TAG_MarsTestCenserPresentationReceived") == 0);
    }

    UFUNCTION()
    private void Step_ResolveAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    { _Resolver = Spawn_Resolver(InHandle, Make_Result(73)); }
}
