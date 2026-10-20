// The jab is a compiled clip and its phases come only from what the resolver accepted from it.
//   - The jab the crawler plays is the clip its definition names (here the reference jab, Script/Editor/
//     Mars_CrawlerAttackClips.as): the body channel from the identity offset; Windup, Strike and Recover with the
//     reference durations and easings; body keys identity -> windup key -> strike key -> identity, each phase starting
//     on the key the one before it ended on; one Offense window over [Windup 0, Recover 1); no slots.
//   - One jab (the target out of reach) runs Windup > Strike > Recover > Cooldown > Idle. Watched every frame after the
//     resolver: the attack tick changes a posed phase (into Strike, Recover or Cooldown) only on the tick right after a
//     frame that accepted a new receipt, and only to the phase that receipt reports (Cooldown: the receipt carried the
//     Offense exit). A frame that accepted nothing new is never followed by a posed phase change, and the attack is never
//     in a posed phase ahead of the last accepted interval.
class UMars_AutoTest_CrawlerMelee_ClipDrivesPhases : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 40.0f;
    default _Origin = FVector(-300000.0, -150000.0, 600.0);

    private const float64 k_TimeTolerance = 1.0e-4;
    private const float64 k_KeyTolerance = 0.01;

    private UCk_ProceduralAction_Data _Clip;
    private int32 _Generation = 0;
    private FMars_Crawler_Spec _Spec;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Spec = Make_ArmedCrawlerSpec(4);
        SpawnFloorAndCrawler(InHandle, _Spec);

        Add_Step("the attack clip is the spec's three posed phases and one Offense window", n"Step_AssertClip");
        Add_SettleSteps();
        Add_Step("spawn a target out of reach; watch what the resolver accepts", n"Step_SpawnTargetAndWatch");
        Add_Step_WaitUntil("the target's hurtbox is traceable", n"Check_TargetTraceable", k_SlowPolls, 0);
        Add_Step("select the target and request one attack", n"Step_TargetAndStart");
        Add_Step_WaitUntil("the attack is admitted (Windup)", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step("record the admitted generation", n"Step_RecordGeneration");
        Add_Step_WaitUntil("the attack is back in Idle", n"Check_AttackFinished", k_SlowPolls, 0);
        Add_Step("every posed phase change followed an accepted receipt of that phase", n"Step_AssertPhasesFollowReceipts");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertClip(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Clip = Get_ReferenceClip(EMars_Crawler_Layout::Radial, EMars_Crawler_AttackClipKind::Jab);
        if (ck::Is_NOT_Valid(_Clip))
        { return; }

        const auto Report = utils_procedural_action::Validate_Data(_Clip);
        Assert_True(Report.Get_Status() == ECk_ProceduralAction_ReportStatus::Valid, "the jab clip validates");
        const auto Check = utils_attack::Validate_Definition(Get_LoadoutJab());
        Assert_True(Check.Get_IsValid() && Get_LoadoutJab().Clip.Get() == _Clip,
            f"the jab definition plays the clip and it passes the definition's clip contract (got [{utils_crawler::Get_AttackValidationText(Check)}])");

        const auto Body = _Clip.Get_BodyChannel();
        Assert_True(Body.Get_Enabled() && Body.Get_InitialSource() == ECk_ProceduralAction_InitialSource::IdentityOffset,
            "the clip drives the body channel from the identity offset");
        Assert_Equals_Int(_Clip.Get_Slots().Num(), 0, "the jab declares no slots");

        const auto Phases = _Clip.Get_Phases();
        Assert_Equals_Int(Phases.Num(), 3, "the clip has three phases");
        if (Phases.Num() != 3)
        { return; }

#if EDITOR
        const auto Reference = utils_crawler::Make_ReferenceAttack(EMars_Crawler_Layout::Radial, EMars_Crawler_AttackClipKind::Jab);
        Assert_Phase(Phases[0], Reference.Windup, FTransform::Identity);
        Assert_Phase(Phases[1], Reference.Strike, Reference.Windup.EndBody);
        Assert_Phase(Phases[2], Reference.Recover, Reference.Strike.EndBody);
#endif

        const auto Windows = _Clip.Get_Windows();
        Assert_Equals_Int(Windows.Num(), 1, "the clip has one window");
        if (Windows.Num() != 1)
        { return; }

        const auto Offense = Windows[0];
        Assert_True(Offense.Get_Id() == utils_crawler::Get_OffenseWindowId() &&
            Offense.Get_Start().Get_PhaseId() == n"Windup" && Offense.Get_Start().Get_Time().Get_Value() == 0.0 &&
            Offense.Get_End().Get_PhaseId() == n"Recover" && Offense.Get_End().Get_Time().Get_Value() == 1.0,
            f"the window is Offense over [Windup 0, Recover 1) (got {Offense.Get_Id()} [{Offense.Get_Start().Get_PhaseId()} {Offense.Get_Start().Get_Time().Get_Value() :.2}, {Offense.Get_End().Get_PhaseId()} {Offense.Get_End().Get_Time().Get_Value() :.2}))");
    }

    // The jab definition in the spec's loadout.
    private FMars_Attack_Definition Get_LoadoutJab() const
    {
        for (const auto& Entry : _Spec.Combat.Loadout.Get().Spec.Entries)
        {
            if (Entry.Id == GameplayTags::Attack_Mars_Jab)
            { return Entry.Definition.Get().Def; }
        }

        return FMars_Attack_Definition();
    }

    // The attack phase an accepted interval's PhaseId poses; Idle for any other id.
    private EMars_Crawler_AttackPhase Find_ClipPhase(FName InPhaseId) const
    {
        if (InPhaseId == utils_crawler::Get_ClipPhaseId(EMars_Crawler_AttackPhase::Windup))
        { return EMars_Crawler_AttackPhase::Windup; }

        if (InPhaseId == utils_crawler::Get_ClipPhaseId(EMars_Crawler_AttackPhase::Strike))
        { return EMars_Crawler_AttackPhase::Strike; }

        if (InPhaseId == utils_crawler::Get_ClipPhaseId(EMars_Crawler_AttackPhase::Recover))
        { return EMars_Crawler_AttackPhase::Recover; }

        return EMars_Crawler_AttackPhase::Idle;
    }

#if EDITOR
    // InPhase lasts and eases as InExpected, and its two body keys run from InFrom to InExpected's end key.
    private void Assert_Phase(const FCk_ProceduralAction_Phase& InPhase, const FMars_Crawler_ReferencePhase& InExpected, FTransform InFrom)
    {
        const auto Label = InPhase.Get_Id();
        Assert_True(Math::Abs(InPhase.Get_Duration().Get_Seconds() - float64(InExpected.Seconds)) <= k_TimeTolerance,
            f"{Label} lasts the reference [{InExpected.Seconds :.3}] s (got [{InPhase.Get_Duration().Get_Seconds() :.3}])");
        Assert_True(InPhase.Get_Easing() == InExpected.Easing, f"{Label} uses the reference easing");

        const auto Keys = InPhase.Get_BodyKeys();
        Assert_Equals_Int(Keys.Num(), 2, f"{Label} has two body keys");
        if (Keys.Num() != 2)
        { return; }

        Assert_True(Keys[0].Get_Time().Get_Value() == 0.0 && (Keys[0].Get_Translation() - InFrom.GetLocation()).Size() <= k_KeyTolerance,
            f"{Label} starts on [{InFrom.GetLocation().ToString()}] (got [{Keys[0].Get_Translation().ToString()}])");
        Assert_True(Keys[1].Get_Time().Get_Value() == 1.0 && (Keys[1].Get_Translation() - InExpected.EndBody.GetLocation()).Size() <= k_KeyTolerance,
            f"{Label} ends on [{InExpected.EndBody.GetLocation().ToString()}] (got [{Keys[1].Get_Translation().ToString()}])");
    }
#endif

    UFUNCTION()
    private void Step_SpawnTargetAndWatch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Target = SpawnTargetAhead(InHandle, 55.0, FVector(10.0, 20.0, 20.0));
        Watch_Accepts();
    }

    UFUNCTION()
    private void Step_RecordGeneration(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Generation = _Crawler.Get_AttackGeneration();
    }

    UFUNCTION()
    private void Step_AssertPhasesFollowReceipts(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Phases = Get_PhaseText(_RecordMark);
        Assert_True(_Records.Num() - _RecordMark == 5 && Find_RecordSinceMark(EMars_Crawler_AttackPhase::Strike) >= 0 &&
            Find_RecordSinceMark(EMars_Crawler_AttackPhase::Recover) >= 0 && Find_RecordSinceMark(EMars_Crawler_AttackPhase::Cooldown) >= 0,
            f"the jab ran Windup > Strike > Recover > Cooldown > Idle (got{Phases})");
        Assert_True(_Crawler.Get_AttackLastCancel().IsSet() == false, f"nothing cancelled the jab (last cancel {Get_LastCancelText()})");
        Assert_True(_Crawler.Get_AttackClip() == _Clip, "the jab played the clip its definition names");

        const auto Watch = Get_AcceptRecords();
        int32 PosedChanges = 0;
        int32 QuietFrames = 0;
        for (int32 Index = 1; Index + 1 < Watch.Num(); ++Index)
        {
            const auto& Previous = Watch[Index - 1];
            const auto& Current = Watch[Index];
            const auto& Next = Watch[Index + 1];
            if (Current.Generation != _Generation || Next.Generation != _Generation)
            { continue; }

            const auto AcceptedPhase = Find_ClipPhase(Current.AcceptedPhaseId);
            if (Current.Phase == EMars_Crawler_AttackPhase::Strike || Current.Phase == EMars_Crawler_AttackPhase::Recover)
            {
                Assert_True(int32(AcceptedPhase) >= int32(Current.Phase),
                    f"frame {Current.Frame}: the attack in {Current.Phase :n} is not ahead of the accepted interval ({Current.AcceptedPhaseId})");
            }

            const auto NewReceipt = Current.AckSampleId != Previous.AckSampleId;
            if (NewReceipt == false && Previous.Generation == _Generation)
            { ++QuietFrames; }

            const auto Posed = Next.Phase == EMars_Crawler_AttackPhase::Strike || Next.Phase == EMars_Crawler_AttackPhase::Recover ||
                Next.Phase == EMars_Crawler_AttackPhase::Cooldown;
            if (Next.Phase == Current.Phase || Posed == false)
            { continue; }

            ++PosedChanges;
            Assert_True(NewReceipt, f"frame {Next.Frame}: {Current.Phase :n} > {Next.Phase :n} came right after a frame that accepted a new receipt (sample {Previous.AckSampleId} -> {Current.AckSampleId})");
            if (Next.Phase == EMars_Crawler_AttackPhase::Cooldown)
            {
                Assert_True(Current.OffenseEnded && Current.AcceptedPhaseId == n"Recover",
                    f"frame {Next.Frame}: Cooldown came right after the accepted Recover interval that closed Offense (got {Current.AcceptedPhaseId}, offense ended {Current.OffenseEnded})");
            }
            else
            {
                Assert_True(int32(AcceptedPhase) >= int32(Next.Phase),
                    f"frame {Next.Frame}: {Next.Phase :n} came right after an accepted interval of that phase (got {Current.AcceptedPhaseId})");
            }
        }

        Assert_True(PosedChanges >= 2, f"the watch saw the posed phase changes ({PosedChanges}; frames that accepted nothing new: {QuietFrames})");
    }
}
