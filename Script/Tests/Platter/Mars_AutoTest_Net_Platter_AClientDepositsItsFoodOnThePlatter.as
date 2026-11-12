// The server's subject holds a meat slab (step 1), and step 2 follows once the platter froze it. At step 1 the client waits
// until its subject's selected food is its slab and deposits it on its platter through the deposit's cue. At step 2 its
// slab rides at the report, its platter holds it and reads it landed, its subject's hotbar no longer holds the slab's item,
// its platter reads one held and one on its books, and its refusal ledger is untouched. The server raised OnLoadAccepted
// once and OnLoaded once, and its subject's hands are empty. The client logs the frames from its deposit to the first frame
// its platter held the slab and to the first it read it landed.
// Surface: Ck.Platter.Net.AS_Platter_AClientDepositsItsFoodOnThePlatter
class UCk_AutoTest_Net_Platter_AClientDepositsItsFoodOnThePlatter : UMars_AutoTestRig_NetPlatter
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 260000.0;

    private FCk_Handle _Food;
    // Client: the deposited piece and its item, and the first sampled frames its platter held it and read it landed.
    private FCk_Handle_FoodPiece _Piece;
    private FCk_Handle_Item _Item;
    private int64 _HoldsFrame = -1;
    private int64 _LandedFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_PlatterRig(InHandle, k_X);
        if (Get_IsServer() == false)
        {
            Begin_Sampling(InHandle);
            Await_Step(1);
        }
    }

    protected void On_ServerPlatterReady() override
    {
        _Food = Spawn_BesideFood(mars_items::Food_MeatSlab(), 1.0);
        Hold_FoodWhenReady(_Food);
    }

    protected void On_ServerFoodHeld() override
    {
        Publish_Location(1, FVector::ZeroVector);
        Await_Frozen(1, 1);
    }

    protected void On_ServerFrozen() override
    {
        Publish_Rides(2);
        WaitSeconds(k_ClientSettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Accepted, 1, "the server's platter raised OnLoadAccepted once");
        Assert_Equals_Int(_Loaded, 1, "the server's platter raised OnLoaded once");
        Assert_True(ck::Is_NOT_Valid(_Carrier.HeldItem.Get_CurrentItem()), "the server's subject's hands are empty");
        End_PlatterServer(f"{Describe_Counts()} {Describe_Signals()} {Describe_PlatterLedger()}");
    }

    protected void On_Sample(TArray<FCk_Handle> InEntities, TArray<FCk_Handle_FoodPiece> InStanding) override
    {
        if (_DepositFrame < 0 || ck::Is_NOT_Valid(_Piece))
        { return; }

        if (_HoldsFrame < 0 && _Platter.Get_HoldsPiece(_Piece))
        { _HoldsFrame = utils_time::Get_FrameCounter(); }

        if (_LandedFrame < 0 && _Platter.Get_HasLanded(_Piece))
        { _LandedFrame = utils_time::Get_FrameCounter(); }
    }

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            WaitUntil(n"Is_ClientHoldsFood", n"OnClientHoldsFood", k_SlowPolls);
            return;
        }

        const auto Slot = Get_PlatterReport().Slot0;
        const auto Piece = Find_PieceById(Slot.Id);
        const auto Fault = Get_RideFault(Piece, Slot);
        Assert_True(Piece == _Piece, "the client's deposited slab is the reported piece");
        Assert_True(Fault.IsEmpty(), f"the client's slab rides at the report ({Fault})");
        Assert_True(_Platter.Get_HoldsPiece(_Piece), "the client's platter holds the slab");
        Assert_True(_Platter.Get_HasLanded(_Piece), "the client's platter reads the slab landed");
        Assert_False(_Carrier.Hotbar.TryGet_SlotIndexOf(_Item).IsSet(), "the client's subject's hotbar no longer holds the slab's item");
        Assert_Equals_Int(_Platter.Get_HeldCount(), 1, "the client's platter reads one held");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 1, "the client's platter reads one on its books");
        Assert_Equals_Int(_Platter.Get_RefusalSerial(), 0, "the client's refusal ledger is untouched");
        End_PlatterClient(f"ride=[{Fault}] depositToHeldFrames={_HoldsFrame - _DepositFrame} depositToLandedFrames={_LandedFrame - _DepositFrame} {Describe_Counts()} {Describe_PlatterLedger()}");
    }

    UFUNCTION()
    private void Is_ClientHoldsFood(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Piece = Get_SelectedFoodPiece();
        auto Result = OutResult;
        Result.Set(ck::IsValid(Piece) && Get_IsNear(Piece, _FloorTop));
    }

    UFUNCTION()
    private void OnClientHoldsFood(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Piece = Get_SelectedFoodPiece();
        _Item = _Carrier.Hotbar.TryGet_SelectedFood();
        Deposit();
        Await_Step(2);
    }
}
