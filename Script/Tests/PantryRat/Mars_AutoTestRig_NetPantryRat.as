// One phase change a machine's copy of the rat raised, with its frame.
struct FMars_NetRatTest_Change
{
    UPROPERTY()
    EMars_PantryRat_Phase From = EMars_PantryRat_Phase::Emerge;

    UPROPERTY()
    EMars_PantryRat_Phase To = EMars_PantryRat_Phase::Emerge;

    UPROPERTY()
    int32 Frame = -1;
}

// One application of the rat's ledger on a copy, with its frame and the phase the ledger then read.
struct FMars_NetRatTest_Application
{
    UPROPERTY()
    EMars_PantryRat_Phase Phase = EMars_PantryRat_Phase::Emerge;

    UPROPERTY()
    int32 Frame = -1;
}

enum EMars_NetRatTest_UntilKind
{
    // The rat reads Phase now.
    ReadsPhase,
    // Phase is among the changes this machine recorded.
    RecordedPhase,
    // The rat stands more than Cm (planar) from where this machine found it.
    MovedFarther,
    // This machine's rat is gone.
    Gone,
    // This machine's rat is gone and its raid holds no rat record.
    GoneAndUnrecorded
}

// What a row waits for on its rat, and for how long at most (unset: until the row's own deadline).
struct FMars_NetRatTest_Until
{
    UPROPERTY()
    EMars_NetRatTest_UntilKind Kind = EMars_NetRatTest_UntilKind::ReadsPhase;

    UPROPERTY()
    EMars_PantryRat_Phase Phase = EMars_PantryRat_Phase::Emerge;

    UPROPERTY()
    float64 Cm = 0.0;

    UPROPERTY()
    TOptional<float32> MaxSeconds;
}

// The pantry rat net tests' shared steps, on top of the raid's rig. The court is the raid's (floor, built field, raid,
// den, a pack with a Monk's Rind in cargo slot 1); the born court is the floor, a raid with no field (never ready, so
// it emerges nothing) and a den with one resident, beside which the server spawns a born rat under its raid. Each
// machine finds its rat nearest the den's spot and records from then on: every OnPhaseChanged with its frame,
// OnClaimResolved and the monster's OnDied, and on a client every application of the rat's ledger (through its own
// rep-notify). Every rig predicate and sampling wait samples the rat each frame: its steps, how far it went, the
// script's measured speed and clips, its fade while it enters its den, whether it was hidden.
UCLASS(Abstract)
class UMars_AutoTestRig_NetPantryRat : UMars_AutoTestRig_NetPantryRaid
{
    default _TimeoutSeconds = 28.0f;

    // A born rat stands this far from its den's spot.
    protected const FVector k_BornFromDen = FVector(75.0, 0.0, 0.0);
    // A rat is found within this of its den's spot.
    protected const float64 k_RatNearDenCm = 700.0;
    protected const int32 k_BornOperationId = 7;

    // Each machine: its rat, and what it recorded of it.
    protected FCk_Handle_PantryRat _RowRat;
    protected int32 _RatFoundFrame = -1;
    protected FVector _RatFoundAt = FVector::ZeroVector;
    protected EMars_Net_InitialState _RatFoundInitialState = EMars_Net_InitialState::Awaited;
    protected TArray<FMars_NetRatTest_Change> _RatChanges;
    protected TArray<FMars_NetRatTest_Application> _RatApplications;
    protected int32 _RatClaimSignals = 0;
    protected int32 _RatDiedSignals = 0;
    protected int32 _RatGoneFrame = -1;

    // Each machine: the samples.
    protected float64 _RatLargestStep = 0.0;
    protected float64 _RatFarthest = 0.0;
    protected float32 _RatHighestSpeed = 0.0f;
    protected TArray<FName> _RatClipsSeen;
    protected TOptional<float32> _RatDenEnterLowestFade;
    protected TOptional<float32> _RatDenEnterHighestFade;
    // While DenEnter: a sample read fully solid, and a later one read below one half.
    protected bool _RatDenEnterSawSolid = false;
    protected bool _RatDenEnterSawFadedAfterSolid = false;
    protected bool _RatHiddenInDenEnter = false;
    protected bool _RatSawHidden = false;
    protected float32 _RatFadeWhenHidden = -1.0f;
    protected bool _RatSawDormant = false;
    protected int32 _RatTakenFrame = -1;
    // Server: the frames its ledger's phase was first read different from the one before, as sampled.
    protected int32 _RatLedgerChangesSampled = 0;
    protected int32 _RatLedgerDenEnterFrame = -1;
    protected int32 _BornSpawnFrame = -1;

