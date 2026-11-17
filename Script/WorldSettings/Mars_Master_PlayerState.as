// See AMars_Master_GameState for the actor -> entity bridge contract.
class AMars_Master_PlayerState : ACk_PlayerState_UE
{
    UPROPERTY(DefaultComponent)
    UCk_EntityBridge_ActorComponent_UE EntityBridge;

    protected FCk_Handle ThisActorEntity;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        EntityBridge.Promise_OnEntityConstructed(FCk_Delegate_EntityScript_Constructed(this, n"OnEntityConstructed"));
        EntityBridge.Promise_OnEntityReady(FCk_Delegate_EntityBridge_OnEntityReady(this, n"OnActorEcsReady"));
        EntityBridge.Request_SpawnEntity(UCk_EntityScript_WithActor_UE);
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
