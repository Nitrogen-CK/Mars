// The Root Maw's arbiter: Cancel -> TakeHit -> Stop -> Drive -> SetStance -> Gape -> Start, each kind in arrival order.
// A Start is admitted only when Get_Admission answers Admitted at drain time (so a second Start in one drain finds the first
// running and is dropped). Phase changes broadcast OnActionPhase after the state is written.
class UMars_Processor_RootMaw_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_RootMaw_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_RootMaw);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_RootMaw_Requests& InRequests)
    {
        auto Self = InHandle.As_RootMaw();

        TArray<FMars_Request_RootMaw_Cancel> CancelRequests = InRequests.CancelRequests;
        TArray<FMars_Request_RootMaw_TakeHit> TakeHitRequests = InRequests.TakeHitRequests;
        TArray<FMars_Request_RootMaw_Stop> StopRequests = InRequests.StopRequests;
        TArray<FMars_Request_RootMaw_Drive> DriveRequests = InRequests.DriveRequests;
        TArray<FMars_Request_RootMaw_SetStance> SetStanceRequests = InRequests.SetStanceRequests;
        TArray<FMars_Request_RootMaw_Gape> GapeRequests = InRequests.GapeRequests;
        TArray<FMars_Request_RootMaw_Start> StartRequests = InRequests.StartRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_RootMaw_Requests);

        for (const auto& Request : CancelRequests)
        { HandleCancel(Self); }

        for (const auto& Request : TakeHitRequests)
        { HandleTakeHit(Self, Request); }

        for (const auto& Request : StopRequests)
        { Self.Get_Fragment(FMars_Fragment_RootMaw_Drive) = FMars_Fragment_RootMaw_Drive(); }

        for (const auto& Request : DriveRequests)
        {
            auto& Drive = Self.Get_Fragment(FMars_Fragment_RootMaw_Drive);
            const auto Valid = Math::IsFinite(Request.Speed) && Request.Speed >= 0.0f && Request.Direction.ContainsNaN() == false;
            if (ck::EnsureIfNot(Valid, f"[RootMaw] [{Self.ToString()}] was asked to drive at [{Request.Speed}] along [{Request.Direction.ToString()}]"))
            { continue; }

            Drive.Direction = Request.Direction.GetSafeNormal();
            Drive.Speed = Drive.Direction.IsNearlyZero() ? 0.0f : Request.Speed;
        }

        // The stance is a target; Emerge runs to it in the tick (which broadcasts OnStance when it gets there).
        for (const auto& Request : SetStanceRequests)
        { Self.Get_Fragment(FMars_Fragment_RootMaw_Posture).Stance = Request.Stance; }

        for (const auto& Request : GapeRequests)
        {
            if (ck::EnsureIfNot(Math::IsFinite(Request.Amount), f"[RootMaw] [{Self.ToString()}] was asked to gape [{Request.Amount}]"))
            { continue; }

            Self.Get_Fragment(FMars_Fragment_RootMaw_Mouth).Gape = Math::Clamp(Request.Amount, 0.0f, 1.0f);
        }

        for (const auto& Request : StartRequests)
        { HandleStart(Self, Request); }
    }

    private void HandleCancel(FCk_Handle_RootMaw& InSelf)
    {
        const auto Ended = utils_root_maw::End_Action(InSelf);
        if (Ended != EMars_RootMaw_Action::None)
        { utils_root_maw::Broadcast_ActionPhase(InSelf, Ended, EMars_RootMaw_ActionPhase::None); }
    }

    // Unless dead: a flinch (the jaw slams shut, or pops wide if the blow found it buried; a bite's windup starts over, an
    // active or recovering bite runs on); buried it is startled up; and the blow's instigator becomes its target when that
    // is a valid Hostile entity and it was buried or held no target.
    private void HandleTakeHit(FCk_Handle_RootMaw& InSelf, const FMars_Request_RootMaw_TakeHit& InRequest)
    {
        if (InSelf.Get_IsDead())
        { return; }

        const auto Buried = InSelf.Get_Stance() == EMars_RootMaw_Stance::Buried;
        const auto From = Get_BlowFrom(InSelf, InRequest.Event);

        auto& Hurt = InSelf.Get_Fragment(FMars_Fragment_RootMaw_Hurt);
        Hurt.FlinchLeft = InSelf.Get_Spec().Vitals.FlinchSeconds;
        Hurt.FlinchCount += 1;
        Hurt.FlinchFrom = From;
        Hurt.Startled = Hurt.Startled || Buried;

        InSelf.Get_Fragment(FMars_Fragment_RootMaw_Mouth).JawOpen = Buried ? 1.0f : 0.0f;

        auto& Action = InSelf.Get_Fragment(FMars_Fragment_RootMaw_Action);
        if (Action.Phase == EMars_RootMaw_ActionPhase::Windup)
        {
            Action.PhaseElapsed = 0.0f;
            Action.JawAtStart = 0.0f;
        }

        const auto Instigator = InRequest.Event.Source.Instigator;
        const auto Provoked = utils_root_maw::Get_IsTargetValid(Instigator) &&
            utils_relationship::Get_AttitudeTowards(InSelf, Instigator) == ECk_RelationshipAttitude::Hostile;
        if (Provoked && (Buried || InSelf.Get_HasTarget() == false))
        {
            auto& Targeting = InSelf.Get_Fragment(FMars_Fragment_RootMaw_Targeting);
            Targeting.Target = Instigator;
            Targeting.SenseClock = 0.0f;
        }
    }

    // Along the ground from the Maw toward the blow: its hit location when it has one, else its instigator.
    private FVector Get_BlowFrom(const FCk_Handle_RootMaw& InSelf, FMars_DamageEvent InEvent) const
    {
        auto Source = InEvent.Hit.Location;
        if (Source.IsNearlyZero())
        {
            const auto Instigator = InEvent.Source.Instigator;
            if (utils_root_maw::Get_IsTargetValid(Instigator) == false)
            { return FVector::ZeroVector; }

            Source = utils_transform::Get_EntityCurrentLocation(Instigator.As_Transform());
        }

        return utils_root_maw::Get_Tangent(Source - InSelf.Get_Location(), InSelf.Get_SurfaceUp());
    }

    private void HandleStart(FCk_Handle_RootMaw& InSelf, const FMars_Request_RootMaw_Start& InRequest)
    {
        if (InRequest.Action == EMars_RootMaw_Action::None)
        { return; }

        if (InSelf.Get_Admission(InRequest.Action, InRequest.Target) != EMars_RootMaw_Admission::Admitted)
        { return; }

        const auto Toward = utils_transform::Get_EntityCurrentLocation(InRequest.Target.As_Transform()) - InSelf.Get_Location();
        const auto Committed = utils_root_maw::Get_Tangent(Toward, InSelf.Get_SurfaceUp());
        const auto Jaw = InSelf.Get_JawOpen();

        auto& Action = InSelf.Get_Fragment(FMars_Fragment_RootMaw_Action);
        Action.Kind = InRequest.Action;
        Action.Phase = EMars_RootMaw_ActionPhase::Windup;
        Action.PhaseElapsed = 0.0f;
        Action.Generation += 1;
        Action.Target = InRequest.Target;
        Action.HitZones.Reset();
        Action.JawAtStart = Jaw;
        if (Committed.IsNearlyZero() == false)
        { Action.CommittedDirection = Committed; }

        utils_root_maw::Broadcast_ActionPhase(InSelf, InRequest.Action, EMars_RootMaw_ActionPhase::Windup);
    }
}

