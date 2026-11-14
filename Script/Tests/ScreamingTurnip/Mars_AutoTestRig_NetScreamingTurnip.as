// One recorded grip holder change, as the bed's Control raised it on this machine.
struct FMars_AutoTestHelper_TurnipHolderChange
{
    EMars_Control_GripHolder Previous = EMars_Control_GripHolder::Nobody;
    EMars_Control_GripHolder Holder = EMars_Control_GripHolder::Nobody;
}

// The turnip bed net tests' shared steps, on the control net rig. The server spawns the real bed under the replicated
// spawn owner with the single-machine rig's pull (travel 120 cm, spring 400 / 40, engage 0.97) and no floor; each machine
// finds its copy by tag with its Use target, takes its Forage, and records the Forage's OnReleased and OnExhausted and the
// Control's OnGripHolderChanged (the control rig records OnEngaged, OnActiveChanged and OnGripRefused). A pull is driven
// as the player's grip task drives it, without gloves: the subject starts the interaction on its own copy's target, the
// new interaction's grip is begun with a puller transform entity this machine owns (k_PullerStartCm from the bed on its
// -X), walking the puller straight away from the bed is the stretch, and the interaction's finish ends the grip.
// "The stretch" is what this machine shows of the grip (TryGet_ShownGripAlpha, 0 when unset).
UCLASS(Abstract)
class UMars_AutoTestRig_NetScreamingTurnip : UMars_AutoTestRig_NetControl
{
    default _TimeoutSeconds = 25.0f;

    protected const float64 k_PullerStartCm = 60.0;
    // A root is near its bed by horizontal distance: nothing has a floor, so it keeps falling.
    protected const float64 k_NearCm = 400.0;
    // How close a shown stretch must come to the pull it follows.
    protected const float32 k_StretchTolerance = 0.05f;

    protected FMars_ScreamingTurnipBed_PullSpec _BedPull = FMars_ScreamingTurnipBed_PullSpec(
        FMars_ScreamingTurnipBed_StretchSpec(120.0f, 15.0f),
        FMars_ScreamingTurnipBed_SpringSpec(400.0f, 40.0f, 0.97f),
        FMars_ScreamingTurnipBed_TimingSpec(0.2f, 0.7f, 540.0f));

    protected FVector _BedLocation = FVector::ZeroVector;
    protected FCk_Handle _TestHandle;
    protected FCk_Handle_Forage _Forage;
    protected FCk_Handle_Transform _Puller;

    protected TArray<EMars_Forage_ReleaseReason> _ReleaseReasons;
    protected int32 _ExhaustedCount = 0;
    protected TArray<FMars_AutoTestHelper_TurnipHolderChange> _HolderChanges;

    // The highest stretch this machine showed while its ledger still counted no engagement.
    protected float32 _MaxStretchBeforeEngage = 0.0f;
    // Whether this machine's interactable held the Operated claim at any sample.
    protected bool _EverClaimed = false;
    // How long Is_PulledAndHeld holds the grip once it began.
    protected float32 _HoldSeconds = 0.0f;
    private TOptional<float64> _GripSeenAt;

    // The frame this machine's interaction ended Succeeded (its threshold), and the frame its Forage first raised
    // OnReleased; -1 before either.
    protected int64 _ThresholdFrame = -1;
    protected int64 _ReleasedFrame = -1;

    // Both machines, first thing: InHandle is the test's own entity (it owns the puller).
    protected void Begin_TurnipTest(FCk_Handle InHandle, FVector InBedLocation)
    {
        Begin_NetControlTest();
        _TestHandle = InHandle;
        _BedLocation = InBedLocation;
    }

