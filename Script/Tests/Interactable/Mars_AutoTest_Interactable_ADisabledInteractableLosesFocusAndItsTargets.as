// The carrier's SM root state: the player HFSM's real InteractionFocus task.
class UMars_AutoTestState_FocusRig : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_InteractionFocus);
    }
}

// A disabled interactable loses the focus and its targets. The carrier (the test entity: a prompt display, a Use resolver
// with Use open, and a PlayerViewpoint-like interaction trace from an eye node along +X) runs the player's real
// InteractionFocus task. A lever whose probe lies on the trace is focused through the trace: it names the carrier as its
// focuser, its Use target is the best Use target and its prompt is on the carrier's display. A ledger then claims the
// lever: it is unfocused, its target leaves the resolver's best Use targets and its prompt leaves the display, while it
// still lies under the trace. Released, it takes the focus back. OnFocusableChanged broadcasts once per edge: Disable at
// the claim, Enable at the release. Isolated origin (63200, -12000, -30000).
class UMars_AutoTest_Interactable_ADisabledInteractableLosesFocusAndItsTargets : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 10.0f;

    private const FVector k_Origin = FVector(63200.0, -12000.0, -30000.0);
    // Where the lever's probe sits on the trace, and the trace's reach (the player's default).
    private const FVector k_LeverOffset = FVector(120.0, 0.0, 0.0);
    private const float32 k_TraceDistance = 250.0f;
    private const float32 k_ProbeRadius = 20.0f;

    private FCk_Handle _Carrier;
    private FCk_Handle_StateMachine _Sm;
    private FCk_Handle_InteractionResolver _Resolver;
    private FCk_Handle_InteractPromptDisplay _Display;
    private FCk_Handle_Interactable _Lever;
    private FCk_Handle_InteractTarget _Target;
    private TArray<ECk_EnableDisable> _FocusableEdges;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Carrier = InHandle;
        auto Root = utils_transform::Add(_Carrier, FTransform(FRotator::ZeroRotator, k_Origin), ECk_Replication::DoesNotReplicate);
        _Display = utils_interact_prompt_display::Add(_Carrier);
        _Resolver = utils_interaction_resolver::Add(_Carrier, Make_ResolverSpec(), ECk_Replication::DoesNotReplicate);
        Add_ViewTrace(Root);
        BuildLever(InHandle);

        _Sm = utils_state_machine::Add(_Carrier, FCk_StateMachine_Spec(UMars_AutoTestState_FocusRig));

        Add_Step_WaitUntil("the carrier's SM runs the focus task", n"Check_RigReady", 0, 0);
        Add_Step("open Use on the carrier's resolver", n"Step_OpenUse");
        Add_Step_WaitUntil("the trace focused the lever: its target is the best Use target and its prompt shows", n"Check_FocusedAndOffered", 0, 0);
        Add_Step("a camp menu captures the carrier's world interaction", n"Step_OpenCampMenu");
        Add_Step_WaitUntil("the menu clears focus, resolver target and prompt even under the trace", n"Check_LostFocusAndOffer", 0, 0);
        Add_Step("Back releases only the camp menu hold", n"Step_CloseCampMenu");
        Add_Step_WaitUntil("Back restores world focus and the prompt", n"Check_FocusedAndOffered", 0, 0);
        Add_Step("a ledger claims the lever", n"Step_Claim");
        Add_Step_WaitUntil("the lever lost the focus, its target and its prompt", n"Check_LostFocusAndOffer", 0, 0);
        Add_Step("the lever is Disabled under the trace, its framework target with it", n"Step_AssertDisabledUnderTheTrace");
        Add_Step("the ledger lets go", n"Step_Release");
        Add_Step_WaitUntil("the lever took the focus back: its target is the best Use target and its prompt shows", n"Check_FocusedAndOffered", 0, 0);
        Add_Step("OnFocusableChanged broadcast Disable at the claim and Enable at the release", n"Step_AssertFocusableEdges");
        Run_Steps(InHandle);
    }

    private FCk_InteractionResolver_Spec Make_ResolverSpec() const
    {
        auto Channels = TArray<FGameplayTag>();
        Channels.Add(GameplayTags::InteractionChannel_Mars_Use);

        // One target needs no distance sort.
        auto Mapping = FCk_InteractionResolver_IntentChannelMapping(GameplayTags::InteractionIntent_Mars_Use, Channels);
        Mapping.Set_DistanceSorting(ECk_InteractionResolver_DistanceSorting::Disabled);

        auto Mappings = TArray<FCk_InteractionResolver_IntentChannelMapping>();
        Mappings.Add(Mapping);
        return FCk_InteractionResolver_Spec(Mappings);
    }

    // What utils_player_viewpoint::Add gives the player, without its camera: a persistent multi line trace filtered on
    // Probe.Mars.Interact from an eye node, here looking along +X.
    private void Add_ViewTrace(FCk_Handle_Transform& InRoot)
    {
        auto Eye = utils_scene_node::Create(InRoot, FTransform::Identity).As_Transform();

        auto TraceSettings = FCk_Probe_RayCastPersistent_Settings(
            Eye,
            FVector(k_TraceDistance, 0.0, 0.0),
            GameplayTag::MakeGameplayTagContainerFromTag(GameplayTags::Probe_Mars_Interact));
        TraceSettings.Set_TracePolicy(ECk_ProbeTrace_Policy::Multi);

        auto Viewpoint = FMars_Fragment_PlayerViewpoint();
        Viewpoint.Viewpoint = Eye;
        Viewpoint.InteractionTrace = utils_probe_trace::Create_LineTrace_Persistent(TraceSettings);

        _Carrier.Add_Fragment(FMars_Feature_PlayerViewpoint());
        _Carrier.Add_Fragment(Viewpoint);
    }

    // A ManuallyCompleted lever with one Use target and a pickup-like probe (Probe.Mars.Interact) on the trace.
    private void BuildLever(FCk_Handle InHandle)
    {
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(RootEntity, FTransform(FRotator::ZeroRotator, k_Origin + k_LeverOffset),
            ECk_Replication::DoesNotReplicate);

        auto ControlSpec = FMars_Control_Spec();
        ControlSpec.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        ControlSpec.Manipulation.PullAxis = FVector(-1.0, 0.0, 0.0);
        ControlSpec.Manipulation.AlphaPerDegree = 0.02f;
        ControlSpec.Manipulation.EngageAlpha = 0.85f;
        auto Control = utils_control::Add(RootEntity, ControlSpec);

        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeSpec.Set_MotionType(ECk_MotionType::Kinematic);
        Probe.ProbeShape = utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(k_ProbeRadius));
        Probe.ProbeOffset = FTransform::Identity;

        auto Spec = FMars_Interactable_Spec();
        Spec.ProbeInfo = Probe;
        Spec.Targets.Add(Control.Make_InteractTarget(FMars_InteractPrompt_Spec(mars::Mars_IA_Interact_Use, FText::FromString("Pull"))));
        _Lever = utils_interactable::Create(Root, Spec);

        const auto Targets = _Lever.Get_AllInteractTargets();
        if (Targets.Num() != 1)
        {
            FinishFailure(f"the lever interactable has {Targets.Num()} interact targets, expected 1");
            return;
        }

        _Target = Targets[0];
        _Lever.BindTo_OnFocusableChanged(FMars_Delegate_Interactable_OnFocusableChanged(this, n"OnFocusableChanged"));
    }

    UFUNCTION()
    private void OnFocusableChanged(FCk_Handle_Interactable InInteractable, ECk_EnableDisable InFocusable)
    {
        _FocusableEdges.Add(InFocusable);
    }

    private bool Get_IsBestUseTarget()
    {
        return _Resolver.Get_BestInteractTargets(GameplayTags::InteractionIntent_Mars_Use).Contains(_Target);
    }

    private bool Get_IsPromptShown()
    {
        const auto Prompt = _Target.As_InteractPrompt();
        const auto Slots = _Display.Get_Slots();
        for (const auto& Slot : Slots)
        {
            for (const auto& Entry : Slot.Stack)
            {
                if (Entry.PromptHandle == Prompt)
                { return true; }
            }
        }

        return false;
    }

    UFUNCTION()
    private void Check_RigReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::IsInState(_Sm, UMars_AutoTestState_FocusRig));
    }

    UFUNCTION()
    private void Step_OpenUse(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Resolver.Request_StartIntent(FCk_Request_InteractionResolver_StartIntent(GameplayTags::InteractionIntent_Mars_Use));
    }

    UFUNCTION()
    private void Check_FocusedAndOffered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Lever.Get_CurrentFocuser() == _Carrier && Get_IsBestUseTarget() && Get_IsPromptShown());
    }

    UFUNCTION()
    private void Step_Claim(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Lever.Request_Disable(FMars_Request_Interactable_Disable(EMars_Interactable_DisableReason::Ledger));
    }

    UFUNCTION()
    private void Step_OpenCampMenu(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto View = _Carrier.As_PlayerViewpoint();
        View.Request_HoldView(FMars_Request_PlayerViewpoint_HoldView(EMars_PlayerViewpoint_ViewHolder::CampMenu));
    }

    UFUNCTION()
    private void Step_CloseCampMenu(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto View = _Carrier.As_PlayerViewpoint();
        View.Request_ReleaseView(FMars_Request_PlayerViewpoint_ReleaseView(EMars_PlayerViewpoint_ViewHolder::CampMenu));
    }

    UFUNCTION()
    private void Check_LostFocusAndOffer(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Lever.Get_IsFocused() == false && Get_IsBestUseTarget() == false && Get_IsPromptShown() == false);
    }

    UFUNCTION()
    private void Step_AssertDisabledUnderTheTrace(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Lever.Get_EnableDisable() == ECk_EnableDisable::Disable, "the lever is disabled");
        Assert_True(utils_interact_target::Get_Enabled(_Target) == ECk_EnableDisable::Disable, "its framework target is disabled");
        Assert_True(utils_state_machine::Get_CurrentStateClass(_Target.As_StateMachine()) == UMars_SmState_Interactable_Disabled,
            "its target's state machine is Disabled");

        auto Trace = _Carrier.As_PlayerViewpoint().Get_InteractionTrace();
        const auto Overlaps = Trace.Get_CurrentOverlaps();
        auto StillUnderTheTrace = false;
        FCk_Handle LeverEntity = _Lever;
        for (auto Overlap : Overlaps)
        { StillUnderTheTrace = StillUnderTheTrace || Overlap.Get_OtherEntity() == LeverEntity; }

        Assert_True(StillUnderTheTrace, "the lever still lies under the trace: only its enable state moved the focus");

        Assert_Equals_Int(_FocusableEdges.Num(), 1, "the claim broadcast one OnFocusableChanged");
        if (_FocusableEdges.Num() == 1)
        { Assert_True(_FocusableEdges[0] == ECk_EnableDisable::Disable, f"the claim's edge is Disable (got {_FocusableEdges[0] :n})"); }
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Lever.Request_Enable(FMars_Request_Interactable_Enable(EMars_Interactable_DisableReason::Ledger));
    }

    UFUNCTION()
    private void Step_AssertFocusableEdges(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_FocusableEdges.Num(), 2, "OnFocusableChanged broadcast once per edge");
        if (_FocusableEdges.Num() == 2)
        { Assert_True(_FocusableEdges[1] == ECk_EnableDisable::Enable, f"the release's edge is Enable (got {_FocusableEdges[1] :n})"); }
    }
}
