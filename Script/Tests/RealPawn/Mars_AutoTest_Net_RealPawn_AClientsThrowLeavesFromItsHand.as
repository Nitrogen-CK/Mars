// A client in the production pawn picks up a rock and throws it (the Launch cue at its player, with its own aim, as its
// throw intent fires it; uncharged and standing still, so the body leaves at rest). The server's thrown body is born
// where the client's own launch solution put it: within k_OriginToleranceCm of the client's hand, while the server's own
// copy of the hand (where its own launch would leave from) lies beyond it. The server reports where it first saw the
// body, and its own copy of the hand, through the test report.
// Surface: Ck.RealPawn.Net.AS_RealPawn_AClientsThrowLeavesFromItsHand
class UCk_AutoTest_Net_RealPawn_AClientsThrowLeavesFromItsHand : UMars_AutoTestRig_NetRealPawn
{
    private const FVector k_Base = FVector(916000.0, 0.0, 5000.0);
    private const FString k_Row = "AClientsThrowLeavesFromItsHand";
    private const float64 k_HandToleranceCm = 5.0;
    // A body at rest falls well under a centimetre in the frames before the server first sees it.
    private const float64 k_OriginToleranceCm = 10.0;

    private FCk_Handle_WorldItem _Rock;
    private bool _ServerLaunched = false;
    // The client's launch solution origin and its held visual's root when it threw.
    private FVector _ClientOrigin = FVector::ZeroVector;
    private FVector _ClientItem = FVector::ZeroVector;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);
        Add_Report();

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

        auto Use = _Player.As_HeldItemUse();
        Use.BindTo_OnItemLaunched(FMars_Delegate_HeldItemUse_OnItemLaunched(this, n"OnServerItemLaunched"));
        Spawn_ServerWorldItem(mars_items::Rock(), _Base + k_ItemFromBase);
        Mark_Deadline(20.0);
        WaitUntil(n"Is_ServerThrownBodySeen", n"OnServerThrownBodySeen", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerItemLaunched(FCk_Handle_HeldItemUse InUse, FCk_Handle_Item InItem, EMars_LaunchKind InKind)
    {
        _ServerLaunched = true;
    }

    // After the launch the only World-mode world item is the thrown body (the picked-up rock's ended long before).
    UFUNCTION()
    private void Is_ServerThrownBodySeen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (_ServerLaunched && ck::IsValid(Find_AnyWorldModeItem(_Pawn.GetActorLocation()))));
    }

    UFUNCTION()
    private void OnServerThrownBodySeen(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Body = Find_AnyWorldModeItem(_Pawn.GetActorLocation());
        const auto ServerHand = Get_RootLocation(Get_HeldItem().Get_HandAttachPoint());
        Log_RealPawnRow(k_Row, f"launched={_ServerLaunched} body={ck::IsValid(Body)} serverHand={ServerHand}");
        Assert_True(_ServerLaunched, "the server launched the client's held rock");
        Assert_Valid(Body, "the server spawned the thrown body");
        if (ck::IsValid(Body))
        { Write_Report(Get_RootLocation(Body), ServerHand); }

        WaitSeconds(k_ServerHoldSeconds + k_SettleSeconds, n"OnServerHeld");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Deadline(8.0);
        WaitUntil(n"Is_ClientRockFound", n"OnClientRockFound", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientRockFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Rock = Find_WorldItemNear(mars_items::Rock(), _Base + k_ItemFromBase, 150.0);
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || ck::IsValid(_Rock));
    }

    UFUNCTION()
    private void OnClientRockFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_Rock))
        { FinishFailure("the client never saw the rock the server spawned in front of its pawn"); return; }

        utils_cue_generic::Request_ExecuteCue(_Rock, GameplayTags::Cue_Mars_WorldItem_PickUp,
            FMars_Request_WorldItem_PickUp(_Player), ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
        Mark_Deadline(8.0);
        WaitUntil(n"Is_ClientHoldingAtHand", n"OnClientHoldingAtHand", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientHoldingAtHand(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (Get_IsHolding(mars_items::Rock()) && Get_IsPresentationAtHand(k_HandToleranceCm)));
    }

    UFUNCTION()
    private void OnClientHoldingAtHand(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsHolding(mars_items::Rock()) == false || Get_IsPresentationAtHand(k_HandToleranceCm) == false)
        {
            Log_RealPawnRow(k_Row, f"holding={Get_IsHolding(mars_items::Rock())} presentationError={Get_PresentationErrorCm() :.2}");
            FinishFailure("the client did not come to hold the rock at its hand, so it had nothing to throw");
            return;
        }

        auto Use = _Player.As_HeldItemUse();
        const auto Solution = Use.Get_LaunchSolution(EMars_LaunchKind::Throw);
        if (Solution.IsSet() == false)
        { FinishFailure("the client holds the rock but has no launch solution"); return; }

        _ClientOrigin = Solution.GetValue().Origin.GetLocation();
        _ClientItem = Get_RootLocation(Get_HeldItem().Get_PresentationEntity());

        // The throw intent's aim (utils_held_item_use::Make_Aim), uncharged and still, so the body leaves at rest.
        auto Aim = utils_held_item_use::Make_Aim(_Player);
        Aim.ThrowPower = 0.0f;
        Aim.PawnVelocity = FVector::ZeroVector;
        utils_cue_generic::Request_ExecuteCue(_Player, GameplayTags::Cue_Mars_HeldItemUse_Launch,
            FMars_HeldItemUse_Launch(EMars_LaunchKind::Throw, Aim), ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
        Mark_Deadline(8.0);
        WaitUntil(n"Is_ClientReportArrived", n"OnClientChecked", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientReportArrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || Get_Report().Serial > 0);
    }

    UFUNCTION()
    private void OnClientChecked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Report = Get_Report();
        const auto Error = (Report.LaunchOrigin - _ClientOrigin).Size();
        // The server's own launch origin is its copy of the hand (Get_OwnLaunchOrigin).
        const auto ServerOwnError = (Report.ServerHand - _ClientOrigin).Size();
        Log_RealPawnRow(k_Row, f"report={Report.Serial} serverOrigin={Report.LaunchOrigin} serverHand={Report.ServerHand} clientOrigin={_ClientOrigin} clientItem={_ClientItem} error={Error :.1} serverOwnToClient={ServerOwnError :.1}");
        Assert_True(Report.Serial > 0, "the server reported where the thrown body was born");
        // Else a body born at the server's own copy of the hand would pass too.
        Assert_True(Report.Serial > 0 && ServerOwnError > k_OriginToleranceCm,
            f"the server's own copy of the hand {Report.ServerHand} lies more than {k_OriginToleranceCm} cm from the client's launch "
            + f"origin {_ClientOrigin} ({ServerOwnError :.1} cm), so the row tells the two apart");
        Assert_True(Report.Serial > 0 && Error <= k_OriginToleranceCm,
            f"the server's thrown body was born at the client's hand: server origin {Report.LaunchOrigin}, client launch origin "
            + f"{_ClientOrigin}, client held item {_ClientItem}, server's own copy of the hand {Report.ServerHand} (error {Error :.1} cm)");
        FinishSuccess();
    }
}
