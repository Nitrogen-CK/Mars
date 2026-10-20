// The declared give-up: a rejected piece with no platter left to take it back is let go where it lies. A press takes the
// top of the pile and releases it; while the hand awaits the answer the platter it came from (the feed's source, so no
// platter is left at all) is destroyed. The rejection then lets the piece go: OnPieceLetGo names it once, after the
// transfer settled Rejected; it hangs from no scene node, rides no platter, and its body is Dynamic; the hand runs its
// Return to rest.
class UMars_AutoTest_CookingFeed_ARejectedPieceWithNoPlatterLeftIsLetGo : UMars_AutoTestRig_CookingFeed
{
    private FCk_Handle_FoodPiece _Piece;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildFeed(InHandle, Make_TestSpec());
        Add_Steps_SourceTheFeed();

        Add_Step("press add food", n"Step_Begin");
        Add_Step_WaitUntil("the hand awaits admission", n"Check_AwaitingAdmission", 0, 0);
        Add_Step("destroy the platter the piece came from", n"Step_DestroyPlatter");
        Add_Step_WaitUntil("the platter is gone", n"Check_PlatterGone", 0, 0);
        Add_Step("reject the release", n"Step_RejectPending");
        Add_Step_WaitUntil("the hand is back at rest", n"Check_Idle", 0, 0);
        Add_Step_WaitUntil("the piece's body is Dynamic", n"Check_PieceDynamic", k_SlowPolls, 0);
        Add_Step("the piece was let go where it lies", n"Step_AssertLetGo");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_DestroyPlatter(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Piece = _Feed.TryGet_ActiveFoodPiece();
        Assert_True(ck::IsValid(_Piece) && _Releases.Num() == 1 && _Releases[0].Piece == _Piece, "the release carries the reserved piece");
        Assert_True(_Feed.TryGet_PieceHold() == EMars_CookingFeed_PieceHold::Released, "the feed let it go at the release");
        Assert_Equals_Int(_LetGo.Num(), 0, "nothing was let go before the platter went");

        FCk_Handle PlatterEntity = _Platter;
        utils_entity_lifetime::Request_DestroyEntity(PlatterEntity);
    }

    UFUNCTION()
    private void Check_PlatterGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_cooking_feed::Get_IsAlive(_Platter) == false);
    }

    UFUNCTION()
    private void Check_PieceDynamic(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        FCk_Handle Entity = _Piece;
        const auto Body = Entity.As_JoltBody(ECk_SanityCheck::UnChecked);
        auto Res = OutResult;
        Res.Set(ck::IsValid(Body) && utils_jolt_body::Get_MotionType(Body) == ECk_MotionType::Dynamic);
    }

    UFUNCTION()
    private void Step_AssertLetGo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Settles.Num(), 1, "one transfer settled");
        Assert_True(_Settles.Num() == 1 && _Settles[0] == EMars_CookingFeed_Settle::Rejected, "it settled Rejected");
        Assert_True(_LetGo.Num() == 1 && _LetGo[0] == _Piece, f"OnPieceLetGo named the piece once ({_LetGo.Num()} let go)");

        Assert_False(_Piece.Get_IsGone(), "the piece lives on where it lies");
        FCk_Handle Entity = _Piece;
        const auto Node = Entity.As_SceneNode(ECk_SanityCheck::UnChecked);
        Assert_True(ck::Is_NOT_Valid(Node) || ck::Is_NOT_Valid(utils_scene_node::Get_Parent(Node)), "it hangs from no scene node");
        Assert_False(ck::IsValid(_Piece.TryGet_Platter()), "it rides no platter");
        Assert_False(_Feed.TryGet_ActivePiece().IsSet(), "no reservation is left");
        Assert_True(_Phases.Num() > 0 && _Phases.Last() == EMars_CookingFeed_Phase::Idle, "the hand ended at rest");
    }
}
