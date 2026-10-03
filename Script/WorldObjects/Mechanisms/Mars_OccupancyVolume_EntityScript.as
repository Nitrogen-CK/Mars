// Placeable invisible occupancy volume: a pressure plate's logic without the slab. Active while at least
// Occupancy.RequiredCount filtered entities are inside the trigger (Trigger.LocalOffset places the box), released
// Occupancy.ReleaseDelaySeconds after they leave. Asserts an optional MechanismSource while active.
class UMars_OccupancyVolume_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_Trigger_Spec Trigger;

    UPROPERTY(ExposeOnSpawn)
    FMars_Occupancy_Spec Occupancy;

    // No source is added while OutputChannel is unset.
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSource_Spec Source;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsOccupancyVolume");

        auto TriggerHandle = utils_trigger::Add(Root, Trigger);
        utils_occupancy::Add(InHandle, Occupancy, TriggerHandle);

        if (Source.OutputChannel.IsValid())
        { utils_mechanism_source::Add(InHandle, Source); }

        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}
