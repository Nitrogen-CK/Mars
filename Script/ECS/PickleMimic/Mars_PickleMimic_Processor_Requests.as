// The pickle mimic's arbiter: Cancel -> Stop -> Drive -> SetStance -> Gape -> Start, each kind in arrival order. A Start is
// admitted only when Get_Admission answers Admitted at drain time (so a second Start in one drain finds the first running
// and is dropped). Phase changes broadcast OnActionPhase after the state is written.
class UMars_Processor_PickleMimic_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_PickleMimic_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_PickleMimic);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_PickleMimic_Requests& InRequests)
    {
        auto Self = InHandle.As_PickleMimic();

        TArray<FMars_Request_PickleMimic_Cancel> CancelRequests = InRequests.CancelRequests;
        TArray<FMars_Request_PickleMimic_Stop> StopRequests = InRequests.StopRequests;
        TArray<FMars_Request_PickleMimic_Drive> DriveRequests = InRequests.DriveRequests;
        TArray<FMars_Request_PickleMimic_SetStance> SetStanceRequests = InRequests.SetStanceRequests;
        TArray<FMars_Request_PickleMimic_Gape> GapeRequests = InRequests.GapeRequests;
        TArray<FMars_Request_PickleMimic_Start> StartRequests = InRequests.StartRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_PickleMimic_Requests);

        for (const auto& Request : CancelRequests)
        { HandleCancel(Self); }

        for (const auto& Request : StopRequests)
        { Self.Get_Fragment(FMars_Fragment_PickleMimic_Drive) = FMars_Fragment_PickleMimic_Drive(); }

        for (const auto& Request : DriveRequests)
        {
            auto& Drive = Self.Get_Fragment(FMars_Fragment_PickleMimic_Drive);
            const auto Valid = Math::IsFinite(Request.Speed) && Request.Speed >= 0.0f && Request.Direction.ContainsNaN() == false;
            if (ck::EnsureIfNot(Valid, f"[PickleMimic] [{Self.ToString()}] was asked to drive at [{Request.Speed}] along [{Request.Direction.ToString()}]"))
            { continue; }

            Drive.Direction = Request.Direction.GetSafeNormal();
            Drive.Speed = Drive.Direction.IsNearlyZero() ? 0.0f : Request.Speed;
        }

        // The stance is a target; Rise runs to it in the tick (which broadcasts OnStance when it gets there).
        for (const auto& Request : SetStanceRequests)
        { Self.Get_Fragment(FMars_Fragment_PickleMimic_Posture).Stance = Request.Stance; }

        for (const auto& Request : GapeRequests)
        {
            if (ck::EnsureIfNot(Math::IsFinite(Request.Amount), f"[PickleMimic] [{Self.ToString()}] was asked to gape [{Request.Amount}]"))
            { continue; }

            Self.Get_Fragment(FMars_Fragment_PickleMimic_Mouth).Gape = Math::Clamp(Request.Amount, 0.0f, 1.0f);
        }

        for (const auto& Request : StartRequests)
        { HandleStart(Self, Request); }
    }

    private void HandleCancel(FCk_Handle_PickleMimic& InSelf)
    {
        const auto Ended = utils_pickle_mimic::End_Action(InSelf);
        if (Ended != EMars_PickleMimic_Action::None)
        { utils_pickle_mimic::Broadcast_ActionPhase(InSelf, Ended, EMars_PickleMimic_ActionPhase::None); }
    }

    private void HandleStart(FCk_Handle_PickleMimic& InSelf, const FMars_Request_PickleMimic_Start& InRequest)
    {
        if (InRequest.Action == EMars_PickleMimic_Action::None)
        { return; }

        if (InSelf.Get_Admission(InRequest.Action, InRequest.Target) != EMars_PickleMimic_Admission::Admitted)
        { return; }

        const auto Toward = utils_transform::Get_EntityCurrentLocation(InRequest.Target.As_Transform()) - InSelf.Get_Location();
        const auto Committed = utils_pickle_mimic::Get_Tangent(Toward, InSelf.Get_SurfaceUp());
        const auto Lid = InSelf.Get_LidOpen();

        auto& Action = InSelf.Get_Fragment(FMars_Fragment_PickleMimic_Action);
        Action.Kind = InRequest.Action;
        Action.Phase = EMars_PickleMimic_ActionPhase::Windup;
        Action.PhaseElapsed = 0.0f;
        Action.Generation += 1;
        Action.Target = InRequest.Target;
        Action.HitZones.Reset();
        Action.LidAtStart = Lid;
        if (Committed.IsNearlyZero() == false)
        { Action.CommittedDirection = Committed; }

        utils_pickle_mimic::Broadcast_ActionPhase(InSelf, InRequest.Action, EMars_PickleMimic_ActionPhase::Windup);
    }
}

namespace utils_pickle_mimic
{
    // Ends the running action without recovery and starts its cooldown; returns what ended (None when nothing ran). The
    // caller broadcasts.
    EMars_PickleMimic_Action End_Action(FCk_Handle_PickleMimic& InSelf)
    {
        auto& Action = InSelf.Get_Fragment(FMars_Fragment_PickleMimic_Action);
        const auto Ended = Action.Kind;
        if (Ended == EMars_PickleMimic_Action::None)
        { return Ended; }

        Action.BiteCooldown = InSelf.Get_Spec().Bite.Timing.CooldownSeconds;
        Action.Kind = EMars_PickleMimic_Action::None;
        Action.Phase = EMars_PickleMimic_ActionPhase::None;
        Action.PhaseElapsed = 0.0f;
        Action.Target = FCk_Handle();
        Action.HitZones.Reset();
        return Ended;
    }

    void Broadcast_ActionPhase(FCk_Handle_PickleMimic& InSelf, EMars_PickleMimic_Action InAction, EMars_PickleMimic_ActionPhase InPhase)
    {
        if (InSelf.Has_Fragment(FMars_Fragment_PickleMimic_Signals))
        { InSelf.Get_Fragment(FMars_Fragment_PickleMimic_Signals).OnActionPhase.Broadcast(InSelf, InAction, InPhase); }
    }
}
