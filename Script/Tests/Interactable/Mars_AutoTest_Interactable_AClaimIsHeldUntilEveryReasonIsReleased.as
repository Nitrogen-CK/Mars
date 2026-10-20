// An interactable is enabled while no reason is held. A lever disabled for two reasons (Ledger and HotbarFull, claimed in
// one frame) stays disabled when one is released and is enabled only when the other is; its framework target follows in
// the same drain, and OnEnableDisableChanged fires once per edge (disabled, then enabled), not per claim. Claims apply in
// arrival order: a reason claimed and released in one frame leaves the lever enabled with nothing broadcast; released and
// claimed again in one frame leaves it held. Isolated origin (60000, -12000, -30000).
class UMars_AutoTest_Interactable_AClaimIsHeldUntilEveryReasonIsReleased : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 10.0f;

    private const FVector k_Origin = FVector(60000.0, -12000.0, -30000.0);

    private FCk_Handle_Interactable _Lever;
    private FCk_Handle_InteractTarget _Target;
    private TArray<ECk_EnableDisable> _Edges;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildLever(InHandle);
        _Lever.BindTo_OnEnableDisableChanged(FMars_Delegate_Interactable_OnEnableDisableChanged(this, n"OnEnableDisableChanged"));

        Add_Step("the lever starts enabled; claim Ledger and HotbarFull", n"Step_ClaimTwo");
        Add_Step_WaitUntil("the lever is disabled", n"Check_Disabled", 0, 0);
        Add_Step("both reasons are held and the framework target is disabled", n"Step_AssertBothHeld");
        Add_Step("release Ledger", n"Step_ReleaseLedger");
        Add_Step_WaitUntil("Ledger is no longer held", n"Check_LedgerReleased", 0, 0);
        Add_Step("HotbarFull still holds the lever and its framework target disabled", n"Step_AssertStillDisabled");
        Add_Step("release HotbarFull", n"Step_ReleaseHotbarFull");
        Add_Step_WaitUntil("the lever is enabled", n"Check_Enabled", 0, 0);
        Add_Step("no reason is held and the framework target is enabled", n"Step_AssertEnabled");
        Add_Step("claim and release Mounted in one frame", n"Step_ClaimThenReleaseMounted");
        Add_Step_WaitFrames("the pair drains", 3);
        Add_Step("the lever is still enabled and nothing was broadcast", n"Step_AssertPairChangedNothing");
        Add_Step("release and claim Operated in one frame", n"Step_ReleaseThenClaimOperated");
        Add_Step_WaitUntil("the lever is disabled", n"Check_Disabled", 0, 0);
        Add_Step("Operated is held alone and the framework target is disabled", n"Step_AssertOperatedHeld");
        Run_Steps(InHandle);
    }

    // A ManuallyCompleted lever with one Use target and no probe.
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
    }

    UFUNCTION()
    private void OnEnableDisableChanged(FCk_Handle_Interactable InInteractable, ECk_EnableDisable InEnableDisable)
    {
        _Edges.Add(InEnableDisable);
    }

    UFUNCTION()
    private void Step_ClaimTwo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Lever.Get_EnableDisable() == ECk_EnableDisable::Enable, "the lever starts enabled");
        Assert_True(utils_interact_target::Get_Enabled(_Target) == ECk_EnableDisable::Enable, "its framework target starts enabled");

        _Lever.Request_Disable(FMars_Request_Interactable_Disable(EMars_Interactable_DisableReason::Ledger));
        _Lever.Request_Disable(FMars_Request_Interactable_Disable(EMars_Interactable_DisableReason::HotbarFull));
    }

    UFUNCTION()
    private void Check_Disabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Lever.Get_EnableDisable() == ECk_EnableDisable::Disable);
    }

    UFUNCTION()
    private void Step_AssertBothHeld(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Lever.Get_IsDisabledFor(EMars_Interactable_DisableReason::Ledger), "Ledger is held");
        Assert_True(_Lever.Get_IsDisabledFor(EMars_Interactable_DisableReason::HotbarFull), "HotbarFull is held");
        Assert_True(utils_interact_target::Get_Enabled(_Target) == ECk_EnableDisable::Disable, "the framework target is disabled");
        Assert_Equals_Int(_Edges.Num(), 1, "two claims in one drain broadcast one edge");
    }

    UFUNCTION()
    private void Step_ReleaseLedger(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Lever.Request_Enable(FMars_Request_Interactable_Enable(EMars_Interactable_DisableReason::Ledger));
    }

    UFUNCTION()
    private void Check_LedgerReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Lever.Get_IsDisabledFor(EMars_Interactable_DisableReason::Ledger) == false);
    }

    UFUNCTION()
    private void Step_AssertStillDisabled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Lever.Get_EnableDisable() == ECk_EnableDisable::Disable, "the lever stays disabled while HotbarFull is held");
        Assert_True(_Lever.Get_IsDisabledFor(EMars_Interactable_DisableReason::HotbarFull), "HotbarFull is still held");
        Assert_True(utils_interact_target::Get_Enabled(_Target) == ECk_EnableDisable::Disable, "the framework target stays disabled");
        Assert_Equals_Int(_Edges.Num(), 1, "releasing one of two reasons broadcasts nothing");
    }

    UFUNCTION()
    private void Step_ReleaseHotbarFull(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Lever.Request_Enable(FMars_Request_Interactable_Enable(EMars_Interactable_DisableReason::HotbarFull));
    }

    UFUNCTION()
    private void Check_Enabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Lever.Get_EnableDisable() == ECk_EnableDisable::Enable);
    }

    UFUNCTION()
    private void Step_AssertEnabled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_interact_target::Get_Enabled(_Target) == ECk_EnableDisable::Enable, "the framework target is enabled again");
        Assert_Equals_Int(_Edges.Num(), 2, "one edge each way");
        if (_Edges.Num() == 2)
        {
            Assert_True(_Edges[0] == ECk_EnableDisable::Disable, "the first edge disabled the lever");
            Assert_True(_Edges[1] == ECk_EnableDisable::Enable, "the second edge enabled it");
        }
    }

    UFUNCTION()
    private void Step_ClaimThenReleaseMounted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Lever.Request_Disable(FMars_Request_Interactable_Disable(EMars_Interactable_DisableReason::Mounted));
        _Lever.Request_Enable(FMars_Request_Interactable_Enable(EMars_Interactable_DisableReason::Mounted));
    }

    UFUNCTION()
    private void Step_AssertPairChangedNothing(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Lever.Get_EnableDisable() == ECk_EnableDisable::Enable, "a reason claimed then released in one drain leaves the lever enabled");
        Assert_True(utils_interact_target::Get_Enabled(_Target) == ECk_EnableDisable::Enable, "the framework target stays enabled");
        Assert_Equals_Int(_Edges.Num(), 2, "the pair broadcasts nothing");
    }

    UFUNCTION()
    private void Step_ReleaseThenClaimOperated(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Lever.Request_Enable(FMars_Request_Interactable_Enable(EMars_Interactable_DisableReason::Operated));
        _Lever.Request_Disable(FMars_Request_Interactable_Disable(EMars_Interactable_DisableReason::Operated));
    }

    UFUNCTION()
    private void Step_AssertOperatedHeld(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Lever.Get_IsDisabledFor(EMars_Interactable_DisableReason::Operated), "the later claim holds Operated");
        Assert_False(_Lever.Get_IsDisabledFor(EMars_Interactable_DisableReason::Mounted), "Mounted is not held");
        Assert_True(utils_interact_target::Get_Enabled(_Target) == ECk_EnableDisable::Disable, "the framework target is disabled");
        Assert_Equals_Int(_Edges.Num(), 3, "one more edge");
    }
}
