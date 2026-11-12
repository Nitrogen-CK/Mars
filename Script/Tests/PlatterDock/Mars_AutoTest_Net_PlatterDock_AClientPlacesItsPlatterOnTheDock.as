// The server has the subject hold the platter (step 1). The client, once its platter is Held by the subject and its Input
// dock offers Place, asks for the Place through the dock's Act; the authority docks the held platter and step 2 follows
// once it arrived. At step 2 the client's Input dock holds the item, raised OnDocked once then OnArrived once, its platter
// is Carried by its own dock and its refusal ledger never moved. The server raised OnDocked once, refused nothing and the
// subject's overflow is empty.
// Surface: Ck.PlatterDock.Net.AS_PlatterDock_AClientPlacesItsPlatterOnTheDock
class UCk_AutoTest_Net_PlatterDock_AClientPlacesItsPlatterOnTheDock : UMars_AutoTestRig_NetPlatterDock
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 250000.0;

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
        Hold_Platter(Get_PlatterWorldItem());
    }

    protected void On_ServerHeld() override
    {
        Publish_Location(1, FVector::ZeroVector);
        Await_Arrived(_InputDock);
    }

    protected void On_ServerDocked() override
    {
        const auto Docked = Get_Count(EMars_PlatterDock_Role::Input, EMars_TESTONLY_NetDockSignal::Docked);
        const auto Refused = Get_Count(EMars_PlatterDock_Role::Input, EMars_TESTONLY_NetDockSignal::DockRefused);
        const auto OverflowEmpty = ck::Is_NOT_Valid(Get_OverflowItem());
        Assert_Equals_Int(Docked, 1, "the server's Input dock raised OnDocked once");
        Assert_Equals_Int(Refused, 0, "the server's Input dock refused nothing");
        Assert_Equals_Int(_InputDock.Get_RefusalSerial(), 0, "the server's ledger refused no Act");
        Assert_True(OverflowEmpty, "the subject's overflow is empty on the server");
        Publish_Location(2, FVector::ZeroVector);
        End_DockServer(f"docked={Docked} overflowEmpty={OverflowEmpty} {Describe_Ledger(_InputDock)} {Describe_DockEvents()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            WaitUntil(n"Is_PlaceOffered", n"OnPlaceOffered", k_SlowPolls);
            return;
        }

        const auto Fault = Get_DockedFault(_InputDock);
        const auto Order = Describe_DockEvents();
        Assert_True(_InputDock.Get_Item() == Get_PlatterItem(), "the client's Input dock holds the platter's item");
        Assert_Equals_Int(Get_SignalCount(EMars_PlatterDock_Role::Input), 2, f"the client's Input dock raised two signals ({Order})");
        Assert_True(_DockEvents.Num() == 2 && _DockEvents[0].Signal == EMars_TESTONLY_NetDockSignal::Docked
            && _DockEvents[1].Signal == EMars_TESTONLY_NetDockSignal::Arrived, f"OnDocked once, then OnArrived once ({Order})");
        Assert_True(Fault.IsEmpty(), f"the client's platter is Carried by its own Input dock ({Fault})");
        Assert_Equals_Int(_InputDock.Get_RefusalSerial(), 0, "the client's ledger serial is 0");
        End_DockClient(f"docked=[{Fault}] {Describe_ActFrames()} {Describe_Ledger(_InputDock)} {Order}");
    }

    UFUNCTION()
    private void Is_PlaceOffered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_HeldFault().IsEmpty() && _InputDock.Get_ActionFor(Get_SubjectEntity()) == EMars_PlatterDock_Action::Place);
    }

    UFUNCTION()
    private void OnPlaceOffered(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Act(_InputDock, EMars_PlatterDock_Action::Place);
        WaitUntil(n"Is_Placed", n"OnPlaced", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_Placed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Placed = _InputDock.Get_Item() == Get_PlatterItem();
        if (Placed)
        { Record_EffectFrame(); }

        auto Result = OutResult;
        Result.Set(Placed);
    }

    UFUNCTION()
    private void OnPlaced(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Await_Step(2);
    }
}
