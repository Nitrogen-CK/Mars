// D04: the consumer only records copied evidence. Public fixture steps own every gameplay request.
class UMars_AutoTest_CrawlerMelee_CatalogCues : UMars_AutoTestRig_CrawlerAttackCatalog
{
    default _TimeoutSeconds = 90.0f;
    default _Origin = FVector(-900000.0, -180000.0, 600.0);
    protected bool _BodyOnly = false;
    protected bool _CustomId = false;
    protected bool _Cancel = false;
    protected bool _DestroyAction = false;
    protected FGameplayTag _ConfiguredProfile = GameplayTags::AttackCue_Mars_Pincer;
    private FGameplayTag _ExpectedId = GameplayTags::Attack_Mars_Pincer;
    UPROPERTY() private UMars_AttackDefinition_Data _CueDefinition;
    UPROPERTY() private UMars_Processor_Crawler_HandleRequests _Requests;
    UPROPERTY() private UMars_Processor_Crawler_AttackTick _Tick;
    private TArray<FMars_Attack_CueBatch> _CueBatches;
    private bool _CallbacksFullyWritten = true;
    private bool _ObservationsValid = true;
    private int64 _LastCueSample = 0;
    private int64 _LastCueRevision = 0;
    private int64 _Identity = 0;
    private int32 _Attempt = 0;
    private int32 _IssuedAtInterruption = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_CatalogSpec(_CustomId);
        _ExpectedId = _CustomId ? GameplayTags::Attack_Mars_Test_Fourth : _BodyOnly ? GameplayTags::Attack_Mars_Jab : GameplayTags::Attack_Mars_Pincer;
        _CueDefinition = _CustomId ? _CatalogCustom : _BodyOnly ? _CatalogJab : _CatalogPincer;
        _CueDefinition.Def.CueProfile = _ConfiguredProfile;
        for (auto& Entry : _Catalog.Spec.Entries)
        { Entry.Enabled = Entry.Id == _ExpectedId; }
        _Requests = Cast<UMars_Processor_Crawler_HandleRequests>(NewObject(this, UMars_Processor_Crawler_HandleRequests));
        _Tick = Cast<UMars_Processor_Crawler_AttackTick>(NewObject(this, UMars_Processor_Crawler_AttackTick));
        SpawnFloorAndCrawler(InHandle, Spec);
        Add_CatalogSettleSteps();
        Add_Step("bind public committed cue batches", n"Step_BindCues");
        Add_Step("spawn the reachable body-sphere target", n"Step_CatalogTarget");
        Add_Step_WaitUntil("target is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("select the target", n"Step_CatalogSelectTarget");
        Add_Step_WaitUntil("target transport drains", n"Check_CatalogRequestsDrained", k_SlowPolls, 0);
        Add_Step_WaitUntil("full fresh advice permits the authored identity", n"Check_CueReady", k_SlowPolls, 0);
        Add_Step("create one real Pending action and prove pending admission is silent", n"Step_StartPending");
        Add_Step_WaitUntil("a real offensive native receipt accepts", n"Check_CatalogAccepted", k_SlowPolls, 0);
        Add_Step("edit only the pinned transient source profile after admission", n"Step_EditSourceProfile");
        if (_Cancel || _DestroyAction)
        { Add_Step("interrupt only through a public cancellation or owned action destruction", n"Step_Interrupt"); }
        Add_Step_WaitUntil("native terminal and game cleanup complete", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitUntil("surviving limbs return to the gait", n"Check_CatalogClawsReturned", k_SlowPolls, 0);
        Add_Step_WaitFrames("extra ticks cannot repeat interruption or completion", 3);
        Add_Step("D04 copied native evidence and exact lifecycle transitions", n"Step_AssertCues");
        Add_Step("explicit public unbind ends the consumer lifetime", n"Step_UnbindCues");
        Run_Steps(InHandle);
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    { Unbind_Cues(); }

    void FinishFailure(const FString& InMessage) override
    { Unbind_Cues(); Super::FinishFailure(InMessage); }

    void FinishSuccess() override
    { Unbind_Cues(); Super::FinishSuccess(); }

    private void Unbind_Cues()
    {
        if (ck::IsValid(_Crawler))
        { _Crawler.UnbindFrom_OnAttackCue(FMars_Delegate_Crawler_OnAttackCue(this, n"OnCue")); }
    }

    UFUNCTION()
    private void Step_BindCues(FCk_Handle InHandle, FInstancedStruct InPayload)
    { _Crawler.BindTo_OnAttackCue(FMars_Delegate_Crawler_OnAttackCue(this, n"OnCue")); }

    UFUNCTION()
    private void Step_UnbindCues(FCk_Handle InHandle, FInstancedStruct InPayload)
    { Unbind_Cues(); }

    UFUNCTION()
    private void Check_CueReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Advice = utils_crawler::Evaluate_AttackLoadout(_Crawler, _Target.Entity);
        auto Res = OutResult;
        Res.Set(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::Idle && Advice.Selection.Selected.IsSet() &&
            Advice.Selection.Selected.GetValue() == _ExpectedId);
    }

    UFUNCTION()
    private void Step_StartPending(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_CueBatches.Num(), 0, "preparation and target selection emit no attack cue");
        _RecordMark = _Records.Num();
        _Crawler.Request_StartAttack(FMars_Request_Crawler_StartAttack(_Target.Entity));
        FMars_Fragment_Crawler_Requests Requests = _Crawler.Get_Fragment(FMars_Fragment_Crawler_Requests);
        FCk_Handle Entity = _Crawler;
        _Requests.ForEachEntity(FCk_Time(0.0), Entity, Requests);
        _Tick.ForEachEntity(FCk_Time(0.000001), Entity);
        const auto Admission = _Crawler.Get_AttackAdmission();
        const auto Action = _Crawler.Get_AttackAction();
        Assert_True(Admission.Accepted == false && Admission.ActionIdentity.Get_Value() > 0 &&
            ck::IsValid(Action) && Action.Get_State() == ECk_ProceduralAction_State::PendingAdmission &&
            Action.Get_LastReceipt().Get_HasAcceptedPose() == false,
            "the real owning kernel created Pending admission without a native accepted pose");
        Assert_Equals_Int(_CueBatches.Num(), 0, "Pending state and requested motion emit no cue batch");
        _Identity = Admission.ActionIdentity.Get_Value();
        _Attempt = Admission.AttemptGeneration;
    }

