// The server docks the platter on the test station's Input dock and reports once it arrived. On the client the Input dock
// raised OnDocked, then OnArrived, once each; it reads its own copy of the platter, which is Carried by that dock at
// AttachPoint.Mars.Dock and settled; the Output dock raised nothing.
// Surface: Ck.PlatterDock.Net.AS_PlatterDock_ADockedPlatterMountsOnTheClientsDock
class UCk_AutoTest_Net_PlatterDock_ADockedPlatterMountsOnTheClientsDock : UMars_AutoTestRig_NetPlatterDock
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 241000.0;

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
        End_DockServer(f"{Describe_ConstructFrames()} docked=[{Get_DockedFault(_InputDock)}] {Describe_DockEvents()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto IsDockedThenArrived = Get_SignalCount(EMars_PlatterDock_Role::Input) == 2
            && _DockEvents[0].Signal == EMars_TESTONLY_NetDockSignal::Docked
            && _DockEvents[1].Signal == EMars_TESTONLY_NetDockSignal::Arrived;
        const auto Fault = Get_DockedFault(_InputDock);

        Assert_True(IsDockedThenArrived, f"the client's Input dock raised OnDocked then OnArrived, once each ({Describe_DockEvents()})");
        Assert_True(_InputDock.Get_Platter() == _Platter, "the client's Input dock reads its own platter");
        Assert_True(Fault.IsEmpty(), f"the client's platter is Carried by its Input dock, settled ({Fault})");
        Assert_True(_InputDock.Get_HasArrived(), "the client's Input dock says its platter has arrived");
        Assert_Equals_Int(Get_SignalCount(EMars_PlatterDock_Role::Output), 0, "the client's Output dock raised nothing");
        End_DockClient(f"docked=[{Fault}] arrived={_InputDock.Get_HasArrived()} {Describe_DockEvents()}");
    }
}
