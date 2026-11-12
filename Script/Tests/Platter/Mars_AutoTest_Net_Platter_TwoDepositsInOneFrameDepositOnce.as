// The server's subject holds a meat slab (step 1); 1.5 s later the server asks its platter for two deposits by the subject
// in one frame, and step 2 follows once the platter froze the slab. The server raised OnLoadAccepted once and OnLoaded once,
// and its ledger reads serial 1, TransferRefused: the second deposit found the food already in the first. At step 2 the
// client's slab rides at the report, its platter reads one held and one on its books, and its ledger reads serial 1,
// TransferRefused.
// Surface: Ck.Platter.Net.AS_Platter_TwoDepositsInOneFrameDepositOnce
class UCk_AutoTest_Net_Platter_TwoDepositsInOneFrameDepositOnce : UMars_AutoTestRig_NetPlatter
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 262000.0;

    private FCk_Handle _Food;

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
        _Food = Spawn_BesideFood(mars_items::Food_MeatSlab(), 1.0);
        Hold_FoodWhenReady(_Food);
    }

    protected void On_ServerFoodHeld() override
    {
        Publish_Location(1, FVector::ZeroVector);
        WaitSeconds(k_StepSeconds, n"OnServerDepositTwice");
    }

    UFUNCTION()
    private void OnServerDepositTwice(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Platter.Request_Deposit(FMars_Request_Platter_Deposit(Get_SubjectEntity()));
        _Platter.Request_Deposit(FMars_Request_Platter_Deposit(Get_SubjectEntity()));
        Await_Frozen(1, 1);
    }

    protected void On_ServerFrozen() override
    {
        Publish_Rides(2);
        WaitSeconds(k_ClientSettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Accepted, 1, "the server's platter raised OnLoadAccepted once");
        Assert_Equals_Int(_Loaded, 1, "the server's platter raised OnLoaded once");
        Assert_Equals_Int(_Platter.Get_RefusalSerial(), 1, "the server's ledger reads serial 1");
        Assert_True(_Platter.Get_LastRefusal() == EMars_Interaction_FailReason::TransferRefused,
            f"the server's ledger says TransferRefused (got [{_Platter.Get_LastRefusal() :n}])");
        End_PlatterServer(f"{Describe_Counts()} {Describe_Signals()} {Describe_PlatterLedger()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Slot = Get_PlatterReport().Slot0;
        const auto Piece = Find_PieceById(Slot.Id);
        const auto Fault = Get_RideFault(Piece, Slot);
        Assert_True(Fault.IsEmpty(), f"the client's slab rides at the report ({Fault})");
        Assert_Equals_Int(_Platter.Get_HeldCount(), 1, "the client's platter reads one held");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 1, "the client's platter reads one on its books");
        Assert_Equals_Int(_Platter.Get_RefusalSerial(), 1, "the client's ledger reads serial 1");
        Assert_True(_Platter.Get_LastRefusal() == EMars_Interaction_FailReason::TransferRefused,
            f"the client's ledger says TransferRefused (got [{_Platter.Get_LastRefusal() :n}])");
        End_PlatterClient(f"ride=[{Fault}] {Describe_Counts()} {Describe_PlatterLedger()}");
    }
}
