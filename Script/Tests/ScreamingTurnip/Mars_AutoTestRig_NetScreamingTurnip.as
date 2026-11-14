// One recorded grip holder change, as the bed's Control raised it on this machine.
struct FMars_AutoTestHelper_TurnipHolderChange
{
    EMars_Control_GripHolder Previous = EMars_Control_GripHolder::Nobody;
    EMars_Control_GripHolder Holder = EMars_Control_GripHolder::Nobody;
}

// One recorded OnPhaseChanged of a root, with the frame it was raised in.
struct FMars_AutoTestHelper_NetTurnipPhase
{
    EMars_ScreamingTurnip_Phase Previous = EMars_ScreamingTurnip_Phase::Dormant;
    EMars_ScreamingTurnip_Phase New = EMars_ScreamingTurnip_Phase::Dormant;
    int64 Frame = 0;
}

// One recorded OnPlacementChanged of a root.
struct FMars_AutoTestHelper_NetTurnipPlacement
{
    EMars_ScreamingTurnip_Placement Previous = EMars_ScreamingTurnip_Placement::Loose;
    EMars_ScreamingTurnip_Placement New = EMars_ScreamingTurnip_Placement::Loose;
    int64 Frame = 0;
}

// One recorded OnScreamCommitted of a root, with the placement the copy read when it was raised.
struct FMars_AutoTestHelper_NetTurnipScream
{
    int32 Sequence = 0;
    FVector Position = FVector::ZeroVector;
    EMars_ScreamingTurnip_Placement Placement = EMars_ScreamingTurnip_Placement::Loose;
    int64 Frame = 0;
}

// One root a row spawned: where, this machine's copy once found, and what that copy raised from then on.
struct FMars_AutoTestHelper_NetTurnipRoot
{
    FVector SpawnPlace = FVector::ZeroVector;
    FCk_Handle_ScreamingTurnip Turnip;
    TArray<FMars_AutoTestHelper_NetTurnipPhase> Phases;
    TArray<FMars_AutoTestHelper_NetTurnipPlacement> Placements;
    TArray<FMars_AutoTestHelper_NetTurnipScream> Screams;
    // The ledger as the last sample saw it, and how many changes the samples saw.
    TOptional<FMars_Fragment_ScreamingTurnip_Net> SampledLedger;
    int32 LedgerChanges = 0;
}

// What Compose_TurnipCarrier built on the subject.
struct FMars_TESTONLY_NetTurnipCarrier
{
    FCk_Handle_Transform Hand;
    FCk_Handle_Transform Back;
    FCk_Handle_Hotbar Hotbar;
    FCk_Handle_HeldItem HeldItem;
    FCk_Handle_HeldItemUse Use;
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

    //----------------------------------------------------------------------------------------------------------------------
    // Released roots on a floor
    //----------------------------------------------------------------------------------------------------------------------
    // The rows below lay the server's static floor with its top at the row's location (Begin_TurnipTest's), spawn
    // World-mode roots 20 cm above it under the replicated spawn owner, and find each machine's copy by where it was
    // spawned. A row that holds a root composes a carrier on the subject on both machines (a hand, a Back node, one bag
    // slot).

    protected const float64 k_TurnipFloorHalfExtent = 800.0;
    protected const FVector k_BackFromHand = FVector(-30.0, 0.0, 20.0);
    protected const float64 k_RootFindRadius = 300.0;

    protected TArray<FMars_AutoTestHelper_NetTurnipRoot> _Roots;
    protected FMars_TESTONLY_NetTurnipCarrier _TurnipCarrier;

    // One scream every 4.5 s on a resting root.
    protected FMars_ScreamingTurnip_Vocal Make_NetVocal() const
    {
        auto Vocal = FMars_ScreamingTurnip_Vocal();
        Vocal.AnticipateSeconds = 0.5f;
        Vocal.InhaleSeconds = 1.0f;
        Vocal.ScreamSeconds = 0.5f;
        Vocal.RecoverSeconds = 0.5f;
        Vocal.CooldownSeconds = 3.0f;
        return Vocal;
    }

    protected FMars_ScreamingTurnip_Vocal Make_LongInhaleVocal() const
    {
        auto Vocal = Make_NetVocal();
        Vocal.InhaleSeconds = 15.0f;
        return Vocal;
    }

    protected FMars_ScreamingTurnip_Vocal Make_LongAnticipateVocal() const
    {
        auto Vocal = Make_NetVocal();
        Vocal.AnticipateSeconds = 15.0f;
        return Vocal;
    }

