// The spot's clocks while it is engaged, one phase step per frame (a long frame finishes at most one transition, so no
// signal is skipped). Casting flies the bait under gravity until it meets the water (OnBaitLanded). Waiting bobs the float
// until the bite is due (OnBite). Bite counts the hook window down and, unhooked, ends it Missed. Hooked sets the hook and
// hands over to the reel. Reeling runs the fish's runs (OnRun), shortens the line while the reel is held and strains it,
// lets the strain recover while released, snaps the line at Reel.SnapTension (OnSnapped) and lands the fish when the line
// runs out (OnLanded). Landed counts the fling down.
class UMars_Processor_Fishing_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Fishing_HandleRequests");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Fishing);
        Query.Require(FMars_Tag_Fishing_Engaged);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Fishing& InState)
    {
        auto Self = InHandle.As_Fishing();
        const auto Spec = Self.Get_Spec();
        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());
        const auto PhaseBefore = InState.Phase;
        auto Landed = TOptional<FVector>();
        auto BiteNow = false;
        auto Missed = false;
        auto RunEdge = TOptional<bool>();
        auto Snapped = false;
        auto Caught = TOptional<FMars_Fishing_Catch>();

        InState.Clock.PhaseSeconds += DeltaSeconds;

        switch (InState.Phase)
        {
            case EMars_Fishing_Phase::Casting:
            {
                InState.Bait.Velocity.Z -= Spec.Launch.GravityCmPerS2 * DeltaSeconds;
                InState.Bait.Position += InState.Bait.Velocity * DeltaSeconds;
                if (InState.Bait.Position.Z <= Spec.Water.SurfaceZ)
                {
                    InState.Bait.Position.Z = Spec.Water.SurfaceZ;
                    InState.Bait.Velocity = FVector::ZeroVector;
                    const auto Out = InState.Bait.Position - Self.Get_AnchorWorld();
                    InState.Line.LengthCm = float32(FVector(Out.X, Out.Y, 0.0).Size());
                    InState.Clock.BiteAtSeconds = utils_fishing::Next_Range(InState.Rng, Spec.Bite.MinWaitSeconds, Spec.Bite.MaxWaitSeconds);
                    utils_fishing_requests::Enter(InState, EMars_Fishing_Phase::Waiting);
                    Landed = TOptional<FVector>(InState.Bait.Position);
                }
                break;
            }
            case EMars_Fishing_Phase::Waiting:
            {
                InState.Bait.BobPhase += 2.0f * PI * Spec.Water.BobHz * DeltaSeconds;
                if (InState.Clock.PhaseSeconds >= InState.Clock.BiteAtSeconds)
                {
                    utils_fishing_requests::Bite(InState, Spec.Bite);
                    BiteNow = true;
                }
                break;
            }
            case EMars_Fishing_Phase::Bite:
            {
                InState.Bait.BobPhase += 2.0f * PI * Spec.Water.BobHz * DeltaSeconds;
                InState.Clock.WindowLeft = Math::Max(0.0f, InState.Clock.WindowLeft - DeltaSeconds);
                if (InState.Clock.WindowLeft <= 0.0f)
                {
                    InState.Bait.DipCm = 0.0f;
                    InState.Clock.BiteAtSeconds = Spec.Bite.MissPenaltySeconds
                        + utils_fishing::Next_Range(InState.Rng, Spec.Bite.MinWaitSeconds, Spec.Bite.MaxWaitSeconds);
                    utils_fishing_requests::Enter(InState, EMars_Fishing_Phase::Waiting);
                    Missed = true;
                }
                break;
            }
            case EMars_Fishing_Phase::Hooked:
            {
                InState.Clock.HookSetLeft = Math::Max(0.0f, InState.Clock.HookSetLeft - DeltaSeconds);
                if (InState.Clock.HookSetLeft <= 0.0f)
                {
                    const auto Fish = utils_fishing::Draw_Fish(Spec.Fish.Table, InState.Rng);
                    InState.Catch = FMars_Fishing_Catch();
                    InState.Catch.Item = Fish.Item;
                    InState.Catch.Fight = Fish.Fight;
                    InState.Run.Running = false;
                    InState.Run.SecondsLeft = utils_fishing::Next_Range(InState.Rng, Spec.Run.MinGapSeconds, Spec.Run.MaxGapSeconds);
                    utils_fishing_requests::Enter(InState, EMars_Fishing_Phase::Reeling);
                }
                break;
            }
            case EMars_Fishing_Phase::Reeling:
            {
                RunEdge = Advance_Run(InState, Spec.Run, DeltaSeconds);
                Advance_Line(InState, Spec, DeltaSeconds);

                if (InState.Line.Tension >= Spec.Reel.SnapTension)
                {
                    InState.Line.Tension = Spec.Reel.SnapTension;
                    InState.Run.Running = false;
                    utils_fishing_requests::Enter(InState, EMars_Fishing_Phase::Snapped);
                    Snapped = true;
                }
                else if (InState.Line.LengthCm <= 0.0f)
                {
                    InState.Line.LengthCm = 0.0f;
                    InState.Run.Running = false;
                    InState.Catch.LandedAt = InState.Bait.Position;
                    InState.Catch.FlingLeft = Spec.Fish.LandFlingSeconds;
                    utils_fishing_requests::Enter(InState, EMars_Fishing_Phase::Landed);
                    Caught = TOptional<FMars_Fishing_Catch>(InState.Catch);
                }
                break;
            }
            case EMars_Fishing_Phase::Landed:
            {
                InState.Catch.FlingLeft = Math::Max(0.0f, InState.Catch.FlingLeft - DeltaSeconds);
                break;
            }
            default:
                break;
        }

        const auto Phase = InState.Phase;

        // InState is not read past this line: a listener may add fragments to the station.
        if (Self.Has_Fragment(FMars_Fragment_Fishing_Signals) == false)
        { return; }

        auto& Signals = Self.Get_Fragment(FMars_Fragment_Fishing_Signals);
        if (Landed.IsSet())
        { Signals.OnBaitLanded.Broadcast(Self, Landed.GetValue()); }

        if (BiteNow)
        { Signals.OnBite.Broadcast(Self); }

        if (Missed)
        { Signals.OnBiteEnded.Broadcast(Self, EMars_Fishing_BiteResult::Missed); }

        if (RunEdge.IsSet())
        { Signals.OnRun.Broadcast(Self, RunEdge.GetValue()); }

        if (Snapped)
        { Signals.OnSnapped.Broadcast(Self); }

        if (Caught.IsSet())
        { Signals.OnLanded.Broadcast(Self, Caught.GetValue()); }

        if (Phase != PhaseBefore)
        { Signals.OnPhaseChanged.Broadcast(Self, Phase); }
    }

    // The fish's run clock: calm until the next run, then a run until it tires. Set when a run starts (true) or ends (false).
    private TOptional<bool> Advance_Run(FMars_Fragment_Fishing& InOutState, const FMars_Fishing_RunSpec& InRun, float32 InDeltaSeconds) const
    {
        InOutState.Run.SecondsLeft -= InDeltaSeconds;
        if (InOutState.Run.SecondsLeft > 0.0f)
        { return TOptional<bool>(); }

        InOutState.Run.Running = InOutState.Run.Running == false;
        InOutState.Run.SecondsLeft = InOutState.Run.Running
            ? utils_fishing::Next_Range(InOutState.Rng, InRun.MinRunSeconds, InRun.MaxRunSeconds)
            : utils_fishing::Next_Range(InOutState.Rng, InRun.MinGapSeconds, InRun.MaxGapSeconds);
        return TOptional<bool>(InOutState.Run.Running);
    }

    // The line this frame: a run pulls line out; a held reel takes it in and strains it; a released reel lets it recover.
    private void Advance_Line(FMars_Fragment_Fishing& InOutState, const FMars_Fishing_Spec& InSpec, float32 InDeltaSeconds) const
    {
        if (InOutState.Run.Running)
        { InOutState.Line.LengthCm += InSpec.Run.PullCmPerS * InOutState.Catch.Fight * InDeltaSeconds; }

        if (InOutState.Reel == EMars_Fishing_Reel::Held)
        {
            InOutState.Line.LengthCm -= InSpec.Reel.ReelSpeedCmPerS * InDeltaSeconds;
            const auto Gain = InOutState.Run.Running ? InSpec.Reel.RunTensionGainPerS : InSpec.Reel.TensionGainPerS;
            InOutState.Line.Tension += Gain * InDeltaSeconds;
        }
        else
        { InOutState.Line.Tension = Math::Max(0.0f, InOutState.Line.Tension - InSpec.Reel.RecoveryPerS * InDeltaSeconds); }
    }
}

