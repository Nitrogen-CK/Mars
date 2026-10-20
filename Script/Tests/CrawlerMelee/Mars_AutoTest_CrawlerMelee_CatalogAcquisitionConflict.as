// The holder command: armed by the test, it creates the independent pincer holder in the frame the game's start drains,
// just before the drain, so both contenders are enqueued before native service can acquire either, the holder first.
struct FMars_TESTONLY_CrawlerMelee_HolderCommand
{
    FCk_Handle_Crawler Crawler;
    TSoftObjectPtr<UCk_ProceduralAction_Data> Clip;
    bool Armed = false;
    FCk_Handle_ProceduralAction Action;
    int64 Frame = 0;
}

class UMars_TESTONLY_Processor_CrawlerMelee_HolderCommand : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunBefore.Add(n"/Script/Angelscript.Mars_Processor_Crawler_HandleRequests");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query) {}

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_TESTONLY_CrawlerMelee_HolderCommand& InCommand)
    {
        if (InCommand.Armed == false || ck::IsValid(InCommand.Action) || ck::Is_NOT_Valid(InCommand.Crawler))
        { return; }

        auto Bindings = TArray<FCk_ProceduralAction_SlotBinding>();
        Bindings.Add(FCk_ProceduralAction_SlotBinding(n"ClawRight", n"Leg0"));
        Bindings.Add(FCk_ProceduralAction_SlotBinding(n"ClawLeft", n"Leg5"));
        auto Play = FCk_ProceduralAction_PlaySpec(InCommand.Clip);
        Play.Set_SlotBindings(Bindings);
        Play.Set_Delivery(ECk_ProceduralAction_Delivery::Explicit);
        InCommand.Action = utils_procedural_action::Create_FromClip(InHandle, InCommand.Crawler.Get_ActionPlayer(), Play);
        InCommand.Frame = utils_time::Get_FrameCounter();
        InCommand.Armed = false;
    }
}

