// A reach for an entity-built mechanism anchors to the part whose mesh carries the grip socket, not the object's root, so
// the glove follows that part when it moves on its own. Rig: a lever-shaped tree (root -> Mover node -> handle mesh node
// with the real LeverHandle_Mars_SM and its Grip socket); the Mover pitches the handle, the root stays put. The resolved
// world grip is compared with the component's live socket, before and after the move.
class UMars_AutoTest_FPHands_SocketGripFollowsMovingPart : UCk_AutoTest_Base
{
    private FCk_Handle _Root;
    private FCk_Handle_Mover _Mover;
    private FCk_Handle _MeshNode;
    private FMars_FPHands_Spec _Spec;
    private FMars_FPHands_ReachTarget _Target;
    private FVector _GripBeforeMove;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Root = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(_Root, FTransform(FRotator::ZeroRotator, FVector(200.0, 0.0, 0.0)), ECk_Replication::DoesNotReplicate);

        auto HandleNode = utils_scene_node::Create(Root, FTransform::Identity);
        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.EndRotation = FRotator(70.0, 0.0, 0.0);
        MoverSpec.Duration = 0.3f;
        _Mover = utils_mover::Add(HandleNode, MoverSpec);

        // Same placement as UMars_Lever_EntityScript: a scaled mesh node under the Mover node.
        auto HandleTransform = HandleNode.As_Transform();
        auto MeshNode = utils_scene_node::Create(HandleTransform, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 45.0), FVector(0.08, 0.08, 0.9)));
        _MeshNode = FCk_Handle(MeshNode);

        auto Mesh = Cast<UStaticMesh>(LoadObject(this, "/Game/Mars/Gameplay/Mechanisms/LeverHandle_Mars_SM.LeverHandle_Mars_SM"));
        if (ck::IsValid(Mesh))
        {
            auto Archetype = NewObject(this, UStaticMeshComponent);
            Archetype.SetMobility(EComponentMobility::Movable);
            Archetype.SetStaticMesh(Mesh);
            Archetype.SetCollisionProfileName(n"NoCollision");
            utils_unreal_component::Add(_MeshNode,
                utils_unreal_component::Make_Params_FromArchetype(Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, n"Test_LeverHandle"));
        }

        Add_Step("the lever handle mesh carries a Grip socket", n"Step_AssertMeshHasSocket");
        Add_Step_WaitUntil("the handle mesh component exists", n"Check_HasComponent", 0, 5.0f);
        Add_Step_WaitSeconds("let the component take the entity transform", 0.1f);
        Add_Step("resolve the reach: anchored to the mesh node, grip on the live socket", n"Step_ResolveAndAssert");
        Add_Step("pitch the handle part way", n"Step_MoveHandle");
        Add_Step_WaitSeconds("let the offset and the component follow", 0.2f);
        Add_Step("the refreshed grip is still on the live socket", n"Step_AssertFollows");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertMeshHasSocket(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Mesh = Cast<UStaticMesh>(LoadObject(this, "/Game/Mars/Gameplay/Mechanisms/LeverHandle_Mars_SM.LeverHandle_Mars_SM"));
        Assert_True(ck::IsValid(Mesh), "LeverHandle_Mars_SM loads");
        Assert_True(ck::IsValid(Mesh) && ck::IsValid(Mesh.FindSocket(n"Grip")), "LeverHandle_Mars_SM has a Grip socket");
    }

    UFUNCTION()
    private void Check_HasComponent(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(Get_HandleComponent()));
    }

    UFUNCTION()
    private void Step_ResolveAndAssert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Hand = FMars_FPHands_HandState(FMars_FPHands_Hold(), FTransform::Identity, true);
        const auto Subject = FMars_FPHands_ReachSubject(FCk_Handle_InteractTarget(), FCk_Handle_Interactable(), _Root);
        _Target = utils_fphands::Resolve_ReachTarget(_Spec.Reach, FMars_FPHands_ReachQuery(Subject, Hand));

        Assert_True(_Target.IsValid, "the reach resolves");
        Assert_True(_Target.Layout == EMars_FPHands_GripLayout::Authored, "the grip comes from the socket");
        Assert_True(FCk_Handle(_Target.Anchor) == _MeshNode, "the reach anchors to the mesh node that carries the socket, not the root");

        _GripBeforeMove = Get_ResolvedGrip();
        const auto Live = Get_LiveSocket();
        const auto Error = _GripBeforeMove.Distance(Live);
        Assert_True(Error < 0.5, f"the resolved grip is on the live socket before the move (off by {Error} cm)");
    }

    UFUNCTION()
    private void Step_MoveHandle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Mover.Request_Scrub(FMars_Request_Mover_Scrub(0.8f));
    }

    UFUNCTION()
    private void Step_AssertFollows(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_fphands::Update_ReachTarget(_Target);

        const auto Grip = Get_ResolvedGrip();
        const auto Live = Get_LiveSocket();
        const auto Moved = Grip.Distance(_GripBeforeMove);
        const auto Error = Grip.Distance(Live);
        Assert_True(Moved > 10.0, f"the handle's socket moved with the pitch (moved {Moved} cm)");
        Assert_True(Error < 0.5, f"the refreshed grip follows the live socket (off by {Error} cm)");
    }

    private FVector Get_ResolvedGrip()
    {
        auto Grip = FMars_FPHands_GripQuery(FTransform::Identity, true, FTransform::Identity);
        utils_fphands::Resolve_WorldGrip(_Spec, _Target, Grip);
        return Grip.WorldGrip.GetLocation();
    }

    private FVector Get_LiveSocket()
    {
        auto Component = Get_HandleComponent();
        if (ck::Is_NOT_Valid(Component))
        { return FVector::ZeroVector; }

        return Component.GetSocketTransform(n"Grip", ERelativeTransformSpace::RTS_World).GetLocation();
    }

    private UStaticMeshComponent Get_HandleComponent() const
    {
        const auto Components = utils_unreal_component::Get_ComponentsByType(_MeshNode, UStaticMeshComponent);
        if (Components.Num() == 0)
        { return nullptr; }

        return Cast<UStaticMeshComponent>(Components[0]);
    }
}
