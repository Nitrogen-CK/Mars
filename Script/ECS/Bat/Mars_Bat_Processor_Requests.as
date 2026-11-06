// The bat's arbiter: Fall -> TakeHit -> CancelSwoop -> RouteResult -> Hold -> SetPhase -> FlyTo -> StartSwoop ->
// ReleaseRoost -> EndSearch, each kind in arrival order. SetPhase runs before FlyTo so a route issued by a state's enter task is stamped
// with that state's phase (Route.IssuedIn). A StartSwoop is admitted only when Get_SwoopAdmission answers Admitted at drain
// time. Signals broadcast after the state they report is written.
class UMars_Processor_Bat_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Bat_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Bat);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Bat_Requests& InRequests)
    {
        auto Self = InHandle.As_Bat();

        TArray<FMars_Request_Bat_Fall> FallRequests = InRequests.FallRequests;
        TArray<FMars_Request_Bat_TakeHit> TakeHitRequests = InRequests.TakeHitRequests;
        TArray<FMars_Request_Bat_CancelSwoop> CancelSwoopRequests = InRequests.CancelSwoopRequests;
        TArray<FMars_Request_Bat_RouteResult> RouteResultRequests = InRequests.RouteResultRequests;
        TArray<FMars_Request_Bat_Hold> HoldRequests = InRequests.HoldRequests;
        TArray<FMars_Request_Bat_SetPhase> SetPhaseRequests = InRequests.SetPhaseRequests;
        TArray<FMars_Request_Bat_FlyTo> FlyToRequests = InRequests.FlyToRequests;
        TArray<FMars_Request_Bat_StartSwoop> StartSwoopRequests = InRequests.StartSwoopRequests;
        TArray<FMars_Request_Bat_ReleaseRoost> ReleaseRoostRequests = InRequests.ReleaseRoostRequests;
        TArray<FMars_Request_Bat_EndSearch> EndSearchRequests = InRequests.EndSearchRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Bat_Requests);

        if (utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        for (const auto& Request : FallRequests)
        { HandleFall(Self); }

        for (const auto& Request : TakeHitRequests)
        { HandleTakeHit(Self, Request); }

        for (const auto& Request : CancelSwoopRequests)
        { HandleCancelSwoop(Self, Request); }

        for (const auto& Request : RouteResultRequests)
        { HandleRouteResult(Self, Request); }

        for (const auto& Request : HoldRequests)
        { HandleHold(Self); }

        for (const auto& Request : SetPhaseRequests)
        { HandleSetPhase(Self, Request); }

        for (const auto& Request : FlyToRequests)
        { HandleFlyTo(Self, Request); }

        for (const auto& Request : StartSwoopRequests)
        { HandleStartSwoop(Self, Request); }

        for (const auto& Request : ReleaseRoostRequests)
        { HandleReleaseRoost(Self); }

        for (const auto& Request : EndSearchRequests)
        { Self.Get_Fragment(FMars_Fragment_Bat).LastKnown.Reset(); }
    }

    // Latched: the agent stops and leaves the crowd, the integrator stops (the tick writes the root from here on), a running
    // swoop ends Died, the hurt clocks clear, the target drops, and it falls from where it flew at the speed it had
    // (clamped to Flight.SwoopSpeed).
    private void HandleFall(FCk_Handle_Bat& InSelf)
    {
        if (InSelf.Get_IsDown())
        { return; }

        utils_bat::End_Swoop(InSelf, EMars_Bat_SwoopCancel::Died);

        auto Agent = InSelf.Get_Agent();
        utils_crowd_agent::Request_Stop(Agent);
        utils_crowd_agent::Request_EnableDisable(Agent, FCk_Request_CrowdAgent_EnableDisable(ECk_EnableDisable::Disable));
        FCk_Handle Root = InSelf;
        utils_euler_integrator::Request_Stop(Root);

        auto& State = InSelf.Get_Fragment(FMars_Fragment_Bat);
        State.Hurt.HitLeft = 0.0f;
        State.Hurt.StunLeft = 0.0f;
        State.Route.Outcome = EMars_Bat_RouteOutcome::None;
        // Seeded with the speed it flew at, never faster than its swoop: the measured velocity is a frame difference and
        // spikes when a frame hitches.
        State.Fall.Velocity = State.Telemetry.Velocity.GetClampedToMaxSize(InSelf.Get_Spec().Flight.SwoopSpeed);
        State.Fall.Elapsed = 0.0f;
        const auto HadTarget = ck::IsValid(State.Target);
        State.Target = FCk_Handle();
        State.LastKnown.Reset();

        utils_bat::Set_Phase(InSelf, EMars_Bat_Phase::Falling);
        if (HadTarget)
        { utils_bat::Broadcast_TargetChanged(InSelf); }
    }

    // Unless it is down: a flinch (Hit) or a stun (StunDamage or more, or a blow while stunned), the agent stops where it
    // is, and a telegraphed or committed swoop ends Interrupted (a recovering one just ends).
    private void HandleTakeHit(FCk_Handle_Bat& InSelf, const FMars_Request_Bat_TakeHit& InRequest)
    {
        if (InSelf.Get_IsDead() || InSelf.Get_IsDown())
        { return; }

        utils_bat::End_Swoop(InSelf, EMars_Bat_SwoopCancel::Interrupted);
        utils_bat::Stop_Agent(InSelf);

        const auto Timing = InSelf.Get_Spec().Timing;
        auto& Hurt = InSelf.Get_Fragment(FMars_Fragment_Bat).Hurt;
        Hurt.HitCount += 1;
        const auto Stun = InRequest.Event.Amount >= Timing.StunDamage || Hurt.StunLeft > 0.0f;
        if (Stun)
        { Hurt.StunLeft = Timing.StunSeconds; }
        else
        { Hurt.HitLeft = Timing.HitSeconds; }

        utils_bat::Set_Phase(InSelf, Stun ? EMars_Bat_Phase::Stunned : EMars_Bat_Phase::Hit);
    }

    private void HandleCancelSwoop(FCk_Handle_Bat& InSelf, const FMars_Request_Bat_CancelSwoop& InRequest)
    {
        const auto Stage = InSelf.Get_SwoopStage();
        if (Stage != EMars_Bat_SwoopStage::Telegraphing && Stage != EMars_Bat_SwoopStage::Committed)
        { return; }

        utils_bat::End_Swoop(InSelf, InRequest.Reason);
        utils_bat::Stop_Agent(InSelf);
    }

    // Only a Pending route takes an answer, so the first of the path's and the agent's answers wins and a late one for a
    // dropped route is ignored. A failure stops the agent: a flyer must not follow CkCrowd's Recast fallback route.
    private void HandleRouteResult(FCk_Handle_Bat& InSelf, const FMars_Request_Bat_RouteResult& InRequest)
    {
        auto& State = InSelf.Get_Fragment(FMars_Fragment_Bat);
        if (State.Route.Outcome != EMars_Bat_RouteOutcome::Pending)
        { return; }

        // A late crowd answer for a superseded MoveTo (the agent reports its active correlation id = our generation).
        if (InRequest.Generation.IsSet() && InRequest.Generation.GetValue() != State.Route.Generation)
        { return; }

        State.Route.Outcome = InRequest.Outcome;
        const auto Failed = utils_bat::Get_IsRouteFailure(InRequest.Outcome);
        const auto DropTarget = Failed && utils_bat::Try_DropApproachTarget(InSelf);
        const auto Generation = InSelf.Get_Fragment(FMars_Fragment_Bat).Route.Generation;
        if (Failed)
        { utils_bat::Stop_Agent(InSelf); }

        utils_bat::Broadcast_RouteOutcome(InSelf, Generation, InRequest.Outcome);
        if (DropTarget)
        { utils_bat::Broadcast_TargetChanged(InSelf); }
    }

    private void HandleHold(FCk_Handle_Bat& InSelf)
    {
        if (InSelf.Get_IsDown() || InSelf.Get_SwoopStage() != EMars_Bat_SwoopStage::None)
        { return; }

        utils_bat::Stop_Agent(InSelf);
        InSelf.Get_Fragment(FMars_Fragment_Bat).Route.Outcome = EMars_Bat_RouteOutcome::None;
    }

    private void HandleSetPhase(FCk_Handle_Bat& InSelf, const FMars_Request_Bat_SetPhase& InRequest)
    {
        if (ck::EnsureIfNot(utils_bat::Get_IsKernelPhase(InRequest.Phase) == false,
            f"[Bat] [{InSelf.ToString()}] was asked to enter the kernel's own phase [{InRequest.Phase}]"))
        { return; }

        // Screeching only renames a running telegraph (presentation): nothing else in the ledger changes.
        if (InRequest.Phase == EMars_Bat_Phase::Screeching)
        {
            if (InSelf.Get_IsDown() == false && InSelf.Get_IsHurt() == false &&
                InSelf.Get_SwoopStage() == EMars_Bat_SwoopStage::Telegraphing && InSelf.Get_Phase() == EMars_Bat_Phase::Telegraphing)
            { utils_bat::Set_Phase(InSelf, EMars_Bat_Phase::Screeching); }

            return;
        }

        // The kernel's phases win: the control layer catches up once they end.
        if (InSelf.Get_IsDown() || InSelf.Get_IsHurt() || InSelf.Get_SwoopStage() != EMars_Bat_SwoopStage::None)
        { return; }

        utils_bat::Set_Phase(InSelf, InRequest.Phase);
    }

    private void HandleFlyTo(FCk_Handle_Bat& InSelf, const FMars_Request_Bat_FlyTo& InRequest)
    {
        const auto Valid = InRequest.Goal.ContainsNaN() == false && Math::IsFinite(InRequest.Speed) && InRequest.Speed > 0.0f;
        if (ck::EnsureIfNot(Valid, f"[Bat] [{InSelf.ToString()}] was asked to fly to [{InRequest.Goal.ToString()}] at [{InRequest.Speed}]"))
        { return; }

        if (InSelf.Get_IsDown() || InSelf.Get_IsHurt() || InSelf.Get_SwoopStage() != EMars_Bat_SwoopStage::None)
        { return; }

        utils_bat::Issue_Move(InSelf, FMars_Request_Bat_FlyTo(InRequest.Goal, InRequest.Speed));
    }

    private void HandleStartSwoop(FCk_Handle_Bat& InSelf, const FMars_Request_Bat_StartSwoop& InRequest)
    {
        if (InSelf.Get_SwoopAdmission(InRequest.Target) != EMars_Bat_SwoopAdmission::Admitted)
        { return; }

        utils_bat::Stop_Agent(InSelf);

        auto& State = InSelf.Get_Fragment(FMars_Fragment_Bat);
        State.Route.Outcome = EMars_Bat_RouteOutcome::None;

        auto& Swoop = State.Swoop;
        Swoop.Stage = EMars_Bat_SwoopStage::Telegraphing;
        Swoop.Generation += 1;
        Swoop.StageElapsed = 0.0f;
        Swoop.Target = InRequest.Target;
        Swoop.From = InSelf.Get_Location();
        Swoop.HitZones.Reset();

        utils_bat::Set_Phase(InSelf, EMars_Bat_Phase::Telegraphing);
    }

    // Latched: the first hands an owned roost back (its own counter records it) and marks the claim Released.
    private void HandleReleaseRoost(FCk_Handle_Bat& InSelf)
    {
        auto& Perch = InSelf.Get_Fragment(FMars_Fragment_Bat).Perch;
        if (Perch.Claim == EMars_Bat_RoostClaim::Released)
        { return; }

        const auto Owned = Perch.Claim == EMars_Bat_RoostClaim::Held || Perch.Claim == EMars_Bat_RoostClaim::Pending;
        if (Owned && utils_bat::Get_IsRoost(Perch.Owner))
        { utils_bat::Request_ReleaseRoost(Perch.Owner, FMars_Request_BatRoost_Release(InSelf)); }

        Perch.Claim = EMars_Bat_RoostClaim::Released;
    }
}

