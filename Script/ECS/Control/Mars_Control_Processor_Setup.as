// One-shot per control: a control that also has a MechanismSource asserts it while active.
class UMars_Processor_Control_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Control_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Control);
        Query.Require(FMars_Tag_Control_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Control = InHandle.As_Control();

        auto Source = InHandle.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Source))
        {
            Control.BindTo_OnActiveChanged(FMars_Delegate_Control_OnActiveChanged(this, n"OnActiveChanged"));
            Source.Request_SetOutput(FMars_Request_MechanismSource_SetOutput(Control.Get_IsActive() ? EMars_MechanismSource_Output::Asserted : EMars_MechanismSource_Output::Deasserted));
        }

        // A momentary control that starts active still has to release; activating it arms the release timer.
        if (Control.Get_IsActive() && Control.Get_Fragment(FMars_Fragment_Control_Params).Behavior == EMars_Control_Behavior::Momentary)
        { Control.Request_SetActive(FMars_Request_Control_SetActive(EMars_Control_Activation::Active)); }

        Control.Request_TryRemove(FMars_Tag_Control_NeedsSetup);
    }

    UFUNCTION()
    private void OnActiveChanged(FCk_Handle_Control InControl, EMars_Control_Activation InActivation)
    {
        auto Source = InControl.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Source))
        { return; }

        const auto Output = InActivation == EMars_Control_Activation::Active ? EMars_MechanismSource_Output::Asserted : EMars_MechanismSource_Output::Deasserted;
        Source.Request_SetOutput(FMars_Request_MechanismSource_SetOutput(Output));
    }
}
