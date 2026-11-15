// Once per fryer. With authority it drops the mirror state: the kernel's own processors publish both ledgers, command the
// skimmer and broadcast. A machine without authority binds both ledgers' rep-notifies, reconciles the kernel's once and
// applies the skimmer's once, showing the ledgers this machine composed. Each ledger's first application is the state
// the copy was born into and is taken once as it stands: no refused skim, take-out or admission the ledger already
// counts is raised; the skimmer is given its commands and settled on them at once, and the skim is announced when it
// differs.
// Each later change is reconciled as it arrives: applying the skimmer's ledger gives this copy's skimmer Implement the
// commands the authority's drain gives its own (utils_fry::Send_SkimmerDrive, _Pose, _Slide), each only when its field
// changed since the last ledger applied, then raises OnSkimChanged once when the skim changed. Each reconcile of the
// kernel's ledger raises, from the arrived ledger against the one it last reconciled: OnSkimRefused once per unseen
// SkimRefusalSerial, OnTakeOutRefused once per unseen TakeOutRefusalSerial and OnAdmissionRefused once per unseen
// AdmissionRefusalSerial (with a default piece id), each with the ledger's last reason. OnPieceAdded is the Tick's (as
// each row's piece shows up on this machine); the other fry signals are never raised without authority.
class UMars_Processor_Fry_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Fry_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Fry);
        Query.Require(FMars_Tag_Fry_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_Fry_NeedsMirror);
        auto Fry = InHandle.As_Fry();

        if (utils_net::Get_HasAuthority(InHandle))
        {
            Fry.Get_Fragment(FMars_Fragment_Fry_Local).Last = TOptional<FMars_Fragment_Fry_Net>();
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_Fry_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        InHandle.BindTo_OnRepNotify(FMars_Fragment_Fry_SkimmerNet, FCk_DynamicFragment_OnRepNotify(this, n"OnSkimmerLedgerReplicated"));
        Reconcile(Fry, EMars_Net_Reconcile::AsItStands);
        Apply_Skimmer(Fry, EMars_Net_Reconcile::AsItStands);
    }

    // An expected absence, not a defect: a notify can land on a station already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (utils_foodpiece::Get_IsLiveEntity(InHandle) == false || InHandle.Is_Fry() == false)
        { return; }

        auto Fry = InHandle.As_Fry();
        if (Fry.Get_Fragment(FMars_Fragment_Fry_Local).InitialState == EMars_Net_InitialState::Awaited)
        {
            Fry.Get_Fragment(FMars_Fragment_Fry_Local).InitialState = EMars_Net_InitialState::Taken;
            Reconcile(Fry, EMars_Net_Reconcile::AsItStands);
            return;
        }

        Reconcile(Fry, EMars_Net_Reconcile::AsItArrives);
    }

    // An expected absence, not a defect: a notify can land on a station already ending.
    UFUNCTION()
    private void OnSkimmerLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (utils_foodpiece::Get_IsLiveEntity(InHandle) == false || InHandle.Is_Fry() == false)
        { return; }

        auto Fry = InHandle.As_Fry();
        if (Fry.Get_Fragment(FMars_Fragment_Fry_Local).SkimmerInitialState == EMars_Net_InitialState::Awaited)
        {
            Fry.Get_Fragment(FMars_Fragment_Fry_Local).SkimmerInitialState = EMars_Net_InitialState::Taken;
            Apply_Skimmer(Fry, EMars_Net_Reconcile::AsItStands);
            return;
        }

        Apply_Skimmer(Fry, EMars_Net_Reconcile::AsItArrives);
    }

    // LastSkimmer is written before any command or broadcast: a handler may compose on another entity and move the fragment
    // storage. As it stands the skimmer is settled on its command.
    private void Apply_Skimmer(FCk_Handle_Fry& InFry, EMars_Net_Reconcile InHow)
    {
        const auto Ledger = InFry.Get_Fragment(FMars_Fragment_Fry_SkimmerNet);
        const auto LastSet = InFry.Get_Fragment(FMars_Fragment_Fry_Local).LastSkimmer;
        if (ck::EnsureIfNot(LastSet.IsSet(), f"[Fry] [{InFry.ToString()}] has no skimmer mirror state off authority"))
        { return; }

        const auto Last = LastSet.GetValue();
        InFry.Get_Fragment(FMars_Fragment_Fry_Local).LastSkimmer = TOptional<FMars_Fragment_Fry_SkimmerNet>(Ledger);

        const auto IsNewDrive = Last.Drive != Ledger.Drive;
        const auto IsNewSkim = Last.Skim != Ledger.Skim;
        const auto IsNewTarget = Last.Target != Ledger.Target;

        if (IsNewDrive)
        { utils_fry::Send_SkimmerDrive(InFry, Ledger.Drive); }

        if (IsNewSkim)
        { utils_fry::Send_SkimmerPose(InFry, Ledger.Skim); }

        if (IsNewTarget)
        { utils_fry::Send_SkimmerSlide(InFry, Ledger.Target); }

        // As it stands, this machine's skimmer is put where the command puts it once it has taken the
        // command: a dip, a pour or a slide the authority's skimmer was making is shown at its end.
        if (InHow == EMars_Net_Reconcile::AsItStands)
        {
            auto Skimmer = InFry.Get_Skimmer();
            Skimmer.Request_Settle(FMars_Request_Implement_Settle());
        }

        if (IsNewSkim == false || InFry.Has_Fragment(FMars_Fragment_Fry_Signals) == false)
        { return; }

        // The dip row re-texts on the station: scope the script world to the station's.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InFry));
        InFry.Get_Fragment(FMars_Fragment_Fry_Signals).OnSkimChanged.Broadcast(InFry, Ledger.Skim);
    }

    // Last is written before any broadcast: a handler may compose on another entity and move the fragment storage, so the
    // signals fragment is read again for every broadcast.
    private void Reconcile(FCk_Handle_Fry& InFry, EMars_Net_Reconcile InHow)
    {
        const auto Ledger = InFry.Get_Fragment(FMars_Fragment_Fry_Net);
        const auto LastSet = InFry.Get_Fragment(FMars_Fragment_Fry_Local).Last;
        if (ck::EnsureIfNot(LastSet.IsSet(), f"[Fry] [{InFry.ToString()}] has no mirror state off authority"))
        { return; }

        auto Last = LastSet.GetValue();
        InFry.Get_Fragment(FMars_Fragment_Fry_Local).Last = TOptional<FMars_Fragment_Fry_Net>(Ledger);

        // As it stands, every skim, take-out and admission the ledger counts as refused came before this
        // copy took its state.
        if (InHow == EMars_Net_Reconcile::AsItStands)
        {
            Last.SkimRefusalSerial = Ledger.SkimRefusalSerial;
            Last.TakeOutRefusalSerial = Ledger.TakeOutRefusalSerial;
            Last.AdmissionRefusalSerial = Ledger.AdmissionRefusalSerial;
        }

        if (InFry.Has_Fragment(FMars_Fragment_Fry_Signals) == false)
        { return; }

        // Handlers flash the station's label: scope the script world to the station's.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InFry));

        for (int32 Index = Last.SkimRefusalSerial; Index < Ledger.SkimRefusalSerial; ++Index)
        {
            if (InFry.Has_Fragment(FMars_Fragment_Fry_Signals))
            { InFry.Get_Fragment(FMars_Fragment_Fry_Signals).OnSkimRefused.Broadcast(InFry, Ledger.LastSkimRefused); }
        }

        for (int32 Index = Last.TakeOutRefusalSerial; Index < Ledger.TakeOutRefusalSerial; ++Index)
        {
            if (InFry.Has_Fragment(FMars_Fragment_Fry_Signals))
            { InFry.Get_Fragment(FMars_Fragment_Fry_Signals).OnTakeOutRefused.Broadcast(InFry, Ledger.LastTakeOutRefusal); }
        }

        for (int32 Index = Last.AdmissionRefusalSerial; Index < Ledger.AdmissionRefusalSerial; ++Index)
        {
            if (InFry.Has_Fragment(FMars_Fragment_Fry_Signals))
            { InFry.Get_Fragment(FMars_Fragment_Fry_Signals).OnAdmissionRefused.Broadcast(InFry, FMars_CookingFeed_PieceId(), Ledger.LastAdmissionRefusal); }
        }
    }
}
