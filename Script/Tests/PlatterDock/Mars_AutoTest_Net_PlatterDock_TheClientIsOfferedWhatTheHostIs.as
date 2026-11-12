// Only reads: no machine acts. The server loads a mushroom onto the first platter and, once it froze, has the subject hold
// that platter (step 1); 2 s later it docks the second, empty platter on the Output dock (step 2). One second after each
// step, each machine asks its own docks what they offer its own subject. Step 1: the Input dock answers Blocked_Policy
// (KindRejected: it takes meat only) and the Output dock Blocked_Policy (MustBeEmpty). Step 2: the Output dock answers
// Blocked_HandsFull, and the Input dock is unchanged.
// Surface: Ck.PlatterDock.Net.AS_PlatterDock_TheClientIsOfferedWhatTheHostIs
class UCk_AutoTest_Net_PlatterDock_TheClientIsOfferedWhatTheHostIs : UMars_AutoTestRig_NetPlatterDock
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 258000.0;
    private const float32 k_GapSeconds = 1.0f;

    private FCk_Handle _Mushroom;
    private FString _Step1Text;

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
        Spawn_SecondPlatter();
    }

    protected void On_ServerSecondPlatterReady() override
    {
        _Mushroom = Spawn_BesideFood(mars_items::Food_Mushroom(), -1.0);
        Load_WhenReady(_Mushroom, 1);
    }

    protected void On_ServerFrozen() override
    {
        Hold_Platter(Get_PlatterWorldItem());
    }

    protected void On_ServerHeld() override
    {
        Publish_Location(1, FVector::ZeroVector);
        WaitSeconds(k_GapSeconds, n"OnServerReadStep1");
    }

    UFUNCTION()
    private void OnServerReadStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Step1Text = Assert_Step1("server");
        WaitSeconds(k_GapSeconds, n"OnServerGap");
    }

    UFUNCTION()
    private void OnServerGap(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Dock_Item(_OutputDock, Get_SecondPlatterItem());
    }

    protected void On_ServerDocked() override
    {
        Publish_Location(2, FVector::ZeroVector);
        WaitSeconds(k_GapSeconds, n"OnServerReadStep2");
    }

    UFUNCTION()
    private void OnServerReadStep2(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Step2Text = Assert_Step2("server");
        End_DockServer(f"step1=[{_Step1Text}] step2=[{Step2Text}] {Describe_Counts()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            _Step1Text = Assert_Step1("client");
            Await_Step(2);
            return;
        }

        const auto Step2Text = Assert_Step2("client");
        End_DockClient(f"step1=[{_Step1Text}] step2=[{Step2Text}] {Describe_Counts()}");
    }

    private FString Assert_Step1(FString InMachine)
    {
        const auto Subject = Get_SubjectEntity();
        const auto InputAction = _InputDock.Get_ActionFor(Subject);
        const auto InputRefusal = _InputDock.TryGet_Refusal(Subject);
        const auto OutputAction = _OutputDock.Get_ActionFor(Subject);
        const auto OutputRefusal = _OutputDock.TryGet_Refusal(Subject);
        Assert_True(InputAction == EMars_PlatterDock_Action::Blocked_Policy, f"the {InMachine}'s Input dock offers Blocked_Policy (got [{InputAction :n}])");
        Assert_True(InputRefusal.IsSet() && InputRefusal.GetValue() == EMars_PlatterDock_Refusal::KindRejected, f"the {InMachine}'s Input dock refuses KindRejected");
        Assert_True(OutputAction == EMars_PlatterDock_Action::Blocked_Policy, f"the {InMachine}'s Output dock offers Blocked_Policy (got [{OutputAction :n}])");
        Assert_True(OutputRefusal.IsSet() && OutputRefusal.GetValue() == EMars_PlatterDock_Refusal::MustBeEmpty, f"the {InMachine}'s Output dock refuses MustBeEmpty");
        return f"input={InputAction :n}/{Describe_Refusal(InputRefusal)} output={OutputAction :n}/{Describe_Refusal(OutputRefusal)}";
    }

    private FString Assert_Step2(FString InMachine)
    {
        const auto Subject = Get_SubjectEntity();
        const auto InputAction = _InputDock.Get_ActionFor(Subject);
        const auto InputRefusal = _InputDock.TryGet_Refusal(Subject);
        const auto OutputAction = _OutputDock.Get_ActionFor(Subject);
        Assert_True(OutputAction == EMars_PlatterDock_Action::Blocked_HandsFull, f"the {InMachine}'s Output dock offers Blocked_HandsFull (got [{OutputAction :n}])");
        Assert_True(InputAction == EMars_PlatterDock_Action::Blocked_Policy, f"the {InMachine}'s Input dock still offers Blocked_Policy (got [{InputAction :n}])");
        Assert_True(InputRefusal.IsSet() && InputRefusal.GetValue() == EMars_PlatterDock_Refusal::KindRejected, f"the {InMachine}'s Input dock still refuses KindRejected");
        return f"input={InputAction :n}/{Describe_Refusal(InputRefusal)} output={OutputAction :n}";
    }

    private FString Describe_Refusal(TOptional<EMars_PlatterDock_Refusal> InRefusal)
    {
        if (InRefusal.IsSet() == false)
        { return "none"; }

        return f"{InRefusal.GetValue() :n}";
    }
}
