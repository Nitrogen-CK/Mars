// A spider's claw leg is severed as its pincer enters Strike, both claws in the air. The attack ends, the rig keeps posing
// the legs it still has (its articulation stays operational rather than freezing in the struck pose), and the surviving
// claw is planted again by the gait.
class UMars_AutoTest_CrawlerMelee_PincerClawSeveredMidStrike : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(-320000.0, -180000.0, 600.0);

    private const FVector k_HalfExtents = FVector(35.0, 25.0, 25.0);

    private bool _Severed = false;
    private FCk_Handle_ProceduralLeg _SurvivingClaw;
    private FString _SeverText = "";

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_AggressiveCrawlerSpec(6);
        Spec.Layout = EMars_Crawler_Layout::Spider;
        Wear_ReferenceClips(Spec, EMars_Crawler_AttackClipKind::Pincer);
        SpawnFloorAndCrawler(InHandle, Spec);

        Add_SettleSteps();
        Add_Step("spawn a tagged hostile 300 cm ahead and arm the sever", n"Step_SpawnTarget");
        Add_Step_WaitUntil("a claw is severed as the pincer enters Strike", n"Check_Severed", 4000, 0);
        Add_Step_WaitUntil("the attack is back in Idle", n"Check_AttackIdle", k_SlowPolls, 0);
        Add_Step_WaitUntil("the surviving claw is planted again", n"Check_SurvivorPlanted", 4000, 0);
        Add_Step("the rig is still operational", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Crawler.BindTo_OnAttackPhaseChanged(FMars_Delegate_Crawler_OnAttackPhaseChanged(this, n"OnPhaseChanged"));
        _RecordMark = _Records.Num();
        _Target = SpawnCombatTargetAt(InHandle, Get_FacingTransform(Get_PointFromRoot(300.0, 0.0)), k_HalfExtents);
    }

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_Crawler InCrawler, EMars_Crawler_AttackPhase InOld, EMars_Crawler_AttackPhase InNew)
    {
        if (InNew != EMars_Crawler_AttackPhase::Strike || _Severed)
        { return; }

        const auto Claws = InCrawler.Get_Fragment(FMars_Fragment_Crawler_Attack).Claws;
        if (Claws.Num() != 2)
        {
            FinishFailure(f"the pincer entered Strike with {Claws.Num()} claws, not 2");
            return;
        }

        FCk_Handle Severed = Claws[0].Leg;
        _SurvivingClaw = Claws[1].Leg;
        auto Parts = _Crawler.Get_LegParts();
        for (int32 Index = 0; Index < Parts.Num(); ++Index)
        {
            FCk_Handle PartEntity = Parts[Index];
            if (PartEntity != Severed)
            { continue; }

            auto Health = Parts[Index].Get_Health();
            Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(1000.0f, GameplayTags::DamageType_Mars_Sever)));
            _Severed = true;
            _SeverText = f"severed leg part {Index} ({Claws[0].LegId})";
            return;
        }
        FinishFailure(f"the right claw {Claws[0].LegId} is not one of the crawler's leg parts");
    }

    private ECk_ProceduralArticulation_Health Get_RigHealth() const
    {
        auto RootHandle = _Crawler.As_Transform();
        const auto Subject = utils_procedural_articulation::DoCastChecked(RootHandle);
        return utils_procedural_articulation::Get_Health(Subject);
    }

    private FString Get_Diagnostics() const
    {
        const auto Survivor = ck::IsValid(_SurvivingClaw) ? f"{utils_procedural_leg::Get_Foot(_SurvivingClaw).Get_Phase() :n}" : "none";
        return f"{_SeverText}; rig {Get_RigHealth() :n}; surviving claw foot {Survivor}; phases{Get_PhaseText(_RecordMark)}; {Get_CrawlerDiagnostics()}";
    }

    UFUNCTION()
    private void Check_Severed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Severed);
    }

    UFUNCTION()
    private void Check_AttackIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::Idle);
    }

    UFUNCTION()
    private void Check_SurvivorPlanted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Get_RigHealth() != ECk_ProceduralArticulation_Health::Operational)
        {
            FinishFailure(f"the rig faulted after the claw was severed ({Get_Diagnostics()})");
            return;
        }

        auto Res = OutResult;
        Res.Set(utils_procedural_leg::Get_Foot(_SurvivingClaw).Get_Phase() == ECk_ProceduralLeg_FootPhase::Planted);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_RigHealth() == ECk_ProceduralArticulation_Health::Operational, f"the rig stays operational ({Get_Diagnostics()})");
    }
}
