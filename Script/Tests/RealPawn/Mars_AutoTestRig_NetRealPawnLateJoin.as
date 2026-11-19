// The late-join rows' shared steps, on the real-pawn rig. The harness's client exists from the start, so a late join is
// made from relevancy: the client stands at the base in the viewer (its own pawn), and the server spawns the host's pawn
// at the far spot, k_FarFromBase away, beyond the pawn class's net cull distance (150 m), so the client has no copy of it.
// There the host's own controller possesses it and it picks up the row's item (Get_Definition). Once it holds the item
// settled in its hand, the server moves the pawn to the base: the client's copy of it is created then, after the hold,
// and derives everything it shows from what has replicated (the hotbar's selection and items; a persistent item's body).
// The client records whether it ever had a copy of a pawn near the far spot, so a row whose pawn was never culled says
// so instead of passing as a late join. Each subclass names the item, its base and how its presentation is checked.
UCLASS(Abstract)
class UMars_AutoTestRig_NetRealPawnLateJoin : UMars_AutoTestRig_NetRealPawn
{
    protected const FVector k_FarFromBase = FVector(0.0, 40000.0, 0.0);
    // A pawn this near the far spot is the host's pawn before it moved.
    protected const float64 k_FarSpotRadiusCm = 2000.0;
    protected const float64 k_HandToleranceCm = 5.0;
    protected const float64 k_GripCm = 30.0;
    // The client checks this long after its copy first shows the item settled in the hand.
    protected const float32 k_ClientLookSeconds = 0.5f;

    private AStaticMeshActor _FarFloor;
    private bool _SawFarCopy = false;

    protected UCk_InventoryItem_Definition Get_Definition()
    {
        return nullptr;
    }

    protected FString Get_Row()
    {
        return "";
    }

    // The row's own checks of the client's copy of the held presentation, after the shared ones.
    protected void DoAssert_ClientPresentation()
    {
    }

    protected FVector Get_FarSpot()
    {
        return _Base + k_FarFromBase;
    }

    protected void Begin_LateJoin(FCk_Handle InHandle, FVector InBase)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(InBase);

        if (Get_IsServer() == false)
        {
            Mark_Deadline(24.0);
            WaitUntil(n"Is_ClientSeesTheLateCopyHolding", n"OnClientSeesTheLateCopy", k_SlowPolls);
            return;
        }

        Spawn_FarFloor();
        Spawn_ServerPawn();
        if (ck::IsValid(_Pawn))
        { _Pawn.SetActorLocation(Get_FarSpot() + Get_FeetToCentre()); }

