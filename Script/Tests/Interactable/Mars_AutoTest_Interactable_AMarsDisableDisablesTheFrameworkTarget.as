// A Mars disable is the framework's: while a reason is held, the lever's Use target answers Get_CanInteractWith with
// TargetDisabled for the carrier (the test entity) and a StartInteraction creates nothing; released, it answers
// CanInteractWith and the same StartInteraction creates the carrier's interaction. A claim landing on a live interaction
// cancels it: it finishes, not Succeeded. Isolated origin (61600, -12000, -30000).
class UMars_AutoTest_Interactable_AMarsDisableDisablesTheFrameworkTarget : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 10.0f;

    private const FVector k_Origin = FVector(61600.0, -12000.0, -30000.0);

    private FCk_Handle _Carrier;
    private FCk_Handle_Interactable _Lever;
    private FCk_Handle_InteractTarget _Target;
    private TArray<ECk_SucceededFailed> _FinishedResults;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Carrier = InHandle;
        BuildLever(InHandle);

        Add_Step("the lever accepts the carrier; claim Operated", n"Step_AssertAcceptedAndClaim");
        Add_Step_WaitUntil("the lever is disabled", n"Check_Disabled", 0, 0);
        Add_Step("the framework target refuses the carrier; try to start", n"Step_AssertRefusedAndTryStart");
        Add_Step_WaitFrames("a wrongly accepted start would have created its interaction by now", 5);
        Add_Step("the refused start created no interaction; release Operated", n"Step_AssertNoInteractionAndRelease");
        Add_Step_WaitUntil("the lever is enabled", n"Check_Enabled", 0, 0);
        Add_Step("the framework target accepts the carrier again; start", n"Step_AssertAcceptedAndStart");
        Add_Step_WaitUntil("the carrier's interaction is live", n"Check_HasInteraction", 0, 0);
        Add_Step("claim Ledger over the live interaction", n"Step_ClaimLedger");
        Add_Step_WaitUntil("the interaction is gone", n"Check_InteractionGone", 0, 0);
        Add_Step("the cancelled interaction finished once, not Succeeded", n"Step_AssertCancelled");
        Run_Steps(InHandle);
    }

    // A ManuallyCompleted lever with one Use target and no probe: nothing completes a started interaction, so it stays live.
    private void BuildLever(FCk_Handle InHandle)
    {
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(RootEntity, FTransform(FRotator::ZeroRotator, k_Origin), ECk_Replication::DoesNotReplicate);

        auto ControlSpec = FMars_Control_Spec();
        ControlSpec.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        ControlSpec.Manipulation.PullAxis = FVector(-1.0, 0.0, 0.0);
        ControlSpec.Manipulation.AlphaPerDegree = 0.02f;
        ControlSpec.Manipulation.EngageAlpha = 0.85f;
        auto Control = utils_control::Add(RootEntity, ControlSpec);

        auto Spec = FMars_Interactable_Spec();
        Spec.Targets.Add(Control.Make_InteractTarget(FMars_InteractPrompt_Spec(mars::Mars_IA_Interact_Use, FText::FromString("Pull"))));
        _Lever = utils_interactable::Create(Root, Spec);

        const auto Targets = _Lever.Get_AllInteractTargets();
        if (Targets.Num() != 1)
        {
            FinishFailure(f"the lever interactable has {Targets.Num()} interact targets, expected 1");
            return;
        }

        _Target = Targets[0];
        _Target.BindTo_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnFinished"));
    }

    UFUNCTION()
    private void OnFinished(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        _FinishedResults.Add(InResult);
    }

    UFUNCTION()
    private void Step_AssertAcceptedAndClaim(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Result = utils_interact_target::Get_CanInteractWith(_Target, _Carrier);
        Assert_True(Result == ECk_CanInteractWithResult::CanInteractWith, f"the enabled lever accepts the carrier (got [{Result :n}])");

        _Lever.Request_Disable(FMars_Request_Interactable_Disable(EMars_Interactable_DisableReason::Operated));
    }

    UFUNCTION()
    private void Check_Disabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Lever.Get_EnableDisable() == ECk_EnableDisable::Disable);
    }

    UFUNCTION()
    private void Step_AssertRefusedAndTryStart(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Result = utils_interact_target::Get_CanInteractWith(_Target, _Carrier);
        Assert_True(Result == ECk_CanInteractWithResult::TargetDisabled, f"the claimed lever refuses the carrier (got [{Result :n}])");

        _Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Step_AssertNoInteractionAndRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Invalid(utils_interact_target::TryGet_Interaction(_Target, _Carrier), "the refused StartInteraction created no interaction");

        _Lever.Request_Enable(FMars_Request_Interactable_Enable(EMars_Interactable_DisableReason::Operated));
    }

    UFUNCTION()
    private void Check_Enabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Lever.Get_EnableDisable() == ECk_EnableDisable::Enable);
    }

    UFUNCTION()
    private void Step_AssertAcceptedAndStart(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Result = utils_interact_target::Get_CanInteractWith(_Target, _Carrier);
        Assert_True(Result == ECk_CanInteractWithResult::CanInteractWith, f"the released lever accepts the carrier (got [{Result :n}])");

        _Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Check_HasInteraction(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(utils_interact_target::TryGet_Interaction(_Target, _Carrier)));
    }

    UFUNCTION()
    private void Step_ClaimLedger(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Lever.Request_Disable(FMars_Request_Interactable_Disable(EMars_Interactable_DisableReason::Ledger));
    }

    UFUNCTION()
    private void Check_InteractionGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(utils_interact_target::TryGet_Interaction(_Target, _Carrier)));
    }

    UFUNCTION()
    private void Step_AssertCancelled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_FinishedResults.Num(), 1, "the interaction finished once");
        if (_FinishedResults.Num() == 1)
        {
            Assert_True(_FinishedResults[0] != ECk_SucceededFailed::Succeeded,
                f"a cancelled interaction does not succeed (got [{_FinishedResults[0] :n}])");
        }

        Assert_True(utils_interact_target::Get_Enabled(_Target) == ECk_EnableDisable::Disable, "the framework target is disabled");
    }
}
