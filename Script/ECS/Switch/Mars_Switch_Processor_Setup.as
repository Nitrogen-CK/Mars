// The link: a switch that also has a MechanismSource asserts it while pressed.
class UMars_Processor_Switch_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Switch_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Switch);
        Query.Require(FMars_Tag_Switch_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Switch = InHandle.As_Switch();

        auto Source = InHandle.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Source))
        {
            Switch.BindTo_OnPressedChanged(FMars_Delegate_Switch_OnPressedChanged(this, n"OnPressedChanged"));
            Source.Request_SetAsserted(Switch.Get_IsPressed());
        }

        Switch.Request_TryRemove(FMars_Tag_Switch_NeedsSetup);
    }

    UFUNCTION()
    private void OnPressedChanged(FCk_Handle_Switch InSwitch, bool InPressed)
    {
        auto Source = InSwitch.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Source))
        { return; }

        Source.Request_SetAsserted(InPressed);
    }
}
