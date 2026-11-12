// The server docks the platter on the Input dock (step 1) and watches 6 s. At step 1 the client, its hands empty, is offered
// what the host would be (Take on the occupied Input dock, Blocked_NothingHeld on the empty Output dock), then bypasses the
// Act and asks its own Input dock to undock the item to the subject and its own Output dock to dock it: 1.5 s later its
// Input dock still holds the item, its Output dock is empty, neither raised a refusal and its platter is still Carried by
// its Input dock. At the end the server's platter is still docked and neither of its docks raised an undock or a refusal.
// Surface: Ck.PlatterDock.Net.AS_PlatterDock_TheClientWroteNothing
class UCk_AutoTest_Net_PlatterDock_TheClientWroteNothing : UMars_AutoTestRig_NetPlatterDock
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 246000.0;
    private const float32 k_ServerWatchSeconds = 6.0f;
    private const float32 k_ClientWatchSeconds = 1.5f;

    private FCk_Handle_Item _ClientItem;

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
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    private int32 Get_RefusalCount()
    {
        return Get_Count(EMars_PlatterDock_Role::Input, EMars_TESTONLY_NetDockSignal::DockRefused)
            + Get_Count(EMars_PlatterDock_Role::Input, EMars_TESTONLY_NetDockSignal::UndockRefused)
            + Get_Count(EMars_PlatterDock_Role::Output, EMars_TESTONLY_NetDockSignal::DockRefused)
            + Get_Count(EMars_PlatterDock_Role::Output, EMars_TESTONLY_NetDockSignal::UndockRefused);
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Undocked = Get_Count(EMars_PlatterDock_Role::Input, EMars_TESTONLY_NetDockSignal::Undocked);
        Assert_True(_InputDock.Get_Item() == Get_PlatterItem() && _InputDock.Get_Platter() == _Platter, "the server's platter is still docked on its Input dock");
        Assert_Equals_Int(Undocked, 0, "the server's Input dock raised no OnUndocked");
        Assert_Equals_Int(Get_RefusalCount(), 0, "the server's docks raised no refusal");
        End_DockServer(f"docked=[{Get_DockedFault(_InputDock)}] {Describe_DockEvents()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        auto Subject = Get_SubjectEntity();
        const auto InputAction = _InputDock.Get_ActionFor(Subject);
        const auto OutputAction = _OutputDock.Get_ActionFor(Subject);
        Assert_True(InputAction == EMars_PlatterDock_Action::Take, f"the client is offered Take on its occupied Input dock (got {InputAction :n})");
        Assert_True(OutputAction == EMars_PlatterDock_Action::Blocked_NothingHeld, f"the client's empty hands get Blocked_NothingHeld on its empty Output dock (got {OutputAction :n})");

        _ClientItem = _InputDock.Get_Item();
        auto Target = _Carrier.Hotbar.TryGet_StowTarget(_ClientItem);
        _InputDock.Request_Undock(FMars_Request_PlatterDock_Undock(_ClientItem, Target));
        _OutputDock.Request_Dock(FMars_Request_PlatterDock_Dock(_ClientItem));
        WaitSeconds(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Fault = Get_DockedFault(_InputDock);
        const auto StillHolds = ck::IsValid(_ClientItem) && _InputDock.Get_Item() == _ClientItem;

        Assert_True(StillHolds, "the client's Input dock still holds the item");
        Assert_False(_OutputDock.Get_IsOccupied(), "the client's Output dock is empty");
        Assert_Equals_Int(Get_RefusalCount(), 0, f"the client's docks raised no refusal ({Describe_DockEvents()})");
        Assert_True(Fault.IsEmpty(), f"the client's platter is still Carried by its Input dock ({Fault})");
        End_DockClient(f"stillHolds={StillHolds} outputOccupied={_OutputDock.Get_IsOccupied()} docked=[{Fault}] {Describe_DockEvents()}");
    }
}
