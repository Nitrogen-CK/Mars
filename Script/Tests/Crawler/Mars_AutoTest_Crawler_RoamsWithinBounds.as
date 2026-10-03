// An unhurt crawler that can walk roams: its brain's leaf is Roam, so the behaviour sub-SM goes Idle -> Roam, and the Roam
// task picks goals in RoamBounds (+-300 around the spawn), walks to them and dwells 0.3 s between. Over at least 8 s the
// body covers >= 150 uu of path, never leaves the bounds inflated by 100 uu, and the navigator arrives at least once.
//
// Spawned through the real entity script onto a runtime static Jolt floor (no nav field: straight-line moves).
// Isolated origin (150000, 80000, 600): the Mars autotest map has no floor of its own there.
class UMars_AutoTest_Crawler_RoamsWithinBounds : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 30.0f;

    private FVector _Origin = FVector(150000.0, 80000.0, 600.0);
    private FBox _Bounds;
    private FCk_Handle_Crawler _Crawler;

    private int32 _ArrivedCount = 0;
    private float64 _RecordStart = 0.0;
    private bool _HasLast = false;
    private FVector _Last;
    private float64 _PathLength = 0.0;
    private float64 _WorstOutside = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto Half = FVector(300.0, 300.0, 200.0);
        _Bounds = FBox(_Origin - Half, _Origin + Half);
        SpawnFloorAndCrawler(InHandle, Make_Spec());

        Add_Step_WaitUntil("the crawler is composed and its gait Ready", n"Check_Ready", 0, 10.0f);
        Add_Step_WaitUntil("the behaviour sub-SM is in Roam", n"Check_InRoam", 0, 5.0f);
        Add_Step("bind the navigator's OnArrived; start recording", n"Step_StartRecording");
        Add_Step_WaitUntil("8 s of roaming recorded and an arrival seen", n"Check_Recorded", 0, 20.0f);
        Add_Step("the crawler roamed inside its bounds", n"Step_AssertRoamed");
        Run_Steps(InHandle);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Shared rig (one scenario per file: copied, not shared)
    //----------------------------------------------------------------------------------------------------------------------

    private FMars_Crawler_Spec Make_Spec()
    {
        auto Spec = FMars_Crawler_Spec(4, _Bounds);
        Spec.RoamDwellSeconds = 0.3f;
        return Spec;
    }

    private void SpawnFloorAndCrawler(FCk_Handle InHandle, FMars_Crawler_Spec InSpec)
    {
        auto Floor = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(Floor, FTransform(FRotator::ZeroRotator, _Origin - FVector(0.0, 0.0, 10.0)), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(1500.0, 1500.0, 10.0));
        auto FloorSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        FloorSpec.Set_ShapeDimensions(Shape);
        FloorSpec.Set_MotionType(ECk_MotionType::Static);
        FloorSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Floor, FloorSpec);

        auto SpawnParams = UMars_Crawler_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, _Origin + FVector(0.0, 0.0, 65.0));
        SpawnParams.Spec = InSpec;
        SpawnParams.WithVisuals = false;
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Crawler_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnCrawlerConstructed"));
    }

    UFUNCTION()
    private void OnCrawlerConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _Crawler = FCk_Handle(InEntityScriptHandle).As_Crawler(ECk_SanityCheck::UnChecked);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (ck::Is_NOT_Valid(_Crawler))
        {
            Res.Set(false);
            return;
        }

        const auto Gait = _Crawler.Get_Gait();
        if (utils_procedural_gait::Get_Status(Gait) == ECk_ProceduralAnimation_Status::Failed)
        {
            FinishFailure(f"the crawler's gait failed: {utils_procedural_gait::Get_Failure(Gait) :n}");
            return;
        }

        Res.Set(utils_procedural_gait::Get_Status(Gait) == ECk_ProceduralAnimation_Status::Ready);
    }

    private FVector BodyLocation() const
    {
        return utils_transform::Get_EntityCurrentLocation(utils_transform::DoCastChecked(FCk_Handle(_Crawler)));
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
    private void Check_InRoam(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_BehaviorStateClass() == UMars_SmState_Crawler_Roam);
    }

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

        if (_HasLast)
        { _PathLength += (Location - _Last).Size2D(); }
        _Last = Location;
        _HasLast = true;

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
