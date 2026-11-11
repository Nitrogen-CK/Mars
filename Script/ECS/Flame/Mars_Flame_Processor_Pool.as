// Follows the flame from pool to pool: on the edge into Stowed a lit flame that snuffs when stowed goes out (the belt is no
// place for an open flame); then, while lit, exactly the Probe.Mars.Light probe of Get_LightPool is enabled (a lantern
// taken from the hand to the belt or a hook swaps probes), and none while dark or in a pool it has no probe for. Polled:
// the pool changes with the world item's mount and the flame with the burn, and a probe toggles only on a change. The
// pool and the probes follow this machine's mount on every machine; the snuff runs only with authority.
class UMars_Processor_Flame_Pool : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Flame);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Flame& InState)
    {
        auto& Local = InHandle.Get_Fragment(FMars_Fragment_Flame_Local);
        auto Self = InHandle.As_Flame();
        const auto& Params = Self.Get_Fragment(FMars_Fragment_Flame_Params);
        const auto Pool = Self.Get_LightPool();

        const auto IsNewPool = Local.LastPool.IsSet() && Local.LastPool.GetValue() != Pool;
        const auto SnuffsHere = Pool == EMars_Flame_Pool::Stowed && Params.OnStow == EMars_Flame_OnStow::Snuffs;
        // A flame goes out where its ignition is decided.
        if (IsNewPool && SnuffsHere && InState.Ignition == EMars_Flame_Ignition::Lit && utils_net::Get_HasAuthority(InHandle))
        {
            const auto Before = utils_flame::Make_Reading(Params, InState);
            InState.Ignition = EMars_Flame_Ignition::Snuffed;
            InState.Condition = utils_flame::Get_Condition(Params, InState, Local);
            utils_flame::Mark_LedgerDirty(InHandle, Params);
            utils_flame::Apply_Changes(Self, Before, utils_flame::Make_Reading(Params, InState));
        }

        Local.LastPool = TOptional<EMars_Flame_Pool>(Pool);

        if (Self.Has_Fragment(FMars_Fragment_Flame_LightProbes) == false)
        { return; }

        DoSync_Probes(Self, Pool);
    }

    private void DoSync_Probes(FCk_Handle_Flame& InFlame, EMars_Flame_Pool InPool)
    {
        auto& Probes = InFlame.Get_Fragment(FMars_Fragment_Flame_LightProbes);
        auto Want = TOptional<EMars_Flame_Pool>();
        if (InFlame.Get_IsLit() && ck::IsValid(InFlame.Get_LightProbe(InPool)))
        { Want = TOptional<EMars_Flame_Pool>(InPool); }

        const auto Unchanged = Want.IsSet() == Probes.Shown.IsSet()
            && (Want.IsSet() == false || Want.GetValue() == Probes.Shown.GetValue());
        if (Unchanged)
        { return; }

        if (Probes.Shown.IsSet())
        { DoSet_Enabled(InFlame, Probes.Shown.GetValue(), ECk_EnableDisable::Disable); }

        if (Want.IsSet())
        { DoSet_Enabled(InFlame, Want.GetValue(), ECk_EnableDisable::Enable); }

        Probes.Shown = Want;
    }

    private void DoSet_Enabled(const FCk_Handle_Flame& InFlame, EMars_Flame_Pool InPool, ECk_EnableDisable InEnableDisable)
    {
        auto Probe = InFlame.Get_LightProbe(InPool);
        if (ck::IsValid(Probe))
        { utils_probe::Request_EnableDisable(Probe, FCk_Request_Probe_EnableDisable(InEnableDisable)); }
    }
}
