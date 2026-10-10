// The feed carries the real piece: from the grasp the reserved piece is off the platter and its scene-node parent is the
// feed's hand node, its middle at the hand's held offset (identity here: on the hand node) through the carry. At the release
// it is let go where it rides (no scene node any more) and the release names that pose, not the release node's. A rejected
// admission puts it back on the platter (the rig stands in for the bridge), and the stock is whole again.
class UMars_AutoTest_CookingFeed_TheCarriedPieceRidesTheHandNode : UMars_AutoTestRig_CookingFeed
{
    private FCk_Handle_FoodPiece _Piece;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        // A carry long enough to look at the piece riding the hand.
        auto Spec = Make_TestSpec();
        Spec.Timing = FMars_CookingFeed_TimingSpec(0.1f, 0.1f, 0.5f, 0.1f);
        BuildFeed(InHandle, Spec);
        Add_Steps_SourceTheFeed();

        Add_Step("press add food", n"Step_Begin");
        Add_Step_WaitUntil("the hand carries and the piece rides the hand node", n"Check_RidingTheHand", 0, 2.0f);
        Add_Step_WaitFrames("the held offset applies", 3);
        Add_Step("off the platter, under the hand node, its middle on the hand", n"Step_AssertRides");
        Add_Step_WaitUntil("the release", n"Check_AwaitingAdmission", 0, 2.0f);
        Add_Step("let go where it rode: no parent, released at its own pose", n"Step_AssertReleased");
        Add_Step("reject the release", n"Step_RejectPending");
        Add_Step_WaitUntil("the piece is back on the platter and the pile settled", n"Check_BackOnThePlatter", 0, 3.0f);
        Add_Step("the stock is whole again", n"Step_AssertBack");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_RidingTheHand(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Piece))
        { _Piece = _Feed.TryGet_ActiveFoodPiece(); }

        auto Res = OutResult;
        Res.Set(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Carry && Get_Parent() == _HandNode.As_Transform());
    }

    UFUNCTION()
    private void Step_AssertRides(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Carry, f"still carrying (got {_Feed.Get_Phase() :n})");
        Assert_True(_Feed.TryGet_PieceHold() == EMars_CookingFeed_PieceHold::InHand, "the feed says the piece is in the hand");
        Assert_True(Get_Parent() == _HandNode.As_Transform(), "the piece's scene-node parent is the hand node");
        Assert_False(ck::IsValid(_Piece.TryGet_Platter()), "the platter no longer holds it");
        Assert_Equals_Int(_Platter.Get_Occupancy(), k_Stock - 1, "the platter holds the other five");
        Assert_Ledger(k_Stock - 1, 0, "carrying");

        const auto HandWorld = utils_transform::Get_EntityCurrentTransform(_HandNode.As_Transform());
        const auto Centre = Get_PieceCentreWorld();
        Assert_True(Centre.Equals(HandWorld.GetLocation(), 0.5), f"its middle sits on the hand ({Centre} vs {HandWorld.GetLocation()})");
    }

    UFUNCTION()
    private void Step_AssertReleased(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Releases.Num(), 1, "one release");
        if (_Releases.Num() != 1)
        { return; }

        const auto Release = _Releases[0];
        Assert_True(Release.Piece == _Piece, "the release names the carried piece");
        Assert_False(Get_Parent() == _HandNode.As_Transform(), "the piece no longer rides the hand node");

        FCk_Handle Entity = _Piece;
        Assert_False(Entity.Is_SceneNode(), "the piece is detached");

        const auto PieceWorld = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform());
        const auto Gap = Release.WorldTransform.GetLocation().Distance(PieceWorld.GetLocation());
        Assert_True(Gap <= 0.5, f"the release is the piece's own pose where it was let go (gap {Gap})");

        const auto NodeGap = Release.WorldTransform.GetLocation().Distance(_ReleaseNodeAtRelease[0].GetLocation());
        Assert_True(NodeGap > 10.0, f"not the release node's pose: the piece rode the hand ({NodeGap} away from the node)");
    }

    UFUNCTION()
    private void Check_BackOnThePlatter(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Piece.TryGet_Platter() == _Platter && _Platter.Get_HeldCount() == k_Stock && _Platter.Get_PendingCount() == 0);
    }

    UFUNCTION()
    private void Step_AssertBack(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Return || _Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle,
            f"the hand returns or rests (got {_Feed.Get_Phase() :n})");
        Assert_Equals_Int(Get_SettleCount(EMars_CookingFeed_Settle::Rejected), 1, "the release settled Rejected");
        Assert_Ledger(k_Stock, 0, "after the rejection");
    }

    // Invalid while the piece is not scene-node attached.
    private FCk_Handle_Transform Get_Parent() const
    {
        if (ck::Is_NOT_Valid(_Piece))
        { return FCk_Handle_Transform(); }

        FCk_Handle Entity = _Piece;
        auto Node = Entity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return FCk_Handle_Transform(); }

        return utils_scene_node::Get_Parent(Node);
    }

    private FVector Get_PieceCentreWorld() const
    {
        FCk_Handle Entity = _Piece;
        const auto PieceWorld = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform());
        return PieceWorld.TransformPosition(utils_searing::Get_BoundsCentre(utils_runtime_mesh::Get_Metrics(_Piece.Get_Geometry())));
    }
}
