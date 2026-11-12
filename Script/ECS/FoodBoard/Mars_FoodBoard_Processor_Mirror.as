// Once per board: the authority drops the mirror state (its own drain publishes the ledger and broadcasts). A machine without
// authority binds the ledger's rep-notify and reconciles once, so a ledger that replicated before the bind still counts;
// each reconcile raises, from the arrived ledger against the one it last reconciled, OnCutIssued once per CutSerial it had
// not seen, OnTurned once per TurnSerial and OnReleaseRefused once per ReleaseRefusalSerial (each with the ledger's last
// answer of its kind), the kinds in the order the authority gave their latest answers, then OnHeldCountChanged when the
// count differs. No signal about a piece is raised here: placing, cutting and releasing are the authority's.
class UMars_Processor_FoodBoard_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_FoodBoard_NeedsMirror;

    // Later than any answer: the At of a kind with nothing left to raise.
    private const int32 k_Never = 2147483647;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_FoodBoard);
        Query.Require(FMars_Tag_FoodBoard_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_FoodBoard_NeedsMirror);
        auto Board = InHandle.As_FoodBoard();

        if (utils_net::Get_HasAuthority(InHandle))
        {
            Board.Get_Fragment(FMars_Fragment_FoodBoard_Local).Last = TOptional<FMars_Fragment_FoodBoard_Net>();
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_FoodBoard_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        Reconcile(Board);
    }

    // An expected absence, not a defect: a notify can land on a board already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (utils_foodpiece::Get_IsLiveEntity(InHandle) == false || InHandle.Is_FoodBoard() == false)
        { return; }

        auto Board = InHandle.As_FoodBoard();
        Reconcile(Board);
    }

    // Last is written before any broadcast: a handler may compose on another entity and move the fragment storage, so the
    // signals fragment is read again for every broadcast.
    private void Reconcile(FCk_Handle_FoodBoard& InBoard)
    {
        const auto Ledger = InBoard.Get_Fragment(FMars_Fragment_FoodBoard_Net);
        auto& Local = InBoard.Get_Fragment(FMars_Fragment_FoodBoard_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[FoodBoard] [{InBoard.ToString()}] has no mirror state off authority"))
        { return; }

        const auto Last = Local.Last.GetValue();
        Local.Last = TOptional<FMars_Fragment_FoodBoard_Net>(Ledger);

        if (InBoard.Has_Fragment(FMars_Fragment_FoodBoard_Signals) == false)
        { return; }

        // Handlers spark and re-text on the station: scope the script world to the board's.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InBoard));

        // Each pass raises the kind whose latest answer came first among those not raised yet.
        auto Cuts = Ledger.CutSerial - Last.CutSerial;
        auto Turns = Ledger.TurnSerial - Last.TurnSerial;
        auto Refusals = Ledger.ReleaseRefusalSerial - Last.ReleaseRefusalSerial;
        while (Cuts > 0 || Turns > 0 || Refusals > 0)
        {
            const auto CutAt = Cuts > 0 ? Ledger.LastCutAt : k_Never;
            const auto TurnAt = Turns > 0 ? Ledger.LastTurnAt : k_Never;
            const auto RefusalAt = Refusals > 0 ? Ledger.LastReleaseRefusalAt : k_Never;

            if (CutAt <= TurnAt && CutAt <= RefusalAt)
            {
                for (; Cuts > 0; --Cuts)
                { InBoard.Get_Fragment(FMars_Fragment_FoodBoard_Signals).OnCutIssued.Broadcast(InBoard, Ledger.LastCut); }
            }
            else if (TurnAt <= RefusalAt)
            {
                for (; Turns > 0; --Turns)
                { InBoard.Get_Fragment(FMars_Fragment_FoodBoard_Signals).OnTurned.Broadcast(InBoard, Ledger.LastTurnDegrees); }
            }
            else
            {
                for (; Refusals > 0; --Refusals)
                { InBoard.Get_Fragment(FMars_Fragment_FoodBoard_Signals).OnReleaseRefused.Broadcast(InBoard, Ledger.LastReleaseRefusal); }
            }
        }

        if (Ledger.HeldCount != Last.HeldCount)
        { InBoard.Get_Fragment(FMars_Fragment_FoodBoard_Signals).OnHeldCountChanged.Broadcast(InBoard, Ledger.HeldCount); }
    }
}
