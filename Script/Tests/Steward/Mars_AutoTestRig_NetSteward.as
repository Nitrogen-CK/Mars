// The Steward net tests' shared steps, on top of the Devour net rig: the server spawns the real steward 400 in front of
// the base, facing it, under the replicated spawn owner, the Devour rig's replicated test victims (A 200 from the
// steward, B 600 from it), an unseen prey (the Devour rig's unseen victim given a transform of the server's own) and a
// fail source (a plain entity of the server's with a mechanism source on the service-failed channel). "Prey" is the
// server's copy carrying TAG_MarsSharedCombatTarget. Each machine finds its copy of the steward through the Devour
// rig, by the steward's entity tag, so its recorders, marker and ledger readers serve, and on every polled frame
// samples whom its steward ever marked and named, the first frame the pawn's camera carried the Devour layer, and where
// the view node stood above and beside the steward's root while the run was at the face (Grin, Bite, Swallowed).
UCLASS(Abstract)
class UMars_AutoTestRig_NetSteward : UMars_AutoTestRig_NetDevour
{
    default _TimeoutSeconds = 28.0f;

    protected const FVector k_StewardOffset = FVector(400.0, 0.0, 0.0);
    protected const FVector k_UnseenPreyOffset = FVector(300.0, 0.0, 0.0);
    // The steward stands within this of its spot.
    protected const float64 k_StewardSpotCm = 5.0;
    // The server waits this long between making the fail source and raising the channel.
    protected const float32 k_RiseDelaySeconds = 0.5f;
    // The server waits this long after a rise that must seize nobody; the client asserts this long after its sink rose.
    protected const float32 k_ServerQuietSeconds = 3.0f;
    protected const float32 k_ClientQuietSeconds = 1.5f;
    // A staged view: the bite point stands Maw.Bite.DistanceCm out of the face, about 229 above the root; a node nobody
    // moved sits on the root, and one left at the victim's own view sits 200 or more away from it.
    protected const float64 k_StagedMinUpCm = 150.0;
    protected const float64 k_StagedMaxUpCm = 320.0;
    protected const float64 k_StagedMaxGroundCm = 150.0;

    protected FCk_Handle_MechanismSource _FailSource;
    // The frame the server last raised the channel; -1 before.
    protected int32 _StewardRiseFrame = -1;

    // What this machine's steward was ever seen doing, sampled on every polled frame.
    protected bool _StewardEverMarkedA = false;
    protected bool _StewardEverMarkedB = false;
    protected bool _StewardEverMarkedPawn = false;
    protected bool _StewardEverNamedVictim = false;
    protected bool _StewardRawVictimEverA = false;
    protected FString _StewardNamedVictims = "";
    // The first frame the pawn's camera carried the Devour layer, and the first its entity read marked; -1 before.
    protected int32 _StewardLayerFrame = -1;
    protected int32 _StewardPawnMarkedFrame = -1;
    protected int32 _StewardStagedSamples = 0;
    protected float64 _StewardStagedMinUp = 0.0;
    protected float64 _StewardStagedMaxUp = 0.0;
    protected float64 _StewardStagedMaxGround = 0.0;

    private EMars_NetDevourTest_Victims _StewardVictims = EMars_NetDevourTest_Victims::None;
    private float64 _StewardSampleUntil = 0.0;

    // Both machines: the Devour rig's row with the steward as this machine's devourer.
    protected void Begin_StewardRow(FVector InBase, EMars_NetDevourTest_Victims InVictims)
    {
        _DevourerTag = constants_steward::k_EntityTag;
        _StewardVictims = InVictims;
        Begin_DevourRow(InBase, k_StewardOffset, InVictims);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server: the steward, the victims, the unseen prey, the fail source
    //----------------------------------------------------------------------------------------------------------------------

    // The sandbox's steward (no services).
    protected void Spawn_ServerSteward()
    {
        DoSpawn_ServerSteward(UMars_Steward_EntityScript::Params(Get_StewardSpawnTransform(), false));
    }

    // The camp's steward (it presents the Contracts station).
    protected void Spawn_ServerCampSteward()
    {
        DoSpawn_ServerSteward(UMars_Steward_EntityScript::Params(Get_StewardSpawnTransform(), true));
    }

    private void DoSpawn_ServerSteward(FMars_Steward_EntityScript_SpawnParams InParams)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        utils_entity_script::Request_SpawnEntity(Owner, UMars_Steward_EntityScript, InParams);
    }

    // At its spot, yawed to face the base.
    private FTransform Get_StewardSpawnTransform()
    {
        return FTransform(FRotator(0.0, 180.0, 0.0), _Base + k_StewardOffset);
    }

