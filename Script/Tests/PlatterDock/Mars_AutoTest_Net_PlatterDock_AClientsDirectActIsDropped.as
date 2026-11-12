// The server docks the platter on the Input dock (step 1) and watches 6 s. The client bypasses the cue and asks its own
// copy of the dock for a Take: its drain drops the request (it has no authority), so 1.5 s later its dock still holds the
// item, its ledger's serial is 0 and the subject's overflow is empty; at the end the server's dock is still docked, its
// ledger untouched, and it raised nothing but the first OnDocked and OnArrived.
// Surface: Ck.PlatterDock.Net.AS_PlatterDock_AClientsDirectActIsDropped
class UCk_AutoTest_Net_PlatterDock_AClientsDirectActIsDropped : UMars_AutoTestRig_NetPlatterDock
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 256000.0;
    private const float32 k_WatchSeconds = 6.0f;
    private const float32 k_DroppedSeconds = 1.5f;

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
        Publish_Location(1, FVector::ZeroVector);
        WaitSeconds(k_WatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Order = Describe_DockEvents();
        Assert_True(_InputDock.Get_Item() == Get_PlatterItem(), "the server's Input dock is still docked");
        Assert_Equals_Int(_InputDock.Get_RefusalSerial(), 0, "the server's ledger refused no Act");
        Assert_True(_DockEvents.Num() == 2 && _DockEvents[0].Signal == EMars_TESTONLY_NetDockSignal::Docked
            && _DockEvents[1].Signal == EMars_TESTONLY_NetDockSignal::Arrived, f"the server's docks raised only the first OnDocked and OnArrived ({Order})");
        End_DockServer(f"docked=[{Get_DockedFault(_InputDock)}] {Describe_Ledger(_InputDock)} {Order}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        _InputDock.Request_Act(FMars_Request_PlatterDock_Act(Get_SubjectEntity(), EMars_PlatterDock_Action::Take));
        WaitSeconds(k_DroppedSeconds, n"OnClientDropped");
    }

    UFUNCTION()
    private void OnClientDropped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto OverflowEmpty = ck::Is_NOT_Valid(Get_OverflowItem());
        Assert_True(_InputDock.Get_Item() == Get_PlatterItem(), "the client's Input dock still holds the item");
        Assert_Equals_Int(_InputDock.Get_RefusalSerial(), 0, "the client's ledger serial is 0");
        Assert_True(OverflowEmpty, "the subject's overflow is empty on the client");
        End_DockClient(f"docked=[{Get_DockedFault(_InputDock)}] overflowEmpty={OverflowEmpty} {Describe_Ledger(_InputDock)} {Describe_DockEvents()}");
    }
}
