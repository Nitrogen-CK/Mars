// Validate() accepts the rig's spec, the default and a one-slot bowl with no ring, and rejects one bad field at a time, each
// rejection naming the field: a bowl with no room, a negative ring, a non-finite rest height, a dip that does not sink, a
// coat that never grows, a negative dip time.
class UMars_AutoTest_Batter_SpecValidateRejectsBadSpecs : UMars_AutoTestRig_Batter
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("validate the rig's spec, the default, a one-slot bowl and every bad field", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Good = Make_TestSpec().Validate();
        Assert_True(Good.IsValid(), f"the rig's spec is accepted (error: {Good.Get_Error()})");

        const auto DefaultSpec = FMars_Batter_Spec();
        const auto Default = DefaultSpec.Validate();
        Assert_True(Default.IsValid(), f"the default spec is accepted (error: {Default.Get_Error()})");

        auto OneSlot = Make_TestSpec();
        OneSlot.Bowl.Capacity = 1;
        OneSlot.Bowl.SlotRadius = 0.0f;
        const auto Single = OneSlot.Validate();
        Assert_True(Single.IsValid(), f"a one-slot bowl with no ring is accepted (error: {Single.Get_Error()})");

        auto NoRoom = Make_TestSpec();
        NoRoom.Bowl.Capacity = 0;
        AssertRejected(NoRoom, "Bowl.Capacity");

        auto NegativeRing = Make_TestSpec();
        NegativeRing.Bowl.SlotRadius = -1.0f;
        AssertRejected(NegativeRing, "Bowl.SlotRadius");

        auto NotFinite = Make_TestSpec();
        NotFinite.Bowl.RestZ = float32(Math::Sqrt(-1.0));
        AssertRejected(NotFinite, "Bowl.RestZ");

        auto NoSink = Make_TestSpec();
        NoSink.Bowl.DipDepthCm = 0.0f;
        AssertRejected(NoSink, "Bowl.DipDepthCm");

        auto NeverCoats = Make_TestSpec();
        NeverCoats.Coat.CoatSeconds = 0.0f;
        AssertRejected(NeverCoats, "Coat.CoatSeconds");

        auto NegativeDip = Make_TestSpec();
        NegativeDip.Coat.DipSeconds = -0.1f;
        AssertRejected(NegativeDip, "Coat.DipSeconds");
    }

    private void AssertRejected(const FMars_Batter_Spec& InSpec, const FString& InField)
    {
        const auto Validation = InSpec.Validate();
        Assert_False(Validation.IsValid(), f"a bad {InField} is rejected");
        Assert_True(Validation.Get_Error().Contains(InField), f"the rejection names {InField} (got {Validation.Get_Error()})");
    }
}
