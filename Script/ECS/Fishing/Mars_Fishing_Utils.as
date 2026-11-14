// A cast to work out: from Origin, along the unit horizontal Forward, at PitchDeg above level, to land DistanceCm out on
// the water plane at SurfaceZ under GravityCmPerS2.
struct FMars_Fishing_CastQuery
{
    FVector Origin;
    FVector Forward;
    float32 PitchDeg = 35.0f;
    float32 DistanceCm = 500.0f;
    float32 GravityCmPerS2 = 980.0f;
    float64 SurfaceZ = 0.0;
}

// What a copy without authority shows: the ledger that arrived, the one it showed before, the spec and its state now.
struct FMars_Fishing_ShowQuery
{
    FMars_Fragment_Fishing_Net Ledger;
    FMars_Fragment_Fishing_Net Last;
    FMars_Fishing_Spec Spec;
    FMars_Fragment_Fishing State;
}

namespace utils_fishing
{
    // Composes the fishing spot on InHandle (the station entity; the feature does not need the Station feature). Every
    // clock is the kernel's; what draws the rod, line, bait and fish follows its state and signals. Adds the replicated
    // ledger unless it already arrived (an arrived ledger is the state this copy was born into and has then taken),
    // this machine's mirror state and the tag that wakes the mirror; without authority the state starts as the ledger
    // shows it and no generator is seeded. A rejected spec ensures and returns an invalid handle.
    FCk_Handle_Fishing Add(FCk_Handle& InHandle, FMars_Fishing_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Fishing] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Fishing(); }

        auto Params = FMars_Fragment_Fishing_Params();
        Params.Spec = InSpec;

        const auto HasAuthority = utils_net::Get_HasAuthority(InHandle);
        auto State = FMars_Fragment_Fishing();
        State.Presence = InSpec.Presence.StartOpen ? EMars_Fishing_Presence::Open : EMars_Fishing_Presence::Arriving;
        State.Clock.PresenceLeft = InSpec.Presence.StartOpen ? 0.0f : InSpec.Presence.ArriveSeconds;
        if (HasAuthority)
        { State.Rng = Make_Seed(InSpec.Seed); }

        auto Fresh = FMars_Fragment_Fishing_Net();
        Fresh.Presence = State.Presence;
        Fresh.PresenceAnchorServerSeconds = utils_mars_net::Get_ServerWorldSeconds(InHandle);
        auto Local = FMars_Fragment_Fishing_Local();

        // A ledger already here can only have been put here by its replicated application: this copy was born into it,
        // has taken that state, and the mirror's first pass shows it as it stands (a spot first read mid-fight shows
        // that fight).
        if (InHandle.Has_Fragment(FMars_Fragment_Fishing_Net))
        { Local.InitialState = EMars_Net_InitialState::Taken; }
        else
        { InHandle.Add_Fragment(Fresh, ECk_Replication::Replicates); }

        const auto Ledger = InHandle.Get_Fragment(FMars_Fragment_Fishing_Net);
        if (HasAuthority == false)
        {
            auto Query = FMars_Fishing_ShowQuery();
            Query.Ledger = Ledger;
            Query.Spec = InSpec;
            Query.State = State;
            State = Get_Shown(InHandle, Query);
        }

        // The mirror compares what arrives against the ledger this machine composed.
        Local.Last = TOptional<FMars_Fragment_Fishing_Net>(Fresh);

        InHandle.Add_Fragment(FMars_Feature_Fishing());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        InHandle.Add_Fragment(Local);
        InHandle.Add_Fragment(FMars_Tag_Fishing_NeedsMirror());
        if (Get_IsFading(State.Presence))
        { InHandle.Add_Fragment(FMars_Tag_Fishing_Transitioning()); }

        if (HasAuthority == false && Ledger.Engagement == EMars_Fishing_Engagement::Engaged)
        { InHandle.Add_Fragment(FMars_Tag_Fishing_Engaged()); }

        return InHandle.As_Fishing();
    }

    bool Get_IsPositiveFinite(float32 InValue)
    {
        return Math::IsFinite(InValue) && InValue > 0.0f;
    }

    // A non-zero xorshift state from a seed.
    uint32 Make_Seed(int32 InSeed)
    {
        uint32 X = uint32(InSeed) * uint32(2654435761);
        X = X ^ (X >> 16);
        X = X * uint32(0x7feb352d);
        X = X ^ (X >> 15);
        return X == 0 ? uint32(0x9e3779b9) : X;
    }

    // The next draw in [0, 1), advancing the state (xorshift32).
    float32 Next_Unit(uint32& InOutRng)
    {
        uint32 X = InOutRng;
        X = X ^ (X << 13);
        X = X ^ (X >> 17);
        X = X ^ (X << 5);
        InOutRng = X;
        return float32(float64(X >> 8) / 16777216.0);
    }

    float32 Next_Range(uint32& InOutRng, float32 InMin, float32 InMax)
    {
        return Math::Lerp(InMin, InMax, Next_Unit(InOutRng));
    }

    // A weighted draw from the table (the table is non-empty: Validate); OutIndex is the entry's place in it.
    FMars_Fishing_FishEntry Draw_Fish(const TArray<FMars_Fishing_FishEntry>& InTable, uint32& InOutRng, int32& OutIndex)
    {
        float32 Total = 0.0f;
        for (const auto& Entry : InTable)
        { Total += Entry.Weight; }

        auto Pick = Next_Unit(InOutRng) * Total;
        for (int32 Index = 0; Index < InTable.Num(); ++Index)
        {
            Pick -= InTable[Index].Weight;
            if (Pick < 0.0f)
            {
                OutIndex = Index;
                return InTable[Index];
            }
        }

        OutIndex = InTable.Num() - 1;
        return InTable[OutIndex];
    }

    // The launch velocity that lands the bait DistanceCm out on the plane: v^2 = g d^2 / (2 cos^2(p) (h + d tan(p))) with
    // h the drop from the origin to the water. An origin under the water (h + d tan p <= 0) launches level at a minimum.
    FVector Make_LaunchVelocity(const FMars_Fishing_CastQuery& InQuery)
    {
        const auto Pitch = Math::DegreesToRadians(InQuery.PitchDeg);
        const auto CosP = Math::Cos(Pitch);
        const auto SinP = Math::Sin(Pitch);
        const auto Drop = InQuery.Origin.Z - InQuery.SurfaceZ;
        const auto Reach = Drop + InQuery.DistanceCm * (SinP / CosP);
        const auto Denominator = 2.0 * CosP * CosP * Math::Max(Reach, 1.0);
        const auto Speed = Math::Sqrt(InQuery.GravityCmPerS2 * InQuery.DistanceCm * InQuery.DistanceCm / Denominator);
        return InQuery.Forward * (Speed * CosP) + FVector::UpVector * (Speed * SinP);
    }

    // The aim's unit horizontal direction in the world: the frame's X turned by the aim's yaw.
    FVector Make_AimForward(const FTransform& InFrame, float32 InYawDeg)
    {
        const auto Local = FRotator(0.0, InYawDeg, 0.0).RotateVector(FVector::ForwardVector);
        auto Forward = InFrame.GetRotation().RotateVector(Local);
        Forward.Z = 0.0;
        return Forward.GetSafeNormal(0.0001, FVector::ForwardVector);
    }

    // The pacing rule for the ledger's aim and line, published while they move: a write when either moved from the ledger's
    // by its quantum and at least 1 / k_PacedHz has passed since the last paced write.
    const float32 k_AimQuantumDeg = 0.25f;
    const float32 k_LineQuantumCm = 2.0f;
    const float32 k_TensionQuantum = 0.01f;
    const float32 k_PacedHz = 15.0f;

    // How fast a copy without authority eases its aim and line toward the ledger's.
    const float32 k_FollowAimDegPerS = 180.0f;
    const float32 k_FollowLineCmPerS = 600.0f;
    const float32 k_FollowTensionPerS = 3.0f;

    // The longest slice a flight is replayed in from its anchor.
    const float32 k_FlightStepSeconds = 1.0f / 60.0f;

    // One step of the bait's flight under gravity; true once it meets the water, where it is set on the surface at rest. The
    // one flight of the kernel, with authority and without.
    bool Advance_Flight(FMars_Fishing_Bait& InOutBait, const FMars_Fishing_Spec& InSpec, float32 InDeltaSeconds)
    {
        InOutBait.Velocity.Z -= InSpec.Launch.GravityCmPerS2 * InDeltaSeconds;
        InOutBait.Position += InOutBait.Velocity * InDeltaSeconds;
        if (InOutBait.Position.Z > InSpec.Water.SurfaceZ)
        { return false; }

        InOutBait.Position.Z = InSpec.Water.SurfaceZ;
        InOutBait.Velocity = FVector::ZeroVector;
        return true;
    }

    // The bait InSeconds into the flight that left as InLaunch, by Advance_Flight in slices of at most k_FlightStepSeconds.
    FMars_Fishing_Bait Get_FlownBait(const FMars_Fishing_Spec& InSpec, const FMars_Fishing_Bait& InLaunch, float32 InSeconds)
    {
        auto Bait = InLaunch;
        auto Left = InSeconds;
        while (Left > 0.0f)
        {
            const auto Step = Math::Min(Left, k_FlightStepSeconds);
            Left -= Step;
            if (Advance_Flight(Bait, InSpec, Step))
            { break; }
        }

        return Bait;
    }

    // The spot is fading in or out: its fade clock runs and it carries the Transitioning tag.
    bool Get_IsFading(EMars_Fishing_Presence InPresence)
    {
        return InPresence == EMars_Fishing_Presence::Arriving || InPresence == EMars_Fishing_Presence::Leaving;
    }

    // The bait floats where it landed: Waiting, a bite, and the fight.
    bool Get_IsOnTheWater(EMars_Fishing_Phase InPhase)
    {
        return InPhase == EMars_Fishing_Phase::Waiting || InPhase == EMars_Fishing_Phase::Bite
            || InPhase == EMars_Fishing_Phase::Hooked || InPhase == EMars_Fishing_Phase::Reeling;
    }

    // What a copy without authority shows from InQuery.Ledger, carried on from InQuery.State against InQuery.Last (the
    // ledger it showed before): the ledger's phase (a new one restarts the phase clock, and the follow then sets the line
    // outright), presence, reel, run, tally and dip; a fade new to this machine's clock from its anchor; a new cast's bait
    // where its flight has reached by now; the bait on the ledger's landing point while it floats; the catch at the
    // ledger's place in the table (none for a bad place) with a new landing's fling from its anchor. The aim and the line
    // are the follow's while the spot is engaged; an idle spot's are the ledger's, since nothing eases them then. Seconds
    // since an anchor are on the server's clock and never negative.
    FMars_Fragment_Fishing Get_Shown(const FCk_Handle& InHandle, const FMars_Fishing_ShowQuery& InQuery)
    {
        const auto Ledger = InQuery.Ledger;
        const auto Last = InQuery.Last;
        const auto Spec = InQuery.Spec;
        const auto Now = utils_mars_net::Get_ServerWorldSeconds(InHandle);

        auto Shown = InQuery.State;
        Shown.Phase = Ledger.Phase;
        Shown.Presence = Ledger.Presence;
        Shown.Reel = Ledger.Reel;
        Shown.Run.Running = Ledger.Run == EMars_Fishing_RunState::Running;
        Shown.Tally = Ledger.Tally;
        if (Ledger.Engagement == EMars_Fishing_Engagement::Idle)
        {
            Shown.Aim = Ledger.Aim;
            Shown.Line = Ledger.Line;
        }

        if (Ledger.PhaseSerial != Last.PhaseSerial)
        { Shown.Clock.PhaseSeconds = 0.0f; }

        if (Ledger.Presence != Last.Presence || Ledger.PresenceAnchorServerSeconds != Last.PresenceAnchorServerSeconds)
        {
            auto FadeSeconds = 0.0f;
            if (Ledger.Presence == EMars_Fishing_Presence::Arriving)
            { FadeSeconds = Spec.Presence.ArriveSeconds; }
            else if (Ledger.Presence == EMars_Fishing_Presence::Leaving)
            { FadeSeconds = Spec.Presence.LeaveSeconds; }

            const auto Faded = float32(Math::Max(Now - Ledger.PresenceAnchorServerSeconds, 0.0));
            Shown.Clock.PresenceLeft = Math::Max(0.0f, FadeSeconds - Faded);
        }

        if (Ledger.CastSerial != Last.CastSerial)
        {
            auto Launch = FMars_Fishing_Bait();
            Launch.Position = Ledger.CastOrigin;
            Launch.Velocity = Ledger.CastVelocity;
            const auto Flown = float32(Math::Max(Now - Ledger.CastAnchorServerSeconds, 0.0));
            Shown.Bait = Get_FlownBait(Spec, Launch, Flown);
        }

        if (Get_IsOnTheWater(Ledger.Phase))
        {
            Shown.Bait.Position = Ledger.BaitPosition;
            Shown.Bait.Velocity = FVector::ZeroVector;
        }

        Shown.Bait.DipCm = Ledger.DipCm;

        const auto FlingLeft = Shown.Catch.FlingLeft;
        Shown.Catch = FMars_Fishing_Catch();
        if (Ledger.CatchIndex >= 0 && Ledger.CatchIndex < Spec.Fish.Table.Num())
        {
            const auto Entry = Spec.Fish.Table[Ledger.CatchIndex];
            Shown.Catch.Item = Entry.Item;
            Shown.Catch.Fight = Entry.Fight;
            Shown.Catch.TableIndex = Ledger.CatchIndex;
            Shown.Catch.LandedAt = Ledger.LandedAt;
            Shown.Catch.FlingLeft = FlingLeft;
            if (Ledger.LandedSerial != Last.LandedSerial)
            {
                const auto Flung = float32(Math::Max(Now - Ledger.LandedAnchorServerSeconds, 0.0));
                Shown.Catch.FlingLeft = Math::Max(0.0f, Spec.Fish.LandFlingSeconds - Flung);
            }
        }

        return Shown;
    }

    // The ledger a copy without authority reads the spot through, from the live state and what the caller announced.
    // Written and marked dirty at once when the engagement, the phase (one serial more; entering Waiting stamps where the
    // bait lies), the presence (a fade that begins stamps its anchor), the reel, the run, the dip, the tally or an answer
    // differ: a cast stamps its origin, velocity and anchor, a landing where the fish left the water and its anchor; every
    // at-once write carries the catch's place and the current aim and line. Otherwise, only from the engaged tick
    // (InAnswers.TickSeconds), the aim and the line alone by the pacing rule. Called only by the spot's processors on the
    // authority, once after their step and before their broadcasts. Reads the state through the handle.
    void Publish(FCk_Handle_Fishing& InFishing, const FMars_Fishing_Answers& InAnswers)
    {
        const auto State = InFishing.Get_Fragment(FMars_Fragment_Fishing);
        const auto Ledger = InFishing.Get_Fragment(FMars_Fragment_Fishing_Net);
        auto& Local = InFishing.Get_Fragment(FMars_Fragment_Fishing_Local);
        if (InAnswers.TickSeconds.IsSet())
        { Local.SecondsSincePaced += InAnswers.TickSeconds.GetValue(); }

        const auto Engagement = InFishing.Get_IsEngaged() ? EMars_Fishing_Engagement::Engaged : EMars_Fishing_Engagement::Idle;
        const auto Run = State.Run.Running ? EMars_Fishing_RunState::Running : EMars_Fishing_RunState::Calm;
        const auto HasAnswer = InAnswers.Casts > 0 || InAnswers.Bites > 0 || InAnswers.BiteEnds.Num() > 0
            || InAnswers.Landings > 0 || InAnswers.Collections > 0;
        const auto IsAtOnce = HasAnswer || Engagement != Ledger.Engagement || State.Phase != Ledger.Phase
            || State.Presence != Ledger.Presence || State.Reel != Ledger.Reel || Run != Ledger.Run
            || State.Bait.DipCm != Ledger.DipCm || State.Tally != Ledger.Tally;
        const auto IsPaced = IsAtOnce == false && InAnswers.TickSeconds.IsSet()
            && Local.SecondsSincePaced >= 1.0f / k_PacedHz && Get_HasPacedMoved(State, Ledger);
        if (IsAtOnce == false && IsPaced == false)
        { return; }

        auto Next = Ledger;
        Next.Aim = State.Aim;
        Next.Line = State.Line;
        Local.SecondsSincePaced = 0.0f;
        if (IsAtOnce)
        {
            const auto Now = utils_mars_net::Get_ServerWorldSeconds(InFishing);
            if (State.Phase != Ledger.Phase)
            {
                Next.PhaseSerial += 1;
                if (State.Phase == EMars_Fishing_Phase::Waiting)
                { Next.BaitPosition = State.Bait.Position; }
            }

            if (State.Presence != Ledger.Presence && Get_IsFading(State.Presence))
            { Next.PresenceAnchorServerSeconds = Now; }

            Next.Engagement = Engagement;
            Next.Phase = State.Phase;
            Next.Presence = State.Presence;
            Next.Reel = State.Reel;
            Next.Run = Run;
            Next.DipCm = State.Bait.DipCm;
            Next.Tally = State.Tally;
            Next.CatchIndex = State.Catch.Item.IsNull() ? -1 : State.Catch.TableIndex;

            if (InAnswers.Casts > 0)
            {
                Next.CastSerial += InAnswers.Casts;
                Next.CastOrigin = State.Bait.Position;
                Next.CastVelocity = State.Bait.Velocity;
                Next.CastAnchorServerSeconds = Now;
            }

            Next.BiteSerial += InAnswers.Bites;
            if (InAnswers.BiteEnds.Num() > 0)
            {
                Next.BiteEndSerial += InAnswers.BiteEnds.Num();
                Next.LastBiteEnd = InAnswers.BiteEnds[InAnswers.BiteEnds.Num() - 1];
            }

            if (InAnswers.Landings > 0)
            {
                Next.LandedSerial += InAnswers.Landings;
                Next.LandedAt = State.Catch.LandedAt;
                Next.LandedAnchorServerSeconds = Now;
            }

            Next.CollectedSerial += InAnswers.Collections;
        }

        InFishing.Get_Fragment(FMars_Fragment_Fishing_Net) = Next;
        FCk_Handle Entity = InFishing;
        Entity.Request_MarkReplicationDirty(FMars_Fragment_Fishing_Net);
    }

    // The state's aim or line moved from the ledger's by its quantum.
    bool Get_HasPacedMoved(const FMars_Fragment_Fishing& InState, const FMars_Fragment_Fishing_Net& InLedger)
    {
        return Math::Abs(InState.Aim.YawDeg - InLedger.Aim.YawDeg) >= k_AimQuantumDeg
            || Math::Abs(InState.Aim.PitchDeg - InLedger.Aim.PitchDeg) >= k_AimQuantumDeg
            || Math::Abs(InState.Line.LengthCm - InLedger.Line.LengthCm) >= k_LineQuantumCm
            || Math::Abs(InState.Line.Tension - InLedger.Line.Tension) >= k_TensionQuantum;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Fishing_Spec Get_Spec(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing_Params).Spec;
}

