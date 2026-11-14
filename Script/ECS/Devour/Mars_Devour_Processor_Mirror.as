// Once per devourer: the authority drops the mirror state (its drain and its tick publish the ledger). A machine
// without authority binds the ledger's rep-notify and reconciles once as it stands, then again as each change
// arrives, with the same two transitions the authority runs: a run that was shown and is over (or replaced) is
// released with the ledger's end, a new run is seized with the victim this machine knows (none when it cannot see it,
// and it never adopts one later), and the phases it did not see arrive are entered in order up to the ledger's, so
// OnPhaseChanged keeps its contract here too. A phase's clock starts at its arrival (the tick runs it). A run that
// began and ended between two arrivals raises nothing.
class UMars_Processor_Devour_Mirror : UMars_Processor_Devour_Base
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Devour_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Devour);
        Query.Require(FMars_Tag_Devour_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_Devour_NeedsMirror);
        auto Devour = InHandle.As_Devour();

        if (utils_net::Get_HasAuthority(InHandle))
        {
            Devour.Get_Fragment(FMars_Fragment_Devour_Local).Last = TOptional<FMars_Fragment_Devour_Net>();
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_Devour_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        Reconcile(Devour);
    }

    // An expected absence, not a defect: a notify can land on an entity already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_Devour() == false)
        { return; }

        auto Devour = InHandle.As_Devour();
        Reconcile(Devour);
    }

    // Last is written before the state and any broadcast; the release comes before the seize, as in the drain.
    private void Reconcile(FCk_Handle_Devour& InDevour)
    {
        const auto Ledger = InDevour.Get_Fragment(FMars_Fragment_Devour_Net);
        auto& Local = InDevour.Get_Fragment(FMars_Fragment_Devour_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[Devour] [{InDevour.ToString()}] has no mirror state off authority"))
        { return; }

        const auto Last = Local.Last.GetValue();
        Local.Last = TOptional<FMars_Fragment_Devour_Net>(Ledger);
        if (utils_devour::Get_IsSameLedger(Last, Ledger))
        { return; }

        auto& State = InDevour.Get_Fragment(FMars_Fragment_Devour);
        const auto WasShown = Last.Phase != EMars_Devour_Phase::Idle;
        const auto IsSameRun = WasShown && Ledger.Serial == Last.Serial;

        auto Released = TOptional<FCk_Handle>();
        if (WasShown && (Ledger.Phase == EMars_Devour_Phase::Idle || IsSameRun == false))
        { Released = TOptional<FCk_Handle>(DoRelease(InDevour, State, Ledger.LastEnd)); }

        TArray<EMars_Devour_Phase> Entered;
        if (Ledger.Phase != EMars_Devour_Phase::Idle)
        {
            auto From = int32(EMars_Devour_Phase::Seize);
            if (IsSameRun)
            { From = int32(Last.Phase) + 1; }
            else
            { DoSeize(InDevour, State, utils_devour::Get_KnownVictim(Ledger, InDevour.H())); }

            for (auto Index = From; Index <= int32(Ledger.Phase); ++Index)
            { Entered.Add(EMars_Devour_Phase(Index)); }

            State.Phase = Ledger.Phase;
            if (Entered.Num() > 0)
            { State.PhaseSeconds = 0.0f; }
        }

        State.Serial = Ledger.Serial;
        State.LastEnd = Ledger.LastEnd;

        if (Released.IsSet() == false && Entered.Num() == 0)
        { return; }

        // Handlers react on the devourer and its victim (a view, a state machine): scope the script world to its own.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InDevour));
        if (Released.IsSet() && InDevour.Has_Fragment(FMars_Fragment_Devour_Signals))
        { InDevour.Get_Fragment(FMars_Fragment_Devour_Signals).OnEnded.Broadcast(InDevour, Released.GetValue(), Ledger.LastEnd); }

        for (const auto Phase : Entered)
        {
            if (InDevour.Has_Fragment(FMars_Fragment_Devour_Signals))
            { InDevour.Get_Fragment(FMars_Fragment_Devour_Signals).OnPhaseChanged.Broadcast(InDevour, Phase); }
        }
    }
}
