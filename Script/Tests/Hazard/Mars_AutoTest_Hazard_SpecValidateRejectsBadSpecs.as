// Validate() on the hazard spec names each broken rule: a missing Trigger and a non-finite PushImpulse; the rig's spec
// passes. utils_hazard::Add with a spec missing its trigger ensures (expected below) and composes nothing.
class UMars_AutoTest_Hazard_SpecValidateRejectsBadSpecs : UMars_AutoTestRig_Hazard
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddTriggerAndOccupant(InHandle, FVector(32000.0, 330000.0, -41000.0));

        Add_Step("Validate names each broken rule", n"Step_AssertValidate");
        Add_Step("Add rejects a spec without a trigger", n"Step_AssertAddRejects");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertValidate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Good = FMars_Hazard_Spec();
        Good.Trigger = _Trigger;
        Good.PushImpulse = FVector(0.0, 0.0, 500.0);
        Assert_True(Good.Validate().IsValid(), f"a spec with a trigger and a finite push validates (got [{Good.Validate().Get_Error()}])");

        auto NoTrigger = Good;
        NoTrigger.Trigger = FCk_Handle_Trigger();
        AssertRejected(NoTrigger, "Trigger", "a spec without a trigger");

        auto NaNPush = Good;
        NaNPush.PushImpulse.Z = Math::Sqrt(-1.0);
        AssertRejected(NaNPush, "PushImpulse", "a NaN push");
    }

    UFUNCTION()
    private void Step_AssertAddRejects(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        const auto Hazard = utils_hazard::Add(Entity, FMars_Hazard_Spec());
        Assert_False(ck::IsValid(Hazard), "Add returns an invalid handle for a spec without a trigger");
        Assert_False(Entity.Is_Hazard(), "Add composed nothing on the entity");
    }

    private void AssertRejected(const FMars_Hazard_Spec& InSpec, const FString& InField, const FString& InWhat)
    {
        const auto Validation = InSpec.Validate();
        Assert_False(Validation.IsValid(), f"Validate() rejects {InWhat}");
        Assert_True(Validation.Get_Error().Contains(InField), f"Validate() on {InWhat} names [{InField}] (got [{Validation.Get_Error()}])");
    }
}

// Hand-authored so Add's deliberate rejection is an expected error rather than a failure.
class AMars_AutoTest_Hazard_SpecValidateRejectsBadSpecs_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_Hazard_SpecValidateRejectsBadSpecs;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("rejected the spec: Trigger must be set: a hazard without one never hits");
        return Out;
    }
}
