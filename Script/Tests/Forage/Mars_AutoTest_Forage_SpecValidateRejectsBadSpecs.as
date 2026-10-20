// A well-formed Forage spec validates; each broken rule (no Definition, Charges 0, Regrows with no RegrowSeconds, no
// ReleasePoint) is rejected by Validate() without composing, and the error names the field.
class UMars_AutoTest_Forage_SpecValidateRejectsBadSpecs : UMars_AutoTestRig_Forage
{
    private const FVector k_Origin = FVector(-60000.0, 6000.0, -60000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddSource(InHandle, k_Origin);

        Add_Step("validate the good spec and each broken one", n"Step_Validate");
        Run_Steps(InHandle);
    }

    private FMars_Forage_Spec Make_ValidSpec() const
    {
        return Make_RockSpec(1, FMars_Forage_ExhaustionSpec(EMars_Forage_Exhaustion::Persists));
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Valid = Make_ValidSpec().Validate();
        Assert_True(Valid.IsValid(), f"the well-formed spec validates (got: {Valid.Get_Error()})");

        auto NoDefinition = Make_ValidSpec();
        NoDefinition.Yield.Definition = TSoftObjectPtr<UCk_InventoryItem_Definition>();
        AssertRejected(NoDefinition, "Yield.Definition", "an unset Definition");

        auto NoCharges = Make_ValidSpec();
        NoCharges.Yield.Charges = 0;
        AssertRejected(NoCharges, "Yield.Charges", "Charges 0");

        auto RegrowsNever = Make_ValidSpec();
        RegrowsNever.Exhaustion = FMars_Forage_ExhaustionSpec(EMars_Forage_Exhaustion::Regrows, 0.0f);
        AssertRejected(RegrowsNever, "Exhaustion.RegrowSeconds", "Regrows with RegrowSeconds 0");

        auto NoReleasePoint = Make_ValidSpec();
        NoReleasePoint.Parts = FMars_Forage_Parts();
        AssertRejected(NoReleasePoint, "Parts.ReleasePoint", "an invalid ReleasePoint");
    }

    private void AssertRejected(const FMars_Forage_Spec& InSpec, const FString& InField, const FString& InWhat)
    {
        const auto Validation = InSpec.Validate();
        Assert_False(Validation.IsValid(), f"Validate() rejects {InWhat}");
        Assert_True(Validation.Get_Error().Contains(InField), f"Validate() on {InWhat} names [{InField}] (got [{Validation.Get_Error()}])");
    }
}
