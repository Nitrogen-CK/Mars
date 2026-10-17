class UMars_AutoTest_AttackCatalog_AdmissionIsAsynchronous : UMars_AutoTestRig_AttackCatalogPublicSurface
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(-370000.0, -180000.0, 600.0);

    private FMars_TESTONLY_AttackCatalog_Stream _Holder;
    private FMars_TESTONLY_AttackCatalog_Stream _Contender;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_ProbeCrawler(InHandle);
        Add_Step("play a valid action that claims both claws", n"Step_Holder");
        Add_Step_WaitUntil("the holder has accepted motion and owns both controls", n"Check_Holder", k_SlowPolls, 0);
        Add_Step("create another valid action with those same bindings", n"Step_Contender");
        Add_Step_WaitUntil("asynchronous acquisition rejects the contender", n"Check_Rejected", k_SlowPolls, 0);
        Add_Step("inspect rejection before the holder releases", n"Step_AssertRejected");
        Add_Step_WaitUntil("the rejected terminal acknowledgement releases its identity", n"Check_ContenderReleased", k_SlowPolls, 0);
        Add_Step("cancel the holder", n"Step_CancelHolder");
        Add_Step_WaitUntil("the holder terminal is observed and acknowledged", n"Check_HolderTerminal", k_SlowPolls, 0);
        Add_Step_WaitUntil("both streams release and both controls are Default", n"Check_AllReleased", k_SlowPolls, 0);
        Add_Step("assert no claims or game damage remain", n"Step_AssertCleanup");
        Run_Steps(InHandle);
    }

    private bool Get_HolderOwnsClaws() const
    {
        FCk_Handle HolderEntity = _Holder.Action;
        for (const auto Id : _ProbeLimbIds)
        {
            const auto Control = _Crawler.Get_Articulation().Get_LimbControl(Id);
            if (Control.Get_State() != ECk_ProceduralLimbControl_State::Controlled || Control.Get_Owner() != HolderEntity)
            { return false; }
        }
        return true;
    }

    UFUNCTION()
    private void Step_Holder(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Holder = Create_ProbeAction(InHandle, _ProbeClip);
    }

    UFUNCTION()
    private void Check_Holder(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Drain_ProbeStream(_Holder) == false)
        { return; }
        auto Res = OutResult;
        Res.Set(_Holder.Accepted.Count > 0 && Get_HolderOwnsClaws());
    }

    UFUNCTION()
    private void Step_Contender(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_HolderOwnsClaws(), "the holder still owns the valid bindings when the contender is created");
        _Contender = Create_ProbeAction(InHandle, _ProbeClip);
        Assert_True(_Contender.Identity.Get_Value() != _Holder.Identity.Get_Value(), "the contender has its own action identity");
        const auto Page = _Crawler.Get_ActionPlayer().Read_Receipts(_Contender.Identity, 0, 16);
        Assert_True(Page.Get_Records().Num() == 0 && Page.Get_Terminal() == false,
            "creation returned a valid action before any accepted admission or terminal result");
    }

    UFUNCTION()
    private void Check_Rejected(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Drain_ProbeStream(_Holder) == false || Drain_ProbeStream(_Contender) == false)
        { return; }
        auto Res = OutResult;
        Res.Set(_Contender.TerminalSeen);
    }

    UFUNCTION()
    private void Step_AssertRejected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Contender.Accepted.Count, 0, "rejected acquisition published zero accepted poses");
        Assert_True(_Contender.Result.Get_Outcome() == ECk_ProceduralAction_Outcome::Rejected &&
            _Contender.Result.Get_Recovery() == ECk_ProceduralAction_Recovery::NotRequired &&
            _Contender.Result.Get_Reason() == n"Busy", "valid conflicting acquisition reports Rejected / NotRequired / Busy");
        Assert_True(Get_HolderOwnsClaws(), "the rejected contender did not replace the holder's claims");
        Assert_ProbeDidNotEnterGameCombat();
    }

    UFUNCTION()
    private void Check_ContenderReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Drain_ProbeStream(_Holder) == false)
        { return; }
        auto Res = OutResult;
        Res.Set(Get_IsProbeReleased(_Contender));
    }

    UFUNCTION()
    private void Step_CancelHolder(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (_Holder.TerminalSeen == false)
        { _Holder.Action.Request_Cancel(FCk_Request_ProceduralAction_Cancel()); }
    }

    UFUNCTION()
    private void Check_HolderTerminal(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Drain_ProbeStream(_Holder) == false)
        { return; }
        auto Res = OutResult;
        Res.Set(_Holder.TerminalSeen);
    }

    UFUNCTION()
    private void Check_AllReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsProbeReleased(_Holder) && Get_IsProbeReleased(_Contender) && Get_AreProbeControlsDefault());
    }

    UFUNCTION()
    private void Step_AssertCleanup(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Holder.Result.Get_Recovery() == ECk_ProceduralAction_Recovery::Succeeded,
            "the holder returned its claws after the rejected action was acknowledged");
        Assert_True(_Crawler.Get_Articulation().Get_IsAnyLimbControlled() == false,
            "neither probe stranded a controlled limb");
        Assert_ProbeDidNotEnterGameCombat();
    }
}
