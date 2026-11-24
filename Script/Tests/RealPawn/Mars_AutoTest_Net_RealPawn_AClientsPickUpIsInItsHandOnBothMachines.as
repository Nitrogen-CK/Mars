// A client picks up a rock with the production pawn (the pickup cue at its copy of the rock, as the pickup interaction
// fires it) and holds it. On the client its HeldItem holds the rock and the first-person held visual sits at the hand. On
// the server the client's HeldItem holds the rock and its own Visual-mode world item is the rock in the client body's hand:
// the server's copy of the hand mount rides the body, the visual's root sits at HeldOffset on it with no Arrival in flight
// (ruling C8), it is within k_GripCm of grip_r and drawn as a world primitive, and the body draws no proxy beside it
// (HeldItemShadow, the owner's shadow, is empty on a copy that is not its player's view).
// Surface: Ck.RealPawn.Net.AS_RealPawn_AClientsPickUpIsInItsHandOnBothMachines
class UCk_AutoTest_Net_RealPawn_AClientsPickUpIsInItsHandOnBothMachines : UMars_AutoTestRig_NetRealPawn
{
    private const FVector k_Base = FVector(910000.0, 0.0, 5000.0);
    private const FString k_Row = "AClientsPickUpIsInItsHandOnBothMachines";
    private const float64 k_HandToleranceCm = 5.0;
    private const float64 k_GripCm = 30.0;

    private FCk_Handle_WorldItem _Rock;

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

        Spawn_ServerWorldItem(mars_items::Rock(), _Base + k_ItemFromBase);
        Mark_Deadline(18.0);
        WaitUntil(n"Is_ServerSeesTheHold", n"OnServerChecked", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSeesTheHold(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (Get_IsHolding(mars_items::Rock()) && Get_IsPresentationAtHand(k_HandToleranceCm)));
    }

    UFUNCTION()
    private void OnServerChecked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto IsHolding = Get_IsHolding(mars_items::Rock());
        const auto IsVisual = Get_IsPresentationVisual();
        const auto IsArriving = Get_IsPresentationArriving();
        const auto FromMount = Get_PresentationErrorCm();
        const auto FromGrip = Get_PresentationFromBodyGripCm();
        const auto OnBody = Get_IsMountOnBody();
        const auto Shadow = Get_HeldItemShadowMesh();
        const auto Mesh = Get_PresentationMeshComponent();
        const auto MeshType = ck::IsValid(Mesh) ? Mesh.FirstPersonPrimitiveType : EFirstPersonPrimitiveType::None;
        const auto MeshName = ck::IsValid(Mesh) ? Describe_Mesh(Mesh.GetStaticMesh()) : "none";
        Log_RealPawnRow(k_Row, f"holding={IsHolding} visual={IsVisual} arriving={IsArriving} onBody={OnBody} fromMount={FromMount :.2} fromGrip={FromGrip :.2} mesh={MeshName} type={MeshType :n} shadow={Describe_Mesh(Shadow)}");
        Assert_True(IsHolding, "the server's copy of the client's HeldItem holds the rock");
        Assert_True(IsVisual, "the server presents the client's rock by a Visual-mode world item of its own");
        Assert_False(IsArriving, "the server's rock visual has no Arrival in flight");
        Assert_True(OnBody, "the server's copy of the client's hand mount rides the body's grip_r");
        Assert_True(FromMount >= 0.0 && FromMount <= k_HandToleranceCm,
            f"the rock's root sits at HeldOffset on the server's copy of the hand mount (error {FromMount :.2} cm; -1: no settled rock in the hand)");
        Assert_True(FromGrip >= 0.0 && FromGrip <= k_GripCm,
            f"the rock is in the client body's right hand on the server ({FromGrip :.2} cm from grip_r)");
        Assert_True(ck::IsValid(Mesh) && ck::IsValid(Mesh.GetStaticMesh()), f"the server's rock visual draws its mesh ({MeshName})");
        Assert_True(MeshType == EFirstPersonPrimitiveType::None, f"the server draws the rock as a world primitive (first-person type {MeshType :n})");
        Assert_False(ck::IsValid(Shadow), f"the server draws no proxy beside the rock (HeldItemShadow mesh {Describe_Mesh(Shadow)})");
        WaitSeconds(k_ServerHoldSeconds + k_SettleSeconds, n"OnServerHeld");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Deadline(10.0);
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
        {
            Log_RealPawnRow(k_Row, "rock=missing");
            FinishFailure("the client never saw the rock the server spawned in front of its pawn");
            return;
        }

        utils_cue_generic::Request_ExecuteCue(_Rock, GameplayTags::Cue_Mars_WorldItem_PickUp,
            FMars_Request_WorldItem_PickUp(_Player), ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
        Mark_Deadline(10.0);
        WaitUntil(n"Is_ClientHoldingAtHand", n"OnClientChecked", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientHoldingAtHand(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (Get_IsHolding(mars_items::Rock()) && Get_IsPresentationAtHand(k_HandToleranceCm)));
    }

    UFUNCTION()
    private void OnClientChecked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto IsHolding = Get_IsHolding(mars_items::Rock());
        const auto Error = Get_PresentationErrorCm();
        const auto Shadow = Get_HeldItemShadowMesh();
        Log_RealPawnRow(k_Row, f"holding={IsHolding} presentationError={Error :.2} firstPersonMount={Get_IsMountFirstPerson()} shadow={Describe_Mesh(Shadow)}");
        Assert_True(IsHolding, "the client's HeldItem holds the rock");
        Assert_True(Error >= 0.0 && Error <= k_HandToleranceCm,
            f"the client's first-person held visual sits at the hand (error {Error :.2} cm; -1: no settled presentation in the hand)");
        Assert_True(Get_IsMountFirstPerson(), "the client's own copy of the hand mount is under its gloves");
        Assert_True(ck::IsValid(Shadow), "the client's own copy casts its held rock's shadow (HeldItemShadow has a mesh)");
        FinishSuccess();
    }
}
