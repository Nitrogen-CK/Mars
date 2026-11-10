namespace constants_mars_net
{
    // The one entity every replicated runtime spawn is parented under (utils_mars_net::Get_ReplicatedSpawnOwner).
    const FName k_SpawnOwnerTag = n"TAG_MarsReplicatedSpawnOwner";
}

// Owns the net-correlated lifetime owner that every replicated runtime spawn goes under. Server only: a client receives
// replicated entities, it never spawns one. A world subsystem rather than the GameState because every world that can
// spawn needs the anchor (the camp, a dungeon, the net-test harness map) and none of them share a GameState.
// A Replicates spawn under a non-replicating owner (ck::TransientEntity()) never reaches a client, so the channel is
// acquired once here and published by entity tag for the synchronous lookup at every spawn site.
class UMars_Net_Subsystem : UScriptWorldSubsystem
{
    private FCk_Handle_PendingActorRelay _PendingChannel;

    // The channel this world's subsystem acquired. Channels are pooled and shared: never destroy it.
    private FCk_Handle _ChannelOwner;

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
        if (System::IsServer() == false)
        { return; }

        _PendingChannel = utils_actor_relay::Request_AcquireChannel(GameplayTags::ActorRelay_Generic);
        _PendingChannel.Promise_OnAcquired(FCk_Delegate_ActorRelay_Acquired(this, n"OnChannelAcquired"));
    }

    UFUNCTION()
    private void OnChannelAcquired(FCk_ActorRelay_ChannelResult InResult)
    {
        _PendingChannel = FCk_Handle_PendingActorRelay();

        auto ChannelOwner = InResult.Get_ChannelEntity();
        if (ck::EnsureIfNot(ck::IsValid(ChannelOwner),
            "[MarsNet] the ActorRelay channel came back invalid: every replicated runtime spawn in this world degrades to a local one"))
        { return; }

        _ChannelOwner = ChannelOwner;
        utils_entity_tag::Add(_ChannelOwner, constants_mars_net::k_SpawnOwnerTag);
    }
}

// The one place networking is spelled for Mars code: the replicated spawn owner and the questions around it.
namespace utils_mars_net
{
    // The replicated lifetime owner for a runtime spawn of a Replicates entity script, resolved through InAnyHandle's
    // world. Authority: the channel entity, or (ensure) ck::TransientEntity() while the channel is still being acquired,
    // so a too-early spawn degrades to a local one instead of crashing. Client: invalid - a client never spawns a
    // replicated thing; callers gate on utils_net::Get_HasAuthority first.
    FCk_Handle Get_ReplicatedSpawnOwner(const FCk_Handle& InAnyHandle)
    {
        if (Get_IsClientWorld(InAnyHandle))
        { return FCk_Handle(); }

        const auto Owner = DoFind_SpawnOwner(InAnyHandle);
        if (ck::EnsureIfNot(ck::IsValid(Owner),
            "[MarsNet] a replicated spawn asked for the spawn owner before the channel was acquired: it spawns local and never reaches a client"))
        { return ck::TransientEntity(); }

        return Owner;
    }

    // Whether this world's spawn owner is published yet; always false on a client. The readiness query for code that
    // can run before the channel arrives (begin play, the net tests), so it never ensures.
    bool Get_HasReplicatedSpawnOwner(const FCk_Handle& InAnyHandle)
    {
        if (Get_IsClientWorld(InAnyHandle))
        { return false; }

        return ck::IsValid(DoFind_SpawnOwner(InAnyHandle));
    }

    // Asks the world, not the handle's role, so the answer holds for any handle, replicated or not.
    bool Get_IsClientWorld(const FCk_Handle& InAnyHandle)
    {
        const auto World = utils_entity_lifetime::Get_WorldForEntity(InAnyHandle);
        if (ck::EnsureIfNot(ck::IsValid(World), "[MarsNet] the handle resolves to no world"))
        { return false; }

        return utils_net::Get_NetMode(World) == ECk_Net_NetModeType::Client;
    }

    // Re-resolved at every call and never latched: the tag answers "does it exist right now".
    FCk_Handle DoFind_SpawnOwner(const FCk_Handle& InAnyHandle)
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(InAnyHandle, constants_mars_net::k_SpawnOwnerTag))
        { return Candidate; }

        return FCk_Handle();
    }
}
