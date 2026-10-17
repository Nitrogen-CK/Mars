// Keeps the light sphere in step with the flame: while lit, exactly the Probe.Mars.Light probe of Get_LightPool is enabled
// (the pool follows the mount, so a lantern taken from the hand to a hook swaps probes); while dark or stowed, none.
// Polled: the pool changes with the world item's mount and the flame with the burn, and a probe toggles only on a change.
class UMars_Processor_Lantern_LightProbe : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Lantern);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Lantern_LightProbes& InProbes)
    {
        const auto Self = InHandle.As_Lantern();
        auto Want = TOptional<EMars_Lantern_Pool>();
        if (Self.Get_IsLit())
        { Want = TOptional<EMars_Lantern_Pool>(Self.Get_LightPool()); }

        const auto Unchanged = Want.IsSet() == InProbes.Shown.IsSet()
            && (Want.IsSet() == false || Want.GetValue() == InProbes.Shown.GetValue());
        if (Unchanged)
        { return; }

        if (InProbes.Shown.IsSet())
        { DoSet_Enabled(Self, InProbes.Shown.GetValue(), ECk_EnableDisable::Disable); }

        if (Want.IsSet())
        { DoSet_Enabled(Self, Want.GetValue(), ECk_EnableDisable::Enable); }

        InProbes.Shown = Want;
    }

    private void DoSet_Enabled(const FCk_Handle_Lantern& InLantern, EMars_Lantern_Pool InPool, ECk_EnableDisable InEnableDisable)
    {
        auto Probe = InLantern.Get_LightProbe(InPool);
        if (ck::IsValid(Probe))
        { utils_probe::Request_EnableDisable(Probe, FCk_Request_Probe_EnableDisable(InEnableDisable)); }
    }
}
