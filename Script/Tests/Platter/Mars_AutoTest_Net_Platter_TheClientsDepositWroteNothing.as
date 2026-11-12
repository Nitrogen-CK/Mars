// The server's subject holds a meat slab (step 1) and watches 6 s. At step 1 the client asks its own copy of the platter
// for a deposit by its subject directly, not through the cue: 1.5 s later its slab is still Held by its subject, its
// platter has no pending deposits, no depositing mark is on its slab and its ledger reads serial 0. At the end the server's
// slab is still Held by the subject, its platter was asked to load nothing, its ledger reads serial 0 and no depositing
// mark is on its slab.
// Surface: Ck.Platter.Net.AS_Platter_TheClientsDepositWroteNothing
class UCk_AutoTest_Net_Platter_TheClientsDepositWroteNothing : UMars_AutoTestRig_NetPlatter
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 267000.0;
    private const float32 k_WatchSeconds = 6.0f;

    private FCk_Handle _Food;

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
        _Food = Spawn_BesideFood(mars_items::Food_MeatSlab(), 1.0);
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
        const auto Fault = Get_HeldFaultOf(_Food);
        Assert_True(Fault.IsEmpty(), f"the server's slab is still Held by the subject ({Fault})");
        Assert_Equals_Int(_Accepted + _Refused, 0, "the server's platter was asked to load nothing");
        Assert_Equals_Int(_Platter.Get_RefusalSerial(), 0, "the server's ledger reads serial 0");
        Assert_False(_Food.Has_Fragment(FMars_Fragment_Platter_Depositing), "no depositing mark is on the server's slab");
        End_PlatterServer(f"held=[{Fault}] {Describe_Counts()} {Describe_Signals()} {Describe_PlatterLedger()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        _Platter.Request_Deposit(FMars_Request_Platter_Deposit(Get_SubjectEntity()));
        WaitSeconds(k_StepSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FCk_Handle Food = Find_FoodPieceNear(_FloorTop);
        const auto Fault = Get_HeldFaultOf(Food);
        Assert_True(Fault.IsEmpty(), f"the client's slab is still Held by its subject ({Fault})");
        Assert_False(_Platter.Has_Fragment(FMars_Fragment_Platter_Deposits), "the client's platter has no pending deposits");
        Assert_False(ck::IsValid(Food) && Food.Has_Fragment(FMars_Fragment_Platter_Depositing), "no depositing mark is on the client's slab");
        Assert_Equals_Int(_Platter.Get_RefusalSerial(), 0, "the client's ledger reads serial 0");
        End_PlatterClient(f"held=[{Fault}] {Describe_Counts()} {Describe_PlatterLedger()}");
    }

    // Empty when InFood is a world item Held by the subject on this machine; otherwise the first fault.
    private FString Get_HeldFaultOf(FCk_Handle InFood)
    {
        if (Get_IsLive(InFood) == false)
        { return "no live slab"; }

        const auto WorldItem = InFood.As_WorldItem();
        if (WorldItem.Get_Mount() != EMars_WorldItem_Mount::Held || WorldItem.Get_Carrier() != Get_SubjectEntity())
        { return f"mount {WorldItem.Get_Mount() :n} by [{WorldItem.Get_Carrier().ToString()}]"; }

        return "";
    }
}
