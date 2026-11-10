// Spawns the world's mechanism driver entity at begin play, on the authority only; the driver finds every source and
// sink through entity tags.
class UMars_MechanismDriver_Subsystem : UScriptWorldSubsystem
{
    private FCk_Handle_PendingEntityScript _PendingDriver;

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
        // The graph evaluates on the authority only; clients receive the sinks' power through the replicated ledgers.
        if (System::IsServer() == false)
        { return; }

        _PendingDriver = utils_entity_script::Request_SpawnEntity(
            ck::TransientEntity(), UMars_MechanismDriver_EntityScript, UMars_MechanismDriver_EntityScript::Params());

        utils_pending_entity_script::Promise_OnConstructed(
            _PendingDriver, FCk_Delegate_EntityScript_Constructed(this, n"OnDriverEntityConstructed"));
    }

    UFUNCTION()
    private void OnDriverEntityConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _PendingDriver = FCk_Handle_PendingEntityScript();
    }
}
