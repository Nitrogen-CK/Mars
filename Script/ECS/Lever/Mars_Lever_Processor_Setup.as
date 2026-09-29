// The link: a lever that also has a MechanismSource asserts it while pulled.
class UMars_Processor_Lever_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Lever_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Lever);
        Query.Require(FMars_Tag_Lever_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Lever = InHandle.As_Lever();

        auto Source = InHandle.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Source))
        {
            Lever.BindTo_OnPulledChanged(FMars_Delegate_Lever_OnPulledChanged(this, n"OnPulledChanged"));
            Source.Request_SetAsserted(Lever.Get_IsPulled());
        }

        Lever.Request_TryRemove(FMars_Tag_Lever_NeedsSetup);
    }

    UFUNCTION()
    private void OnPulledChanged(FCk_Handle_Lever InLever, bool InPulled)
    {
        auto Source = InLever.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Source))
        { return; }

        Source.Request_SetAsserted(InPulled);
    }
}
