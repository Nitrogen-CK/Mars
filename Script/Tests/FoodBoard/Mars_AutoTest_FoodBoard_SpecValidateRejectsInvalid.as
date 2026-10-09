// Validate() accepts the default spec and the boundary values (one held piece, one and four cuts a chop, no parting, a ring
// of one, restitution 1), and rejects, each naming its rule: no held piece, zero or five cuts a chop, a negative or
// non-finite parting, a ring of zero, no collision profile, a negative or non-finite friction, a restitution outside [0, 1]
// and a non-finite release velocity.
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
        Edges.Tuners.MaxReleasedPieces = 1;
        Edges.Tuners.Release.Restitution = 1.0f;
        const auto EdgesResult = Edges.Validate();
        Assert_True(EdgesResult.IsValid(), f"the lower boundary values are accepted (error: {EdgesResult.Get_Error()})");

        auto FourCuts = FMars_FoodBoard_Spec();
        FourCuts.Tuners.MaxCutsPerChop = 4;
        const auto FourCutsResult = FourCuts.Validate();
        Assert_True(FourCutsResult.IsValid(), f"four cuts a chop are accepted (error: {FourCutsResult.Get_Error()})");

        auto NoHeld = FMars_FoodBoard_Spec();
        NoHeld.Tuners.MaxHeldPieces = 0;
        AssertRejected(NoHeld, "a board that holds nothing");

        auto NoCuts = FMars_FoodBoard_Spec();
        NoCuts.Tuners.MaxCutsPerChop = 0;
        AssertRejected(NoCuts, "zero cuts a chop");

        auto FiveCuts = FMars_FoodBoard_Spec();
        FiveCuts.Tuners.MaxCutsPerChop = 5;
        AssertRejected(FiveCuts, "five cuts a chop");

        auto NegativeParting = FMars_FoodBoard_Spec();
        NegativeParting.Tuners.SeparationCm = -0.1f;
        AssertRejected(NegativeParting, "a negative parting");

        auto NaNParting = FMars_FoodBoard_Spec();
        NaNParting.Tuners.SeparationCm = float32(Math::Sqrt(-1.0));
        AssertRejected(NaNParting, "a non-finite parting");

        auto NoRing = FMars_FoodBoard_Spec();
        NoRing.Tuners.MaxReleasedPieces = 0;
        AssertRejected(NoRing, "a release ring of zero");

        auto NoProfile = FMars_FoodBoard_Spec();
        NoProfile.Tuners.Release.CollisionProfileName = NAME_None;
        AssertRejected(NoProfile, "no collision profile");

        auto NegativeFriction = FMars_FoodBoard_Spec();
        NegativeFriction.Tuners.Release.Friction = -0.2f;
        AssertRejected(NegativeFriction, "a negative friction");

        auto NaNFriction = FMars_FoodBoard_Spec();
        NaNFriction.Tuners.Release.Friction = float32(Math::Sqrt(-1.0));
        AssertRejected(NaNFriction, "a non-finite friction");

        auto NegativeRestitution = FMars_FoodBoard_Spec();
        NegativeRestitution.Tuners.Release.Restitution = -0.1f;
        AssertRejected(NegativeRestitution, "a negative restitution");

        auto BouncyRestitution = FMars_FoodBoard_Spec();
        BouncyRestitution.Tuners.Release.Restitution = 1.5f;
        AssertRejected(BouncyRestitution, "a restitution above 1");

        auto NaNVelocity = FMars_FoodBoard_Spec();
        NaNVelocity.Tuners.Release.VelocityLocal = FVector(0.0, Math::Sqrt(-1.0), 0.0);
        AssertRejected(NaNVelocity, "a non-finite release velocity");
    }

    private void AssertRejected(const FMars_FoodBoard_Spec& InSpec, const FString& InWhat)
    {
        const auto Result = InSpec.Validate();
        Assert_False(Result.IsValid(), f"{InWhat} is rejected");
        Assert_True(Result.Get_Error().Len() > 0, f"the rejection of {InWhat} names its rule (error: {Result.Get_Error()})");
    }
}
