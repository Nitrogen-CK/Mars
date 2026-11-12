// The server docks the first platter on the Input dock, then has the subject hold the second (step 1), and watches 5 s.
// The client records its Input dock's refusal serial and asks for a Place through the dock's Act, although its own
// preview says Blocked_HandsFull. The authority's dock refuses the held platter Occupied and the Act DockRefused: the
// client's ledger advances by one, says DockRefused and names its subject, and nothing moved on either machine.
// Surface: Ck.PlatterDock.Net.AS_PlatterDock_ARefusedPlaceNamesItsInitiator
class UCk_AutoTest_Net_PlatterDock_ARefusedPlaceNamesItsInitiator : UMars_AutoTestRig_NetPlatterDock
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 252000.0;
    private const float32 k_WatchSeconds = 5.0f;

    private int32 _SerialAtAct = 0;
    private EMars_PlatterDock_Action _Preview = EMars_PlatterDock_Action::Place;

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
        Spawn_SecondPlatter();
    }

    protected void On_ServerSecondPlatterReady() override
    {
        Hold_Platter(Get_SecondWorldItem());
    }

    protected void On_ServerHeld() override
    {
        Publish_Location(1, FVector::ZeroVector);
        WaitSeconds(k_WatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Refusals = 0;
        auto Occupied = false;
        for (const auto& Event : _DockEvents)
        {
            if (Event.Role == EMars_PlatterDock_Role::Input && Event.Signal == EMars_TESTONLY_NetDockSignal::DockRefused)
            {
                ++Refusals;
                Occupied = Event.Refusal == EMars_PlatterDock_Refusal::Occupied;
            }
        }

        const auto HeldFault = Get_HeldBySubjectFault(Get_SecondWorldItem());
        Assert_Equals_Int(Refusals, 1, f"the server's Input dock refused one Dock ({Describe_DockEvents()})");
        Assert_True(Occupied, "the refusal is Occupied");
        Assert_True(_InputDock.Get_Item() == Get_PlatterItem(), "the server's Input dock still holds the first platter");
        Assert_True(HeldFault.IsEmpty(), f"the subject still holds the second platter on the server ({HeldFault})");
        End_DockServer(f"refusals={Refusals} occupied={Occupied} held=[{HeldFault}] {Describe_Ledger(_InputDock)} {Describe_DockEvents()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        WaitUntil(n"Is_SecondHeld", n"OnSecondHeld", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_SecondHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Try_FindSecondPlatter() && Get_HeldBySubjectFault(Get_SecondWorldItem()).IsEmpty());
    }

    UFUNCTION()
    private void OnSecondHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _SerialAtAct = _InputDock.Get_RefusalSerial();
        _Preview = _InputDock.Get_ActionFor(Get_SubjectEntity());
        Act(_InputDock, EMars_PlatterDock_Action::Place);
        WaitUntil(n"Is_Refused", n"OnRefused", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_Refused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Refused = _InputDock.Get_RefusalSerial() > _SerialAtAct;
        if (Refused)
        { Record_EffectFrame(); }

        auto Result = OutResult;
        Result.Set(Refused);
    }

    UFUNCTION()
    private void OnRefused(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto DockedFault = Get_DockedFault(_InputDock);
        const auto HeldFault = Get_HeldBySubjectFault(Get_SecondWorldItem());
        Assert_True(_Preview == EMars_PlatterDock_Action::Blocked_HandsFull, f"the client's own preview said Blocked_HandsFull (got [{_Preview :n}])");
        Assert_Equals_Int(_InputDock.Get_RefusalSerial(), _SerialAtAct + 1, "the client's ledger advanced by one");
        Assert_True(_InputDock.Get_LastRefusal() == EMars_Interaction_FailReason::DockRefused,
            f"the client's ledger says DockRefused (got [{_InputDock.Get_LastRefusal() :n}])");
        Assert_True(Get_LedgerNamesSubject(_InputDock), "the client's ledger names its subject");
        Assert_True(_InputDock.Get_Item() == Get_PlatterItem() && DockedFault.IsEmpty(), f"the client's Input dock still holds the first platter ({DockedFault})");
        Assert_True(HeldFault.IsEmpty(), f"the client's subject still holds the second platter ({HeldFault})");
        Assert_Equals_Int(_DockEvents.Num(), 2, f"the client's docks raised only the first OnDocked and OnArrived ({Describe_DockEvents()})");
        End_DockClient(f"preview={_Preview :n} serial={_SerialAtAct}->{_InputDock.Get_RefusalSerial()} docked=[{DockedFault}] held=[{HeldFault}] {Describe_ActFrames()} {Describe_Ledger(_InputDock)} {Describe_DockEvents()}");
    }
}
