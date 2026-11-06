// The facing fix: a bat that telegraphs after a pull-out used to dive from whatever heading its last leg left it on. Now
// the kernel turns the root toward the aim point while it telegraphs, and the recovery carries THROUGH past the target
// (the mirror of the strike point on the far side) instead of flying back the way it came. With the target 600 uu out
// along +X, the first commit must face it (yaw within 15 degrees) and the first recovery must end beyond it.
class UMars_AutoTest_Bat_TelegraphFacesTheTargetAndCarriesThrough : UMars_AutoTestRig_Bat
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(320000.0, -186000.0, 2000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_World(InHandle);
        SpawnTarget(InHandle, FVector(600.0, 0.0, 0.0));

        Add_WorldSteps();
        Add_Step_WaitUntil("it commits a swoop and the blow lands", n"Check_Landed", 0, k_FlightSeconds);
        Add_Step_WaitUntil("its first recovery ends", n"Check_Recovered", 0, k_FlightSeconds);
        Add_Step("it faced the target at commit and carried through past it", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Landed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Landed.Num() >= 1 && _FacingErrorAtCommit.IsSet());
    }

    UFUNCTION()
    private void Check_Recovered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_FirstRecoverEnd.IsSet());
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Error = _FacingErrorAtCommit.GetValue();
        const auto End = _FirstRecoverEnd.GetValue();
        const auto TargetX = utils_transform::Get_EntityCurrentLocation(_TargetRoot).X;
        Log(f"[BatTest] facing error at commit {Error} deg; first recovery ended at {End.ToString()} (target x {TargetX})");
        Assert_True(Error <= 15.0f, f"it faced the target when it committed ({Error} degrees off)");
        Assert_True(End.X > TargetX + 100.0, f"its recovery carried through past the target (ended at x {End.X}, target x {TargetX})");
        Assert_Equals_Int(_Landed.Num(), 1, "the first swoop landed once");
    }
}
