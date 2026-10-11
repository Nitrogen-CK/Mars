// A stopped crawler turns on the spot through SurfaceMotion alone: once its navigator has stopped (and so relinquished
// steering), a zero-speed steering request whose direction is 90 degrees off the root's forward turns the root to within
// 10 degrees of that direction inside 4 s while the root drifts less than 10 cm. This is the facing the melee Prepare
// state depends on, without a second root rotation writer. The reach-pace state is sampled every poll,
// so a failure says whether the turn was paced or blocked by reach while stepping continued, or never turned at all.
//
// The stop is issued only once the behaviour sub-SM is in Roam, so the Roam task's first MoveTo cannot land after it, and
// RoamDwellSeconds is long so the Roam task, which dwells after a stop from outside, issues no new MoveTo afterwards. The
// stopped body is then watched unsteered for 1 s (the rest drift), and the navigator must stay stopped from the stop on.
class UMars_AutoTest_CrawlerMelee_StationaryFacing : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 30.0f;
    default _Origin = FVector(-160000.0, -150000.0, 600.0);

    private const float32 k_ToleranceDegrees = 10.0f;
    private const float32 k_TurnSeconds = 4.0f;
    private const float64 k_MaxDriftCm = 10.0;
    private const float32 k_SampleEverySeconds = 0.1f;
    // Before steering, the stopped body is watched this long with no steer at all: drift there is settling, not turning.
    private const float32 k_RestSeconds = 1.0f;

    private FVector _Up = FVector::UpVector;
    private FVector _TargetDirection;
    private FVector _StartLocation;
    private float64 _StartSeconds = 0.0;

    private float64 _StartErrorDegrees = 0.0;
    private float64 _ErrorDegrees = 180.0;
    private float64 _MaxDrift = 0.0;
    private float64 _MaxDriftHorizontal = 0.0;
    private float64 _MaxDriftVertical = 0.0;
    private FVector _RestLocation;
    private FVector _RestDrift;
    private float64 _RestStartSeconds = 0.0;
    private TOptional<float64> _ConvergedAfter;
    private bool _NavigatorMovedAgain = false;
    private int32 _PacedPolls = 0;
    private int32 _BlockedPolls = 0;
    private int32 _Polls = 0;
    private float64 _NextSampleSeconds = 0.0;
    private FString _Samples = "";

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_CrawlerSpec(FVector(150.0, 150.0, 200.0));
        Spec.RoamDwellSeconds = 120.0f;
        SpawnFloorAndCrawler(InHandle, Spec);

        Add_Step_WaitUntil("the crawler is composed, its gait Ready and its 4 parts registered", n"Check_Ready", k_SlowPolls, 0);
        Add_Step_WaitUntil("the behaviour sub-SM is in Roam", n"Check_InRoam", k_SlowPolls, 0);
        Add_Step("stop the navigator", n"Step_StopNavigator");
        Add_Step_WaitUntil("the navigator has drained the stop and is not Moving", n"Check_NavigatorStopped", k_SlowPolls, 0);
        Add_Step("record the stopped body's location", n"Step_RecordRest");
        Add_Step_WaitUntil("the stopped body rests, unsteered, for 1 s", n"Check_Rested", 0, 0);
        Add_Step("record the rest drift; steer at zero speed 90 degrees off the root's forward", n"Step_SteerSideways");
        Add_Step_WaitUntil("the root faces the steer direction within 10 degrees, or 4 s pass", n"Check_TurnedOrTimedOut", 0, 0);
        Add_Step("the root turned in place within 4 s through SurfaceMotion alone", n"Step_AssertTurned");
        Run_Steps(InHandle);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Helpers
    //----------------------------------------------------------------------------------------------------------------------

    private FVector Get_RootForwardInPlane() const
    {
        const auto Forward = utils_transform::Get_EntityCurrentTransform(_Crawler.As_Transform()).GetRotation().GetForwardVector();
        return (Forward - _Up * Forward.DotProduct(_Up)).GetSafeNormal();
    }

    private float64 Get_HeadingErrorDegrees() const
    {
        const auto Dot = Math::Clamp(Get_RootForwardInPlane().DotProduct(_TargetDirection), -1.0, 1.0);
        return Math::RadiansToDegrees(Math::Acos(Dot));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Step_StopNavigator(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Navigator = _Crawler.Get_Navigator();
        Navigator.Request_Stop(FMars_Request_SurfaceNavigator_Stop());
    }

    UFUNCTION()
    private void Check_NavigatorStopped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Navigator = _Crawler.Get_Navigator();
        auto Res = OutResult;
        Res.Set(Navigator.Get_HasPendingRequests() == false && Navigator.Get_Status() != EMars_SurfaceNavigator_Status::Moving);
    }

    UFUNCTION()
    private void Check_InRoam(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_BehaviorStateClass() == UMars_SmState_Crawler_Roam);
    }

    UFUNCTION()
    private void Step_RecordRest(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _RestLocation = BodyLocation();
        _RestStartSeconds = System::GetGameTimeInSeconds();
    }

    UFUNCTION()
    private void Check_Rested(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Navigator = _Crawler.Get_Navigator();
        if (Navigator.Get_Status() == EMars_SurfaceNavigator_Status::Moving)
        { _NavigatorMovedAgain = true; }

        auto Res = OutResult;
        Res.Set(System::GetGameTimeInSeconds() - _RestStartSeconds >= k_RestSeconds);
    }

    UFUNCTION()
    private void Step_SteerSideways(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _RestDrift = BodyLocation() - _RestLocation;

        auto Motion = _Crawler.Get_Motion();
        const auto SupportNormal = utils_surface_motion::Get_SupportNormal(Motion);
        if (SupportNormal.IsNearlyZero() == false)
        { _Up = SupportNormal.GetSafeNormal(); }

        const auto Forward = Get_RootForwardInPlane();
        _TargetDirection = _Up.CrossProduct(Forward).GetSafeNormal();
        _StartLocation = BodyLocation();
        _StartSeconds = System::GetGameTimeInSeconds();
        _NextSampleSeconds = 0.0;
        _StartErrorDegrees = Get_HeadingErrorDegrees();

        utils_surface_motion::Request_Steering(Motion, FCk_Request_SurfaceMotion_Steering(_TargetDirection, 0.0f));
    }

    // Samples the heading error, the reach-pace state and the drift every poll; holds once the error is inside the
    // tolerance, or once the 4 s window has passed so the assertion step can report the samples.
    UFUNCTION()
    private void Check_TurnedOrTimedOut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        auto Motion = _Crawler.Get_Motion();
        auto Navigator = _Crawler.Get_Navigator();

        const auto Elapsed = System::GetGameTimeInSeconds() - _StartSeconds;
        const auto Pace = utils_surface_motion::Get_ReachPaceState(Motion);
        const auto Delta = BodyLocation() - _StartLocation;
        const auto Drift = Delta.Size();
        const auto DriftHorizontal = Delta.Size2D();
        const auto DriftVertical = Delta.Z;

        ++_Polls;
        _ErrorDegrees = Get_HeadingErrorDegrees();
        _MaxDrift = Math::Max(_MaxDrift, Drift);
        _MaxDriftHorizontal = Math::Max(_MaxDriftHorizontal, DriftHorizontal);
        _MaxDriftVertical = Math::Max(_MaxDriftVertical, Math::Abs(DriftVertical));

        if (Pace == ECk_SurfaceMotion_ReachPaceState::Pacing)
        { ++_PacedPolls; }

        if (Pace == ECk_SurfaceMotion_ReachPaceState::Blocked)
        { ++_BlockedPolls; }

        if (Navigator.Get_Status() == EMars_SurfaceNavigator_Status::Moving)
        { _NavigatorMovedAgain = true; }

        if (Elapsed >= _NextSampleSeconds)
        {
            _Samples = f"{_Samples} [t={Elapsed :.2} err={_ErrorDegrees :.1} pace={Pace :n} dxy={DriftHorizontal :.2} dz={DriftVertical :.2}]";
            _NextSampleSeconds += k_SampleEverySeconds;
        }

        if (_ErrorDegrees <= k_ToleranceDegrees)
        {
            _ConvergedAfter = Elapsed;
            _Samples = f"{_Samples} [t={Elapsed :.2} err={_ErrorDegrees :.1} pace={Pace :n} dxy={DriftHorizontal :.2} dz={DriftVertical :.2} converged]";
            Res.Set(true);
            return;
        }

        Res.Set(Elapsed >= k_TurnSeconds);
    }

    UFUNCTION()
    private void Step_AssertTurned(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Converged = _ConvergedAfter.IsSet();
        const auto ConvergedAfter = Converged ? _ConvergedAfter.GetValue() : -1.0;
        ck::Trace(f"[CrawlerMelee.P0] stationary-facing: startErr={_StartErrorDegrees :.1} converged={Converged} after={ConvergedAfter :.2}s finalErr={_ErrorDegrees :.1} maxDrift={_MaxDrift :.2}cm (xy {_MaxDriftHorizontal :.2}, |z| {_MaxDriftVertical :.2}) restDrift={_RestDrift.ToString()} polls={_Polls} pacing={_PacedPolls} blocked={_BlockedPolls} navigatorMovedAgain={_NavigatorMovedAgain} samples:{_Samples}");

        Assert_True(_StartErrorDegrees >= 80.0,
            f"the steer direction starts about 90 degrees off the root's forward (got {_StartErrorDegrees :.1}), so the turn is not vacuous");
        Assert_False(_NavigatorMovedAgain,
            "the navigator stayed stopped from the stop to the end of the turn, so SurfaceMotion's steering came only from this test");
        Assert_True(Converged,
            f"a zero-speed steer turns the stopped root to within {k_ToleranceDegrees :.0} degrees inside {k_TurnSeconds :.0} s (final error {_ErrorDegrees :.1}, polls Pacing {_PacedPolls} / Blocked {_BlockedPolls} of {_Polls}; samples:{_Samples})");
        Assert_True(_MaxDrift < k_MaxDriftCm,
            f"the root drifts less than {k_MaxDriftCm :.0} cm while turning in place (max {_MaxDrift :.2} cm: horizontal {_MaxDriftHorizontal :.2}, vertical {_MaxDriftVertical :.2}; unsteered rest drift before the turn {_RestDrift.Size() :.2}; samples:{_Samples})");
    }
}
