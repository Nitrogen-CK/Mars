// The server asks its board, in one frame, to place the slab and to release every free piece (no cap, no tray), and
// reports: the claim is made and released in one drain, so the server raises one OnPlaced and one OnReleased and its
// pickup and ledger end unclaimed. The client, sampling every frame for 1.5 s from the report on, never sees its whole
// food's pickup disabled for Ledger nor its ledger Claimed.
// Surface: Ck.FoodBoard.Net.AS_FoodBoard_APlaceAndASweepInOneFrameLeaveTheJointInReach
class UCk_AutoTest_Net_FoodBoard_APlaceAndASweepInOneFrameLeaveTheJointInReach : UMars_AutoTestRig_NetFoodBoard
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 215000.0;
    private const float32 k_ServerWatchSeconds = 2.0f;

    private FCk_Handle _SampleOwner;
    private FCk_Handle_Timer _SampleTick;
    // Client: frames sampled with a whole food found, and those of them that read the pickup disabled for Ledger or the
    // ledger Claimed.
    private int32 _SampledFrames = 0;
    private int32 _LedgerHeldFrames = 0;
    private int32 _ClaimedFrames = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        _SampleOwner = InHandle;
        Begin_BoardRig(InHandle, k_X);
        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientReportArrived", n"OnClientReportArrived", k_SlowPolls);
            return;
        }

        Begin_ServerBoardWithSlab(InHandle);
    }

    protected void On_ServerBoardReady() override
    {
        Place_Slab();
        _Board.Request_Release(FMars_Request_FoodBoard_Release(TOptional<int32>()));
        Publish_BoardReport(1);
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Slab = _Rock.As_WorldItem();
        const auto Text = mars_test_ledger_claim::Describe(Slab);
        Assert_Equals_Int(Get_EventCount(EMars_TESTONLY_NetBoardEvent::Placed), 1, "the server placed the slab once");
        Assert_Equals_Int(Get_EventCount(EMars_TESTONLY_NetBoardEvent::Released), 1, "the server released it once");
        Assert_False(mars_test_ledger_claim::Get_IsHeldByLedger(Slab), f"the server's pickup is not disabled for Ledger ({Text})");
        Assert_True(Slab.Get_LedgerClaim() == EMars_WorldItem_LedgerClaim::Unclaimed, f"the server's ledger reads Unclaimed ({Text})");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(Text);
        End_ServerAfterReport();
    }

    UFUNCTION()
    private void Is_ClientReportArrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsFound = Get_IsBoardStationFound();
        auto Result = OutResult;
        Result.Set(IsFound && Get_BoardReport().Step >= 1);
    }

    UFUNCTION()
    private void OnClientReportArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _SampleTick = utils_timer::Create_Tick(_SampleOwner, FCk_Delegate_Timer(this, n"OnClientSample"));
        WaitSeconds(constants_foodboard_net_autotest::k_StepSeconds, n"OnClientSampled");
    }

    UFUNCTION()
    private void OnClientSample(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Food = Find_WholeFood();
        if (ck::Is_NOT_Valid(Food))
        { return; }

        ++_SampledFrames;
        if (mars_test_ledger_claim::Get_IsHeldByLedger(Food))
        { ++_LedgerHeldFrames; }

        if (Food.Get_LedgerClaim() == EMars_WorldItem_LedgerClaim::Claimed)
        { ++_ClaimedFrames; }
    }

    UFUNCTION()
    private void OnClientSampled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        utils_timer::UnbindFrom_OnUpdate(_SampleTick, FCk_Delegate_Timer(this, n"OnClientSample"));
        utils_entity_lifetime::Request_DestroyEntity(_SampleTick.H());
        const auto Text = f"sampled={_SampledFrames} ledger-held={_LedgerHeldFrames} claimed={_ClaimedFrames}";
        Assert_True(_SampledFrames > 0, f"the client sampled its whole food ({Text})");
        Assert_Equals_Int(_LedgerHeldFrames, 0, "the client's pickup was never disabled for Ledger");
        Assert_Equals_Int(_ClaimedFrames, 0, "the client's ledger never read Claimed");
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure");
        Log_BoardResult(Text);
        End_Client();
    }
}
