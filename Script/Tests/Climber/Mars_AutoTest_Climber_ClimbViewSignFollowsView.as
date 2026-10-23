// utils_climber::Get_ClimbViewSign: looking into the wall or up climbs up (+1), looking out over the room or down climbs
// down (-1), a level look along the wall (and anything inside the dead band) keeps the previous sign, the view's length
// does not matter, and the answer turns with the ladder.
class UMars_AutoTest_Climber_ClimbViewSignFollowsView : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the sign for each view", n"Step_Signs");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Signs(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        // The ladder faces +X: the wall is behind it at -X.
        const auto Out = FVector(1.0, 0.0, 0.0);

        AssertSign(FMars_Climber_ViewQuery(FVector(-1.0, 0.0, 0.0), Out, -1.0f), 1.0f, "level into the wall");
        AssertSign(FMars_Climber_ViewQuery(FVector(0.0, 0.0, 1.0), Out, -1.0f), 1.0f, "straight up");
        AssertSign(FMars_Climber_ViewQuery(FVector(1.0, 0.0, 0.0), Out, 1.0f), -1.0f, "level out over the room");
        AssertSign(FMars_Climber_ViewQuery(FVector(0.0, 0.0, -1.0), Out, 1.0f), -1.0f, "straight down");
        AssertSign(FMars_Climber_ViewQuery(FVector(0.866, 0.0, -0.5), Out, 1.0f), -1.0f, "out and 30 deg down (stepping onto the head)");
        AssertSign(FMars_Climber_ViewQuery(FVector(-0.5, 0.866, 0.0), Out, -1.0f), 1.0f, "30 deg into the wall from along it");
        AssertSign(FMars_Climber_ViewQuery(FVector(-4.0, 0.0, 0.0), Out, -1.0f), 1.0f, "an unnormalised view into the wall");

        AssertSign(FMars_Climber_ViewQuery(FVector(0.0, 1.0, 0.0), Out, 1.0f), 1.0f, "level along the wall holds up");
        AssertSign(FMars_Climber_ViewQuery(FVector(0.0, 1.0, 0.0), Out, -1.0f), -1.0f, "level along the wall holds down");
        AssertSign(FMars_Climber_ViewQuery(FVector(-0.087, 0.996, 0.0), Out, -1.0f), -1.0f, "5 deg into the wall is inside the dead band");

        // The same looks with the ladder turned to face +Y.
        const auto OutY = FVector(0.0, 1.0, 0.0);
        AssertSign(FMars_Climber_ViewQuery(FVector(0.0, -1.0, 0.0), OutY, -1.0f), 1.0f, "into a ladder facing +Y");
        AssertSign(FMars_Climber_ViewQuery(FVector(0.0, 1.0, 0.0), OutY, 1.0f), -1.0f, "out from a ladder facing +Y");
    }

    private void AssertSign(const FMars_Climber_ViewQuery& InQuery, float32 InExpected, const FString& InCase)
    {
        const auto Sign = utils_climber::Get_ClimbViewSign(InQuery);
        Assert_True(Sign == InExpected, f"{InCase}: sign {Sign}, expected {InExpected}");
    }
}
