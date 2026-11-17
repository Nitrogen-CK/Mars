delegate void FMars_Delegate_GameState_OnEcsComposed(FCk_Handle InEntity);
event void FMars_Delegate_GameState_OnEcsComposed_MC(FCk_Handle InEntity);

// Every Master_* class bridges its actor to an ECS entity the same way: it carries a Ck Entity Bridge and
// BeginPlay requests the entity through it. The order on every machine is:
//   1. OnEntityConstructed -> EcsConstructionScript (compose features);
//   2. OnEcsComposed: the composed features are safe to read;
//   3. OnEcsReady: the entity has begun play and, on a client, its replicated values have arrived.
// Consumers that read features composed in EcsConstructionScript wait for OnEcsComposed or OnEcsReady.
class AMars_Master_GameState : ACk_GameState_UE
{
    UPROPERTY(DefaultComponent)
    UCk_EntityBridge_ActorComponent_UE EntityBridge;

    protected FCk_Handle ThisActorEntity;

    private bool _IsEcsComposed = false;
    private FMars_Delegate_GameState_OnEcsComposed_MC _OnEcsComposed;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        EntityBridge.Promise_OnEntityConstructed(FCk_Delegate_EntityScript_Constructed(this, n"OnEntityConstructed"));
        EntityBridge.Promise_OnEntityReady(FCk_Delegate_EntityBridge_OnEntityReady(this, n"OnActorEcsReady"));
        EntityBridge.Request_SpawnEntity(UCk_EntityScript_WithActor_UE);
    }

    UFUNCTION()
    private void OnEntityConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        ThisActorEntity = InEntityScriptHandle;
        utils_handle::Set_DebugName(ThisActorEntity, n"GameState");
        EcsConstructionScript(ThisActorEntity);

        _IsEcsComposed = true;
        _OnEcsComposed.Broadcast(ThisActorEntity);
    }

    // Fires once, right after EcsConstructionScript has composed this GameState's features (step 3 above); binding after
    // the fact calls the delegate immediately.
    void Promise_OnEcsComposed(FMars_Delegate_GameState_OnEcsComposed InDelegate)
    {
        if (ck::EnsureIfNot(InDelegate.IsBound(), "[Mars_Master_GameState] Promise_OnEcsComposed needs a bound delegate"))
        { return; }

        if (_IsEcsComposed)
        {
            InDelegate.ExecuteIfBound(ThisActorEntity);
            return;
        }

        _OnEcsComposed.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
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
