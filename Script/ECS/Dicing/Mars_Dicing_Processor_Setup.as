// One-shot per Dicing entity: binds the cleaver Mover's OnArrived, where a chop resolves.
//   Arrived at the end (contact): aligned = the hand is within BandHalfWidth of the band. An aligned chop counts; at
//     ChopsPerState the pile advances one state (GreenPaste stays) and the band steps to the next table entry. Writes land
//     first, then OnStateChanged (+ OnRequestedStateReached on exactly the requested state), OnBandMoved, OnChopResolved;
//     then the cleaver is sent back up.
//   Arrived at the start (back up): the chop is over; the next press may chop.
// The Mover finds its Dicing through FMars_Fragment_Dicing_ChopLink (stamped by Add on the Mover entity).
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

        auto Mover = InState.ChopMover;
        if (ck::IsValid(Mover))
        { Mover.BindTo_OnArrived(FMars_Delegate_Mover_OnArrived(this, n"OnChopMoverArrived")); }

        Self.Request_TryRemove(FMars_Tag_Dicing_NeedsSetup);
    }

    UFUNCTION()
    private void OnChopMoverArrived(FCk_Handle_Mover InMover, bool InAtEnd)
    {
        auto MoverEntity = FCk_Handle(InMover);
        if (ck::Is_NOT_Valid(MoverEntity) || MoverEntity.Has_Fragment(FMars_Fragment_Dicing_ChopLink) == false)
        { return; }

        auto Dicing = MoverEntity.Get_Fragment(FMars_Fragment_Dicing_ChopLink).Dicing;
        if (ck::Is_NOT_Valid(Dicing))
        { return; }

        auto& State = Dicing.Get_Fragment(FMars_Fragment_Dicing);
        if (State.IsChopping == false)
        { return; }

        if (InAtEnd == false)
        {
            State.IsChopping = false;
            return;
        }

        Resolve_Contact(Dicing, State);

        auto ChopMover = InMover;
        ChopMover.Request_MoveTo(false);
    }

    private void Resolve_Contact(FCk_Handle_Dicing& InDicing, FMars_Fragment_Dicing& InState)
    {
        const auto Spec = InDicing.Get_Spec();
        const auto Aligned = Math::Abs(InState.HandLateral - InState.BandCenter) <= Spec.BandHalfWidth;

        auto StateChanged = false;
        auto BandMoved = false;
        if (Aligned)
        {
            InState.UsefulChops += 1;
            InState.ChopsInState += 1;

            if (InState.ChopsInState >= Spec.ChopsPerState && InState.MaterialState != EMars_Dicing_State::GreenPaste)
            {
                InState.MaterialState = utils_dicing::Get_NextState(InState.MaterialState);
                InState.ChopsInState = 0;
                StateChanged = true;
            }

            InState.BandIndex = (InState.BandIndex + 1) % utils_dicing::k_BandTableSize;
            const auto NewCenter = utils_dicing::Get_BandCenterAt(Spec, InState.BandIndex);
            BandMoved = NewCenter != InState.BandCenter;
            InState.BandCenter = NewCenter;
        }

        const auto NewState = InState.MaterialState;
        const auto NewBand = InState.BandCenter;

        const FString Verdict = Aligned ? "aligned" : "off the band";
        ck::Trace(f"[Dicing] [{InDicing.ToString()}] chop {Verdict}: state {NewState :n}, useful chops {InState.UsefulChops}");

        if (InDicing.Has_Fragment(FMars_Fragment_Dicing_Signals) == false)
        { return; }

        if (StateChanged)
        {
            InDicing.Get_Fragment(FMars_Fragment_Dicing_Signals).OnStateChanged.Broadcast(InDicing, NewState);

            if (NewState == Spec.RequestedState && InDicing.Has_Fragment(FMars_Fragment_Dicing_Signals))
            { InDicing.Get_Fragment(FMars_Fragment_Dicing_Signals).OnRequestedStateReached.Broadcast(InDicing); }
        }

        if (BandMoved && InDicing.Has_Fragment(FMars_Fragment_Dicing_Signals))
        { InDicing.Get_Fragment(FMars_Fragment_Dicing_Signals).OnBandMoved.Broadcast(InDicing, NewBand); }

        if (InDicing.Has_Fragment(FMars_Fragment_Dicing_Signals))
        { InDicing.Get_Fragment(FMars_Fragment_Dicing_Signals).OnChopResolved.Broadcast(InDicing, Aligned); }
    }
}
