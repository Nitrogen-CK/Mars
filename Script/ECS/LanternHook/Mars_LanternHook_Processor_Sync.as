// Polls each hook against the last pass (the KeyLock sync shape). A change of the hung lantern broadcasts OnLanternChanged;
// a MechanismSource on the same entity is asserted while the hook holds a lit lantern, so it follows the lantern's flame
// and fuel as well as what hangs here (asked only when that reading changes).
class UMars_Processor_LanternHook_Sync : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_LanternHook);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_LanternHook& InState)
    {
        auto Self = InHandle.As_LanternHook();
        const auto Output = Self.Get_HoldsLitFlame() ? EMars_MechanismSource_Output::Asserted : EMars_MechanismSource_Output::Deasserted;
        DoSync_Source(InHandle, InState, Output);

        auto Now = InState.Inventory.Get_SoleItem();
        if (Now == InState.LastSeen)
        { return; }

        InState.LastSeen = Now;
        if (Self.Has_Fragment(FMars_Fragment_LanternHook_Signals))
        { Self.Get_Fragment(FMars_Fragment_LanternHook_Signals).OnLanternChanged.Broadcast(Self, Now); }
    }

    private void DoSync_Source(FCk_Handle& InHandle, FMars_Fragment_LanternHook& InState, EMars_MechanismSource_Output InOutput)
    {
        if (InState.LastOutput.IsSet() && InState.LastOutput.GetValue() == InOutput)
        { return; }

        InState.LastOutput = TOptional<EMars_MechanismSource_Output>(InOutput);

        auto Source = InHandle.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Source))
        { return; }

        Source.Request_SetOutput(utils_mechanism_source::Make_SetOutput(InOutput));
    }
}
