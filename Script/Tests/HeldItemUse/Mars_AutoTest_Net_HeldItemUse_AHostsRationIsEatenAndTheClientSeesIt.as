// The host eats: with a ration in slot 0, selected and held on both machines, the server makes the consume task's one
// call (with authority it asks its own drain, no cue). Its tally reads one consume applied, and the client reads slot 0
// empty, its hands empty and the selection still 0, with one slot change since it held the ration; its own tally stays
// default.
// Surface: Ck.HeldItemUse.Net.AS_HeldItemUse_AHostsRationIsEatenAndTheClientSeesIt
class UCk_AutoTest_Net_HeldItemUse_AHostsRationIsEatenAndTheClientSeesIt : UMars_AutoTestRig_NetConsume
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(791000.0, 0.0, 5000.0);
    private const FString k_Row = "AHostsRationIsEatenAndTheClientSeesIt";
    // The client's copy composes and holds the ration within this of the server's hands holding it.
    private const float32 k_ClientHoldsSeconds = 2.5f;

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
        WaitSeconds(k_ClientHoldsSeconds, n"OnServerClientHolds");
    }

    UFUNCTION()
    private void OnServerClientHolds(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_SlotChanges();
        Eat();
        WaitUntil(n"Is_SlotZeroEmpty", n"OnServerEaten", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerEaten(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_ConsumeTally(1, 0, TOptional<EMars_HeldItemUse_ConsumeRefusal>());
        Hold_ConsumeServerRow(k_Row, "");
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_SlotChanges();
        WaitUntil(n"Is_Eaten", n"OnClientEaten", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientEaten(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ConsumeSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_IsEaten(), "the client's slot 0 is still empty and its hands hold nothing");
        Assert_SelectionZero();
        Assert_Equals_Int(Get_SlotChangesSinceMark(), 1, "one slot change on the client since it was ready");
        Assert_ConsumeTallyDefault();
        Finish_ConsumeRow(k_Row, "");
    }
}
