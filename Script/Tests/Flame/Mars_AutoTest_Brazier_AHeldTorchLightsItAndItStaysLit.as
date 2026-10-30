// A brazier (UMars_Brazier_EntityScript: NeedsAFlame, Open, no fuel) is lit through its own ignite row by a carrier holding
// a lit torch: the brazier's interactable is focused by the carrier and offered to its Use resolver (what the player's
// focus task does), Use is pressed on a private key, the ignite task passes fire from the held torch, and the brazier's
// World pool (800) comes on. With no fuel it stays lit, Steady, with nothing to count down; the torch keeps burning, and a
// torch snuffed afterwards can take light back from it. Isolated origin: (16000, 0, -60000).
class UMars_AutoTest_Brazier_AHeldTorchLightsItAndItStaysLit : UMars_AutoTestRig_FlameItem
{
    default _TimeoutSeconds = 45.0f;

    private const FVector k_Origin = FVector(16000.0, 0.0, -60000.0);
    private const float32 k_BrazierWorldRadius = 800.0f;
    // A measureless flame has nothing to burn through; this long lit is "stays lit" for the test.
    private const float32 k_StaysLitSeconds = 1.0f;

    private FCk_Handle _BrazierEntity;
    private FCk_Handle_Flame _Brazier;
    // _Hands (the gloves) is the carrier rig's.
    private FCk_Handle_InteractionResolver _Resolver;
    private FCk_Handle_InputIntents _Intents;
    private UMars_AutoTestHelper_UseKey _UseKey;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBelt(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);

        // The player's pieces on the carrier: gloves on its hand, a Use resolver, intents read from a private Use key, and
        // the tasks that turn a Use press into the focused row's interaction (UMars_AutoTestState_CarrierHands).
        auto HandsSpec = FMars_FPHands_Spec();
        HandsSpec.HandNode = _HandNode;
        _Hands = utils_fphands::Add(_Carrier, HandsSpec);
        _Resolver = utils_interaction_resolver::Add(_Carrier, mars_test_interaction::Make_UseResolverSpec(), ECk_Replication::DoesNotReplicate);
        _Intents = utils_input_intents::Add(_Carrier);
        utils_state_machine::Add(_Carrier, FCk_StateMachine_Spec(UMars_AutoTestState_CarrierHands));

        _UseKey = Cast<UMars_AutoTestHelper_UseKey>(NewObject(this, UMars_AutoTestHelper_UseKey));
        _UseKey.Build(InHandle, EKeys::F9);

        SpawnBrazier(InHandle, k_Origin + FVector(120.0, 0.0, 0.0));
        SpawnFlameItem(InHandle, FMars_AutoTestHelper_FlameItemSpawn(mars_items::Torch(), UMars_Torch_EntityScript, k_Origin + FVector(0.0, 150.0, 0.0)));

