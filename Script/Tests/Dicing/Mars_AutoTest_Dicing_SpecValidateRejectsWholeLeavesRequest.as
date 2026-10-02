// Validate() accepts the default dicing spec and rejects a RequestedState of WholeLeaves: the pile starts there, so the
// requested texture must take at least one chop.
class UMars_AutoTest_Dicing_SpecValidateRejectsWholeLeavesRequest : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("validate the default spec and a whole-leaves request", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Default = FMars_Dicing_Spec().Validate();
        Assert_True(Default.IsValid, f"the default spec is accepted (error: {Default.Get_Error()})");

        auto WholeLeaves = FMars_Dicing_Spec();
        WholeLeaves.RequestedState = EMars_Dicing_State::WholeLeaves;
        const auto Rejected = WholeLeaves.Validate();
        Assert_False(Rejected.IsValid, "RequestedState WholeLeaves is rejected");
        Assert_True(Rejected.Get_Error().Len() > 0, f"the rejection names its rule (error: {Rejected.Get_Error()})");

        auto CoarseChop = FMars_Dicing_Spec();
        CoarseChop.RequestedState = EMars_Dicing_State::CoarseChop;
        const auto OneChop = CoarseChop.Validate();
        Assert_True(OneChop.IsValid, f"RequestedState CoarseChop is accepted (error: {OneChop.Get_Error()})");
    }
}