    // The row's replicated test victims under the replicated spawn owner.
    protected void Spawn_ServerStewardVictims()
    {
        if (_StewardVictims == EMars_NetDevourTest_Victims::None)
        { return; }

        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        utils_entity_script::Request_SpawnEntity(Owner, UMars_NetDevour_Victim_EntityScript,
            FMars_NetDevour_Victim_SpawnParams(FTransform(FRotator::ZeroRotator, _Base + k_VictimAOffset)));

        if (_StewardVictims != EMars_NetDevourTest_Victims::AAndB)
        { return; }

        utils_entity_script::Request_SpawnEntity(Owner, UMars_NetDevour_Victim_EntityScript,
            FMars_NetDevour_Victim_SpawnParams(FTransform(FRotator::ZeroRotator, _Base + k_VictimBOffset)));
    }

    // InOutVictim becomes prey on this machine, as a pawn a player controls is on the machine with authority over it.
    protected void Request_MakePrey(FCk_Handle& InOutVictim)
    {
        utils_entity_tag::Add(InOutVictim, n"TAG_MarsSharedCombatTarget");
    }

    // The Devour rig's unseen victim with a transform of the server's own, so the steward's scan can measure it.
    protected void Spawn_ServerUnseenPrey()
    {
        Spawn_ServerUnseenVictim();
        utils_transform::Add(_UnseenVictim, FTransform(FRotator::ZeroRotator, _Base + k_UnseenPreyOffset), ECk_Replication::DoesNotReplicate);
        Track_ForCleanup(_UnseenVictim);
    }

    // A plain entity under the subject with a source on the service-failed channel, after the check that nothing else
    // in the world outputs on it.
    protected void Spawn_ServerFailSource(EMars_MechanismSource_Output InOutput)
    {
        const auto Channel = GameplayTags::ResolveGameplayTag(constants_steward::k_ServiceFailedChannel);
        Assert_Equals_Int(utils_mechanism_source::Get_SourcesOn(Get_SubjectEntity(), Channel).Num(), 0,
            "no source in the world outputs on the service-failed channel before the row adds its own");

        auto Entity = utils_entity_lifetime::Request_CreateEntity(Get_SubjectEntity());
        auto Spec = FMars_MechanismSource_Spec();
        Spec.OutputChannel = Channel;
        Spec.StartAsserted = InOutput == EMars_MechanismSource_Output::Asserted;
        _FailSource = utils_mechanism_source::Add(Entity, Spec);
        Track_ForCleanup(Entity);
        if (InOutput == EMars_MechanismSource_Output::Asserted)
        { _StewardRiseFrame = int32(utils_time::Get_FrameCounter()); }
    }

    // The channel rises (Asserted) or falls (Deasserted).
    protected void Request_ServerFailChannel(EMars_MechanismSource_Output InOutput)
    {
        _FailSource.Request_SetOutput(utils_mechanism_source::Make_SetOutput(InOutput));
        if (InOutput == EMars_MechanismSource_Output::Asserted)
        { _StewardRiseFrame = int32(utils_time::Get_FrameCounter()); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Each machine: its copies, its sink
    //----------------------------------------------------------------------------------------------------------------------

    // A, found by this rig for the row that needs it before the steward exists; the Devour rig's readers then serve.
    protected bool Get_IsStewardVictimAFound()
    {
        if (ck::IsValid(_VictimA))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsTestNetDevourVictim"))
        {
            if (Get_IsStewardNear(Candidate, _Base + k_VictimAOffset, k_VictimNearCm) == false)
            { continue; }

            _VictimA = Candidate;
            if (Get_IsServer())
            { Track_ForCleanup(Candidate); }

            return true;
        }

        return false;
    }

    protected bool Get_IsStewardNear(FCk_Handle InEntity, FVector InSpot, float64 InCm)
    {
        const auto Transform = InEntity.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Transform))
        { return false; }

        return (utils_transform::Get_EntityCurrentTransform(Transform).GetLocation() - InSpot).Size() < InCm;
    }

    // This machine's copy of the steward as a mechanism sink; invalid before it is found and once it is gone.
    protected FCk_Handle_MechanismSink Get_StewardSink()
    {
        if (Get_IsDevourerGone())
        { return FCk_Handle_MechanismSink(); }

        FCk_Handle Entity = _Devourer;
        return Entity.As_MechanismSink(ECk_SanityCheck::UnChecked);
    }

