// See AMars_Master_GameState for the actor -> entity bridge contract.
class AMars_Master_PlayerState : ACk_PlayerState_UE
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
    FCk_Handle Get_PlayerStateEntity() const
    {
        return ThisActorEntity;
    }

    UFUNCTION()
    private void OnEntityConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        ThisActorEntity = InEntityScriptHandle;
        utils_handle::Set_DebugName(ThisActorEntity, n"PlayerState");
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
