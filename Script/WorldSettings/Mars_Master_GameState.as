delegate void FMars_Delegate_GameState_OnEcsComposed(FCk_Handle InEntity);
event void FMars_Delegate_GameState_OnEcsComposed_MC(FCk_Handle InEntity);

// Every Master_* class bridges its actor to an ECS entity the same way: it carries a Ck Entity Bridge and
// BeginPlay requests the entity through it, built by the class's own entity script. The order on every machine is:
//   1. the script's DoConstruct -> Request_ComposeEntity -> EcsConstructionScript (compose features);
//   2. OnEcsComposed: the composed features are safe to read;
//   3. OnEcsReady: the entity has begun play and, on a client, its replicated values have arrived.
// Consumers that read features composed in EcsConstructionScript wait for OnEcsComposed or OnEcsReady.
UCLASS(NotPlaceable)
class UMars_Master_GameState_EntityScript : UCk_EntityScript_WithActor_UE
{
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Actor = Cast<AMars_Master_GameState>(DoGet_Actor());
        if (ck::EnsureIfNot(ck::IsValid(Actor), "[Mars_Master_GameState] the entity script's Actor is not a Master GameState"))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        Actor.Request_ComposeEntity(InHandle);
        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}

class AMars_Master_GameState : ACk_GameState_UE
{
    UPROPERTY(DefaultComponent)
    UCk_EntityBridge_ActorComponent_UE EntityBridge;

    // The proximity voice channel this GameState hosts (Mars_Voice_Assets.as).
    UPROPERTY(EditDefaultsOnly, Category = "Voice")
    UMars_Voice_Config VoiceConfig = mars::Mars_Voice_Config;

    protected FCk_Handle ThisActorEntity;

    private bool _IsEcsComposed = false;
    private FMars_Delegate_GameState_OnEcsComposed_MC _OnEcsComposed;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        EntityBridge.Promise_OnEntityReady(FCk_Delegate_EntityBridge_OnEntityReady(this, n"OnActorEcsReady"));
        EntityBridge.Request_SpawnLinkedEntity(UMars_Master_GameState_EntityScript);
    }

    // Called by the entity script while it constructs the entity (step 1 above).
    void Request_ComposeEntity(FCk_Handle InEntity)
    {
        ThisActorEntity = InEntity;
        utils_handle::Set_DebugName(ThisActorEntity, n"GameState");
        ConstructVoiceChannel();
        EcsConstructionScript(ThisActorEntity);

        _IsEcsComposed = true;
        _OnEcsComposed.Broadcast(ThisActorEntity);
    }

    // The proximity voice channel, on every machine and in every mode (a live camp has chefs too): a client applies the
    // replicated membership only once it has composed the channel itself. Chefs join it by name (Mars_Voice_Assets.as). A
    // rejected Spec ensures in Add and leaves the world without proximity voice.
    private void ConstructVoiceChannel()
    {
        if (ck::EnsureIfNot(ck::IsValid(VoiceConfig), "[Mars_Master_GameState] VoiceConfig is unset - this world has no proximity voice channel"))
        { return; }

        utils_voice_channel::Add(ThisActorEntity, VoiceConfig.ProximityChannel);
    }

    // Fires once, right after EcsConstructionScript has composed this GameState's features (step 2 above); binding after
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
