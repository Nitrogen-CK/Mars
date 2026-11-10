// Placeable invisible occupancy volume: a pressure plate's logic without the slab. Active while at least
// Occupancy.RequiredCount filtered entities are inside the trigger (Trigger.LocalOffset places the box), released
// Occupancy.ReleaseDelaySeconds after they leave. Asserts an optional MechanismSource while active.
class UMars_OccupancyVolume_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    // Stance A: placed by the authority's spawner; the volume, its root transform and its occupancy ledger replicate;
    // the trigger is built on every machine and only the authority counts from it.
    default _Replication = ECk_Replication::Replicates;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_Trigger_Spec Trigger;

    UPROPERTY(ExposeOnSpawn)
    FMars_Occupancy_Spec Occupancy;

    // Optional: unwired while OutputChannel is unset (utils_mechanism_source::TryAdd).
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSource_Spec Source;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::Replicates);
        utils_entity_tag::Add(InHandle, n"TAG_MarsOccupancyVolume");

        auto TriggerHandle = utils_trigger::Add(Root, Trigger);
        auto OccupancySpec = Occupancy;
        OccupancySpec.Parts = FMars_Occupancy_Parts(TriggerHandle);
        utils_occupancy::Add(InHandle, OccupancySpec);

        utils_mechanism_source::TryAdd(InHandle, Source);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}
