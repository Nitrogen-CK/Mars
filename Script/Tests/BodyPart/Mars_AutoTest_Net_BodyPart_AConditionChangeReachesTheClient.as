// The server hits part 0 of its monster for 10 (Sever): the client's part 0 reads Damaged and raised OnConditionChanged
// once (Pristine to Damaged), and its part 1 stays Pristine with no signal.
// Surface: Ck.BodyPart.Net.AS_BodyPart_AConditionChangeReachesTheClient
class UCk_AutoTest_Net_BodyPart_AConditionChangeReachesTheClient : UMars_AutoTestRig_NetBodyPart
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(550000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BodyPart(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientPart0Damaged", n"OnClientDamaged", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerMonster(0.0f);
        WaitUntil(n"Is_MonsterFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ComposeSeconds, n"OnServerComposed");
    }

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerPartHit(0, 10.0f);
        WaitSeconds(k_ServerHoldSeconds, n"OnServerEnd");
    }

    UFUNCTION()
    private void OnServerEnd(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_PartRow("AConditionChangeReachesTheClient", "");
        Assert_True(Get_IsPartCondition(0, EMars_BodyPart_Condition::Damaged), "the server's part 0 is Damaged");
        Assert_True(Get_IsPartState(0, EMars_BodyPart_State::Attached), "the server's part 0 is Attached");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_ClientPart0Damaged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsMonsterFound() && Get_IsPartCondition(0, EMars_BodyPart_Condition::Damaged));
    }

    UFUNCTION()
    private void OnClientDamaged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_PartRow("AConditionChangeReachesTheClient", "");
        Assert_True(Get_IsPartCondition(0, EMars_BodyPart_Condition::Damaged), "the client's part 0 reads Damaged");
        Assert_Equals_Int(_PartSignals[0].ConditionChanged, 1, "the client's part 0 raised OnConditionChanged once");
        Assert_True(_PartSignals[0].LastOld == EMars_BodyPart_Condition::Pristine && _PartSignals[0].LastNew == EMars_BodyPart_Condition::Damaged,
            "the client's part 0 changed from Pristine to Damaged");
        Assert_True(Get_IsPartCondition(1, EMars_BodyPart_Condition::Pristine), "the client's part 1 reads Pristine");
        Assert_Equals_Int(_PartSignals[1].ConditionChanged + _PartSignals[1].Broken + _PartSignals[1].Severed, 0, "the client's part 1 raised no signal");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
