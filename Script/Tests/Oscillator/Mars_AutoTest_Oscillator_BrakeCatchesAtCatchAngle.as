// CatchAngleDegrees, the Censer's Window brake: stopping a swing with a catch angle does not settle it to rest; it swings on
// until it passes the catch angle and holds there, writing that angle to its node; restarting releases it and it swings
// again. A spec whose catch angle lies outside its amplitude fails Validate(). Isolated Z band: -77000.
class UMars_AutoTest_Oscillator_BrakeCatchesAtCatchAngle : UCk_AutoTest_Base
{
    private FVector _Origin = FVector(0.0, 0.0, -77000.0);
    private FCk_Handle_Oscillator _Oscillator;
    private FCk_Handle_SceneNode _Pivot;
    private float32 _CatchAngle = -30.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, _Origin), ECk_Replication::DoesNotReplicate);
        _Pivot = utils_scene_node::Create(Root, FTransform::Identity);

        _Oscillator = utils_oscillator::Add(_Pivot, MakeSpec());

        Add_Step("a catch angle beyond the amplitude is rejected", n"Step_AssertValidate");
        Add_Step_WaitSeconds("let it swing", 0.3f);
        Add_Step("brake it", n"Step_Stop");
        Add_Step_WaitUntil("the brake catches it", n"Check_Caught", 0, 3.0f);
        Add_Step("caught at the catch angle", n"Step_AssertAtCatchAngle");
        Add_Step_WaitSeconds("a caught swing holds", 0.3f);
        Add_Step("still caught, still at the catch angle, written to the node", n"Step_AssertHeld");
        Add_Step("release it", n"Step_Start");
        Add_Step_WaitUntil("released, it swings away from the catch angle", n"Check_SwingingAgain", 0, 3.0f);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertValidate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Oscillator), "utils_oscillator::Add accepted a catch angle within the amplitude");
        Assert_True(MakeSpec().Validate().IsValid, "a catch angle within the amplitude validates");

        auto Wide = MakeSpec();
        Wide.CatchAngleDegrees = TOptional<float32>(45.0f);
        Assert_False(Wide.Validate().IsValid, "a catch angle beyond the amplitude does not validate");
    }

    UFUNCTION()
    private void Step_Stop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Oscillator.Request_SetRunning(false);
    }

    UFUNCTION()
    private void Check_Caught(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Oscillator.Get_IsCaught());
    }

    UFUNCTION()
    private void Step_AssertAtCatchAngle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Oscillator.Get_IsRunning(), "a caught swing is stopped");
        Assert_Equals_Float(_Oscillator.Get_Angle(), _CatchAngle, 0.5, "caught at the catch angle");
    }

    UFUNCTION()
    private void Step_AssertHeld(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Oscillator.Get_IsCaught(), "a caught swing stays caught while stopped");
        Assert_Equals_Float(_Oscillator.Get_Angle(), _CatchAngle, 0.5, "a caught swing does not drift");
        Assert_Equals_Float(utils_scene_node::Get_Offset_Rotation(_Pivot).Pitch, _CatchAngle, 0.5,
            "the node shows the catch angle (pitch axis, zero rest rotation)");
    }

    UFUNCTION()
    private void Step_Start(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Oscillator.Request_SetRunning(true);
    }

    UFUNCTION()
    private void Check_SwingingAgain(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Oscillator.Get_IsCaught() == false && Math::Abs(_Oscillator.Get_Angle() - _CatchAngle) > 5.0f);
    }

    private FMars_Oscillator_Spec MakeSpec() const
    {
        auto Spec = FMars_Oscillator_Spec();
        Spec.AmplitudeDegrees = 30.0f;
        Spec.PeriodSeconds = 1.0f;
        Spec.SettleSeconds = 0.2f;
        Spec.StartRunning = true;
        Spec.CatchAngleDegrees = TOptional<float32>(_CatchAngle);
        return Spec;
    }
}