// The spot's fade in and out, with or without an operator: Arriving opens after Presence.ArriveSeconds, Leaving is Gone
// after Presence.LeaveSeconds (OnPresenceChanged), and the Transitioning tag leaves with the fade.
class UMars_Processor_Fishing_PresenceTick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Fishing_HandleRequests");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Fishing);
        Query.Require(FMars_Tag_Fishing_Transitioning);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Fishing& InState)
    {
        auto Self = InHandle.As_Fishing();
        InState.Clock.PresenceLeft = Math::Max(0.0f, InState.Clock.PresenceLeft - float32(InDeltaT.Get_Seconds()));
        if (InState.Clock.PresenceLeft > 0.0f)
        { return; }

        auto Changed = false;
        if (InState.Presence == EMars_Fishing_Presence::Arriving)
        {
            InState.Presence = EMars_Fishing_Presence::Open;
            Changed = true;
        }
        else if (InState.Presence == EMars_Fishing_Presence::Leaving)
        {
            InState.Presence = EMars_Fishing_Presence::Gone;
            Changed = true;
        }

        const auto Presence = InState.Presence;

        // InState is not read past this line: the tag moves, and a listener may add fragments to the station.
        Self.Request_TryRemove(FMars_Tag_Fishing_Transitioning);

        if (Changed == false || Self.Has_Fragment(FMars_Fragment_Fishing_Signals) == false)
        { return; }

        Self.Get_Fragment(FMars_Fragment_Fishing_Signals).OnPresenceChanged.Broadcast(Self, Presence);
    }
}
