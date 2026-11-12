// The server docks the platter on the Input dock (step 1). The client, once its Input dock offers Take, asks for the Take
// through the dock's Act; the authority undocks the platter into the subject's stow target and step 2 follows once the
// subject's overflow holds it. At step 2 the client's Input dock is empty and raised OnUndocked once, and its platter is
// Held by the subject on its own hand. The server raised OnUndocked once.
// Surface: Ck.PlatterDock.Net.AS_PlatterDock_AClientTakesTheDockedPlatter
class UCk_AutoTest_Net_PlatterDock_AClientTakesTheDockedPlatter : UMars_AutoTestRig_NetPlatterDock
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 251000.0;

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
        Assert_Equals_Int(Undocked, 1, "the server's Input dock raised OnUndocked once");
        End_DockServer(f"undocked={Undocked} {Describe_Ledger(_InputDock)} {Describe_DockEvents()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            WaitUntil(n"Is_TakeOffered", n"OnTakeOffered", k_SlowPolls);
            return;
        }

        const auto Fault = Get_HeldFault();
        const auto Undocked = Get_Count(EMars_PlatterDock_Role::Input, EMars_TESTONLY_NetDockSignal::Undocked);
        Assert_False(_InputDock.Get_IsOccupied(), "the client's Input dock is empty");
        Assert_Equals_Int(Undocked, 1, "the client's Input dock raised OnUndocked once");
        Assert_True(Fault.IsEmpty(), f"the client's platter is Held by the subject on its own hand ({Fault})");
        End_DockClient(f"held=[{Fault}] undocked={Undocked} {Describe_ActFrames()} {Describe_Ledger(_InputDock)} {Describe_DockEvents()}");
    }

    UFUNCTION()
    private void Is_TakeOffered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_InputDock.Get_ActionFor(Get_SubjectEntity()) == EMars_PlatterDock_Action::Take);
    }

    UFUNCTION()
    private void OnTakeOffered(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Act(_InputDock, EMars_PlatterDock_Action::Take);
        WaitUntil(n"Is_Taken", n"OnTaken", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_Taken(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Taken = _InputDock.Get_IsOccupied() == false && _Carrier.Hotbar.TryGet_SlotIndexOf(Get_PlatterItem()).IsSet();
        if (Taken)
        { Record_EffectFrame(); }

        auto Result = OutResult;
        Result.Set(Taken);
    }

    UFUNCTION()
    private void OnTaken(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Await_Step(2);
    }
}
