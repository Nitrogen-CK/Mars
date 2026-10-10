// The cutting station's cleaver is drawn from the kernel's chop signals, never read by it: the assembly sends the cleaver's
// Mover down when a chop starts and back up when it lands. On the real station, one chop: the Mover's target goes to End
// within a frame of OnChopStarted and back to Start within a frame of OnChopLanded, those two changes only, and the Mover
// rests raised once the kernel reads Idle. Isolated origin (184000, -70000, -30000).
class UMars_AutoTest_CuttingStation_TheCleaverFollowsTheChopSignals : UMars_AutoTestRig_CuttingStation
{
    private const FVector k_Origin = FVector(184000.0, -70000.0, -30000.0);
    // A Mover request from a signal handler drains in that frame's Mover pass or the next one.
    private const int64 k_FrameLag = 1;

    private FCk_Handle_Mover _ChopMover;
    private int64 _StartedFrame = -1;
    private int64 _LandedFrame = -1;
    private TArray<EMars_Mover_Pose> _Targets;
    private TArray<int64> _TargetFrames;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);

        Add_Step_WaitUntil("the station composed its Cutting, FoodBoard and docks", n"Check_StationReady", 0, 0);
        Add_Step("find the cleaver's Mover and watch it", n"Step_WatchTheCleaver");
        Add_Step("chop", n"Step_Chop");
        Add_Step_WaitUntil("the chop landed and the cleaver is back up", n"Check_ChopDone", 0, 0);
        Add_Step_WaitUntil("the cleaver rests raised", n"Check_CleaverRaised", 0, 0);
        Add_Step("the Mover followed the two signals and nothing else", n"Step_AssertFollowed");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_WatchTheCleaver(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _ChopMover = Find_Mover(_Station);
        Assert_True(ck::IsValid(_ChopMover), "the station has a cleaver Mover");
        if (ck::Is_NOT_Valid(_ChopMover))
        { return; }

        Assert_True(_ChopMover.Get_Target() == EMars_Mover_Pose::Start && _ChopMover.Get_IsResting(), "the cleaver starts raised");
        _ChopMover.BindTo_OnTargetChanged(FMars_Delegate_Mover_OnTargetChanged(this, n"OnCleaverTargetChanged"));
        _Cutting.BindTo_OnChopStarted(FMars_Delegate_Cutting_OnChopStarted(this, n"OnChopStarted"));
        _Cutting.BindTo_OnChopLanded(FMars_Delegate_Cutting_OnChopLanded(this, n"OnChopLandedFrame"));
    }

    UFUNCTION()
    private void Step_Chop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Chop();
    }

    UFUNCTION()
    private void Check_CleaverRaised(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ChopMover.Get_Target() == EMars_Mover_Pose::Start && _ChopMover.Get_IsResting());
    }

    UFUNCTION()
    private void Step_AssertFollowed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_StartedFrame >= 0 && _LandedFrame >= 0, "the kernel started and landed the chop");
        Assert_Equals_Int(_Targets.Num(), 2, "the Mover changed target twice");
        if (_Targets.Num() != 2)
        { return; }

        Assert_True(_Targets[0] == EMars_Mover_Pose::End, "down first");
        Assert_True(_TargetFrames[0] - _StartedFrame >= 0 && _TargetFrames[0] - _StartedFrame <= k_FrameLag,
            f"down at the chop's start (frame {_TargetFrames[0]} vs {_StartedFrame})");
        Assert_True(_Targets[1] == EMars_Mover_Pose::Start, "then back up");
        Assert_True(_TargetFrames[1] - _LandedFrame >= 0 && _TargetFrames[1] - _LandedFrame <= k_FrameLag,
            f"up at the chop's landing (frame {_TargetFrames[1]} vs {_LandedFrame})");
    }

    // The Mover the station's assembly built, found among the station's lifetime dependents (the cleaver node hangs under
    // the lateral node).
    private FCk_Handle_Mover Find_Mover(FCk_Handle InEntity) const
    {
        for (auto Dependent : utils_entity_lifetime::Get_LifetimeDependents(InEntity))
        {
            if (ck::Is_NOT_Valid(Dependent))
            { continue; }

            if (Dependent.Is_Mover())
            { return Dependent.As_Mover(); }

            const auto Found = Find_Mover(Dependent);
            if (ck::IsValid(Found))
            { return Found; }
        }

        return FCk_Handle_Mover();
    }

    UFUNCTION()
    private void OnCleaverTargetChanged(FCk_Handle_Mover InMover, EMars_Mover_Pose InTarget)
    {
        _Targets.Add(InTarget);
        _TargetFrames.Add(utils_time::Get_FrameCounter());
    }

    UFUNCTION()
    private void OnChopStarted(FCk_Handle_Cutting InCutting)
    {
        _StartedFrame = utils_time::Get_FrameCounter();
    }

    UFUNCTION()
    private void OnChopLandedFrame(FCk_Handle_Cutting InCutting)
    {
        _LandedFrame = utils_time::Get_FrameCounter();
    }
}
