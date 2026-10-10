// Validate() accepts the default spec and the boundary values (one held piece, one and k_MaxCutsPerChop cuts a chop, no
// parting), and rejects, each naming its rule: no held piece, zero or one past k_MaxCutsPerChop cuts a chop, and a negative
// or non-finite parting.
class UMars_AutoTest_FoodBoard_SpecValidateRejectsInvalid : UCk_AutoTest_Base
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
        const auto Good = FMars_FoodBoard_Spec().Validate();
        Assert_True(Good.IsValid(), f"the default spec is accepted (error: {Good.Get_Error()})");

        auto Edges = FMars_FoodBoard_Spec();
        Edges.Tuners.MaxHeldPieces = 1;
        Edges.Tuners.MaxCutsPerChop = 1;
        Edges.Tuners.SeparationCm = 0.0f;
        const auto EdgesResult = Edges.Validate();
        Assert_True(EdgesResult.IsValid(), f"the lower boundary values are accepted (error: {EdgesResult.Get_Error()})");

        auto MostCuts = FMars_FoodBoard_Spec();
        MostCuts.Tuners.MaxCutsPerChop = utils_foodboard::k_MaxCutsPerChop;
        const auto MostCutsResult = MostCuts.Validate();
        Assert_True(MostCutsResult.IsValid(), f"{utils_foodboard::k_MaxCutsPerChop} cuts a chop are accepted (error: {MostCutsResult.Get_Error()})");

        auto NoHeld = FMars_FoodBoard_Spec();
        NoHeld.Tuners.MaxHeldPieces = 0;
        AssertRejected(NoHeld, "a board that holds nothing");

        auto NoCuts = FMars_FoodBoard_Spec();
        NoCuts.Tuners.MaxCutsPerChop = 0;
        AssertRejected(NoCuts, "zero cuts a chop");

        auto TooManyCuts = FMars_FoodBoard_Spec();
        TooManyCuts.Tuners.MaxCutsPerChop = utils_foodboard::k_MaxCutsPerChop + 1;
        AssertRejected(TooManyCuts, "one cut a chop past the most");

        auto NegativeParting = FMars_FoodBoard_Spec();
        NegativeParting.Tuners.SeparationCm = -0.1f;
        AssertRejected(NegativeParting, "a negative parting");

        auto NaNParting = FMars_FoodBoard_Spec();
        NaNParting.Tuners.SeparationCm = float32(Math::Sqrt(-1.0));
        AssertRejected(NaNParting, "a non-finite parting");
    }

    private void AssertRejected(const FMars_FoodBoard_Spec& InSpec, const FString& InWhat)
    {
        const auto Result = InSpec.Validate();
        Assert_False(Result.IsValid(), f"{InWhat} is rejected");
        Assert_True(Result.Get_Error().Len() > 0, f"the rejection of {InWhat} names its rule (error: {Result.Get_Error()})");
    }
}
