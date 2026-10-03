// An owner's grip table gives each glove its own anchor: a timed reach for an interactable whose owner declares a right
// grip on node R and a left grip on node L holds with the right glove anchored to R and the left to L, each with its own
// pose. R rides a Mover; when it moves, only the right glove's anchor follows. Rig: hands + Hands SM on the test entity,
// and an owner root with the two nodes, the grip table and a transform-only interactable (no targets: the reach is
// requested directly).
class UMars_AutoTest_FPHands_GripTableGivesEachHandItsOwnAnchor : UCk_AutoTest_Base
{
    private FCk_Handle_FPHands _Hands;
    private FCk_Handle_StateMachine _Sm;
    private FCk_Handle _Player;
    private FCk_Handle _Owner;
    private FCk_Handle_Interactable _Interactable;
    private FCk_Handle_Transform _NodeR;
    private FCk_Handle_Transform _NodeL;
    private FCk_Handle_Mover _MoverR;
    private FTransform _RightBeforeMove;
    private FTransform _LeftBeforeMove;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Player = InHandle;
        auto HandRootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto HandRoot = utils_transform::Add(HandRootEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        auto HandNode = utils_scene_node::Create(HandRoot, FTransform::Identity);

        auto Spec = FMars_FPHands_Spec();
        Spec.Reach.HoldReachSeconds = 0.1f;
        _Hands = utils_fphands::Add(_Player, Spec, HandNode.As_Transform());
        BuildOwner(InHandle);
        _Sm = utils_state_machine::Add(_Player, FCk_StateMachine_Spec(UMars_SmState_Hands_Rest));

        Add_Step_WaitUntil("the Hands SM rests in Rest, listening for a reach", n"Check_RestListening", 0, 5.0f);
        Add_Step("request a timed reach for the owner's interactable", n"Step_RequestTimedReach");
        Add_Step_WaitUntil("the phase is Hold", n"Check_IsHold", 0, 5.0f);
        Add_Step("each glove has its own anchor, both are used, the left takes its own pose", n"Step_AssertPerHandAnchors");
        Add_Step("move node R to the Mover's end", n"Step_MoveR");
        Add_Step_WaitUntil("the Mover reached its end", n"Check_MoverAtEnd", 0, 5.0f);
        Add_Step_WaitSeconds("let the offset and the anchors refresh", 0.1f);
        Add_Step("the right anchor moved down 20, the left did not move", n"Step_AssertOnlyRightFollows");
        Run_Steps(InHandle);
    }

    private void BuildOwner(FCk_Handle InHandle)
    {
        _Owner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(_Owner, FTransform(FRotator::ZeroRotator, FVector(100.0, 0.0, 0.0)), ECk_Replication::DoesNotReplicate);

        auto NodeR = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(0.0, 15.0, 0.0)));
        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.StartLocation = FVector(0.0, 15.0, 0.0);
        MoverSpec.EndLocation = FVector(0.0, 15.0, -20.0);
        MoverSpec.Duration = 0.05f;
        _MoverR = utils_mover::Add(NodeR, MoverSpec);
        _NodeR = NodeR.As_Transform();
        _NodeL = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(0.0, -15.0, 0.0))).As_Transform();

        auto Entries = TArray<FMars_FPHands_GripEntry>();
        Entries.Add(FMars_FPHands_GripEntry(EMars_Hand::Right, _NodeR, NAME_None, EMars_HandGripPose::Power, TOptional<float32>(), EMars_FPHands_GripFrame::Aimed, EMars_FPHands_GripRoll::Fixed));
        Entries.Add(FMars_FPHands_GripEntry(EMars_Hand::Left, _NodeL, NAME_None, EMars_HandGripPose::Open, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
        utils_fphands::Add_Grips(_Owner, Entries);

        _Interactable = utils_interactable::Create(Root, FMars_Interactable_Spec());
    }

    UFUNCTION()
    private void Check_RestListening(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::Get_CurrentStateClass(_Sm) == UMars_SmState_Hands_Rest
            && _Hands.Has_Fragment(FMars_Fragment_FPHands_Signals)
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachRequested._Inner.IsBound());
    }

    UFUNCTION()
    private void Step_RequestTimedReach(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(FCk_Handle_InteractTarget(), _Interactable, _Owner, false));
    }

    UFUNCTION()
    private void Check_IsHold(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Hold);
    }

    UFUNCTION()
    private void Step_AssertPerHandAnchors(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Target = _Hands.Get_Target();
        Assert_True(Target.IsValid, "the reach resolves");
        Assert_True(Target.Right.IsUsed, "the right glove is used");
        Assert_True(Target.Left.IsUsed, "the left glove is used");
        Assert_True(FCk_Handle(Target.Right.Anchor) == FCk_Handle(_NodeR), "the right glove anchors to node R");
        Assert_True(FCk_Handle(Target.Left.Anchor) == FCk_Handle(_NodeL), "the left glove anchors to node L");
        Assert_True(Target.Left.HasPose && Target.Left.Pose == EMars_HandGripPose::Open, "the left glove takes its entry's Open pose");
        Assert_True(Target.Right.HasPose && Target.Right.Pose == EMars_HandGripPose::Power, "the right glove takes its entry's Power pose");
        Assert_True(Target.Left.IsAuthored, "a socketless entry that uses its node frame is an authored grip");
        Assert_False(Target.Right.IsAuthored, "a socketless entry without it stays a point grip");

        _RightBeforeMove = Target.Right.AnchorWorld;
        _LeftBeforeMove = Target.Left.AnchorWorld;
    }

    UFUNCTION()
    private void Step_MoveR(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _MoverR.Request_MoveTo(true);
    }

    UFUNCTION()
    private void Check_MoverAtEnd(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_MoverR.Get_AtEnd() && _MoverR.Get_Alpha() >= 0.999f);
    }

    UFUNCTION()
    private void Step_AssertOnlyRightFollows(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Target = _Hands.Get_Target();
        Assert_True(_Hands.Get_Phase() == EMars_FPHands_Phase::Hold, "the gloves still hold");

        const auto RightDeltaZ = Target.Right.AnchorWorld.GetLocation().Z - _RightBeforeMove.GetLocation().Z;
        Assert_True(Math::Abs(RightDeltaZ + 20.0) <= 0.5, f"the right anchor moved down 20 with node R (moved {RightDeltaZ})");

        const auto LeftMoved = Target.Left.AnchorWorld.GetLocation().Distance(_LeftBeforeMove.GetLocation());
        Assert_True(LeftMoved <= 0.01, f"the left anchor did not move (moved {LeftMoved})");
    }
}