        Add_Step_WaitUntil("the brazier and the torch are composed", n"Check_AllReady", k_SlowPolls, 0);
        Add_Step("the brazier starts dark, measureless, lighting nothing", n"Step_AssertBrazierDark");
        Add_Step_WaitUntil("the Use key is minted and the sampler records", n"Check_UseKeyRecording", 0, 0);
        Add_Step("bake the Use level row and swap it in", n"Step_SwapUseSet");
        Add_Step_WaitUntil("the Use row is live on the matcher", n"Check_UseSetActive", 0, 0);
        Add_Step("the carrier reads the Use key's matcher", n"Step_SetMatcher");
        Add_Step_WaitUntil("the carrier reads the matcher", n"Check_MatcherSet", 0, 0);
        Add_Step("stow the torch (slot 0, selected)", n"Step_StowFlame");
        Add_Step_WaitUntil("the carrier holds the torch", n"Check_TorchHeld", k_SlowPolls, 0);
        Add_Step("light the torch", n"Step_Light");
        Add_Step_WaitUntil("the carrier holds the lit torch", n"Check_FlameHeldAndLit", k_SlowPolls, 0);
        Add_Step("the lit torch at the dark brazier offers Light", n"Step_AssertOffersLight");
        Add_Step("focus the brazier and offer its ignite row to the resolver", n"Step_FocusAndOfferBrazier");
        Add_Step_WaitUntil("the brazier's ignite row is Focused", n"Check_BrazierFocused", k_SlowPolls, 0);
        Add_Step("press Use", n"Step_PressUse");
        Add_Step_WaitUntil("the brazier lights", n"Check_BrazierLit", k_SlowPolls, 0);
        Add_Step("release Use", n"Step_ReleaseUse");
        Add_Step_WaitUntil("the brazier's World pool is the shown one", n"Check_BrazierShowsWorldPool", k_SlowPolls, 0);
        Add_Step("the brazier lights its World pool and the torch still burns", n"Step_AssertLitFromTorch");
        Add_Step_WaitSeconds("a measureless flame burns on", k_StaysLitSeconds);
        Add_Step("the brazier is still lit and Steady with nothing to count down", n"Step_AssertStaysLit");
        Add_Step("snuff the torch", n"Step_Snuff");
        Add_Step_WaitUntil("the torch goes out", n"Check_TorchDark", 0, 0);
        Add_Step("the lit brazier offers the snuffed torch its light", n"Step_AssertOffersTakeLight");
        Run_Steps(InHandle);
    }

    // The world item and the fixture outlive the test entity: they are owned by the transient entity.
    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_FlameItem))
        {
            auto Torch = _FlameItem.H();
            utils_entity_lifetime::Request_DestroyEntity(Torch);
        }

        if (ck::IsValid(_BrazierEntity))
        { utils_entity_lifetime::Request_DestroyEntity(_BrazierEntity); }
    }

    // A brazier at InLocation, snuffed, with the fixture's defaults (its DoConstruct sets the rules).
    private void SpawnBrazier(FCk_Handle InHandle, FVector InLocation)
    {
        auto SpawnParams = UMars_Brazier_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, InLocation);

        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Brazier_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnBrazierConstructed"));
    }

    UFUNCTION()
    private void OnBrazierConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        // A UFUNCTION parameter is read-only to script: copy it before H().
        FCk_Handle_EntityScript Script = InEntityScriptHandle;
        _BrazierEntity = Script.H();
        _Brazier = _BrazierEntity.As_Flame(ECk_SanityCheck::UnChecked);
    }

    private FCk_Handle_InteractTarget Get_IgniteRow()
    {
        auto Interactable = _Brazier.Get_Interactable();
        return Interactable.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
    }

    private void Assert_Action(EMars_Flame_Action InExpected, const FString& InMessage)
    {
        const auto Action = _Brazier.Get_ActionFor(_Carrier);
        Assert_True(Action == InExpected, f"{InMessage}: expected [{InExpected :n}], got [{Action :n}]");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps and conditions
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Check_AllReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsFlameReady() && ck::IsValid(_Brazier) && ck::IsValid(_Brazier.Get_Interactable()));
    }

    UFUNCTION()
    private void Step_AssertBrazierDark(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Brazier.Get_IsLit(), "the brazier starts dark");
        Assert_Equals_Int(_Brazier.Get_Measures(), 0, "the brazier has no fuel to measure");
        Assert_True(_Brazier.Get_Enclosure() == EMars_Flame_Enclosure::Open, "the brazier is an open fire");
        Assert_True(_Brazier.Get_LightRadius() == 0.0f, "a dark brazier lights nothing");
        Assert_Action(EMars_Flame_Action::Blocked_NeedsAFlame, "empty hands at the dark brazier");
    }

    UFUNCTION()
    private void Check_UseKeyRecording(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_UseKey.Get_IsRecording());
    }

    UFUNCTION()
    private void Step_SwapUseSet(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Swapped = _UseKey.Request_SwapUseSet();
        if (Swapped.IsValid() == false)
        { FinishFailure(Swapped.Get_Error()); }
    }

    UFUNCTION()
    private void Check_UseSetActive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_UseKey.Get_IsUseSetActive());
    }

    UFUNCTION()
    private void Step_SetMatcher(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Intents.Request_SetMatcher(FMars_Request_InputIntents_SetMatcher(_UseKey.Get_Matcher()));
    }

    UFUNCTION()
    private void Check_MatcherSet(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Intents.Get_Matcher() == _UseKey.Get_Matcher());
    }

    UFUNCTION()
    private void Check_TorchHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HeldItem.Get_CurrentItem() == Get_FlameItem());
    }

    UFUNCTION()
    private void Step_AssertOffersLight(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Action(EMars_Flame_Action::Light, "a lit torch at the dark brazier");
    }

    // What the player's focus task does for a fixture under the view: focuses it and offers its row to the resolver.
    UFUNCTION()
    private void Step_FocusAndOfferBrazier(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Interactable = _Brazier.Get_Interactable();
        Interactable.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
        _Resolver.Request_AddInteractTarget(FCk_Request_InteractionResolver_AddInteractTarget(Get_IgniteRow()));
    }

    UFUNCTION()
    private void Check_BrazierFocused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::Get_CurrentStateClass(Get_IgniteRow().As_StateMachine()) == UMars_SmState_Interactable_Focused);
    }

    UFUNCTION()
    private void Step_PressUse(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _UseKey.Press();
    }

    UFUNCTION()
    private void Step_ReleaseUse(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _UseKey.Release();
    }

    UFUNCTION()
    private void Check_BrazierLit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Brazier.Get_IsLit());
    }

    UFUNCTION()
    private void Check_BrazierShowsWorldPool(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Shown = _Brazier.Get_ShownLightPool();
        auto Res = OutResult;
        Res.Set(Shown.IsSet() && Shown.GetValue() == EMars_Flame_Pool::World);
    }

    UFUNCTION()
    private void Step_AssertLitFromTorch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Brazier.Get_IsLit(), "the brazier is lit");
        Assert_True(_Brazier.Get_LightPool() == EMars_Flame_Pool::World, "a fixture's flame is a World pool");
        Assert_True(Math::IsNearlyEqual(_Brazier.Get_LightRadius(), k_BrazierWorldRadius),
            f"the brazier lights its World radius [{k_BrazierWorldRadius}], got [{_Brazier.Get_LightRadius()}]");
        Assert_True(Get_Flame().Get_IsLit(), "lighting the brazier left the torch lit");
        Assert_Action(EMars_Flame_Action::None, "a lit torch at the lit brazier");
    }

    UFUNCTION()
    private void Step_AssertStaysLit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Brazier.Get_IsLit(), "a measureless brazier stays lit");
        Assert_True(_Brazier.Get_Condition() == EMars_Flame_Condition::Steady, "a measureless flame never gutters");
        Assert_Equals_Int(_Brazier.Get_MeasuresLeft(), 0, "nothing counts down on a measureless flame");
        Assert_True(Math::IsNearlyEqual(_Brazier.Get_FuelFraction(), 1.0f), "a measureless flame is always full");
    }

    UFUNCTION()
    private void Check_TorchDark(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_Flame().Get_IsLit() == false);
    }

    UFUNCTION()
    private void Step_AssertOffersTakeLight(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Brazier.Get_IsLit(), "the brazier burns on without the torch");
        Assert_Action(EMars_Flame_Action::TakeLight, "a snuffed torch at the lit brazier");
    }
}
