// The host-side check behind utils_net_spawn::Expect_Replicated: a stamped Replicates spawn must report replication
// complete within constants_net_spawn::k_ReplicationFrameBudget frames. It tells two causes apart: built with no
// replication driver (its owner has none, so it never reaches a client), and built but not complete past the budget (it
// never finished its construction, or the framework built it without replicating it).
// Once per frame, never pumped (no dirty marker): the frame count is the budget. A spawn whose request has not executed
// yet (no entity script attached) only counts frames. An entity that begins destroying stops being checked.
//
// Authority only: Expect_Replicated stamps nothing on a client.
class UMars_Processor_NetSpawn_VerifyReplication : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_NetSpawn_AwaitingReplication& InAwaiting)
    {
        if (utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        {
            InHandle.Request_TryRemove(FMars_Fragment_NetSpawn_AwaitingReplication);
            return;
        }

        InAwaiting.Frames += 1;
        const auto IsBuilt = utils_entity_script::Has(InHandle);
        if (IsBuilt)
        {
            if (ck::EnsureIfNot(utils_entity_replication_driver::Has(InHandle),
                f"[NetSpawn] [{InHandle.ToString()}] ({DoGet_ScriptName(InHandle)}) was expected to replicate, but its owner "
                + f"[{utils_entity_lifetime::Get_LifetimeOwner(InHandle).ToString()}] has no replication driver: it never reaches a client"))
            {
                InHandle.Request_TryRemove(FMars_Fragment_NetSpawn_AwaitingReplication);
                return;
            }

            // Has is checked first: on a driverless entity this query ensures.
            if (utils_entity_replication_driver::Get_IsReplicationComplete(InHandle))
            {
                InHandle.Request_TryRemove(FMars_Fragment_NetSpawn_AwaitingReplication);
                return;
            }
        }

        const auto Frames = InAwaiting.Frames;
        if (ck::EnsureIfNot(Frames <= constants_net_spawn::k_ReplicationFrameBudget,
            f"[NetSpawn] [{InHandle.ToString()}] ({DoGet_ScriptName(InHandle)}) under [{utils_entity_lifetime::Get_LifetimeOwner(InHandle).ToString()}] "
            + f"was expected to replicate and has not after {Frames} frames: either it never finished its construction (a "
            + "Continue-flow script that never calls DoFinishConstruction is never replicated), or the framework built it "
            + "without replicating it"))
        {
            // InAwaiting is invalid past this line.
            InHandle.Request_TryRemove(FMars_Fragment_NetSpawn_AwaitingReplication);
        }
    }

    private FString DoGet_ScriptName(const FCk_Handle& InHandle) const
    {
        if (utils_entity_script::Has(InHandle) == false)
        { return "not built yet"; }

        return f"{utils_entity_script::Get_ScriptClass(InHandle.As_EntityScript()).Get().GetName()}";
    }
}
