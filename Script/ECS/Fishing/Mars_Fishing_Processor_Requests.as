// Drains Disengage -> Engage -> Leave -> Reset -> ForceBite -> ForceLand -> Aim -> Cast -> Hook -> ReelRelease -> ReelHold
// -> Collect. Disengage pulls the line in and stops the clocks; Engage starts them; Leave starts the spot's fade out; Reset
// re-rigs from any phase; the Force requests are the cheats' and tests' shortcuts; Aim turns the rod; Cast launches the bait
// along the aim; Hook sets inside a Bite; the Reel requests move the reel's hold; Collect takes a Landed catch.
// UMars_Processor_Fishing_Tick flies the bait, brings the bite, runs the fight and lands the fish.
class UMars_Processor_Fishing_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Fishing_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Fishing);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Fishing_Requests& InRequests,
                       FMars_Fragment_Fishing& InState)
    {
        auto Self = InHandle.As_Fishing();

        const auto HasDisengage = InRequests.DisengageRequests.Num() > 0;
        const auto HasEngage = InRequests.EngageRequests.Num() > 0;
        const auto HasLeave = InRequests.LeaveRequests.Num() > 0;
        const auto HasReset = InRequests.ResetRequests.Num() > 0;
        const auto HasForceBite = InRequests.ForceBiteRequests.Num() > 0;
        const auto HasForceLand = InRequests.ForceLandRequests.Num() > 0;
        const auto HasAim = InRequests.AimRequests.Num() > 0;
        const auto Aim = HasAim ? InRequests.AimRequests[InRequests.AimRequests.Num() - 1] : FMars_Request_Fishing_Aim();
        const auto HasCast = InRequests.CastRequests.Num() > 0;
        const auto CastRequest = HasCast ? InRequests.CastRequests[InRequests.CastRequests.Num() - 1] : FMars_Request_Fishing_Cast();
        const auto HasHook = InRequests.HookRequests.Num() > 0;
        const auto HasReelRelease = InRequests.ReelReleaseRequests.Num() > 0;
        const auto HasReelHold = InRequests.ReelHoldRequests.Num() > 0;
        const auto HasCollect = InRequests.CollectRequests.Num() > 0;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Fishing_Requests);

        const auto Spec = Self.Get_Spec();
        auto IsEngaged = Self.Has_Fragment(FMars_Tag_Fishing_Engaged);
        const auto WasEngaged = IsEngaged;
        auto IsTransitioning = Self.Has_Fragment(FMars_Tag_Fishing_Transitioning);
        const auto WasTransitioning = IsTransitioning;
        const auto PhaseBefore = InState.Phase;
        auto PresenceChanged = false;
        auto BiteNow = false;
        auto Hooked = false;
        auto LaunchVelocity = TOptional<FVector>();
        auto Collected = TOptional<FMars_Fishing_Catch>();

        if (HasDisengage)
        {
            IsEngaged = false;
            InState.Reel = EMars_Fishing_Reel::Released;
            utils_fishing_requests::Rig(InState);
        }

        if (HasEngage)
        {
            IsEngaged = true;
            InState.Clock.PhaseSeconds = 0.0f;
        }

        if (HasLeave && (InState.Presence == EMars_Fishing_Presence::Open || InState.Presence == EMars_Fishing_Presence::Arriving))
        {
            InState.Presence = EMars_Fishing_Presence::Leaving;
            InState.Clock.PresenceLeft = Spec.Presence.LeaveSeconds;
            IsTransitioning = true;
            PresenceChanged = true;
        }

        if (HasReset)
        { utils_fishing_requests::Rig(InState); }

        if (HasForceBite && InState.Phase == EMars_Fishing_Phase::Waiting)
        {
            utils_fishing_requests::Bite(InState, Spec.Bite);
            BiteNow = true;
        }

        if (HasForceLand && InState.Phase == EMars_Fishing_Phase::Reeling)
        { InState.Line.LengthCm = 0.0f; }

        if (HasAim)
        {
            InState.Aim.YawDeg = Math::Clamp(Aim.YawDeg, -Spec.Launch.YawHalfAngleDeg, Spec.Launch.YawHalfAngleDeg);
            InState.Aim.PitchDeg = Math::Clamp(Aim.PitchDeg, -Spec.Launch.PitchRangeDeg, Spec.Launch.PitchRangeDeg);
        }

        const auto CanCast = IsEngaged && InState.Phase == EMars_Fishing_Phase::Idle && InState.Presence == EMars_Fishing_Presence::Open;
        if (HasCast && CanCast)
        {
            auto Query = FMars_Fishing_CastQuery();
            Query.Origin = Self.Get_AnchorWorld();
            Query.Forward = utils_fishing::Make_AimForward(utils_transform::Get_EntityCurrentTransform(Spec.Setup.Frame), InState.Aim.YawDeg);
            Query.PitchDeg = Spec.Launch.LaunchPitchDeg + InState.Aim.PitchDeg;
            Query.DistanceCm = Math::Lerp(Spec.Launch.MinDistanceCm, Spec.Launch.MaxDistanceCm, Math::Clamp(CastRequest.Power, 0.0f, 1.0f));
            Query.GravityCmPerS2 = Spec.Launch.GravityCmPerS2;
            Query.SurfaceZ = Spec.Water.SurfaceZ;

            InState.Bait.Position = Query.Origin;
            InState.Bait.Velocity = utils_fishing::Make_LaunchVelocity(Query);
            InState.Bait.BobPhase = 0.0f;
            InState.Bait.DipCm = 0.0f;
            InState.Line = FMars_Fishing_Line();
            utils_fishing_requests::Enter(InState, EMars_Fishing_Phase::Casting);
            LaunchVelocity = TOptional<FVector>(InState.Bait.Velocity);
        }

        if (HasHook && InState.Phase == EMars_Fishing_Phase::Bite)
        {
            InState.Bait.DipCm = 0.0f;
            InState.Line.Tension = Spec.Reel.HookTension;
            InState.Clock.HookSetLeft = Spec.Reel.HookSetSeconds;
            utils_fishing_requests::Enter(InState, EMars_Fishing_Phase::Hooked);
            Hooked = true;
        }

        // The reel is only in a hand while engaged.
        if (IsEngaged && HasReelRelease)
        { InState.Reel = EMars_Fishing_Reel::Released; }

        if (IsEngaged && HasReelHold)
        { InState.Reel = EMars_Fishing_Reel::Held; }

        if (HasCollect && InState.Phase == EMars_Fishing_Phase::Landed)
        {
            InState.Tally += 1;
            Collected = TOptional<FMars_Fishing_Catch>(InState.Catch);
            utils_fishing_requests::Rig(InState);
        }

        const auto Phase = InState.Phase;
        const auto Presence = InState.Presence;

        // InState is not read past this line: the tags move, and a listener may add fragments to the station.
        if (IsEngaged && WasEngaged == false)
        { Self.Add_Fragment(FMars_Tag_Fishing_Engaged()); }
        else if (IsEngaged == false && WasEngaged)
        { Self.Request_TryRemove(FMars_Tag_Fishing_Engaged); }

        if (IsTransitioning && WasTransitioning == false)
        { Self.Add_Fragment(FMars_Tag_Fishing_Transitioning()); }

        if (Self.Has_Fragment(FMars_Fragment_Fishing_Signals) == false)
        { return; }

        auto& Signals = Self.Get_Fragment(FMars_Fragment_Fishing_Signals);
        if (LaunchVelocity.IsSet())
        { Signals.OnCast.Broadcast(Self, LaunchVelocity.GetValue()); }

        if (BiteNow)
        { Signals.OnBite.Broadcast(Self); }

        if (Hooked)
        { Signals.OnBiteEnded.Broadcast(Self, EMars_Fishing_BiteResult::Hooked); }

        if (Collected.IsSet())
        { Signals.OnCollected.Broadcast(Self, Collected.GetValue()); }

        if (Phase != PhaseBefore)
        { Signals.OnPhaseChanged.Broadcast(Self, Phase); }

        if (PresenceChanged)
        { Signals.OnPresenceChanged.Broadcast(Self, Presence); }
    }
}

