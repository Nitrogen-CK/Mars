// A client claims the same consume twice in one frame: the server applies one and refuses the other, as Leaving when
// both begin in one frame (the first already took the item) or as ItemMismatch when the second begins a frame later
// with the hands already empty. The result does not depend on the order they begin in: slot 0 is empty and the client
// saw one slot change.
// Surface: Ck.HeldItemUse.Net.AS_HeldItemUse_TwoConsumesInOneFrameEatOnce
class UCk_AutoTest_Net_HeldItemUse_TwoConsumesInOneFrameEatOnce : UMars_AutoTestRig_NetConsume
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(794000.0, 0.0, 5000.0);
    private const FString k_Row = "TwoConsumesInOneFrameEatOnce";
    private const float32 k_ServerWatchSeconds = 2.0f;

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
        WaitUntil(n"Is_SlotZeroEmpty", n"OnServerEaten", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerEaten(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Tally = Get_ConsumeTallyHere();
        Assert_Equals_Int(Tally.Applied, 1, "the server applied one consume");
        Assert_Equals_Int(Tally.Refused, 1, "the server refused one consume");
        const auto IsExpected = Tally.LastRefusal.IsSet()
            && (Tally.LastRefusal.GetValue() == EMars_HeldItemUse_ConsumeRefusal::Leaving
                || Tally.LastRefusal.GetValue() == EMars_HeldItemUse_ConsumeRefusal::ItemMismatch);
        Assert_True(IsExpected, "the second consume was refused as Leaving or ItemMismatch");
        Assert_Equals_Int(Get_SlotItemCount(0), 0, "the server's slot 0 is empty");
        Hold_ConsumeServerRow(k_Row, "");
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_SlotChanges();
        Claim(mars_items::Ration());
        Claim(mars_items::Ration());
        WaitUntil(n"Is_SlotZeroEmpty", n"OnClientEaten", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientEaten(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ConsumeSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_SlotChangesSinceMark(), 1, "one slot change on the client since it claimed");
        Assert_Equals_Int(Get_SlotItemCount(0), 0, "the client's slot 0 is empty");
        Finish_ConsumeRow(k_Row, "");
    }
}
