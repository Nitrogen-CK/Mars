// The jab is a compiled clip and its phases come only from what the resolver accepted from it.
//   - utils_crawler::Build_AttackClip builds the spec's jab: the body channel from the identity offset; Windup, Strike and
//     Recover with the spec's durations and easings; body keys identity -> windup key -> strike key -> identity, each
//     phase starting on the key the one before it ended on; one Offense window over [Windup 0, Recover 1).
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

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_ArmedCrawlerSpec(4));

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
        // The kernel rebuilds the clip at every admission with the claws that attack claims; a body-only jab claims none.
        auto Combat = Make_ArmedCrawlerSpec(4).Combat;
        _Clip = Cast<UCk_ProceduralAction_Data>(NewObject(this, UCk_ProceduralAction_Data));
        auto Build = FMars_Crawler_ClipBuild();
        Build.Combat = Combat;
        const auto Built = utils_crawler::Build_AttackClip(Build, _Clip);
        Assert_True(Built.Get_Status() == ECk_ProceduralAction_ReportStatus::Valid,
            f"Build_AttackClip built the body-only jab (got [{utils_crawler::Get_FirstDiagnosticText(Built)}])");
        if (Built.Get_Status() != ECk_ProceduralAction_ReportStatus::Valid)
        { return; }

        const auto Report = utils_procedural_action::Validate_Data(_Clip);
        Assert_True(Report.Get_Status() == ECk_ProceduralAction_ReportStatus::Valid, "the built clip validates");

        const auto Body = _Clip.Get_BodyChannel();
        Assert_True(Body.Get_Enabled() && Body.Get_InitialSource() == ECk_ProceduralAction_InitialSource::IdentityOffset,
            "the clip drives the body channel from the identity offset");

        const auto Phases = _Clip.Get_Phases();
        Assert_Equals_Int(Phases.Num(), 3, "the clip has three phases");
        if (Phases.Num() != 3)
        { return; }

        const auto& Timing = Combat.Timing;
        const auto& Pose = Combat.Pose;
        Assert_Phase(Phases[0], FMars_Crawler_ClipPhase(EMars_Crawler_AttackPhase::Windup, Timing.WindupSeconds, Pose.WindupEasing, FTransform::Identity, Pose.Windup));
        Assert_Phase(Phases[1], FMars_Crawler_ClipPhase(EMars_Crawler_AttackPhase::Strike, Timing.StrikeSeconds, Pose.StrikeEasing, Pose.Windup, Pose.Strike));
        Assert_Phase(Phases[2], FMars_Crawler_ClipPhase(EMars_Crawler_AttackPhase::Recover, Timing.RecoverSeconds, Pose.RecoverEasing, Pose.Strike, FTransform::Identity));

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

    private void Assert_Phase(const FCk_ProceduralAction_Phase& InPhase, const FMars_Crawler_ClipPhase& InExpected)
    {
        const auto Label = utils_crawler::Get_ClipPhaseId(InExpected.Phase);
        Assert_True(InPhase.Get_Id() == Label, f"phase {Label} is in order (got {InPhase.Get_Id()})");
        Assert_True(Math::Abs(InPhase.Get_Duration().Get_Seconds() - float64(InExpected.Seconds)) <= k_TimeTolerance,
            f"{Label} lasts the spec's [{InExpected.Seconds :.3}] s (got [{InPhase.Get_Duration().Get_Seconds() :.3}])");
        Assert_True(InPhase.Get_Easing() == InExpected.Easing, f"{Label} uses the spec's easing");

        const auto Keys = InPhase.Get_BodyKeys();
        Assert_Equals_Int(Keys.Num(), 2, f"{Label} has two body keys");
        if (Keys.Num() != 2)
        { return; }

        Assert_True(Keys[0].Get_Time().Get_Value() == 0.0 && (Keys[0].Get_Translation() - InExpected.From.GetLocation()).Size() <= k_KeyTolerance,
            f"{Label} starts on [{InExpected.From.GetLocation().ToString()}] (got [{Keys[0].Get_Translation().ToString()}])");
        Assert_True(Keys[1].Get_Time().Get_Value() == 1.0 && (Keys[1].Get_Translation() - InExpected.To.GetLocation()).Size() <= k_KeyTolerance,
            f"{Label} ends on [{InExpected.To.GetLocation().ToString()}] (got [{Keys[1].Get_Translation().ToString()}])");
    }

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

            const auto AcceptedPhase = utils_crawler::Find_ClipPhase(Current.AcceptedPhaseId);
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
