// See AMars_Master_GameState for the actor -> entity bridge contract.
UCLASS(NotPlaceable)
class UMars_Master_PlayerState_EntityScript : UCk_EntityScript_WithActor_UE
{
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Actor = Cast<AMars_Master_PlayerState>(DoGet_Actor());
        if (ck::EnsureIfNot(ck::IsValid(Actor), "[Mars_Master_PlayerState] the entity script's Actor is not a Master PlayerState"))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        Actor.Request_ComposeEntity(InHandle);
        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}

class AMars_Master_PlayerState : ACk_PlayerState_UE
{
    UPROPERTY(DefaultComponent)
    UCk_EntityBridge_ActorComponent_UE EntityBridge;

    protected FCk_Handle ThisActorEntity;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        EntityBridge.Promise_OnEntityReady(FCk_Delegate_EntityBridge_OnEntityReady(this, n"OnActorEcsReady"));
        EntityBridge.Request_SpawnLinkedEntity(UMars_Master_PlayerState_EntityScript);
    }

    UFUNCTION()
    FCk_Handle Get_PlayerStateEntity() const
    {
        return ThisActorEntity;
    }

    // Called by the entity script while it constructs the entity.
    void Request_ComposeEntity(FCk_Handle InEntity)
    {
        ThisActorEntity = InEntity;
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
