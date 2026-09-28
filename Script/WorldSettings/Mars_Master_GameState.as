// Every Master_* class bridges its actor to an ECS entity the same way: BeginPlay spawns a
// UCk_EntityScript_WithActor_UE, OnConstructed runs EcsConstructionScript (compose features), and
// Promise_OnActorEcsReady runs OnEcsReady (the entity is linked and safe to read).
class AMars_Master_GameState : ACk_GameState_UE
{
    protected FCk_Handle ThisActorEntity;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        auto PendingEntity = utils_entity_script::Request_SpawnEntity(
            ck::TransientEntity(), UCk_EntityScript_WithActor_UE, FCk_EntityScript_WithActor_SpawnParams(this));

        utils_pending_entity_script::Promise_OnConstructed(
            PendingEntity, FCk_Delegate_EntityScript_Constructed(this, n"OnEntityConstructed"));
        utils_owning_actor::Promise_OnActorEcsReady(this, FCk_Delegate_OwningActor_OnEcsReady(this, n"OnActorEcsReady"));
    }

    UFUNCTION()
    private void OnEntityConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        ThisActorEntity = InEntityScriptHandle;
        utils_handle::Set_DebugName(ThisActorEntity, n"GameState");
        EcsConstructionScript(ThisActorEntity);
    }

    UFUNCTION()
    private void OnActorEcsReady(AActor InActor, FCk_Handle InEntity)
    {
        OnEcsReady(InEntity);
    }

    UFUNCTION(BlueprintEvent)
    protected void EcsConstructionScript(FCk_Handle InEntity)
    {
    }

    UFUNCTION(BlueprintEvent)
    protected void OnEcsReady(FCk_Handle InEntity)
    {
    }
}
