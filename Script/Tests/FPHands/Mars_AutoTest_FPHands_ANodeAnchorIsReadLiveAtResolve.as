// A grip's anchor is read when the grip is composed, not from the copy the reach target cached: a grip-table reach on a
// node is resolved once and held (nothing refreshes its AnchorWorld); the node is then moved 30 cm and, with the cached
// world still the old place, utils_fphands::Resolve_WorldGrip puts the grip on the node's new place. Once the node is
// destroyed, the grip falls back to the last known world (refreshed before the destroy), with no ensure.
class UMars_AutoTest_FPHands_ANodeAnchorIsReadLiveAtResolve : UCk_AutoTest_Base
{
    private const FVector k_Offset = FVector(0.0, 15.0, 0.0);
    private const FVector k_MovedOffset = FVector(0.0, 15.0, -30.0);

    private FCk_Handle _Owner;
    private FCk_Handle_SceneNode _Node;
    private FMars_FPHands_Spec _Spec;
    private TOptional<FMars_FPHands_ReachTarget> _Target;
    private FVector _CachedBeforeMove;
    private FVector _LastKnown;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Owner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(_Owner, FTransform(FRotator::ZeroRotator, FVector(300.0, 0.0, 0.0)), ECk_Replication::DoesNotReplicate);
        _Node = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, k_Offset));

        auto Entries = TArray<FMars_FPHands_GripEntry>();
        Entries.Add(FMars_FPHands_GripEntry(EMars_Hand::Right, _Node.As_Transform(), TOptional<FName>(), EMars_HandGripPose::Power,
            TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
        utils_fphands::Add_Grips(_Owner, Entries);

        Add_Step_WaitUntil("the node stands at its offset", n"Check_NodePlaced", 0, 0);
        Add_Step("resolve the grip-table reach once and hold it", n"Step_Resolve");
        Add_Step("move the node 30 cm down", n"Step_MoveNode");
        Add_Step_WaitUntil("the node has moved", n"Check_NodeMoved", 0, 0);
        Add_Step("the held target's cached world is old, the composed grip is on the moved node", n"Step_AssertLive");
        Add_Step("refresh the cache, then destroy the node", n"Step_RefreshAndDestroy");
        Add_Step_WaitUntil("the node is gone", n"Check_NodeGone", 0, 0);
        Add_Step("the grip falls back to the last known world", n"Step_AssertFallback");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_NodePlaced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_NodeWorld().Equals(FVector(300.0, 0.0, 0.0) + k_Offset, 0.01));
    }

    UFUNCTION()
    private void Step_Resolve(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Hand = FMars_FPHands_HandState(FMars_FPHands_Hold(), FTransform::Identity, EMars_Hand::Right);
        const auto Subject = FMars_FPHands_ReachSubject(FCk_Handle_Interactable(), _Owner);
        _Target = utils_fphands::Resolve_ReachTarget(_Spec.Reach, FMars_FPHands_ReachQuery(Subject, Hand));
        Assert_True(utils_fphands::Get_UsesHand(_Target, EMars_Hand::Right), "the reach resolves with the right glove");
        if (utils_fphands::Get_UsesHand(_Target, EMars_Hand::Right))
        { _CachedBeforeMove = _Target.GetValue().Right.GetValue().AnchorWorld.GetLocation(); }
    }

    UFUNCTION()
    private void Step_MoveNode(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_scene_node::Request_UpdateOffset(_Node, FCk_Request_SceneNode_UpdateRelativeTransform(FTransform(FRotator::ZeroRotator, k_MovedOffset)));
    }

    UFUNCTION()
    private void Check_NodeMoved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_NodeWorld().Equals(FVector(300.0, 0.0, 0.0) + k_MovedOffset, 0.01));
    }

    UFUNCTION()
    private void Step_AssertLive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (utils_fphands::Get_UsesHand(_Target, EMars_Hand::Right) == false)
        {
            FinishFailure("no resolved target to compose");
            return;
        }

        const auto Cached = _Target.GetValue().Right.GetValue().AnchorWorld.GetLocation();
        Assert_True(Cached.Equals(_CachedBeforeMove, 0.001), "nothing refreshed the held target's cached AnchorWorld");

        const auto Grip = Compose();
        const auto Error = Grip.Distance(Get_NodeWorld());
        Assert_True(Error <= 0.01, f"the composed grip is on the node's new place (off by {Error} cm)");
        Assert_True(Grip.Distance(Cached) > 29.0, f"not on the cached old place ({Grip.Distance(Cached)} cm from it)");
    }

    UFUNCTION()
    private void Step_RefreshAndDestroy(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_fphands::Update_ReachTarget(_Target);
        _LastKnown = _Target.GetValue().Right.GetValue().AnchorWorld.GetLocation();
        utils_entity_lifetime::Request_DestroyEntity(_Node.H());
    }

    UFUNCTION()
    private void Check_NodeGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_Node));
    }

    UFUNCTION()
    private void Step_AssertFallback(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Grip = Compose();
        const auto Error = Grip.Distance(_LastKnown);
        Assert_True(_LastKnown.Equals(FVector(300.0, 0.0, 0.0) + k_MovedOffset, 0.01), "the refresh cached the moved place");
        Assert_True(Error <= 0.01, f"the grip of a destroyed anchor is its last known world (off by {Error} cm)");
    }

    private FVector Compose()
    {
        auto Grip = FMars_FPHands_GripQuery(FTransform::Identity, EMars_Hand::Right, FTransform::Identity);
        utils_fphands::Resolve_WorldGrip(_Spec, _Target.GetValue(), Grip);
        return Grip.WorldGrip.GetLocation();
    }

    private FVector Get_NodeWorld() const
    {
        return utils_transform::Get_EntityCurrentTransform(_Node.As_Transform()).GetLocation();
    }
}
