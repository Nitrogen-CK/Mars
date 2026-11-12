// The server docks the platter on the Input dock (step 1), waits 1.5 s, then asks the dock for a Take and then a Place by
// the subject in one frame. The Take undocks the platter; the Place arrives while that transfer is in flight and is refused
// DockRefused in the ledger. Step 2 once the subject's overflow holds the item. The server raised OnUndocked once and
// OnDocked once in all. At step 2 the client's dock is empty and its platter is Held by the subject.
// Surface: Ck.PlatterDock.Net.AS_PlatterDock_ATakeAndAPlaceInOneFrame
class UCk_AutoTest_Net_PlatterDock_ATakeAndAPlaceInOneFrame : UMars_AutoTestRig_NetPlatterDock
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 255000.0;

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
        _InputDock.Request_Act(FMars_Request_PlatterDock_Act(Get_SubjectEntity(), EMars_PlatterDock_Action::Take));
        _InputDock.Request_Act(FMars_Request_PlatterDock_Act(Get_SubjectEntity(), EMars_PlatterDock_Action::Place));
        WaitUntil(n"Is_ServerOverflowHolds", n"OnServerOverflowHolds", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerOverflowHolds(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_OverflowItem() == Get_PlatterItem());
    }

    UFUNCTION()
    private void OnServerOverflowHolds(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_Location(2, FVector::ZeroVector);
        WaitSeconds(k_ClientSettleSeconds, n"OnServerSettled");
    }

    // The dock's signals follow its content pass: the server counts them a settle after the step, as the client does.
    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Undocked = Get_Count(EMars_PlatterDock_Role::Input, EMars_TESTONLY_NetDockSignal::Undocked);
        const auto DockedInAll = Get_Count(EMars_PlatterDock_Role::Input, EMars_TESTONLY_NetDockSignal::Docked)
            + Get_Count(EMars_PlatterDock_Role::Output, EMars_TESTONLY_NetDockSignal::Docked);
        Assert_Equals_Int(Undocked, 1, "the server's Input dock raised OnUndocked once");
        Assert_Equals_Int(DockedInAll, 1, "the server's docks raised OnDocked once in all");
        Assert_Equals_Int(_InputDock.Get_RefusalSerial(), 1, "the server's ledger refused one Act");
        Assert_True(_InputDock.Get_LastRefusal() == EMars_Interaction_FailReason::DockRefused,
            f"the server's ledger says DockRefused (got [{_InputDock.Get_LastRefusal() :n}])");
        End_DockServer(f"undocked={Undocked} dockedInAll={DockedInAll} {Describe_Ledger(_InputDock)} {Describe_DockEvents()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Fault = Get_HeldFault();
        Assert_False(_InputDock.Get_IsOccupied(), "the client's Input dock is empty");
        Assert_True(Fault.IsEmpty(), f"the client's platter is Held by the subject ({Fault})");
        End_DockClient(f"held=[{Fault}] {Describe_Ledger(_InputDock)} {Describe_DockEvents()}");
    }
}
