// The server spawns the real cutting station, docks the empty platter on its Output dock, makes a meat slab Kinematic and
// places it on the board (step 1 once the board holds it), waits 1.5 s and sweeps the board onto the docked tray (step 2
// once the tray froze the slab). At step 1 the client's board holds one and its tray none; at step 2 its board holds none,
// its tray holds one with one on its books, the slab rides its tray at the report and the label no longer says "no tray".
// Surface: Ck.PlatterDock.Net.AS_PlatterDock_ASweepLandsOnTheClientsTray
class UCk_AutoTest_Net_PlatterDock_ASweepLandsOnTheClientsTray : UMars_AutoTestRig_NetPlatterDock
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 249000.0;

    private FCk_Handle _Slab;
    private FString _StepOneText;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        _StationKind = EMars_TESTONLY_NetDockStationKind::CuttingStation;
        Begin_PlatterRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1); }
    }

    protected void On_ServerPlatterReady() override
    {
        Spawn_ServerStation();
    }

    protected void On_ServerDocksReady() override
    {
        Dock_Platter(_OutputDock);
    }

    protected void On_ServerDocked() override
    {
        _Slab = Spawn_BesideFood(mars_items::Food_MeatSlab(), -1.0);
        WaitUntil(n"Is_SlabKinematic", n"OnSlabKinematic", k_SlowPolls);
    }

    // The SetMotionType handler drops a request that reaches a body not added yet: ask until the body reads it.
    UFUNCTION()
    private void Is_SlabKinematic(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsFoodReady(_Slab) && Ask_Kinematic());
    }

    private bool Ask_Kinematic()
    {
        auto Body = _Slab.As_WorldItem().Get_Body();
        if (ck::Is_NOT_Valid(Body) || utils_jolt_body::Get_IsBodyAdded(Body) == false)
        { return false; }

        if (utils_jolt_body::Get_MotionType(Body) == ECk_MotionType::Kinematic)
        { return true; }

        utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Kinematic));
        return false;
    }

    UFUNCTION()
    private void OnSlabKinematic(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Board = _Station.As_FoodBoard();
        Board.Request_Place(FMars_Request_FoodBoard_Place(_Slab.As_FoodPiece()));
        WaitUntil(n"Is_SlabOnBoard", n"OnSlabOnBoard", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_SlabOnBoard(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Station.As_FoodBoard().Get_HeldCount() == 1);
    }

    UFUNCTION()
    private void OnSlabOnBoard(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_Location(1, FVector::ZeroVector);
        WaitSeconds(k_StepGapSeconds, n"OnServerSweepGap");
    }

    UFUNCTION()
    private void OnServerSweepGap(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        utils_cooking_feed::Request_TakeOutToDock(_Station, _OutputDock);
        Await_Frozen(1, 1);
    }

    protected void On_ServerFrozen() override
    {
        Publish_Rides(2);
        const auto Label = Get_ShownLabel().Replace("\n", " / ");
        End_DockServer(f"board={_Station.As_FoodBoard().Get_HeldCount()} {Describe_Counts()} label=[{Label}] {Describe_DockEvents()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Board = _Station.As_FoodBoard();
        const auto Tray = _OutputDock.Get_Platter();
        if (InStep == 1)
        {
            Assert_Equals_Int(Board.Get_HeldCount(), 1, "step 1: the client's board holds one");
            Assert_True(ck::IsValid(Tray) && Tray.Get_HeldCount() == 0, "step 1: the client's tray holds none");
            const auto TrayHeld = ck::IsValid(Tray) ? Tray.Get_HeldCount() : -1;
            _StepOneText = f"step1 board={Board.Get_HeldCount()} trayHeld={TrayHeld}";
            Await_Step(2);
            return;
        }

        const auto Slot = Get_PlatterReport().Slot0;
        const auto Fault = Get_RideFault(Find_PieceById(Slot.Id), Slot);
        const auto Label = Get_ShownLabel();
        Assert_Equals_Int(Board.Get_HeldCount(), 0, "step 2: the client's board holds none");
        Assert_True(ck::IsValid(Tray) && Tray == _Platter, "step 2: the client's tray is its platter");
        Assert_Equals_Int(_Platter.Get_HeldCount(), 1, "step 2: the client's tray holds one");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 1, "step 2: the client's tray has one on its books");
        Assert_True(Fault.IsEmpty(), f"step 2: the slab rides the client's tray at the report ({Fault})");
        Assert_False(Label.Contains("no tray"), f"step 2: the client's label does not say no tray ({Label})");
        const auto ShownLabel = Label.Replace("\n", " / ");
        End_DockClient(f"{_StepOneText} step2 board={Board.Get_HeldCount()} {Describe_Counts()} rides=[{Fault}] label=[{ShownLabel}] {Describe_DockEvents()}");
    }
}
