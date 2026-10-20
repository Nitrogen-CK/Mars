class UMars_AutoTest_CrawlerMelee_CatalogProcessedSever : UMars_AutoTestRig_CrawlerAttackCatalog
{
    default _TimeoutSeconds = 120.0f;
    default _Origin = FVector(-460000.0, -180000.0, 600.0);

    protected EMars_TESTONLY_CatalogBoundary _Boundary = EMars_TESTONLY_CatalogBoundary::Strike;
    private FCk_Handle _BoundaryEntity;
    private FCk_Handle_BodyPart _LostPart;
    private FCk_Handle_ProceduralLeg _Survivor;
    private int32 _DamageAtProcessed = 0;
    private int32 _ProcessedPolls = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_CatalogSpec(false));
        Add_CatalogSettleSteps();
        Add_Step("spawn a reachable target", n"Step_CatalogTarget");
        Add_Step_WaitUntil("target geometry is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("select the first pincer target", n"Step_CatalogSelectTarget");
        Add_Step_WaitUntil("the first target transport has drained", n"Check_CatalogRequestsDrained", k_SlowPolls, 0);
        Add_Step_WaitUntil("fresh complete pincer advice is ready before arming the boundary", n"Check_CatalogPincerReady", k_SlowPolls, 0);
        Add_Step("arm a public sever at the requested processed boundary", n"Step_Arm");
        Add_Step("start a pincer", n"Step_TargetAndStart");
        Add_Step_WaitUntil("Health depletion, BodyPart sever and native detach have processed", n"Check_Processed", k_SlowPolls, 0);
        Add_Step_WaitUntil("cancel/managed return/autonomous obligations finish", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitUntil("the survivor is Default and planted on an operational articulation", n"Check_Survivor", k_SlowPolls, 0);
        Add_Step("no candidate or damage survived processed invalidation", n"Step_AssertBoundary");
        // A processed hit exits Roam for Flinch. Re-entered Roam picks another goal once the attack releases;
        // establish this direct-start fixture's stationary geometry again before checking the next attack.
        Add_Step_WaitUntil("Flinch has returned the passive crawler to Roam", n"Check_InRoam", k_SlowPolls, 0);
        Add_Step("stop the resumed roaming navigator", n"Step_StopCrawlerNavigator");
        Add_Step_WaitUntil("the resumed navigation stop has drained", n"Check_CrawlerNavigatorStopped", k_SlowPolls, 0);
        Add_Step_WaitUntil("the recovered crawler rests with a stable heading for one second", n"Check_AtRest", k_SlowPolls, 0);
        Add_Step("place a fresh fallback target from the recovered settled pose", n"Step_RenewFallbackTarget");
        Add_Step_WaitUntil("fresh fallback geometry is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("select the fresh fallback target", n"Step_CatalogSelectTarget");
        Add_Step_WaitUntil("the new target transport has drained", n"Check_CatalogRequestsDrained", k_SlowPolls, 0);
        Add_Step_WaitUntil("a fresh eligible fallback is ready", n"Check_FallbackReady", k_SlowPolls, 0);
        Add_Step("request the next automatic attack", n"Step_TargetAndStart");
        Add_Step_WaitUntil("a real fallback admission accepts", n"Check_CatalogAccepted", k_SlowPolls, 0);
        Add_Step("the next attempt uses Jab instead of a mid-animation swap", n"Step_AssertFallback");
        Add_Step_WaitUntil("the fallback finishes", n"Check_AttackFinished", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Arm(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _LostPart = _Crawler.Get_LegParts().Last();
        _Survivor = _Crawler.Get_LegParts()[0].Get_Leg();
        _BoundaryEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Command = FMars_TESTONLY_CatalogBoundaryCommand();
        Command.Crawler = _Crawler;
        Command.Health = _LostPart.Get_Health();
        Command.When = _Boundary;
        _BoundaryEntity.AddOrGet_Fragment(FMars_TESTONLY_CatalogBoundaryCommand) = Command;
    }

    UFUNCTION()
    private void Step_RenewFallbackTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_entity_lifetime::Request_DestroyEntity(_Target.Entity);
        Step_CatalogTarget(InHandle, InPayload);
    }

    UFUNCTION()
    private void Check_Processed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Evidence = _BoundaryEntity.Get_Fragment(FMars_TESTONLY_CatalogBoundaryCommand).Evidence;
        const auto Processed = Evidence.Fired && _LostPart.Get_Health().Get_IsDepleted() &&
            _LostPart.Get_State() == EMars_BodyPart_State::Severed && utils_procedural_leg::Get_IsAttached(_LostPart.Get_Leg()) == false;
        if (Processed)
        {
            _DamageAtProcessed = _Crawler.Get_IssuedDamageRequests();
            Assert_Equals_Int(_DamageAtProcessed, Evidence.DamageRequests,
                "the canonical Health/BodyPart boundary invalidated the candidate before AttackTick could issue damage");
        }
        else if (++_ProcessedPolls == 60)
        {
            const auto Admission = _Crawler.Get_AttackAdmission();
            const auto Result = _Crawler.Get_AttackResult();
            const auto Action = _Crawler.Get_AttackAction();
            const FString NativeState = ck::IsValid(Action) ? f"{Action.Get_State() :n}" : "Absent";
            auto Details = f"[CatalogBoundaryDiagnostic] boundary {_Boundary :n}, fired {Evidence.Fired}/{Evidence.Frame}, candidate at fired {Evidence.CandidatePending}, candidate now {_Crawler.Get_AttackCandidatePending()}, phase {_Crawler.Get_AttackPhase() :n}, reject {Get_LastRejectText()}, cancel {Get_LastCancelText()}, action {Admission.ActionIdentity.Get_Value()}/{NativeState}, accepted {Admission.Accepted}, issued damage {_Crawler.Get_IssuedDamageRequests()}, native terminal {Result.Native.Get_Outcome() :n}/{Result.Native.Get_Reason()}, observed {Result.Evidence.Observed}/{Result.Evidence.Source}/{Result.Evidence.Failure}; {Get_CrawlerDiagnostics()}";
            const auto Fresh = utils_crawler::Evaluate_AttackLoadout(_Crawler, _Target.Entity);
            Details = f"{Details}; current advice {utils_crawler::Get_AttackDecisionSignature(Fresh)}";
            for (const auto& Evaluation : Fresh.Evaluations)
            {
                Details = f"{Details}; {Evaluation.AttackId} {Evaluation.Availability :n}";
                for (const auto& Blocker : Evaluation.Blockers)
                { Details = f"{Details} [{Blocker.Code :n} {Blocker.Field}: {Blocker.Expected} / {Blocker.Actual}]"; }
            }
            Log(Details);
            // The current advice may have recovered by this poll. Preserve the kernel's copied rejection-time facts.
            for (const auto& Event : _Crawler.Get_AttackHistory())
            {
                if (Event.Event != n"Rejected")
                { continue; }
                auto Rejected = f"[CatalogBoundaryRejectedSnapshot] {Event.Reason}, attempt {Event.Context.AttemptGeneration}, selection {Event.Context.SelectionGeneration}, target {Event.Context.TargetGeneration}";
                for (const auto& Evaluation : Event.Context.Evaluation.Evaluations)
                {
                    Rejected = f"{Rejected}; {Evaluation.AttackId} {Evaluation.Availability :n}";
                    for (const auto& Blocker : Evaluation.Blockers)
                    { Rejected = f"{Rejected} [{Blocker.Code :n} {Blocker.Field}: {Blocker.Expected} / {Blocker.Actual}]"; }
                }
                Log(Rejected);
            }
        }
        auto Res = OutResult;
        Res.Set(Processed);
    }

    UFUNCTION()
    private void Check_Survivor(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_Articulation().Get_Health() == ECk_ProceduralArticulation_Health::Operational &&
            _Crawler.Get_Articulation().Get_LimbControl(utils_procedural_leg::Get_Id(_Survivor)).Get_State() == ECk_ProceduralLimbControl_State::Default &&
            utils_procedural_leg::Get_Foot(_Survivor).Get_Phase() == ECk_ProceduralLeg_FootPhase::Planted);
    }

    UFUNCTION()
    private void Step_AssertBoundary(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Evidence = _BoundaryEntity.Get_Fragment(FMars_TESTONLY_CatalogBoundaryCommand).Evidence;
        Assert_True(Evidence.Fired && Evidence.Frame > 0, "the mutation was injected at an observed live boundary");
        if (_Boundary == EMars_TESTONLY_CatalogBoundary::Candidate)
        {
            Assert_True(Evidence.CandidatePending, "the sever exercise had a real candidate waiting for commit");
            Assert_Equals_Int(_DamageAtProcessed, 0, "the severed candidate never issued its damage request");
        }
        Assert_Equals_Int(_Crawler.Get_IssuedDamageRequests(), _DamageAtProcessed,
            "zero additional issued damage requests follow processed required-part invalidation, including pending dealer requests");
        Assert_True(_CatalogResults.Num() == 1 && _CatalogResults[0].AttackId == GameplayTags::Attack_Mars_Pincer && _CatalogResults[0].Accepted,
            "one accepted pincer terminates without replacing its committed identity");
        if (_CatalogResults.Num() != 1)
        { return; }
        const auto Result = _CatalogResults[0];
        Assert_True(Result.RequiredPartFailures.Num() > 0, "the terminal retains the required-part failure even when Hurt is the primary cancellation");
        Assert_True(Result.Native.Get_Recovery() != ECk_ProceduralAction_Recovery::Pending,
            "the result exposes a terminal native managed recovery outcome");
        Log(f"[CatalogProcessedSever] boundary {_Boundary :n}, managed {Result.Native.Get_Outcome() :n}/{Result.Native.Get_Recovery() :n} [{Result.Native.Get_Reason()}], game cleanup [{Result.CleanupOutcome}], survivor Default/Planted/Operational");
        Assert_True(_Crawler.Get_AttackWindowClosed() && _Crawler.Get_AttackCandidatePending() == false,
            "processed invalidation closes damage and discards candidate evidence");
    }

    UFUNCTION()
    private void Check_FallbackReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Advice = utils_crawler::Evaluate_AttackLoadout(_Crawler, _Target.Entity);
        auto Res = OutResult;
        Res.Set(Advice.Selection.Selected.IsSet() && Advice.Selection.Selected.GetValue() == GameplayTags::Attack_Mars_Jab);
    }

    UFUNCTION()
    private void Step_AssertFallback(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Crawler.Get_AttackId() == GameplayTags::Attack_Mars_Jab && _Crawler.Get_AttackPlan().Entry.Slots.Num() == 0,
            "the next automatic attempt selects body Jab after cleanup, without a mid-action swap");
        Assert_Equals_Int(_CatalogAdmissions.Num(), 2, "one interrupted admission and one fresh fallback admission are visible");
    }
}
