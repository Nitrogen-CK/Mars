// The link: every rising edge on the MechanismSink on the bellkeeper's own entity is a commit, and the optional
// MechanismSource on that entity is asserted while the lock is solved.
class UMars_Processor_Bellkeeper_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Bellkeeper_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Bellkeeper);
        Query.Require(FMars_Tag_Bellkeeper_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Bellkeeper = InHandle.As_Bellkeeper();

        auto Sink = InHandle.As_MechanismSink(ECk_SanityCheck::UnChecked);
        const auto HasSink = ck::IsValid(Sink);
        ck::EnsureIfNot(HasSink, f"[Bellkeeper] [{Bellkeeper.ToString()}] has no MechanismSink on its entity; nothing can commit");
        if (HasSink)
        { Sink.BindTo_OnInputRose(FMars_Delegate_MechanismSink_OnInputRose(this, n"OnSinkInputRose")); }

        auto Source = InHandle.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Source))
        {
            const auto Output = Bellkeeper.Get_IsSolved() ? EMars_MechanismSource_Output::Asserted : EMars_MechanismSource_Output::Deasserted;
            Source.Request_SetOutput(utils_mechanism_source::Make_SetOutput(Output));
        }

        auto VentCycle = Bellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper_Params).VentCycle;
        if (ck::IsValid(VentCycle))
        { VentCycle.BindTo_OnRunningChanged(FMars_Delegate_Cycle_OnRunningChanged(this, n"OnVentCycleChanged")); }

        Bellkeeper.Request_TryRemove(FMars_Tag_Bellkeeper_NeedsSetup);
    }

    UFUNCTION()
    private void OnSinkInputRose(FCk_Handle_MechanismSink InSink, FGameplayTag InChannel)
    {
        auto Bellkeeper = InSink.As_Bellkeeper();
        Bellkeeper.Request_Commit(FMars_Request_Bellkeeper_Commit());
    }

    UFUNCTION()
    private void OnVentCycleChanged(FCk_Handle_Cycle InCycle, EMars_Cycle_RunState InRunState)
    {
        auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InCycle);
        if (ck::Is_NOT_Valid(Owner))
        { return; }

        auto Bellkeeper = Owner.As_Bellkeeper(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Bellkeeper) || Bellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper_Params).VentCycle != InCycle)
        { return; }

        Bellkeeper.Request_VentCycleChanged(FMars_Request_Bellkeeper_VentCycleChanged(InCycle, InRunState));
    }
}
