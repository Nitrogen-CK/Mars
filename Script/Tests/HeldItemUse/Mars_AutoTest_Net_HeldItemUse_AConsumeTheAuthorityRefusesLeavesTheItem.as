// A consume the authority refuses leaves the item: with a ration held on both machines, the client first asks its own
// copy directly (dropped there: it has no authority), then claims a consume naming the tenderizer. The server refuses
// it as ItemMismatch and applies nothing; slot 0 still holds the ration on both machines, with no slot change on the
// client.
// Surface: Ck.HeldItemUse.Net.AS_HeldItemUse_AConsumeTheAuthorityRefusesLeavesTheItem
class UCk_AutoTest_Net_HeldItemUse_AConsumeTheAuthorityRefusesLeavesTheItem : UMars_AutoTestRig_NetConsume
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(792000.0, 0.0, 5000.0);
    private const FString k_Row = "AConsumeTheAuthorityRefusesLeavesTheItem";
    private const float32 k_ServerWatchSeconds = 4.0f;
    private const float32 k_ClientWatchSeconds = 2.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Consume(k_Base);

        if (Get_IsConsumeServer())
        {
            WaitUntil(n"Is_HotbarReady", n"OnServerReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_FedWithRation", n"OnClientReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_FedWithRation(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsFedWith(mars_items::Ration()));
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Feed_Server(mars_items::Ration());
        WaitUntil(n"Is_FedWithRation", n"OnServerFed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_ConsumeTally(0, 1, TOptional<EMars_HeldItemUse_ConsumeRefusal>(EMars_HeldItemUse_ConsumeRefusal::ItemMismatch));
        Assert_True(Get_SlotHolds(0, mars_items::Ration()), "the server's slot 0 still holds the ration");
        Hold_ConsumeServerRow(k_Row, "");
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_SlotChanges();
        _Carrier.Use.Request_Consume(FMars_Request_HeldItemUse_Consume(utils_held_item::Make_DefinitionSoft(mars_items::Ration())));
        Claim(mars_items::Tenderizer());
        WaitSeconds(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_SlotHolds(0, mars_items::Ration()), "the client's slot 0 still holds the ration");
        Assert_Equals_Int(Get_SlotChangesSinceMark(), 0, "no slot change on the client");
        Assert_ConsumeTallyDefault();
        Finish_ConsumeRow(k_Row, "");
    }
}