mixin EMars_Fishing_Phase Get_Phase(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing).Phase;
}

mixin EMars_Fishing_Presence Get_Presence(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing).Presence;
}

// 0..1 of the spot's being here: fading in while Arriving, 1 while Open, fading out while Leaving, 0 once Gone.
mixin float32 Get_PresenceAlpha(const FCk_Handle_Fishing& Self)
{
    const auto State = Self.Get_Fragment(FMars_Fragment_Fishing);
    const auto Presence = Self.Get_Spec().Presence;
    switch (State.Presence)
    {
        case EMars_Fishing_Presence::Arriving: return 1.0f - Math::Clamp(State.Clock.PresenceLeft / Presence.ArriveSeconds, 0.0f, 1.0f);
        case EMars_Fishing_Presence::Leaving: return Math::Clamp(State.Clock.PresenceLeft / Presence.LeaveSeconds, 0.0f, 1.0f);
        case EMars_Fishing_Presence::Gone: return 0.0f;
        default: return 1.0f;
    }
}

mixin EMars_Fishing_Reel Get_Reel(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing).Reel;
}

mixin FMars_Fishing_Aim Get_Aim(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing).Aim;
}

mixin FMars_Fishing_Bait Get_Bait(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing).Bait;
}

mixin FMars_Fishing_Line Get_Line(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing).Line;
}

