// The server has the subject hold the platter (step 1), waits 1.5 s, then asks the empty Input dock for a Place and then a
// Take by the subject in one frame. The Place docks the held platter; the Take arrives while that transfer is in flight and
// is refused UndockRefused in the ledger. Step 2 once the platter arrived. The server raised OnDocked once and OnUndocked
// never. At step 2 the client's dock holds the item, its platter is Carried by its dock and the subject's overflow is
// empty.
// Surface: Ck.PlatterDock.Net.AS_PlatterDock_APlaceAndATakeInOneFrame
class UCk_AutoTest_Net_PlatterDock_APlaceAndATakeInOneFrame : UMars_AutoTestRig_NetPlatterDock
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 254000.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_PlatterRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(2); }
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
        WaitSeconds(k_StepGapSeconds, n"OnServerGap");
    }

    UFUNCTION()
    private void OnServerGap(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _InputDock.Request_Act(FMars_Request_PlatterDock_Act(Get_SubjectEntity(), EMars_PlatterDock_Action::Place));
        _InputDock.Request_Act(FMars_Request_PlatterDock_Act(Get_SubjectEntity(), EMars_PlatterDock_Action::Take));
        Await_Arrived(_InputDock);
    }

    protected void On_ServerDocked() override
    {
        const auto Docked = Get_Count(EMars_PlatterDock_Role::Input, EMars_TESTONLY_NetDockSignal::Docked);
        const auto Undocked = Get_Count(EMars_PlatterDock_Role::Input, EMars_TESTONLY_NetDockSignal::Undocked);
        Assert_Equals_Int(Docked, 1, "the server's Input dock raised OnDocked once");
        Assert_Equals_Int(Undocked, 0, "the server's Input dock never undocked");
        Assert_Equals_Int(_InputDock.Get_RefusalSerial(), 1, "the server's ledger refused one Act");
        Assert_True(_InputDock.Get_LastRefusal() == EMars_Interaction_FailReason::UndockRefused,
            f"the server's ledger says UndockRefused (got [{_InputDock.Get_LastRefusal() :n}])");
        Publish_Location(2, FVector::ZeroVector);
        End_DockServer(f"docked={Docked} undocked={Undocked} {Describe_Ledger(_InputDock)} {Describe_DockEvents()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Fault = Get_DockedFault(_InputDock);
        const auto OverflowEmpty = ck::Is_NOT_Valid(Get_OverflowItem());
        Assert_True(_InputDock.Get_Item() == Get_PlatterItem(), "the client's Input dock holds the platter's item");
        Assert_True(Fault.IsEmpty(), f"the client's platter is Carried by its own Input dock ({Fault})");
        Assert_True(OverflowEmpty, "the subject's overflow is empty on the client");
        End_DockClient(f"docked=[{Fault}] overflowEmpty={OverflowEmpty} {Describe_Ledger(_InputDock)} {Describe_DockEvents()}");
    }
}
