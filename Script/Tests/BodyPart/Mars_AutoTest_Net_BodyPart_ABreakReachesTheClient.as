// The server hits part 1 of its monster for 30 (its whole Health): on both machines part 1 reads Broken with its zone
// disabled, OnBroken was raised exactly once and never OnSevered, and the monster counts one attached part.
// Surface: Ck.BodyPart.Net.AS_BodyPart_ABreakReachesTheClient
class UCk_AutoTest_Net_BodyPart_ABreakReachesTheClient : UMars_AutoTestRig_NetBodyPart
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(551000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BodyPart(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientPart1Broken", n"OnClientBroken", k_SlowPolls);
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
        Request_ServerPartHit(1, 30.0f);
        WaitSeconds(k_ServerHoldSeconds, n"OnServerEnd");
    }

    UFUNCTION()
    private void OnServerEnd(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_PartRow("ABreakReachesTheClient", "");
        Assert_Broken("server");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_ClientPart1Broken(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsMonsterFound() && Get_IsPartState(1, EMars_BodyPart_State::Broken));
    }

    UFUNCTION()
    private void OnClientBroken(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_PartRow("ABreakReachesTheClient", "");
        Assert_Broken("client");
        FinishSuccess();
    }

    private void Assert_Broken(FString InMachine)
    {
        Assert_True(Get_IsPartState(1, EMars_BodyPart_State::Broken), f"the {InMachine}'s part 1 reads Broken");
        Assert_False(Get_IsPartZoneEnabled(1), f"the {InMachine}'s part 1 zone is disabled");
        Assert_Equals_Int(_PartSignals[1].Broken, 1, f"the {InMachine}'s part 1 raised OnBroken exactly once");
        Assert_Equals_Int(_PartSignals[1].Severed, 0, f"the {InMachine}'s part 1 raised no OnSevered");
        Assert_Equals_Int(_Monster.Get_AttachedPartCount(), 1, f"the {InMachine}'s monster counts one attached part");
        Assert_Equals_Int(Get_NewEnsures(), 0, f"no ensure on the {InMachine}");
    }
}
