UCLASS(Abstract)
class UMars_AutoTestRig_CrawlerAttackCatalog : UMars_AutoTestRig_CrawlerMelee
{
    UPROPERTY()
    protected UMars_AttackLoadout_Data _Catalog;

    UPROPERTY()
    protected UMars_AttackDefinition_Data _CatalogJab;

    UPROPERTY()
    protected UMars_AttackDefinition_Data _CatalogPincer;

    UPROPERTY()
    protected UMars_AttackDefinition_Data _CatalogCustom;

    UPROPERTY()
    protected UCk_ProceduralAction_Data _CatalogJabSource;

    UPROPERTY()
    protected UCk_ProceduralAction_Data _CatalogPincerSource;

    protected FMars_Crawler_Spec _CatalogSpec;
    protected int32 _CatalogLegCount = 6;
    protected EMars_Crawler_Layout _CatalogLayout = EMars_Crawler_Layout::Spider;
    protected TArray<FMars_Attack_Admission> _CatalogAdmissions;
    protected TArray<FMars_Attack_Result> _CatalogResults;
    protected int32 _CatalogDecisionChanges = 0;
    private int32 _CatalogAdmissionPolls = 0;

    // Copy legacy geometry and native execution policy before removing its clip references. The fixture's no-visuals
    // crawler uses the same 40/55 cm box half-length as the production entity script's no-look construction.
    protected FMars_Crawler_Spec Make_CatalogSpec(bool InIncludeCustom)
    {
        auto Spec = Make_ArmedCrawlerSpec(_CatalogLegCount);
        Spec.Layout = _CatalogLayout;
        Wear_ReferenceClips(Spec, EMars_Crawler_AttackClipKind::Pincer);
        const auto HalfLength = _CatalogLegCount == 6 ? 55.0f : 40.0f;
        Spec.Combat.Hit.LocalCenter = FVector(HalfLength, 0.0, 0.0);
        Spec.Combat.Prepare.StartDistance = HalfLength + 70.0f;
        _CatalogJabSource = Spec.Combat.JabClip.Get();
        _CatalogPincerSource = Spec.Combat.PincerClip.Get();
        _Catalog = Cast<UMars_AttackLoadout_Data>(NewObject(this, UMars_AttackLoadout_Data));
        _Catalog.Spec.Execution.Tuning = utils_crawler::Make_AttackTuning(Spec);
        _Catalog.Spec.Execution.Locomotion = utils_crawler::Make_PincerLocomotion(Spec);
        _Catalog.Spec.Execution.MaxRootDrift = Spec.Combat.Hit.MaxRootDrift;
        _Catalog.Spec.Execution.MaxGroundSlopeDegrees = Spec.Combat.Prepare.MaxGroundSlopeDegrees;
        _Catalog.Spec.Selection.TemporaryReadiness = EMars_Attack_TemporaryReadinessPolicy::WaitPreferred;
        _Catalog.Spec.Selection.ControlWait = EMars_Attack_ControlWaitPolicy::PreferAvailable;
        _CatalogJab = Make_CatalogDefinition(Spec, _CatalogJabSource);
        _CatalogPincer = Make_CatalogDefinition(Spec, _CatalogPincerSource);
        auto Right = FMars_Attack_SlotRole();
        Right.Slot = utils_crawler::Get_RightClawSlotId();
        Right.Role = GameplayTags::AttackRole_Mars_FrontRight;
        _CatalogPincer.Def.Requirements.Slots.Add(Right);
        auto Left = FMars_Attack_SlotRole();
        Left.Slot = utils_crawler::Get_LeftClawSlotId();
        Left.Role = GameplayTags::AttackRole_Mars_FrontLeft;
        _CatalogPincer.Def.Requirements.Slots.Add(Left);
        _Catalog.Spec.Entries.Add(Make_CatalogEntry(GameplayTags::Attack_Mars_Pincer, _CatalogPincer, 100));
        _Catalog.Spec.Entries.Add(Make_CatalogEntry(GameplayTags::Attack_Mars_Jab, _CatalogJab, 0));
        if (InIncludeCustom)
        {
            _CatalogCustom = Make_CatalogDefinition(Spec, _CatalogJabSource);
            auto Required = FMars_Attack_PartRequirement();
            Required.Role = GameplayTags::AttackRole_Mars_FrontLeft;
            _CatalogCustom.Def.Requirements.Parts.Add(Required);
            _Catalog.Spec.Entries.Add(Make_CatalogEntry(GameplayTags::Attack_Mars_Test_Fourth, _CatalogCustom, 200));
        }
        auto Body = FMars_Attack_AnatomyBinding();
        Body.Role = GameplayTags::AttackRole_Mars_Body;
        Spec.Combat.Anatomy.Add(Body);
        for (int32 Index = 0; Index < _CatalogLegCount; ++Index)
        {
            auto Binding = FMars_Attack_AnatomyBinding();
            Binding.Source = EMars_Attack_AnatomySource::ProceduralLimb;
            // All crawler procedural limbs walk. Authored false must be normalized by the game adapter.
            Binding.Locomotor = false;
            Binding.LimbId = FName(f"Leg{Index}");
            Binding.Role = Index == 0 ? GameplayTags::AttackRole_Mars_FrontRight : Index == _CatalogLegCount - 1 ? GameplayTags::AttackRole_Mars_FrontLeft :
                GameplayTags::ResolveGameplayTag(FName(f"AttackRole.Mars.Test.Support{Index}"));
            Spec.Combat.Anatomy.Add(Binding);
        }
        Spec.Combat.Loadout = TSoftObjectPtr<UMars_AttackLoadout_Data>(_Catalog);
        Spec.Combat.JabClip = TSoftObjectPtr<UCk_ProceduralAction_Data>();
        Spec.Combat.PincerClip = TSoftObjectPtr<UCk_ProceduralAction_Data>();
        _CatalogSpec = Spec;
        return Spec;
    }

