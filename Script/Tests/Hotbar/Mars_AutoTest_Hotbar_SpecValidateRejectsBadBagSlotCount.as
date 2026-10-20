// BagSlotCount is accepted from 1 to utils_hotbar::k_MaxBagSlotCount (the Inventory.Mars.Slot.N tags go no further) and
// rejected at 0 and one past the max, each rejection naming BagSlotCount.
class UMars_AutoTest_Hotbar_SpecValidateRejectsBadBagSlotCount : UCk_AutoTest_Base
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
        const auto Defaults = FMars_Hotbar_Spec().Validate();
        Assert_True(Defaults.IsValid(), f"the default spec is valid ({Defaults.Get_Error()})");

        AssertAccepted(1);
        AssertAccepted(utils_hotbar::k_MaxBagSlotCount);
        AssertRejected(0);
        AssertRejected(utils_hotbar::k_MaxBagSlotCount + 1);
    }

    private void AssertAccepted(int32 InBagSlotCount)
    {
        auto Spec = FMars_Hotbar_Spec();
        Spec.BagSlotCount = InBagSlotCount;
        const auto Result = Spec.Validate();
        Assert_True(Result.IsValid(), f"BagSlotCount [{InBagSlotCount}] is accepted ({Result.Get_Error()})");
    }

    private void AssertRejected(int32 InBagSlotCount)
    {
        auto Spec = FMars_Hotbar_Spec();
        Spec.BagSlotCount = InBagSlotCount;
        const auto Result = Spec.Validate();
        Assert_False(Result.IsValid(), f"BagSlotCount [{InBagSlotCount}] is rejected");
        Assert_True(Result.Get_Error().Contains("BagSlotCount"), f"the rejection of BagSlotCount [{InBagSlotCount}] names BagSlotCount (got [{Result.Get_Error()}])");
    }
}
