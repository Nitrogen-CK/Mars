// Spawns the world's eye-swarm roster (Mars_EyeSwarm_Roster_EntityScript.as) at begin play wherever cosmetics run: every
// game or PIE world on a client, a listen server or standalone; never a dedicated server, which draws no eyes. One roster
// feeds every eye cluster in the world, so placed clusters need no per-map setup.
class UMars_EyeSwarmRoster_Subsystem : UScriptWorldSubsystem
{
    private FCk_Handle_PendingEntityScript _PendingRoster;

    UFUNCTION(BlueprintOverride)
    bool ShouldCreateSubsystem(UObject InOuter) const
    {
        auto OuterWorld = InOuter.GetWorld();
        if (ck::Is_NOT_Valid(OuterWorld))
        { return false; }

        const auto WorldType = OuterWorld.WorldType;
        return WorldType == EWorldType::Game || WorldType == EWorldType::PIE;
    }

    UFUNCTION(BlueprintOverride)
    void OnWorldBeginPlay()
    {
        if (System::IsDedicatedServer() || ck::CanExecuteCosmeticEvents() == false)
        { return; }

        _PendingRoster = utils_entity_script::Request_SpawnEntity(
            ck::TransientEntity(), UMars_EyeSwarmRoster_EntityScript, UMars_EyeSwarmRoster_EntityScript::Params());

        utils_pending_entity_script::Promise_OnConstructed(
            _PendingRoster, FCk_Delegate_EntityScript_Constructed(this, n"OnRosterConstructed"));
    }

    UFUNCTION()
    private void OnRosterConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _PendingRoster = FCk_Handle_PendingEntityScript();
    }
}
