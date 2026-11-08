// A Face turns an idle body in place: the body starts facing +X, a Face toward +Y turns its forward onto +Y (planar dot
// >= 0.99) while its location stays within 2 uu of where it stood; the navigator counts the Face as applied and stays Idle.
// A Face sent while a move is under way is dropped: the move's heading is unchanged and the drop is counted.
class UMars_AutoTest_SurfaceNavigator_FaceTurnsInPlace : UMars_AutoTestRig_SurfaceNavigator
{
    default _TimeoutSeconds = 20.0f;
    default _Origin = FVector(140000.0, 100000.0, 600.0);

    private FVector _Start;
    private float64 _MaxDrift = 0.0;
    private float64 _MinMoveDot = 1.0;
    private int32 _MoveFrames = 0;
    private bool _WatchMove = false;
    private bool _SecondFaceSent = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndBody(InHandle);
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWatch"));

        Add_Step_WaitUntil("the body's surface motion is Ready", n"Check_MotionReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("the body has settled on the floor", n"Check_Settled", k_SlowPolls, 0);
        Add_Step("the idle navigator is asked to face +Y", n"Step_Face");
        Add_Step_WaitUntil("the body faces +Y", n"Check_FacesY", k_SlowPolls, 0);
        Add_Step("it turned in place and the Face was applied", n"Step_AssertTurned");
        Add_Step("a move along +X, then a Face toward -Y while it runs", n"Step_MoveThenFace");
        Add_Step_WaitUntil("the body has run 300 uu of the move", n"Check_MovedFar", k_SlowPolls, 0);
        Add_Step("the move kept its heading and the Face was dropped", n"Step_AssertDropped");
        Run_Steps(InHandle);
    }

    private FVector Get_Forward2D() const
    {
        auto Forward = utils_transform::Get_EntityCurrentRotation(_Motion.As_Transform()).GetForwardVector();
        Forward.Z = 0.0;
        return Forward.GetSafeNormal();
    }

    UFUNCTION()
    private void OnWatch(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (IsFinished() || ck::Is_NOT_Valid(_Motion))
        { return; }

        if (_WatchMove == false)
        {
            if (_Start.IsZero() == false)
            { _MaxDrift = Math::Max(_MaxDrift, (Get_BodyLocation() - _Start).Size2D()); }
            return;
        }

        // Once the turn onto the move has settled, the heading stays on +X.
        if (_Nav.Get_Status() == EMars_SurfaceNavigator_Status::Moving && (Get_BodyLocation() - _Start).Size2D() > 120.0)
        {
            ++_MoveFrames;
            _MinMoveDot = Math::Min(_MinMoveDot, Get_Forward2D().DotProduct(FVector(1.0, 0.0, 0.0)));
        }
    }

    UFUNCTION()
    private void Check_Settled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_surface_motion::Get_Velocity(_Motion).Size() < 1.0 && Get_Forward2D().DotProduct(FVector(1.0, 0.0, 0.0)) > 0.999);
    }

    UFUNCTION()
    private void Step_Face(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Start = Get_BodyLocation();
        _Nav.Request_Face(FMars_Request_SurfaceNavigator_Face(FVector(0.0, 250.0, 40.0)));
    }

    UFUNCTION()
    private void Check_FacesY(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_Forward2D().DotProduct(FVector(0.0, 1.0, 0.0)) >= 0.99);
    }

    UFUNCTION()
    private void Step_AssertTurned(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_MaxDrift <= 2.0, f"the body turned in place (drifted {_MaxDrift} uu)");
        Assert_Equals_Int(_Nav.Get_FacesApplied(), 1, "the idle navigator applied the Face");
        Assert_Equals_Int(_Nav.Get_FacesDropped(), 0, "nothing was dropped");
        Assert_True(_Nav.Get_Status() == EMars_SurfaceNavigator_Status::Idle, f"a Face does not start a move (got [{_Nav.Get_Status() :n}])");
    }

    UFUNCTION()
    private void Step_MoveThenFace(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Start = Get_BodyLocation();
        _WatchMove = true;
        _Nav.Request_MoveTo(FMars_Request_SurfaceNavigator_MoveTo(_Start + FVector(1000.0, 0.0, 0.0)));
        _Nav.Request_Face(FMars_Request_SurfaceNavigator_Face(FVector(0.0, -1.0, 0.0)));
    }

    UFUNCTION()
    private void Check_MovedFar(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        // A second Face mid-move, after the turn onto +X settled.
        if (_MoveFrames >= 10 && _SecondFaceSent == false)
        {
            _SecondFaceSent = true;
            _Nav.Request_Face(FMars_Request_SurfaceNavigator_Face(FVector(0.0, -1.0, 0.0)));
        }

        auto Res = OutResult;
        Res.Set((Get_BodyLocation() - _Start).Size2D() > 300.0);
    }

    UFUNCTION()
    private void Step_AssertDropped(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_MoveFrames > 10, f"the move was watched after its turn ({_MoveFrames} frames)");
        Assert_True(_MinMoveDot >= 0.99, f"a Face during the move never turned the body off +X (min dot {_MinMoveDot})");
        Assert_Equals_Int(_Nav.Get_FacesDropped(), 2, "both Faces sent during the move were dropped");
        Assert_Equals_Int(_Nav.Get_FacesApplied(), 1, "no Face was applied during the move");
        Assert_True(_Nav.Get_Status() == EMars_SurfaceNavigator_Status::Moving, f"the move is still under way (got [{_Nav.Get_Status() :n}])");
    }
}