    // Server: the bed at the test's location, under the spawn owner.
    protected void Spawn_ServerBed()
    {
        auto Params = UMars_ScreamingTurnipBed_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _BedLocation);
        Params.Pull = _BedPull;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
            UMars_ScreamingTurnipBed_EntityScript, Params);
    }

    // This machine's copy of the bed has composed with its Use target; the first time, its Forage and holder signals are
    // recorded from here, its grip is ended by its interaction's finish, and this machine's puller is made.
    protected bool Get_IsBedFound()
    {
        if (ck::IsValid(_Forage))
        { return true; }

        if (Get_IsControlFound(n"TAG_MarsScreamingTurnipBed") == false)
        { return false; }

        FCk_Handle Bed = _Control;
        _Forage = Bed.As_Forage(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Forage))
        { return false; }

        _Forage.BindTo_OnReleased(FMars_Delegate_Forage_OnReleased(this, n"OnBedReleased"));
        _Forage.BindTo_OnExhausted(FMars_Delegate_Forage_OnExhausted(this, n"OnBedExhausted"));
        _Control.BindTo_OnGripHolderChanged(FMars_Delegate_Control_OnGripHolderChanged(this, n"OnBedGripHolderChanged"));
        _Target.BindTo_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnBedInteractionFinished"));

        auto PullerEntity = utils_entity_lifetime::Request_CreateEntity(_TestHandle);
        _Puller = utils_transform::Add(PullerEntity, FTransform(FRotator::ZeroRotator, Get_PullerLocation(0.0)),
            ECk_Replication::DoesNotReplicate);
        utils_handle::Set_DebugName(_Puller.H(), n"NetScreamingTurnipRig.Puller");
        return true;
    }

    // The grip of this machine's live interaction, with its puller.
    protected void Begin_Pull()
    {
        _Control.Request_BeginManipulation(FMars_Request_Control_BeginManipulation(_Interaction,
            EMars_Control_ManipulationCompletion::AtEngageAlpha, _Puller));
    }

    // The puller InAlpha of the travel farther from the bed than where it gripped.
    protected void Walk_To(float32 InAlpha)
    {
        utils_transform::Request_SetLocation(_Puller, FCk_Request_Transform_SetLocation(Get_PullerLocation(InAlpha * _BedPull.Stretch.TravelCm)));
    }

    // The press ends early: this machine's live interaction is cancelled, as letting go of Use does.
    protected void Cancel_Pull()
    {
        _Target.Request_CancelInteraction(FCk_Request_InteractTarget_CancelInteraction(Get_SubjectEntity()));
    }

    private FVector Get_PullerLocation(float64 InGainedCm) const
    {
        return _BedLocation + FVector(-(k_PullerStartCm + InGainedCm), 0.0, 0.0);
    }

    protected float32 Get_Stretch() const
    {
        const auto Shown = _Control.TryGet_ShownGripAlpha();
        return Shown.IsSet() ? Shown.GetValue() : 0.0f;
    }

    protected bool Get_IsTargetEnabled() const
    {
        return ck::IsValid(_Interactable) && _Interactable.Get_EnableDisable() == ECk_EnableDisable::Enable;
    }

    // World items within k_NearCm of the bed, horizontally (the server tracks each root its bed releases).
    protected int32 Count_RootsNearBed() const
    {
        auto Count = 0;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(_Subject, n"TAG_MarsWorldItem"))
        {
            if (Candidate.Is_WorldItem() == false)
            { continue; }

            auto Offset = utils_transform::Get_EntityCurrentTransform(Candidate.As_Transform()).GetLocation() - _BedLocation;
            Offset.Z = 0.0;
            if (Offset.Size() >= k_NearCm)
            { continue; }

            Count += 1;
        }

        return Count;
    }

    protected int32 Count_HolderChanges(EMars_Control_GripHolder InPrevious, EMars_Control_GripHolder InHolder) const
    {
        auto Count = 0;
        for (const auto& Change : _HolderChanges)
        {
            if (Change.Previous == InPrevious && Change.Holder == InHolder)
            { Count += 1; }
        }

        return Count;
    }

    protected int32 Count_HolderChangesTo(EMars_Control_GripHolder InHolder) const
    {
        auto Count = 0;
        for (const auto& Change : _HolderChanges)
        {
            if (Change.Holder == InHolder)
            { Count += 1; }
        }

        return Count;
    }

    // Forgets every signal this machine recorded so far.
    protected void Clear_Record()
    {
        _ReleaseReasons.Empty();
        _ExhaustedCount = 0;
        _HolderChanges.Empty();
        _EngagedCount = 0;
        _Activations.Empty();
        _GripRefusals.Empty();
    }

    // The bed's three ledgers as this machine reads them.
    protected FString Get_LedgersText() const
    {
        const auto& Ledger = _Control.Get_Fragment(FMars_Fragment_Control);
        return f"active {Ledger.IsActive}, engagements {Ledger.Engagements}, {Get_GripText(_Control)}, ledgerPull {_Control.Get_GripPull() :.3}, charges {_Forage.Get_ChargesLeft()}, released {_Forage.Get_ReleasedCount()}";
    }

    protected FString Get_HolderChangesText() const
    {
        auto Text = FString();
        for (const auto& Change : _HolderChanges)
        { Text += f"{Change.Previous :n}>{Change.Holder :n} "; }

        return Text;
    }

    protected FString Get_ReleaseReasonsText() const
    {
        auto Text = FString();
        for (auto Reason : _ReleaseReasons)
        { Text += f"{Reason :n} "; }

        return Text;
    }

    // What every log line carries.
    protected FString Get_BedText() const
    {
        const auto Shown = _Control.TryGet_ShownGripAlpha();
        const auto ShownText = Shown.IsSet() ? f"{Shown.GetValue() :.3}" : "unset";
        return f"{Get_LedgersText()}, holder {_Control.Get_GripHolder() :n}, stretch {ShownText}, manipulating {_Control.Get_IsManipulating()}, claimed {Get_IsClaimed()}, enabled {Get_IsTargetEnabled()}, exhaustedFor {_Interactable.Get_IsDisabledFor(EMars_Interactable_DisableReason::Exhausted)}, onReleased [{Get_ReleaseReasonsText()}], onExhausted {_ExhaustedCount}, onEngaged {_EngagedCount}, holderChanges [{Get_HolderChangesText()}], refusalsRaised {_GripRefusals.Num()}, finished {_FinishedResults.Num()}, roots {Count_RootsNearBed()}, ensures {Get_NewEnsures()}";
    }

    private void Sample_Pull()
    {
        if (Get_Engagements() == 0)
        { _MaxStretchBeforeEngage = Math::Max(_MaxStretchBeforeEngage, Get_Stretch()); }

        _EverClaimed = _EverClaimed || Get_IsClaimed();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Predicates
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Is_BedFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsBedFound());
    }

    UFUNCTION()
    protected void Is_BedAndStandInFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsBedFound() && Get_IsStandInFound());
    }

    // Reports every poll until this machine's grip has ended and its interaction finished.
    UFUNCTION()
    protected void Is_PulledUntilItEnds(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Pull();
        Send_PullReport(Get_FrameSeconds());

        auto Result = OutResult;
        Result.Set(_Control.Get_IsManipulating() == false && _FinishedResults.Num() > 0);
    }

    // Reports every poll until this machine's grip has been held _HoldSeconds (or ended).
    UFUNCTION()
    protected void Is_PulledAndHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Pull();
        Send_PullReport(Get_FrameSeconds());

        const auto Now = float64(System::GetGameTimeInSeconds());
        if (_GripSeenAt.IsSet() == false && _Control.Get_IsManipulating())
        { _GripSeenAt = Now; }

        auto Result = OutResult;
        if (_FinishedResults.Num() > 0)
        {
            Result.Set(true);
            return;
        }

        Result.Set(_GripSeenAt.IsSet() && Now - _GripSeenAt.GetValue() >= _HoldSeconds);
    }

    UFUNCTION()
    protected void Is_Harvested(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Forage) && _Forage.Get_IsExhausted());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnBedReleased(FCk_Handle_Forage InForage, FCk_Handle InWorldItem, EMars_Forage_ReleaseReason InReason)
    {
        _ReleaseReasons.Add(InReason);
        if (_ReleasedFrame < 0)
        { _ReleasedFrame = int64(utils_time::Get_FrameCounter()); }

        if (Get_IsServer() && ck::IsValid(InWorldItem))
        { Track_ForCleanup(InWorldItem); }
    }

    UFUNCTION()
    private void OnBedExhausted(FCk_Handle_Forage InForage)
    {
        _ExhaustedCount += 1;
    }

    UFUNCTION()
    private void OnBedGripHolderChanged(FCk_Handle_Control InControl, EMars_Control_GripHolder InPrevious, EMars_Control_GripHolder InHolder)
    {
        auto Change = FMars_AutoTestHelper_TurnipHolderChange();
        Change.Previous = InPrevious;
        Change.Holder = InHolder;
        _HolderChanges.Add(Change);
    }

    // As the player's grip task's finish: the finish ends the grip (nothing after the threshold).
    UFUNCTION()
    private void OnBedInteractionFinished(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        if (InResult == ECk_SucceededFailed::Succeeded && _ThresholdFrame < 0)
        { _ThresholdFrame = int64(utils_time::Get_FrameCounter()); }

        _Control.Request_EndManipulation(FMars_Request_Control_EndManipulation());
    }
}