    protected EMars_MechanismSink_Power Get_StewardPower()
    {
        const auto Sink = Get_StewardSink();
        if (ck::Is_NOT_Valid(Sink))
        { return EMars_MechanismSink_Power::Unevaluated; }

        return Sink.Get_Fragment(FMars_Fragment_MechanismSink).Power;
    }

    // This machine's steward's root, where it stands; the zero vector before it is found.
    protected FVector Get_StewardLocation()
    {
        if (Get_IsDevourerGone())
        { return FVector::ZeroVector; }

        FCk_Handle Entity = _Devourer;
        const auto Root = Entity.As_Transform(ECk_SanityCheck::UnChecked);
        return ck::IsValid(Root) ? utils_transform::Get_EntityCurrentLocation(Root) : FVector::ZeroVector;
    }

    // The Devour mirror's record on this machine's steward is set (only a copy without authority keeps one).
    protected bool Get_HasStewardMirrorState()
    {
        if (Get_IsDevourerGone() || _Devourer.Has_Fragment(FMars_Fragment_Devour_Local) == false)
        { return false; }

        return _Devourer.Get_Fragment(FMars_Fragment_Devour_Local).Last.IsSet();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The sampler
    //----------------------------------------------------------------------------------------------------------------------

    // Called from every polled predicate: finds the copies first, then records what this machine's steward shows.
    protected void Sample_Steward()
    {
        Get_AreDevourCopiesFound();
        if (_StewardLayerFrame < 0 && Get_HasDevourLayer())
        { _StewardLayerFrame = int32(utils_time::Get_FrameCounter()); }

        if (Get_IsDevourerGone())
        { return; }

        if (Get_IsMarkedByDevourer(_VictimA))
        { _StewardEverMarkedA = true; }

        if (Get_IsMarkedByDevourer(_VictimB))
        { _StewardEverMarkedB = true; }

        if (Get_IsMarkedByDevourer(_Player))
        {
            _StewardEverMarkedPawn = true;
            if (_StewardPawnMarkedFrame < 0)
            { _StewardPawnMarkedFrame = int32(utils_time::Get_FrameCounter()); }
        }

        const auto Victim = _Devourer.Get_Victim();
        if (ck::IsValid(Victim))
        {
            _StewardEverNamedVictim = true;
            const auto Name = Describe_DevourHandle(Victim) + ",";
            if (_StewardNamedVictims.Contains(Name) == false)
            { _StewardNamedVictims += Name; }
        }

        if (Describe_RawVictim() == "A")
        { _StewardRawVictimEverA = true; }

        Sample_StagedView();
    }

    // While the run is at the face, where the view node stands above the root and how far from it along the ground.
    private void Sample_StagedView()
    {
        const auto Phase = _Devourer.Get_Phase();
        if (Phase != EMars_Devour_Phase::Grin && Phase != EMars_Devour_Phase::Bite && Phase != EMars_Devour_Phase::Swallowed)
        { return; }

        const auto View = _Devourer.Get_View();
        if (ck::Is_NOT_Valid(View))
        { return; }

        const auto RootAt = Get_StewardLocation();
        const auto ViewAt = utils_transform::Get_EntityCurrentLocation(View);
        const auto Up = ViewAt.Z - RootAt.Z;
        const auto Ground = FVector(ViewAt.X - RootAt.X, ViewAt.Y - RootAt.Y, 0.0).Size();
        if (_StewardStagedSamples == 0)
        {
            _StewardStagedMinUp = Up;
            _StewardStagedMaxUp = Up;
            _StewardStagedMaxGround = Ground;
        }
        else
        {
            _StewardStagedMinUp = Math::Min(_StewardStagedMinUp, Up);
            _StewardStagedMaxUp = Math::Max(_StewardStagedMaxUp, Up);
            _StewardStagedMaxGround = Math::Max(_StewardStagedMaxGround, Ground);
        }

        _StewardStagedSamples += 1;
    }

    // At least one sample at the face, all of them at the bite point.
    protected bool Get_WasViewStaged() const
    {
        return _StewardStagedSamples > 0 && _StewardStagedMinUp >= k_StagedMinUpCm && _StewardStagedMaxUp <= k_StagedMaxUpCm
            && _StewardStagedMaxGround <= k_StagedMaxGroundCm;
    }

    // Each recorded phase is the one after the previous (Seize after Swallowed); the first may be any but Idle.
    protected bool Get_AreDevourPhasesConsecutive() const
    {
        for (auto Index = 0; Index < _DevourPhases.Num(); ++Index)
        {
            const auto Phase = _DevourPhases[Index].Phase;
            if (Phase == EMars_Devour_Phase::Idle)
            { return false; }

            if (Index == 0)
            { continue; }

            const auto Previous = _DevourPhases[Index - 1].Phase;
            const auto Expected = Previous == EMars_Devour_Phase::Swallowed
                ? EMars_Devour_Phase::Seize
                : EMars_Devour_Phase(int32(Previous) + 1);
            if (Phase != Expected)
            { return false; }
        }

        return true;
    }

    protected bool Get_DoPhasesEndAtSwallowed() const
    {
        return _DevourPhases.Num() > 0 && _DevourPhases[_DevourPhases.Num() - 1].Phase == EMars_Devour_Phase::Swallowed;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Polled predicates and the sampling wait
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Is_StewardCopiesFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Steward();
        auto Result = OutResult;
        Result.Set(Get_AreDevourCopiesFound());
    }

    // This machine's copies are found and its steward's sink has had its first evaluation.
    UFUNCTION()
    protected void Is_StewardSinkEvaluated(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Steward();
        auto Result = OutResult;
        Result.Set(Get_AreDevourCopiesFound() && Get_StewardPower() != EMars_MechanismSink_Power::Unevaluated);
    }

    UFUNCTION()
    protected void Is_StewardSinkPowered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Steward();
        auto Result = OutResult;
        Result.Set(Get_AreDevourCopiesFound() && Get_StewardPower() == EMars_MechanismSink_Power::Powered);
    }

