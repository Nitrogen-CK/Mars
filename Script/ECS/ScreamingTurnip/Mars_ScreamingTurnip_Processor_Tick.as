// Every frame, in order: the kernel clock advances by the frame's delta (a zero, negative or non-finite delta advances
// nothing at all); the placement is derived from the world item's mount and, on the World mount, from the body's settle
// sample; a placement change applies its rule to the warning; then, while the placement is Held or LooseSettled, the voice
// advances. Writes land first, then OnPlacementChanged, then OnPhaseChanged in order, then OnScreamCommitted.
//
// Placement: mount Held and settled -> Held; mount Held or Carried with a mount change in flight (a pending mount, an
// arrival, a pending release), or mount World with a pending mount (a pickup underway) -> Transfer; mount Carried and
// settled -> Protected; mount World -> Loose or LooseSettled from the settle sampler.
//
// Placement rules: entering Transfer freezes the warning (WarningElapsed kept, phase Dormant); entering Loose or Protected
// cancels it (WarningElapsed 0, phase Dormant), keeping the last commit and the sequence; entering Held or LooseSettled
// resumes the warning from WarningElapsed (a fresh one after a cancel), after whatever cooldown is left.
//
// Voice: Anticipate -> Inhale -> COMMIT at the first tick the Inhale is complete (the sequence, the commit time = this tick's
// clock, the world item's root copied) -> Scream -> Recover -> RecoveryIdle until LastScreamCommittedAt + Cooldown ->
// Anticipate. Every other phase boundary carries over (a phase that ends mid-tick starts the next with the remainder); the
// commit restarts the cycle from this tick, so a long hitch emits one scream and schedules the next from its actual commit.
//
// Order: after every WorldItem processor that changes what the placement reads (the release drain that adds the
// PendingRelease, the reconcile that adds a PendingMount, the mount commit, the arrival, the launch), so a mount change
// made in this frame's main pass is read by this frame's tick, never the next. A release drained in the main pass reads
// Transfer at once, so the tick that would have completed the Inhale commits nothing. Not covered: a mount change made in
// the scheduler's tail pump (the release's World commit answers an inventory transfer pumped after the main graph; a
// release requested from a processor that runs after the WorldItem drain is drained there too). This processor has no
// dirty marker and is not pumped, so it reads such a change on the next frame.
class UMars_Processor_ScreamingTurnip_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_ScreamingTurnip_HandleRequests");
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_WorldItem_HandleRequests");
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_WorldItem_Reconcile");
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_WorldItem_Mount");
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_WorldItem_Arrive");
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_WorldItem_Launch");

    // More than one full cycle's phase changes in one pass would need a commit, which ends the pass's advance anyway.
    private const int32 k_MaxPhaseSteps = 8;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_ScreamingTurnip);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_ScreamingTurnip_Params& InParams,
                       FMars_Fragment_ScreamingTurnip& InState,
                       FMars_Fragment_ScreamingTurnip_Settle& InSettle)
    {
        // Destruction wins over a deadline: an entity on its way out commits nothing.
        if (utils_world_item::Get_IsEnding(InHandle))
        { return; }

        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());
        if (Math::IsFinite(DeltaSeconds) == false || DeltaSeconds <= 0.0f)
        { return; }

        auto Self = InHandle.As_ScreamingTurnip();
        InState.Clock += DeltaSeconds;

        const auto PreviousPlacement = InState.Placement;
        const auto NewPlacement = Derive_Placement(Self, DeltaSeconds);

        TArray<EMars_ScreamingTurnip_Phase> PhaseTrail;
        PhaseTrail.Add(InState.Phase);

        if (NewPlacement != PreviousPlacement)
        {
            InState.Placement = NewPlacement;
            Apply_PlacementRule(InState, NewPlacement, PhaseTrail);
        }

        auto Committed = false;
        if (InState.SuspendPending)
        { InState.SuspendPending = false; }
        else if (utils_screaming_turnip::Get_IsEligible(NewPlacement))
        { Committed = Advance_Voice(Self, PhaseTrail); }

        const auto Sequence = InState.ScreamSequence;
        const auto Position = InState.LastWorldPosition;

        // InState and InSettle may move under a handler that composes on another entity: nothing below reads them.
        if (NewPlacement != PreviousPlacement && Self.Has_Fragment(FMars_Fragment_ScreamingTurnip_Signals))
        { Self.Get_Fragment(FMars_Fragment_ScreamingTurnip_Signals).OnPlacementChanged.Broadcast(Self, PreviousPlacement, NewPlacement); }

        for (int32 Index = 1; Index < PhaseTrail.Num(); ++Index)
        {
            if (Self.Has_Fragment(FMars_Fragment_ScreamingTurnip_Signals))
            { Self.Get_Fragment(FMars_Fragment_ScreamingTurnip_Signals).OnPhaseChanged.Broadcast(Self, PhaseTrail[Index - 1], PhaseTrail[Index]); }
        }

        if (Committed && Self.Has_Fragment(FMars_Fragment_ScreamingTurnip_Signals))
        { Self.Get_Fragment(FMars_Fragment_ScreamingTurnip_Signals).OnScreamCommitted.Broadcast(Self, Sequence, Position); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Placement
    //----------------------------------------------------------------------------------------------------------------------

    private EMars_ScreamingTurnip_Placement Derive_Placement(FCk_Handle_ScreamingTurnip& InSelf, float32 InDeltaSeconds)
    {
        const auto& Params = InSelf.Get_Fragment(FMars_Fragment_ScreamingTurnip_Params);
        const auto& State = InSelf.Get_Fragment(FMars_Fragment_ScreamingTurnip);
        auto& Settle = InSelf.Get_Fragment(FMars_Fragment_ScreamingTurnip_Settle);
        auto WorldItem = Params.WorldItem;
        const auto Mount = WorldItem.Get_Mount();
        if (Mount != EMars_WorldItem_Mount::World)
        {
            Reset_Sampler(Settle);
            if (WorldItem.Get_IsSettled() == false)
            { return EMars_ScreamingTurnip_Placement::Transfer; }

            return Mount == EMars_WorldItem_Mount::Held ? EMars_ScreamingTurnip_Placement::Held : EMars_ScreamingTurnip_Placement::Protected;
        }

        // A pickup underway: the body is going Kinematic for its new mount, which commits a frame or more later.
        if (WorldItem.Has_Fragment(FMars_Fragment_WorldItem_PendingMount))
        {
            Reset_Sampler(Settle);
            return EMars_ScreamingTurnip_Placement::Transfer;
        }

        auto Query = FMars_ScreamingTurnip_SettleQuery(Params.Settlement, State.Clock, InDeltaSeconds);
        Query.WasSettled = State.Placement == EMars_ScreamingTurnip_Placement::LooseSettled;
        return Sample_Settle(InSelf, Query, Settle);
    }

    // The sampler off the World mount: no dwell, no previous rotation, no support.
    private void Reset_Sampler(FMars_Fragment_ScreamingTurnip_Settle& InSettle)
    {
        InSettle.EnterDwell = 0.0f;
        InSettle.ExitDwell = 0.0f;
        InSettle.LastSupportAt.Reset();
        InSettle.PrevRotation.Reset();
        InSettle.PrevSampleAt.Reset();
        InSettle.AngularDegPerSec = 0.0f;
        InSettle.LinearCmPerSec = 0.0f;
        InSettle.HasSupport = false;
    }

    // One settle sample: the body's linear speed, the root's rotation delta since the last sample (deg/s), and support (a
    // supporting contact within the grace, or asleep). A missing body, an unadded one, a non-finite velocity or the first
    // sample after a reset reads as unsettled, never as zero motion.
    private EMars_ScreamingTurnip_Placement Sample_Settle(FCk_Handle_ScreamingTurnip& InSelf, const FMars_ScreamingTurnip_SettleQuery& InQuery,
                                                          FMars_Fragment_ScreamingTurnip_Settle& InSettle)
    {
        const auto& Settlement = InQuery.Settlement;
        auto WorldItem = InSelf.Get_Fragment(FMars_Fragment_ScreamingTurnip_Params).WorldItem;
        const auto Body = WorldItem.Get_Body();

        auto HasMotion = false;
        if (ck::Is_NOT_Valid(Body))
        {
            if (InSettle.WarnedMissingBody == false)
            {
                InSettle.WarnedMissingBody = true;
                ck::Trace(f"[ScreamingTurnip] [{InSelf.ToString()}] has no body to sample: it reads as unsettled (its world item was built without one)");
            }
        }
        else if (utils_jolt_body::Get_IsBodyAdded(Body))
        {
            const auto Velocity = utils_jolt_body::Get_LinearVelocity(Body);
            HasMotion = Velocity.ContainsNaN() == false;
            InSettle.LinearCmPerSec = float32(Velocity.Size());
        }

        FCk_Handle Entity = WorldItem;
        const auto Rotation = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform()).GetRotation();
        auto HasAngular = false;
        if (InSettle.PrevRotation.IsSet() && InSettle.PrevSampleAt.IsSet())
        {
            const auto SampleSeconds = InQuery.Clock - InSettle.PrevSampleAt.GetValue();
            if (SampleSeconds > 0.0f)
            {
                const auto Degrees = Math::RadiansToDegrees(Rotation.AngularDistance(InSettle.PrevRotation.GetValue()));
                InSettle.AngularDegPerSec = float32(Degrees / SampleSeconds);
                HasAngular = true;
            }
        }

        InSettle.PrevRotation = TOptional<FQuat>(Rotation);
        InSettle.PrevSampleAt = TOptional<float32>(InQuery.Clock);

        const auto IsAsleep = ck::IsValid(Body) && utils_jolt_body::Get_IsBodyAdded(Body)
            && utils_jolt_body::Get_SleepState(Body) == ECk_Jolt_SleepState::Asleep;
        const auto HasRecentContact = InSettle.LastSupportAt.IsSet()
            && InQuery.Clock - InSettle.LastSupportAt.GetValue() <= Settlement.SupportGraceSeconds;
        InSettle.HasSupport = HasMotion && (IsAsleep || HasRecentContact);

        if (InQuery.WasSettled)
        {
            if (InSettle.HasSupport == false)
            {
                InSettle.ExitDwell = 0.0f;
                return EMars_ScreamingTurnip_Placement::Loose;
            }

            const auto IsMoving = InSettle.LinearCmPerSec > Settlement.ExitLinearCmPerSec
                || (HasAngular && InSettle.AngularDegPerSec > Settlement.ExitAngularDegPerSec);
            InSettle.ExitDwell = IsMoving ? InSettle.ExitDwell + InQuery.DeltaSeconds : 0.0f;
            if (IsMoving && InSettle.ExitDwell >= Settlement.ExitDwellSeconds)
            {
                InSettle.ExitDwell = 0.0f;
                return EMars_ScreamingTurnip_Placement::Loose;
            }

            return EMars_ScreamingTurnip_Placement::LooseSettled;
        }

        const auto IsStill = InSettle.HasSupport && HasAngular
            && InSettle.LinearCmPerSec <= Settlement.EnterLinearCmPerSec
            && InSettle.AngularDegPerSec <= Settlement.EnterAngularDegPerSec;
        InSettle.EnterDwell = IsStill ? InSettle.EnterDwell + InQuery.DeltaSeconds : 0.0f;
        if (IsStill && InSettle.EnterDwell >= Settlement.EnterDwellSeconds)
        {
            InSettle.EnterDwell = 0.0f;
            InSettle.ExitDwell = 0.0f;
            return EMars_ScreamingTurnip_Placement::LooseSettled;
        }

        return EMars_ScreamingTurnip_Placement::Loose;
    }

    // Transfer freezes the warning; Loose and Protected cancel it; Held and LooseSettled leave it for the voice to resume.
    private void Apply_PlacementRule(FMars_Fragment_ScreamingTurnip& InState, EMars_ScreamingTurnip_Placement InNew,
                                     TArray<EMars_ScreamingTurnip_Phase>& InOutPhaseTrail)
    {
        if (utils_screaming_turnip::Get_IsEligible(InNew))
        { return; }

        if (InNew != EMars_ScreamingTurnip_Placement::Transfer)
        { InState.WarningElapsed = 0.0f; }

        Set_Phase(InState, FMars_ScreamingTurnip_PhaseEntry(EMars_ScreamingTurnip_Phase::Dormant, InState.Clock), InOutPhaseTrail);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Voice
    //----------------------------------------------------------------------------------------------------------------------

    // True when this pass committed a scream (at most one).
    private bool Advance_Voice(FCk_Handle_ScreamingTurnip& InSelf, TArray<EMars_ScreamingTurnip_Phase>& InOutPhaseTrail)
    {
        const auto Vocal = InSelf.Get_Fragment(FMars_Fragment_ScreamingTurnip_Params).Vocal;
        auto& State = InSelf.Get_Fragment(FMars_Fragment_ScreamingTurnip);
        const auto Now = State.Clock;
        auto Committed = false;

        for (int32 Step = 0; Step < k_MaxPhaseSteps; ++Step)
        {
            const auto Start = State.PhaseStartedAt;
            auto Next = TOptional<FMars_ScreamingTurnip_PhaseEntry>();

            switch (State.Phase)
            {
                case EMars_ScreamingTurnip_Phase::Dormant:
                {
                    Next = TOptional<FMars_ScreamingTurnip_PhaseEntry>(Get_EntryFromDormant(Vocal, State));
                    break;
                }

                case EMars_ScreamingTurnip_Phase::Anticipate:
                {
                    const auto End = Start + Vocal.AnticipateSeconds;
                    if (End <= Now)
                    { Next = TOptional<FMars_ScreamingTurnip_PhaseEntry>(FMars_ScreamingTurnip_PhaseEntry(EMars_ScreamingTurnip_Phase::Inhale, End)); }

                    break;
                }

                case EMars_ScreamingTurnip_Phase::Inhale:
                {
                    if (Committed || Start + Vocal.InhaleSeconds > Now)
                    { break; }

                    if (Commit_Scream(InSelf, State) == false)
                    { break; }

                    Committed = true;
                    Next = TOptional<FMars_ScreamingTurnip_PhaseEntry>(FMars_ScreamingTurnip_PhaseEntry(EMars_ScreamingTurnip_Phase::Scream, Now));
                    break;
                }

                case EMars_ScreamingTurnip_Phase::Scream:
                {
                    const auto End = Start + Vocal.ScreamSeconds;
                    if (End <= Now)
                    { Next = TOptional<FMars_ScreamingTurnip_PhaseEntry>(FMars_ScreamingTurnip_PhaseEntry(EMars_ScreamingTurnip_Phase::Recover, End)); }

                    break;
                }

                case EMars_ScreamingTurnip_Phase::Recover:
                {
                    const auto End = Start + Vocal.RecoverSeconds;
                    if (End <= Now)
                    { Next = TOptional<FMars_ScreamingTurnip_PhaseEntry>(FMars_ScreamingTurnip_PhaseEntry(EMars_ScreamingTurnip_Phase::RecoveryIdle, End)); }

                    break;
                }

                case EMars_ScreamingTurnip_Phase::RecoveryIdle:
                {
                    const auto End = Get_CooldownEnd(Vocal, State);
                    if (End <= Now)
                    {
                        State.WarningElapsed = 0.0f;
                        Next = TOptional<FMars_ScreamingTurnip_PhaseEntry>(
                            FMars_ScreamingTurnip_PhaseEntry(EMars_ScreamingTurnip_Phase::Anticipate, Math::Max(End, Start)));
                    }

                    break;
                }
            }

            if (Next.IsSet() == false)
            { break; }

            Set_Phase(State, Next.GetValue(), InOutPhaseTrail);
        }

        State.WarningElapsed = Get_WarningElapsed(Vocal, State);
        return Committed;
    }

    // Where an eligible Dormant root starts: quiet until a pending cooldown runs out, else the warning, resumed from
    // WarningElapsed (zero after a cancel).
    private FMars_ScreamingTurnip_PhaseEntry Get_EntryFromDormant(const FMars_ScreamingTurnip_Vocal& InVocal,
                                                                  const FMars_Fragment_ScreamingTurnip& InState) const
    {
        const auto Now = InState.Clock;
        if (InState.LastScreamCommittedAt.IsSet() && Get_CooldownEnd(InVocal, InState) > Now)
        { return FMars_ScreamingTurnip_PhaseEntry(EMars_ScreamingTurnip_Phase::RecoveryIdle, Now); }

        const auto Elapsed = Math::Clamp(InState.WarningElapsed, 0.0f, InVocal.AnticipateSeconds + InVocal.InhaleSeconds);
        if (Elapsed < InVocal.AnticipateSeconds)
        { return FMars_ScreamingTurnip_PhaseEntry(EMars_ScreamingTurnip_Phase::Anticipate, Now - Elapsed); }

        return FMars_ScreamingTurnip_PhaseEntry(EMars_ScreamingTurnip_Phase::Inhale, Now - (Elapsed - InVocal.AnticipateSeconds));
    }

    // The clock time the cooldown from the last commit runs out; a root that never screamed has none (its Clock).
    private float32 Get_CooldownEnd(const FMars_ScreamingTurnip_Vocal& InVocal, const FMars_Fragment_ScreamingTurnip& InState) const
    {
        if (InState.LastScreamCommittedAt.IsSet() == false)
        { return InState.Clock; }

        return InState.LastScreamCommittedAt.GetValue() + InVocal.CooldownSeconds;
    }

    private float32 Get_WarningElapsed(const FMars_ScreamingTurnip_Vocal& InVocal, const FMars_Fragment_ScreamingTurnip& InState) const
    {
        if (InState.Phase == EMars_ScreamingTurnip_Phase::Anticipate)
        { return Math::Max(InState.Clock - InState.PhaseStartedAt, 0.0f); }

        if (InState.Phase == EMars_ScreamingTurnip_Phase::Inhale)
        { return InVocal.AnticipateSeconds + Math::Max(InState.Clock - InState.PhaseStartedAt, 0.0f); }

        return 0.0f;
    }

    // The commit: the next sequence, this tick's clock, the root copied. A root with no transform commits nothing and says
    // so once: a burst is never placed at the origin.
    private bool Commit_Scream(FCk_Handle_ScreamingTurnip& InSelf, FMars_Fragment_ScreamingTurnip& InState)
    {
        FCk_Handle Entity = InSelf.Get_Fragment(FMars_Fragment_ScreamingTurnip_Params).WorldItem;
        if (Entity.Is_Transform() == false)
        {
            if (InState.WarnedMissingTransform == false)
            {
                InState.WarnedMissingTransform = true;
                ck::Trace(f"[ScreamingTurnip] [{InSelf.ToString()}] has no transform to place its scream: the commit is suppressed");
            }

            return false;
        }

        InState.ScreamSequence += 1;
        InState.LastScreamCommittedAt = TOptional<float32>(InState.Clock);
        InState.LastWorldPosition = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform()).GetLocation();
        return true;
    }

    private void Set_Phase(FMars_Fragment_ScreamingTurnip& InState, const FMars_ScreamingTurnip_PhaseEntry& InEntry,
                           TArray<EMars_ScreamingTurnip_Phase>& InOutPhaseTrail)
    {
        InState.PhaseStartedAt = InEntry.StartedAt;
        if (InState.Phase == InEntry.Phase)
        { return; }

        InState.Phase = InEntry.Phase;
        InOutPhaseTrail.Add(InEntry.Phase);
    }
}

