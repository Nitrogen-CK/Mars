// Validate() accepts the default searing spec and rejects a pan that takes no piece, a pan disc no wider than a piece and a
// face that never sears;
// the pan's own spec (its Implement) accepts its default and rejects a tilt past 80 degrees, a tilt that cannot move and a
// lift spring with no stiffness; the pan body spec accepts the pan mesh at scale 1 and rejects no mesh, a zero scale and a
// restitution past 1.
class UMars_AutoTest_Searing_SpecValidateRejectsBadPans : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("validate the default specs and nine bad ones", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Default = FMars_Searing_Spec().Validate();
        Assert_True(Default.IsValid(), f"the default spec is accepted (error: {Default.Get_Error()})");

        const auto DefaultPan = FMars_Implement_Spec().Validate();
        Assert_True(DefaultPan.IsValid(), f"the default pan spec is accepted (error: {DefaultPan.Get_Error()})");

        auto NoRoom = FMars_Searing_Spec();
        NoRoom.Supply.MaxPieces = 0;
        AssertRejected(NoRoom.Validate(), "MaxPieces <= 0");

        auto NarrowPan = FMars_Searing_Spec();
        NarrowPan.Loss.PanRadius = NarrowPan.Steak.HalfSize;
        AssertRejected(NarrowPan.Validate(), "PanRadius <= HalfSize");

        auto NeverSears = FMars_Searing_Spec();
        NeverSears.Cook.SecondsPerFace = 0.0f;
        AssertRejected(NeverSears.Validate(), "SecondsPerFace <= 0");

        auto Steep = FMars_Implement_Spec();
        Steep.Tilt.MaxTiltDegrees = 81.0f;
        AssertRejected(Steep.Validate(), "MaxTiltDegrees > 80");

        auto Frozen = FMars_Implement_Spec();
        Frozen.Tilt.MaxTiltRateDegreesPerSecond = 0.0f;
        AssertRejected(Frozen.Validate(), "MaxTiltRateDegreesPerSecond <= 0");

        auto Slack = FMars_Implement_Spec();
        Slack.Lift.SpringHz = 0.0f;
        AssertRejected(Slack.Validate(), "SpringHz <= 0");

        const auto PanMesh = assets::FryPan_Mars_SM();
        const auto PanBody = FMars_Searing_PanBodySpec(PanMesh, 1.0f).Validate();
        Assert_True(PanBody.IsValid(), f"the pan mesh at scale 1 is accepted (error: {PanBody.Get_Error()})");

        AssertRejected(FMars_Searing_PanBodySpec().Validate(), "no pan Mesh");
        AssertRejected(FMars_Searing_PanBodySpec(PanMesh, 0.0f).Validate(), "pan body Scale <= 0");

        auto Bouncy = FMars_Searing_PanBodySpec(PanMesh, 1.0f);
        Bouncy.Restitution = 1.5f;
        AssertRejected(Bouncy.Validate(), "pan body Restitution > 1");
    }

    private void AssertRejected(const FMars_Validation& InValidation, const FString& InRule)
    {
        Assert_False(InValidation.IsValid(), f"{InRule} is rejected");
        Assert_True(InValidation.Get_Error().Len() > 0, f"the {InRule} rejection names its rule (error: {InValidation.Get_Error()})");
    }
}
