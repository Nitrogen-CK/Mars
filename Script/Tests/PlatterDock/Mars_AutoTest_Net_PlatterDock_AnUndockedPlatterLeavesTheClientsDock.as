// The server docks the platter on the Input dock (step 1), waits 1.5 s and undocks it into the subject's stow target
// (step 2 once it is Held). At step 2 the client's Input dock raised OnUndocked once, is empty and reads no platter, and
// its own copy of the platter is Held by the subject on its own hand.
// Surface: Ck.PlatterDock.Net.AS_PlatterDock_AnUndockedPlatterLeavesTheClientsDock
class UCk_AutoTest_Net_PlatterDock_AnUndockedPlatterLeavesTheClientsDock : UMars_AutoTestRig_NetPlatterDock
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 242000.0;

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
        Undock_ToSubject(_InputDock);
    }

    protected void On_ServerUndocked() override
    {
        Publish_Location(2, FVector::ZeroVector);
        End_DockServer(f"held=[{Get_HeldFault()}] {Describe_DockEvents()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Fault = Get_HeldFault();
        Assert_Equals_Int(Get_Count(EMars_PlatterDock_Role::Input, EMars_TESTONLY_NetDockSignal::Undocked), 1, "the client's Input dock raised OnUndocked once");
        Assert_False(_InputDock.Get_IsOccupied(), "the client's Input dock is empty");
        Assert_True(ck::Is_NOT_Valid(_InputDock.Get_Platter()), "the client's Input dock reads no platter");
        Assert_True(Fault.IsEmpty(), f"the client's platter is Held by the subject on its own hand ({Fault})");
        End_DockClient(f"held=[{Fault}] occupied={_InputDock.Get_IsOccupied()} {Describe_DockEvents()}");
    }
}
