// The platter is ready first; then the server spawns the test station and docks the platter on its Input dock in the
// continuation in which it first finds its docks composed, and holds 4 s. The client binds when its own docks compose and
// 2 s later reads its own platter on its Input dock, arrived; its Input dock raised OnDocked and OnArrived at most once
// each and OnUndocked never.
// Surface: Ck.PlatterDock.Net.AS_PlatterDock_ALateBinderReadsTheDockAsItStands
class UCk_AutoTest_Net_PlatterDock_ALateBinderReadsTheDockAsItStands : UMars_AutoTestRig_NetPlatterDock
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 244000.0;
    private const float32 k_DockHoldSeconds = 4.0f;
    private const float32 k_ClientWaitSeconds = 2.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_PlatterRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { WaitUntil(n"Is_ClientDocksFound", n"OnClientDocksFound", k_SlowPolls); }
    }

    protected void On_ServerPlatterReady() override
    {
        Spawn_ServerStation();
    }

    protected void On_ServerDocksReady() override
    {
        _InputDock.Request_Dock(FMars_Request_PlatterDock_Dock(Get_PlatterItem()));
        WaitSeconds(k_DockHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_InputDock.Get_HasArrived(), "the server's platter arrived on its Input dock");
        End_DockServer(f"{Describe_ConstructFrames()} arrived={_InputDock.Get_HasArrived()} {Describe_DockEvents()}");
    }

    UFUNCTION()
    private void Is_ClientDocksFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Try_FindDocks() && Try_FindPlatter());
    }

    UFUNCTION()
    private void OnClientDocksFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientWaitSeconds, n"OnClientWaited");
    }

    UFUNCTION()
    private void OnClientWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Docked = Get_Count(EMars_PlatterDock_Role::Input, EMars_TESTONLY_NetDockSignal::Docked);
        const auto Arrived = Get_Count(EMars_PlatterDock_Role::Input, EMars_TESTONLY_NetDockSignal::Arrived);
        const auto Undocked = Get_Count(EMars_PlatterDock_Role::Input, EMars_TESTONLY_NetDockSignal::Undocked);

        Assert_True(_InputDock.Get_Platter() == _Platter, "the client's Input dock reads its own platter");
        Assert_True(_InputDock.Get_HasArrived(), "the client's Input dock says its platter has arrived");
        Assert_True(Docked <= 1, f"the client's Input dock raised OnDocked at most once (got {Docked})");
        Assert_True(Arrived <= 1, f"the client's Input dock raised OnArrived at most once (got {Arrived})");
        Assert_Equals_Int(Undocked, 0, "the client's Input dock raised no OnUndocked");
        End_DockClient(f"docked={Docked} arrived={Arrived} undocked={Undocked} hasArrived={_InputDock.Get_HasArrived()} {Describe_DockEvents()}");
    }
}
