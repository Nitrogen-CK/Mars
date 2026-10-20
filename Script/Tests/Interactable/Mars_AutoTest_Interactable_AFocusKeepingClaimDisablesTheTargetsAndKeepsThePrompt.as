// A claim that keeps the interactable focusable disables its targets and keeps its prompt. The carrier (the test entity: a
// prompt display, a Use resolver with Use open, and a PlayerViewpoint-like interaction trace from an eye node along +X)
// runs the player's real InteractionFocus task over a lever lying on the trace. HotbarFull is claimed on the focused lever:
// it stays focused by the carrier and in its Focused state, its prompt stays on the display, and its framework target is
// disabled, so a start from the carrier creates nothing. Released, the target accepts the carrier again, still focused.
// Isolated origin (69600, -12000, -30000).
class UMars_AutoTest_Interactable_AFocusKeepingClaimDisablesTheTargetsAndKeepsThePrompt : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 10.0f;

    private const FVector k_Origin = FVector(69600.0, -12000.0, -30000.0);
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
    private int32 _FocusEdges = 0;

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
        Add_Step_WaitUntil("the trace focused the lever and its prompt shows", n"Check_FocusedAndShown", 0, 0);
        Add_Step("a full hotbar claims the lever", n"Step_Claim");
        Add_Step_WaitUntil("the lever's framework target is disabled", n"Check_TargetDisabled", 0, 0);
        Add_Step_WaitFrames("a claim that took it out of focus would have unfocused it by now", 5);
        Add_Step("still focused, Focused and shown, the target refuses the carrier; try to start", n"Step_AssertKeptAndTryStart");
        Add_Step_WaitFrames("a wrongly accepted start would have created its interaction by now", 5);
        Add_Step("the refused start created nothing; release the claim", n"Step_AssertNoInteractionAndRelease");
        Add_Step_WaitUntil("the lever's framework target is enabled", n"Check_TargetEnabled", 0, 0);
        Add_Step("the target accepts the carrier again, and the focus never moved", n"Step_AssertAcceptedStillFocused");
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
        _Lever.BindTo_OnFocused(FMars_Delegate_Interactable_OnFocused(this, n"OnLeverFocused"));
        _Lever.BindTo_OnUnfocused(FMars_Delegate_Interactable_OnUnfocused(this, n"OnLeverUnfocused"));
    }

    UFUNCTION()
    private void OnLeverFocused(FCk_Handle_Interactable InInteractable, FCk_Handle InFocusedBy)
    {
        _FocusEdges += 1;
    }

    UFUNCTION()
    private void OnLeverUnfocused(FCk_Handle_Interactable InInteractable, FCk_Handle InUnfocusedBy)
    {
        _FocusEdges += 1;
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
    private void Check_FocusedAndShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Lever.Get_CurrentFocuser() == _Carrier && Get_IsPromptShown()
            && utils_state_machine::Get_CurrentStateClass(_Target.As_StateMachine()) == UMars_SmState_Interactable_Focused);
    }

    UFUNCTION()
    private void Step_Claim(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _FocusEdges = 0;
        _Lever.Request_Disable(FMars_Request_Interactable_Disable(EMars_Interactable_DisableReason::HotbarFull));
    }

    UFUNCTION()
    private void Check_TargetDisabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_interact_target::Get_Enabled(_Target) == ECk_EnableDisable::Disable);
    }

    UFUNCTION()
    private void Step_AssertKeptAndTryStart(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Lever.Get_IsDisabledFor(EMars_Interactable_DisableReason::HotbarFull), "the lever holds the HotbarFull claim");
        Assert_True(_Lever.Get_IsFocusable(), "HotbarFull keeps the lever focusable");
        Assert_True(_Lever.Get_CurrentFocuser() == _Carrier, "the carrier still focuses the lever");
        Assert_Equals_Int(_FocusEdges, 0, "the claim moved no focus");
        Assert_True(utils_state_machine::Get_CurrentStateClass(_Target.As_StateMachine()) == UMars_SmState_Interactable_Focused,
            "its target's state machine stays Focused");
        Assert_True(Get_IsPromptShown(), "its prompt stays on the display");

        const auto Result = utils_interact_target::Get_CanInteractWith(_Target, _Carrier);
        Assert_True(Result == ECk_CanInteractWithResult::TargetDisabled, f"the claimed lever refuses the carrier (got [{Result :n}])");

        _Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Step_AssertNoInteractionAndRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Invalid(utils_interact_target::TryGet_Interaction(_Target, _Carrier), "the refused start created no interaction");

        _Lever.Request_Enable(FMars_Request_Interactable_Enable(EMars_Interactable_DisableReason::HotbarFull));
    }

    UFUNCTION()
    private void Check_TargetEnabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_interact_target::Get_Enabled(_Target) == ECk_EnableDisable::Enable);
    }

    UFUNCTION()
    private void Step_AssertAcceptedStillFocused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Result = utils_interact_target::Get_CanInteractWith(_Target, _Carrier);
        Assert_True(Result == ECk_CanInteractWithResult::CanInteractWith, f"the released lever accepts the carrier (got [{Result :n}])");
        Assert_True(_Lever.Get_CurrentFocuser() == _Carrier, "the carrier still focuses the lever");
        Assert_Equals_Int(_FocusEdges, 0, "neither the claim nor its release moved the focus");
    }
}
