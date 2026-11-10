namespace utils_net_spawn
{
    // The host-side check that InEntity, a Replicates entity script whose spawn was just requested (it may still be under
    // construction), reaches replication complete within constants_net_spawn::k_ReplicationFrameBudget frames
    // (UMars_Processor_NetSpawn_VerifyReplication ensures otherwise). Only on an authority's game world; a no-op on a
    // client and in an editor world. Never for an actor-bridged (WithActor) root: its driver arrives with its actor.
    void Expect_Replicated(FCk_Handle& InEntity)
    {
        if (ck::Is_NOT_Valid(InEntity))
        { return; }

        const auto World = utils_entity_lifetime::Get_WorldForEntity(InEntity);
        if (ck::Is_NOT_Valid(World))
        { return; }

        if (World.WorldType != EWorldType::Game && World.WorldType != EWorldType::PIE)
        { return; }

        if (utils_net::Get_NetMode(World) == ECk_Net_NetModeType::Client)
        { return; }

        if (InEntity.Has_Fragment(FMars_Fragment_NetSpawn_AwaitingReplication))
        { return; }

        InEntity.Add_Fragment(FMars_Fragment_NetSpawn_AwaitingReplication());
    }
}