// The kernel's shared writes (the request drain and the tick). Only the bat's processors call these.
namespace utils_bat
{
    void Set_Phase(FCk_Handle_Bat& InSelf, EMars_Bat_Phase InPhase)
    {
        auto& State = InSelf.Get_Fragment(FMars_Fragment_Bat);
        const auto From = State.Phase;
        if (From == InPhase)
        { return; }

        State.Phase = InPhase;
        State.PhaseClock = 0.0f;

        if (InSelf.Has_Fragment(FMars_Fragment_Bat_Signals))
        { InSelf.Get_Fragment(FMars_Fragment_Bat_Signals).OnPhaseChanged.Broadcast(InSelf, From, InPhase); }
    }

    void Stop_Agent(FCk_Handle_Bat& InSelf)
    {
        auto Agent = InSelf.Get_Agent();
        if (ck::IsValid(Agent))
        { utils_crowd_agent::Request_Stop(Agent); }
    }

    // Ends a telegraphed or committed swoop as InReason (broadcast OnSwoopCancelled) or a recovering one silently; the
    // cooldown starts either way. Nothing when no swoop runs.
    void End_Swoop(FCk_Handle_Bat& InSelf, EMars_Bat_SwoopCancel InReason)
    {
        auto& Swoop = InSelf.Get_Fragment(FMars_Fragment_Bat).Swoop;
        const auto Stage = Swoop.Stage;
        if (Stage == EMars_Bat_SwoopStage::None)
        { return; }

        const auto Generation = Swoop.Generation;
        Swoop.Stage = EMars_Bat_SwoopStage::None;
        Swoop.StageElapsed = 0.0f;
        Swoop.Target = FCk_Handle();
        Swoop.Cooldown = InSelf.Get_Spec().Swoop.Timing.CooldownSeconds;
        if (Stage == EMars_Bat_SwoopStage::Recovering)
        { return; }

        Swoop.Cancelled += 1;
        if (InSelf.Has_Fragment(FMars_Fragment_Bat_Signals))
        { InSelf.Get_Fragment(FMars_Fragment_Bat_Signals).OnSwoopCancelled.Broadcast(InSelf, Generation, InReason); }
    }