    UFUNCTION()
    private void Step_EditSourceProfile(FCk_Handle InHandle, FInstancedStruct InPayload)
    { _CueDefinition.Def.CueProfile = GameplayTags::AttackCue_Mars_Test_EditedSource; }

    UFUNCTION()
    private void Step_Interrupt(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _IssuedAtInterruption = utils_mars_test_catalog::Get_IssuedDamageRequests(_Crawler);
        if (_DestroyAction)
        {
            FCk_Handle Action = _Crawler.Get_AttackAction();
            Assert_True(ck::IsValid(Action) && _Crawler.Get_AttackAdmission().Accepted,
                "action-loss interruption destroys the actual accepted owned action only");
            utils_entity_lifetime::Request_DestroyEntity(Action);
            return;
        }
        _Crawler.Request_CancelAttack(FMars_Request_Crawler_CancelAttack(EMars_Crawler_AttackCancel::StateExit));
    }

    UFUNCTION()
    private void OnCue(FCk_Handle_Crawler InCrawler, FMars_Attack_CueBatch InBatch)
    {
        const auto Admission = InCrawler.Get_AttackAdmission();
        const auto Result = InCrawler.Get_AttackResult();
        _CallbacksFullyWritten = _CallbacksFullyWritten && InCrawler == _Crawler && Admission.Accepted &&
            InBatch.ActionIdentity.Get_Value() == Admission.ActionIdentity.Get_Value() &&
            InBatch.AttackId == Admission.AttackId && InBatch.AdmissionAttemptGeneration == Admission.AttemptGeneration &&
            InBatch.Profile == _ConfiguredProfile;
        if (InBatch.Admitted)
        { _CallbacksFullyWritten = _CallbacksFullyWritten && Admission.SampleId > 0; }
        if (InBatch.Interrupted)
        {
            const auto Phase = InCrawler.Get_AttackPhase();
            _CallbacksFullyWritten = _CallbacksFullyWritten && InCrawler.Get_AttackLastCancel().IsSet() &&
                (Phase == EMars_Crawler_AttackPhase::CancelRecover || Phase == EMars_Crawler_AttackPhase::Cooldown ||
                    Phase == EMars_Crawler_AttackPhase::Idle);
        }
        if (InBatch.Completed)
        {
            _CallbacksFullyWritten = _CallbacksFullyWritten && Result.Accepted && Result.Completed &&
                InCrawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::Idle &&
                InBatch.Result.Completed && InBatch.Result.Accepted &&
                InBatch.Result.ActionIdentity.Get_Value() == Result.ActionIdentity.Get_Value() &&
                InBatch.Result.Native.Get_Outcome() == Result.Native.Get_Outcome() &&
                InBatch.Result.Native.Get_Reason() == Result.Native.Get_Reason() &&
                InBatch.Result.Native.Get_Recovery() == Result.Native.Get_Recovery() &&
                InBatch.Result.CleanupOutcome == Result.CleanupOutcome;
        }
        _ObservationsValid = _ObservationsValid && InBatch.Observations.Num() <= 64;
        for (const auto& Observation : InBatch.Observations)
        {
            _ObservationsValid = _ObservationsValid && Observation.Stamp.Get_Identity().Get_Value() == Admission.ActionIdentity.Get_Value() &&
                Observation.Stamp.Get_SampleSequence() > _LastCueSample && Observation.Stamp.Get_SubjectPoseRevision() > _LastCueRevision &&
                Observation.ObservationFrame > 0 && Observation.ObservationFrame <= utils_time::Get_FrameCounter();
            _LastCueSample = Observation.Stamp.Get_SampleSequence();
            _LastCueRevision = Observation.Stamp.Get_SubjectPoseRevision();
        }
        _CueBatches.Add(InBatch);
    }