mixin float32 Get_Tension(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing).Line.Tension;
}

mixin float32 Get_LineLengthCm(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing).Line.LengthCm;
}

mixin bool Get_IsRunning(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing).Run.Running;
}

mixin FMars_Fishing_Catch Get_Catch(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing).Catch;
}

mixin int32 Get_Tally(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing).Tally;
}

// The replicated ledger as it stands on this machine.
mixin FMars_Fragment_Fishing_Net Get_Ledger(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing_Net);
}

// Seconds into the current phase.
mixin float32 Get_PhaseSeconds(const FCk_Handle_Fishing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fishing).Clock.PhaseSeconds;
}

// An operator is working the spot: its clocks run.
mixin bool Get_IsEngaged(const FCk_Handle_Fishing& Self)
{
    return Self.Has_Fragment(FMars_Tag_Fishing_Engaged);
}

// A line is out: the bait is in the air or on the water, or a fish is on.
mixin bool Get_HasLineOut(const FCk_Handle_Fishing& Self)
{
    const auto Phase = Self.Get_Phase();
    return Phase != EMars_Fishing_Phase::Idle && Phase != EMars_Fishing_Phase::Landed && Phase != EMars_Fishing_Phase::Snapped;
}

mixin FVector Get_AnchorWorld(const FCk_Handle_Fishing& Self)
{
    return utils_transform::Get_EntityCurrentLocation(Self.Get_Spec().Setup.Anchor);
}