// An independent pincer holder and the game's own pincer contend for the same claws in one frame, the holder enqueued
// first. The game's attempt is created and then refused by native acquisition (Busy): no accepted admission, no reuse or
// least-recent charge, no damage. Once the holder is cancelled and released, a retry is admitted and charged once.
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
    private FCk_Handle _HolderCommand;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_CatalogSpec(false);
        _CatalogPincer.Def.Cooldown.ReuseSeconds = 5.0f;
        _CatalogJab.Def.Cooldown.ReuseSeconds = 5.0f;
        SpawnFloorAndCrawler(InHandle, Spec);
        Add_CatalogSettleSteps();
        Add_Step("spawn a reachable target", n"Step_CatalogTarget");
        Add_Step_WaitUntil("target is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("select the target", n"Step_CatalogSelectTarget");
        Add_Step_WaitUntil("target transport drains", n"Check_CatalogRequestsDrained", k_SlowPolls, 0);
        Add_Step_WaitUntil("fresh complete pincer advice is ready before creating either contender", n"Check_CatalogPincerReady", k_SlowPolls, 0);
        Add_Step("arm the holder and queue one game start in the same step", n"Step_Race");
        Add_Step_WaitUntil("the holder and the game attempt both exist", n"Check_Contenders", k_SlowPolls, 0);
        Add_Step("both contenders were created in one frame, the holder first", n"Step_AssertContenders");
        Add_Step_WaitUntil("the game attempt reports a real native acquisition terminal", n"Check_RejectedResult", k_SlowPolls, 0);
        Add_Step("no accepted charge or damage follows the real Busy outcome", n"Step_AssertRejected");
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
        auto Command = FMars_TESTONLY_CrawlerMelee_HolderCommand();
        Command.Crawler = _Crawler;
        Command.Clip = TSoftObjectPtr<UCk_ProceduralAction_Data>(_CatalogPincerSource);
        Command.Armed = true;
        _HolderCommand = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _HolderCommand.Add_Fragment(Command);
        Step_TargetAndStart(InHandle, InPayload);
    }

    UFUNCTION()
    private void Check_Contenders(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto& Command = _HolderCommand.Get_Fragment(FMars_TESTONLY_CrawlerMelee_HolderCommand);
        auto Res = OutResult;
        Res.Set(ck::IsValid(Command.Action) && _Crawler.Get_HasPendingCombatRequests() == false &&
            (_Crawler.Get_AttackActionIdentity().Get_Value() > 0 || _CatalogResults.Num() > 0 || _Crawler.Get_AttackLastReject().IsSet()));
    }

    UFUNCTION()
    private void Step_AssertContenders(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto& Command = _HolderCommand.Get_Fragment(FMars_TESTONLY_CrawlerMelee_HolderCommand);
        _Holder.Action = Command.Action;
        _Holder.Identity = Command.Action.Get_Identity();
        const auto GameIdentity = _Crawler.Get_AttackAdmission().ActionIdentity.Get_Value();
        Assert_True(GameIdentity > 0 && _Crawler.Get_AttackLastReject().IsSet() == false,
            f"the game kernel created its own attempt rather than refusing the start on advice (last reject {Get_LastRejectText()})");
        Assert_True(_Holder.Identity.Get_Value() > 0 && _Holder.Identity.Get_Value() < GameIdentity,
            f"the holder was enqueued before the game attempt (holder {_Holder.Identity.Get_Value()}, game {GameIdentity}, holder frame {Command.Frame})");
    }

    private FString Describe_RaceAdvice(const FMars_Attack_LoadoutEvaluation& InAdvice, FString InPrefix) const
    {
        auto Details = f"{InPrefix}, selection {utils_crawler::Get_AttackDecisionSignature(InAdvice)}";
        for (const auto& Evaluation : InAdvice.Evaluations)
        {
            Details = f"{Details}; {Evaluation.AttackId} {Evaluation.Availability :n}";
            for (const auto& Blocker : Evaluation.Blockers)
            { Details = f"{Details} [{Blocker.Code :n} {Blocker.Field}: {Blocker.Expected} / {Blocker.Actual}]"; }
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
        if (_CatalogResults.Num() == 0)
        { ++_RejectedPolls; }

        if (_CatalogResults.Num() == 0 && _RejectedPolls == 60)
        {
            const auto Admission = _Crawler.Get_AttackAdmission();
            const auto Decision = _Crawler.Get_AttackDecision();
            const auto Action = _Crawler.Get_AttackAction();
            const FString HolderState = ck::IsValid(_Holder.Action) ? f"{_Holder.Action.Get_State() :n}" : "Released";
            const FString GameState = ck::IsValid(Action) ? f"{Action.Get_State() :n}" : "Absent";
            auto Details = f"race frame {_RaceFrame}, now {utils_time::Get_FrameCounter()}, reject {Get_LastRejectText()}, results {_CatalogResults.Num()}, phase {_Crawler.Get_AttackPhase() :n}, game action {Admission.ActionIdentity.Get_Value()}/{GameState}, accepted {Admission.Accepted}, holder {_Holder.Identity.Get_Value()}/{HolderState}, holder accepted {_Holder.Accepted.Count}, holder terminal {_Holder.TerminalSeen}/{_Holder.Result.Get_Outcome() :n}/{_Holder.Result.Get_Reason()}, decision {Decision.Signature}; {Get_CrawlerDiagnostics()}";
            for (const auto& Evaluation : Decision.Evaluation.Evaluations)
            {
                Details = f"{Details}; {Evaluation.AttackId} {Evaluation.Availability :n}";
                for (const auto& Blocker : Evaluation.Blockers)
                { Details = f"{Details} [{Blocker.Code :n} {Blocker.Field}: {Blocker.Expected} / {Blocker.Actual}]"; }
            }
            for (const auto Id : _Crawler.Get_AttackCleanup().ClaimedIds)
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
