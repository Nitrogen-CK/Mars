// Spawns the world's anchor resolver at begin play on an anchored map; a map whose game mode is not anchored (the
// AutoTest map, the sandbox, a client) gets none. The game mode's solve is idempotent, so login order does not matter.
class UMars_AnchorResolver_Subsystem : UScriptWorldSubsystem
{
    private FCk_Handle_PendingEntityScript _PendingResolver;

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
        auto Mode = Cast<AMars_Anchored_GameMode>(Gameplay::GetGameMode());
        if (ck::Is_NOT_Valid(Mode))
        { return; }

        _PendingResolver = utils_entity_script::Request_SpawnEntity(
            ck::TransientEntity(), UMars_AnchorResolver_EntityScript, FMars_AnchorResolver_SpawnParams(Mode.Ensure_Solved()));

        utils_pending_entity_script::Promise_OnConstructed(
            _PendingResolver, FCk_Delegate_EntityScript_Constructed(this, n"OnResolverConstructed"));
    }

    UFUNCTION()
    private void OnResolverConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _PendingResolver = FCk_Handle_PendingEntityScript();
    }
}
