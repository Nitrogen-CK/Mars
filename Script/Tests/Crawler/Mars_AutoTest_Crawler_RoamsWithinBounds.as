// An unhurt crawler that can walk roams: its brain's leaf is Roam, so the behaviour sub-SM goes Idle -> Roam, and the Roam
// task picks goals in RoamBounds (+-300 around the spawn), walks to them and dwells 0.3 s between. Over at least 8 s the
// body covers >= 150 uu of path, never leaves the bounds inflated by 100 uu, and the navigator arrives at least once.
class UMars_AutoTest_Crawler_RoamsWithinBounds : UMars_AutoTestRig_Crawler
{
    default _TimeoutSeconds = 30.0f;
    default _Origin = FVector(150000.0, 80000.0, 600.0);

    private FBox _Bounds;

    private int32 _ArrivedCount = 0;
    private float64 _RecordStart = 0.0;
    private TOptional<FVector> _Last;
    private float64 _PathLength = 0.0;
    private float64 _WorstOutside = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto Half = FVector(300.0, 300.0, 200.0);
        _Bounds = FBox(_Origin - Half, _Origin + Half);
        SpawnFloorAndCrawler(InHandle, Make_Spec());

        Add_Step_WaitUntil("the crawler is composed and its gait Ready", n"Check_GaitReady", 0, 10.0f);
        Add_Step_WaitUntil("the behaviour sub-SM is in Roam", n"Check_InRoam", 0, 5.0f);
        Add_Step("bind the navigator's OnArrived; start recording", n"Step_StartRecording");
        Add_Step_WaitUntil("8 s of roaming recorded and an arrival seen", n"Check_Recorded", 0, 20.0f);
        Add_Step("the crawler roamed inside its bounds", n"Step_AssertRoamed");
        Run_Steps(InHandle);
    }

    private FMars_Crawler_Spec Make_Spec()
    {
        auto Spec = FMars_Crawler_Spec(4, _Bounds);
        Spec.RoamDwellSeconds = 0.3f;
        return Spec;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnArrived(FCk_Handle_SurfaceNavigator InNavigator, FVector InGoal)
    {
        ++_ArrivedCount;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Step_StartRecording(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Navigator = _Crawler.Get_Navigator();
        Navigator.BindTo_OnArrived(FMars_Delegate_SurfaceNavigator_OnArrived(this, n"OnArrived"));
        _RecordStart = System::GetGameTimeInSeconds();
    }

    // Accumulates the body's XY path and its worst excursion outside RoamBounds every evaluation.
    UFUNCTION()
    private void Check_Recorded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Location = BodyLocation();

        if (_Last.IsSet())
        { _PathLength += (Location - _Last.GetValue()).Size2D(); }

        _Last = Location;

        const auto OutsideX = Math::Max(_Bounds.Min.X - Location.X, Location.X - _Bounds.Max.X);
        const auto OutsideY = Math::Max(_Bounds.Min.Y - Location.Y, Location.Y - _Bounds.Max.Y);
        _WorstOutside = Math::Max(_WorstOutside, Math::Max(OutsideX, OutsideY));

        Res.Set(System::GetGameTimeInSeconds() - _RecordStart >= 8.0 && _ArrivedCount > 0);
    }

    UFUNCTION()
    private void Step_AssertRoamed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_PathLength >= 150.0, f"the body roamed >= 150 uu of path ({_PathLength})");
        Assert_True(_WorstOutside <= 100.0, f"the body stayed within RoamBounds + 100 uu (worst excursion {_WorstOutside})");
        Assert_True(_ArrivedCount >= 1, f"the navigator arrived at least once ({_ArrivedCount})");
        Assert_True(_Crawler.Get_BehaviorStateClass() == UMars_SmState_Crawler_Roam, "the crawler is still roaming");
        Assert_True(_Crawler.Get_Brain().Get_LeafClass() == UMars_GoapAction_Crawler_Roam, "the brain's leaf is Roam");
    }
}
