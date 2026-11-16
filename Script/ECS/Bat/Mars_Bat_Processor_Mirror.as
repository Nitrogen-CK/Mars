// Once per bat: the authority drops the mirror state (its drain and its tick publish the ledger). A machine without
// authority binds the ledger's rep-notify and reconciles once as it stands, which shows what this machine composed.
// The ledger's first application is the state the copy was born into and is taken once as it stands: the phase and
// the place it hangs from as they are, its phase clock from that moment, and no past change heard. Each later change
// is reconciled as it arrives: the phase starts on this machine's clock and OnPhaseChanged is raised once. A phase
// that never arrived because two of the authority's writes reached this machine as one is not replayed. Both ways the
// swoop stage the phase names is written before the phase, its clock at 0 unless it is the stage already shown.
class UMars_Processor_Bat_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Bat_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Bat);
        Query.Require(FMars_Tag_Bat_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_Bat_NeedsMirror);
        auto Bat = InHandle.As_Bat();

        if (utils_net::Get_HasAuthority(InHandle))
        {
            Bat.Get_Fragment(FMars_Fragment_Bat_Local).Last = TOptional<FMars_Fragment_Bat_Net>();
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_Bat_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        Reconcile(Bat, EMars_Bat_Reconcile::AsItStands);
    }

    // An expected absence, not a defect: a notify can land on an entity already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_Bat() == false)
        { return; }

        auto Bat = InHandle.As_Bat();
        if (Bat.Get_Fragment(FMars_Fragment_Bat_Local).InitialState == EMars_Net_InitialState::Awaited)
        {
            Bat.Get_Fragment(FMars_Fragment_Bat_Local).InitialState = EMars_Net_InitialState::Taken;
            Reconcile(Bat, EMars_Bat_Reconcile::AsItStands);
            return;
        }

        Reconcile(Bat, EMars_Bat_Reconcile::AsItArrives);
    }

    // Last is written before the state and any broadcast; then the place it hangs from, then the phase. As it stands,
    // the phase is set with its clock at 0 and nothing is raised; as it arrives, utils_bat::Set_Phase writes it,
    // restarts the clock and raises OnPhaseChanged.
    private void Reconcile(FCk_Handle_Bat& InBat, EMars_Bat_Reconcile InHow)
    {
        const auto Ledger = InBat.Get_Fragment(FMars_Fragment_Bat_Net);
        auto& Local = InBat.Get_Fragment(FMars_Fragment_Bat_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[Bat] [{InBat.ToString()}] has no mirror state off authority"))
        { return; }

        const auto Last = Local.Last.GetValue();
        Local.Last = TOptional<FMars_Fragment_Bat_Net>(Ledger);

        InBat.Get_Fragment(FMars_Fragment_Bat).Perch.ShownAnchor = TOptional<FVector>(Ledger.PerchAnchor);

        if (Ledger.Phase == Last.Phase)
        { return; }

        Show_SwoopStage(InBat, Ledger.Phase);

        if (InHow == EMars_Bat_Reconcile::AsItStands)
        {
            auto& State = InBat.Get_Fragment(FMars_Fragment_Bat);
            State.Phase = Ledger.Phase;
            State.PhaseClock = 0.0f;
            return;
        }

        // Handlers react on the bat (its look): scope the script world to its own.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InBat));
        utils_bat::Set_Phase(InBat, Ledger.Phase);
    }

    // The swoop stage the phase names, on this machine's clock from now. A phase that names the stage already shown
    // (Screeching after Telegraphing) leaves its clock running.
    private void Show_SwoopStage(FCk_Handle_Bat& InBat, EMars_Bat_Phase InPhase)
    {
        auto& Swoop = InBat.Get_Fragment(FMars_Fragment_Bat).Swoop;
        const auto Stage = utils_bat::Get_ShownSwoopStage(InPhase);
        if (Swoop.Stage == Stage)
        { return; }

        Swoop.Stage = Stage;
        Swoop.StageElapsed = 0.0f;
    }
}
