// Compose: utils_pantry_raid::Add's spec. The shipped spec validates; each sub-group's Validate rejects its own bad value
// and the Spec's Validate chains them (an empty bounds box, a guard exit under its enter, a lease shorter than the tell, an
// inverted rhythm range, a hop over 8 cm, a zero cap). A valid Add on a transform root composes the raid, tags it
// TAG_MarsPantryRaid and starts not ready (no readiness without a built field). Add compose test (no rubric row).
class UMars_AutoTest_PantryRaid_SpecValidateRejectsEveryBadGroup : UCk_AutoTest_Base
{
    default _AutoStageOriginField = false;

    private FCk_Handle _Owner;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("each bad group is rejected and the shipped spec passes", n"Step_Validate");
        Add_Step("a valid Add composes an unready raid", n"Step_Compose");
        Add_Step_WaitUntil("the raid carries TAG_MarsPantryRaid", n"Check_Tagged");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Shipped = FMars_PantryRaid_Spec();
        Assert_True(Shipped.Validate().IsValid(), f"the shipped spec validates ({Shipped.Validate().Get_Error()})");

        auto Bounds = FMars_PantryRaid_Spec();
        Bounds.EncounterBounds = FBox(FVector::ZeroVector, FVector::ZeroVector);
        Assert_False(Bounds.Validate().IsValid(), "an empty bounds box is rejected");

        auto Guard = FMars_PantryRaid_Spec();
        Guard.Guard.GuardExitCm = Guard.Guard.GuardEnterCm - 1.0f;
        Assert_False(Guard.Validate().IsValid(), "a guard exit under its enter is rejected");

        auto Theft = FMars_PantryRaid_Spec();
        Theft.Theft.LeaseSeconds = Theft.Theft.InspectSeconds + Theft.Theft.RummageSeconds;
        Assert_False(Theft.Validate().IsValid(), "a lease that does not outlast the tell is rejected");

        auto Rhythm = FMars_PantryRaid_Spec();
        Rhythm.Rhythm.EmptyBoundsMax = 0;
        Assert_False(Rhythm.Validate().IsValid(), "an inverted bound range is rejected");

        auto Hop = FMars_PantryRaid_Spec();
        Hop.Hop.MaxLiftCm = 9.0f;
        Assert_False(Hop.Validate().IsValid(), "a hop over 8 cm is rejected");

        auto Population = FMars_PantryRaid_Spec();
        Population.Population.MaxActiveRats = 0;
        Assert_False(Population.Validate().IsValid(), "a zero cap is rejected");
    }

    UFUNCTION()
    private void Step_Compose(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Owner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(_Owner, FTransform(FRotator::ZeroRotator, FVector(612000.0, -200000.0, -60000.0)), ECk_Replication::DoesNotReplicate);
        auto Raid = utils_pantry_raid::Add(_Owner, FMars_PantryRaid_Spec());
        Assert_Valid(Raid, "the raid composed");
        Assert_False(Raid.Get_IsReady(), "a raid with no field is not ready");
        Assert_Equals_Int(Raid.Get_RatCount(), 0, "no rat before readiness");
    }

    // The entity tag is applied by its own pass, not at Add.
    UFUNCTION()
    private void Check_Tagged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Found = false;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(InHandle, utils_pantry_raid::RaidTag))
        { Found = Found || Candidate == _Owner; }

        auto Result = OutResult;
        Result.Set(Found);
    }
}
