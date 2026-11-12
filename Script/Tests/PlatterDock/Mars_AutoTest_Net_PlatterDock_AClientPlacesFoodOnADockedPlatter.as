// The server docks the platter on the test station's Input dock (meat only), its subject holds a meat slab (step 1), and
// step 2 follows once the docked platter froze the slab. At step 1 the client waits until its Input dock offers its subject
// PlaceFood and asks for it through the dock's Act. At step 2 its slab rides its docked platter at the report, and its
// platter reads one held and one on its books. The server's dock and platter ledgers both read serial 0.
// Surface: Ck.PlatterDock.Net.AS_PlatterDock_AClientPlacesFoodOnADockedPlatter
class UCk_AutoTest_Net_PlatterDock_AClientPlacesFoodOnADockedPlatter : UMars_AutoTestRig_NetPlatterDock
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 263000.0;

    private FCk_Handle _Food;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

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
        Dock_Platter(_InputDock);
    }

    protected void On_ServerDocked() override
    {
        _Food = Spawn_BesideFood(mars_items::Food_MeatSlab(), -1.0);
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
        Assert_Equals_Int(_InputDock.Get_RefusalSerial(), 0, "the server's dock ledger reads serial 0");
        Assert_Equals_Int(_Platter.Get_RefusalSerial(), 0, "the server's platter ledger reads serial 0");
        End_DockServer(f"{Describe_Counts()} {Describe_Signals()} dock {Describe_Ledger(_InputDock)} platter {Describe_PlatterLedger()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            WaitUntil(n"Is_ClientOfferedPlaceFood", n"OnClientOfferedPlaceFood", k_SlowPolls);
            return;
        }

        const auto Slot = Get_PlatterReport().Slot0;
        const auto Piece = Find_PieceById(Slot.Id);
        const auto Fault = Get_RideFault(Piece, Slot);
        const auto DockedFault = Get_DockedFault(_InputDock);
        Assert_True(DockedFault.IsEmpty(), f"the client's platter is on its Input dock ({DockedFault})");
        Assert_True(Fault.IsEmpty(), f"the client's slab rides its docked platter at the report ({Fault})");
        Assert_Equals_Int(_Platter.Get_HeldCount(), 1, "the client's platter reads one held");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 1, "the client's platter reads one on its books");
        End_DockClient(f"ride=[{Fault}] docked=[{DockedFault}] {Describe_Counts()} dock {Describe_Ledger(_InputDock)} platter {Describe_PlatterLedger()}");
    }

    UFUNCTION()
    private void Is_ClientOfferedPlaceFood(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_InputDock.Get_ActionFor(Get_SubjectEntity()) == EMars_PlatterDock_Action::PlaceFood);
    }

    UFUNCTION()
    private void OnClientOfferedPlaceFood(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Act(_InputDock, EMars_PlatterDock_Action::PlaceFood);
        Await_Step(2);
    }
}