    // A new route generation toward InOrder.Goal: refused at once with an explicit outcome when there is no volume, no
    // bake or the goal is not in free space; otherwise the agent's max speed and MoveTo, Pending until answered. A FlyTo
    // to the goal already Pending at the same speed is not re-issued.
    void Issue_Move(FCk_Handle_Bat& InSelf, FMars_Request_Bat_FlyTo InOrder)
    {
        auto& State = InSelf.Get_Fragment(FMars_Fragment_Bat);
        auto& Route = State.Route;
        if (Route.Outcome == EMars_Bat_RouteOutcome::Pending && (Route.Goal - InOrder.Goal).Size() < 1.0 &&
            Math::Abs(Route.Speed - InOrder.Speed) < 0.5f && Route.IssuedIn == State.Phase)
        { return; }

        Route.Generation += 1;
        Route.Goal = InOrder.Goal;
        Route.Speed = InOrder.Speed;
        Route.IssuedIn = State.Phase;

        const auto Volume = Route.Volume;
        auto Outcome = EMars_Bat_RouteOutcome::Pending;
        if (ck::Is_NOT_Valid(Volume))
        { Outcome = EMars_Bat_RouteOutcome::NoVolume; }
        else if (utils_voxel_nav_volume::Get_IsBuilt(Volume) == false)
        { Outcome = EMars_Bat_RouteOutcome::NoBake; }
        else if (utils_voxel_nav_volume::Get_IsPointFree(Volume, InOrder.Goal) == false)
        { Outcome = EMars_Bat_RouteOutcome::EndpointUnresolvable; }

        Route.Outcome = Outcome;
        const auto Generation = Route.Generation;
        if (Outcome != EMars_Bat_RouteOutcome::Pending)
        {
            // Refused at once: the same as a failure answered later (an Approach drops its target), or the Approach state
            // would wait forever on a route that was never issued (seen in PIE: NoBake before the volume's first bake).
            const auto DropTarget = Try_DropApproachTarget(InSelf);
            Stop_Agent(InSelf);
            Broadcast_RouteOutcome(InSelf, Generation, Outcome);
            if (DropTarget)
            { Broadcast_TargetChanged(InSelf); }

            return;
        }

        auto Agent = InSelf.Get_Agent();
        utils_crowd_agent::Request_SetMaxSpeed(Agent, InOrder.Speed);
        auto MoveTo = FCk_Request_CrowdAgent_MoveTo(InOrder.Goal);
        MoveTo.Set_ForceRepath(true);
        // The agent keeps this as its active move correlation id; goal failures read it back (Bat_Setup) so a late answer
        // for an older generation is dropped.
        MoveTo.Set_CorrelationId(Generation);
        utils_crowd_agent::Request_MoveTo(Agent, MoveTo);
    }

