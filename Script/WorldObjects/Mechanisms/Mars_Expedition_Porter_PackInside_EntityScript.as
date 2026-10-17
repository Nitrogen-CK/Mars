// Matches the expedition's 6 x 4 m freight reliquary. A pack anywhere inside keeps the existing grace circuit alive;
// a pack outside its walls cannot power it. The interior rescue chain remains reachable without the pack.
class UMars_Expedition_Porter_PackInside_EntityScript : UMars_OccupancyVolume_EntityScript
{
    default Source.OutputChannel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Gauntlet.Porter.PackInside");

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Trigger.Shape = EMars_Trigger_Shape::Box;
        Trigger.BoxHalfExtents = FVector(280.0, 175.0, 60.0);
        Trigger.LocalOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 60.0));
        Trigger.DetectionFilter = GameplayTag::MakeGameplayTagContainerFromTag(GameplayTags::Probe_Mars_Backpack);
        Occupancy.RequiredCount = 1;
        Occupancy.ReleaseDelaySeconds = 0.0f;
        return Super::DoConstruct(InHandle);
    }
}