    protected UMars_AttackDefinition_Data Make_CatalogDefinition(const FMars_Crawler_Spec& InSpec, UCk_ProceduralAction_Data InClip)
    {
        auto Asset = Cast<UMars_AttackDefinition_Data>(NewObject(this, UMars_AttackDefinition_Data));
        Asset.Def.Clip = TSoftObjectPtr<UCk_ProceduralAction_Data>(InClip);
        Asset.Def.Prepare.MinDistance = 0.0f;
        Asset.Def.Prepare.MaxDistance = InSpec.Combat.Prepare.StartDistance;
        Asset.Def.Prepare.FacingToleranceDegrees = InSpec.Combat.Prepare.FacingToleranceDegrees;
        Asset.Def.Prepare.MaxHeightDifference = InSpec.Combat.Prepare.MaxHeightDifference;
        Asset.Def.Prepare.MaxSpeedToStart = InSpec.Combat.Prepare.MaxSpeedToStart;
        Asset.Def.Prepare.TimeoutSeconds = InSpec.Combat.Prepare.TimeoutSeconds;
        Asset.Def.Hit.Damage = InSpec.Combat.Hit.Damage;
        Asset.Def.Hit.DamageType = InSpec.Combat.Hit.DamageType;
        Asset.Def.Cooldown.RecoverySeconds = InSpec.Combat.Timing.CooldownSeconds;
        auto Emitter = FMars_Attack_Emitter();
        Emitter.Id = GameplayTags::AttackEmitter_Mars_Body;
        Emitter.LocalCenter = InSpec.Combat.Hit.LocalCenter;
        Emitter.Radius = InSpec.Combat.Hit.Radius;
        Emitter.MaxSampleTravel = InSpec.Combat.Hit.MaxSampleTravel;
        Asset.Def.Hit.Emitters.Add(Emitter);
        auto Body = FMars_Attack_PartRequirement();
        Body.Role = GameplayTags::AttackRole_Mars_Body;
        Asset.Def.Requirements.Parts.Add(Body);
        return Asset;
    }

    protected FMars_Attack_Entry Make_CatalogEntry(FGameplayTag InId, UMars_AttackDefinition_Data InDefinition, int32 InPriority)
    {
        auto Entry = FMars_Attack_Entry();
        Entry.Id = InId;
        Entry.Definition = TSoftObjectPtr<UMars_AttackDefinition_Data>(InDefinition);
        Entry.Priority = InPriority;
        return Entry;
    }

