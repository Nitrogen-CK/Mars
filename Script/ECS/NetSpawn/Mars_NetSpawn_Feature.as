// Stance D: a host-side detector; it runs on the authority and nothing of it replicates. A Replicates spawn stamped with
// utils_net_spawn::Expect_Replicated (the world-item funnel, the anchor drain's replicated rows) must report replication
// complete within constants_net_spawn::k_ReplicationFrameBudget frames, or UMars_Processor_NetSpawn_VerifyReplication
// ensures. What makes it fire: an owner with no replication driver, a script that never finishes its construction, or a
// framework regression that builds a Replicates script on the host without replicating it.

namespace constants_net_spawn
{
    // Frames a stamped spawn may take to report replication complete on the host before the check ensures. A spawn
    // normally completes in the frame it is built; the budget covers a request the spawn processor defers while its owner
    // is still constructing.
    const int32 k_ReplicationFrameBudget = 30;
}

// Authority only, never replicated; written only by utils_net_spawn::Expect_Replicated and the verify processor. A
// replicated spawn the host has not yet seen complete, and for how many frames it has waited.
struct FMars_Fragment_NetSpawn_AwaitingReplication
{
    UPROPERTY()
    int32 Frames = 0;
}