    // A failed route while Approaching drops the target and ignores it for HoverRetrySeconds, remembering where it was last
    // sensed that the bat can fly to (Try_RememberLastKnown: a target that went where the bat cannot follow is searched for
    // at the last reachable spot). True when it dropped one (the caller broadcasts OnTargetChanged after its route outcome).
    bool Try_DropApproachTarget(FCk_Handle_Bat& InSelf)
    {
        auto& State = InSelf.Get_Fragment(FMars_Fragment_Bat);
        if (State.Phase != EMars_Bat_Phase::Approaching || ck::Is_NOT_Valid(State.Target))
        { return false; }

        Try_RememberLastKnown(InSelf, State.Target);
        State.Ignored = State.Target;
        State.IgnoreLeft = InSelf.Get_Spec().Timing.HoverRetrySeconds;
        State.Target = FCk_Handle();
        return true;
    }

    void Broadcast_RouteOutcome(FCk_Handle_Bat& InSelf, int32 InGeneration, EMars_Bat_RouteOutcome InOutcome)
    {
        if (InSelf.Has_Fragment(FMars_Fragment_Bat_Signals))
        { InSelf.Get_Fragment(FMars_Fragment_Bat_Signals).OnRouteOutcome.Broadcast(InSelf, InGeneration, InOutcome); }
    }

