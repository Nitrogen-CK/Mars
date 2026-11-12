// The server slices a meat slab lying beside a platter by hand and spawns its positive half; in the continuation in which
// that half first is a FoodPiece it stamps the platter as its holder, attaches it under the platter's root at (0, 0, 6)
// and stamps that ride (step 1), holds 4 s, then clears the holder. On the client the half, whose ledger may say it rides
// before the replay built it, rides its platter at (0, 0, 6) within 10 frames of becoming a FoodPiece.
// Surface: Ck.Platter.Net.AS_Platter_ALateBuiltPieceRidesFromItsFirstLedger
class UCk_AutoTest_Net_Platter_ALateBuiltPieceRidesFromItsFirstLedger : UMars_AutoTestRig_NetPlatter
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 236000.0;
    private const FVector k_RideLocation = FVector(0.0, 0.0, 6.0);
    private const float32 k_HoldSeconds = 4.0f;
    private const int32 k_MaxRideFrames = 10;

    // Client: sampled frames the half appeared, first was a FoodPiece and first rode (-1 until then), and whether its ledger
    // said it rides in a frame before it was a FoodPiece.
    private int32 _AppearFrame = -1;
    private int32 _PieceFrame = -1;
    private int32 _RideFrame = -1;
    private bool _RidingBeforePiece = false;
    private FString _LastFault;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_PlatterRig(InHandle, k_X);
        if (Get_IsServer() == false)
        {
            Begin_Sampling(InHandle);
            WaitUntil(n"Is_ClientDone", n"OnClientDone", k_SlowPolls);
        }
    }

    protected void On_ServerPlatterReady() override
    {
        _Rock = Spawn_BesideFood(mars_items::Food_MeatSlab(), 1.0);
        WaitUntil(n"Is_ServerSlabStill", n"OnServerSlabStill", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSlabStill(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Tick_SlabReadyAndStill());
    }

    UFUNCTION()
    private void OnServerSlabStill(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_ByHandHalves();
    }

    protected void On_ServerHalvesHeld() override
    {
        Spawn_P();
        WaitUntil(n"Is_ServerHalfPiece", n"OnServerHalfPiece", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerHalfPiece(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsLive(_SpawnedP) && _SpawnedP.Is_FoodPiece());
    }

    UFUNCTION()
    private void OnServerHalfPiece(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Piece = _SpawnedP.As_FoodPiece();
        const auto Offset = FTransform(FRotator::ZeroRotator, k_RideLocation);
        utils_foodpiece::Stamp_Holder(Piece, _Platter);
        auto PieceTransform = _SpawnedP.As_Transform();
        auto Root = Get_PlatterRoot();
        utils_scene_node::Add(PieceTransform, Root, Offset);
        utils_foodpiece::Stamp_Ride(Piece, _Platter, Offset);

        auto Report = Get_PlatterReport();
        Report.Step = 1;
        Report.Count = 1;
        Report.Slot0 = Make_Slot(Piece, Offset);
        Write_PlatterReport(Report);
        WaitSeconds(k_HoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Piece = _SpawnedP.As_FoodPiece();
        const auto OnRoot = Get_IsOnPlatterRoot(Piece);
        utils_foodpiece::Clear_Holder(Piece, _Platter);
        End_PlatterServer(f"onRoot={OnRoot} {Describe_Counts()} {Describe_Signals()}");
    }

    protected void On_Sample(TArray<FCk_Handle> InEntities, TArray<FCk_Handle_FoodPiece> InStanding) override
    {
        Try_FindPlatter();
        const auto Half = Find_ByKept(Get_PieceEntitiesNear(_FloorTop), EMars_FoodPiece_CutSide::Positive);
        if (ck::Is_NOT_Valid(Half))
        { return; }

        if (_AppearFrame < 0)
        { _AppearFrame = _SampleFrame; }

        if (Half.Is_FoodPiece() == false)
        {
            const auto Ledger = utils_foodpiece::TryGet_Ledger(Half);
            if (Ledger.IsSet() && Ledger.GetValue().Holding == EMars_FoodPiece_Holding::Held && Ledger.GetValue().Riding == EMars_FoodPiece_Riding::Riding)
            { _RidingBeforePiece = true; }

            return;
        }

        if (_PieceFrame < 0)
        { _PieceFrame = _SampleFrame; }

        if (_RideFrame >= 0 || ck::Is_NOT_Valid(_Platter))
        { return; }

        auto Slot = FMars_TESTONLY_NetPlatterSlot();
        Slot.RideLocation = k_RideLocation;
        _LastFault = Get_RideFault(Half.As_FoodPiece(), Slot);
        if (_LastFault.IsEmpty())
        { _RideFrame = _SampleFrame; }
    }

    UFUNCTION()
    private void Is_ClientDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsDecided = _RideFrame >= 0 || (_PieceFrame >= 0 && _SampleFrame - _PieceFrame > k_MaxRideFrames);
        auto Result = OutResult;
        Result.Set(Get_IsStepArrived(1) && IsDecided);
    }

    UFUNCTION()
    private void OnClientDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto RideFrames = _RideFrame >= 0 ? _RideFrame - _PieceFrame : -1;
        Assert_True(_RideFrame >= 0 && RideFrames <= k_MaxRideFrames,
            f"the half rides its platter at (0, 0, 6) within {k_MaxRideFrames} frames of becoming a FoodPiece (took {RideFrames}; last fault: {_LastFault})");
        End_PlatterClient(f"appear={_AppearFrame} piece={_PieceFrame} ride={_RideFrame} rideFrames={RideFrames} ridingBeforePiece={_RidingBeforePiece} lastFault=[{_LastFault}]");
    }
}
