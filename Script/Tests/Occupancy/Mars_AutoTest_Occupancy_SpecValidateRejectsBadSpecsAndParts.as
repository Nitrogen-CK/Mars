// Validate() on the occupancy spec names each broken rule: a RequiredCount under 1, a negative or non-finite release
// delay, and missing Parts.Trigger; the rig's spec passes. utils_occupancy::Add with a spec missing its trigger ensures
// (expected below) and composes nothing.
class UMars_AutoTest_Occupancy_SpecValidateRejectsBadSpecsAndParts : UMars_AutoTestRig_Occupancy
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddTrigger(InHandle, FVector(16000.0, 330000.0, -41000.0));

        Add_Step("Validate names each broken rule", n"Step_AssertValidate");
        Add_Step("Add rejects a spec without a trigger", n"Step_AssertAddRejects");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertValidate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Good = Make_Spec(1, 0.5f).Validate();
        Assert_True(Good.IsValid(), f"a spec with a trigger, RequiredCount 1 and a 0.5 s delay validates (got [{Good.Get_Error()}])");

        AssertRejected(Make_Spec(0, 0.0f), "RequiredCount", "RequiredCount 0");
        AssertRejected(Make_Spec(1, -1.0f), "ReleaseDelaySeconds", "a negative delay");
        AssertRejected(Make_Spec(1, float32(Math::Sqrt(-1.0))), "ReleaseDelaySeconds", "a NaN delay");

        auto NoTrigger = Make_Spec(1, 0.0f);
        NoTrigger.Parts = FMars_Occupancy_Parts();
        AssertRejected(NoTrigger, "Parts.Trigger", "a spec without a trigger");
    }

    UFUNCTION()
    private void Step_AssertAddRejects(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto NoTrigger = Make_Spec(1, 0.0f);
        NoTrigger.Parts = FMars_Occupancy_Parts();
        const auto Occupancy = utils_occupancy::Add(Entity, NoTrigger);
        Assert_False(ck::IsValid(Occupancy), "Add returns an invalid handle for a spec without a trigger");
        Assert_False(Entity.Is_Occupancy(), "Add composed nothing on the entity");
    }

    private void AssertRejected(const FMars_Occupancy_Spec& InSpec, const FString& InField, const FString& InWhat)
    {
        const auto Validation = InSpec.Validate();
        Assert_False(Validation.IsValid(), f"Validate() rejects {InWhat}");
        Assert_True(Validation.Get_Error().Contains(InField), f"Validate() on {InWhat} names [{InField}] (got [{Validation.Get_Error()}])");
    }
}

// Hand-authored so Add's deliberate rejection is an expected error rather than a failure.
class AMars_AutoTest_Occupancy_SpecValidateRejectsBadSpecsAndParts_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_Occupancy_SpecValidateRejectsBadSpecsAndParts;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("rejected the spec: Parts.Trigger must be set: an occupancy without one never counts anybody");
        return Out;
    }
}
