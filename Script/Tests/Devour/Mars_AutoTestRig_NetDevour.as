// The Devour net tests' shared steps, on top of the pawn rig (whose pawn only the joined-player row spawns): the server
// spawns a test devourer 100 above its spot and the row's victims at fixed offsets from the base, each under the
// replicated spawn owner, and, when a row needs one, an unseen victim, a plain entity owned by the subject (so it
// exists on the server only). Each machine finds its copy of the devourer and of each victim by tag near its spot,
// records every OnPhaseChanged and OnEnded its own devourer raises (with the frame) and, for the pawn, every entry into
// Devoured.
struct FMars_NetDevourTest_Phase
{
    UPROPERTY()
    EMars_Devour_Phase Phase = EMars_Devour_Phase::Idle;

    UPROPERTY()
    int32 Frame = -1;
}

struct FMars_NetDevourTest_End
{
    UPROPERTY()
    EMars_Devour_End End = EMars_Devour_End::Completed;

    UPROPERTY()
    FCk_Handle Victim;

    UPROPERTY()
    int32 Frame = -1;
}

// The victims a row spawns and finds.
enum EMars_NetDevourTest_Victims
{
    None,
    A,
    AAndB
}

UCLASS(Abstract)
class UMars_AutoTestRig_NetDevour : UMars_AutoTestRig_NetPlayerCombat
{
    default _TimeoutSeconds = 25.0f;

    protected const FVector k_DevourerOffset = FVector(0.0, 0.0, 100.0);
    protected const FVector k_VictimAOffset = FVector(200.0, 0.0, 0.0);
    protected const FVector k_VictimBOffset = FVector(-200.0, 0.0, 0.0);
    protected const float64 k_DevourerNearCm = 300.0;
    protected const float64 k_VictimNearCm = 100.0;

    protected FCk_Handle_Devour _Devourer;
    protected FCk_Handle _VictimA;
    protected FCk_Handle _VictimB;
    // The server's plain entity no client has.
    protected FCk_Handle _UnseenVictim;
    protected TArray<FMars_NetDevourTest_Phase> _DevourPhases;
    protected TArray<FMars_NetDevourTest_End> _DevourEnds;
    protected int32 _DevouredEntries = 0;
    protected int32 _DevouredFrame = -1;

    private FVector _DevourerSpot = FVector::ZeroVector;
    private EMars_NetDevourTest_Victims _Victims = EMars_NetDevourTest_Victims::A;
    private bool _DevouredBound = false;