mixin FVector Get_CatchWorld(const FCk_Handle_Fishing& Self)
{
    return utils_transform::Get_EntityCurrentLocation(Self.Get_Spec().Setup.Catch);
}

// The bait as drawn: its kernel position with the float's bob and a bite's dip, once it is on the water.
mixin FVector Get_BaitWorld(const FCk_Handle_Fishing& Self)
{
    const auto State = Self.Get_Fragment(FMars_Fragment_Fishing);
    if (State.Phase == EMars_Fishing_Phase::Casting || State.Phase == EMars_Fishing_Phase::Idle)
    { return State.Bait.Position; }

    const auto Bob = Self.Get_Spec().Water.BobAmpCm * Math::Sin(State.Bait.BobPhase);
    return State.Bait.Position + FVector(0.0, 0.0, Bob - State.Bait.DipCm);
}

// 0..1 of the landed fish's fling from the water to the catch point (1 once Landed and arrived, 0 before Landed).
mixin float32 Get_FlingAlpha(const FCk_Handle_Fishing& Self)
{
    const auto State = Self.Get_Fragment(FMars_Fragment_Fishing);
    if (State.Phase != EMars_Fishing_Phase::Landed)
    { return 0.0f; }

    const auto Fling = Self.Get_Spec().Fish.LandFlingSeconds;
    return 1.0f - Math::Clamp(State.Catch.FlingLeft / Fling, 0.0f, 1.0f);
}

