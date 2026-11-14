// Once per pan. With authority it drops the mirror state: the kernel's own processors publish both ledgers and broadcast. A
// machine without authority binds both ledgers' rep-notifies, reconciles the kernel's once and applies the pan's once,
// showing the ledgers this machine composed. Applying the pan's ledger is its pan Implement following the command. Each
// ledger's first application is the state the copy was born into and is taken once as it stands: the heat announced, no
// refused take-out and no seared face the ledger already counts raised, the pan starting a new session as it follows.
// Each later change is reconciled as it arrives: each reconcile of the kernel's ledger raises, from the arrived ledger
// against the one it last reconciled: OnTakeOutRefused once per unseen TakeOutRefusalSerial (with the ledger's last
// reason), OnHeatChanged once when the heat differs, then OnFaceSeared once for every face that reads 1 in a row whose
// piece was in the last ledger with that face under 1 (a piece first read seared raises no burst). OnPieceAdded is the
// Tick's (as each row's piece shows up on this machine); the other searing signals are never raised without authority.
class UMars_Processor_Searing_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Searing_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Searing);
        Query.Require(FMars_Tag_Searing_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_Searing_NeedsMirror);
        auto Searing = InHandle.As_Searing();

        if (utils_net::Get_HasAuthority(InHandle))
        {
            Searing.Get_Fragment(FMars_Fragment_Searing_Local).Last = TOptional<FMars_Fragment_Searing_Net>();
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_Searing_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        InHandle.BindTo_OnRepNotify(FMars_Fragment_Searing_PanNet, FCk_DynamicFragment_OnRepNotify(this, n"OnPanLedgerReplicated"));
        Reconcile(Searing, EMars_Net_Reconcile::AsItStands);
        Apply_Pan(Searing, EMars_Net_Reconcile::AsItStands);
    }

    // An expected absence, not a defect: a notify can land on a station already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (utils_foodpiece::Get_IsLiveEntity(InHandle) == false || InHandle.Is_Searing() == false)
        { return; }

        auto Searing = InHandle.As_Searing();
        if (Searing.Get_Fragment(FMars_Fragment_Searing_Local).InitialState == EMars_Net_InitialState::Awaited)
        {
            Searing.Get_Fragment(FMars_Fragment_Searing_Local).InitialState = EMars_Net_InitialState::Taken;
            Reconcile(Searing, EMars_Net_Reconcile::AsItStands);
            return;
        }

        Reconcile(Searing, EMars_Net_Reconcile::AsItArrives);
    }

    // An expected absence, not a defect: a notify can land on a station already ending.
    UFUNCTION()
    private void OnPanLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (utils_foodpiece::Get_IsLiveEntity(InHandle) == false || InHandle.Is_Searing() == false)
        { return; }

        auto Searing = InHandle.As_Searing();
        if (Searing.Get_Fragment(FMars_Fragment_Searing_Local).PanInitialState == EMars_Net_InitialState::Awaited)
        {
            Searing.Get_Fragment(FMars_Fragment_Searing_Local).PanInitialState = EMars_Net_InitialState::Taken;
            Apply_Pan(Searing, EMars_Net_Reconcile::AsItStands);
            return;
        }

        Apply_Pan(Searing, EMars_Net_Reconcile::AsItArrives);
    }

    // As it stands the pan starts a new session before it follows: the reset forgets the kick total this machine last
    // followed, so the command's total is recorded and no toss made before this copy took its state is played.
    private void Apply_Pan(FCk_Handle_Searing& InSearing, EMars_Net_Reconcile InHow)
    {
        auto Pan = InSearing.Get_Pan();
        if (InHow == EMars_Net_Reconcile::AsItStands)
        { Pan.Request_Reset(FMars_Request_Implement_Reset()); }

        Pan.Request_Follow(FMars_Request_Implement_Follow(InSearing.Get_Fragment(FMars_Fragment_Searing_PanNet).Pan));
    }

    // Last is written before any broadcast: a handler may compose on another entity and move the fragment storage, so the
    // signals fragment is read again for every broadcast.
    private void Reconcile(FCk_Handle_Searing& InSearing, EMars_Net_Reconcile InHow)
    {
        const auto Ledger = InSearing.Get_Fragment(FMars_Fragment_Searing_Net);
        auto& Local = InSearing.Get_Fragment(FMars_Fragment_Searing_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[Searing] [{InSearing.ToString()}] has no mirror state off authority"))
        { return; }

        auto Last = Local.Last.GetValue();
        Local.Last = TOptional<FMars_Fragment_Searing_Net>(Ledger);

        // As it stands, every take-out the ledger counts as refused came before this copy took its state, and so did
        // every face it shows seared: no burst for one.
        if (InHow == EMars_Net_Reconcile::AsItStands)
        {
            Last.TakeOutRefusalSerial = Ledger.TakeOutRefusalSerial;
            Last.Pieces = Ledger.Pieces;
        }

        if (InSearing.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
        { return; }

        // Handlers re-text, glow and burst on the station: scope the script world to the station's.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InSearing));

        for (int32 Index = Last.TakeOutRefusalSerial; Index < Ledger.TakeOutRefusalSerial; ++Index)
        {
            if (InSearing.Has_Fragment(FMars_Fragment_Searing_Signals))
            { InSearing.Get_Fragment(FMars_Fragment_Searing_Signals).OnTakeOutRefused.Broadcast(InSearing, Ledger.LastTakeOutRefusal); }
        }

        if (Ledger.Heat != Last.Heat && InSearing.Has_Fragment(FMars_Fragment_Searing_Signals))
        { InSearing.Get_Fragment(FMars_Fragment_Searing_Signals).OnHeatChanged.Broadcast(InSearing, Ledger.Heat); }

        for (const auto& Row : Ledger.Pieces)
        {
            const auto LastIndex = utils_searing::Find_RowIndex(Last.Pieces, Row.Id);
            if (LastIndex < 0)
            { continue; }

            const auto& LastSears = Last.Pieces[LastIndex].FaceSear;
            for (int32 Face = 0; Face < Row.FaceSear.Num(); ++Face)
            {
                const auto WasUnder = LastSears.IsValidIndex(Face) == false || LastSears[Face] < 1.0f;
                if (Row.FaceSear[Face] < 1.0f || WasUnder == false || InSearing.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
                { continue; }

                InSearing.Get_Fragment(FMars_Fragment_Searing_Signals).OnFaceSeared.Broadcast(InSearing, Row.Id, EMars_FoodPiece_Face(Face));
            }
        }
    }
}
