// Once per tumbler. With authority it drops the mirror state: the kernel's own processors publish both ledgers and
// broadcast. A machine without authority binds the kernel ledger's rep-notify and reconciles once, showing the ledger
// this machine composed; the motion ledger is not notified, the Tick follows it every frame. The ledger's first
// application is the state the copy was born into and is taken once as it stands: the hinge put at its pose at once,
// every level announced, no refused press or take-out the ledger already counts. Each later change is reconciled as it
// arrives: a hatch that differs from the ledger it last reconciled tweens this machine's hinge Mover to its end for
// Opening or Open and to its start for Closing or Closed. Each reconcile then raises, from the arrived ledger against
// the one it last reconciled: OnPressRefused once per unseen PressRefusalSerial and OnTakeOutRefused once per unseen
// TakeOutRefusalSerial, each with the ledger's last reason, then OnDrumChanged, OnHatchChanged, OnHoverChanged and
// OnHandModeChanged, each once when its value differs (the Tick's own order). OnPieceAdded is the Tick's (as each row's
// piece shows up on this machine); OnPieceTakenOut, OnCoverageChanged and OnPieceReseated are never raised without
// authority.
class UMars_Processor_Tumbler_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Tumbler_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Tumbler);
        Query.Require(FMars_Tag_Tumbler_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_Tumbler_NeedsMirror);
        auto Tumbler = InHandle.As_Tumbler();

        if (utils_net::Get_HasAuthority(InHandle))
        {
            Tumbler.Get_Fragment(FMars_Fragment_Tumbler_Local).Last = TOptional<FMars_Fragment_Tumbler_Net>();
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_Tumbler_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        Reconcile(Tumbler, EMars_Net_Reconcile::AsItStands);
    }

    // An expected absence, not a defect: a notify can land on a station already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (utils_foodpiece::Get_IsLiveEntity(InHandle) == false || InHandle.Is_Tumbler() == false)
        { return; }

        auto Tumbler = InHandle.As_Tumbler();
        if (Tumbler.Get_Fragment(FMars_Fragment_Tumbler_Local).InitialState == EMars_Net_InitialState::Awaited)
        {
            Tumbler.Get_Fragment(FMars_Fragment_Tumbler_Local).InitialState = EMars_Net_InitialState::Taken;
            Reconcile(Tumbler, EMars_Net_Reconcile::AsItStands);
            return;
        }

        Reconcile(Tumbler, EMars_Net_Reconcile::AsItArrives);
    }

    // Last is written before the hinge is asked or anything is raised: a handler may compose on another entity and move the
    // fragment storage, so the signals fragment is read again for every broadcast.
    private void Reconcile(FCk_Handle_Tumbler& InTumbler, EMars_Net_Reconcile InHow)
    {
        const auto Ledger = InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Net);
        const auto LastSet = InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Local).Last;
        if (ck::EnsureIfNot(LastSet.IsSet(), f"[Tumbler] [{InTumbler.ToString()}] has no mirror state off authority"))
        { return; }

        auto Last = LastSet.GetValue();
        InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Local).Last = TOptional<FMars_Fragment_Tumbler_Net>(Ledger);

        // As it stands, every press and take-out the ledger counts as refused came before this copy took its state.
        if (InHow == EMars_Net_Reconcile::AsItStands)
        {
            Last.PressRefusalSerial = Ledger.PressRefusalSerial;
            Last.TakeOutRefusalSerial = Ledger.TakeOutRefusalSerial;
        }

        if (Ledger.Hatch != Last.Hatch)
        { Move_Hatch(InTumbler, Ledger.Hatch, InHow); }

        if (InTumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
        { return; }

        // Handlers flash and re-text the station's label and rows: scope the script world to the station's.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InTumbler));

        for (int32 Index = Last.PressRefusalSerial; Index < Ledger.PressRefusalSerial; ++Index)
        {
            if (InTumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals))
            { InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnPressRefused.Broadcast(InTumbler, Ledger.LastPressRefusal); }
        }

        for (int32 Index = Last.TakeOutRefusalSerial; Index < Ledger.TakeOutRefusalSerial; ++Index)
        {
            if (InTumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals))
            { InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnTakeOutRefused.Broadcast(InTumbler, Ledger.LastTakeOutRefusal); }
        }

        if (Ledger.Drum != Last.Drum && InTumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals))
        { InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnDrumChanged.Broadcast(InTumbler, Ledger.Drum); }

        if (Ledger.Hatch != Last.Hatch && InTumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals))
        { InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnHatchChanged.Broadcast(InTumbler, Ledger.Hatch); }

        if (Ledger.Hovered != Last.Hovered && InTumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals))
        { InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnHoverChanged.Broadcast(InTumbler, Ledger.Hovered); }

        if (Ledger.HandMode != Last.HandMode && InTumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals))
        { InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnHandModeChanged.Broadcast(InTumbler, Ledger.HandMode); }
    }

    // This machine's hinge Mover to the pose InHatch is at or moving toward: put there at once as it stands, a hatch
    // opening or closing shown at its end; tweened there as it arrives.
    private void Move_Hatch(FCk_Handle_Tumbler& InTumbler, EMars_Tumbler_Hatch InHatch, EMars_Net_Reconcile InHow)
    {
        const auto IsOpening = InHatch == EMars_Tumbler_Hatch::Opening || InHatch == EMars_Tumbler_Hatch::Open;
        auto Hatch = InTumbler.Get_Spec().Nodes.Hatch;
        if (InHow == EMars_Net_Reconcile::AsItStands)
        { Hatch.Request_Scrub(FMars_Request_Mover_Scrub(IsOpening ? 1.0f : 0.0f)); }

        Hatch.Request_MoveTo(FMars_Request_Mover_MoveTo(IsOpening ? EMars_Mover_Pose::End : EMars_Mover_Pose::Start));
    }
}