// The landed fish as drawn: an arc from where it left the water to the catch point, LandArcHeightCm high at its middle.
mixin FVector Get_FishWorld(const FCk_Handle_Fishing& Self)
{
    const auto State = Self.Get_Fragment(FMars_Fragment_Fishing);
    const auto Alpha = Self.Get_FlingAlpha();
    const auto Eased = 0.5f - 0.5f * Math::Cos(PI * Alpha);
    const auto Height = Self.Get_Spec().Fish.LandArcHeightCm * Math::Sin(PI * Eased);
    const auto Catch = Self.Get_CatchWorld();
    return State.Catch.LandedAt + (Catch - State.Catch.LandedAt) * float64(Eased) + FVector(0.0, 0.0, Height);
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Engage(FCk_Handle_Fishing& Self, const FMars_Request_Fishing_Engage& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Requests);
    Requests.EngageRequests.Add(InRequest);
}

mixin void Request_Disengage(FCk_Handle_Fishing& Self, const FMars_Request_Fishing_Disengage& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Requests);
    Requests.DisengageRequests.Add(InRequest);
}

mixin void Request_Leave(FCk_Handle_Fishing& Self, const FMars_Request_Fishing_Leave& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Requests);
    Requests.LeaveRequests.Add(InRequest);
}

mixin void Request_Reset(FCk_Handle_Fishing& Self, const FMars_Request_Fishing_Reset& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Requests);
    Requests.ResetRequests.Add(InRequest);
}

