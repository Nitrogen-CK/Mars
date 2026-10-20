class UMars_AutoTest_CrawlerMelee_CatalogParity : UMars_AutoTestRig_CrawlerAttackCatalog
{
    default _TimeoutSeconds = 90.0f;
    default _Origin = FVector(-400000.0, -180000.0, 600.0);

    private int32 _ClaimedAtAccept = 0;
    private FGameplayTag _AcceptedId;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_CatalogSpec(false));
        Add_CatalogSettleSteps();
        Add_Step("spawn a target in the existing body sphere strike", n"Step_CatalogTarget");
        Add_Step_WaitUntil("the target is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("select the target", n"Step_CatalogSelectTarget");
        Add_Step_WaitUntil("target transport drains", n"Check_CatalogRequestsDrained", k_SlowPolls, 0);
        Add_Step_WaitUntil("fresh catalogue advice permits the requested pincer", n"Check_CatalogPincerReady", k_SlowPolls, 0);
        Add_Step("start an authored catalogue pincer", n"Step_TargetAndStart");
        Add_Step_WaitUntil("the first real receipt admits the attack", n"Check_CatalogAccepted", k_SlowPolls, 0);
        Add_Step("inspect committed identity and current-action claims", n"Step_InspectAccepted");
        Add_Step_WaitUntil("the attack returns to Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step_WaitUntil("the claws return to Default", n"Check_CatalogClawsReturned", k_SlowPolls, 0);
        Add_Step_WaitUntil("the target received the hit", n"Check_Hit", k_SlowPolls, 0);
        Add_Step("catalogue body sphere keeps old phases, damage and return", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_InspectAccepted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Plan = _Crawler.Get_AttackPlan();
        for (const auto& Binding : _CatalogSpec.Combat.Anatomy)
        {
            if (Binding.Source == EMars_Attack_AnatomySource::ProceduralLimb)
            { Assert_True(Binding.Locomotor == false, "the source anatomy fixture actually authored false locomotor flags"); }
        }
        for (const auto& Binding : _Crawler.Get_Spec().ResolvedAttacks.Anatomy)
        {
            if (Binding.Source == EMars_Attack_AnatomySource::ProceduralLimb)
            { Assert_True(Binding.Locomotor, "crawler adapter normalizes every procedural limb to locomotor despite authored false"); }
        }
        auto Unsafe = _Crawler.Get_Spec().ResolvedAttacks;
        auto Locomotion = Unsafe.Execution.Locomotion;
        Locomotion.Set_Support(FCk_ProceduralLimbControl_Support(ECk_ProceduralLimbControl_SupportMode::Disabled, 2));
        Unsafe.Execution.Locomotion = Locomotion;
        const auto UnsafeReport = utils_attack::Validate_ResolvedLoadout(Unsafe);
        auto RejectedSupport = false;
        for (const auto& Diagnostic : UnsafeReport.Diagnostics)
        { RejectedSupport = RejectedSupport || Diagnostic.Code == n"LocomotorSupportDisabled"; }
        Assert_True(UnsafeReport.Get_IsValid() == false && RejectedSupport,
            "normalized locomotor claims reject disabled common support through structured validation, without constructing an invalid crawler");
        _AcceptedId = Plan.Entry.Identity.Id;
        _ClaimedAtAccept = Plan.Entry.Slots.Num();
        FCk_Handle ActionEntity = _Crawler.Get_AttackAction();
        for (const auto& Slot : Plan.Entry.Slots)
        {
            const auto Control = _Crawler.Get_Articulation().Get_LimbControl(Slot.Binding.LimbId);
            Assert_True(Control.Get_State() == ECk_ProceduralLimbControl_State::Controlled && Control.Get_Owner() == ActionEntity,
                "a committed action's own controls remain valid continuation");
        }
        Assert_True(_Crawler.Get_AttackFrozenPlayedClip() != _CatalogPincerSource,
            "the played clip is a construction-time copy while source identity stays separate");
        Assert_True(_Crawler.Get_AttackAdmission().Accepted && _Crawler.Get_AttackAdmission().SampleId > 0,
            "game admission exposes real first accepted receipt evidence");
    }

    UFUNCTION()
    private void Check_Hit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Target.Health.Get_Current() < 100.0f);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_AcceptedId == GameplayTags::Attack_Mars_Pincer && _ClaimedAtAccept == 2, "authored pincer selected its two stable front role bindings");
        Assert_Equals_Int(_Records.Num() - _RecordMark, 5, "catalogue attack retains five legacy phase changes");
        Assert_Equals_Int(_CatalogAdmissions.Num(), 1, "accepted admission signal fires exactly once");
        Assert_Equals_Int(_CatalogResults.Num(), 1, "completion signal fires exactly once after cleanup");
        Assert_True(_CatalogResults.Num() == 1 && _CatalogResults[0].AttackId == GameplayTags::Attack_Mars_Pincer && _CatalogResults[0].Accepted &&
            _CatalogResults[0].Native.Get_Outcome() == ECk_ProceduralAction_Outcome::Completed &&
            _CatalogResults[0].Native.Get_Recovery() == ECk_ProceduralAction_Recovery::Succeeded,
            "completed catalogue result preserves identity and exact native recovery");
        Assert_True(Get_CatalogLastStart(GameplayTags::Attack_Mars_Pincer) > 0, "accepted admission charges the least-recent history once");
        Assert_Equals_Int(Get_DamageRequestCount(), 1, "body sphere emits one damage request");
        Assert_Equals_Float(_Target.Health.Get_Current(), 85.0f, 0.01f, "authored catalogue retains the existing 15 HP strike");
        const auto History = _Crawler.Get_AttackHistory();
        Assert_True(History.Num() > 0 && History.Num() <= 16, "catalogue decisions and terminal events have bounded visible history");
        for (int32 Index = 1; Index < History.Num(); ++Index)
        { Assert_True(History[Index].Sequence > History[Index - 1].Sequence, "history event sequence remains chronological"); }
        auto HasTerminalContext = false;
        for (const auto& Event : History)
        {
            if (Event.Event != n"Completed")
            { continue; }
            HasTerminalContext = Event.Context.AttemptGeneration > 0 && Event.Context.SelectionGeneration > 0 &&
                Event.Context.TargetGeneration > 0 && Event.Context.Evaluation.TargetIdentity > 0 &&
                Event.Context.Evaluation.Evaluations.Num() == 2;
        }
        Assert_True(HasTerminalContext, "terminal history retains copied selection, target and attempt generation context");
        Assert_True(_CatalogResults.Num() == 1 && _CatalogResults[0].Evidence.Observed,
            "a native terminal result is explicitly distinguished from missing evidence");
    }
}