    UFUNCTION()
    private void Step_AssertCues(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_CatalogAdmissions.Num(), 1, "one native accepted admission occurred");
        Assert_Equals_Int(_CatalogResults.Num(), 1, "one fully settled game result occurred");
        Assert_True(_Crawler.Get_AttackAdmission().AttackId == _ExpectedId && _Crawler.Get_AttackResult().Completed,
            "the configured data-only entry completed through the real attack kernel");
        if (_ConfiguredProfile.IsValid() == false)
        {
            Assert_Equals_Int(_CueBatches.Num(), 0, "empty construction-time profile stays silent despite editing its source during play");
            return;
        }
        auto Admitted = 0;
        auto Interrupted = 0;
        auto Completed = 0;
        auto Windup = false;
        auto Strike = false;
        auto Recover = false;
        auto WindowEnter = false;
        auto WindowExit = false;
        for (const auto& Batch : _CueBatches)
        {
            Admitted += Batch.Admitted ? 1 : 0;
            Interrupted += Batch.Interrupted ? 1 : 0;
            Completed += Batch.Completed ? 1 : 0;
            Assert_True(Batch.ActionIdentity.Get_Value() == _Identity && Batch.AttackId == _ExpectedId &&
                Batch.AdmissionAttemptGeneration == _Attempt && Batch.Profile == _ConfiguredProfile,
                "every batch retains frozen source profile and committed admission identity");
            for (const auto& Observation : Batch.Observations)
            {
                Windup = Windup || Observation.Interval.Get_PhaseId() == Batch.Motion.WindupPhase;
                Strike = Strike || Observation.Interval.Get_PhaseId() == Batch.Motion.StrikePhase;
                Recover = Recover || Observation.Interval.Get_PhaseId() == Batch.Motion.RecoverPhase;
                for (const auto& Event : Observation.Interval.Get_Events())
                {
                    if (Event.Get_Id() != Batch.Motion.ObstructionWindow) { continue; }
                    WindowEnter = WindowEnter || Event.Get_Kind() == ECk_ProceduralAction_EventKind::WindowEnter;
                    WindowExit = WindowExit || Event.Get_Kind() == ECk_ProceduralAction_EventKind::WindowExit;
                }
            }
        }
        Assert_True(_CallbacksFullyWritten, "cue callbacks observe fully written public admission/cancel/result state");
        Assert_True(_ObservationsValid && _LastCueSample > 0, "only chronological unique accepted stamps and observation frames reached cues");
        Assert_Equals_Int(Admitted, 1, "cue admission transition fires exactly once");
        Assert_Equals_Int(Interrupted, _Cancel || _DestroyAction ? 1 : 0, "actual accepted interruption fires exactly once including action loss");
        Assert_Equals_Int(Completed, 1, "the exact fully written accepted result fires once after cleanup");
        if (_Cancel || _DestroyAction)
        {
            Assert_Equals_Int(utils_mars_test_catalog::Get_IssuedDamageRequests(_Crawler), _IssuedAtInterruption,
                "the cue consumer neither emits gameplay requests nor reopens offense after interruption");
            Assert_True(_Crawler.Get_AttackLastCancel().IsSet() && _Crawler.Get_AttackLastCancel().GetValue() ==
                (_DestroyAction ? EMars_Crawler_AttackCancel::PoseFailed : EMars_Crawler_AttackCancel::StateExit),
                "the cue interruption retains the real kernel cancellation reason");
        }
        else
        {
            Assert_True(Windup && Strike && Recover && WindowEnter && WindowExit,
                "accepted native phase intervals and the terminal Offense window exit all reached the consumer");
            Assert_True(_Crawler.Get_AttackResult().Native.Get_Outcome() == ECk_ProceduralAction_Outcome::Completed,
                "normal cue completion retains the actual native outcome");
        }
    }
}