    private TOptional<FVector> _RatLastSample;
    private TOptional<EMars_PantryRat_Phase> _RatLastLedgerSample;
    private FMars_NetRatTest_Until _RatUntil;
    private float64 _RatUntilDeadline = 0.0;
    private FMars_PantryRaid_Spec _CourtSpec;
    private FName _CourtContinuation;

    //------------------------------------------------------------------------------------------------------------------
    // Server: the court and the born court
    //------------------------------------------------------------------------------------------------------------------

    // The raid's court with InSpec, through its waits in order (the spawn owner, the floor, the field's build, the pack
    // and the cheese, the stow), until its first rat is out and found; then InContinuation.
    protected void Begin_ServerRatCourt(FMars_PantryRaid_Spec InSpec, FName InContinuation)
    {
        _CourtSpec = InSpec;
        _CourtContinuation = InContinuation;
        WaitUntil(n"Is_RowSpawnOwnerPublished", n"OnRatCourtOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnRatCourtOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerCourt(_CourtSpec);
        WaitUntil(n"Is_RowFloorJoined", n"OnRatCourtFloorJoined", k_SlowPolls);
    }

    UFUNCTION()
    private void OnRatCourtFloorJoined(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerFieldBuild();
        WaitUntil(n"Is_RowPackAndCheeseReady", n"OnRatCourtPackReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnRatCourtPackReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerStowCheese();
        WaitUntil(n"Is_RowCheeseStowed", n"OnRatCourtStowed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnRatCourtStowed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_RowRatOutAndFound", _CourtContinuation, k_SlowPolls);
    }

    UFUNCTION()
    protected void Is_RowRatOutAndFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Out = ck::IsValid(Get_RowFirstRat()) && Get_IsRowRatFound();
        Sample_Row();
        auto Result = OutResult;
        Result.Set(Out);
    }

    // The floor, a raid with InSpec and no field, a den with one resident, through their waits in order (the spawn
    // owner, the floor, the raid and the den found); then InContinuation, which spawns the born rat.
    protected void Begin_ServerBornCourt(FMars_PantryRaid_Spec InSpec, FName InContinuation)
    {
        _CourtSpec = InSpec;
        _CourtContinuation = InContinuation;
        WaitUntil(n"Is_RowSpawnOwnerPublished", n"OnBornCourtOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnBornCourtOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerFloor();
        Spawn_ServerRaid(_CourtSpec);
        Spawn_ServerDen(1);
        WaitUntil(n"Is_RowFloorJoined", n"OnBornCourtFloorJoined", k_SlowPolls);
    }

    UFUNCTION()
    private void OnBornCourtFloorJoined(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_RowRaidAndDenFound", _CourtContinuation, k_SlowPolls);
    }

    // The born rat under the server's raid (the owner production spawns its rats under), at the den's spot plus
    // k_BornFromDen facing +X, its links the raid and the den, slot 0; it advances through InBornThrough as it
    // composes.
    protected void Spawn_ServerBornRat(TArray<EMars_PantryRat_Phase> InBornThrough, FMars_PantryRat_Tuning InTuning)
    {
        auto Spec = FMars_PantryRat_Spec();
        Spec.Links.Raid = _RowRaid;
        Spec.Links.Den = _RowDen;
        Spec.Links.ResidentSlot = 0;
        Spec.Links.OperationId = k_BornOperationId;
        Spec.Tuning = InTuning;

        auto Params = FMars_NetPantryRat_Born_SpawnParams();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _DenSpot + k_BornFromDen);
        Params.Spec = Spec;
        Params.BornThrough = InBornThrough;

        FCk_Handle Owner = _RowRaid;
        Track_ForCleanup(utils_entity_script::Request_SpawnEntity(Owner, UMars_NetPantryRat_Born_EntityScript, Params).Get_EntityUnderConstruction());
        _BornSpawnFrame = int32(utils_time::Get_FrameCounter());
    }

    //------------------------------------------------------------------------------------------------------------------
    // Each machine: its rat
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Is_RowRatFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Get_IsRowRaidFound();
        Get_IsRowDenFound();
        const auto Found = Get_IsRowRatFound();
        Sample_Row();
        auto Result = OutResult;
        Result.Set(Found);
    }

