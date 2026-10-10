// Validate() accepts the default cutting spec and rejects a board with no width, a look that moves nothing and a strike that
// takes no time.
class UMars_AutoTest_Cutting_SpecValidateRejectsANonPositiveBoard : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("validate the default spec and three broken ones", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Default = FMars_Cutting_Spec().Validate();
        Assert_True(Default.IsValid(), f"the default spec is accepted (error: {Default.Get_Error()})");

        auto NoBoard = FMars_Cutting_Spec();
        NoBoard.BoardHalfWidth = 0.0f;
        const auto NoBoardResult = NoBoard.Validate();
        Assert_False(NoBoardResult.IsValid(), "a zero BoardHalfWidth is rejected");
        Assert_True(NoBoardResult.Get_Error().Len() > 0, f"the rejection names its rule (error: {NoBoardResult.Get_Error()})");

        auto NoSteer = FMars_Cutting_Spec();
        NoSteer.LateralPerDegree = -1.0f;
        Assert_False(NoSteer.Validate().IsValid(), "a negative LateralPerDegree is rejected");

        auto NoStrike = FMars_Cutting_Spec();
        NoStrike.ChopDownSeconds = 0.0f;
        Assert_False(NoStrike.Validate().IsValid(), "a zero ChopDownSeconds is rejected");
    }
}