mixin void Request_ForceBite(FCk_Handle_Fishing& Self, const FMars_Request_Fishing_ForceBite& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Requests);
    Requests.ForceBiteRequests.Add(InRequest);
}

mixin void Request_ForceLand(FCk_Handle_Fishing& Self, const FMars_Request_Fishing_ForceLand& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Requests);
    Requests.ForceLandRequests.Add(InRequest);
}

mixin void Request_Aim(FCk_Handle_Fishing& Self, const FMars_Request_Fishing_Aim& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Requests);
    Requests.AimRequests.Add(InRequest);
}

mixin void Request_Cast(FCk_Handle_Fishing& Self, const FMars_Request_Fishing_Cast& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Requests);
    Requests.CastRequests.Add(InRequest);
}

mixin void Request_Hook(FCk_Handle_Fishing& Self, const FMars_Request_Fishing_Hook& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Requests);
    Requests.HookRequests.Add(InRequest);
}

mixin void Request_ReelHold(FCk_Handle_Fishing& Self, const FMars_Request_Fishing_ReelHold& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Requests);
    Requests.ReelHoldRequests.Add(InRequest);
}

mixin void Request_ReelRelease(FCk_Handle_Fishing& Self, const FMars_Request_Fishing_ReelRelease& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Requests);
    Requests.ReelReleaseRequests.Add(InRequest);
}

