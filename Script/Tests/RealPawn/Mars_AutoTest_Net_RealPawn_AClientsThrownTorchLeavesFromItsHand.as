// A client in the production pawn picks up a torch (a Persistent item: its one world item rides the hand) and throws it,
// uncharged and standing still, through the Launch cue with its own aim. The authority holds the torch in the client
// body's hand, the client in its first-person hand; the release leaves from the client's: the server's torch body, the
// second frame it reads World (the release's start pose has been applied by then), is within k_OriginToleranceCm of
// HeldOffset on the client's launch origin, while where its own copy of the hand would have released it (HeldOffset on its
// hand mount, the body's hand) lies beyond that tolerance. The server reports both.
// Surface: Ck.RealPawn.Net.AS_RealPawn_AClientsThrownTorchLeavesFromItsHand
class UCk_AutoTest_Net_RealPawn_AClientsThrownTorchLeavesFromItsHand : UMars_AutoTestRig_NetRealPawn
{
    private const FVector k_Base = FVector(940000.0, 0.0, 5000.0);
    private const FString k_Row = "AClientsThrownTorchLeavesFromItsHand";
    private const float64 k_HandToleranceCm = 5.0;
    // A body at rest falls well under a centimetre in the frames before the server samples it.
    private const float64 k_OriginToleranceCm = 10.0;

    private FCk_Handle _ServerTorch;
    private bool _ServerLaunched = false;
    private FVector _ServerOwnOrigin = FVector::ZeroVector;
    private int32 _ServerWorldSightings = 0;