    protected void Add_CatalogSettleSteps()
    {
        Add_SettleSteps();
        Add_Step("bind the catalogue decision/admission/result signals", n"Step_BindCatalogSignals");
        Add_Step("export the actual catalogue scheduler", n"Step_ExportCatalogScheduler");
        Add_Step_WaitUntil("the two front roles can be prepared for pincer", n"Check_CatalogStance", k_SlowPolls, 0);
    }

    UFUNCTION()
    protected void Step_ExportCatalogScheduler(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        System::ExecuteConsoleCommand("Ck.Ecs.Scheduler.ExportOrder Saved/CkEcs/AttackCatalog-P2-SchedulerOrder.txt");
        System::ExecuteConsoleCommand("Ck.Ecs.Scheduler.ExportGraph Saved/CkEcs/AttackCatalog-P2-SchedulerGraph.dot");
    }

    protected void Spawn_CatalogCrawlerOnly(FCk_Handle InHandle, const FMars_Crawler_Spec& InSpec)
    {
        auto SpawnParams = UMars_Crawler_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, _Origin + FVector(0.0, 0.0, 65.0));
        SpawnParams.Spec = InSpec;
        SpawnParams.WithVisuals = false;
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Crawler_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnCrawlerConstructed"));
    }

    UFUNCTION()
    protected void Step_BindCatalogSignals(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        // Sever/death deliberately moves debris into the world; this fixture still owns its cleanup.
        for (const auto& Part : _Crawler.Get_LegParts())
        {
            FCk_Handle Entity = Part;
            Track_ForCleanup(Entity);
        }
        _Crawler.BindTo_OnAttackAdmitted(FMars_Delegate_Crawler_OnAttackAdmitted(this, n"OnCatalogAdmitted"));
        _Crawler.BindTo_OnAttackCompleted(FMars_Delegate_Crawler_OnAttackCompleted(this, n"OnCatalogCompleted"));
        _Crawler.BindTo_OnAttackDecisionChanged(FMars_Delegate_Crawler_OnAttackDecisionChanged(this, n"OnCatalogDecision"));
    }

    UFUNCTION()
    protected void OnCatalogAdmitted(FCk_Handle_Crawler InCrawler, FMars_Attack_Admission InAdmission)
    { _CatalogAdmissions.Add(InAdmission); }

    UFUNCTION()
    protected void OnCatalogCompleted(FCk_Handle_Crawler InCrawler, FMars_Attack_Result InResult)
    { _CatalogResults.Add(InResult); }

    UFUNCTION()
    protected void OnCatalogDecision(FCk_Handle_Crawler InCrawler, FMars_Attack_Decision InDecision)
    { ++_CatalogDecisionChanges; }

    UFUNCTION()
    protected void Check_CatalogAccepted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Phase = _Crawler.Get_AttackPhase();
        const auto Accepted = _Crawler.Get_HasPendingCombatRequests() == false && _Crawler.Get_AttackAdmission().Accepted &&
            (Phase == EMars_Crawler_AttackPhase::Windup || Phase == EMars_Crawler_AttackPhase::Strike || Phase == EMars_Crawler_AttackPhase::Recover);
        if (Accepted)
        { _CatalogAdmissionPolls = 0; }
        else
        {
            ++_CatalogAdmissionPolls;
            if (_CatalogAdmissionPolls == 60 && _Crawler.Get_HasPendingCombatRequests() == false)
            {
                const auto Admission = _Crawler.Get_AttackAdmission();
                const auto Result = _Crawler.Get_AttackResult();
                auto Details = f"phase {Phase :n}, reject {Get_LastRejectText()}, cancel {Get_LastCancelText()}, generation {_Crawler.Get_AttackGeneration()}, action {Admission.ActionIdentity.Get_Value()}, accepted {Admission.Accepted}, native {Result.Native.Get_Outcome() :n}/{Result.Native.Get_Reason()}, evidence {Result.Evidence.Observed}/{Result.Evidence.Source}/{Result.Evidence.Failure}, cleanup {Result.CleanupOutcome}; {Get_CrawlerDiagnostics()}";
                for (const auto& Evaluation : _Crawler.Get_AttackEvaluation().Evaluations)
                {
                    Details = f"{Details}; {Evaluation.AttackId} {Evaluation.Availability :n}";
                    for (const auto& Blocker : Evaluation.Blockers)
                    { Details = f"{Details} [{Blocker.Code} {Blocker.Field}: {Blocker.Expected} / {Blocker.Actual}]"; }
                }
                Log(f"[CatalogAdmissionDiagnostic] {Details}");
                for (const auto& Event : _Crawler.Get_AttackHistory())
                {
                    if (Event.Event != n"Rejected")
                    { continue; }
                    auto Rejected = f"[CatalogRejectedSnapshot] {Event.Reason}, generation {Event.Context.AttemptGeneration}";
                    for (const auto& Evaluation : Event.Context.Evaluation.Evaluations)
                    {
                        Rejected = f"{Rejected}; {Evaluation.AttackId} {Evaluation.Availability :n}";
                        for (const auto& Blocker : Evaluation.Blockers)
                        { Rejected = f"{Rejected} [{Blocker.Code} {Blocker.Field}: {Blocker.Expected} / {Blocker.Actual}]"; }
                    }
                    Log(Rejected);
                }
            }
        }
        auto Res = OutResult;
        Res.Set(Accepted);
    }

    protected int64 Get_CatalogLastStart(FGameplayTag InId) const
    {
        for (const auto& Reuse : _Crawler.Get_AttackReuse())
        {
            if (Reuse.Id == InId)
            { return Reuse.LastStartSequence; }
        }
        return 0;
    }

    protected float32 Get_CatalogReuseRemaining(FGameplayTag InId) const
    {
        for (const auto& Reuse : _Crawler.Get_AttackReuse())
        {
            if (Reuse.Id == InId)
            { return Reuse.Remaining; }
        }
        return 0.0f;
    }

    UFUNCTION()
    protected void Check_CatalogStance(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Parts = _Crawler.Get_LegParts();
        auto Ready = Parts.Num() == _CatalogLegCount;
        if (Ready)
        {
            auto Claws = TArray<FMars_Crawler_AttackClaw>();
            auto Right = FMars_Crawler_AttackClaw();
            Right.Leg = Parts[0].Get_Leg();
            Right.LegId = utils_procedural_leg::Get_Id(Right.Leg);
            Claws.Add(Right);
            auto Left = FMars_Crawler_AttackClaw();
            Left.Leg = Parts.Last().Get_Leg();
            Left.LegId = utils_procedural_leg::Get_Id(Left.Leg);
            Claws.Add(Left);
            Ready = utils_crawler::Get_IsPincerStanceReady(_Crawler, Claws);
            // The catalogue requires trusted contact on the claimed feet as well as standing support.
            for (const auto& Claw : Claws)
            { Ready = Ready && Claw.Leg.Get_Foot().Get_Contact() == ECk_ProceduralLeg_FootContact::Trusted; }
        }
        auto Res = OutResult;
        Res.Set(Ready);
    }

    UFUNCTION()
    protected void Check_CatalogPincerReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Advice = utils_crawler::Evaluate_AttackLoadout(_Crawler, _Target.Entity);
        auto Res = OutResult;
        Res.Set(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::Idle && Advice.Selection.Selected.IsSet() &&
            Advice.Selection.Selected.GetValue() == GameplayTags::Attack_Mars_Pincer);
    }

    UFUNCTION()
    protected void Step_CatalogTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, 30.0, FVector(10.0, 20.0, 20.0));
    }

    UFUNCTION()
    protected void Step_CatalogSelectTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Crawler.Request_SetCombatTarget(FMars_Request_Crawler_SetCombatTarget(_Target.Entity));
    }

    UFUNCTION()
    protected void Check_CatalogRequestsDrained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_HasPendingCombatRequests() == false);
    }

    protected bool Get_AreCatalogClawsReturned() const
    {
        const auto Subject = _Crawler.Get_Articulation();
        const auto Parts = _Crawler.Get_LegParts();
        if (Subject.Get_Health() != ECk_ProceduralArticulation_Health::Operational)
        { return false; }
        const auto Right = Parts[0].Get_Leg();
        const auto Left = Parts.Last().Get_Leg();
        return Subject.Get_LimbControl(utils_procedural_leg::Get_Id(Right)).Get_State() == ECk_ProceduralLimbControl_State::Default &&
            Subject.Get_LimbControl(utils_procedural_leg::Get_Id(Left)).Get_State() == ECk_ProceduralLimbControl_State::Default;
    }

    UFUNCTION()
    protected void Check_CatalogClawsReturned(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_AreCatalogClawsReturned());
    }
}
