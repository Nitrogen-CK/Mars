// The server sources its feed and presses add food; in the first frame its phase reads Reach it puts the reserved slab's
// item into the subject's stow target and selects it. Once its feed is idle and the subject holds the slab it reports: it
// settled one transfer Cancelled. On the client the feed is idle and the last phase it raised is Idle; its slab is held by
// the subject on the subject's own hand node and not under the feed's; one is available and its hand is at rest.
// Surface: Ck.CookingFeed.Net.AS_CookingFeed_AReservedPieceTakenByHandCancelsOnTheClient
class UCk_AutoTest_Net_CookingFeed_AReservedPieceTakenByHandCancelsOnTheClient : UMars_AutoTestRig_NetCookingFeed
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 279000.0;

    private FCk_Handle_FoodPiece _Piece;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_FeedRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_FeedStep(1, n"OnClientStep1"); }
    }

    protected void On_ServerFeedFound() override
    {
        Source_AfterBind();
    }

    protected void On_ServerSourced() override
    {
        Begin_Transfer();
        Await_Phase(EMars_CookingFeed_Phase::Reach, n"OnServerReach");
    }

    UFUNCTION()
    private void OnServerReach(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Piece = _Feed.TryGet_ActiveFoodPiece();
        Assert_True(Get_IsCarrierReady(_Carrier), "the server's carrier is ready");
        FCk_Handle Entity = _Piece;
        Stow(Entity.As_WorldItem());
        WaitUntil(n"Is_ServerStowed", n"OnServerStowed", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Carrier.Hotbar.TryGet_SlotIndexOf(Get_WorldItem().Get_Item()).IsSet());
    }

    UFUNCTION()
    private void OnServerStowed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Index = _Carrier.Hotbar.TryGet_SlotIndexOf(Get_WorldItem().Get_Item()).GetValue();
        _Carrier.Hotbar.Request_SetSelection(FMars_Request_Hotbar_SetSelection(TOptional<int32>(Index)));
        WaitUntil(n"Is_ServerHeldAndIdle", n"OnServerHeldAndIdle", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerHeldAndIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto WorldItem = Get_WorldItem();
        auto Result = OutResult;
        Result.Set(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle && WorldItem.Get_Mount() == EMars_WorldItem_Mount::Held
            && WorldItem.Get_Carrier() == Get_SubjectEntity() && WorldItem.Get_IsSettled());
    }

    UFUNCTION()
    private void OnServerHeldAndIdle(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Report = Make_FeedStep(1);
        Report.PieceId = _Piece.Get_Id();
        Publish_FeedStep(Report);
        WaitSeconds(k_ClientSettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Settles.Num() == 1 && _Settles[0] == EMars_CookingFeed_Settle::Cancelled, f"the server settled one transfer Cancelled ({Describe_Record()})");
        End_FeedServer(f"{Describe_Record()} {Describe_Counts()}");
    }

    private FCk_Handle_WorldItem Get_WorldItem()
    {
        FCk_Handle Entity = _Piece;
        return Entity.As_WorldItem(ECk_SanityCheck::UnChecked);
    }

    UFUNCTION()
    private void OnClientStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Piece = Find_PieceById(Get_FeedReport().PieceId);
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, "the client's feed is idle");
        Assert_True(_Phases.Num() > 0 && _Phases.Last() == EMars_CookingFeed_Phase::Idle, f"the last phase the client raised is Idle ({Describe_Record()})");

        auto HandCm = -1.0;
        const auto WorldItem = Get_WorldItem();
        Assert_True(Get_IsLive(_Piece) && ck::IsValid(WorldItem), "the client finds its slab");
        if (ck::IsValid(WorldItem))
        {
            Assert_True(WorldItem.Get_Mount() == EMars_WorldItem_Mount::Held && WorldItem.Get_Carrier() == Get_SubjectEntity(),
                f"the client's slab is held by the subject (mount {WorldItem.Get_Mount() :n})");
            Assert_False(Get_IsUnderFeedHand(_Piece), "the client's slab is not under the feed's hand node");
            const UMars_ItemTrait_Presentation Presentation = WorldItem.Get_Item().Get_Presentation();
            FCk_Handle Entity = _Piece;
            HandCm = Get_PoseError(Entity, _Carrier.Hand, Presentation.Mounting.HeldOffset);
            Assert_True(HandCm <= k_HandPoseToleranceCm, f"the client's slab is on the subject's hand node (off by {HandCm} cm)");
        }

        Assert_Equals_Int(_Feed.Get_Available(), 1, "the client's feed reads one available");
        Assert_True(Get_IsHandAtRest(), f"the client's feed hand is at rest ({Describe_HandRest()})");
        End_FeedClient(f"{Describe_Record()} parent=[{Get_Parent(_Piece).ToString()}] subjectHandCm={HandCm} ledger [{Describe_Ledger(_Feed.Get_Ledger())}]");
    }
}
