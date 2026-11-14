// The pantry raid encounter: composes the PantryRaid kernel on its root (the bounds are local to SpawnTransform's
// translation) with the ground nav field it waits on. It draws nothing; dens and packs are discovered inside the bounds, and
// the rats it spawns are its own (they live under this entity, never under a den). The entity and its root replicate;
// every machine composes the kernel, and only the machine with authority runs it. NavVolume resolves only there: a copy
// reads it invalid and never uses it.
class UMars_PantryRaid_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    // Stance C: the authority runs the raid; the entity replicates only so that a copy has no authority and is inert.
    default _Replication = ECk_Replication::Replicates;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_PantryRaid_Spec Spec;

    // The encounter's ground nav field (readiness waits on it being built and current).
    UPROPERTY(ExposeOnSpawn)
    FCk_Handle_GroundNavVolume NavVolume;

    private FCk_Handle_PantryRaid _Raid;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        InHandle.Request_OverrideToSelf();
        utils_handle::Set_DebugName(InHandle, n"PantryRaid");

        utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::Replicates);
        auto Composed = Spec;
        Composed.Parts.NavVolume = NavVolume;
        _Raid = utils_pantry_raid::Add(InHandle, Composed);
        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    FCk_Handle_PantryRaid Get_Raid() const
    {
        return _Raid;
    }
}
