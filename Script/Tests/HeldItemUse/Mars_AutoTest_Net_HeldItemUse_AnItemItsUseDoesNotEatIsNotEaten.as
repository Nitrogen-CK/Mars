// An item whose use does not eat it is not eaten: with a cleaver held on both machines (its UseAction swings and does
// not consume), the client claims a consume naming the cleaver. The server refuses it as NotConsumable and applies
// nothing; slot 0 still holds the cleaver on both machines.
// Surface: Ck.HeldItemUse.Net.AS_HeldItemUse_AnItemItsUseDoesNotEatIsNotEaten
class UCk_AutoTest_Net_HeldItemUse_AnItemItsUseDoesNotEatIsNotEaten : UMars_AutoTestRig_NetConsume
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(793000.0, 0.0, 5000.0);
    private const FString k_Row = "AnItemItsUseDoesNotEatIsNotEaten";
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

        WaitUntil(n"Is_FedWithCleaver", n"OnClientReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_FedWithCleaver(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsFedWith(mars_items::Cleaver()));
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Feed_Server(mars_items::Cleaver());
        WaitUntil(n"Is_FedWithCleaver", n"OnServerFed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_ConsumeTally(0, 1, TOptional<EMars_HeldItemUse_ConsumeRefusal>(EMars_HeldItemUse_ConsumeRefusal::NotConsumable));
        Assert_True(Get_SlotHolds(0, mars_items::Cleaver()), "the server's slot 0 still holds the cleaver");
        Hold_ConsumeServerRow(k_Row, "");
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_SlotChanges();
        Claim(mars_items::Cleaver());
        WaitSeconds(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_SlotHolds(0, mars_items::Cleaver()), "the client's slot 0 still holds the cleaver");
        Assert_ConsumeTallyDefault();
        Finish_ConsumeRow(k_Row, "");
    }
}
