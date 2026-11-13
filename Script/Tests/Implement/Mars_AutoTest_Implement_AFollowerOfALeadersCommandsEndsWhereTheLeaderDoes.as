// Two implements with the same pan-like spec. The leader is driven by a second of looks: half a second sweeping right (to
// the roll clamp), one fast upward flick (a kick), then nothing. The follower is fed the leader's Get_Command() whenever
// utils_implement::Advance_CommandPacer says so. Every frame the two shown rolls differ by under 6 degrees; half a second
// after the looks stop their shown tilts differ by under 0.2 degrees and their lifts by under 0.2 uu; the follower's lift
// rose above half the leader's peak; the follower's roll never moves faster in one frame than the spec's rate allows (plus
// 0.1 degrees).
class UMars_AutoTest_Implement_AFollowerOfALeadersCommandsEndsWhereTheLeaderDoes : UMars_AutoTestRig_Implement
{
    default _TimeoutSeconds = 8.0f;

    // Degrees of look per second while sweeping: with the default 1.2 tilt per degree less the 45 deg/s relax, the roll
    // target climbs about 99 deg/s and meets the 30-degree clamp a third of a second into the half-second sweep.
    private const float64 k_SweepLookDegreesPerSecond = 120.0;
    private const float64 k_SweepSeconds = 0.5;
    private const float64 k_FlickDegrees = 40.0;
    private const float64 k_LooksSeconds = 1.0;
    private const float64 k_SettleSeconds = 0.5;

    private FCk_Handle_Implement _Follower;
    private FMars_Implement_CommandPacer _Pacer;

    private float64 _StartSeconds = -1.0;
    private float64 _LastSeconds = -1.0;
    private bool _Flicked = false;
    private int32 _Frames = 0;
    private int32 _Publishes = 0;
    private float32 _WorstRollDifference = 0.0f;
    private float32 _LeaderPeakLift = 0.0f;
    private float32 _FollowerPeakLift = 0.0f;
    private float32 _LargestFollowerStep = 0.0f;
    // The largest follower roll step less what the rate allows that frame (positive = faster than the rate).
    private float32 _WorstStepExcess = -1000.0f;
    private float32 _LastFollowerRoll = 0.0f;
    private float32 _LeaderPeakRoll = 0.0f;
    private int64 _LastFrame = -1;
    private float64 _LastFrameSeconds = 0.0;
    // The poll that gave _WorstStepExcess: its frame time and how many frames it covered.
    private float32 _WorstStepSeconds = 0.0f;
    private int64 _WorstStepFrames = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildImplement(InHandle, FMars_Implement_Spec());
        _Follower = Build_Follower(InHandle);

