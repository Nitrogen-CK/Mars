// A backpack spec is accepted with 1 and constants_cargo_slot::k_MaxCount slots indexed 0..N-1, each with a prompt, and
// rejected, naming the rule, for no slots, one slot too many, an index outside 0..N-1, a repeated index, a zero, negative
// or NaN ProbeRadius, and a slot with no prompt input action. A slot's Backpack is not checked here: utils_backpack::Add
// fills it in.
class UMars_AutoTest_Backpack_SpecValidateRejectsBadCargoSlots : UCk_AutoTest_Base
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
        const auto One = Make_Spec(1).Validate();
        Assert_True(One.IsValid(), f"one slot is valid ({One.Get_Error()})");

        const auto Most = Make_Spec(constants_cargo_slot::k_MaxCount).Validate();
        Assert_True(Most.IsValid(), f"{constants_cargo_slot::k_MaxCount} slots are valid ({Most.Get_Error()})");

        AssertRejected(FMars_Backpack_Spec(), "cargo slots is outside", "no slots");
        AssertRejected(Make_Spec(constants_cargo_slot::k_MaxCount + 1), "cargo slots is outside", "one slot past the most");

        auto PastLast = Make_Spec(2);
        PastLast.CargoSlots[1].Index = 2;
        AssertRejected(PastLast, "has index", "an index past the last slot");

        auto Negative = Make_Spec(2);
        Negative.CargoSlots[0].Index = -1;
        AssertRejected(Negative, "has index", "a negative index");

        auto Repeated = Make_Spec(2);
        Repeated.CargoSlots[1].Index = 0;
        AssertRejected(Repeated, "repeats the index", "a repeated index");

        auto NoRadius = Make_Spec(2);
        NoRadius.CargoSlots[1].ProbeRadius = 0.0f;
        AssertRejected(NoRadius, "ProbeRadius", "a zero ProbeRadius");

        auto NegativeRadius = Make_Spec(2);
        NegativeRadius.CargoSlots[1].ProbeRadius = -1.0f;
        AssertRejected(NegativeRadius, "ProbeRadius", "a negative ProbeRadius");

        auto NaNRadius = Make_Spec(2);
        NaNRadius.CargoSlots[1].ProbeRadius = float32(Math::Sqrt(-1.0));
        AssertRejected(NaNRadius, "ProbeRadius", "a NaN ProbeRadius");

        auto NoPrompt = Make_Spec(2);
        NoPrompt.CargoSlots[1].Prompt = FMars_InteractPrompt_Spec();
        AssertRejected(NoPrompt, "prompt input action", "a slot with no prompt input action");
    }

    // InCount slots indexed 0..InCount-1, each with the cargo slot's prompt.
    private FMars_Backpack_Spec Make_Spec(int32 InCount) const
    {
        auto Spec = FMars_Backpack_Spec();
        for (int32 Index = 0; Index < InCount; ++Index)
        {
            auto Slot = FMars_CargoSlot_Spec();
            Slot.Index = Index;
            Slot.Prompt = utils_cargo_slot::Make_PromptSpec();
            Spec.CargoSlots.Add(Slot);
        }

        return Spec;
    }

    private void AssertRejected(const FMars_Backpack_Spec& InSpec, const FString& InRule, const FString& InWhat)
    {
        const auto Result = InSpec.Validate();
        Assert_False(Result.IsValid(), f"{InWhat} is rejected");
        Assert_True(Result.Get_Error().Contains(InRule), f"the rejection of {InWhat} names [{InRule}] (got [{Result.Get_Error()}])");
    }
}