        Spawn_ServerViewer();
        Spawn_ServerJoltFloorAt(InHandle, Get_FarSpot());
        WaitUntil(n"Is_ServerPawnAndOwnerReady", n"OnLateServerComposed", k_SlowPolls);
    }

    private FVector Get_FeetToCentre()
    {
        return FVector(0.0, 0.0, float64(mars::Mars_PlayerCharacter_Config.Body.CapsuleHalfHeight) + 2.0);
    }

    // Server: an engine cube slab at the far spot, its top at the spot's Z (the base's floor is too far away).
    private void Spawn_FarFloor()
    {
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_TestWorld());
        auto Cube = Cast<UStaticMesh>(LoadObject(UStaticMesh, "/Engine/BasicShapes/Cube.Cube"));
        _FarFloor = Cast<AStaticMeshActor>(SpawnActor(AStaticMeshActor, Get_FarSpot() - FVector(0.0, 0.0, 50.0)));
        if (ck::Is_NOT_Valid(_FarFloor) || ck::Is_NOT_Valid(Cube))
        {
            FinishFailure("the far floor block (the engine cube) did not spawn");
            return;
        }

        _FarFloor.StaticMeshComponent.SetMobility(EComponentMobility::Movable);
        _FarFloor.StaticMeshComponent.SetStaticMesh(Cube);
        _FarFloor.SetActorScale3D(FVector(20.0, 20.0, 1.0));
    }

    protected void TearDown() override
    {
        if (ck::IsValid(_FarFloor))
        { _FarFloor.DestroyActor(); }

        _FarFloor = nullptr;
        Super::TearDown();
    }

    //------------------------------------------------------------------------------------------------------------------
    // Server
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnLateServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ComposeSeconds, n"OnLateServerComposeWaited");
    }

    UFUNCTION()
    private void OnLateServerComposeWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Request_ServerPossessByLocal(_Pawn) == false)
        { FinishFailure("the server's world has not exactly one local player controller"); return; }

        Spawn_ServerWorldItem(Get_Definition(), Get_FarSpot() + k_ItemFromBase);
        Mark_Deadline(14.0);
        WaitUntil(n"Is_LateServerReadyToPickUp", n"OnLateServerReadyToPickUp", k_SlowPolls);
    }

    private FCk_Handle_WorldItem _Item;

    UFUNCTION()
    private void Is_LateServerReadyToPickUp(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Item = Find_WorldItemNear(Get_Definition(), Get_FarSpot() + k_ItemFromBase, 100.0);
        const auto Hotbar = _Player.As_Hotbar(ECk_SanityCheck::UnChecked);
        const auto IsReady = _Pawn.IsLocallyControlled() && Get_IsStateActive(UMars_SmState_Loco_Idle) && ck::IsValid(Hotbar)
            && Hotbar.Get_IsReady() && Get_IsMountFirstPerson() && ck::IsValid(_Item);
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || IsReady);
    }

    UFUNCTION()
    private void OnLateServerReadyToPickUp(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPastDeadline())
        {
            Log_RealPawnRow(Get_Row(), f"item={ck::IsValid(_Item)} firstPersonMount={Get_IsMountFirstPerson()}");
            FinishFailure("the host's pawn, its hotbar, its first-person mount or the item was not ready at the far spot");
            return;
        }

        _Item.Request_PickUp(FMars_Request_WorldItem_PickUp(_Player));
        WaitUntil(n"Is_LateServerHolding", n"OnLateServerHolding", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_LateServerHolding(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (Get_IsHolding(Get_Definition()) && Get_IsPresentationAtHand(k_HandToleranceCm)));
    }

    // The host holds the item: only now does its pawn come where the client can see it.
    UFUNCTION()
    private void OnLateServerHolding(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto IsHolding = Get_IsHolding(Get_Definition());
        Log_RealPawnRow(Get_Row(), f"holding={IsHolding} presentationError={Get_PresentationErrorCm() :.2} firstPersonMount={Get_IsMountFirstPerson()} at={_Pawn.GetActorLocation()}");
        Assert_True(IsHolding && Get_IsPresentationAtHand(k_HandToleranceCm), "the host holds the item at its hand at the far spot");

        _Pawn.SetActorLocation(_Base + Get_FeetToCentre());
        WaitSeconds(k_ServerHoldSeconds + 6.0f, n"OnServerHeld");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Is_ClientSeesTheLateCopyHolding(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Get_HasPawnNear(Get_FarSpot(), k_FarSpotRadiusCm))
        { _SawFarCopy = true; }

        const auto HeldItem = Get_IsPawnComposed() ? Get_HeldItem() : FCk_Handle_HeldItem();
        const auto Sees = ck::IsValid(HeldItem) && Get_IsHolding(Get_Definition()) && Get_IsPresentationAtHand(k_HandToleranceCm);
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || Sees);
    }

    UFUNCTION()
    private void OnClientSeesTheLateCopy(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPastDeadline())
        {
            OnClientChecked(InTimer, InChrono, InDeltaT);
            return;
        }

        WaitSeconds(k_ClientLookSeconds, n"OnClientChecked");
    }

    UFUNCTION()
    private void OnClientChecked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto IsComposed = Get_IsPawnComposed();
        const auto IsHolding = IsComposed && Get_IsHolding(Get_Definition());
        const auto FromMount = IsComposed ? Get_PresentationErrorCm() : -1.0;
        const auto FromGrip = IsComposed ? Get_PresentationFromBodyGripCm() : -1.0;
        const auto OnBody = IsComposed && Get_IsMountOnBody();
        const auto IsArriving = IsComposed && Get_IsPresentationArriving();
        const auto Shadow = Get_HeldItemShadowMesh();
        Log_RealPawnRow(Get_Row(), f"composed={IsComposed} sawFarCopy={_SawFarCopy} holding={IsHolding} visual={IsComposed && Get_IsPresentationVisual()} arriving={IsArriving} onBody={OnBody} fromMount={FromMount :.2} fromGrip={FromGrip :.2} shadow={Describe_Mesh(Shadow)}");
        Assert_False(_SawFarCopy, "the client had no copy of the host's pawn at the far spot: its copy was made after the hold (a late join)");
        Assert_True(IsComposed, "the client's late copy of the host's pawn composed at the base");
        Assert_True(IsHolding, f"the client's late copy of the host's HeldItem holds the {Get_Definition().GetName().ToString()}");
        Assert_False(IsArriving, "the client's late copy's held presentation has no Arrival in flight");
        Assert_True(OnBody, "the client's late copy of the host's hand mount rides the body's grip_r");
        Assert_True(FromMount >= 0.0 && FromMount <= k_HandToleranceCm,
            f"the item's root sits at HeldOffset on the late copy's hand mount (error {FromMount :.2} cm; -1: no settled item in the hand)");
        Assert_True(FromGrip >= 0.0 && FromGrip <= k_GripCm,
            f"the item is in the host body's right hand on the client ({FromGrip :.2} cm from grip_r)");
        Assert_False(ck::IsValid(Shadow), f"the late copy draws no proxy beside the item (HeldItemShadow mesh {Describe_Mesh(Shadow)})");
        if (IsHolding)
        { DoAssert_ClientPresentation(); }

        FinishSuccess();
    }

    // An AMars_PlayerCharacter in this machine's world within InRadius of InSpot.
    private bool Get_HasPawnNear(FVector InSpot, float64 InRadius)
    {
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_TestWorld());
        auto Pawns = TArray<AActor>();
        Gameplay::GetAllActorsOfClass(AMars_PlayerCharacter, Pawns);
        for (auto Actor : Pawns)
        {
            if (ck::IsValid(Actor) && (Actor.GetActorLocation() - InSpot).Size() < InRadius)
            { return true; }
        }

        return false;
    }

    // Every primitive of the client's held presentation is drawn as a world primitive; at least one.
    protected void Assert_PresentationIsWorldPrimitive()
    {
        auto Count = 0;
        auto Wrong = "";
        for (auto Primitive : utils_fphands::Get_TreePrimitives(Get_HeldItem().Get_PresentationEntity()))
        {
            Count += 1;
            if (Primitive.FirstPersonPrimitiveType != EFirstPersonPrimitiveType::None)
            { Wrong += f"{Primitive.GetName()}({Primitive.FirstPersonPrimitiveType :n}) "; }
        }

        Assert_True(Count >= 1 && Wrong.IsEmpty(), f"the late copy draws the item as world primitives ({Count}; not None: {Wrong})");
    }
}