namespace utils_root_maw
{
    // Ends the running action without recovery and starts its cooldown; returns what ended (None when nothing ran). The
    // caller broadcasts.
    EMars_RootMaw_Action End_Action(FCk_Handle_RootMaw& InSelf)
    {
        auto& Action = InSelf.Get_Fragment(FMars_Fragment_RootMaw_Action);
        const auto Ended = Action.Kind;
        if (Ended == EMars_RootMaw_Action::None)
        { return Ended; }

        Action.BiteCooldown = InSelf.Get_Spec().Bite.Timing.CooldownSeconds;
        Action.Kind = EMars_RootMaw_Action::None;
        Action.Phase = EMars_RootMaw_ActionPhase::None;
        Action.PhaseElapsed = 0.0f;
        Action.Target = FCk_Handle();
        Action.HitZones.Reset();
        return Ended;
    }

    void Broadcast_ActionPhase(FCk_Handle_RootMaw& InSelf, EMars_RootMaw_Action InAction, EMars_RootMaw_ActionPhase InPhase)
    {
        if (InSelf.Has_Fragment(FMars_Fragment_RootMaw_Signals))
        { InSelf.Get_Fragment(FMars_Fragment_RootMaw_Signals).OnActionPhase.Broadcast(InSelf, InAction, InPhase); }
    }
}
