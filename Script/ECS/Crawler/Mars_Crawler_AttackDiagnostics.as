// Read-only copied game observations for tools. These accessors never evaluate, select, acquire, or advance an attack.
struct FMars_Crawler_AttackDebugStream
{
    FCk_ProceduralAction_Identity Identity;
    int64 Cursor = 0;
    int64 AckSampleId = 0;
    int64 AckRevision = 0;
    int64 ContentRevision = 0;
    int64 TopologyRevision = 0;
}

struct FMars_Crawler_AttackDebugStatus
{
    bool WindowClosed = false;
    bool Obstructed = false;
    TOptional<EMars_Crawler_AttackCancel> Displaced;
    FName StreamFailure;
    bool StreamUnavailable = false;
    bool OffenseEnded = false;
    bool ActionStreamFailed = false;
}

struct FMars_Crawler_AttackAnatomyCapture
{
    int64 Frame = 0;
    TArray<FMars_Attack_RoleObservation> Roles;
    bool ArticulationValid = false;
    ECk_ProceduralArticulation_Health Health = ECk_ProceduralArticulation_Health::Operational;
    ECk_ProceduralArticulation_Fault Fault = ECk_ProceduralArticulation_Fault::None;
}

struct FMars_Crawler_AttackDebugLedger
{
    int64 StartSequence = 0;
    int64 EventSequence = 0;
}

struct FMars_Crawler_AttackDebugSnapshot
{
    int64 Frame = 0;
    FMars_Crawler_AttackDebugStream Stream;
    FMars_Crawler_AttackDebugStatus Status;
    FMars_Crawler_AttackCleanup Cleanup;
    TOptional<FMars_Crawler_HitCandidate> Candidate;
    FMars_Crawler_AttackAnatomyCapture Anatomy;
    FMars_Crawler_AttackDebugLedger Ledger;
}

mixin FMars_Crawler_AttackDebugSnapshot Get_AttackDebugSnapshot(const FCk_Handle_Crawler& Self)
{
    auto Snapshot = FMars_Crawler_AttackDebugSnapshot();
    FCk_Handle Entity = Self;
    if (ck::Is_NOT_Valid(Self) || utils_entity_lifetime::Get_IsPendingDestroy(Entity, ECk_EntityLifetime_DestructionPhase::BeginDestroy) ||
        Self.Get_IsCombatArmed() == false)
    { return Snapshot; }
    Snapshot.Frame = utils_time::Get_FrameCounter();
    const auto& Attack = Self.Get_Fragment(FMars_Fragment_Crawler_Attack);
    const auto& Observed = Self.Get_Fragment(FMars_Fragment_Crawler_AttackObservations);
    const auto& Selection = Self.Get_Fragment(FMars_Fragment_Crawler_AttackSelection);
    Snapshot.Stream.Identity = Attack.ActionIdentity;
    Snapshot.Stream.Cursor = Attack.ReceiptCursor;
    Snapshot.Stream.AckSampleId = Observed.AckSampleId;
    Snapshot.Stream.AckRevision = Observed.AckRevision;
    Snapshot.Stream.ContentRevision = Observed.ContentRevision;
    Snapshot.Stream.TopologyRevision = Observed.TopologyRevision;
    Snapshot.Status.WindowClosed = Attack.WindowClosed;
    Snapshot.Status.Obstructed = Observed.Obstructed;
    Snapshot.Status.Displaced = Observed.Displaced;
    Snapshot.Status.StreamFailure = Observed.StreamFailure;
    Snapshot.Status.StreamUnavailable = Observed.StreamUnavailable;
    Snapshot.Status.OffenseEnded = Observed.OffenseEnded;
    Snapshot.Status.ActionStreamFailed = Observed.ActionStreamFailed;
    Snapshot.Cleanup = Attack.Cleanup;
    Snapshot.Candidate = Observed.Candidate;
    Snapshot.Ledger.StartSequence = Selection.Ledger.StartSequence;
    Snapshot.Ledger.EventSequence = Selection.Ledger.EventSequence;
    Snapshot.Anatomy.Frame = Snapshot.Frame;
    const auto Articulation = Self.Get_Articulation();
    if (ck::IsValid(Articulation))
    {
        Snapshot.Anatomy.ArticulationValid = true;
        Snapshot.Anatomy.Health = Articulation.Get_Health();
        Snapshot.Anatomy.Fault = Articulation.Get_Fault();
    }
    for (const auto& Binding : Self.Get_Spec().ResolvedAttacks.Anatomy)
    { Snapshot.Anatomy.Roles.Add(utils_crawler::Capture_AttackRole(Self, Binding)); }
    return Snapshot;
}
