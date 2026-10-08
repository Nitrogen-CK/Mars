// A per-glove pose override plays only while that glove is on a reach target. Left overridden to Cradle: at rest the left
// glove keeps its rest pose; during a bare (right-only) timed reach it still does; on an owner's grip table that uses both
// gloves the left plays Cradle (the right keeps its entry's Power). The phase returning to None clears the override. Beside
// the hands rig: an owner root with a right and a left grip node, and a transform-only interactable.
class UMars_AutoTest_FPHands_PoseOverrideAppliesOnlyWhileReaching : UMars_AutoTestRig_Hands
{
    default _TimeoutSeconds = 8.0f;

    private FCk_Handle _Owner;
    private FCk_Handle_Interactable _Interactable;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_FPHands_Spec();
        Spec.Reach.Hold.ReachSeconds = 0.1f;
        Add_Hands(InHandle, Spec);
        BuildOwner(InHandle);
        Add_HandsSm();

        Add_Step_WaitUntil("the Hands SM rests in Rest, listening for a reach", n"Check_RestListening", 0, 5.0f);
        Add_Step("override the left glove to Cradle", n"Step_OverrideLeft");
        Add_Step_WaitFrames("the override drains", 2);
        Add_Step("at rest the left glove keeps its rest pose", n"Step_AssertLeftAtRest");
        Add_Step("request a bare timed reach (right only)", n"Step_RequestTimedReach");
        Add_Step_WaitUntil("the phase is Hold", n"Check_IsHold", 0, 5.0f);
        Add_Step_WaitSeconds("the reach completes", 0.2f);
        Add_Step("the left glove is not on the target: its pose is unchanged", n"Step_AssertLeftAtRest");
        Add_Step("let go", n"Step_RequestRelease");
        Add_Step_WaitUntil("the gloves are back at rest", n"Check_IsNone", 0, 5.0f);
        Add_Step("the return to None cleared the override", n"Step_AssertCleared");
        Add_Step_WaitUntil("the Hands SM listens again", n"Check_RestListening", 0, 5.0f);
        Add_Step("override the left glove to Cradle again; reach for the owner's grip table", n"Step_OverrideAndReachForOwner");
        Add_Step_WaitUntil("the phase is Hold", n"Check_IsHold", 0, 5.0f);
        Add_Step_WaitSeconds("the reach completes", 0.2f);
        Add_Step("the left glove plays Cradle, the right its own Power", n"Step_AssertLeftCradle");
        Add_Step("let go", n"Step_RequestRelease");
        Add_Step_WaitUntil("the gloves are back at rest", n"Check_IsNone", 0, 5.0f);
        Add_Step("the return to None cleared the override", n"Step_AssertCleared");
        Run_Steps(InHandle);
    }

    private void BuildOwner(FCk_Handle InHandle)
    {
        _Owner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(_Owner, FTransform(FRotator::ZeroRotator, FVector(100.0, 0.0, 0.0)), ECk_Replication::DoesNotReplicate);

        auto NodeR = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(0.0, 15.0, 0.0))).As_Transform();
        auto NodeL = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(0.0, -15.0, 0.0))).As_Transform();

        auto Entries = TArray<FMars_FPHands_GripEntry>();
        Entries.Add(FMars_FPHands_GripEntry(EMars_Hand::Right, NodeR, TOptional<FName>(), EMars_HandGripPose::Power, TOptional<float32>(), EMars_FPHands_GripFrame::Aimed, EMars_FPHands_GripRoll::Fixed));
        Entries.Add(FMars_FPHands_GripEntry(EMars_Hand::Left, NodeL, TOptional<FName>(), EMars_HandGripPose::Open, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
        utils_fphands::Add_Grips(_Owner, Entries);

        _Interactable = utils_interactable::Create(Root, FMars_Interactable_Spec());
    }

    private FMars_FPHands_HandTargets Get_Targets()
    {
        const auto HandWorld = utils_transform::Get_EntityCurrentTransform(_Hands.Get_HandNode());
        auto Targets = FMars_FPHands_HandTargets();
        _Hands.Get_HandTargets(FMars_FPHands_TargetFrame(HandWorld, FVector::ZeroVector, FVector::ZeroVector), Targets);
        return Targets;
    }

    private void Override_Left()
    {
        _Hands.Request_SetPoseOverride(FMars_Request_FPHands_SetPoseOverride(EMars_Hand::Left, TOptional<EMars_HandGripPose>(EMars_HandGripPose::Cradle)));
    }

    UFUNCTION()
    private void Step_OverrideLeft(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Override_Left();
    }

    UFUNCTION()
    private void Step_AssertLeftAtRest(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Override = _Hands.TryGet_PoseOverride(EMars_Hand::Left);
        Assert_True(Override.IsSet() && Override.GetValue() == EMars_HandGripPose::Cradle, "the left override is stored");
        Assert_False(_Hands.Get_IsReaching(EMars_Hand::Left), "the left glove is on no reach target");

        const auto Targets = Get_Targets();
        Assert_True(Targets.Left.Pose == EMars_HandGripPose::Relaxed, f"the left glove keeps its rest pose (got {Targets.Left.Pose :n})");
    }

    UFUNCTION()
    private void Check_IsNone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::None);
    }

    UFUNCTION()
    private void Step_AssertCleared(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Hands.TryGet_PoseOverride(EMars_Hand::Left).IsSet(), "the left override is cleared");
        Assert_False(_Hands.TryGet_PoseOverride(EMars_Hand::Right).IsSet(), "no right override");
        Assert_True(Get_Targets().Left.Pose == EMars_HandGripPose::Relaxed, "the left glove is back to its rest pose");
    }

    UFUNCTION()
    private void Step_OverrideAndReachForOwner(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Override_Left();
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(FMars_FPHands_ReachSubject(_Interactable, _Owner), ECk_Interaction_CompletionPolicy::Timed));
    }

    UFUNCTION()
    private void Step_AssertLeftCradle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hands.Get_IsReaching(EMars_Hand::Left), "the left glove is on the owner's target");
        Assert_True(_Hands.Get_IsReaching(EMars_Hand::Right), "the right glove is on the owner's target");

        const auto Targets = Get_Targets();
        Assert_True(Targets.Left.Pose == EMars_HandGripPose::Cradle, f"the left glove plays its override (got {Targets.Left.Pose :n})");
        Assert_True(Targets.Right.Pose == EMars_HandGripPose::Power, f"the right glove plays its entry's Power (got {Targets.Right.Pose :n})");
    }
}