    UFUNCTION()
    protected void Is_StewardEndedOnce(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Steward();
        auto Result = OutResult;
        Result.Set(_DevourEnds.Num() >= 1);
    }

    UFUNCTION()
    protected void Is_StewardVictimAFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsStewardVictimAFound());
    }

    // A wall-clock settle that keeps sampling every frame, then InContinuation.
    protected void WaitSampling(float32 InSeconds, FName InContinuation)
    {
        _StewardSampleUntil = Get_StewardWorldSeconds() + InSeconds;
        WaitUntil(n"Is_StewardSampledLongEnough", InContinuation, k_SlowPolls);
    }

    UFUNCTION()
    protected void Is_StewardSampledLongEnough(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Steward();
        auto Result = OutResult;
        Result.Set(Get_StewardWorldSeconds() >= _StewardSampleUntil);
    }

    private float64 Get_StewardWorldSeconds()
    {
        const auto SubjectWorld = utils_entity_lifetime::Get_WorldForEntity(Get_SubjectEntity());
        return float64(SubjectWorld.GetTimeSeconds());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The log line and the server's hold
    //----------------------------------------------------------------------------------------------------------------------

    protected void Log_StewardRow(FString InRow, FString InExtra)
    {
        const auto IsThere = Get_IsDevourerGone() == false;
        const auto Phase = IsThere ? f"{_Devourer.Get_Phase() :n}" : FString("gone");
        const auto Victim = Describe_DevourHandle(Get_DevourVictim());
        const auto Ledger = Get_DevourLedger();
        const auto LedgerText = f"{Ledger.Phase :n} serial {Ledger.Serial} end {Ledger.LastEnd :n} victim {Describe_RawVictim()}";
        const auto Power = Get_StewardPower();
        const auto EverMarked = f"A {_StewardEverMarkedA} B {_StewardEverMarkedB} pawn {_StewardEverMarkedPawn}@{_StewardPawnMarkedFrame}";
        const auto Named = f"{_StewardEverNamedVictim} [{_StewardNamedVictims}] rawEverA {_StewardRawVictimEverA}";
        const auto Staged = f"minUp {_StewardStagedMinUp} maxUp {_StewardStagedMaxUp} maxGround {_StewardStagedMaxGround} samples {_StewardStagedSamples}";
        const auto Phases = Describe_DevourPhases();
        const auto Ends = Describe_DevourEnds();
        const auto Line = f"[StewardNetTest] {InRow} {Get_MachineName()} authority={Get_HasDevourerAuthority()} phase={Phase} victim={Victim} ledger=[{LedgerText}] power={Power :n} everMarked=[{EverMarked}] named=[{Named}] phases=[{Phases}] ends=[{Ends}] devoured={_DevouredEntries}@{_DevouredFrame} layerFrame={_StewardLayerFrame} staged=[{Staged}] riseFrame={_StewardRiseFrame} ensures={Get_NewEnsures()} frame={utils_time::Get_FrameCounter()} {InExtra}";
        Log(Line);
    }

    // Server: the row's log line and no ensure, then the hold after its last write before it finishes.
    protected void Hold_StewardServerRow(FString InRow, FString InExtra)
    {
        Log_StewardRow(InRow, InExtra);
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
