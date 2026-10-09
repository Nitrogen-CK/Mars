// Validate() accepts a spec with a mass and the default tuners and cap, and rejects, each naming its rule: no mass, a
// negative or non-finite mass, a parent without a lineage, a non-positive portion mass, a non-positive or oversized portion
// thickness, a negative cap material slot and a zero cap UV scale.
class UMars_AutoTest_FoodPiece_SpecValidateRejectsInvalid : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("validate good and bad specs", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Good = Make_Good().Validate();
        Assert_True(Good.IsValid(), f"a spec with a mass is accepted (error: {Good.Get_Error()})");

        auto Derived = Make_Good();
        Derived.Data.Lineage = FGuid::NewGuid();
        Derived.Data.ParentId = FGuid::NewGuid();
        const auto DerivedResult = Derived.Validate();
        Assert_True(DerivedResult.IsValid(), f"a derived piece with a lineage is accepted (error: {DerivedResult.Get_Error()})");

        AssertRejected(FMars_FoodPiece_Spec(), "the default spec (no mass)");

        auto Negative = Make_Good();
        Negative.Data.MassKg = -1.0;
        AssertRejected(Negative, "a negative mass");

        auto NotFinite = Make_Good();
        NotFinite.Data.MassKg = Math::Sqrt(-1.0);
        AssertRejected(NotFinite, "a non-finite mass");

        auto Orphan = Make_Good();
        Orphan.Data.ParentId = FGuid::NewGuid();
        AssertRejected(Orphan, "a parent without a lineage");

        auto ZeroPortion = Make_Good();
        ZeroPortion.Tuners.MinPortionMassKg = 0.0;
        AssertRejected(ZeroPortion, "a zero portion mass");

        auto NegativePortion = Make_Good();
        NegativePortion.Tuners.MinPortionMassKg = -0.1;
        AssertRejected(NegativePortion, "a negative portion mass");

        auto NegativeThickness = Make_Good();
        NegativeThickness.Tuners.MinPortionThicknessCm = -1.0;
        AssertRejected(NegativeThickness, "a negative portion thickness");

        auto HugeThickness = Make_Good();
        HugeThickness.Tuners.MinPortionThicknessCm = 20000.0;
        AssertRejected(HugeThickness, "a portion thickness beyond RuntimeMesh's ceiling");

        auto NegativeSlot = Make_Good();
        NegativeSlot.Cap.Set_MaterialID(-1);
        AssertRejected(NegativeSlot, "a negative cap material slot");

        auto ZeroUVScale = Make_Good();
        ZeroUVScale.Cap.Set_CmPerUVUnit(0.0);
        AssertRejected(ZeroUVScale, "a zero cap UV scale");
    }

    private FMars_FoodPiece_Spec Make_Good() const
    {
        auto Spec = FMars_FoodPiece_Spec();
        Spec.Data.MassKg = 0.8;
        return Spec;
    }

    private void AssertRejected(const FMars_FoodPiece_Spec& InSpec, const FString& InWhat)
    {
        const auto Result = InSpec.Validate();
        Assert_False(Result.IsValid(), f"{InWhat} is rejected");
        Assert_True(Result.Get_Error().Len() > 0, f"the rejection of {InWhat} names its rule (error: {Result.Get_Error()})");
    }
}
