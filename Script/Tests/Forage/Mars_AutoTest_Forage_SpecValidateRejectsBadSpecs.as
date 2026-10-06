// A well-formed Forage spec validates; each broken rule (no Definition, Charges 0, Regrows with no RegrowSeconds, no
// ReleasePoint) is rejected by Validate() without composing.
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
        Assert_False(NoDefinition.Validate().IsValid(), "an unset Definition is rejected");

        auto NoCharges = Make_ValidSpec();
        NoCharges.Yield.Charges = 0;
        Assert_False(NoCharges.Validate().IsValid(), "Charges 0 is rejected");

        auto RegrowsNever = Make_ValidSpec();
        RegrowsNever.Exhaustion = FMars_Forage_ExhaustionSpec(EMars_Forage_Exhaustion::Regrows, 0.0f);
        Assert_False(RegrowsNever.Validate().IsValid(), "Regrows with RegrowSeconds 0 is rejected");

        auto NoReleasePoint = Make_ValidSpec();
        NoReleasePoint.Parts = FMars_Forage_Parts();
        Assert_False(NoReleasePoint.Validate().IsValid(), "an invalid ReleasePoint is rejected");
    }
}