// A phase and the clock time it began (carry-over makes that earlier than this tick's clock).
struct FMars_ScreamingTurnip_PhaseEntry
{
    EMars_ScreamingTurnip_Phase Phase = EMars_ScreamingTurnip_Phase::Dormant;

    float32 StartedAt = 0.0f;

    FMars_ScreamingTurnip_PhaseEntry() {}

    FMars_ScreamingTurnip_PhaseEntry(EMars_ScreamingTurnip_Phase InPhase, float32 InStartedAt)
    {
        Phase = InPhase;
        StartedAt = InStartedAt;
    }
}

// One settle sample's inputs.
struct FMars_ScreamingTurnip_SettleQuery
{
    FMars_ScreamingTurnip_Settlement Settlement;

    float32 Clock = 0.0f;

    float32 DeltaSeconds = 0.0f;

    // The placement before this sample was LooseSettled: the exit test applies, not the enter test.
    bool WasSettled = false;

    FMars_ScreamingTurnip_SettleQuery() {}

    FMars_ScreamingTurnip_SettleQuery(const FMars_ScreamingTurnip_Settlement& InSettlement, float32 InClock, float32 InDeltaSeconds)
    {
        Settlement = InSettlement;
        Clock = InClock;
        DeltaSeconds = InDeltaSeconds;
    }
}
