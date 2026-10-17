class UMars_Processor_AnchorResolver_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_AnchorResolver_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_AnchorResolver);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_AnchorResolver_Requests& InRequests,
                       FMars_Fragment_AnchorResolver& InResolverComp)
    {
        auto Self = InHandle.As_AnchorResolver();
        const auto Requests = InRequests.ResolveAnchor;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_AnchorResolver_Requests);

        const auto Result = Self.Get_Result();
        auto Resolved = TArray<FMars_AnchorLedger_Entry>();
        for (const auto& Request : Requests)
        {
            auto Anchor = Request.Anchor;
            if (ck::Is_NOT_Valid(Anchor))
            { continue; }

            const auto AnchorId = Anchor.Get_AnchorId();
            const auto Existing = Find_Entry(InResolverComp.Ledger, AnchorId);
            // Already resolved: the same anchor again is a no-op; a different anchor with the same id is a level bug.
            if (Existing != utils_anchor_resolver::k_NoIndex)
            {
                ck::EnsureIfNot(InResolverComp.Ledger[Existing].Anchor == Anchor, f"[AnchorResolver] duplicate anchor id {AnchorId.ToString()}");
                continue;
            }

            const auto Role = Result.Get_Role(AnchorId);
            auto Query = FMars_AnchorRow_Query();
            Query.Role = Role;
            Query.RunSeed = Result.Seed;
            Query.AnchorId = AnchorId;
            Query.PinnedRow = Anchor.Get_PinnedRow();

            auto Table = Anchor.Get_Table();
            if (ck::EnsureIfNot(ck::IsValid(Table), f"[AnchorResolver] anchor {AnchorId.ToString()} has no loadable table"))
            { continue; }

            const auto Pick = utils_anchor_resolver::Pick_Row(Table, Query);
            if (Pick.RowIndex.IsSet() == false)
            {
                // An anchor the plan does not name draws from its table's Other rows; a Route or Spawn table has none,
                // so a placed anchor missing from the plan is a level bug, not a resolvable flavour anchor.
                const auto Why = Role == EMars_Anchor_Role::None ? "is not in the plan and its table has no row for an unplanned anchor" :
                    f"has no table row for role {Role :n}";
                ck::EnsureIfNot(false, f"[AnchorResolver] anchor {AnchorId.ToString()} {Why}");
                continue;
            }

            // A channel wires exactly one lever-gate pair: two anchors sharing one would open each other's gate.
            const auto Channel = Anchor.Get_Channel();
            for (const auto& Ledgered : InResolverComp.Ledger)
            {
                if (Channel.IsValid() && ck::IsValid(Ledgered.Anchor) && Ledgered.Anchor.Get_Channel() == Channel)
                { ck::EnsureIfNot(false, f"[AnchorResolver] anchors {Ledgered.AnchorId.ToString()} and {AnchorId.ToString()} share channel {Channel.ToString()}"); }
            }

            const auto RowIndex = Pick.RowIndex.GetValue();
            auto Context = FMars_Anchor_Context();
            Context.AnchorId = AnchorId;
            Context.Channel = Anchor.Get_Channel();
            Context.SpanCm = Anchor.Get_SpanCm();
            Context.HomeRadiusCm = Anchor.Get_HomeRadiusCm();
            Context.RunSeed = Result.Seed;
            Anchor.Request_Resolve(FMars_Request_Anchor_Resolve(RowIndex, Role, Context));

            auto Entry = FMars_AnchorLedger_Entry();
            Entry.AnchorId = AnchorId;
            Entry.Role = Role;
            Entry.RowIndex = RowIndex;
            Entry.Pinned = Pick.Pinned;
            Entry.RoleMismatch = Pick.RoleMismatch;
            Entry.ScriptName = "Nothing";
            if (Table.Rows[RowIndex].Script != nullptr)
            { Entry.ScriptName = f"{Table.Rows[RowIndex].Script.Get().GetName()}"; }
            Entry.Anchor = Anchor;
            Insert_Sorted(InResolverComp.Ledger, Entry);
            Resolved.Add(Entry);

            const auto PinnedText = Entry.Pinned ? ", pinned" : "";
            const auto MismatchText = Entry.RoleMismatch ? ", role mismatch" : "";
            LogDisplay(f"Anchor {AnchorId.ToString()} -> {Entry.ScriptName} (row {RowIndex}, role {Role :n}{PinnedText}{MismatchText})");
        }

        if (Self.Has_Fragment(FMars_Fragment_AnchorResolver_Signals) == false)
        { return; }

        for (const auto& Entry : Resolved)
        { Self.Get_Fragment(FMars_Fragment_AnchorResolver_Signals).OnAnchorResolved.Broadcast(Self, Entry); }
    }

    private int32 Find_Entry(const TArray<FMars_AnchorLedger_Entry>& InLedger, FGameplayTag InAnchorId) const
    {
        for (int32 Index = 0; Index < InLedger.Num(); ++Index)
        {
            if (InLedger[Index].AnchorId == InAnchorId)
            { return Index; }
        }
        return utils_anchor_resolver::k_NoIndex;
    }

    private void Insert_Sorted(TArray<FMars_AnchorLedger_Entry>& InOutLedger, const FMars_AnchorLedger_Entry& InEntry) const
    {
        const auto Key = utils_anchor_resolver::Get_SortKey(InEntry.AnchorId);
        auto Slot = 0;
        while (Slot < InOutLedger.Num() && utils_anchor_resolver::Get_SortKey(InOutLedger[Slot].AnchorId) < Key)
        { ++Slot; }

        InOutLedger.Insert(InEntry, Slot);
    }
}
