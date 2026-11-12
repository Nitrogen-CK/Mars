// The server docks the platter on the test station's Input dock (meat only), its subject holds a mushroom (step 1), and it
// watches 5 s. At step 1 the client's Input dock offers its subject Blocked_Policy, refused KindRejected; the client records
// the dock's refusal serial and asks for PlaceFood through the dock's Act all the same. Its dock ledger then reads one more,
// ActionBlocked naming its subject, and its mushroom is still Held by its subject. At the end the server's dock ledger reads
// serial 1, ActionBlocked naming the subject, its platter loaded nothing, and the mushroom is still the subject's held item.
// Surface: Ck.PlatterDock.Net.AS_PlatterDock_ADocksPolicyRefusesAClientsFood
class UCk_AutoTest_Net_PlatterDock_ADocksPolicyRefusesAClientsFood : UMars_AutoTestRig_NetPlatterDock
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 264000.0;
    private const float32 k_WatchSeconds = 5.0f;

    private FCk_Handle _Food;
    // Client: what its dock offered at step 1, its mushroom, and the dock serial it recorded at its act.
    private EMars_PlatterDock_Action _Offered = EMars_PlatterDock_Action::Place;
    private TOptional<EMars_PlatterDock_Refusal> _OfferedRefusal;
    private FCk_Handle_WorldItem _Mushroom;
    private int32 _SerialAtAct = -1;

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
        _Food = Spawn_BesideFood(mars_items::Food_Mushroom(), -1.0);
        Hold_FoodWhenReady(_Food);
    }

    protected void On_ServerFoodHeld() override
    {
        Publish_Location(1, FVector::ZeroVector);
        WaitSeconds(k_WatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto WorldItem = _Food.As_WorldItem();
        Assert_Equals_Int(_InputDock.Get_RefusalSerial(), 1, "the server's dock ledger reads serial 1");
        Assert_True(_InputDock.Get_LastRefusal() == EMars_Interaction_FailReason::ActionBlocked,
            f"the server's dock ledger says ActionBlocked (got [{_InputDock.Get_LastRefusal() :n}])");
        Assert_True(Get_LedgerNamesSubject(_InputDock), "the server's dock ledger names the subject");
        Assert_Equals_Int(_Accepted + _Loaded, 0, "the server's platter loaded nothing");
        Assert_True(_Carrier.HeldItem.Get_CurrentItem() == WorldItem.Get_Item() && WorldItem.Get_Mount() == EMars_WorldItem_Mount::Held,
            f"the mushroom is still the server's subject's held item (mount {WorldItem.Get_Mount() :n})");
        End_DockServer(f"{Describe_Counts()} {Describe_Signals()} dock {Describe_Ledger(_InputDock)}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        _Offered = _InputDock.Get_ActionFor(Get_SubjectEntity());
        _OfferedRefusal = _InputDock.TryGet_Refusal(Get_SubjectEntity());
        Assert_True(_Offered == EMars_PlatterDock_Action::Blocked_Policy, f"the client's Input dock offers Blocked_Policy (got [{_Offered :n}])");
        Assert_True(_OfferedRefusal.IsSet() && _OfferedRefusal.GetValue() == EMars_PlatterDock_Refusal::KindRejected,
            "the client's Input dock says KindRejected");

        FCk_Handle Entity = Get_SelectedFoodPiece();
        _Mushroom = ck::IsValid(Entity) ? Entity.As_WorldItem(ECk_SanityCheck::UnChecked) : FCk_Handle_WorldItem();
        _SerialAtAct = _InputDock.Get_RefusalSerial();
        Act(_InputDock, EMars_PlatterDock_Action::PlaceFood);
        WaitUntil(n"Is_ClientRefused", n"OnClientRefused", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientRefused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsLive(_InputDock) && _InputDock.Get_RefusalSerial() > _SerialAtAct);
    }

    UFUNCTION()
    private void OnClientRefused(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto HeldFault = Get_HeldBySubjectFault(_Mushroom);
        Assert_Equals_Int(_InputDock.Get_RefusalSerial(), _SerialAtAct + 1, "the client's dock ledger reads one more refusal");
        Assert_True(_InputDock.Get_LastRefusal() == EMars_Interaction_FailReason::ActionBlocked,
            f"the client's dock ledger says ActionBlocked (got [{_InputDock.Get_LastRefusal() :n}])");
        Assert_True(Get_LedgerNamesSubject(_InputDock), "the client's dock ledger names its subject");
        Assert_True(HeldFault.IsEmpty(), f"the client's mushroom is still Held by its subject ({HeldFault})");
        End_DockClient(f"offered={_Offered :n} serialAtAct={_SerialAtAct} held=[{HeldFault}] dock {Describe_Ledger(_InputDock)}");
    }
}
