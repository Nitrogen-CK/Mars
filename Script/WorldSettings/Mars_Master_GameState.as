delegate void FMars_Delegate_GameState_OnEcsComposed(FCk_Handle InEntity);
event void FMars_Delegate_GameState_OnEcsComposed_MC(FCk_Handle InEntity);

// Every Master_* class bridges its actor to an ECS entity the same way: BeginPlay spawns a
// UCk_EntityScript_WithActor_UE. The real order on authority is:
//   1. link: Promise_OnActorEcsReady -> OnEcsReady fires INSIDE the entity's Construct (the actor and entity are
//      linked, but nothing is composed yet - ValuesReplicated "collapses to link-time on authority");
//   2. OnConstructed -> EcsConstructionScript (compose features);
//   3. OnEcsComposed: the composed features are safe to read.
// Consumers that read features composed in EcsConstructionScript must wait for OnEcsComposed, not OnEcsReady.
class AMars_Master_GameState : ACk_GameState_UE
{
    protected FCk_Handle ThisActorEntity;

    private bool _IsEcsComposed = false;
    private FMars_Delegate_GameState_OnEcsComposed_MC _OnEcsComposed;

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

        _IsEcsComposed = true;
        _OnEcsComposed.Broadcast(ThisActorEntity);
    }

    // Fires once, right after EcsConstructionScript has composed this GameState's features; binding after the fact
    // calls the delegate immediately. Promise_OnActorEcsReady is NOT this: on authority it fires at LINK time, inside
    // the entity's Construct, before EcsConstructionScript (ECk_ActorEcsReady_Policy::ValuesReplicated "collapses to
    // link-time on authority").
    void Promise_OnEcsComposed(FMars_Delegate_GameState_OnEcsComposed InDelegate)
    {
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