    void Broadcast_TargetChanged(FCk_Handle_Bat& InSelf)
    {
        if (InSelf.Has_Fragment(FMars_Fragment_Bat_Signals))
        { InSelf.Get_Fragment(FMars_Fragment_Bat_Signals).OnTargetChanged.Broadcast(InSelf, InSelf.Get_Fragment(FMars_Fragment_Bat).Target); }
    }

    void Broadcast_PerchLost(FCk_Handle_Bat& InSelf, FCk_Handle InOwner)
    {
        if (InSelf.Has_Fragment(FMars_Fragment_Bat_Signals))
        { InSelf.Get_Fragment(FMars_Fragment_Bat_Signals).OnPerchLost.Broadcast(InSelf, InOwner); }
    }
}

// The roost's arbiter: Release -> Claim, each kind in arrival order. A claim is granted only to a free roost (or to the
// bat already holding it); a release counts only from the claimant.
class UMars_Processor_BatRoost_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_BatRoost_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_BatRoost);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_BatRoost_Requests& InRequests)
    {
        TArray<FMars_Request_BatRoost_Release> ReleaseRequests = InRequests.ReleaseRequests;
        TArray<FMars_Request_BatRoost_Claim> ClaimRequests = InRequests.ClaimRequests;

        InHandle.Request_TryRemove(FMars_Fragment_BatRoost_Requests);

        auto& Roost = InHandle.Get_Fragment(FMars_Fragment_BatRoost);
        for (const auto& Request : ReleaseRequests)
        {
            if (Roost.Occupancy == EMars_BatRoost_Occupancy::Claimed && Roost.Claimant == Request.Bat)
            { utils_bat::Free_Roost(Roost); }
        }

        for (const auto& Request : ClaimRequests)
        {
            if (ck::Is_NOT_Valid(Request.Bat) || Roost.Occupancy == EMars_BatRoost_Occupancy::Claimed)
            { continue; }

            Roost.Occupancy = EMars_BatRoost_Occupancy::Claimed;
            Roost.Claimant = Request.Bat;
            Roost.ClaimCount += 1;
        }
    }
}

// Hands back a roost whose claimant has gone (destroyed without releasing): that is the teardown's release, counted like
// any other, so a bat's claim is released exactly once whichever way it ends.
class UMars_Processor_BatRoost_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_BatRoost);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_BatRoost& InRoost)
    {
        if (InRoost.Occupancy != EMars_BatRoost_Occupancy::Claimed)
        { return; }

        // Invalid: the entity is already gone; pending destroy: it is going.
        if (ck::IsValid(InRoost.Claimant) &&
            utils_entity_lifetime::Get_IsPendingDestroy(InRoost.Claimant, ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false)
        { return; }

        utils_bat::Free_Roost(InRoost);
    }
}

namespace utils_bat
{
    // The one place a roost is handed back.
    void Free_Roost(FMars_Fragment_BatRoost& InOutRoost)
    {
        InOutRoost.Occupancy = EMars_BatRoost_Occupancy::Free;
        InOutRoost.Claimant = FCk_Handle();
        InOutRoost.ReleaseCount += 1;
    }
}
