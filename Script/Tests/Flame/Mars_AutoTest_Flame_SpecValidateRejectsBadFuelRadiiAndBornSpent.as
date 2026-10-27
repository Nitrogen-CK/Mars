// Measured fuel needs at least one measure of positive length, a gutter no longer than a measure and a start inside its
// measures; every flame needs positive Held and World radii, and a positive Stowed radius when it stays lit stowed; fuel
// that cannot be refuelled may not start empty. Unlimited fuel accepts any Stowed radius when the flame snuffs stowed.
class UMars_AutoTest_Flame_SpecValidateRejectsBadFuelRadiiAndBornSpent : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("validate the spec rules", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Defaults = FMars_Flame_Spec().Validate();
        Assert_True(Defaults.IsValid(), f"the defaults (unlimited fuel) are valid ({Defaults.Get_Error()})");

        const auto Measured = Make_Measured(FMars_Flame_Fuel()).Validate();
        Assert_True(Measured.IsValid(), f"the default fuel is valid ({Measured.Get_Error()})");

        auto NoMeasures = FMars_Flame_Fuel();
        NoMeasures.Measures = 0;
        AssertRejected(Make_Measured(NoMeasures), "zero measures", "Measures [");

        auto Timeless = FMars_Flame_Fuel();
        Timeless.SecondsPerMeasure = 0.0f;
        AssertRejected(Make_Measured(Timeless), "a zero-length measure", "SecondsPerMeasure [");

        auto LongGutter = FMars_Flame_Fuel();
        LongGutter.GutterSeconds = LongGutter.SecondsPerMeasure + 1.0f;
        AssertRejected(Make_Measured(LongGutter), "a gutter longer than a measure", "GutterSeconds [");

        auto Overfull = FMars_Flame_Fuel();
        Overfull.StartMeasures = TOptional<int32>(Overfull.Measures + 1);
        AssertRejected(Make_Measured(Overfull), "starting with more than Measures", "StartMeasures [");

        auto Empty = FMars_Flame_Fuel();
        Empty.StartMeasures = TOptional<int32>(0);
        Assert_True(Make_Measured(Empty).Validate().IsValid(), "refuelable fuel starting empty is valid");

        auto Unlit = Make_Measured(FMars_Flame_Fuel());
        Unlit.Radius.World = 0.0f;
        AssertRejected(Unlit, "a zero radius", "every Radius");

        auto NoBeltPool = FMars_Flame_Spec();
        NoBeltPool.OnStow = EMars_Flame_OnStow::StaysLit;
        NoBeltPool.Radius.Stowed = 0.0f;
        AssertRejected(NoBeltPool, "a flame that stays lit stowed with no Stowed radius", "Radius.Stowed [");

        auto BornSpent = FMars_Flame_Fuel();
        BornSpent.Refuel = EMars_Flame_Refuel::NotRefuelable;
        BornSpent.StartMeasures = TOptional<int32>(0);
        AssertRejected(Make_Measured(BornSpent), "unrefuelable fuel starting empty", "Refuel [NotRefuelable]");

        auto Unlimited = FMars_Flame_Spec();
        Unlimited.OnStow = EMars_Flame_OnStow::Snuffs;
        Unlimited.Radius.Stowed = 0.0f;
        Unlimited.Lighting = EMars_Flame_Lighting::NeedsAFlame;
        Unlimited.StartIgnition = EMars_Flame_Ignition::Lit;
        const auto UnlimitedValidation = Unlimited.Validate();
        Assert_True(UnlimitedValidation.IsValid(), f"unlimited fuel with no Stowed radius on a flame that snuffs stowed, started lit, is valid ({UnlimitedValidation.Get_Error()})");
    }

    private FMars_Flame_Spec Make_Measured(FMars_Flame_Fuel InFuel) const
    {
        auto Spec = FMars_Flame_Spec();
        Spec.Fuel = TOptional<FMars_Flame_Fuel>(InFuel);
        return Spec;
    }

    // InRule opens the error: the field whose rule broke.
    private void AssertRejected(const FMars_Flame_Spec& InSpec, const FString& InCase, const FString& InRule)
    {
        const auto Validation = InSpec.Validate();
        Assert_False(Validation.IsValid(), f"{InCase} is rejected");
        Assert_True(Validation.Get_Error().StartsWith(InRule), f"{InCase} names its rule, [{InRule}...] (error: {Validation.Get_Error()})");
    }
}
