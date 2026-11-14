// Once per Maw: the authority drops the mirror state (its drain publishes the ledger). A machine without authority
// binds the ledger's rep-notify and reconciles once as it stands, so a copy that composed late shows the Maw where it
// is; each later change is reconciled as it arrives, and the tick then plays the rise, the sink and the jaw's ease on
// this machine's clock. A reconcile raises nothing: OnStance is the tick's.
class UMars_Processor_RootMaw_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_RootMaw_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_RootMaw);
        Query.Require(FMars_Tag_RootMaw_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_RootMaw_NeedsMirror);
        auto Maw = InHandle.As_RootMaw();

        if (utils_net::Get_HasAuthority(InHandle))
        {
            Maw.Get_Fragment(FMars_Fragment_RootMaw_Local).Last = TOptional<FMars_Fragment_RootMaw_Net>();
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_RootMaw_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        Reconcile(Maw, EMars_RootMaw_Reconcile::AsItStands);
    }

    // An expected absence, not a defect: a notify can land on an entity already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_RootMaw() == false)
        { return; }

        auto Maw = InHandle.As_RootMaw();
        Reconcile(Maw, EMars_RootMaw_Reconcile::AsItArrives);
    }

    // Last is written before the state. As it stands, Emerge and the jaw are set to where the ledger has them; as it
    // arrives, the tick runs them there.
    private void Reconcile(FCk_Handle_RootMaw& InMaw, EMars_RootMaw_Reconcile InHow)
    {
        const auto Ledger = InMaw.Get_Fragment(FMars_Fragment_RootMaw_Net);
        auto& Local = InMaw.Get_Fragment(FMars_Fragment_RootMaw_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[RootMaw] [{InMaw.ToString()}] has no mirror state off authority"))
        { return; }

        Local.Last = TOptional<FMars_Fragment_RootMaw_Net>(Ledger);

        auto& Posture = InMaw.Get_Fragment(FMars_Fragment_RootMaw_Posture);
        auto& Mouth = InMaw.Get_Fragment(FMars_Fragment_RootMaw_Mouth);
        Posture.Stance = Ledger.Stance;
        Mouth.Gape = Ledger.Gape;
        if (InHow == EMars_RootMaw_Reconcile::AsItArrives)
        { return; }

        Posture.Emerge = Ledger.Stance == EMars_RootMaw_Stance::Emerged ? 1.0f : 0.0f;
        Mouth.JawOpen = Ledger.Gape;
    }
}
