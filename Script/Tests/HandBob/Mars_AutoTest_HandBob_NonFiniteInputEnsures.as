// Non-finite locomotion input is a bug upstream, not something to bob with: Advance ensures and puts the bob back at
// rest with every value finite, instead of letting the NaN reach the node offset. Kernel level (utils_hand_bob::Advance).
class UMars_AutoTest_HandBob_NonFiniteInputEnsures : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("a NaN vertical speed ensures and leaves the bob at rest", n"Step_AdvanceWithNaN");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AdvanceWithNaN(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Spec = FMars_HandBob_Spec();
        auto State = FMars_Fragment_HandBob();

        auto Walking = FMars_HandBob_Input();
        Walking.DeltaSeconds = 1.0f / 60.0f;
        Walking.GroundSpeed = Spec.ReferenceSpeed;
        for (int32 Frame = 0; Frame < 30; ++Frame)
        { utils_hand_bob::Advance(Spec, State, Walking); }
        Assert_True(State.Amount > 0.0f, "walking builds up the stride first");

        auto Broken = Walking;
        Broken.VerticalSpeed = float32(Math::Sqrt(-1.0));
        Assert_True(Math::IsNaN(Broken.VerticalSpeed), "the test input is NaN");
        utils_hand_bob::Advance(Spec, State, Broken);

        const auto Offset = utils_hand_bob::Make_NodeOffset(Spec, State);
        Assert_Equals_Float(State.Amount, 0.0, 0.0001, "the bob is back at rest");
        Assert_True(Math::IsFinite(State.SpringOffset) && Math::IsFinite(State.SpringVelocity) && Math::IsFinite(State.LastVerticalSpeed),
            "every bob value is finite");
        const auto Location = Offset.GetLocation();
        Assert_True(Math::IsFinite(Location.X) && Math::IsFinite(Location.Y) && Math::IsFinite(Location.Z), "the node offset stays finite");
    }
}

// Hand-authored so the deliberate non-finite-input ensure is an expected error rather than a failure.
class AMars_AutoTest_HandBob_NonFiniteInputEnsures_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_HandBob_NonFiniteInputEnsures;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("[HandBob] Non-finite locomotion input");
        return Out;
    }
}
