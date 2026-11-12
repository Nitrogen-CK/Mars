// The server places the slab and reports; 1.5 s later it releases it (no cap, no tray) and reports again. While the board
// holds it the slab's pickup is disabled for Ledger on the server, and on the client its whole food's pickup is disabled
// for Ledger and out of focus, its ledger reading Claimed; once released, neither machine's pickup holds the Ledger reason
// and the client's ledger reads Unclaimed.
// Surface: Ck.FoodBoard.Net.AS_FoodBoard_AJointOnTheBoardIsOutOfAClientsReach
class UCk_AutoTest_Net_FoodBoard_AJointOnTheBoardIsOutOfAClientsReach : UMars_AutoTestRig_NetFoodBoard
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 214000.0;
    // Frames after a place or a release the server waits for its pickup's drain before it reads it.
    private const int32 k_DrainFrames = 2;

    private FString _Step1Text;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BoardRig(InHandle, k_X);
        if (Get_IsServer() == false)
        {
            Await_ClientStep(1, n"OnClientStep1");
            return;
        }

        Begin_ServerBoardWithSlab(InHandle);
    }

    protected void On_ServerBoardReady() override
    {
        Place_SlabThen(n"OnServerHoldsOne");
    }

    UFUNCTION()
    private void OnServerHoldsOne(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(k_DrainFrames, n"OnServerPlaceDrained");
    }

    UFUNCTION()
    private void OnServerPlaceDrained(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_BoardReport(1);
        auto Slab = _Rock.As_WorldItem();
        _Step1Text = mars_test_ledger_claim::Describe(Slab);
        Assert_True(mars_test_ledger_claim::Get_IsHeldByLedger(Slab), f"step 1: the server's slab pickup is disabled for Ledger ({_Step1Text})");
        WaitSeconds(constants_foodboard_net_autotest::k_StepSeconds, n"OnServerRelease");
    }

    UFUNCTION()
    private void OnServerRelease(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Board.Request_Release(FMars_Request_FoodBoard_Release(TOptional<int32>()));
        WaitUntil(n"Is_ServerReleased", n"OnServerReleased", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_EventCount(EMars_TESTONLY_NetBoardEvent::Released) >= 1);
    }

    UFUNCTION()
    private void OnServerReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(k_DrainFrames, n"OnServerReleaseDrained");
    }

    UFUNCTION()
    private void OnServerReleaseDrained(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_BoardReport(2);
        auto Slab = _Rock.As_WorldItem();
        const auto Step2Text = mars_test_ledger_claim::Describe(Slab);
        Assert_False(mars_test_ledger_claim::Get_IsHeldByLedger(Slab), f"step 2: the server's slab pickup is not disabled for Ledger ({Step2Text})");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"step1 ({_Step1Text}) step2 ({Step2Text})");
        End_ServerAfterReport();
    }

    UFUNCTION()
    private void OnClientStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Food = Find_WholeFood();
        _Step1Text = mars_test_ledger_claim::Describe(Food);
        Assert_True(ck::IsValid(Food), "step 1: the client's whole food is a world item");
        Assert_True(mars_test_ledger_claim::Get_IsHeldByLedger(Food), f"step 1: the client's pickup is disabled for Ledger ({_Step1Text})");
        Assert_False(mars_test_ledger_claim::Get_IsFocusable(Food), f"step 1: the client's pickup is out of focus ({_Step1Text})");
        Assert_True(ck::IsValid(Food) && Food.Get_LedgerClaim() == EMars_WorldItem_LedgerClaim::Claimed, f"step 1: the client's ledger reads Claimed ({_Step1Text})");
        Await_ClientStep(2, n"OnClientStep2");
    }

    UFUNCTION()
    private void OnClientStep2(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Food = Find_WholeFood();
        const auto Step2Text = mars_test_ledger_claim::Describe(Food);
        Assert_True(ck::IsValid(Food), "step 2: the client's whole food is a world item");
        Assert_False(mars_test_ledger_claim::Get_IsHeldByLedger(Food), f"step 2: the client's pickup is not disabled for Ledger ({Step2Text})");
        Assert_True(ck::IsValid(Food) && Food.Get_LedgerClaim() == EMars_WorldItem_LedgerClaim::Unclaimed, f"step 2: the client's ledger reads Unclaimed ({Step2Text})");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(f"step1 ({_Step1Text}) step2 ({Step2Text})");
        End_Client();
    }
}
