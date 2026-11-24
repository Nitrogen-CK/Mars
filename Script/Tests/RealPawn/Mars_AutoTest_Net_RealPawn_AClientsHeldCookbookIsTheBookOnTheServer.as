// A client picks up the cookbook with the production pawn (the pickup cue at its copy of the book, as the pickup
// interaction fires it) and holds it. On the server, the client's body holds the real book: the client's HeldItem holds
// the cookbook, the body draws no proxy (HeldItemShadow empty, where it drew the bare closed mesh), and the book's skeletal
// presentation is visible, drawn as a world primitive (first-person type None), its root at HeldOffset on the server's
// copy of the hand mount, which rides the body, within k_GripCm of grip_r.
// Surface: Ck.RealPawn.Net.AS_RealPawn_AClientsHeldCookbookIsTheBookOnTheServer
class UCk_AutoTest_Net_RealPawn_AClientsHeldCookbookIsTheBookOnTheServer : UMars_AutoTestRig_NetRealPawn
{
    private const FVector k_Base = FVector(922000.0, 0.0, 5000.0);
    private const FString k_Row = "AClientsHeldCookbookIsTheBookOnTheServer";
    private const float64 k_HandToleranceCm = 5.0;
    private const float64 k_GripCm = 30.0;

    private FCk_Handle_WorldItem _Book;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientOwnerReady", n"OnClientReady", k_SlowPolls);
            return;
        }

        Spawn_ServerPawn();
        Spawn_ServerJoltFloor(InHandle);
        WaitUntil(n"Is_ServerPawnAndOwnerReady", n"OnServerComposed", k_SlowPolls);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Server
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ComposeSeconds, n"OnServerComposeWaited");
    }

    UFUNCTION()
    private void OnServerComposeWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Request_ServerPossessByRemote(_Pawn) == false)
        { FinishFailure("the server's world has not exactly one player controller that is not local"); return; }

        Spawn_ServerWorldItem(mars_items::Cookbook(), _Base + k_ItemFromBase);
        Mark_Deadline(18.0);
        WaitUntil(n"Is_ServerSeesTheBook", n"OnServerChecked", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSeesTheBook(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (Get_IsHolding(mars_items::Cookbook()) && Get_IsPresentationAtHand(k_HandToleranceCm)
            && ck::IsValid(utils_cookbook::TryGet_HeldBook(_Player))));
    }

    UFUNCTION()
    private void OnServerChecked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto IsHolding = Get_IsHolding(mars_items::Cookbook());
        const auto Book = utils_cookbook::TryGet_HeldBook(_Player);
        const auto FromMount = Get_PresentationErrorCm();
        const auto FromGrip = Get_PresentationFromBodyGripCm();
        const auto OnBody = Get_IsMountOnBody();
        const auto Proxy = Get_HeldItemShadowMesh();
        const auto ProxyName = ck::IsValid(Proxy) ? Proxy.GetName().ToString() : "none";
        const auto HasBook = ck::IsValid(Book);
        const auto IsVisible = HasBook && Book.IsVisible();
        const auto BookType = HasBook ? Book.FirstPersonPrimitiveType : EFirstPersonPrimitiveType::None;
        const auto BookFromGrip = HasBook ? (Book.GetWorldLocation() - _Pawn.Mesh.GetSocketTransform(n"grip_r").GetLocation()).Size() : -1.0;
        Log_RealPawnRow(k_Row, f"holding={IsHolding} book={HasBook} visible={IsVisible} type={BookType :n} onBody={OnBody} fromMount={FromMount :.2} fromGrip={FromGrip :.2} bookFromGrip={BookFromGrip :.2} proxy={ProxyName}");
        Assert_True(IsHolding, "the server's copy of the client's HeldItem holds the cookbook");
        Assert_False(ck::IsValid(Proxy), f"the server draws no proxy in the client's body hand (HeldItemShadow mesh {ProxyName})");
        Assert_True(HasBook, "the server's copy of the held book has its skeletal presentation");
        Assert_True(IsVisible, "the book's skeletal presentation is visible on the server");
        Assert_True(HasBook && BookType == EFirstPersonPrimitiveType::None,
            f"the server draws the book as a world primitive (first-person type {BookType :n})");
        Assert_True(OnBody, "the server's copy of the client's hand mount rides the body's grip_r");
        Assert_True(FromMount >= 0.0 && FromMount <= k_HandToleranceCm,
            f"the book's root sits at HeldOffset on the server's copy of the hand mount (error {FromMount :.2} cm; -1: no settled book in the hand)");
        Assert_True(BookFromGrip >= 0.0 && BookFromGrip <= k_GripCm,
            f"the book is in the client body's right hand on the server ({BookFromGrip :.2} cm from grip_r)");
        WaitSeconds(k_ServerHoldSeconds + k_SettleSeconds, n"OnServerHeld");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Deadline(10.0);
        WaitUntil(n"Is_ClientBookFound", n"OnClientBookFound", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientBookFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Book = Find_WorldItemNear(mars_items::Cookbook(), _Base + k_ItemFromBase, 150.0);
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || ck::IsValid(_Book));
    }

    UFUNCTION()
    private void OnClientBookFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_Book))
        {
            Log_RealPawnRow(k_Row, "book=missing");
            FinishFailure("the client never saw the cookbook the server spawned in front of its pawn");
            return;
        }

        utils_cue_generic::Request_ExecuteCue(_Book, GameplayTags::Cue_Mars_WorldItem_PickUp,
            FMars_Request_WorldItem_PickUp(_Player), ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
        Mark_Deadline(12.0);
        WaitUntil(n"Is_ClientHoldingAtHand", n"OnClientChecked", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientHoldingAtHand(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (Get_IsHolding(mars_items::Cookbook()) && Get_IsPresentationAtHand(k_HandToleranceCm)));
    }

    UFUNCTION()
    private void OnClientChecked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto IsHolding = Get_IsHolding(mars_items::Cookbook());
        const auto Error = Get_PresentationErrorCm();
        Log_RealPawnRow(k_Row, f"holding={IsHolding} presentationError={Error :.2} firstPersonMount={Get_IsMountFirstPerson()}");
        Assert_True(IsHolding, "the client's HeldItem holds the cookbook");
        Assert_True(Get_IsMountFirstPerson(), "the client's own hand mount is under its gloves");
        Assert_True(Error >= 0.0 && Error <= k_HandToleranceCm,
            f"the client's book sits at its first-person hand (error {Error :.2} cm; -1: no settled presentation in the hand)");
        FinishSuccess();
    }
}
