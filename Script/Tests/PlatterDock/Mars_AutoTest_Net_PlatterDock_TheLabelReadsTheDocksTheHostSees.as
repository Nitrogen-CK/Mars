// The server spawns the real cutting station beside an empty platter (step 1), docks the platter on its Output dock (step 2
// once it arrived) and 1.5 s later undocks it to the subject (step 3 once it is Held), waiting 1.5 s after each step. One
// second after each step the client's label says "no tray" at steps 1 and 3 and not at step 2.
// Surface: Ck.PlatterDock.Net.AS_PlatterDock_TheLabelReadsTheDocksTheHostSees
class UCk_AutoTest_Net_PlatterDock_TheLabelReadsTheDocksTheHostSees : UMars_AutoTestRig_NetPlatterDock
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 248000.0;

    private TArray<FString> _Labels;

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
        Publish_Location(1, FVector::ZeroVector);
        WaitSeconds(k_StepGapSeconds, n"OnServerDockGap");
    }

    UFUNCTION()
    private void OnServerDockGap(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Dock_Platter(_OutputDock);
    }

    protected void On_ServerDocked() override
    {
        Publish_Location(2, FVector::ZeroVector);
        WaitSeconds(k_StepGapSeconds, n"OnServerUndockGap");
    }

    UFUNCTION()
    private void OnServerUndockGap(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Undock_ToSubject(_OutputDock);
    }

    protected void On_ServerUndocked() override
    {
        Publish_Location(3, FVector::ZeroVector);
        End_DockServer(f"{Describe_ConstructFrames()} {Describe_DockEvents()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Label = Get_ShownLabel();
        _Labels.Add(Label.Replace("\n", " / "));
        const auto SaysNoTray = Label.Contains("no tray");
        if (InStep == 2)
        { Assert_False(SaysNoTray, f"step 2: the client's label does not say no tray ({Label})"); }
        else
        { Assert_True(SaysNoTray, f"step {InStep}: the client's label says no tray ({Label})"); }

        if (InStep < 3)
        {
            Await_Step(InStep + 1);
            return;
        }

        End_DockClient(f"labels=[{_Labels[0]}] [{_Labels[1]}] [{_Labels[2]}] {Describe_DockEvents()}");
    }
}
