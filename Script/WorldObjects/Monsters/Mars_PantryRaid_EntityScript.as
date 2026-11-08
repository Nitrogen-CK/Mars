// The pantry raid encounter: composes the PantryRaid kernel on its root (the bounds are local to SpawnTransform's
// translation) with the ground nav field it waits on. It draws nothing; dens and packs are discovered inside the bounds, and
// the rats it spawns are its own (they live under this entity, never under a den).
class UMars_PantryRaid_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

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

        utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
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
