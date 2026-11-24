// The host's own production pawn (possessed by the server's local controller) picks up a rock, a transient item. On the
// client, standing beside it in a pawn of its own, the client's copy of the host's HeldItem presents the rock by a
// Visual-mode world item of its own in the host body's right hand: its copy of the hand mount rides the body, the visual's
// root sits at HeldOffset on it with no Arrival in flight, it is within k_GripCm of grip_r and drawn as a world primitive,
// and the body draws no proxy beside it (HeldItemShadow empty). Before the rock arrives the client asks its copy for a
// spawn-from pose far from the hand, as a pickup's gloves would (ruling C8): the gloves of a copy that is not its player's
// view never carry an item in, so the visual must take HeldOffset anyway. On the server the host's own copy has its mount
// under its gloves and casts the rock's shadow (HeldItemShadow draws the rock's mesh).
// Surface: Ck.RealPawn.Net.AS_RealPawn_AHostsHeldRockIsInItsBodyHandOnTheClient
class UCk_AutoTest_Net_RealPawn_AHostsHeldRockIsInItsBodyHandOnTheClient : UMars_AutoTestRig_NetRealPawn
{
    private const FVector k_Base = FVector(930000.0, 0.0, 5000.0);
    private const FString k_Row = "AHostsHeldRockIsInItsBodyHandOnTheClient";
    private const float64 k_HandToleranceCm = 5.0;
    private const float64 k_GripCm = 30.0;
    // The spawn-from pose the client asks for, from its copy's hand mount: well away from HeldOffset.
    private const FVector k_SpawnFromInHand = FVector(60.0, -40.0, 50.0);