    // The entity tagged as a rat nearest the den's spot, within k_RatNearDenCm, that is a pantry rat and not ending;
    // the first time, what it raises is recorded from here.
    protected bool Get_IsRowRatFound()
    {
        if (_RatFoundFrame >= 0)
        { return true; }

        auto Found = FCk_Handle();
        auto Nearest = k_RatNearDenCm;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), utils_pantry_rat::RatTag))
        {
            if (Get_IsRowEnding(Candidate) || Candidate.Is_PantryRat() == false)
            { continue; }

            const auto Distance = (Get_RowRootLocation(Candidate) - _DenSpot).Size();
            if (Distance >= Nearest)
            { continue; }

            Found = Candidate;
            Nearest = Distance;
        }

        if (ck::Is_NOT_Valid(Found))
        { return false; }

        _RowRat = Found.As_PantryRat();
        _RatFoundFrame = int32(utils_time::Get_FrameCounter());
        _RatFoundAt = _RowRat.Get_Location();
        _RatFoundInitialState = Get_RowRatInitialState();
        _RowRat.BindTo_OnPhaseChanged(FMars_Delegate_PantryRat_OnPhaseChanged(this, n"OnRowRatPhaseChanged"));
        _RowRat.BindTo_OnClaimResolved(FMars_Delegate_PantryRat_OnClaimResolved(this, n"OnRowRatClaimResolved"));
        auto Monster = _RowRat.Get_Monster();
        Monster.BindTo_OnDied(FMars_Delegate_Monster_OnDied(this, n"OnRowRatDied"));
        if (Get_IsServer() == false)
        { Found.BindTo_OnRepNotify(FMars_Fragment_PantryRat_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnRowRatLedgerNotify")); }

        return true;
    }

    protected bool Get_IsRowRatGone()
    {
        return Get_IsRowEnding(_RowRat);
    }

    protected bool Get_HasRowRatLedger()
    {
        return Get_IsRowRatGone() == false && _RowRat.Has_Fragment(FMars_Fragment_PantryRat_Net);
    }

    // This machine's rat ledger; a default one without it.
    protected FMars_Fragment_PantryRat_Net Get_RowRatLedger()
    {
        if (Get_HasRowRatLedger() == false)
        { return FMars_Fragment_PantryRat_Net(); }

        return _RowRat.Get_Fragment(FMars_Fragment_PantryRat_Net);
    }

    protected bool Get_HasRowRatLocal()
    {
        return Get_IsRowRatGone() == false && _RowRat.Has_Fragment(FMars_Fragment_PantryRat_Local);
    }

    // This machine's copy's level; Awaited without one.
    protected EMars_Net_InitialState Get_RowRatInitialState()
    {
        if (Get_HasRowRatLocal() == false)
        { return EMars_Net_InitialState::Awaited; }

        return _RowRat.Get_Fragment(FMars_Fragment_PantryRat_Local).InitialState;
    }

    // The mirror's state on this machine's rat: set only without authority.
    protected bool Get_IsRowRatMirrorStateSet()
    {
        return Get_HasRowRatLocal() && _RowRat.Get_Fragment(FMars_Fragment_PantryRat_Local).Last.IsSet();
    }

    protected UMars_PantryRat_EntityScript Get_RowRatScript()
    {
        if (Get_IsRowRatGone() || _RowRat.Has_Fragment(FMars_Fragment_PantryRat_Assembly) == false)
        { return nullptr; }

        return _RowRat.Get_Fragment(FMars_Fragment_PantryRat_Assembly).Script.Get();
    }

    protected bool Get_HasRowRatStateMachine()
    {
        FCk_Handle Entity = _RowRat;
        return Get_IsRowRatGone() == false && ck::IsValid(Entity.As_StateMachine(ECk_SanityCheck::UnChecked));
    }

    protected bool Get_HasRowRatSurfaceNavigator()
    {
        FCk_Handle Entity = _RowRat;
        return Get_IsRowRatGone() == false && Entity.Is_SurfaceNavigator();
    }

    // raid: its lifetime owner is this machine's raid; other: another entity; none: no owner (or no rat).
    protected FString Get_RowRatOwnerText()
    {
        if (Get_IsRowRatGone())
        { return "none"; }

        FCk_Handle Entity = _RowRat;
        const auto Owner = Entity.Get_LifetimeOwner();
        if (ck::Is_NOT_Valid(Owner))
        { return "none"; }

        FCk_Handle RaidEntity = _RowRaid;
        return ck::IsValid(_RowRaid) && Owner == RaidEntity ? "raid" : "other";
    }

    //------------------------------------------------------------------------------------------------------------------
    // Each machine: the samples, and the rig's own waits
    //------------------------------------------------------------------------------------------------------------------

    protected void Sample_Row() override
    {
        if (_RatFoundFrame < 0)
        { return; }

        if (Get_IsRowRatGone())
        {
            if (_RatGoneFrame < 0)
            { _RatGoneFrame = int32(utils_time::Get_FrameCounter()); }

            return;
        }

        const auto Here = _RowRat.Get_Location();
        if (_RatLastSample.IsSet())
        { _RatLargestStep = Math::Max(_RatLargestStep, Get_PlanarDistance(Here, _RatLastSample.GetValue())); }

        _RatLastSample = Here;
        _RatFarthest = Math::Max(_RatFarthest, Get_PlanarDistance(Here, _RatFoundAt));

        const auto Script = Get_RowRatScript();
        if (ck::IsValid(Script))
        {
            _RatHighestSpeed = Math::Max(_RatHighestSpeed, Script.Get_MeasuredSpeed());
            const auto Clip = Script.Get_PlayingClip();
            if (Clip != NAME_None && _RatClipsSeen.Contains(Clip) == false)
            { _RatClipsSeen.Add(Clip); }
        }

        const auto Phase = _RowRat.Get_Phase();
        const auto Fade = _RowRat.Get_FadeAlpha();
        const auto Hidden = _RowRat.Get_IsHidden();
        if (Phase == EMars_PantryRat_Phase::DenEnter)
        {
            _RatDenEnterLowestFade = _RatDenEnterLowestFade.IsSet() ? Math::Min(_RatDenEnterLowestFade.GetValue(), Fade) : Fade;
            _RatDenEnterHighestFade = _RatDenEnterHighestFade.IsSet() ? Math::Max(_RatDenEnterHighestFade.GetValue(), Fade) : Fade;
            if (Fade >= 1.0f)
            { _RatDenEnterSawSolid = true; }
            else if (Fade < 0.5f && _RatDenEnterSawSolid)
            { _RatDenEnterSawFadedAfterSolid = true; }

            if (Hidden)
            { _RatHiddenInDenEnter = true; }
        }

        if (Hidden)
        {
            _RatSawHidden = true;
            _RatFadeWhenHidden = Fade;
        }

        if (Phase == EMars_PantryRat_Phase::DormantInDen)
        { _RatSawDormant = true; }

        if (Get_RowRatInitialState() == EMars_Net_InitialState::Taken && _RatTakenFrame < 0)
        { _RatTakenFrame = int32(utils_time::Get_FrameCounter()); }

        if (Get_HasRowRatLedger())
        {
            const auto LedgerPhase = Get_RowRatLedger().Phase;
            if (_RatLastLedgerSample.IsSet() && _RatLastLedgerSample.GetValue() != LedgerPhase)
            { ++_RatLedgerChangesSampled; }

            _RatLastLedgerSample = LedgerPhase;
            if (LedgerPhase == EMars_PantryRat_Phase::DenEnter && _RatLedgerDenEnterFrame < 0)
            { _RatLedgerDenEnterFrame = int32(utils_time::Get_FrameCounter()); }
        }
    }

    // Samples every frame until InUntil holds on this machine's rat (or its MaxSeconds pass), then InContinuation.
    protected void Wait_RowRatUntil(FMars_NetRatTest_Until InUntil, FName InContinuation)
    {
        _RatUntil = InUntil;
        _RatUntilDeadline = InUntil.MaxSeconds.IsSet() ? Get_RowWorldSeconds() + InUntil.MaxSeconds.GetValue() : 1.0e12;
        WaitUntil(n"Is_RowRatUntil", InContinuation, k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RowRatUntil(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Row();
        auto Result = OutResult;
        Result.Set(Get_IsRowRatUntil() || Get_RowWorldSeconds() >= _RatUntilDeadline);
    }

    private bool Get_IsRowRatUntil()
    {
        if (_RatUntil.Kind == EMars_NetRatTest_UntilKind::RecordedPhase)
        { return Get_IsRatRecorded(_RatUntil.Phase); }

        if (_RatUntil.Kind == EMars_NetRatTest_UntilKind::Gone)
        { return Get_IsRowRatGone(); }

        if (_RatUntil.Kind == EMars_NetRatTest_UntilKind::GoneAndUnrecorded)
        { return Get_IsRowRatGone() && Get_IsRowEnding(_RowRaid) == false && _RowRaid.Get_RatCount() == 0; }

        if (Get_IsRowRatGone())
        { return false; }

        if (_RatUntil.Kind == EMars_NetRatTest_UntilKind::MovedFarther)
        { return Get_PlanarDistance(_RowRat.Get_Location(), _RatFoundAt) > _RatUntil.Cm; }

        return _RowRat.Get_Phase() == _RatUntil.Phase;
    }

    protected FMars_NetRatTest_Until Make_RatUntil(EMars_NetRatTest_UntilKind InKind, EMars_PantryRat_Phase InPhase)
    {
        auto Until = FMars_NetRatTest_Until();
        Until.Kind = InKind;
        Until.Phase = InPhase;
        return Until;
    }

    //------------------------------------------------------------------------------------------------------------------
    // Each machine: the recorded changes
    //------------------------------------------------------------------------------------------------------------------

    protected bool Get_IsRatRecorded(EMars_PantryRat_Phase InPhase) const
    {
        for (const auto& Change : _RatChanges)
        {
            if (Change.To == InPhase)
            { return true; }
        }

        return false;
    }

    // InExpected appears among the recorded changes in this order (other phases may come between).
    protected bool Get_IsRatRecordedInOrder(const TArray<EMars_PantryRat_Phase>& InExpected) const
    {
        auto Next = 0;
        for (const auto& Change : _RatChanges)
        {
            if (Next < InExpected.Num() && Change.To == InExpected[Next])
            { ++Next; }
        }

        return Next == InExpected.Num();
    }

    // Each recorded change's From is the To of the one before.
    protected bool Get_IsRatRecordChained() const
    {
        for (auto Index = 1; Index < _RatChanges.Num(); ++Index)
        {
            if (_RatChanges[Index].From != _RatChanges[Index - 1].To)
            { return false; }
        }

        return true;
    }

    //------------------------------------------------------------------------------------------------------------------
    // The row's log line, its end
    //------------------------------------------------------------------------------------------------------------------

    protected void Log_RatRow(FString InRow, FString InExtra)
    {
        const auto Line = f"[RatNetTest] {InRow} {Get_MachineName()} {Describe_RowRat()} ratsHere={Count_RatsHere()} ensures={Get_NewEnsures()} frame={utils_time::Get_FrameCounter()} {InExtra}";
        Log(Line);
    }

    protected FString Describe_RowRat()
    {
        FString Changes;
        for (const auto& Change : _RatChanges)
        { Changes += f"{Change.From :n}>{Change.To :n}@{Change.Frame},"; }

        FString Applications;
        for (const auto& Application : _RatApplications)
        { Applications += f"{Application.Phase :n}@{Application.Frame},"; }

        FString Clips;
        for (const auto& Clip : _RatClipsSeen)
        { Clips += f"{Clip},"; }

        const auto LowFade = _RatDenEnterLowestFade.IsSet() ? f"{_RatDenEnterLowestFade.GetValue()}" : "unset";
        const auto HighFade = _RatDenEnterHighestFade.IsSet() ? f"{_RatDenEnterHighestFade.GetValue()}" : "unset";
        const auto Records = f"found@{_RatFoundFrame} gone@{_RatGoneFrame} born@{_BornSpawnFrame} ledgerDenEnter@{_RatLedgerDenEnterFrame} "
            + f"taken@{_RatTakenFrame} changes [{Changes}] applications [{Applications}] claims {_RatClaimSignals} "
            + f"died {_RatDiedSignals} ledgerChangesSampled {_RatLedgerChangesSampled} step {_RatLargestStep} "
            + f"farthest {_RatFarthest} speed {_RatHighestSpeed} clips [{Clips}] denEnterFade {LowFade}..{HighFade} "
            + f"solidThenFaded {_RatDenEnterSawSolid}/{_RatDenEnterSawFadedAfterSolid} hiddenInDenEnter {_RatHiddenInDenEnter} "
            + f"sawHidden {_RatSawHidden}:{_RatFadeWhenHidden} sawDormant {_RatSawDormant}";
        if (Get_IsRowRatGone())
        { return f"rat=[gone {Records}]"; }

        FCk_Handle Entity = _RowRat;
        const auto Authority = utils_net::Get_HasAuthority(Entity);
        const auto Links = _RowRat.Get_Links();
        const auto Script = Get_RowRatScript();
        auto ScriptLinks = "noScript";
        if (ck::IsValid(Script))
        { ScriptLinks = f"{ck::IsValid(Script.Spec.Links.Raid)}/{ck::IsValid(Script.Spec.Links.Den)}"; }

        const auto Loaded = _RowRat.Has_Fragment(FMars_Fragment_PantryRat_Params) ? f"{_RowRat.Get_IsLoaded()}" : "unknown";
        return f"rat=[authority {Authority} replicatesHere {utils_mars_net::Get_ReplicatesHere(Entity)} "
            + f"driver {utils_entity_replication_driver::Has(Entity)} owner {Get_RowRatOwnerText()} phase {_RowRat.Get_Phase() :n} "
            + f"ledger {Get_HasRowRatLedger()}:{Get_RowRatLedger().Phase :n} mirrorState {Get_IsRowRatMirrorStateSet()} "
            + f"initial {_RatFoundInitialState :n}/{Get_RowRatInitialState() :n} fade {_RowRat.Get_FadeAlpha()} "
            + f"hidden {_RowRat.Get_IsHidden()} navigator {ck::IsValid(_RowRat.Get_Navigator())} pocket {ck::IsValid(_RowRat.Get_Pocket())} "
            + f"raidLink {ck::IsValid(_RowRat.Get_Raid())} denLink {ck::IsValid(_RowRat.Get_Den())} scriptLinks {ScriptLinks} "
            + f"op {Links.OperationId} slot {Links.ResidentSlot} sm {Get_HasRowRatStateMachine()} "
            + f"surfaceNavigator {Get_HasRowRatSurfaceNavigator()} loaded {Loaded} phaseChanges {_RowRat.Get_PhaseChanges()} "
            + f"claimResult {_RowRat.Get_LastClaimResult() :n} transfers {_RowRat.Get_ClaimTransfersIssued()} {Records}]";
    }

    // The row's [RatNetTest] line, then the raid rig's finish.
    protected void Finish_RatRow(FString InRow, FString InExtra)
    {
        Log_RatRow(InRow, InExtra);
        Finish_PantryRow(InRow, "");
    }

    // Server: the row's [RatNetTest] line, then the raid rig's hold after its last write.
    protected void Hold_RatServerRow(FString InRow, FString InExtra)
    {
        Log_RatRow(InRow, InExtra);
        Hold_PantryServerRow(InRow, "");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Signals
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnRowRatPhaseChanged(FCk_Handle_PantryRat InRat, EMars_PantryRat_Phase InPrevious, EMars_PantryRat_Phase InNew)
    {
        auto Change = FMars_NetRatTest_Change();
        Change.From = InPrevious;
        Change.To = InNew;
        Change.Frame = int32(utils_time::Get_FrameCounter());
        _RatChanges.Add(Change);
    }

    UFUNCTION()
    private void OnRowRatClaimResolved(FCk_Handle_PantryRat InRat, EMars_PantryRat_ClaimResult InResult, FCk_Handle_Item InItem)
    {
        _RatClaimSignals += 1;
    }

    UFUNCTION()
    private void OnRowRatDied(FCk_Handle_Monster InMonster, FMars_DamageEvent InCause)
    {
        _RatDiedSignals += 1;
    }

    // An expected absence: a notify can land on a copy already ending.
    UFUNCTION()
    private void OnRowRatLedgerNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (Get_HasRowRatLedger() == false)
        { return; }

        auto Application = FMars_NetRatTest_Application();
        Application.Phase = Get_RowRatLedger().Phase;
        Application.Frame = int32(utils_time::Get_FrameCounter());
        _RatApplications.Add(Application);
    }
}
