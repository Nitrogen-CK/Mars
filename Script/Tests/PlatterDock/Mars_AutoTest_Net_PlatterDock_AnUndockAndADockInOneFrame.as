// The server docks the platter on the Input dock (step 1), waits 1.5 s, then in one frame asks the Input dock to undock it
// to the subject and to dock the same item. The drain refuses the dock (Occupied) and the undock lands: step 2 once the
// platter is Held. At step 2 the client's Input dock is empty, raised OnUndocked once and OnDocked once in all, and its own
// platter is Held by the subject.
// Surface: Ck.PlatterDock.Net.AS_PlatterDock_AnUndockAndADockInOneFrame
class UCk_AutoTest_Net_PlatterDock_AnUndockAndADockInOneFrame : UMars_AutoTestRig_NetPlatterDock
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 245000.0;

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
        Dock_Platter(_InputDock);
    }

    protected void On_ServerDocked() override
    {
        Publish_Location(1, FVector::ZeroVector);
        WaitSeconds(k_StepGapSeconds, n"OnServerGap");
    }

    UFUNCTION()
    private void OnServerGap(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Item = Get_PlatterItem();
        Request_UndockToSubject(_InputDock);
        _InputDock.Request_Dock(FMars_Request_PlatterDock_Dock(Item));
        Await_Undocked();
    }

    protected void On_ServerUndocked() override
    {
        const auto Refused = Get_Count(EMars_PlatterDock_Role::Input, EMars_TESTONLY_NetDockSignal::DockRefused);
        auto RefusalIsOccupied = false;
        auto RefusalBeforeUndock = false;
        for (int32 Index = 0; Index < _DockEvents.Num(); ++Index)
        {
            if (_DockEvents[Index].Signal != EMars_TESTONLY_NetDockSignal::DockRefused)
            { continue; }

            RefusalIsOccupied = _DockEvents[Index].Refusal == EMars_PlatterDock_Refusal::Occupied;
            for (int32 Later = Index + 1; Later < _DockEvents.Num(); ++Later)
            {
                if (_DockEvents[Later].Signal == EMars_TESTONLY_NetDockSignal::Undocked)
                { RefusalBeforeUndock = true; }
            }
        }

        Assert_Equals_Int(Refused, 1, "the server's Input dock refused the dock once");
        Assert_True(RefusalIsOccupied, "the refusal is Occupied");
        Assert_True(RefusalBeforeUndock, f"the refusal came before the undock landed ({Describe_DockEvents()})");
        Publish_Location(2, FVector::ZeroVector);
        End_DockServer(f"refused={Refused} occupied={RefusalIsOccupied} beforeUndock={RefusalBeforeUndock} {Describe_DockEvents()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Fault = Get_HeldFault();
        const auto DockedInAll = Get_Count(EMars_PlatterDock_Role::Input, EMars_TESTONLY_NetDockSignal::Docked)
            + Get_Count(EMars_PlatterDock_Role::Output, EMars_TESTONLY_NetDockSignal::Docked);

        Assert_False(_InputDock.Get_IsOccupied(), "the client's Input dock is empty");
        Assert_True(Fault.IsEmpty(), f"the client's platter is Held by the subject ({Fault})");
        Assert_Equals_Int(Get_Count(EMars_PlatterDock_Role::Input, EMars_TESTONLY_NetDockSignal::Undocked), 1, "the client's Input dock raised OnUndocked once");
        Assert_Equals_Int(DockedInAll, 1, "the client's docks raised OnDocked once in all");
        End_DockClient(f"held=[{Fault}] dockedInAll={DockedInAll} {Describe_DockEvents()}");
    }
}
