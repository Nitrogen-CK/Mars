// A transient authored clip exercises the public loaded-content path without changing the crawler jab.
// The projected variant keeps its requested point outside reach; only accepted chain geometry may hit.
// The arc variant moves a two-link chain through an authored midpoint with bounded evaluated samples.
UCLASS(Abstract)
class UMars_AutoTest_CrawlerMelee_LongLimbLoadedBase : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 30.0f;
    default _AutoStageOriginField = false;

    protected bool _Arc = false;
    protected bool _Branch = false;
    private FCk_Handle_Transform _Root;
    private FCk_Handle_ProceduralArticulation _Subject;
    private FCk_Handle_ProceduralActionPlayer _Player;
    private FCk_Handle _Scope;
    private FCk_Handle_ProceduralAction _Action;
    private UCk_ProceduralAction_Data _Clip;
    private FMars_AutoTest_CrawlerMelee_Target _SphereTarget;
    private FVector _RootLocation;

    protected void LongLimbLoaded_Begin(FCk_Handle InHandle)
    {
        _RootLocation = _Arc ? FVector(164000.0, 82000.0, 2000.0) :
            (_Branch ? FVector(165000.0, 82000.0, 2000.0) : FVector(163000.0, 82000.0, 2000.0));
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Root = utils_transform::Add(RootEntity, FTransform(_RootLocation),
            ECk_Replication::DoesNotReplicate);
        auto PartEntities = TArray<FCk_Handle_Transform>();
        for (auto Index = 0; Index < 2; ++Index)
        {
            auto PartEntity = utils_entity_lifetime::Request_CreateEntity(RootEntity);
            PartEntities.Add(utils_transform::Add(PartEntity, FTransform::Identity,
                ECk_Replication::DoesNotReplicate));
        }
        auto Lengths = TArray<float32>();
        Lengths.Add(50.0f);
        Lengths.Add(50.0f);
        auto Layouts = TArray<FCk_ProceduralLimb_Layout>();
        Layouts.Add(FCk_ProceduralLimb_Layout(n"Arm", FTransform::Identity,
            Lengths, FTransform(FVector(_Arc ? 70.0 : 90.0, 0.0, 0.0)), FVector::UpVector));
        auto Bindings = TArray<FCk_ProceduralLimb_Binding>();
        Bindings.Add(FCk_ProceduralLimb_Binding(n"Arm", PartEntities));
        _Subject = utils_procedural_articulation::Add(_Root,
            FCk_ProceduralArticulation_Spec(FCk_ProceduralArticulation_Layout(Layouts), Bindings));
        // The arc's first-link midpoint sweeps through this point while both accepted end poses miss it.
        const auto TargetLocal = _Arc ? FVector(8.75, 8.75, 17.85) :
            (_Branch ? FVector(22.5, 0.0, -11.0) : FVector(115.0, 0.0, 0.0));
        _SphereTarget = SpawnCombatTarget(InHandle, _RootLocation + TargetLocal,
            FVector(5.0, 5.0, 5.0));
        if (ck::Is_NOT_Valid(_Subject) || ck::Is_NOT_Valid(_SphereTarget.Root))
        { FinishFailure("Two-link articulation and explicit target must compose"); return; }

        Add_Step_WaitUntil("two-link subject settles", n"LongLimbLoaded_Check_Settled", 900);
        Add_Step("author and admit a transient loaded clip", n"LongLimbLoaded_Step_Admit");
        Add_Step_WaitUntil("loaded clip closes and acknowledges its stream", n"LongLimbLoaded_Check_Released", 1200);
        Add_Step("verify projected or fast-arc accepted geometry", n"LongLimbLoaded_Step_Verify");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void LongLimbLoaded_Check_Settled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Subject.Get_SettledRevision() > 0 && _Subject.Get_Limbs().Num() == 1);
    }

    private UCk_ProceduralAction_Data LongLimbLoaded_MakeClip()
    {
        auto Clip = Cast<UCk_ProceduralAction_Data>(NewObject(this, UCk_ProceduralAction_Data));
        if (Clip == nullptr)
        { return nullptr; }
        auto Slot = FCk_ProceduralAction_Slot(n"ArmSlot");
        Slot.Set_InitialSource(ECk_ProceduralAction_InitialSource::AuthoredRest);
        auto Slots = TArray<FCk_ProceduralAction_Slot>();
        Slots.Add(Slot);
        Clip.Set_Slots(Slots);

        auto Track = FCk_ProceduralAction_LimbTrack(n"ArmSlot");
        Track.Set_Space(ECk_ProceduralAction_TrackSpace::RootAtStart);
        Track.Set_ReachPolicy((_Arc || _Branch) ? ECk_ProceduralAction_ReachPolicy::RejectUnreachable :
            ECk_ProceduralAction_ReachPolicy::ProjectToReach);
        auto Keys = TArray<FCk_ProceduralAction_VectorKey>();
        if (_Arc)
        {
            Keys.Add(FCk_ProceduralAction_VectorKey(FCk_FloatRange_0to1(0.0f), FVector(70.0, 0.0, 0.0)));
            Keys.Add(FCk_ProceduralAction_VectorKey(FCk_FloatRange_0to1(0.5f), FVector(0.0, 70.0, 0.0)));
            Keys.Add(FCk_ProceduralAction_VectorKey(FCk_FloatRange_0to1(1.0f), FVector(70.0, 0.0, 0.0)));
        }
        else if (_Branch)
        {
            Keys.Add(FCk_ProceduralAction_VectorKey(FCk_FloatRange_0to1(0.0f), FVector(90.0, 0.0, 0.0)));
            Keys.Add(FCk_ProceduralAction_VectorKey(FCk_FloatRange_0to1(0.5f), FVector(100.0, 0.0, 0.0)));
            Keys.Add(FCk_ProceduralAction_VectorKey(FCk_FloatRange_0to1(1.0f), FVector(90.0, 0.0, 0.0)));
            auto BendKeys = TArray<FCk_ProceduralAction_VectorKey>();
            BendKeys.Add(FCk_ProceduralAction_VectorKey(FCk_FloatRange_0to1(0.0f), FVector::UpVector));
            BendKeys.Add(FCk_ProceduralAction_VectorKey(FCk_FloatRange_0to1(0.49f), FVector::UpVector));
            BendKeys.Add(FCk_ProceduralAction_VectorKey(FCk_FloatRange_0to1(0.5f), FVector(0.0, 1.0, 0.0)));
            BendKeys.Add(FCk_ProceduralAction_VectorKey(FCk_FloatRange_0to1(0.51f), FVector(0.0, 0.0, -1.0)));
            BendKeys.Add(FCk_ProceduralAction_VectorKey(FCk_FloatRange_0to1(1.0f), FVector(0.0, 0.0, -1.0)));
            Track.Set_BendKeys(BendKeys);
        }
        else
        {
            Keys.Add(FCk_ProceduralAction_VectorKey(FCk_FloatRange_0to1(0.0f), FVector(90.0, 0.0, 0.0)));
            Keys.Add(FCk_ProceduralAction_VectorKey(FCk_FloatRange_0to1(1.0f), FVector(120.0, 0.0, 0.0)));
        }
        Track.Set_PositionKeys(Keys);
        auto Tracks = TArray<FCk_ProceduralAction_LimbTrack>();
        Tracks.Add(Track);
        const auto PhaseId = _Arc ? n"Arc" : (_Branch ? n"Branch" : n"Project");
        auto Phase = FCk_ProceduralAction_Phase(PhaseId, FCk_Time(_Arc ? 0.004 : 0.4));
        Phase.Set_LimbTracks(Tracks);
        auto Phases = TArray<FCk_ProceduralAction_Phase>();
        if (_Arc)
        { Phases.Add(FCk_ProceduralAction_Phase(n"Seed", FCk_Time(0.05))); }
        Phases.Add(Phase);
        Clip.Set_Phases(Phases);

        auto Windows = TArray<FCk_ProceduralAction_Window>();
        Windows.Add(FCk_ProceduralAction_Window(n"HitWindow",
            FCk_ProceduralAction_TimeRef(PhaseId, FCk_FloatRange_0to1(0.0f)),
            FCk_ProceduralAction_TimeRef(PhaseId, FCk_FloatRange_0to1(1.0f))));
        Clip.Set_Windows(Windows);
        return Clip;
    }

    UFUNCTION()
    private void LongLimbLoaded_Step_Admit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Clip = LongLimbLoaded_MakeClip();
        const auto Report = utils_procedural_action::Validate_Data(_Clip);
        Assert_True(_Clip != nullptr && Report.Get_Status() == ECk_ProceduralAction_ReportStatus::Valid,
            "The authored transient clip passes public structured validation");
        if (_Clip == nullptr || Report.Get_Status() != ECk_ProceduralAction_ReportStatus::Valid)
        { return; }

        auto PlayerSpec = FCk_ProceduralActionPlayer_Spec();
        auto Tuning = PlayerSpec.Get_Tuning();
        auto Sampling = Tuning.Get_Sampling();
        Sampling.Set_MaxAdvance(FCk_Time(_Arc ? 0.01 : 1.0 / 240.0));
        Sampling.Set_MaxSamples(64);
        if (_Arc)
        {
            Sampling.Set_MaxEndpointTravelCm(100.0f);
            Sampling.Set_MaxSegmentAngularStepDegrees(180.0f);
        }
        Tuning.Set_Sampling(Sampling);
        PlayerSpec.Set_Tuning(Tuning);
        _Player = utils_procedural_action_player::Add(_Subject, PlayerSpec);
        FCk_Handle Owner = _Root;
        _Scope = utils_entity_lifetime::Request_CreateEntity(Owner);
        auto SlotBindings = TArray<FCk_ProceduralAction_SlotBinding>();
        SlotBindings.Add(FCk_ProceduralAction_SlotBinding(n"ArmSlot", n"Arm"));
        auto Play = FCk_ProceduralAction_LoadedPlaySpec(_Clip);
        Play.Set_SlotBindings(SlotBindings);
        _Action = utils_procedural_action::Create_FromLoadedClip(_Scope, _Player, Play);
        auto Spec = FMars_Crawler_LongLimbSpec();
        Spec.LimbId = n"Arm";
        Spec.SegmentLengths.Add(50.0f);
        Spec.SegmentLengths.Add(50.0f);
        Spec.SegmentRadii.Add(1.0f);
        Spec.SegmentRadii.Add(1.0f);
        Spec.TargetRadiusCm = 1.0f;
        const auto Attached = utils_crawler_long_limb_demo::Attach(Owner, _Subject,
            _Player, _Action, _Scope, _SphereTarget.Root, _SphereTarget.Hurtbox, Spec, n"HitWindow");
        Assert_True(ck::IsValid(_Player) && ck::IsValid(_Action) && Attached,
            "The loaded clip owns a scoped two-link public action and bounded receipt consumer");
    }

    UFUNCTION()
    private void LongLimbLoaded_Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Root.Has_Fragment(FMars_Fragment_Crawler_LongLimbDemo) &&
            _Root.Get_Fragment(FMars_Fragment_Crawler_LongLimbDemo).StreamReleased);
    }

    UFUNCTION()
    private void LongLimbLoaded_Step_Verify(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto& Demo = _Root.Get_Fragment(FMars_Fragment_Crawler_LongLimbDemo);
        const auto Result = Demo.TerminalResult;
        Log(f"[LongLimb loaded] arc={_Arc} branch={_Branch} outcome={Result.Get_Outcome()} reason={Result.Get_Reason()} recovery={Result.Get_Recovery()} receipts={Demo.AcceptedReceiptCount} evaluated={Demo.EvaluatedSampleCount} queries={Demo.WorldQueryCount} reach={Demo.MaxAcceptedReachCm} heights={Demo.MinFirstSegmentHeightCm}/{Demo.MaxFirstSegmentHeightCm} candidates={Demo.DamageCandidateCount} failure={Demo.Failure}");
        Assert_True(Demo.Failure.IsEmpty() && Demo.TerminalSeen && Demo.StreamReleased &&
            Demo.AcceptedReceiptCount >= 2 && Demo.MaxObservedSegmentCount == 2 && Demo.WorldQueryCount > 0,
            f"Two-link loaded playback supplied accepted, reconstructed, world-queried geometry ({Demo.Failure})");
        if (_Arc)
        {
            Assert_True(Demo.EvaluatedSampleCount > 0 && Demo.DamageCandidateCount == 1 &&
                Demo.EvaluatedOnlyHitCount == 1,
                "The explicit target is hit once by evaluated geometry while both accepted endpoints miss");
        }
        else if (_Branch)
        {
            Assert_True(Demo.MaxAcceptedReachCm >= 99.9 &&
                Demo.MinFirstSegmentHeightCm < -1.0 && Demo.MaxFirstSegmentHeightCm > 1.0 &&
                Demo.DamageCandidateCount == 1,
                "Accepted two-link geometry reaches full extension, switches bend branch, and hits its bend-side target once");
        }
        else
        {
            Assert_True(Demo.MaxRequestedAcceptedErrorCm > 5.0 && Demo.DamageCandidateCount == 0,
                "Projected out-of-reach request differs from accepted chain and cannot hit the requested-only target");
        }
    }
}

class UMars_AutoTest_CrawlerMelee_LongLimbLoadedProjected : UMars_AutoTest_CrawlerMelee_LongLimbLoadedBase
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        LongLimbLoaded_Begin(InHandle);
    }
}

class UMars_AutoTest_CrawlerMelee_LongLimbLoadedFastArc : UMars_AutoTest_CrawlerMelee_LongLimbLoadedBase
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Arc = true;
        LongLimbLoaded_Begin(InHandle);
    }
}

class UMars_AutoTest_CrawlerMelee_LongLimbLoadedBranch : UMars_AutoTest_CrawlerMelee_LongLimbLoadedBase
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Branch = true;
        LongLimbLoaded_Begin(InHandle);
    }
}
