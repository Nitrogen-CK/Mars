// A cancel mid-windup turns the swing into its recovery from where the hand is: the arc's Strike key becomes the current
// pose, the clock jumps to the strike's end, the phase is Recover, and the hand eases home from there (no jump: right
// after the cancel the pose is no further from rest than it was) until the swing is None with an identity pose. A
// cancel at rest changes nothing. Isolated Z band: -84000.
class UMars_AutoTest_HandSwing_CancelRecoversFromTheCurrentPose : UCk_AutoTest_Base
{
    private FVector _Origin = FVector(100.0, 0.0, -84000.0);
    private FCk_Handle_HandSwing _Swing;
    private FCk_Handle_SceneNode _Node;
    private FTransform _PoseAtCancel;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, _Origin), ECk_Replication::DoesNotReplicate);
        _Node = utils_scene_node::Create(Root, FTransform::Identity);
        _Swing = utils_hand_swing::Add(Entity, FMars_HandSwing_Spec(_Node));

        Add_Step("a cancel at rest is ignored", n"Step_CancelAtRest");
        Add_Step_WaitSeconds("let the drain run", 0.1f);
        Add_Step("still at rest", n"Step_AssertStillAtRest");
        Add_Step("start a slow swing", n"Step_Start");
        Add_Step_WaitUntil("well into the windup", n"Check_IntoWindup", 0, 2.0f);
        Add_Step("cancel", n"Step_Cancel");
        Add_Step_WaitUntil("recovering", n"Check_Recovering", 0, 1.0f);
        Add_Step("the recovery leaves from the cancelled pose", n"Step_AssertRecoveringFromPose");
        Add_Step_WaitUntil("back at rest", n"Check_AtRest", 0, 3.0f);
        Add_Step("at rest with an identity pose", n"Step_AssertAtRest");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_CancelAtRest(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Swing.Request_Cancel();
    }

    UFUNCTION()
    private void Step_AssertStillAtRest(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Swing.Get_IsSwinging(), "a cancel at rest leaves the swing at rest");
        Assert_True(_Swing.Get_Pose().Equals(FTransform::Identity), "a cancel at rest leaves the pose identity");
    }

    UFUNCTION()
    private void Step_Start(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Swing.Request_Start(FMars_Request_HandSwing_Start(MakeArc(), 2.0f, 0.5f));
    }

    UFUNCTION()
    private void Check_IntoWindup(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Swing.Get_Phase() == EMars_HandSwing_Phase::Windup && _Swing.Get_Elapsed() > 0.3f);
    }

    UFUNCTION()
    private void Step_Cancel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _PoseAtCancel = _Swing.Get_Pose();
        Assert_True(_PoseAtCancel.Equals(FTransform::Identity, 0.01) == false, "the hand had left rest before the cancel");
        _Swing.Request_Cancel();
    }

    UFUNCTION()
    private void Check_Recovering(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Swing.Get_Phase() == EMars_HandSwing_Phase::Recover);
    }

    // The cancel may land a frame after the pose was read, so the strike key is within one slow windup frame of it.
    UFUNCTION()
    private void Step_AssertRecoveringFromPose(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Timeline = _Swing.Get_Timeline();
        Assert_True(_Swing.Get_Elapsed() >= Timeline.StrikeEnd, "the clock jumped to the strike's end");
        Assert_True(_Swing.Get_Elapsed() < Timeline.RecoverEnd, "the clock is within the recovery");

        const auto StrikeKey = _Swing.Get_Arc().Strike;
        Assert_True(StrikeKey.Location.Equals(_PoseAtCancel.GetLocation(), 2.0),
            f"the strike key became the cancelled pose (key [{StrikeKey.Location}], pose [{_PoseAtCancel.GetLocation()}])");
        Assert_True(_Swing.Get_Pose().GetLocation().Size() <= _PoseAtCancel.GetLocation().Size() + 2.0,
            f"the recovery heads home from the cancelled pose (now [{_Swing.Get_Pose().GetLocation()}], cancelled at [{_PoseAtCancel.GetLocation()}])");
    }

    UFUNCTION()
    private void Check_AtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Swing.Get_IsSwinging() == false);
    }

    UFUNCTION()
    private void Step_AssertAtRest(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Swing.Get_Pose().Equals(FTransform::Identity, 0.001), f"at rest the pose is identity (got [{_Swing.Get_Pose()}])");
        Assert_True(utils_scene_node::Get_Offset(_Node).Equals(FTransform::Identity, 0.001), "at rest the node is back at identity");
    }

    // A long linear windup (the hand moves about 1 cm per frame at 20 fps), so the cancel's pose is well defined.
    private FMars_HandSwing_Arc MakeArc() const
    {
        auto Arc = FMars_HandSwing_Arc();
        Arc.Windup = FMars_HandSwing_Key(FVector(-10.0, 5.0, 20.0), FRotator(30.0, 0.0, 0.0), ECk_TweenEasing::Linear);
        Arc.Strike = FMars_HandSwing_Key(FVector(15.0, -5.0, -15.0), FRotator(-50.0, 0.0, 0.0), ECk_TweenEasing::InQuad);
        Arc.RecoverEasing = ECk_TweenEasing::Linear;
        Arc.StrikeSeconds = 0.3f;
        return Arc;
    }
}