    private FCk_Handle_WorldItem _Torch;
    // HeldOffset on the client's launch origin, and its torch root, when it threw.
    private FVector _ClientExpected = FVector::ZeroVector;
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
        _ServerTorch = Spawn_ServerWorldItem(mars_items::Torch(), _Base + k_ItemFromBase);
        Mark_Deadline(20.0);
        WaitUntil(n"Is_ServerTorchReleased", n"OnServerTorchReleased", k_SlowPolls);
    }

    // Still held when it fires: the server's own origin is HeldOffset on its copy of the hand (the body's hand).
    UFUNCTION()
    private void OnServerItemLaunched(FCk_Handle_HeldItemUse InUse, FCk_Handle_Item InItem, EMars_LaunchKind InKind)
    {
        _ServerLaunched = true;
        if (InItem.Has_Presentation())
        {
            const auto Hand = utils_transform::Get_EntityCurrentTransform(Get_HeldItem().Get_HandAttachPoint());
            _ServerOwnOrigin = (InItem.Get_Presentation().Mounting.HeldOffset * Hand).GetLocation();
        }
    }

    // The second frame the launched torch reads World: the release commits World and queues the start pose in one call,
    // and the body takes the pose when it drains its requests later that frame.
    UFUNCTION()
    private void Is_ServerTorchReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto WorldItem = _ServerTorch.As_WorldItem(ECk_SanityCheck::UnChecked);
        if (_ServerLaunched && ck::IsValid(WorldItem) && WorldItem.Get_Mount() == EMars_WorldItem_Mount::World)
        { _ServerWorldSightings += 1; }

        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || _ServerWorldSightings >= 2);
    }

    UFUNCTION()
    private void OnServerTorchReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto IsReleased = _ServerWorldSightings >= 2;
        const auto Body = ck::IsValid(_ServerTorch) ? Get_RootLocation(_ServerTorch) : FVector::ZeroVector;
        Log_RealPawnRow(k_Row, f"launched={_ServerLaunched} released={IsReleased} body={Body} serverOwnOrigin={_ServerOwnOrigin}");
        Assert_True(_ServerLaunched, "the server launched the client's held torch");
        Assert_True(IsReleased, "the server's torch was released to the world");
        if (IsReleased)
        { Write_Report(Body, _ServerOwnOrigin); }

        WaitSeconds(k_ServerHoldSeconds + k_SettleSeconds, n"OnServerHeld");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Deadline(10.0);
        WaitUntil(n"Is_ClientTorchFound", n"OnClientTorchFound", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientTorchFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Torch = Find_WorldItemNear(mars_items::Torch(), _Base + k_ItemFromBase, 150.0);
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || ck::IsValid(_Torch));
    }

    UFUNCTION()
    private void OnClientTorchFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_Torch))
        { FinishFailure("the client never saw the torch the server spawned in front of its pawn"); return; }

        utils_cue_generic::Request_ExecuteCue(_Torch, GameplayTags::Cue_Mars_WorldItem_PickUp,
            FMars_Request_WorldItem_PickUp(_Player), ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
        Mark_Deadline(10.0);
        WaitUntil(n"Is_ClientHoldingAtHand", n"OnClientHoldingAtHand", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientHoldingAtHand(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (Get_IsHolding(mars_items::Torch()) && Get_IsPresentationAtHand(k_HandToleranceCm)));
    }

    UFUNCTION()
    private void OnClientHoldingAtHand(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsHolding(mars_items::Torch()) == false || Get_IsPresentationAtHand(k_HandToleranceCm) == false)
        {
            Log_RealPawnRow(k_Row, f"holding={Get_IsHolding(mars_items::Torch())} presentationError={Get_PresentationErrorCm() :.2}");
            FinishFailure("the client did not come to hold the torch at its first-person hand, so it had nothing to throw");
            return;
        }

        // The throw intent's aim (utils_held_item_use::Make_Aim), uncharged and still, so the body leaves at rest.
        auto Aim = utils_held_item_use::Make_Aim(_Player);
        Aim.ThrowPower = 0.0f;
        Aim.PawnVelocity = FVector::ZeroVector;
        if (Aim.Origin.IsSet() == false)
        { FinishFailure("the client's aim carries no launch origin"); return; }

        const auto HeldOffset = Get_HeldItem().Get_CurrentItem().Get_Presentation().Mounting.HeldOffset;
        _ClientExpected = (HeldOffset * Aim.Origin.GetValue()).GetLocation();
        _ClientItem = Get_RootLocation(Get_HeldItem().Get_PresentationEntity());
        utils_cue_generic::Request_ExecuteCue(_Player, GameplayTags::Cue_Mars_HeldItemUse_Launch,
            FMars_HeldItemUse_Launch(EMars_LaunchKind::Throw, Aim), ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
        Mark_Deadline(10.0);
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
        const auto Error = (Report.LaunchOrigin - _ClientExpected).Size();
        const auto ServerOwnError = (Report.ServerHand - _ClientExpected).Size();
        Log_RealPawnRow(k_Row, f"report={Report.Serial} serverBody={Report.LaunchOrigin} serverOwnOrigin={Report.ServerHand} clientExpected={_ClientExpected} clientItem={_ClientItem} error={Error :.1} serverOwnToClient={ServerOwnError :.1}");
        Assert_True(Report.Serial > 0, "the server reported where the thrown torch was released");
        // Else a release from the server's own copy of the hand would pass too.
        Assert_True(Report.Serial > 0 && ServerOwnError > k_OriginToleranceCm,
            f"the server's own body-hand origin {Report.ServerHand} lies more than {k_OriginToleranceCm} cm from HeldOffset on the "
            + f"client's launch origin {_ClientExpected} ({ServerOwnError :.1} cm), so the row tells the two apart");
        Assert_True(Report.Serial > 0 && Error <= k_OriginToleranceCm,
            f"the server's torch left from the client's hand: server body {Report.LaunchOrigin}, HeldOffset on the client's launch "
            + f"origin {_ClientExpected}, client's torch {_ClientItem}, the server's own body-hand origin {Report.ServerHand} (error {Error :.1} cm, server's own {ServerOwnError :.1} cm)");
        FinishSuccess();
    }
}
