// Polls each hook against the last pass (the KeyLock sync shape). A change of the hung lantern broadcasts OnLanternChanged;
// a MechanismSource on the same entity is asserted while the hook holds a lit lantern, so it follows the lantern's shutter
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
        DoSync_Source(InHandle, InState, Self.Get_HoldsLitLantern());

        auto Now = InState.Inventory.Get_SoleItem();
        if (Now == InState.LastSeen)
        { return; }

        InState.LastSeen = Now;
        if (Self.Has_Fragment(FMars_Fragment_LanternHook_Signals))
        { Self.Get_Fragment(FMars_Fragment_LanternHook_Signals).OnLanternChanged.Broadcast(Self, Now); }
    }

    private void DoSync_Source(FCk_Handle& InHandle, FMars_Fragment_LanternHook& InState, bool InAsserted)
    {
        if (InState.LastAsserted.IsSet() && InState.LastAsserted.GetValue() == InAsserted)
        { return; }

        InState.LastAsserted = TOptional<bool>(InAsserted);

        auto Source = InHandle.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Source))
        { return; }

        const auto Output = InAsserted ? EMars_MechanismSource_Output::Asserted : EMars_MechanismSource_Output::Deasserted;
        Source.Request_SetOutput(FMars_Request_MechanismSource_SetOutput(Output));
    }
}