    // Both machines: the pawn rig's floor, then where this row's devourer stands and which victims it has.
    protected void Begin_DevourRow(FVector InBase, FVector InDevourerOffset, EMars_NetDevourTest_Victims InVictims)
    {
        Begin_Rig(InBase);
        _DevourerSpot = InBase + InDevourerOffset;
        _Victims = InVictims;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Timings
    //----------------------------------------------------------------------------------------------------------------------

    protected FMars_Devour_Timing Make_Timing(float32 InSeconds) const
    {
        auto Timing = FMars_Devour_Timing();
        Timing.SeizeSeconds = InSeconds;
        Timing.LiftSeconds = InSeconds;
        Timing.BlinkSeconds = InSeconds;
        Timing.GrinSeconds = InSeconds;
        Timing.BiteSeconds = InSeconds;
        Timing.SwallowedSeconds = InSeconds;
        return Timing;
    }

    // Every phase 0.5 s: a run is 3.0 s.
    protected FMars_Devour_Timing Make_NetTiming() const
    {
        return Make_Timing(0.5f);
    }

    protected FMars_Devour_Timing Make_LongSeizeTiming() const
    {
        auto Timing = Make_Timing(0.5f);
        Timing.SeizeSeconds = 20.0f;
        return Timing;
    }

    protected FMars_Devour_Timing Make_LongLiftTiming() const
    {
        auto Timing = Make_Timing(0.5f);
        Timing.SeizeSeconds = 0.3f;
        Timing.LiftSeconds = 20.0f;
        return Timing;
    }

    // Grin 4.0, the rest 0.3: a run is 5.5 s.
    protected FMars_Devour_Timing Make_LongGrinTiming() const
    {
        auto Timing = Make_Timing(0.3f);
        Timing.GrinSeconds = 4.0f;
        return Timing;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server: the devourer, the victims
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Is_ServerSpawnOwnerReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()));
    }

    // The devourer at its spot and the row's victims, under the replicated spawn owner.
    protected void Spawn_ServerDevourRow(FMars_Devour_Timing InTiming, ECk_EnableDisable InViewNode)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Params = FMars_NetDevour_Devourer_SpawnParams(FTransform(FRotator::ZeroRotator, _DevourerSpot), InTiming);
        Params.ViewNode = InViewNode;
        utils_entity_script::Request_SpawnEntity(Owner, UMars_NetDevour_Devourer_EntityScript, Params);

        if (_Victims == EMars_NetDevourTest_Victims::None)
        { return; }

        utils_entity_script::Request_SpawnEntity(Owner, UMars_NetDevour_Victim_EntityScript,
            FMars_NetDevour_Victim_SpawnParams(FTransform(FRotator::ZeroRotator, _Base + k_VictimAOffset)));

        if (_Victims != EMars_NetDevourTest_Victims::AAndB)
        { return; }

        utils_entity_script::Request_SpawnEntity(Owner, UMars_NetDevour_Victim_EntityScript,
            FMars_NetDevour_Victim_SpawnParams(FTransform(FRotator::ZeroRotator, _Base + k_VictimBOffset)));
    }

    // A plain entity under the subject: it never replicates.
    protected void Spawn_ServerUnseenVictim()
    {
        _UnseenVictim = utils_entity_lifetime::Request_CreateEntity(Get_SubjectEntity());
    }

    protected void Request_DevourBegin(FCk_Handle InVictim)
    {
        _Devourer.Request_Begin(FMars_Request_Devour_Begin(InVictim));
    }

    protected void Request_DevourCancel()
    {
        _Devourer.Request_Cancel(FMars_Request_Devour_Cancel());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Each machine: its copies
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Is_DevourCopiesFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_AreDevourCopiesFound());
    }

    // This machine's devourer and the row's victims have composed.
    protected bool Get_AreDevourCopiesFound()
    {
        const auto HasDevourer = Get_IsDevourerFound();
        if (_Victims == EMars_NetDevourTest_Victims::None)
        { return HasDevourer; }

        const auto HasA = Get_IsVictimFound(_VictimA, k_VictimAOffset);
        if (_Victims == EMars_NetDevourTest_Victims::A)
        { return HasDevourer && HasA; }

        const auto HasB = Get_IsVictimFound(_VictimB, k_VictimBOffset);
        return HasDevourer && HasA && HasB;
    }

    // The first time it is found, its signals are recorded from here (and the server tracks it).
    protected bool Get_IsDevourerFound()
    {
        if (ck::IsValid(_Devourer))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsTestNetDevourer"))
        {
            if (Get_IsWithin(Candidate, _DevourerSpot, k_DevourerNearCm) == false)
            { continue; }

            auto Devourer = Candidate.As_Devour(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Devourer))
            { continue; }

            _Devourer = Devourer;
            _Devourer.BindTo_OnPhaseChanged(FMars_Delegate_Devour_OnPhaseChanged(this, n"OnDevourPhaseChanged"));
            _Devourer.BindTo_OnEnded(FMars_Delegate_Devour_OnEnded(this, n"OnDevourEnded"));
            if (Get_IsServer())
            { Track_ForCleanup(Candidate); }

            return true;
        }

        return false;
    }

    private bool Get_IsVictimFound(FCk_Handle& OutVictim, FVector InOffset)
    {
        if (ck::IsValid(OutVictim))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsTestNetDevourVictim"))
        {
            if (Get_IsWithin(Candidate, _Base + InOffset, k_VictimNearCm) == false)
            { continue; }

            OutVictim = Candidate;
            if (Get_IsServer())
            { Track_ForCleanup(Candidate); }

            return true;
        }

        return false;
    }

    private bool Get_IsWithin(FCk_Handle InEntity, FVector InSpot, float64 InCm)
    {
        const auto Transform = InEntity.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Transform))
        { return false; }

        return (utils_transform::Get_EntityCurrentTransform(Transform).GetLocation() - InSpot).Size() < InCm;
    }

    // Quiet when the server has already destroyed what this machine's copy was.
    protected bool Get_IsDevourerGone()
    {
        FCk_Handle Entity = _Devourer;
        return ck::Is_NOT_Valid(Entity) || utils_entity_lifetime::Get_IsPendingDestroy(Entity, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
    }

    protected bool Get_IsDevourerIn(EMars_Devour_Phase InPhase)
    {
        return Get_IsDevourerGone() == false && _Devourer.Get_Phase() == InPhase;
    }

    protected bool Get_HasRunningTag()
    {
        return Get_IsDevourerGone() == false && _Devourer.Has_Fragment(FMars_Tag_Devour_Running);
    }

    protected bool Get_HasDevourRequests()
    {
        return Get_IsDevourerGone() == false && _Devourer.Has_Fragment(FMars_Fragment_Devour_Requests);
    }

    protected bool Get_HasDevourerAuthority()
    {
        return Get_IsDevourerGone() == false && utils_net::Get_HasAuthority(_Devourer.H());
    }

    // This machine's ledger; a default one before the devourer is found.
    protected FMars_Fragment_Devour_Net Get_DevourLedger()
    {
        if (Get_IsDevourerGone() || _Devourer.Has_Fragment(FMars_Fragment_Devour_Net) == false)
        { return FMars_Fragment_Devour_Net(); }

        return _Devourer.Get_Fragment(FMars_Fragment_Devour_Net);
    }

    // InVictim carries the marker and it names this machine's copy of the devourer.
    protected bool Get_IsMarkedByDevourer(FCk_Handle InVictim)
    {
        if (ck::Is_NOT_Valid(InVictim) || Get_IsDevourerGone())
        { return false; }

        return utils_devour::TryGet_Devourer(InVictim).H() == _Devourer.H();
    }

    protected bool Get_HasVictimMarker(FCk_Handle InVictim)
    {
        return ck::IsValid(InVictim) && InVictim.Has_Fragment(FMars_Fragment_Devour_Victim);
    }

    protected FCk_Handle Get_DevourVictim()
    {
        if (Get_IsDevourerGone())
        { return FCk_Handle(); }

        return _Devourer.Get_Victim();
    }

    // InHandle named as this rig knows it.
    protected FString Describe_DevourHandle(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(InHandle))
        { return "invalid"; }

        if (ck::IsValid(_Devourer) && InHandle == _Devourer.H())
        { return "self"; }

        if (ck::IsValid(_VictimA) && InHandle == _VictimA)
        { return "A"; }

        if (ck::IsValid(_VictimB) && InHandle == _VictimB)
        { return "B"; }

        if (ck::IsValid(_Player) && InHandle == _Player)
        { return "pawn"; }

        if (ck::IsValid(_UnseenVictim) && InHandle == _UnseenVictim)
        { return "unseen"; }

        return "other";
    }

    protected FString Describe_RawVictim()
    {
        return Describe_DevourHandle(Get_DevourLedger().Victim);
    }

    // Who this machine sees marked by its devourer.
    protected FString Describe_Marked()
    {
        FString Text = "";
        if (Get_IsMarkedByDevourer(_VictimA))
        { Text += "A,"; }

        if (Get_IsMarkedByDevourer(_VictimB))
        { Text += "B,"; }

        if (Get_IsMarkedByDevourer(_Player))
        { Text += "pawn,"; }

        if (Get_IsMarkedByDevourer(_UnseenVictim))
        { Text += "unseen,"; }

        return Text;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The pawn: Devoured and the camera
    //----------------------------------------------------------------------------------------------------------------------

    // The pawn's copy is composed; from the first poll that finds its state machine, its entries into Devoured are
    // counted.
    protected bool Get_IsPawnComposedForDevour()
    {
        if (Get_IsPawnComposed() == false)
        { return false; }

        if (_DevouredBound == false && ck::IsValid(_Sm))
        {
            utils_state_machine::BindTo_OnStateChanged(_Sm, FCk_Delegate_Sm_OnStateChanged(this, n"OnDevourSmStateChanged"));
            _DevouredBound = true;
        }

        return true;
    }

    // The pawn's viewpoint's camera carries the Devour layer.
    protected bool Get_HasDevourLayer()
    {
        if (ck::Is_NOT_Valid(_Player))
        { return false; }

        const auto Viewpoint = _Player.As_PlayerViewpoint(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Viewpoint))
        { return false; }

        const auto Camera = Viewpoint.Get_Camera();
        return ck::IsValid(Camera) && Camera.Has_Layer(UMars_CameraLayer_Devour);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The recorded phases and ends
    //----------------------------------------------------------------------------------------------------------------------

    // Each recorded phase is the next of Seize, Lift, Blink, Grin, Bite, Swallowed, over and over.
    protected bool Get_AreDevourPhasesInRunOrder() const
    {
        for (auto Index = 0; Index < _DevourPhases.Num(); ++Index)
        {
            const auto Expected = EMars_Devour_Phase(int32(EMars_Devour_Phase::Seize) + Index % 6);
            if (_DevourPhases[Index].Phase != Expected)
            { return false; }
        }

        return true;
    }

    // In run order, InRuns runs.
    protected bool Get_AreDevourRuns(int32 InRuns) const
    {
        return _DevourPhases.Num() == InRuns * 6 && Get_AreDevourPhasesInRunOrder();
    }

    protected int32 Count_DevourPhases(EMars_Devour_Phase InPhase) const
    {
        auto Count = 0;
        for (const auto& Recorded : _DevourPhases)
        {
            if (Recorded.Phase == InPhase)
            { ++Count; }
        }

        return Count;
    }

    // How many recorded phases had a frame of their own.
    protected int32 Count_DevourPhasesAlone() const
    {
        auto Count = 0;
        for (auto Index = 0; Index < _DevourPhases.Num(); ++Index)
        {
            const auto Frame = _DevourPhases[Index].Frame;
            const auto SharesBefore = Index > 0 && _DevourPhases[Index - 1].Frame == Frame;
            const auto SharesAfter = Index + 1 < _DevourPhases.Num() && _DevourPhases[Index + 1].Frame == Frame;
            if (SharesBefore == false && SharesAfter == false)
            { ++Count; }
        }

        return Count;
    }

    protected FString Describe_DevourPhases() const
    {
        FString Text = "";
        for (const auto& Recorded : _DevourPhases)
        { Text += f"{Recorded.Phase :n}@{Recorded.Frame},"; }

        return Text;
    }

    protected FString Describe_DevourEnds()
    {
        FString Text = "";
        for (const auto& Recorded : _DevourEnds)
        { Text += f"{Recorded.End :n}/{Describe_DevourHandle(Recorded.Victim)}@{Recorded.Frame},"; }

        return Text;
    }

    UFUNCTION()
    protected void Is_DevourEndedOnce(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_DevourEnds.Num() >= 1);
    }

    UFUNCTION()
    protected void Is_DevourEndedTwice(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_DevourEnds.Num() >= 2);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The log line and the finish
    //----------------------------------------------------------------------------------------------------------------------

    protected void Log_DevourRow(FString InRow, FString InExtra)
    {
        const auto IsThere = Get_IsDevourerGone() == false;
        const auto Phase = IsThere ? f"{_Devourer.Get_Phase() :n}" : FString("gone");
        const auto Seconds = IsThere ? _Devourer.Get_PhaseSeconds() : -1.0f;
        const auto Victim = Describe_DevourHandle(Get_DevourVictim());
        const auto Ledger = Get_DevourLedger();
        const auto LedgerText = f"{Ledger.Phase :n} serial {Ledger.Serial} end {Ledger.LastEnd :n} victim {Describe_RawVictim()}";
        const auto Phases = Describe_DevourPhases();
        const auto Ends = Describe_DevourEnds();
        const auto Marked = Describe_Marked();
        const auto Line = f"[DevourNetTest] {InRow} {Get_MachineName()} authority={Get_HasDevourerAuthority()} phase={Phase} phaseSeconds={Seconds} victim={Victim} ledger=[{LedgerText}] running={Get_HasRunningTag()} marked=[{Marked}] phases=[{Phases}] ends=[{Ends}] devoured={_DevouredEntries}@{_DevouredFrame} layer={Get_HasDevourLayer()} ensures={Get_NewEnsures()} frame={utils_time::Get_FrameCounter()} {InExtra}";
        Log(Line);
    }

    // Client: no ensure, then the finish (the row has logged its line).
    protected void Finish_DevourRow()
    {
        Assert_Equals_Int(Get_NewEnsures(), 0, f"no ensure on the {Get_MachineName()}");
        TearDown();
        FinishSuccess();
    }

    // Server: the row's log line and no ensure, then the hold after its last write before it finishes.
    protected void Hold_DevourServerRow(FString InRow, FString InExtra)
    {
        Log_DevourRow(InRow, InExtra);
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Signals
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnDevourPhaseChanged(FCk_Handle_Devour InDevour, EMars_Devour_Phase InPhase)
    {
        auto Recorded = FMars_NetDevourTest_Phase();
        Recorded.Phase = InPhase;
        Recorded.Frame = int32(utils_time::Get_FrameCounter());
        _DevourPhases.Add(Recorded);
    }

    UFUNCTION()
    private void OnDevourEnded(FCk_Handle_Devour InDevour, FCk_Handle InVictim, EMars_Devour_End InEnd)
    {
        auto Recorded = FMars_NetDevourTest_End();
        Recorded.End = InEnd;
        Recorded.Victim = InVictim;
        Recorded.Frame = int32(utils_time::Get_FrameCounter());
        _DevourEnds.Add(Recorded);
    }

    UFUNCTION()
    private void OnDevourSmStateChanged(FCk_Handle_StateMachine InStateMachine, FCk_Sm_Payload_OnStateChanged InPayload)
    {
        if (InPayload.Get_NewStateClass() != UMars_SmState_Devoured)
        { return; }

        _DevouredEntries += 1;
        _DevouredFrame = int32(utils_time::Get_FrameCounter());
    }
}
