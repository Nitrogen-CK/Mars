// Once per piece with a replicated ledger: the authority drops the tag (it writes the ledger). A copy without authority binds
// the ledger's rep-notify and reconciles once, so a ledger that replicated before the bind still counts; each reconcile
// adopts the ledger's Id and Lineage while this copy has no Id (a valid Id that differs from the ledger's is a defect),
// wears the ledger's cook state when its serial is one this copy has not worn and then raises OnCookStateChanged, and
// checks this copy's geometry against the authority's numbers (utils_foodpiece::Update_CheckResult); a lineage it adopts tags
// the piece for the Succession processor. A notify that changes nothing does nothing.
class UMars_Processor_FoodPiece_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_FoodPiece_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_FoodPiece);
        Query.Require(FMars_Tag_FoodPiece_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_FoodPiece_NeedsMirror);
        if (utils_net::Get_HasAuthority(InHandle))
        { return; }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_FoodPiece_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        auto Piece = InHandle.As_FoodPiece();
        Reconcile(Piece);
    }

    // An expected absence, not a defect: a notify can land on a piece already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || InHandle.Is_FoodPiece() == false)
        { return; }

        auto Piece = InHandle.As_FoodPiece();
        if (Piece.Get_IsGone())
        { return; }

        Reconcile(Piece);
    }

    // Every write lands before the broadcast: a handler may compose on another entity and move the fragment storage.
    private void Reconcile(FCk_Handle_FoodPiece& InPiece)
    {
        const auto Ledger = InPiece.Get_Fragment(FMars_Fragment_FoodPiece_Net);
        auto& State = InPiece.Get_Fragment(FMars_Fragment_FoodPiece);
        auto IsLineageAdopted = false;

        if (Ledger.Id.IsValid())
        {
            if (State.Id.IsValid() == false)
            {
                State.Id = Ledger.Id;
                if (Ledger.Lineage.IsValid())
                {
                    IsLineageAdopted = State.Lineage.IsValid() == false;
                    State.Lineage = Ledger.Lineage;
                }
            }
            else
            {
                ck::EnsureIfNot(State.Id == Ledger.Id,
                    f"[FoodPiece] [{InPiece.ToString()}] has Id [{State.Id.ToString(EGuidFormats::Short)}] but the authority's ledger names it [{Ledger.Id.ToString(EGuidFormats::Short)}]");
            }
        }

        auto& Local = InPiece.Get_Fragment(FMars_Fragment_FoodPiece_Local);
        const auto IsNewCookState = Ledger.CookSerial != Local.LastCookSerial;
        if (IsNewCookState)
        {
            State.CookState = Ledger.CookState;
            Local.LastCookSerial = Ledger.CookSerial;
        }

        utils_foodpiece::Update_CheckResult(InPiece);

        // A lineage now known is ruled on (the Succession processor runs after this one).
        if (IsLineageAdopted && InPiece.Has_Fragment(FMars_Tag_FoodPiece_NeedsSuccession) == false)
        { InPiece.Add_Fragment(FMars_Tag_FoodPiece_NeedsSuccession()); }

        if (IsNewCookState && InPiece.Has_Fragment(FMars_Fragment_FoodPiece_Signals))
        { InPiece.Get_Fragment(FMars_Fragment_FoodPiece_Signals).OnCookStateChanged.Broadcast(InPiece); }
    }
}
