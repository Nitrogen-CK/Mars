// CatchAngleDegrees brakes a swing: stopping a swing with a catch angle does not settle it to rest; it swings on until it
// passes the catch angle and holds there, writing that angle to its node; restarting releases it and it swings again.
// Two swings of amplitude 30 run side by side: one caught at the amplitude's edge (-30, passed once per period) and one
// caught mid-amplitude (-15, passed twice per period, on the way out and on the way back). A spec whose catch angle lies
// outside its amplitude fails Validate(). Each swing broadcasts OnRunningChanged once per edge (Stopped on the brake,
// Running on the release) and OnCameToRest once, at the catch, not at the stop. Isolated Z band: -77000.
class UMars_AutoTest_Oscillator_BrakeCatchesAtCatchAngle : UCk_AutoTest_Base
{
    // A poll budget, not a ceiling: a catch or a release waits on the swing's period.
    private const int32 k_SlowPolls = 900;

    private FVector _Origin = FVector(0.0, 0.0, -77000.0);
    private FCk_Handle_Oscillator _Oscillator;
    private FCk_Handle_SceneNode _Pivot;
    private float32 _CatchAngle = -30.0f;

    private FCk_Handle_Oscillator _MidOscillator;
    private FCk_Handle_SceneNode _MidPivot;
    private float32 _MidCatchAngle = -15.0f;

    private TArray<EMars_Oscillator_RunState> _EdgeRunChanges;
    private TArray<EMars_Oscillator_RunState> _MidRunChanges;
    private int32 _EdgeRests = 0;
    private int32 _MidRests = 0;

