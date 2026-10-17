class UMars_AutoTest_CrawlerMelee_CatalogAcquisitionConflict : UMars_AutoTestRig_CrawlerAttackCatalog
{
    default _TimeoutSeconds = 90.0f;
    default _Origin = FVector(-450000.0, -180000.0, 600.0);

    private FMars_TESTONLY_AttackCatalog_Stream _Holder;
    private FGameplayTag _RejectedId;
    private int32 _RejectedPolls = 0;
    private int64 _RaceFrame = 0;
    private FMars_Attack_LoadoutEvaluation _BeforeHolderAdvice;
    private bool _ImmediateDiagnostic = false;
    UPROPERTY() private UMars_Processor_Crawler_HandleRequests _Requests;
    UPROPERTY() private UMars_Processor_Crawler_AttackTick _Tick;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_CatalogSpec(false);
        _CatalogPincer.Def.Cooldown.ReuseSeconds = 5.0f;
        _CatalogJab.Def.Cooldown.ReuseSeconds = 5.0f;
        _Requests = Cast<UMars_Processor_Crawler_HandleRequests>(NewObject(this, UMars_Processor_Crawler_HandleRequests));
        _Tick = Cast<UMars_Processor_Crawler_AttackTick>(NewObject(this, UMars_Processor_Crawler_AttackTick));
        SpawnFloorAndCrawler(InHandle, Spec);
        Add_CatalogSettleSteps();
        Add_Step("spawn a reachable target", n"Step_CatalogTarget");
        Add_Step_WaitUntil("target is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("select the target", n"Step_CatalogSelectTarget");
        Add_Step_WaitUntil("target transport drains", n"Check_CatalogRequestsDrained", k_SlowPolls, 0);
        Add_Step_WaitUntil("fresh complete pincer advice is ready before creating either contender", n"Check_CatalogPincerReady", k_SlowPolls, 0);
        Add_Step("create a pending native holder and queue one game start in the same step", n"Step_Race");
        Add_Step_WaitUntil("the game attempt reports a real native acquisition terminal", n"Check_RejectedResult", k_SlowPolls, 0);
        Add_Step("C05 no accepted charge or damage follows the real Busy outcome", n"Step_AssertRejected");
        Add_Step("cancel the independent native holder", n"Step_CancelHolder");
        Add_Step_WaitUntil("holder terminal is read and acknowledged", n"Check_HolderTerminal", k_SlowPolls, 0);
        Add_Step_WaitUntil("native holder and game action both release", n"Check_Released", k_SlowPolls, 0);
        Add_Step("retry a normal game attack after cleanup", n"Step_TargetAndStart");
        Add_Step_WaitUntil("the retry actually accepts", n"Check_CatalogAccepted", k_SlowPolls, 0);
        Add_Step("accepted retry charges its entry once", n"Step_AssertRetry");
        Add_Step_WaitUntil("retry ends normally", n"Check_AttackFinished", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Race(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _RaceFrame = utils_time::Get_FrameCounter();
        _BeforeHolderAdvice = utils_crawler::Evaluate_AttackLoadout(_Crawler, _Target.Entity);
        Log(Describe_RaceAdvice(_BeforeHolderAdvice, f"[CatalogRaceBeforeHolder] frame {_RaceFrame}"));
        auto Bindings = TArray<FCk_ProceduralAction_SlotBinding>();
        Bindings.Add(FCk_ProceduralAction_SlotBinding(n"ClawRight", n"Leg0"));
        Bindings.Add(FCk_ProceduralAction_SlotBinding(n"ClawLeft", n"Leg5"));
        auto Play = FCk_ProceduralAction_PlaySpec(TSoftObjectPtr<UCk_ProceduralAction_Data>(_CatalogPincerSource));
        Play.Set_SlotBindings(Bindings);
        Play.Set_Delivery(ECk_ProceduralAction_Delivery::Explicit);
        auto Owner = InHandle;
        _Holder.Action = utils_procedural_action::Create_FromClip(Owner, _Crawler.Get_ActionPlayer(), Play);
        Assert_True(ck::IsValid(_Holder.Action) && _Holder.Action.Get_State() == ECk_ProceduralAction_State::PendingAdmission,
            "the independent holder is valid but has not yet acquired control at creation");
        _Holder.Identity = _Holder.Action.Get_Identity();
        Log(f"[CatalogRaceAfterHolder] frame {utils_time::Get_FrameCounter()}, holder {_Holder.Identity.Get_Value()}, state {_Holder.Action.Get_State() :n}, accepted {_Holder.Action.Get_LastReceipt().Get_HasAcceptedPose()}");
        Step_TargetAndStart(InHandle, InPayload);
        // Establish both real contenders before native service can acquire the holder. Native service traverses
        // enqueue order, so its first acquisition belongs to the holder and the game must observe the actual Busy.
        FMars_Fragment_Crawler_Requests Requests = _Crawler.Get_Fragment(FMars_Fragment_Crawler_Requests);
        FCk_Handle Entity = _Crawler;
        _Requests.ForEachEntity(FCk_Time(0.0), Entity, Requests);
        _Tick.ForEachEntity(FCk_Time(1.0e-6), Entity);
        const auto GameAction = _Crawler.Get_Fragment(FMars_Fragment_Crawler_Attack).Action;
        Assert_True(ck::IsValid(GameAction) && GameAction.Get_Identity().Get_Value() > 0 &&
            GameAction.Get_State() == ECk_ProceduralAction_State::PendingAdmission &&
            GameAction.Get_LastReceipt().Get_HasAcceptedPose() == false && _Crawler.Get_AttackAdmission().Accepted == false,
            "the owning game kernel created a real pending contender before any native accepted pose");
        Assert_True(_Holder.Action.Get_State() == ECk_ProceduralAction_State::PendingAdmission &&
            _Holder.Action.Get_LastReceipt().Get_HasAcceptedPose() == false &&
            _Holder.Identity.Get_Value() < _Crawler.Get_AttackAdmission().ActionIdentity.Get_Value(),
            "both contenders are still pending and the native holder was enqueued first");
    }

    private FString Describe_RaceAdvice(const FMars_Attack_LoadoutEvaluation& InAdvice, FString InPrefix) const
    {
        auto Details = f"{InPrefix}, selection {utils_crawler::Get_AttackDecisionSignature(InAdvice)}";
        for (const auto& Evaluation : InAdvice.Evaluations)
        {
            Details = f"{Details}; {Evaluation.AttackId} {Evaluation.Availability :n}";
            for (const auto& Blocker : Evaluation.Blockers)
            { Details = f"{Details} [{Blocker.Code} {Blocker.Field}: {Blocker.Expected} / {Blocker.Actual}]"; }
        }
        return Details;
    }

    private bool Drain_Holder()
    {
        if (_Holder.TerminalSeen)
        { return true; }
        auto Player = _Crawler.Get_ActionPlayer();
        const auto Page = Player.Read_Receipts(_Holder.Identity, _Holder.Cursor, 16);
        if (Page.Get_Result() == ECk_ProceduralAction_ReadResult::Gap || Page.Get_Result() == ECk_ProceduralAction_ReadResult::StreamExpired ||
            Page.Get_Result() == ECk_ProceduralAction_ReadResult::InvalidCursor || Page.Get_Result() == ECk_ProceduralAction_ReadResult::InvalidPlayer)
        {
            FinishFailure(f"the holder's explicit stream failed: {Page.Get_Result() :n}");
            return false;
        }
        for (const auto& Record : Page.Get_Records())
        {
            if (Record.Get_Kind() == ECk_ProceduralAction_RecordKind::AcceptedPose)
            { ++_Holder.Accepted.Count; }
            else if (Record.Get_Kind() == ECk_ProceduralAction_RecordKind::Terminal)
            {
                _Holder.TerminalSeen = true;
                _Holder.Result = Record.Get_Result();
            }
        }
        _Holder.Cursor = Page.Get_LastStreamSequence();
        if (Page.Get_Records().Num() > 0)
        { Player.Request_ConsumeReceipts(FCk_Request_ProceduralActionPlayer_ConsumeReceipts(_Holder.Identity, _Holder.Cursor)); }
        return true;
    }

    UFUNCTION()
    private void Check_RejectedResult(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Drain_Holder() == false)
        { return; }
        if (_ImmediateDiagnostic == false && _Crawler.Get_HasPendingCombatRequests() == false &&
            _Crawler.Get_AttackAdmission().ActionIdentity.Get_Value() == 0 && _CatalogResults.Num() == 0 &&
            _Crawler.Get_AttackLastReject().IsSet())
        {
            _ImmediateDiagnostic = true;
            const FString HolderState = ck::IsValid(_Holder.Action) ? f"{_Holder.Action.Get_State() :n}" : "Released";
            const auto Fresh = utils_crawler::Evaluate_AttackLoadout(_Crawler, _Target.Entity);
            auto Details = f"[CatalogRaceDrainedWithoutAction] race frame {_RaceFrame}, now {utils_time::Get_FrameCounter()}, reject {Get_LastRejectText()}, phase {_Crawler.Get_AttackPhase() :n}, holder {_Holder.Identity.Get_Value()}/{HolderState}, holder accepted {_Holder.Accepted.Count}, holder terminal {_Holder.TerminalSeen}; {Get_CrawlerDiagnostics()}";
            Details = Describe_RaceAdvice(_BeforeHolderAdvice, Details + "; before-holder");
            Details = Describe_RaceAdvice(Fresh, Details + "; current-fresh");
            Log(Details);
        }
        if (_CatalogResults.Num() == 0 && ++_RejectedPolls == 60)
        {
            const auto Admission = _Crawler.Get_AttackAdmission();
            const auto Decision = _Crawler.Get_AttackDecision();
            const auto Action = _Crawler.Get_Fragment(FMars_Fragment_Crawler_Attack).Action;
            const FString HolderState = ck::IsValid(_Holder.Action) ? f"{_Holder.Action.Get_State() :n}" : "Released";
            const FString GameState = ck::IsValid(Action) ? f"{Action.Get_State() :n}" : "Absent";
            auto Details = f"race frame {_RaceFrame}, now {utils_time::Get_FrameCounter()}, reject {Get_LastRejectText()}, results {_CatalogResults.Num()}, phase {_Crawler.Get_AttackPhase() :n}, game action {Admission.ActionIdentity.Get_Value()}/{GameState}, accepted {Admission.Accepted}, holder {_Holder.Identity.Get_Value()}/{HolderState}, holder accepted {_Holder.Accepted.Count}, holder terminal {_Holder.TerminalSeen}/{_Holder.Result.Get_Outcome() :n}/{_Holder.Result.Get_Reason()}, decision {Decision.Signature}; {Get_CrawlerDiagnostics()}";
            for (const auto& Evaluation : Decision.Evaluation.Evaluations)
            {
                Details = f"{Details}; {Evaluation.AttackId} {Evaluation.Availability :n}";
                for (const auto& Blocker : Evaluation.Blockers)
                { Details = f"{Details} [{Blocker.Code} {Blocker.Field}: {Blocker.Expected} / {Blocker.Actual}]"; }
            }
            for (const auto Id : _Crawler.Get_Fragment(FMars_Fragment_Crawler_Attack).Cleanup.ClaimedIds)
            {
                const auto Control = _Crawler.Get_Articulation().Get_LimbControl(Id);
                Details = f"{Details}; game claim {Id} {Control.Get_State() :n} owner {Control.Get_Owner().ToString()}";
            }
            const auto Right = _Crawler.Get_Articulation().Get_LimbControl(n"Leg0");
            const auto Left = _Crawler.Get_Articulation().Get_LimbControl(n"Leg5");
            Details = f"{Details}; holder slots Leg0 {Right.Get_State() :n} owner {Right.Get_Owner().ToString()}, Leg5 {Left.Get_State() :n} owner {Left.Get_Owner().ToString()}, body status {_Crawler.Get_BodyPose().Get_Status() :n}, body owner unavailable through public AS observation";
            Log(f"[CatalogAcquisitionDiagnostic] {Details}");
        }
        auto Res = OutResult;
        Res.Set(_CatalogResults.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertRejected(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (_CatalogResults.Num() == 0)
        { FinishFailure("the game never created a native acquisition attempt"); return; }
        const auto Result = _CatalogResults[0];
        _RejectedId = Result.AttackId;
        Assert_True(Result.ActionIdentity.Get_Value() > 0 && Result.Accepted == false &&
            Result.Native.Get_Outcome() == ECk_ProceduralAction_Outcome::Rejected && Result.Native.Get_Reason() == n"Busy",
            f"the game action really failed native acquisition, not an earlier advice rejection: {Result.Native.Get_Outcome() :n} [{Result.Native.Get_Reason()}]");
        Assert_True(_Holder.Accepted.Count > 0, "the independent holder actually acquired and accepted motion");
        Assert_Equals_Int(_CatalogAdmissions.Num(), 0, "rejected-before-accept attempt emitted zero accepted-admission signals");
        Assert_True(Get_CatalogLastStart(_RejectedId) == 0 && Get_CatalogReuseRemaining(_RejectedId) == 0.0f,
            "native acquisition rejection charged neither entry reuse nor least-recent admission history");
        Assert_Equals_Int(Get_DamageRequestCount(), 0, "the rejected pending attempt emitted zero damage");
        Assert_Equals_Int(_CatalogResults.Num(), 1, "one queued start created only one reported game attempt");
        Log(f"[CatalogAcquisitionConflict] game ID [{_RejectedId.ToString()}], native [{Result.Native.Get_Outcome() :n}/{Result.Native.Get_Reason()}], accepted [{Result.Accepted}], cleanup [{Result.CleanupOutcome}]");
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
        if (Drain_Holder() == false)
        { return; }
        auto Res = OutResult;
        Res.Set(_Holder.TerminalSeen);
    }

    UFUNCTION()
    private void Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Retained = false;
        for (const auto& Identity : _Crawler.Get_ActionPlayer().Get_RetainedReceiptIdentities())
        { Retained = Retained || Identity.Get_Value() == _Holder.Identity.Get_Value(); }
        auto Res = OutResult;
        Res.Set(_Holder.TerminalSeen && Retained == false && ck::Is_NOT_Valid(_Holder.Action) &&
            _Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::Idle && Get_AreCatalogClawsReturned());
    }

    UFUNCTION()
    private void Step_AssertRetry(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_CatalogAdmissions.Num(), 1, "the retry produces one accepted admission");
        Assert_True(Get_CatalogLastStart(_Crawler.Get_AttackId()) > 0 && Get_CatalogReuseRemaining(_Crawler.Get_AttackId()) > 0.0f,
            "reuse and start sequence charge only after the retry's first accepted receipt");
    }
}
