namespace constants_mars_net
{
    // The one entity every replicated runtime spawn is parented under (utils_mars_net::Get_ReplicatedSpawnOwner).
    const FName k_SpawnOwnerTag = n"TAG_MarsReplicatedSpawnOwner";
}

// Owns the net-correlated lifetime owner that every replicated runtime spawn goes under. Every world but a client's
// (a listen host, a dedicated server, a standalone session alike): a client receives replicated entities, it never spawns
// one. A world subsystem rather than the GameState because every world that can spawn needs the anchor (the camp, a
// dungeon, the net-test harness map) and none of them share a GameState.
// A Replicates script spawned under an owner with no replication driver (ck::TransientEntity()) gets replicated net
// params and no driver: it never reaches a client and cannot create a replicated inventory item, in standalone too. So
// the channel is acquired once here and published by entity tag for the synchronous lookup at every spawn site.
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
        // The automation lanes inherit this machine's PIE net mode, so every log says which world it ran.
        Log(f"[MarsNet] world [{GetWorld().GetName()}] begins play with net mode {GetWorld().GetNetMode() :n}");

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
            "[MarsNet] the ActorRelay channel came back invalid: no replicated runtime spawn can happen in this world"))
        { return; }

        _ChannelOwner = ChannelOwner;
        utils_entity_tag::Add(_ChannelOwner, constants_mars_net::k_SpawnOwnerTag);
    }
}

// The one place networking is spelled for Mars code: the replicated spawn owner and the questions around it.
namespace utils_mars_net
{
    // The replicated lifetime owner for a runtime spawn of a Replicates entity script, resolved through InAnyHandle's
    // world. Authority: the channel entity; invalid (ensure) while the channel is still being acquired, because a
    // Replicates script under a driverless owner is a broken half-replicated entity, never a working local one: a caller
    // that can run that early asks Get_HasReplicatedSpawnOwner first. Client: invalid - a client never spawns a
    // replicated thing.
    FCk_Handle Get_ReplicatedSpawnOwner(const FCk_Handle& InAnyHandle)
    {
        if (Get_IsClientWorld(InAnyHandle))
        { return FCk_Handle(); }

        const auto Owner = DoFind_SpawnOwner(InAnyHandle);
        if (ck::EnsureIfNot(ck::IsValid(Owner),
            "[MarsNet] a replicated spawn asked for the spawn owner before the channel was acquired: nothing spawns"))
        { return FCk_Handle(); }

        return Owner;
    }

    // The lifetime owner a runtime spawn of a Replicates script gets when the caller wants it to follow InOwner: InOwner
    // itself when it has a replication driver (the spawn is then its replicated child), else the replicated spawn owner.
    // One path on every authority world, standalone included; invalid on a client and while the channel is not
    // acquired (Get_ReplicatedSpawnOwner). A spawn that lands under the spawn owner no longer dies with InOwner: its
    // caller ends it.
    FCk_Handle Get_SpawnOwnerFor(const FCk_Handle& InAnyHandle, const FCk_Handle& InOwner)
    {
        if (Get_IsClientWorld(InAnyHandle))
        { return FCk_Handle(); }

        if (ck::IsValid(InOwner) && utils_entity_replication_driver::Has(InOwner))
        { return InOwner; }

        return Get_ReplicatedSpawnOwner(InAnyHandle);
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

    // The authority's clock as this machine knows it: the server's world time on the server, a smoothed estimate of it
    // on a client (the GameState learns the offset from replication, so it lags by about the one-way latency and reads
    // the local clock until the first update arrives). Without a GameState, the world's own time. Resolved through
    // InAnyHandle's world, never the implicit world context: a processor has none, and two PIE worlds share a process.
    float64 Get_ServerWorldSeconds(const FCk_Handle& InAnyHandle)
    {
        const auto World = utils_entity_lifetime::Get_WorldForEntity(InAnyHandle);
        if (ck::EnsureIfNot(ck::IsValid(World), "[MarsNet] the handle resolves to no world: it has no server time"))
        { return 0.0; }

        const auto GameState = World.GetGameState();
        if (GameState == nullptr)
        { return World.GetTimeSeconds(); }

        return GameState.GetServerWorldTimeSeconds();
    }

    // Re-resolved at every call and never latched: the tag answers "does it exist right now".
    FCk_Handle DoFind_SpawnOwner(const FCk_Handle& InAnyHandle)
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(InAnyHandle, constants_mars_net::k_SpawnOwnerTag))
        { return Candidate; }

        return FCk_Handle();
    }
}