mixin void Request_Collect(FCk_Handle_Fishing& Self, const FMars_Request_Fishing_Collect& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Requests);
    Requests.CollectRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnPhaseChanged(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnPhaseChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Signals);
    Fragment.OnPhaseChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPhaseChanged(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnPhaseChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fishing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fishing_Signals).OnPhaseChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPresenceChanged(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnPresenceChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Signals);
    Fragment.OnPresenceChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPresenceChanged(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnPresenceChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fishing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fishing_Signals).OnPresenceChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnCast(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnCast InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Signals);
    Fragment.OnCast.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnCast(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnCast InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fishing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fishing_Signals).OnCast.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnBaitLanded(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnBaitLanded InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Signals);
    Fragment.OnBaitLanded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnBaitLanded(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnBaitLanded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fishing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fishing_Signals).OnBaitLanded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnBite(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnBite InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Signals);
    Fragment.OnBite.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnBite(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnBite InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fishing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fishing_Signals).OnBite.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnBiteEnded(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnBiteEnded InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Signals);
    Fragment.OnBiteEnded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnBiteEnded(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnBiteEnded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fishing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fishing_Signals).OnBiteEnded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnRun(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnRun InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Signals);
    Fragment.OnRun.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnRun(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnRun InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fishing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fishing_Signals).OnRun.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnSnapped(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnSnapped InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Signals);
    Fragment.OnSnapped.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnSnapped(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnSnapped InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fishing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fishing_Signals).OnSnapped.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnLanded(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnLanded InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Signals);
    Fragment.OnLanded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnLanded(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnLanded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fishing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fishing_Signals).OnLanded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnCollected(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnCollected InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fishing_Signals);
    Fragment.OnCollected.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnCollected(FCk_Handle_Fishing& Self, FMars_Delegate_Fishing_OnCollected InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fishing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fishing_Signals).OnCollected.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