    private FCk_Handle_WorldItem _Rock;
    private bool _AskedSpawnFrom = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            Mark_Deadline(22.0);
            WaitUntil(n"Is_ClientCopyReady", n"OnClientCopyReady", k_SlowPolls);
            return;
        }

        Spawn_ServerPawn();
        Spawn_ServerViewer();
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
        if (Request_ServerPossessByLocal(_Pawn) == false)
        { FinishFailure("the server's world has not exactly one local player controller"); return; }

        Spawn_ServerWorldItem(mars_items::Rock(), _Base + k_ItemFromBase);
        Mark_Deadline(16.0);
        WaitUntil(n"Is_ServerReadyToPickUp", n"OnServerReadyToPickUp", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerReadyToPickUp(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Rock = Find_WorldItemNear(mars_items::Rock(), _Base + k_ItemFromBase, 100.0);
        const auto Hotbar = _Player.As_Hotbar(ECk_SanityCheck::UnChecked);
        const auto IsReady = _Pawn.IsLocallyControlled() && Get_IsStateActive(UMars_SmState_Loco_Idle) && ck::IsValid(Hotbar)
            && Hotbar.Get_IsReady() && Get_IsMountFirstPerson() && ck::IsValid(_Rock);
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || IsReady);
    }

    UFUNCTION()
    private void OnServerReadyToPickUp(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPastDeadline())
        {
            Log_RealPawnRow(k_Row, f"rock={ck::IsValid(_Rock)} firstPersonMount={Get_IsMountFirstPerson()}");
            FinishFailure("the host's pawn, its hotbar, its first-person mount or the rock was not ready on the server");
            return;
        }

        _Rock.Request_PickUp(FMars_Request_WorldItem_PickUp(_Player));
        WaitUntil(n"Is_ServerHoldingTheRock", n"OnServerHoldingTheRock", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerHoldingTheRock(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (Get_IsHolding(mars_items::Rock()) && Get_IsPresentationAtHand(k_HandToleranceCm)));
    }

    UFUNCTION()
    private void OnServerHoldingTheRock(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto IsHolding = Get_IsHolding(mars_items::Rock());
        const auto Shadow = Get_HeldItemShadowMesh();
        UStaticMesh Expected;
        if (IsHolding)
        { Expected = Get_HeldItem().Get_CurrentItem().Get_Presentation().Visual.Mesh.Get(); }

        Log_RealPawnRow(k_Row, f"holding={IsHolding} presentationError={Get_PresentationErrorCm() :.2} firstPersonMount={Get_IsMountFirstPerson()} shadow={Describe_Mesh(Shadow)} expected={Describe_Mesh(Expected)}");
        Assert_True(IsHolding, "the host's own copy holds the rock");
        Assert_True(Get_IsPresentationAtHand(k_HandToleranceCm), "the host's first-person rock sits at its hand");
        Assert_True(Get_IsMountFirstPerson(), "the host's own copy of the hand mount is under its gloves");
        Assert_True(ck::IsValid(Shadow) && Shadow == Expected,
            f"the host's own copy casts the rock's shadow (HeldItemShadow mesh {Describe_Mesh(Shadow)}, the rock's {Describe_Mesh(Expected)})");
        WaitSeconds(k_ServerHoldSeconds + 3.0f, n"OnServerHeld");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    // The client's copy of the host's pawn is composed and holds nothing yet.
    UFUNCTION()
    private void Is_ClientCopyReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto HeldItem = Get_IsPawnComposed() ? Get_HeldItem() : FCk_Handle_HeldItem();
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (ck::IsValid(HeldItem) && ck::Is_NOT_Valid(HeldItem.Get_CurrentItem())));
    }

    UFUNCTION()
    private void OnClientCopyReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPastDeadline() == false)
        {
            auto HeldItem = Get_HeldItem();
            const auto HandWorld = utils_transform::Get_EntityCurrentTransform(HeldItem.Get_HandAttachPoint());
            HeldItem.Request_SetNextSpawnFrom(FMars_Request_HeldItem_SetNextSpawnFrom(FTransform(FRotator::ZeroRotator, k_SpawnFromInHand) * HandWorld));
            _AskedSpawnFrom = true;
        }

        WaitUntil(n"Is_ClientSeesTheRock", n"OnClientChecked", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientSeesTheRock(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Sees = Get_IsPawnComposed() && Get_IsHolding(mars_items::Rock()) && Get_HeldItem().Get_IsPresentationSettled();
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || Sees);
    }

    UFUNCTION()
    private void OnClientChecked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto IsComposed = Get_IsPawnComposed();
        const auto IsHolding = IsComposed && Get_IsHolding(mars_items::Rock());
        const auto IsVisual = IsComposed && Get_IsPresentationVisual();
        const auto IsArriving = IsComposed && Get_IsPresentationArriving();
        const auto FromMount = IsComposed ? Get_PresentationErrorCm() : -1.0;
        const auto FromGrip = IsComposed ? Get_PresentationFromBodyGripCm() : -1.0;
        const auto OnBody = IsComposed && Get_IsMountOnBody();
        const auto Shadow = Get_HeldItemShadowMesh();
        const auto Mesh = IsComposed ? Get_PresentationMeshComponent() : nullptr;
        const auto MeshType = ck::IsValid(Mesh) ? Mesh.FirstPersonPrimitiveType : EFirstPersonPrimitiveType::None;
        const auto MeshName = ck::IsValid(Mesh) ? Describe_Mesh(Mesh.GetStaticMesh()) : "none";
        Log_RealPawnRow(k_Row, f"composed={IsComposed} askedSpawnFrom={_AskedSpawnFrom} holding={IsHolding} visual={IsVisual} arriving={IsArriving} onBody={OnBody} fromMount={FromMount :.2} fromGrip={FromGrip :.2} mesh={MeshName} type={MeshType :n} shadow={Describe_Mesh(Shadow)}");
        Assert_True(_AskedSpawnFrom, "the client asked its copy for a spawn-from pose before the rock arrived");
        Assert_True(IsHolding, "the client's copy of the host's HeldItem holds the rock");
        Assert_True(IsVisual, "the client presents the host's rock by a Visual-mode world item of its own");
        Assert_False(IsArriving, "the client's rock visual has no Arrival in flight");
        Assert_True(OnBody, "the client's copy of the host's hand mount rides the body's grip_r");
        Assert_True(FromMount >= 0.0 && FromMount <= k_HandToleranceCm,
            f"the rock's root sits at HeldOffset on the client's copy of the hand mount, not at the spawn-from pose (error {FromMount :.2} cm; -1: no settled rock in the hand)");
        Assert_True(FromGrip >= 0.0 && FromGrip <= k_GripCm,
            f"the rock is in the host body's right hand on the client ({FromGrip :.2} cm from grip_r)");
        Assert_True(ck::IsValid(Mesh) && ck::IsValid(Mesh.GetStaticMesh()), f"the client's rock visual draws its mesh ({MeshName})");
        Assert_True(MeshType == EFirstPersonPrimitiveType::None, f"the client draws the rock as a world primitive (first-person type {MeshType :n})");
        Assert_False(ck::IsValid(Shadow), f"the client draws no proxy beside the rock (HeldItemShadow mesh {Describe_Mesh(Shadow)})");
        FinishSuccess();
    }
}
