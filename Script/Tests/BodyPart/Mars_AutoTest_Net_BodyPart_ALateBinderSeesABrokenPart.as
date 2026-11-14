// The server, in the continuation in which it first finds its monster (before the client's copy can be sure to have
// composed), hits part 0 for 30 and part 1 for 10: the client's part 0 reads Broken with its zone disabled and raised
// OnBroken exactly once; its part 1 reads Damaged and raised OnConditionChanged once.
// Surface: Ck.BodyPart.Net.AS_BodyPart_ALateBinderSeesABrokenPart
class UCk_AutoTest_Net_BodyPart_ALateBinderSeesABrokenPart : UMars_AutoTestRig_NetBodyPart
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(554000.0, 0.0, 5000.0);
    private const float32 k_BrokenHoldSeconds = 4.0f;

    private int32 _ServerHitFrame = -1;
    private int32 _ClientFoundFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BodyPart(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientPart0Broken", n"OnClientBroken", k_SlowPolls);
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
        _ServerHitFrame = int32(utils_time::Get_FrameCounter());
        Request_ServerPartHit(0, 30.0f);
        Request_ServerPartHit(1, 10.0f);
        WaitSeconds(k_BrokenHoldSeconds, n"OnServerHeldBroken");
    }

    UFUNCTION()
    private void OnServerHeldBroken(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Extra = f"hitFrame={_ServerHitFrame}";
        Log_PartRow("ALateBinderSeesABrokenPart", Extra);
        Assert_True(Get_IsPartState(0, EMars_BodyPart_State::Broken), "the server's part 0 is Broken");
        Assert_True(Get_IsPartCondition(1, EMars_BodyPart_Condition::Damaged), "the server's part 1 is Damaged");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_ClientPart0Broken(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsFound = Get_IsMonsterFound();
        if (IsFound && _ClientFoundFrame < 0)
        { _ClientFoundFrame = int32(utils_time::Get_FrameCounter()); }

        auto Result = OutResult;
        Result.Set(IsFound && Get_IsPartState(0, EMars_BodyPart_State::Broken));
    }

    UFUNCTION()
    private void OnClientBroken(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Extra = f"foundFrame={_ClientFoundFrame}";
        Log_PartRow("ALateBinderSeesABrokenPart", Extra);
        Assert_True(Get_IsPartState(0, EMars_BodyPart_State::Broken), "the client's part 0 reads Broken");
        Assert_Equals_Int(_PartSignals[0].Broken, 1, "the client's part 0 raised OnBroken exactly once");
        Assert_False(Get_IsPartZoneEnabled(0), "the client's part 0 zone is disabled");
        Assert_True(Get_IsPartCondition(1, EMars_BodyPart_Condition::Damaged), "the client's part 1 reads Damaged");
        Assert_Equals_Int(_PartSignals[1].ConditionChanged, 1, "the client's part 1 raised OnConditionChanged once");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