    private bool _EdgeSwungAway = false;
    private bool _MidSwungAway = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, _Origin), ECk_Replication::DoesNotReplicate);
        _Pivot = utils_scene_node::Create(Root, FTransform::Identity);
        _MidPivot = utils_scene_node::Create(Root, FTransform::Identity);

        _Oscillator = utils_oscillator::Add(_Pivot, MakeSpec(_CatchAngle));
        _MidOscillator = utils_oscillator::Add(_MidPivot, MakeSpec(_MidCatchAngle));
        _Oscillator.BindTo_OnRunningChanged(FMars_Delegate_Oscillator_OnRunningChanged(this, n"OnEdgeRunningChanged"));
        _MidOscillator.BindTo_OnRunningChanged(FMars_Delegate_Oscillator_OnRunningChanged(this, n"OnMidRunningChanged"));
        _Oscillator.BindTo_OnCameToRest(FMars_Delegate_Oscillator_OnCameToRest(this, n"OnEdgeCameToRest"));
        _MidOscillator.BindTo_OnCameToRest(FMars_Delegate_Oscillator_OnCameToRest(this, n"OnMidCameToRest"));

        Add_Step("a catch angle beyond the amplitude is rejected", n"Step_AssertValidate");
        Add_Step_WaitSeconds("let them swing", 0.3f);
        Add_Step("brake them", n"Step_Stop");
        Add_Step_WaitUntil("the brake catches both", n"Check_Caught", k_SlowPolls, 0);
        Add_Step("each is caught at its catch angle", n"Step_AssertAtCatchAngle");
        Add_Step_WaitSeconds("a caught swing holds", 0.3f);
        Add_Step("still caught, still at the catch angle, written to the node", n"Step_AssertHeld");
        Add_Step("release them", n"Step_Start");
        Add_Step_WaitUntil("released, each swings away from its catch angle", n"Check_SwingingAgain", k_SlowPolls, 0);
        Add_Step("one Stopped and one Running edge each, one rest each", n"Step_AssertEdges");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertValidate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Oscillator, "utils_oscillator::Add accepted a catch angle at the amplitude's edge");
        Assert_Valid(_MidOscillator, "utils_oscillator::Add accepted a catch angle mid-amplitude");
        Assert_True(MakeSpec(_CatchAngle).Validate().IsValid(), "a catch angle at the amplitude's edge validates");
        Assert_True(MakeSpec(_MidCatchAngle).Validate().IsValid(), "a catch angle mid-amplitude validates");

        auto Wide = MakeSpec(_CatchAngle);
        Wide.CatchAngleDegrees = TOptional<float32>(45.0f);
        Assert_False(Wide.Validate().IsValid(), "a catch angle beyond the amplitude does not validate");
    }

    UFUNCTION()
    private void Step_Stop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Oscillator.Request_SetRunning(FMars_Request_Oscillator_SetRunning(EMars_Oscillator_RunState::Stopped));
        _MidOscillator.Request_SetRunning(FMars_Request_Oscillator_SetRunning(EMars_Oscillator_RunState::Stopped));
    }

    UFUNCTION()
    private void Check_Caught(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Oscillator.Get_IsCaught() && _MidOscillator.Get_IsCaught());
    }

    UFUNCTION()
    private void Step_AssertAtCatchAngle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_EdgeRunChanges.Num(), 1, "the brake broadcast one OnRunningChanged on the edge swing");
        Assert_Equals_Int(_MidRunChanges.Num(), 1, "the brake broadcast one OnRunningChanged on the mid swing");
        Assert_True(_EdgeRunChanges.Num() == 1 && _EdgeRunChanges[0] == EMars_Oscillator_RunState::Stopped, "the edge swing's edge is Stopped");
        Assert_True(_MidRunChanges.Num() == 1 && _MidRunChanges[0] == EMars_Oscillator_RunState::Stopped, "the mid swing's edge is Stopped");
        Assert_Equals_Int(_EdgeRests, 1, "the edge swing came to rest once, at its catch");
        Assert_Equals_Int(_MidRests, 1, "the mid swing came to rest once, at its catch");
        Assert_False(_Oscillator.Get_IsRunning(), "a swing caught at the edge is stopped");
        Assert_Equals_Float(_Oscillator.Get_Angle(), _CatchAngle, 0.5, "caught at the edge catch angle");
        Assert_False(_MidOscillator.Get_IsRunning(), "a swing caught mid-amplitude is stopped");
        Assert_Equals_Float(_MidOscillator.Get_Angle(), _MidCatchAngle, 0.5, "caught at the mid-amplitude catch angle");
    }

    UFUNCTION()
    private void Step_AssertHeld(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Oscillator.Get_IsCaught(), "a swing caught at the edge stays caught while stopped");
        Assert_Equals_Float(_Oscillator.Get_Angle(), _CatchAngle, 0.5, "a swing caught at the edge does not drift");
        Assert_Equals_Float(utils_scene_node::Get_Offset_Rotation(_Pivot).Pitch, _CatchAngle, 0.5,
            "the edge node shows its catch angle (pitch axis, zero rest rotation)");

        Assert_True(_MidOscillator.Get_IsCaught(), "a swing caught mid-amplitude stays caught while stopped");
        Assert_Equals_Float(_MidOscillator.Get_Angle(), _MidCatchAngle, 0.5, "a swing caught mid-amplitude does not drift");
        Assert_Equals_Float(utils_scene_node::Get_Offset_Rotation(_MidPivot).Pitch, _MidCatchAngle, 0.5,
            "the mid-amplitude node shows its catch angle (pitch axis, zero rest rotation)");
    }

    UFUNCTION()
    private void Step_Start(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Oscillator.Request_SetRunning(FMars_Request_Oscillator_SetRunning(EMars_Oscillator_RunState::Running));
        _MidOscillator.Request_SetRunning(FMars_Request_Oscillator_SetRunning(EMars_Oscillator_RunState::Running));
    }

    // Each swing passes back near its catch angle once or twice per period, so each one's departure is latched.
    UFUNCTION()
    private void Check_SwingingAgain(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _EdgeSwungAway = _EdgeSwungAway ||
            (_Oscillator.Get_IsCaught() == false && Math::Abs(_Oscillator.Get_Angle() - _CatchAngle) > 5.0f);
        _MidSwungAway = _MidSwungAway ||
            (_MidOscillator.Get_IsCaught() == false && Math::Abs(_MidOscillator.Get_Angle() - _MidCatchAngle) > 5.0f);

        auto Res = OutResult;
        Res.Set(_EdgeSwungAway && _MidSwungAway);
    }

    UFUNCTION()
    private void Step_AssertEdges(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_EdgeRunChanges.Num() == 2 && _EdgeRunChanges[1] == EMars_Oscillator_RunState::Running, "the edge swing's release is one Running edge");
        Assert_True(_MidRunChanges.Num() == 2 && _MidRunChanges[1] == EMars_Oscillator_RunState::Running, "the mid swing's release is one Running edge");
        Assert_Equals_Int(_EdgeRests, 1, "a released swing does not report rest again");
        Assert_Equals_Int(_MidRests, 1, "a released swing does not report rest again");
    }

    UFUNCTION()
    private void OnEdgeRunningChanged(FCk_Handle_Oscillator InOscillator, EMars_Oscillator_RunState InRunState)
    {
        _EdgeRunChanges.Add(InRunState);
    }

    UFUNCTION()
    private void OnMidRunningChanged(FCk_Handle_Oscillator InOscillator, EMars_Oscillator_RunState InRunState)
    {
        _MidRunChanges.Add(InRunState);
    }

    UFUNCTION()
    private void OnEdgeCameToRest(FCk_Handle_Oscillator InOscillator)
    {
        ++_EdgeRests;
    }

    UFUNCTION()
    private void OnMidCameToRest(FCk_Handle_Oscillator InOscillator)
    {
        ++_MidRests;
    }

    private FMars_Oscillator_Spec MakeSpec(float32 InCatchAngle) const
    {
        auto Spec = FMars_Oscillator_Spec();
        Spec.AmplitudeDegrees = 30.0f;
        Spec.PeriodSeconds = 1.0f;
        Spec.SettleSeconds = 0.2f;
        Spec.StartRunning = true;
        Spec.CatchAngleDegrees = TOptional<float32>(InCatchAngle);
        return Spec;
    }
}
