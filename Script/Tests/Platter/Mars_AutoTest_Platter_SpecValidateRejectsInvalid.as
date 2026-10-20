// The default platter spec and one whose MaxSeconds is just above its DwellSeconds are accepted. Rejected, each naming its
// rule: a Capacity of 0; a zero, negative or NaN inner half extent on either axis; a zero or NaN WallHeight or DropHeight;
// each settle tuner at zero and at NaN; and a MaxSeconds not above DwellSeconds.
class UMars_AutoTest_Platter_SpecValidateRejectsInvalid : UCk_AutoTest_Base
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
        const auto NaN = float32(Math::Sqrt(-1.0));
        Assert_True(Math::IsNaN(NaN), "the test input is NaN");

        const auto Defaults = FMars_Platter_Spec().Validate();
        Assert_True(Defaults.IsValid(), f"the default spec is valid ({Defaults.Get_Error()})");

        auto JustAbove = FMars_Platter_Spec();
        JustAbove.Settle.MaxSeconds = JustAbove.Settle.DwellSeconds + 0.01f;
        const auto JustAboveResult = JustAbove.Validate();
        Assert_True(JustAboveResult.IsValid(), f"a MaxSeconds just above DwellSeconds is valid ({JustAboveResult.Get_Error()})");

        auto NoRoom = FMars_Platter_Spec();
        NoRoom.Capacity = 0;
        AssertRejected(NoRoom, "Capacity", "a Capacity of 0");

        auto FlatX = FMars_Platter_Spec();
        FlatX.Bounds.InnerHalfExtents.X = 0.0;
        AssertRejected(FlatX, "InnerHalfExtents", "a zero InnerHalfExtents.X");

        auto NegativeY = FMars_Platter_Spec();
        NegativeY.Bounds.InnerHalfExtents.Y = -1.0;
        AssertRejected(NegativeY, "InnerHalfExtents", "a negative InnerHalfExtents.Y");

        auto NaNX = FMars_Platter_Spec();
        NaNX.Bounds.InnerHalfExtents.X = Math::Sqrt(-1.0);
        AssertRejected(NaNX, "InnerHalfExtents", "a NaN InnerHalfExtents.X");

        auto NaNY = FMars_Platter_Spec();
        NaNY.Bounds.InnerHalfExtents.Y = Math::Sqrt(-1.0);
        AssertRejected(NaNY, "InnerHalfExtents", "a NaN InnerHalfExtents.Y");

        auto NoWall = FMars_Platter_Spec();
        NoWall.Bounds.WallHeight = 0.0f;
        AssertRejected(NoWall, "WallHeight", "a zero WallHeight");

        auto NaNWall = FMars_Platter_Spec();
        NaNWall.Bounds.WallHeight = NaN;
        AssertRejected(NaNWall, "WallHeight", "a NaN WallHeight");

        auto NoDrop = FMars_Platter_Spec();
        NoDrop.Bounds.DropHeight = 0.0f;
        AssertRejected(NoDrop, "DropHeight", "a zero DropHeight");

        auto NaNDrop = FMars_Platter_Spec();
        NaNDrop.Bounds.DropHeight = NaN;
        AssertRejected(NaNDrop, "DropHeight", "a NaN DropHeight");

        auto Tuners = FMars_Platter_SettleTuners();
        Tuners.DropCadenceSeconds = 0.0f;
        AssertTunerRejected(Tuners, "a zero DropCadenceSeconds");
        Tuners = FMars_Platter_SettleTuners();
        Tuners.DropCadenceSeconds = NaN;
        AssertTunerRejected(Tuners, "a NaN DropCadenceSeconds");

        Tuners = FMars_Platter_SettleTuners();
        Tuners.SampleSeconds = 0.0f;
        AssertTunerRejected(Tuners, "a zero SampleSeconds");
        Tuners = FMars_Platter_SettleTuners();
        Tuners.SampleSeconds = NaN;
        AssertTunerRejected(Tuners, "a NaN SampleSeconds");

        Tuners = FMars_Platter_SettleTuners();
        Tuners.DriftCm = 0.0f;
        AssertTunerRejected(Tuners, "a zero DriftCm");
        Tuners = FMars_Platter_SettleTuners();
        Tuners.DriftCm = NaN;
        AssertTunerRejected(Tuners, "a NaN DriftCm");

        Tuners = FMars_Platter_SettleTuners();
        Tuners.DwellSeconds = 0.0f;
        AssertTunerRejected(Tuners, "a zero DwellSeconds");
        Tuners = FMars_Platter_SettleTuners();
        Tuners.DwellSeconds = NaN;
        AssertTunerRejected(Tuners, "a NaN DwellSeconds");

        Tuners = FMars_Platter_SettleTuners();
        Tuners.MaxSeconds = 0.0f;
        AssertTunerRejected(Tuners, "a zero MaxSeconds");
        Tuners = FMars_Platter_SettleTuners();
        Tuners.MaxSeconds = NaN;
        AssertTunerRejected(Tuners, "a NaN MaxSeconds");

        auto EqualTimeout = FMars_Platter_Spec();
        EqualTimeout.Settle.MaxSeconds = EqualTimeout.Settle.DwellSeconds;
        AssertRejected(EqualTimeout, "MaxSeconds", "a MaxSeconds equal to DwellSeconds");

        auto ShortTimeout = FMars_Platter_Spec();
        ShortTimeout.Settle.MaxSeconds = ShortTimeout.Settle.DwellSeconds * 0.5f;
        AssertRejected(ShortTimeout, "MaxSeconds", "a MaxSeconds below DwellSeconds");
    }

    // The default spec with InTuners as its settle tuners is rejected as a settle tuner.
    private void AssertTunerRejected(const FMars_Platter_SettleTuners& InTuners, const FString& InWhat)
    {
        auto Spec = FMars_Platter_Spec();
        Spec.Settle = InTuners;
        AssertRejected(Spec, "settle tuner", InWhat);
    }

    private void AssertRejected(const FMars_Platter_Spec& InSpec, const FString& InRule, const FString& InWhat)
    {
        const auto Result = InSpec.Validate();
        Assert_False(Result.IsValid(), f"{InWhat} is rejected");
        Assert_True(Result.Get_Error().Contains(InRule), f"the rejection of {InWhat} names [{InRule}] (got [{Result.Get_Error()}])");
    }
}