        Add_Step("drive the leader", n"Step_Drive");
        Add_Step_WaitUntil("the leader is Driven", n"Check_Driven", 0, 0);
        Add_Step_WaitUntil("a second of looks on the leader, the follower fed its commands, then half a second", n"Check_Run", 0, 0);
        Add_Step("the follower ends where the leader does", n"Step_Assert");
        Run_Steps(InHandle);
    }

    // The same spec on its own root beside the leader's.
    private FCk_Handle_Implement Build_Follower(FCk_Handle InHandle)
    {
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(RootEntity, FTransform(FRotator::ZeroRotator, k_Origin + FVector(0.0, 300.0, 0.0)), ECk_Replication::DoesNotReplicate);
        auto Node = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 100.0)));
        auto Spec = FMars_Implement_Spec();
        Spec.Nodes = FMars_Implement_Nodes(Node);
        return utils_implement::Add(RootEntity, Spec);
    }

    UFUNCTION()
    private void Step_Drive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Implement) && ck::IsValid(_Follower), "both implements composed");
        Drive();
    }

    // Once a frame: the leader's look for this frame, the pacer, the comparison.
    UFUNCTION()
    private void Check_Run(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Now = System::GetGameTimeInSeconds();
        if (_StartSeconds < 0.0)
        {
            _StartSeconds = Now;
            _LastSeconds = Now;
            _LastFollowerRoll = float32(_Follower.Get_Tilt().Roll);
        }

        const auto Elapsed = Now - _StartSeconds;
        const auto DeltaSeconds = float32(Now - _LastSeconds);
        _LastSeconds = Now;
        ++_Frames;

        if (Elapsed < k_SweepSeconds)
        { Look(FVector(k_SweepLookDegreesPerSecond * float64(DeltaSeconds), 0.0, 0.0)); }
        else if (_Flicked == false)
        {
            _Flicked = true;
            Look(FVector(0.0, -k_FlickDegrees, 0.0));
        }

        if (utils_implement::Advance_CommandPacer(_Pacer, _Implement.Get_Command(), DeltaSeconds))
        {
            ++_Publishes;
            _Follower.Request_Follow(FMars_Request_Implement_Follow(_Pacer.Published.GetValue()));
        }

        const auto LeaderRoll = _Implement.Get_Tilt().Roll;
        const auto FollowerRoll = _Follower.Get_Tilt().Roll;
        _WorstRollDifference = Math::Max(_WorstRollDifference, Math::Abs(float32(LeaderRoll - FollowerRoll)));
        _LeaderPeakRoll = Math::Max(_LeaderPeakRoll, float32(LeaderRoll));
        _LeaderPeakLift = Math::Max(_LeaderPeakLift, _Implement.Get_Lift());
        _FollowerPeakLift = Math::Max(_FollowerPeakLift, _Follower.Get_Lift());

        // A frame can be polled twice, before and after the implement's tick (at one game time): the step is measured
        // between the first polls of two frames, which are one tick and one frame time apart.
        const auto Frame = utils_time::Get_FrameCounter();
        if (Frame != _LastFrame)
        {
            const auto Step = Math::Abs(float32(FollowerRoll) - _LastFollowerRoll);
            const auto StepSeconds = float32(Now - _LastFrameSeconds);
            const auto Excess = Step - _Spec.Tilt.MaxTiltRateDegreesPerSecond * StepSeconds;
            _LastFollowerRoll = float32(FollowerRoll);
            _LargestFollowerStep = Math::Max(_LargestFollowerStep, Step);
            if (_LastFrame >= 0 && Excess > _WorstStepExcess)
            {
                _WorstStepExcess = Excess;
                _WorstStepSeconds = StepSeconds;
                _WorstStepFrames = Frame - _LastFrame;
            }

            _LastFrame = Frame;
            _LastFrameSeconds = Now;
        }

        auto Res = OutResult;
        Res.Set(Elapsed >= k_LooksSeconds + k_SettleSeconds);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto LeaderTilt = _Implement.Get_Tilt();
        const auto FollowerTilt = _Follower.Get_Tilt();
        const auto TiltDifference = Math::Max(Math::Abs(LeaderTilt.Pitch - FollowerTilt.Pitch),
            Math::Max(Math::Abs(LeaderTilt.Roll - FollowerTilt.Roll), Math::Abs(LeaderTilt.Yaw - FollowerTilt.Yaw)));
        const auto LiftDifference = Math::Abs(_Implement.Get_Lift() - _Follower.Get_Lift());

        ck::Trace(f"[Implement] follower: frames {_Frames} publishes {_Publishes} worstRollDiff {_WorstRollDifference :.3} leaderPeakRoll {_LeaderPeakRoll :.3} "
            + f"liftPeaks leader {_LeaderPeakLift :.3} follower {_FollowerPeakLift :.3} largestFollowerStep {_LargestFollowerStep :.3} worstStepExcess {_WorstStepExcess :.3} at dt {_WorstStepSeconds} over {_WorstStepFrames} frames "
            + f"endTiltDiff {TiltDifference :.4} endLiftDiff {LiftDifference :.4}");

        Assert_True(_Follower.Get_Steering() == EMars_Implement_Steering::Followed, "the follower is Followed");
        Assert_True(_LeaderPeakRoll >= _Spec.Tilt.MaxTiltDegrees - 0.5f, f"the leader's sweep reached the roll clamp (peak {_LeaderPeakRoll})");
        Assert_True(_WorstRollDifference < 6.0f, f"every frame the two rolls differ by under 6 degrees (worst {_WorstRollDifference})");
        Assert_True(TiltDifference < 0.2, f"after the looks the two tilts differ by under 0.2 degrees (got {TiltDifference})");
        Assert_True(LiftDifference < 0.2, f"after the looks the two lifts differ by under 0.2 uu (got {LiftDifference})");
        Assert_True(_LeaderPeakLift > 1.0f, f"the flick kicked the leader's lift (peak {_LeaderPeakLift})");
        Assert_True(_FollowerPeakLift > 0.5f * _LeaderPeakLift,
            f"the follower's lift rose above half the leader's peak (follower {_FollowerPeakLift}, leader {_LeaderPeakLift})");
        Assert_True(_WorstStepExcess < 0.1f, f"the follower's roll never outran its rate by 0.1 degrees in a frame (worst excess {_WorstStepExcess}, largest step {_LargestFollowerStep})");
    }
}
