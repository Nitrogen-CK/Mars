// A client eats: with a ration in slot 0, selected and held on both machines, the client makes the consume task's one
// call; in that frame its slot still holds the ration (nothing is predicted). The server applies the consume once and
// removes the ration from its slot, and both machines read slot 0 empty, the hands empty and the selection still 0,
// with one slot change since the ration was held. The client's own tally stays default.
// Surface: Ck.HeldItemUse.Net.AS_HeldItemUse_AClientsRationIsEatenOnBothMachines
class UCk_AutoTest_Net_HeldItemUse_AClientsRationIsEatenOnBothMachines : UMars_AutoTestRig_NetConsume
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(790000.0, 0.0, 5000.0);
    private const FString k_Row = "AClientsRationIsEatenOnBothMachines";

    private int32 _AskFrame = -1;
    private int32 _EatenFrame = -1;

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
        Mark_SlotChanges();
        WaitUntil(n"Is_ServerAppliedAndEmpty", n"OnServerEaten", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerAppliedAndEmpty(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_SlotItemCount(0) == 0 && Get_ConsumeTallyHere().Applied == 1);
    }

    UFUNCTION()
    private void OnServerEaten(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ConsumeSettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_ConsumeTally(1, 0, TOptional<EMars_HeldItemUse_ConsumeRefusal>());
        Assert_True(ck::Is_NOT_Valid(_Carrier.HeldItem.Get_CurrentItem()), "the server's hands hold nothing");
        Assert_Equals_Int(Get_SlotItemCount(0), 0, "the server's slot 0 is empty");
        Assert_SelectionZero();
        Assert_Equals_Int(Get_SlotChangesSinceMark(), 1, "one slot change on the server since its hands held the ration");
        Hold_ConsumeServerRow(k_Row, "");
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_Carrier.Use), "the client's HeldItemUse has no authority");
        Mark_SlotChanges();
        _AskFrame = int32(utils_time::Get_FrameCounter());
        Eat();
        Assert_True(Get_SlotHolds(0, mars_items::Ration()), "in the frame it ate, the client's slot 0 still holds the ration");
        WaitUntil(n"Is_Eaten", n"OnClientEaten", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientEaten(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _EatenFrame = int32(utils_time::Get_FrameCounter());
        WaitSeconds(k_ConsumeSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_IsEaten(), "the client's slot 0 is still empty and its hands hold nothing");
        Assert_SelectionZero();
        Assert_Equals_Int(Get_SlotChangesSinceMark(), 1, "one slot change on the client since it ate");
        Assert_ConsumeTallyDefault();
        Finish_ConsumeRow(k_Row, f"askFrame={_AskFrame} eatenFrame={_EatenFrame} frames={_EatenFrame - _AskFrame}");
    }
}
