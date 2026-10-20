// D02 integrated public contract: target requests, callback-visible decisions, bounded chronological history.
// Uses the established passive catalogue fixture; never requests an attack or writes a production fragment.
class UMars_AutoTest_AttackCatalog_DecisionHistory : UMars_AutoTestRig_CrawlerAttackCatalog
{
    default _TimeoutSeconds = 90.0f;
    default _Origin = FVector(-900000.0, -180000.0, 600.0);

    private FMars_AutoTest_CrawlerMelee_Target _FirstTarget;
    private FMars_AutoTest_CrawlerMelee_Target _SecondTarget;
    private FCk_Handle _ExpectedTarget;
    private int32 _SwitchesCompleted = 0;
    private int32 _BeforeTargetGeneration = 0;
    private int32 _BeforeSignals = 0;
    private int32 _DecisionSignals = 0;
    private int32 _InitialAttemptGeneration = 0;
    private int64 _OldFirstSequence = 0;
    // Copies observed through the public getter during real broadcasts, not a simulated history ring.
    private TArray<FMars_Attack_HistoryEntry> _ObservedPublications;
    private int32 _QuietSignals = 0;
    private FMars_Attack_Decision _QuietDecision;
    private TArray<FMars_Attack_HistoryEntry> _QuietHistory;
    private int64 _QuietFrame = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_CatalogSpec(false));
        Add_CatalogSettleSteps(); // Includes tracking every composed leg part for fixture cleanup.
        Add_Step("own two stationary combat targets and bind the callback-state observer", n"Step_ArrangeMonitor");
        for (int32 Index = 0; Index < 20; ++Index)
        {
            Add_Step(f"queue public alternating target request {Index + 1}/20", n"Step_QueueTarget");
            Add_Step_WaitUntil(f"request {Index + 1}/20 drains and its generation/decision is observed", n"Check_TargetObserved", k_SlowPolls, 0);
            Add_Step(f"confirm request {Index + 1}/20 caused a real decision publication", n"Step_ConfirmTarget");
        }
        Add_Step("latest 16 histories are chronological callback-observed publications; old first is evicted", n"Step_AssertHistory");
        // The harness's WaitFrames counts processor pumps; more than one pump can share GFrameCounter.
        Add_Step_WaitUntil("observe ten actual engine frames without requests or cooldowns", n"Check_QuietFrames", k_SlowPolls, 0);
        Add_Step("unchanged decision adds no history or signal during those ten passes", n"Step_AssertQuiet");
        Run_Steps(InHandle);
    }

    private bool Same_OptionalName(const TOptional<FGameplayTag>& InLeft, const TOptional<FGameplayTag>& InRight) const
    {
        if (InLeft.IsSet() != InRight.IsSet()) { return false; }
        return InLeft.IsSet() == false || InLeft.GetValue() == InRight.GetValue();
    }

    private bool Same_Selection(const FMars_Attack_Selection& InLeft, const FMars_Attack_Selection& InRight) const
    {
        return InLeft.Disposition == InRight.Disposition && Same_OptionalName(InLeft.Preferred, InRight.Preferred) &&
            Same_OptionalName(InLeft.ReadyChoice, InRight.ReadyChoice) && Same_OptionalName(InLeft.Selected, InRight.Selected);
    }

    private void Assert_NoAttackOrCooldown()
    {
        Assert_True(_Crawler.Get_IsAggressive() == false, "the fixture remains passive; targeting/behaviour cannot start an attack");
        Assert_True(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::Idle && ck::Is_NOT_Valid(_Crawler.Get_AttackAction()),
            "the decision-history scenario has no running attack");
        Assert_Equals_Int(_Crawler.Get_AttackGeneration(), _InitialAttemptGeneration, "no attempt generation was allocated");
        Assert_Equals_Int(_CatalogAdmissions.Num(), 0, "no accepted game admission was broadcast");
        Assert_Equals_Int(_CatalogResults.Num(), 0, "no game terminal result was broadcast");
        Assert_Equals_Int(Get_DamageRequestCount(), 0, "decision changes queued no damage");
        Assert_True(_Crawler.Get_AttackPreparation().State == EMars_Attack_PreparationState::Idle, "the fixture queued no preparation lifecycle");
        Assert_Equals_Float(_Crawler.Get_AttackCooldownRemaining(), 0.0f, 0.0001f, "common recovery cooldown is idle");
        for (const auto& Reuse : _Crawler.Get_AttackReuse())
        { Assert_True(Reuse.Remaining == 0.0f && Reuse.LastStartSequence == 0, "entry clocks have no accepted start to advance"); }
    }

    UFUNCTION()
    private void Step_ArrangeMonitor(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _InitialAttemptGeneration = _Crawler.Get_AttackGeneration();
        // Both targets are out of attack range on the fixture floor. Passive behaviour never scans or pursues them.
        _FirstTarget = SpawnCombatTarget(InHandle, _SettledLocation + _SettledForward * 800.0, FVector(10.0, 20.0, 20.0));
        _SecondTarget = SpawnCombatTarget(InHandle, _SettledLocation - _SettledForward * 800.0, FVector(10.0, 20.0, 20.0));
        Track_ForCleanup(_FirstTarget.Entity); Track_ForCleanup(_SecondTarget.Entity);
        const auto InitialHistory = _Crawler.Get_AttackHistory();
        if (InitialHistory.Num() == 0)
        { FinishFailure("settled composed crawler has no initial public decision history to test eviction"); return; }
        _OldFirstSequence = InitialHistory[0].Sequence;
        _Crawler.BindTo_OnAttackDecisionChanged(FMars_Delegate_Crawler_OnAttackDecisionChanged(this, n"OnHistoryDecision"));
        Assert_NoAttackOrCooldown();
    }

    UFUNCTION()
    private void OnHistoryDecision(FCk_Handle_Crawler InCrawler, FMars_Attack_Decision InDecision)
    {
        ++_DecisionSignals;
        Assert_True(InCrawler == _Crawler, "callback identifies the owned crawler stream");
        const auto Stored = InCrawler.Get_AttackDecision();
        const auto Evaluation = InCrawler.Get_AttackEvaluation();
        Assert_True(Stored.Signature != "" && Stored.Signature == InDecision.Signature && Stored.LastReason == InDecision.LastReason,
            "public stored signature/reason are fully written before broadcast");
        Assert_True(Same_Selection(Stored.Evaluation.Selection, InDecision.Evaluation.Selection) &&
            Same_Selection(Evaluation.Selection, InDecision.Evaluation.Selection), "public stored preferred/ready/selected/disposition match the callback");
        Assert_True(Stored.Evaluation.TargetGeneration == InDecision.Evaluation.TargetGeneration &&
            Evaluation.TargetGeneration == InCrawler.Get_CombatTargetGeneration() &&
            InDecision.Evaluation.TargetGeneration == InCrawler.Get_CombatTargetGeneration() &&
            Stored.Evaluation.TargetIdentity == InDecision.Evaluation.TargetIdentity &&
            InDecision.Evaluation.TargetIdentity == utils_crawler::Get_AttackTargetIdentity(InCrawler.Get_CombatTarget()),
            "callback and public stored decision observe the fully committed target identity/generation");
        Assert_True(Stored.Evaluation.SelectionGeneration == InDecision.Evaluation.SelectionGeneration &&
            Evaluation.SelectionGeneration == InDecision.Evaluation.SelectionGeneration,
            "callback and both public decision getters observe the committed selection generation");
        Assert_Equals_Int(Stored.Evaluation.Evaluations.Num(), 2, "both authored candidates are already stored at broadcast");
        Assert_Equals_Int(Stored.Evaluation.Evaluations.Num(), InDecision.Evaluation.Evaluations.Num(), "payload candidate array is fully written");
        if (Stored.Evaluation.Evaluations.Num() == InDecision.Evaluation.Evaluations.Num())
        {
            for (int32 Index = 0; Index < Stored.Evaluation.Evaluations.Num(); ++Index)
            {
                const auto Candidate = Stored.Evaluation.Evaluations[Index];
                const auto Payload = InDecision.Evaluation.Evaluations[Index];
                Assert_True(Candidate.AttackId == Payload.AttackId && Candidate.Availability == Payload.Availability &&
                    Candidate.Blockers.Num() == Payload.Blockers.Num(), "stored candidate identity/readiness/blocker count matches the callback");
            }
        }
        const auto History = InCrawler.Get_AttackHistory();
        if (History.Num() == 0)
        { FinishFailure("decision callback preceded public history publication"); return; }
        const auto Latest = History.Last();
        Assert_True(Latest.Event == n"Decision" && Latest.Context.SelectionGeneration == InDecision.Evaluation.SelectionGeneration &&
            Latest.Context.Evaluation.SelectionGeneration == InDecision.Evaluation.SelectionGeneration &&
            Latest.Context.TargetGeneration == InDecision.Evaluation.TargetGeneration &&
            Latest.Context.Evaluation.TargetIdentity == InDecision.Evaluation.TargetIdentity &&
            Same_Selection(Latest.Context.Evaluation.Selection, InDecision.Evaluation.Selection),
            "public latest history contains this fully written callback decision context");
        if (_ObservedPublications.Num() > 0)
        { Assert_True(Latest.Sequence > _ObservedPublications.Last().Sequence, "a changed decision publishes a newer history sequence"); }
        _ObservedPublications.Add(Latest);
    }

    UFUNCTION()
    private void Step_QueueTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Crawler.Get_HasPendingCombatRequests() == false, "previous public target request has drained before the next is queued");
        _ExpectedTarget = _SwitchesCompleted % 2 == 0 ? _FirstTarget.Entity : _SecondTarget.Entity;
        Assert_True(_Crawler.Get_CombatTarget() != _ExpectedTarget, "each request changes to the other owned target");
        _BeforeTargetGeneration = _Crawler.Get_CombatTargetGeneration(); _BeforeSignals = _DecisionSignals;
        _Crawler.Request_SetCombatTarget(FMars_Request_Crawler_SetCombatTarget(_ExpectedTarget));
    }

    UFUNCTION()
    private void Check_TargetObserved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_HasPendingCombatRequests() == false && _Crawler.Get_CombatTarget() == _ExpectedTarget &&
            _Crawler.Get_CombatTargetGeneration() > _BeforeTargetGeneration &&
            _Crawler.Get_AttackDecision().Evaluation.TargetGeneration == _Crawler.Get_CombatTargetGeneration() &&
            _DecisionSignals > _BeforeSignals);
    }

    UFUNCTION()
    private void Step_ConfirmTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Crawler.Get_CombatTargetGeneration(), _BeforeTargetGeneration + 1, "one drained alternating request advances target generation exactly once");
        Assert_True(_DecisionSignals > _BeforeSignals, "the drained target change actually broadcast a decision");
        ++_SwitchesCompleted;
        Assert_NoAttackOrCooldown();
    }

    UFUNCTION()
    private void Step_AssertHistory(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_SwitchesCompleted, 20, "all twenty public target changes drained separately");
        Assert_True(_DecisionSignals >= 20 && _ObservedPublications.Num() >= 20, "at least twenty actual changed decisions/public history rows were observed");
        const auto History = _Crawler.Get_AttackHistory();
        Assert_Equals_Int(History.Num(), 16, "public history retains exactly the latest sixteen entries");
        if (History.Num() != 16 || _ObservedPublications.Num() < 16)
        { FinishFailure("insufficient public history/publication observations for the bounded-tail assertion"); return; }
        for (int32 Index = 0; Index < History.Num(); ++Index)
        {
            const auto Entry = History[Index];
            const auto Observed = _ObservedPublications[_ObservedPublications.Num() - 16 + Index];
            Assert_True(Entry.Sequence == Observed.Sequence && Entry.Sequence != _OldFirstSequence,
                "retained sequence is the exact callback-observed latest tail; original first row is evicted");
            if (Index > 0) { Assert_True(Entry.Sequence > History[Index - 1].Sequence, "retained entries are in strict chronological sequence order"); }
            Assert_True(Entry.Event == n"Decision" && Entry.ActionIdentity.Get_Value() == 0 &&
                Entry.Context.AttemptGeneration == _InitialAttemptGeneration &&
                Entry.Context.SelectionGeneration == Entry.Context.Evaluation.SelectionGeneration &&
                Entry.Context.TargetGeneration == Entry.Context.Evaluation.TargetGeneration &&
                Entry.Context.TargetGeneration == Observed.Context.TargetGeneration &&
                Entry.Context.Evaluation.TargetIdentity == Observed.Context.Evaluation.TargetIdentity &&
                Same_Selection(Entry.Context.Evaluation.Selection, Observed.Context.Evaluation.Selection),
                "every retained row preserves its own coherent target/selection context in this unchanged attempt stream");
            Assert_True(Entry.Context.Evaluation.TargetIdentity == utils_crawler::Get_AttackTargetIdentity(_FirstTarget.Entity) ||
                Entry.Context.Evaluation.TargetIdentity == utils_crawler::Get_AttackTargetIdentity(_SecondTarget.Entity), "history refers only to the two owned targets");
        }
        Assert_NoAttackOrCooldown();
        Assert_True(_Crawler.Get_HasPendingCombatRequests() == false, "quiet window starts without queued public requests");
        _QuietSignals = _DecisionSignals; _QuietDecision = _Crawler.Get_AttackDecision();
        _QuietHistory = History; _QuietFrame = utils_time::Get_FrameCounter();
    }

    UFUNCTION()
    private void Check_QuietFrames(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_time::Get_FrameCounter() - _QuietFrame >= 10);
    }

    UFUNCTION()
    private void Step_AssertQuiet(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_time::Get_FrameCounter() - _QuietFrame >= 10, "the unchanged-state observation covered at least ten actual processor frames");
        Assert_NoAttackOrCooldown();
        Assert_True(_Crawler.Get_HasPendingCombatRequests() == false, "quiet window ends without queued public requests");
        const auto Decision = _Crawler.Get_AttackDecision();
        Assert_True(Decision.Signature == _QuietDecision.Signature && Decision.LastReason == _QuietDecision.LastReason &&
            Decision.Evaluation.TargetGeneration == _QuietDecision.Evaluation.TargetGeneration &&
            Decision.Evaluation.SelectionGeneration == _QuietDecision.Evaluation.SelectionGeneration &&
            Same_Selection(Decision.Evaluation.Selection, _QuietDecision.Evaluation.Selection), "public decision remains unchanged throughout the quiet window");
        Assert_Equals_Int(_DecisionSignals, _QuietSignals, "unchanged decision broadcasts no further signal");
        const auto History = _Crawler.Get_AttackHistory();
        Assert_Equals_Int(History.Num(), _QuietHistory.Num(), "unchanged decision appends no history");
        if (History.Num() == _QuietHistory.Num())
        { for (int32 Index = 0; Index < History.Num(); ++Index) { Assert_True(History[Index].Sequence == _QuietHistory[Index].Sequence, "quiet history keeps every retained sequence"); } }
        Assert_Equals_Float(_FirstTarget.Health.Get_Current(), 100.0f, 0.0001f, "first target took no damage");
        Assert_Equals_Float(_SecondTarget.Health.Get_Current(), 100.0f, 0.0001f, "second target took no damage");
        _Crawler.UnbindFrom_OnAttackDecisionChanged(FMars_Delegate_Crawler_OnAttackDecisionChanged(this, n"OnHistoryDecision"));
    }
}