    // Server: a static floor whose top is the row's location, under the test's entity.
    protected void Spawn_ServerTurnipFloor()
    {
        auto Slab = utils_entity_lifetime::Request_CreateEntity(_TestHandle);
        utils_transform::Add(Slab, FTransform(FRotator::ZeroRotator, _BedLocation - FVector(0.0, 0.0, 10.0)), ECk_Replication::DoesNotReplicate);

        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(k_TurnipFloorHalfExtent, k_TurnipFloorHalfExtent, 10.0));
        auto SlabSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        SlabSpec.Set_ShapeDimensions(Shape);
        SlabSpec.Set_MotionType(ECk_MotionType::Static);
        SlabSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Slab, SlabSpec);
    }

    // Both machines: the root a row will find at InOffset from its location; returns its index.
    protected int32 Expect_Root(FVector InOffset)
    {
        auto Root = FMars_AutoTestHelper_NetTurnipRoot();
        Root.SpawnPlace = _BedLocation + InOffset;
        _Roots.Add(Root);
        return _Roots.Num() - 1;
    }

    // Server: the root InIndex names, 20 cm above the floor, under the replicated spawn owner, tracked for cleanup.
    protected void Spawn_ServerRoot(int32 InIndex, FMars_ScreamingTurnip_Vocal InVocal)
    {
        auto Params = UMars_ScreamingTurnip_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Roots[InIndex].SpawnPlace + FVector(0.0, 0.0, 20.0));
        Params.Definition = mars_items::ScreamingTurnip();
        Params.Mode = EMars_WorldItem_Mode::World;
        Params.Vocal = InVocal;

        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Pending = utils_world_item::Request_SpawnWorldEntity(Owner, UMars_ScreamingTurnip_EntityScript, Params);
        Track_ForCleanup(Pending.Get_EntityUnderConstruction());
    }

    // Both machines: a hand node at InHandLocation and a Back node behind and above it, their attach points, a hotbar
    // of one bag slot (no backpack slot), HeldItem and HeldItemUse, on the subject.
    protected void Compose_TurnipCarrier(FVector InHandLocation)
    {
        auto Subject = Get_SubjectEntity();

        auto HandEntity = utils_entity_lifetime::Request_CreateEntity(Subject);
        _TurnipCarrier.Hand = utils_transform::Add(HandEntity, FTransform(FRotator::ZeroRotator, InHandLocation), ECk_Replication::DoesNotReplicate);

        auto BackEntity = utils_entity_lifetime::Request_CreateEntity(Subject);
        _TurnipCarrier.Back = utils_transform::Add(BackEntity, FTransform(FRotator::ZeroRotator, InHandLocation + k_BackFromHand),
            ECk_Replication::DoesNotReplicate);

        auto Points = FMars_AttachPoints_Spec();
        Points.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Hand, _TurnipCarrier.Hand));
        Points.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Back, _TurnipCarrier.Back));
        utils_attach_points::Add(Subject, Points);

        auto HotbarSpec = FMars_Hotbar_Spec();
        HotbarSpec.BagSlotCount = 1;
        HotbarSpec.BackpackSlot = ECk_EnableDisable::Disable;
        _TurnipCarrier.Hotbar = utils_hotbar::Add(Subject, HotbarSpec);
        _TurnipCarrier.HeldItem = utils_held_item::Add(Subject);
        _TurnipCarrier.Use = utils_held_item_use::Add(Subject);
    }

    // This machine's copy of root InIndex: the World-mode world item within k_RootFindRadius of its spawn place in X
    // and Y that is a ScreamingTurnip. The first time, its three signals are recorded from here.
    protected bool Get_IsRootFound(int32 InIndex)
    {
        if (ck::IsValid(_Roots[InIndex].Turnip))
        { return true; }

        const auto Place = _Roots[InIndex].SpawnPlace;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            auto WorldItem = Candidate.As_WorldItem(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(WorldItem) || WorldItem.Get_Mode() != EMars_WorldItem_Mode::World || Candidate.Is_ScreamingTurnip() == false)
            { continue; }

            const auto Location = utils_transform::Get_EntityCurrentTransform(Candidate.As_Transform()).GetLocation();
            if (FVector2D(Location.X - Place.X, Location.Y - Place.Y).Size() >= k_RootFindRadius)
            { continue; }

            auto Turnip = Candidate.As_ScreamingTurnip();
            _Roots[InIndex].Turnip = Turnip;
            Turnip.BindTo_OnPhaseChanged(FMars_Delegate_ScreamingTurnip_OnPhaseChanged(this, n"OnRootPhaseChanged"));
            Turnip.BindTo_OnPlacementChanged(FMars_Delegate_ScreamingTurnip_OnPlacementChanged(this, n"OnRootPlacementChanged"));
            Turnip.BindTo_OnScreamCommitted(FMars_Delegate_ScreamingTurnip_OnScreamCommitted(this, n"OnRootScreamCommitted"));
            return true;
        }

        return false;
    }

    // A copy the server may already have destroyed: callers return quietly when it is gone.
    protected bool Get_IsRootGone(int32 InIndex)
    {
        FCk_Handle Entity = _Roots[InIndex].Turnip;
        return ck::Is_NOT_Valid(Entity) || utils_entity_lifetime::Get_IsPendingDestroy(Entity, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
    }

    protected FCk_Handle_WorldItem Get_RootWorldItem(int32 InIndex)
    {
        FCk_Handle Entity = _Roots[InIndex].Turnip;
        return Entity.As_WorldItem(ECk_SanityCheck::UnChecked);
    }

    protected FVector Get_TurnipRootLocation(int32 InIndex)
    {
        FCk_Handle Entity = _Roots[InIndex].Turnip;
        return utils_transform::Get_EntityCurrentTransform(Entity.As_Transform()).GetLocation();
    }

    // The ledger on this machine's copy; unset while it has none.
    protected TOptional<FMars_Fragment_ScreamingTurnip_Net> TryGet_Ledger(int32 InIndex)
    {
        if (Get_IsRootGone(InIndex) || _Roots[InIndex].Turnip.Has_Fragment(FMars_Fragment_ScreamingTurnip_Net) == false)
        { return TOptional<FMars_Fragment_ScreamingTurnip_Net>(); }

        return TOptional<FMars_Fragment_ScreamingTurnip_Net>(_Roots[InIndex].Turnip.Get_Fragment(FMars_Fragment_ScreamingTurnip_Net));
    }

    // Whether the ledger matches this machine's state and settle fragments, field for field.
    protected bool Get_IsLedgerTheState(int32 InIndex)
    {
        const auto Ledger = TryGet_Ledger(InIndex);
        if (Ledger.IsSet() == false)
        { return false; }

        auto Turnip = _Roots[InIndex].Turnip;
        const auto Value = Ledger.GetValue();
        const auto Support = Turnip.Get_HasSupport() ? EMars_ScreamingTurnip_Support::Supported : EMars_ScreamingTurnip_Support::Unsupported;
        return Value.Placement == Turnip.Get_Placement() && Value.Phase == Turnip.Get_Phase() && Value.Support == Support
            && Value.ScreamSequence == Turnip.Get_ScreamSequence() && Value.ScreamPosition.Equals(Turnip.Get_LastScreamPosition(), 0.0);
    }

    // Call once per frame from a predicate: counts the ledger changes this machine sees.
    protected void Sample_Ledger(int32 InIndex)
    {
        const auto Ledger = TryGet_Ledger(InIndex);
        if (Ledger.IsSet() == false)
        { return; }

        const auto Value = Ledger.GetValue();
        const auto& Sampled = _Roots[InIndex].SampledLedger;
        const auto Changed = Sampled.IsSet() == false || Sampled.GetValue().Placement != Value.Placement || Sampled.GetValue().Phase != Value.Phase
            || Sampled.GetValue().Support != Value.Support || Sampled.GetValue().ScreamSequence != Value.ScreamSequence
            || Sampled.GetValue().ScreamPosition.Equals(Value.ScreamPosition, 0.0) == false;
        if (Changed == false)
        { return; }

        _Roots[InIndex].SampledLedger = Ledger;
        _Roots[InIndex].LedgerChanges += 1;
    }

    // Server: the subject picks root InIndex up. Get_IsReadyToPickUp must hold.
    protected void Request_ServerPickUp(int32 InIndex)
    {
        auto WorldItem = Get_RootWorldItem(InIndex);
        WorldItem.Request_PickUp(FMars_Request_WorldItem_PickUp(Get_SubjectEntity()));
    }

    // The root is linked and holds its item, and the carrier's hotbar is ready on this machine.
    protected bool Get_IsReadyToPickUp(int32 InIndex)
    {
        if (Get_IsRootFound(InIndex) == false || Get_IsRootGone(InIndex))
        { return false; }

        auto WorldItem = Get_RootWorldItem(InIndex);
        return ck::IsValid(WorldItem) && WorldItem.Get_IsLinked() && ck::IsValid(WorldItem.Get_HeldItem())
            && ck::IsValid(_TurnipCarrier.Hotbar) && _TurnipCarrier.Hotbar.Get_IsReady();
    }

    // Server: no slot selected, so a held root is stowed.
    protected void Request_ServerClearSelection()
    {
        _TurnipCarrier.Hotbar.Request_SetSelection(FMars_Request_Hotbar_SetSelection(TOptional<int32>()));
    }

    // Server: the held root InIndex is let go with InVelocity.
    protected void Request_ServerRelease(int32 InIndex, FVector InVelocity)
    {
        auto WorldItem = Get_RootWorldItem(InIndex);
        WorldItem.Request_Release(FMars_Request_WorldItem_Release(InVelocity, FVector::ZeroVector));
    }

    protected bool Get_IsRootIn(int32 InIndex, EMars_ScreamingTurnip_Placement InPlacement)
    {
        return Get_IsRootFound(InIndex) && Get_IsRootGone(InIndex) == false && _Roots[InIndex].Turnip.Get_Placement() == InPlacement;
    }

    protected bool Get_IsRootPhase(int32 InIndex, EMars_ScreamingTurnip_Phase InPhase)
    {
        return Get_IsRootFound(InIndex) && Get_IsRootGone(InIndex) == false && _Roots[InIndex].Turnip.Get_Phase() == InPhase;
    }

    protected int32 Get_RootSequence(int32 InIndex)
    {
        if (Get_IsRootFound(InIndex) == false || Get_IsRootGone(InIndex))
        { return 0; }

        return _Roots[InIndex].Turnip.Get_ScreamSequence();
    }

    // The age of the copy's phase on its own clock.
    protected float32 Get_PhaseAge(int32 InIndex)
    {
        const auto& State = _Roots[InIndex].Turnip.Get_Fragment(FMars_Fragment_ScreamingTurnip);
        return State.Clock - State.PhaseStartedAt;
    }

    protected int32 Get_SignalCount(int32 InIndex) const
    {
        const auto& Root = _Roots[InIndex];
        return Root.Phases.Num() + Root.Placements.Num() + Root.Screams.Num();
    }

    // The cycle's next phase after InPhase; unset for Dormant, which is no part of it.
    protected TOptional<EMars_ScreamingTurnip_Phase> TryGet_CycleNext(EMars_ScreamingTurnip_Phase InPhase) const
    {
        switch (InPhase)
        {
            case EMars_ScreamingTurnip_Phase::Anticipate: { return TOptional<EMars_ScreamingTurnip_Phase>(EMars_ScreamingTurnip_Phase::Inhale); }
            case EMars_ScreamingTurnip_Phase::Inhale: { return TOptional<EMars_ScreamingTurnip_Phase>(EMars_ScreamingTurnip_Phase::Scream); }
            case EMars_ScreamingTurnip_Phase::Scream: { return TOptional<EMars_ScreamingTurnip_Phase>(EMars_ScreamingTurnip_Phase::Recover); }
            case EMars_ScreamingTurnip_Phase::Recover: { return TOptional<EMars_ScreamingTurnip_Phase>(EMars_ScreamingTurnip_Phase::RecoveryIdle); }
            case EMars_ScreamingTurnip_Phase::RecoveryIdle: { return TOptional<EMars_ScreamingTurnip_Phase>(EMars_ScreamingTurnip_Phase::Anticipate); }
            default: { break; }
        }

        return TOptional<EMars_ScreamingTurnip_Phase>();
    }

    // The index of the first recorded entry into InPhase at or after InFrom; -1 when none.
    protected int32 Find_PhaseEntry(int32 InIndex, EMars_ScreamingTurnip_Phase InPhase, int32 InFrom) const
    {
        const auto& Phases = _Roots[InIndex].Phases;
        for (int32 Entry = Math::Max(InFrom, 0); Entry < Phases.Num(); ++Entry)
        {
            if (Phases[Entry].New == InPhase)
            { return Entry; }
        }

        return -1;
    }

    // Each recorded entry from the first into InFirst on is the cycle's next after the one before it; false when there
    // is no entry into InFirst.
    protected bool Get_IsInCycleOrderFrom(int32 InIndex, EMars_ScreamingTurnip_Phase InFirst) const
    {
        const auto& Phases = _Roots[InIndex].Phases;
        const auto First = Find_PhaseEntry(InIndex, InFirst, 0);
        if (First < 0)
        { return false; }

        for (int32 Entry = First + 1; Entry < Phases.Num(); ++Entry)
        {
            const auto Next = TryGet_CycleNext(Phases[Entry - 1].New);
            if (Next.IsSet() == false || Next.GetValue() != Phases[Entry].New)
            { return false; }
        }

        return true;
    }

    protected int32 Count_PhaseEntries(int32 InIndex, EMars_ScreamingTurnip_Phase InPhase, int32 InFrom) const
    {
        auto Count = 0;
        const auto& Phases = _Roots[InIndex].Phases;
        for (int32 Entry = Math::Max(InFrom, 0); Entry < Phases.Num(); ++Entry)
        {
            if (Phases[Entry].New == InPhase)
            { Count += 1; }
        }

        return Count;
    }

    protected bool Get_HasScreamWhile(int32 InIndex, EMars_ScreamingTurnip_Placement InPlacement) const
    {
        for (const auto& Scream : _Roots[InIndex].Screams)
        {
            if (Scream.Placement == InPlacement)
            { return true; }
        }

        return false;
    }

    // What every log line of a root carries.
    protected FString Get_RootText(int32 InIndex)
    {
        if (Get_IsRootGone(InIndex))
        { return f"root {InIndex} gone, ensures {Get_NewEnsures()}"; }

        auto Turnip = _Roots[InIndex].Turnip;
        auto WorldItem = Get_RootWorldItem(InIndex);
        const auto Ledger = TryGet_Ledger(InIndex);
        auto LedgerText = FString("none");
        if (Ledger.IsSet())
        {
            const auto Value = Ledger.GetValue();
            LedgerText = f"{Value.Placement :n}/{Value.Phase :n}/{Value.Support :n}/{Value.ScreamSequence}/{Value.ScreamPosition.ToString()}";
        }

        auto PhasesText = FString();
        for (const auto& Phase : _Roots[InIndex].Phases)
        { PhasesText += f"{Phase.New :n}@{Phase.Frame} "; }

        auto ScreamsText = FString();
        for (const auto& Scream : _Roots[InIndex].Screams)
        { ScreamsText += f"{Scream.Sequence}({Scream.Placement :n})@{Scream.Frame} "; }

        return f"root {InIndex} authority {utils_net::Get_HasAuthority(Turnip)}, placement {Turnip.Get_Placement() :n}, phase {Turnip.Get_Phase() :n}, support {Turnip.Get_HasSupport()}, sequence {Turnip.Get_ScreamSequence()}, ledger [{LedgerText}], ledgerChanges {_Roots[InIndex].LedgerChanges}, mount {WorldItem.Get_Mount() :n}, body {ck::IsValid(WorldItem.Get_Body())}, phases [{PhasesText}], screams [{ScreamsText}], ensures {Get_NewEnsures()}";
    }

    private int32 Find_RootOf(FCk_Handle_ScreamingTurnip InTurnip) const
    {
        for (int32 Index = 0; Index < _Roots.Num(); ++Index)
        {
            if (_Roots[Index].Turnip == InTurnip)
            { return Index; }
        }

        return -1;
    }

    UFUNCTION()
    private void OnRootPhaseChanged(FCk_Handle_ScreamingTurnip InTurnip, EMars_ScreamingTurnip_Phase InPrevious, EMars_ScreamingTurnip_Phase InNew)
    {
        const auto Index = Find_RootOf(InTurnip);
        if (Index < 0)
        { return; }

        auto Entry = FMars_AutoTestHelper_NetTurnipPhase();
        Entry.Previous = InPrevious;
        Entry.New = InNew;
        Entry.Frame = int64(utils_time::Get_FrameCounter());
        _Roots[Index].Phases.Add(Entry);
    }

    UFUNCTION()
    private void OnRootPlacementChanged(FCk_Handle_ScreamingTurnip InTurnip, EMars_ScreamingTurnip_Placement InPrevious,
                                        EMars_ScreamingTurnip_Placement InNew)
    {
        const auto Index = Find_RootOf(InTurnip);
        if (Index < 0)
        { return; }

        auto Entry = FMars_AutoTestHelper_NetTurnipPlacement();
        Entry.Previous = InPrevious;
        Entry.New = InNew;
        Entry.Frame = int64(utils_time::Get_FrameCounter());
        _Roots[Index].Placements.Add(Entry);
    }

    UFUNCTION()
    private void OnRootScreamCommitted(FCk_Handle_ScreamingTurnip InTurnip, int32 InSequence, FVector InWorldPosition)
    {
        const auto Index = Find_RootOf(InTurnip);
        if (Index < 0)
        { return; }

        auto Entry = FMars_AutoTestHelper_NetTurnipScream();
        Entry.Sequence = InSequence;
        Entry.Position = InWorldPosition;
        Entry.Placement = InTurnip.Get_Placement();
        Entry.Frame = int64(utils_time::Get_FrameCounter());
        _Roots[Index].Screams.Add(Entry);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Root predicates (row-specific ones live in the rows)
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Is_RootFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsRootFound(0));
    }

    UFUNCTION()
    protected void Is_RootReadyToPickUp(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsReadyToPickUp(0));
    }
}