class UMars_AutoTest_CrawlerMelee_CatalogCuesPincerCancel : UMars_AutoTest_CrawlerMelee_CatalogCues
{
    default _Origin = FVector(-910000.0, -180000.0, 600.0);
    default _Cancel = true;
}
class UMars_AutoTest_CrawlerMelee_CatalogCuesJabProfile : UMars_AutoTest_CrawlerMelee_CatalogCues
{
    default _Origin = FVector(-920000.0, -180000.0, 600.0);
    default _BodyOnly = true;
    default _ConfiguredProfile = GameplayTags::AttackCue_Mars_Jab;
}
class UMars_AutoTest_CrawlerMelee_CatalogCuesJabEmpty : UMars_AutoTest_CrawlerMelee_CatalogCuesJabProfile
{
    default _Origin = FVector(-930000.0, -180000.0, 600.0);
    default _ConfiguredProfile = FGameplayTag();
}
class UMars_AutoTest_CrawlerMelee_CatalogCuesCustomProfile : UMars_AutoTest_CrawlerMelee_CatalogCues
{
    default _Origin = FVector(-940000.0, -180000.0, 600.0);
    default _CustomId = true;
    default _ConfiguredProfile = GameplayTags::AttackCue_Mars_Test_CustomPulse;
}
class UMars_AutoTest_CrawlerMelee_CatalogCuesCustomEmpty : UMars_AutoTest_CrawlerMelee_CatalogCuesCustomProfile
{
    default _Origin = FVector(-950000.0, -180000.0, 600.0);
    default _ConfiguredProfile = FGameplayTag();
}
class UMars_AutoTest_CrawlerMelee_CatalogCuesActionLoss : UMars_AutoTest_CrawlerMelee_CatalogCuesJabProfile
{
    default _Origin = FVector(-960000.0, -180000.0, 600.0);
    default _DestroyAction = true;
}
