// One-shot per Dicing entity: binds the cleaver Mover's OnArrived, where a chop resolves. At the end pose (contact) the
// chop is judged and the cleaver sent back up; at the start pose (back up) the next press may chop. The Mover finds its
// Dicing through FMars_Fragment_Dicing_ChopLink (stamped by Add on the Mover entity).
class UMars_Processor_Dicing_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Dicing_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Dicing);
        Query.Require(FMars_Tag_Dicing_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Dicing& InState)
    {
        auto Self = InHandle.As_Dicing();

        auto Mover = Self.Get_Spec().Nodes.ChopMover;
        Mover.BindTo_OnArrived(FMars_Delegate_Mover_OnArrived(this, n"OnChopMoverArrived"));

        Self.Request_TryRemove(FMars_Tag_Dicing_NeedsSetup);
    }

    UFUNCTION()
    private void OnChopMoverArrived(FCk_Handle_Mover InMover, EMars_Mover_Pose InPose)
    {
        if (ck::EnsureIfNot(InMover.Has_Fragment(FMars_Fragment_Dicing_ChopLink),
            f"[Dicing] chop Mover [{InMover.ToString()}] carries no ChopLink"))
        { return; }

        // The station is being torn down with its cleaver.
        auto Dicing = InMover.Get_Fragment(FMars_Fragment_Dicing_ChopLink).Dicing;
        if (ck::Is_NOT_Valid(Dicing))
        { return; }

        auto& State = Dicing.Get_Fragment(FMars_Fragment_Dicing);
        if (State.IsChopping == false)
        { return; }

        if (InPose == EMars_Mover_Pose::Start)
        {
            State.IsChopping = false;
            return;
        }

        Resolve_Contact(Dicing, State);

        auto ChopMover = InMover;
        ChopMover.Request_MoveTo(FMars_Request_Mover_MoveTo(EMars_Mover_Pose::Start));
    }

    // An aligned chop counts; at ChopsPerState the pile advances one state (GreenPaste stays) and the band steps to the
    // next table entry. Writes land first, then OnStateChanged (+ OnRequestedStateReached on exactly the requested state),
    // OnBandMoved, OnChopResolved.
    private void Resolve_Contact(FCk_Handle_Dicing& InDicing, FMars_Fragment_Dicing& InState)
    {
        const auto Spec = InDicing.Get_Spec();
        const auto StartBand = utils_dicing::Get_BandCenterAt(Spec, InState.BandIndex);
        const auto Result = Math::Abs(InState.HandLateral - StartBand) <= Spec.BandHalfWidth
            ? EMars_Dicing_ChopResult::Aligned
            : EMars_Dicing_ChopResult::OffTheBand;

        auto StateChanged = false;
        if (Result == EMars_Dicing_ChopResult::Aligned)
        {
            InState.Pile.UsefulChops += 1;
            InState.Pile.ChopsInState += 1;

            if (InState.Pile.ChopsInState >= Spec.ChopsPerState && InState.Pile.MaterialState != EMars_Dicing_State::GreenPaste)
            {
                InState.Pile.MaterialState = utils_dicing::Get_NextState(InState.Pile.MaterialState);
                InState.Pile.ChopsInState = 0;
                StateChanged = true;
            }

            InState.BandIndex = utils_dicing::Get_NextBandIndex(InState.BandIndex);
        }

        const auto NewState = InState.Pile.MaterialState;
        const auto NewBand = utils_dicing::Get_BandCenterAt(Spec, InState.BandIndex);

        ck::Trace(f"[Dicing] [{InDicing.ToString()}] chop {Result :n}: state {NewState :n}, useful chops {InState.Pile.UsefulChops}");

        if (InDicing.Has_Fragment(FMars_Fragment_Dicing_Signals) == false)
        { return; }

        if (StateChanged)
        {
            InDicing.Get_Fragment(FMars_Fragment_Dicing_Signals).OnStateChanged.Broadcast(InDicing, NewState);

            if (NewState == Spec.RequestedState && InDicing.Has_Fragment(FMars_Fragment_Dicing_Signals))
            { InDicing.Get_Fragment(FMars_Fragment_Dicing_Signals).OnRequestedStateReached.Broadcast(InDicing); }
        }

        if (NewBand != StartBand && InDicing.Has_Fragment(FMars_Fragment_Dicing_Signals))
        { InDicing.Get_Fragment(FMars_Fragment_Dicing_Signals).OnBandMoved.Broadcast(InDicing, NewBand); }

        if (InDicing.Has_Fragment(FMars_Fragment_Dicing_Signals))
        { InDicing.Get_Fragment(FMars_Fragment_Dicing_Signals).OnChopResolved.Broadcast(InDicing, Result); }
    }
}