// Shared state moves for the two Fishing processors: a phase entry restarts the phase clock; a re-rig pulls everything in.
namespace utils_fishing_requests
{
    void Enter(FMars_Fragment_Fishing& InOutState, EMars_Fishing_Phase InPhase)
    {
        InOutState.Phase = InPhase;
        InOutState.Clock.PhaseSeconds = 0.0f;
    }

    // Back to Idle: no line out, no fish, no catch. The aim, the tally, the presence and the rng stay.
    void Rig(FMars_Fragment_Fishing& InOutState)
    {
        InOutState.Bait = FMars_Fishing_Bait();
        InOutState.Line = FMars_Fishing_Line();
        InOutState.Run = FMars_Fishing_Run();
        InOutState.Catch = FMars_Fishing_Catch();
        InOutState.Clock.BiteAtSeconds = 0.0f;
        InOutState.Clock.WindowLeft = 0.0f;
        InOutState.Clock.HookSetLeft = 0.0f;
        Enter(InOutState, EMars_Fishing_Phase::Idle);
    }

    // A fish takes the bait: the window opens and the float dips.
    void Bite(FMars_Fragment_Fishing& InOutState, const FMars_Fishing_BiteSpec& InBite)
    {
        InOutState.Clock.WindowLeft = InBite.HookWindowSeconds;
        InOutState.Bait.DipCm = InBite.DipCm;
        Enter(InOutState, EMars_Fishing_Phase::Bite);
    }
}
