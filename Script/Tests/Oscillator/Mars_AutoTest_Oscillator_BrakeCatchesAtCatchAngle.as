// CatchAngleDegrees brakes a swing: stopping a swing with a catch angle does not settle it to rest; it swings on until it
// passes the catch angle and holds there, writing that angle to its node; restarting releases it and it swings again.
// Two swings of amplitude 30 run side by side: one caught at the amplitude's edge (-30, passed once per period) and one
// caught mid-amplitude (-15, passed twice per period, on the way out and on the way back). A spec whose catch angle lies
// outside its amplitude fails Validate(). Isolated Z band: -77000.
class UMars_AutoTest_Oscillator_BrakeCatchesAtCatchAngle : UCk_AutoTest_Base
{
    private FVector _Origin = FVector(0.0, 0.0, -77000.0);
    private FCk_Handle_Oscillator _Oscillator;
    private FCk_Handle_SceneNode _Pivot;
    private float32 _CatchAngle = -30.0f;

    private FCk_Handle_Oscillator _MidOscillator;
    private FCk_Handle_SceneNode _MidPivot;
    private float32 _MidCatchAngle = -15.0f;

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

        Add_Step("a catch angle beyond the amplitude is rejected", n"Step_AssertValidate");
        Add_Step_WaitSeconds("let them swing", 0.3f);
        Add_Step("brake them", n"Step_Stop");
        Add_Step_WaitUntil("the brake catches both", n"Check_Caught", 0, 3.0f);
        Add_Step("each is caught at its catch angle", n"Step_AssertAtCatchAngle");
        Add_Step_WaitSeconds("a caught swing holds", 0.3f);
        Add_Step("still caught, still at the catch angle, written to the node", n"Step_AssertHeld");
        Add_Step("release them", n"Step_Start");
        Add_Step_WaitUntil("released, each swings away from its catch angle", n"Check_SwingingAgain", 0, 3.0f);
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
