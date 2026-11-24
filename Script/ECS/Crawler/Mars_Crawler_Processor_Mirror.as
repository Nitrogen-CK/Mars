// Once per combat-enabled crawler: the authority drops the mirror state (its attack tick publishes the ledger). A
// machine without authority binds the ledger's rep-notify and reconciles once as it stands, which shows what this
// machine composed. The ledger's first application is the state the copy was born into and is taken once as it stands:
// the attack it names is never played or cued on this machine. Each later application is reconciled as it arrives.
// Both ways Last is written first, then the copy's hurt count. The mirror creates and broadcasts nothing:
// UMars_Processor_Crawler_AttackShow acts on the levels in its next pass. An attack phase that never arrived because
// two of the authority's writes reached this machine as one is not replayed.
class UMars_Processor_Crawler_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Crawler_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Crawler);
        Query.Require(FMars_Tag_Crawler_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_Crawler_NeedsMirror);
        auto Crawler = InHandle.As_Crawler();

        if (utils_net::Get_HasAuthority(InHandle))
        {
            Crawler.Get_Fragment(FMars_Fragment_Crawler_Local).Last = TOptional<FMars_Fragment_Crawler_Net>();
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_Crawler_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        Reconcile(Crawler, EMars_Net_Reconcile::AsItStands);
    }

    // An expected absence, not a defect: a notify can land on an entity already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_Crawler() == false)
        { return; }

        auto Crawler = InHandle.As_Crawler();
        if (Crawler.Get_Fragment(FMars_Fragment_Crawler_Local).InitialState == EMars_Net_InitialState::Awaited)
        {
            Crawler.Get_Fragment(FMars_Fragment_Crawler_Local).InitialState = EMars_Net_InitialState::Taken;
            Reconcile(Crawler, EMars_Net_Reconcile::AsItStands);
            return;
        }

        Reconcile(Crawler, EMars_Net_Reconcile::AsItArrives);
    }

    // Last, then the copy's hurt count (a flinch has no look of its own; its count is what a copy knows of it). As it
    // stands, the ledger's attack is the one this copy took as it stood and never shows.
    private void Reconcile(FCk_Handle_Crawler& InCrawler, EMars_Net_Reconcile InHow)
    {
        const auto Ledger = InCrawler.Get_Fragment(FMars_Fragment_Crawler_Net);
        auto& Local = InCrawler.Get_Fragment(FMars_Fragment_Crawler_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[Crawler] [{InCrawler.ToString()}] has no mirror state off authority"))
        { return; }

        Local.Last = TOptional<FMars_Fragment_Crawler_Net>(Ledger);
        if (InHow == EMars_Net_Reconcile::AsItStands)
        { Local.StoodGeneration = Ledger.AttackGeneration; }

        InCrawler.Get_Fragment(FMars_Fragment_Crawler).HurtCount = Ledger.HurtCount;
    }
}
