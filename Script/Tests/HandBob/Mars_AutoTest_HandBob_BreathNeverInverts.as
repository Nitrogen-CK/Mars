// Breathing fades out as the stride fades in and stays off at a sprint: with Amount past 1 (up to MaxAmountScale) the
// breath term is 0, never a negative (inverted) breath. Pure kernel (utils_hand_bob::Make_NodeOffset).
class UMars_AutoTest_HandBob_BreathNeverInverts : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("breath is full at rest and off at a sprint", n"Step_AssertBreath");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertBreath(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Spec = FMars_HandBob_Spec();

        // Phase 0 silences the stride terms; a quarter period is the top of the breath.
        auto State = FMars_Fragment_HandBob();
        State.BreathTime = Spec.BreathPeriodSeconds * 0.25f;

        State.Amount = 0.0f;
        Assert_Equals_Float(utils_hand_bob::Make_NodeOffset(Spec, State).GetLocation().Z, Spec.BreathCm, 0.0001,
            "at rest the hands rise by a full breath");

        State.Amount = 1.0f;
        Assert_Equals_Float(utils_hand_bob::Make_NodeOffset(Spec, State).GetLocation().Z, 0.0, 0.0001,
            "at full stride there is no breath");

        State.Amount = Spec.MaxAmountScale;
        Assert_Equals_Float(utils_hand_bob::Make_NodeOffset(Spec, State).GetLocation().Z, 0.0, 0.0001,
            "at a sprint past full stride the breath stays off instead of inverting");
    }
}
