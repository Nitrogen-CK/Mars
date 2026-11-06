// A socket-authored item's grips are its world item's grip nodes, and the gloves' hold and reach read them with the
// results the old socket path gave. The Cleaver (MeatCleaver_Mars_SM: Grip_R / Grip_L, SocketTwist_R -25, _L -60, an
// upright HeldOffset) lies on a static floor as a World-mode world item:
// - it carries a grip table of two nodes whose offsets from the root (and, at rest, world transforms) are the asset's
//   sockets turned by the twists;
// - utils_fphands::Make_Hold gives the socket grips and kind captured from the old path (Find_MeshSockets in Make_Hold,
//   2026-11-06, before the grip-point change) within 0.001;
// - an empty-handed reach is an Authored pickup anchored to the root whose grips sit where the old path put them; their
//   rotations now carry the twist the hold always had (the old reach used the untwisted socket, so the gloves turned
//   between reach and hold): the old reach grips turned by the twists, within 0.001.
// Isolated origin (197000, -93300, -30000).
class UMars_AutoTest_WorldItem_MeshSocketsBecomeGripPoints : UMars_AutoTestRig_Hands
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(197000.0, -93300.0, -30000.0);
    private const float k_RestSpeed = 1.0;
    private const int32 k_RestPolls = 10;

    // Captured from the old path (Test-TurnipE-Capture, Saved/Logs/Mars_2.log, 2026-11-06 07:16).
    private const FTransform k_OldSocketGrip_R = FTransform(FQuat(0.365525, -0.516709, 0.382345, 0.673213), FVector(-4.0, 22.0, -14.0));
    private const FTransform k_OldSocketGrip_L = FTransform(FQuat(0.146168, -0.607768, 0.209271, 0.751970), FVector(-1.568925, 23.918822, -0.346869));
    private const FTransform k_OldReachGrip_R = FTransform(FQuat(0.707107, 0.0, 0.0, 0.707107), FVector(0.0, 0.0, 0.0));
    private const FTransform k_OldReachGrip_L = FTransform(FQuat(0.707107, 0.0, 0.0, 0.707107), FVector(14.0, 0.0, 0.0));

    private FCk_Handle _CleaverEntity;
    private FCk_Handle_WorldItem _Cleaver;
    private int32 _RestCount = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Owner = InHandle;
        Add_StaticBox(Owner, k_Origin - FVector(0.0, 0.0, 1.0), FVector(80.0, 80.0, 1.0));
        _CleaverEntity = utils_world_item::Request_SpawnWorld(Owner, FMars_WorldItem_WorldSpec(
            utils_held_item::Make_DefinitionSoft(mars_items::Cleaver()), FTransform(FRotator(0.0, 30.0, 0.0), k_Origin + FVector(0.0, 0.0, 10.0))));

        Add_Step_WaitUntil("the cleaver is a world item holding its item", n"Check_CleaverReady", 0, 0);
        Add_Step_WaitUntil("the cleaver lies still on the floor", n"Check_CleaverAtRest", k_SlowPolls, 0);
        Add_Step("its grip nodes are the asset's sockets turned by the twists", n"Step_AssertNodes");
        Add_Step("the hold equals the captured old-path hold", n"Step_AssertHold");
        Add_Step("the reach is an Authored pickup on the old grips, turned by the twists", n"Step_AssertReach");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_CleaverReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsReady = ck::IsValid(_CleaverEntity) && _CleaverEntity.Is_WorldItem()
            && ck::IsValid(_CleaverEntity.As_WorldItem().Get_HeldItem());
        if (IsReady && ck::Is_NOT_Valid(_Cleaver))
        { _Cleaver = _CleaverEntity.As_WorldItem(); }

        auto Res = OutResult;
        Res.Set(IsReady);
    }

    UFUNCTION()
    private void Check_CleaverAtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsSlow = utils_jolt_body::Get_LinearVelocity(_Cleaver.Get_Body()).Size() < k_RestSpeed;
        _RestCount = IsSlow ? _RestCount + 1 : 0;

        auto Res = OutResult;
        Res.Set(_RestCount >= k_RestPolls);
    }

    UFUNCTION()
    private void Step_AssertNodes(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_CleaverEntity.Has_Fragment(FMars_Fragment_FPHands_Grips), "the cleaver carries a grip table");
        if (_CleaverEntity.Has_Fragment(FMars_Fragment_FPHands_Grips) == false)
        { return; }

        const auto Entries = _CleaverEntity.Get_Fragment(FMars_Fragment_FPHands_Grips).Entries;
        Assert_Equals_Int(Entries.Num(), 2, "one node per glove");

        const UMars_ItemTrait_Presentation Presentation = _Cleaver.Get_HeldItem().Get_Presentation();
        const UStaticMesh Mesh = System::LoadAsset_Blocking(Presentation.Visual.Mesh);
        const auto RootWorld = utils_transform::Get_EntityCurrentTransform(_CleaverEntity.As_Transform());
        for (const auto& Entry : Entries)
        {
            const auto IsRight = Entry.Hand == EMars_Hand::Right;
            const auto Socket = Mesh.FindSocket(IsRight ? n"Grip_R" : n"Grip_L");
            const auto Twist = IsRight ? Presentation.Grip.SocketTwist_R : Presentation.Grip.SocketTwist_L;
            const auto Expected = utils_fphands::Twist_AboutHandle(
                FTransform(Socket.RelativeRotation, Socket.RelativeLocation * Presentation.Visual.MeshScale), Twist);

            const auto Offset = utils_scene_node::Get_Offset(Entry.Node.As_SceneNode());
            Assert_True(Offset.Equals(Expected, 0.001), f"{Entry.Hand :n}: node offset [{Offset}] is the twisted socket [{Expected}]");

            const auto NodeWorld = utils_transform::Get_EntityCurrentTransform(Entry.Node);
            Assert_True(NodeWorld.Equals(Expected * RootWorld, 0.01), f"{Entry.Hand :n}: node world [{NodeWorld}] is the twisted socket on the root");
            Assert_True(Entry.Frame == EMars_FPHands_GripFrame::Node && Entry.Roll == EMars_FPHands_GripRoll::Fixed && Entry.Socket.IsSet() == false,
                f"{Entry.Hand :n}: a Node-frame, Fixed, socketless entry");
            Assert_True(Entry.Pose == Presentation.Grip.Pose, f"{Entry.Hand :n}: the Presentation's pose");
        }
    }

    UFUNCTION()
    private void Step_AssertHold(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Hold = utils_fphands::Make_Hold(_Cleaver.Get_HeldItem());
        Assert_True(Hold.Kind == EMars_FPHands_HoldKind::TwoHanded, f"two-handed (got {Hold.Kind :n})");
        Assert_True(Hold.SocketGrips.IsSet(), "the hold has socket grips");
        if (Hold.SocketGrips.IsSet() == false)
        { return; }

        const auto Grips = Hold.SocketGrips.GetValue();
        Assert_True(Grips.Right.Equals(k_OldSocketGrip_R, 0.001), f"the right socket grip [{Grips.Right}] equals the old path's");
        Assert_True(Grips.Left.Equals(k_OldSocketGrip_L, 0.001), f"the left socket grip [{Grips.Left}] equals the old path's");
    }

    UFUNCTION()
    private void Step_AssertReach(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto HandState = FMars_FPHands_HandState(FMars_FPHands_Hold(), FTransform::Identity, EMars_Hand::Right);
        const auto Query = FMars_FPHands_ReachQuery(FMars_FPHands_ReachSubject(_Cleaver.Get_Pickup(), _CleaverEntity), HandState);
        const auto MaybeTarget = utils_fphands::Resolve_ReachTarget(FMars_FPHands_Spec().Reach, Query);
        Assert_True(MaybeTarget.IsSet(), "the reach resolves");
        if (MaybeTarget.IsSet() == false)
        { return; }

        const auto Target = MaybeTarget.GetValue();
        Assert_True(Target.Layout == EMars_FPHands_GripLayout::Authored, f"Authored (got {Target.Layout :n})");
        Assert_True(Target.Pickup.IsSet, "a pickup");
        Assert_True(Target.Right.IsSet() && Target.Left.IsSet(), "both gloves reach");
        if (Target.Right.IsSet() == false || Target.Left.IsSet() == false)
        { return; }

        const UMars_ItemTrait_Presentation Presentation = _Cleaver.Get_HeldItem().Get_Presentation();
        const auto Root = _CleaverEntity.As_Transform();
        const auto Right = Target.Right.GetValue();
        const auto Left = Target.Left.GetValue();
        Assert_True(Right.Anchor == Root && Left.Anchor == Root, "both gloves anchor to the cleaver's root");
        Assert_True(Right.IsAuthored && Left.IsAuthored, "both grips are authored");

        const auto ExpectedRight = utils_fphands::Twist_AboutHandle(k_OldReachGrip_R, Presentation.Grip.SocketTwist_R);
        const auto ExpectedLeft = utils_fphands::Twist_AboutHandle(k_OldReachGrip_L, Presentation.Grip.SocketTwist_L);
        Assert_True(Right.Grip.GetLocation().Equals(k_OldReachGrip_R.GetLocation(), 0.001), f"the right grip [{Right.Grip.GetLocation()}] sits where the old reach put it");
        Assert_True(Left.Grip.GetLocation().Equals(k_OldReachGrip_L.GetLocation(), 0.001), f"the left grip [{Left.Grip.GetLocation()}] sits where the old reach put it");
        Assert_True(Right.Grip.Equals(ExpectedRight, 0.001), f"the right grip [{Right.Grip}] is the old reach grip turned by SocketTwist_R");
        Assert_True(Left.Grip.Equals(ExpectedLeft, 0.001), f"the left grip [{Left.Grip}] is the old reach grip turned by SocketTwist_L");
    }
}
