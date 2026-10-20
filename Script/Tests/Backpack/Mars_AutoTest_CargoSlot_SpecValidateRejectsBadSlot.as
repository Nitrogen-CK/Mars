// A cargo slot spec with an Index in [0, constants_cargo_slot::k_MaxCount), a ProbeRadius, the cargo prompt and a Backpack
// is accepted at both index bounds, and rejected, naming the rule, for an Index of -1 or k_MaxCount, a zero, negative or NaN
// ProbeRadius, no prompt input action, and no Backpack. The Backpack is a bare Visual-mode world item (no holder, body or
// probe): Validate reads only that the handle is a world item. Isolated Z band: -56700.
class UMars_AutoTest_CargoSlot_SpecValidateRejectsBadSlot : UCk_AutoTest_Base
{
    private FCk_Handle_WorldItem _Backpack;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto PackEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(PackEntity, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -56700.0)), ECk_Replication::DoesNotReplicate);

        auto PackSpec = FMars_WorldItem_Spec();
        PackSpec.Mode = EMars_WorldItem_Mode::Visual;
        PackSpec.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Backpack());
        _Backpack = utils_world_item::Add(PackEntity, PackSpec);

        Add_Step("validate the spec rules", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Backpack), "the test's backpack world item was composed");

        const auto First = Make_Spec(0).Validate();
        Assert_True(First.IsValid(), f"Index 0 is valid ({First.Get_Error()})");

        const auto LastIndex = constants_cargo_slot::k_MaxCount - 1;
        const auto Last = Make_Spec(LastIndex).Validate();
        Assert_True(Last.IsValid(), f"Index {LastIndex} is valid ({Last.Get_Error()})");

        AssertRejected(Make_Spec(-1), "Index", "Index -1");
        AssertRejected(Make_Spec(constants_cargo_slot::k_MaxCount), "Index", f"Index {constants_cargo_slot::k_MaxCount}");

        auto NoRadius = Make_Spec(0);
        NoRadius.ProbeRadius = 0.0f;
        AssertRejected(NoRadius, "ProbeRadius", "a zero ProbeRadius");

        auto NegativeRadius = Make_Spec(0);
        NegativeRadius.ProbeRadius = -1.0f;
        AssertRejected(NegativeRadius, "ProbeRadius", "a negative ProbeRadius");

        auto NaNRadius = Make_Spec(0);
        NaNRadius.ProbeRadius = float32(Math::Sqrt(-1.0));
        AssertRejected(NaNRadius, "ProbeRadius", "a NaN ProbeRadius");

        auto NoPrompt = Make_Spec(0);
        NoPrompt.Prompt = FMars_InteractPrompt_Spec();
        AssertRejected(NoPrompt, "prompt input action", "no prompt input action");

        auto NoBackpack = Make_Spec(0);
        NoBackpack.Backpack = FCk_Handle_WorldItem();
        AssertRejected(NoBackpack, "Backpack", "no Backpack");
    }

    private FMars_CargoSlot_Spec Make_Spec(int32 InIndex) const
    {
        auto Spec = FMars_CargoSlot_Spec();
        Spec.Index = InIndex;
        Spec.Prompt = utils_cargo_slot::Make_PromptSpec();
        Spec.Backpack = _Backpack;
        return Spec;
    }

    private void AssertRejected(const FMars_CargoSlot_Spec& InSpec, const FString& InRule, const FString& InWhat)
    {
        const auto Result = InSpec.Validate();
        Assert_False(Result.IsValid(), f"{InWhat} is rejected");
        Assert_True(Result.Get_Error().Contains(InRule), f"the rejection of {InWhat} names [{InRule}] (got [{Result.Get_Error()}])");
    }
}
