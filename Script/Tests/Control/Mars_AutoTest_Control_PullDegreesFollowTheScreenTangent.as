// The look delta counts toward a pull only along the pull axis' on-screen direction, from any side of the control; an
// axis that projects to nothing on screen falls back to raw pitch (mouse down pulls).
class UMars_AutoTest_Control_PullDegreesFollowTheScreenTangent : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("project look deltas onto pull axes", n"Step_Project");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Project(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto View = FTransform::Identity;

        Assert_Equals_Float(utils_control::Get_PullDegrees(FVector(0.0, 0.0, -1.0), View, FVector(0.0, 10.0, 0.0)), 10.0, 0.001,
            "pull down, mouse down");
        Assert_Equals_Float(utils_control::Get_PullDegrees(FVector(0.0, 0.0, -1.0), View, FVector(10.0, 0.0, 0.0)), 0.0, 0.001,
            "pull down, mouse right does nothing");
        Assert_Equals_Float(utils_control::Get_PullDegrees(FVector(0.0, 1.0, 0.0), View, FVector(10.0, 0.0, 0.0)), 10.0, 0.001,
            "pull right, mouse right");
        Assert_Equals_Float(utils_control::Get_PullDegrees(FVector(0.0, -1.0, 0.0), View, FVector(10.0, 0.0, 0.0)), -10.0, 0.001,
            "pull left, mouse right pushes back");
        Assert_Equals_Float(utils_control::Get_PullDegrees(FVector(1.0, 0.0, 0.0), View, FVector(3.0, 7.0, 0.0)), 7.0, 0.001,
            "a pull toward the viewer is degenerate on screen: raw pitch");
        Assert_Equals_Float(utils_control::Get_PullDegrees(FVector::ZeroVector, View, FVector(3.0, 7.0, 0.0)), 7.0, 0.001,
            "no pull axis: raw pitch");

        const auto YawedView = FTransform(FRotator(0.0, 90.0, 0.0));
        Assert_Equals_Float(utils_control::Get_PullDegrees(FVector(-1.0, 0.0, 0.0), YawedView, FVector(10.0, 0.0, 0.0)), 10.0, 0.001,
            "from a view yawed 90 degrees the lever's -X is screen-right");
    }
}
