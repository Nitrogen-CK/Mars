// A grip may be a socket on a skeletal mesh, read live: a grip-table entry names HarvestGrip_R on a scene node carrying the
// Screaming Turnip's presentation component (ScreamingTurnip_R01_Mars_SK through its anim blueprint) with a SocketRotation.
// The reach is resolved once and held. Moving the node, the composed grip is SocketRotation x the socket's world transform
// of that moment; posing the mesh instead (SRC_Tug scrubbed to 1 with a 100 cm runtime crown offset), the socket leaves the
// node and the grip goes with the socket, not the node. Logs the socket's bind-pose frame in the component (the crown's axes,
// which the bed's SocketRotation is authored in).
class UMars_AutoTest_FPHands_ASkeletalSocketGripIsResolvedLive : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 30.0f;

    private const int32 k_SlowPolls = 900;
    private const FVector k_RootLocation = FVector(700.0, 0.0, 0.0);
    private const FVector k_MovedOffset = FVector(0.0, 0.0, 40.0);
    private const float64 k_PoseMinShiftCm = 50.0;

    private FCk_Handle _Owner;
    private FCk_Handle_SceneNode _Node;
    private UMars_ScreamingTurnipPresentationComponent _Presentation;
    private FMars_FPHands_Spec _Spec;
    private FQuat _SocketRotation;
    private TOptional<FMars_FPHands_ReachTarget> _Target;
    private FVector _SocketBeforePose;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Owner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(_Owner, FTransform(FRotator::ZeroRotator, k_RootLocation), ECk_Replication::DoesNotReplicate);
        _Node = utils_scene_node::Create(Root, FTransform::Identity);

        const auto Params = utils_unreal_component::Make_Params(UMars_ScreamingTurnipPresentationComponent,
            ECk_UnrealComponent_TickPolicy::TickViaProcessor, n"Test_SkeletalSocketGrip");
        auto Component = utils_unreal_component::Add(_Node.H(), Params);
        utils_unreal_component::BindTo_OnAdded(Component, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPresentationAdded"));

        _SocketRotation = utils_fphands::Make_GripRotation(EMars_Hand::Right, FVector::ForwardVector, -FVector::RightVector);
        auto Entries = TArray<FMars_FPHands_GripEntry>();
        Entries.Add(FMars_FPHands_GripEntry(EMars_Hand::Right, _Node.As_Transform(),
            TOptional<FName>(constants_screaming_turnip_assets::k_HarvestGripSocket_R), EMars_HandGripPose::Power,
            TOptional<float32>(), EMars_FPHands_GripFrame::Aimed, EMars_FPHands_GripRoll::Fixed, TOptional<FQuat>(_SocketRotation)));
        utils_fphands::Add_Grips(_Owner, Entries);

        Add_Step_WaitUntil("the skeletal mesh is on the node and carries HarvestGrip_R", n"Check_MeshReady", k_SlowPolls, 0);
        Add_Step("resolve the reach once: bound to the socket on the mesh component", n"Step_Resolve");
        Add_Step("move the node 40 cm up", n"Step_MoveNode");
        Add_Step_WaitUntil("the node and its mesh moved", n"Check_NodeMoved", k_SlowPolls, 0);
        Add_Step("the grip is SocketRotation x the live socket", n"Step_AssertOnSocket");
        Add_Step("pose the mesh: Tug at 1 with a 100 cm crown offset", n"Step_Pose");
        Add_Step_WaitUntil("the socket left the node with the pose", n"Check_Posed", k_SlowPolls, 0);
        Add_Step("the grip follows the socket, not the node", n"Step_AssertFollowsPose");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnPresentationAdded(FCk_Handle_UnrealComponent InHandle)
    {
        _Presentation = Cast<UMars_ScreamingTurnipPresentationComponent>(utils_unreal_component::Get_Component(InHandle));
    }

    UFUNCTION()
    private void Check_MeshReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Presentation) && _Presentation.Get_HasMesh()
            && _Presentation.DoesSocketExist(constants_screaming_turnip_assets::k_HarvestGripSocket_R));
    }

    UFUNCTION()
    private void Step_Resolve(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Local = _Presentation.GetSocketTransform(constants_screaming_turnip_assets::k_HarvestGripSocket_R, ERelativeTransformSpace::RTS_Component);
        Log(f"[ASkeletalSocketGripIsResolvedLive] HarvestGrip_R in the component at bind: location {Local.GetLocation().ToString()}, rotation {Local.GetRotation().Rotator().ToString()}");

        const auto Hand = FMars_FPHands_HandState(FMars_FPHands_Hold(), FTransform::Identity, EMars_Hand::Right);
        const auto Subject = FMars_FPHands_ReachSubject(FCk_Handle_Interactable(), _Owner);
        _Target = utils_fphands::Resolve_ReachTarget(_Spec.Reach, FMars_FPHands_ReachQuery(Subject, Hand));
        Assert_True(utils_fphands::Get_UsesHand(_Target, EMars_Hand::Right), "the reach resolves with the right glove");
        if (utils_fphands::Get_UsesHand(_Target, EMars_Hand::Right) == false)
        { return; }

        const auto Grip = _Target.GetValue().Right.GetValue();
        Assert_True(ck::IsValid(Grip.SocketHost), "the grip is bound to the mesh component");
        Assert_True(Grip.Socket == constants_screaming_turnip_assets::k_HarvestGripSocket_R, f"on HarvestGrip_R (got {Grip.Socket})");
        Assert_True(Grip.IsAuthored, "a socket grip is authored");
        Assert_True(Grip.Grip.GetRotation().Equals(_SocketRotation, 0.0001) && Grip.Grip.GetLocation().IsNearlyZero(0.0001),
            "the grip is the SocketRotation in the socket's frame");
    }

    UFUNCTION()
    private void Step_MoveNode(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_scene_node::Request_UpdateOffset(_Node, FCk_Request_SceneNode_UpdateRelativeTransform(FTransform(FRotator::ZeroRotator, k_MovedOffset)));
    }

    UFUNCTION()
    private void Check_NodeMoved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto NodeWorld = utils_transform::Get_EntityCurrentTransform(_Node.As_Transform()).GetLocation();
        auto Res = OutResult;
        Res.Set(NodeWorld.Equals(k_RootLocation + k_MovedOffset, 0.01) && _Presentation.GetWorldLocation().Equals(NodeWorld, 0.01));
    }

    UFUNCTION()
    private void Step_AssertOnSocket(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Composed("after the node moved");
        _SocketBeforePose = Get_SocketWorld().GetLocation();
    }

    // Stretch alpha follows the clip on screen: SRC_Tug scrubbed to 1 draws the full crown offset; no Control drives it.
    UFUNCTION()
    private void Step_Pose(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Presentation.Set_PullDrawing(FMars_ScreamingTurnip_PullDrawing(FCk_Handle_Control(), 100.0f, 10.0f));
        _Presentation.Scrub_Clip(FMars_ScreamingTurnip_PresentationClip(constants_screaming_turnip_assets::k_Clip_Tug,
            EMars_ScreamingTurnip_ClipEnd::HoldLastFrame), 1.0f);
    }

    UFUNCTION()
    private void Check_Posed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_SocketWorld().GetLocation().Distance(_SocketBeforePose) > k_PoseMinShiftCm);
    }

    UFUNCTION()
    private void Step_AssertFollowsPose(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto NodeWorld = utils_transform::Get_EntityCurrentTransform(_Node.As_Transform()).GetLocation();
        Assert_True(NodeWorld.Equals(k_RootLocation + k_MovedOffset, 0.01), "the node did not move with the pose");
        Assert_Composed("after the pose moved the socket");
    }

    private void Assert_Composed(const FString& InWhen)
    {
        if (utils_fphands::Get_UsesHand(_Target, EMars_Hand::Right) == false)
        {
            FinishFailure("no resolved target to compose");
            return;
        }

        auto Query = FMars_FPHands_GripQuery(FTransform::Identity, EMars_Hand::Right, FTransform::Identity);
        utils_fphands::Resolve_WorldGrip(_Spec, _Target.GetValue(), Query);
        const auto Expected = FTransform(_SocketRotation, FVector::ZeroVector, FVector::OneVector) * Get_SocketWorld();
        const auto Error = Query.WorldGrip.GetLocation().Distance(Expected.GetLocation());
        Assert_True(Error <= 0.01, f"{InWhen}: the grip is on the live socket (off by {Error} cm)");
        Assert_True(Query.WorldGrip.GetRotation().Equals(Expected.GetRotation(), 0.0001),
            f"{InWhen}: the grip's rotation is SocketRotation in the live socket's frame");
    }

    private FTransform Get_SocketWorld() const
    {
        return _Presentation.GetSocketTransform(constants_screaming_turnip_assets::k_HarvestGripSocket_R, ERelativeTransformSpace::RTS_World);
    }
}
