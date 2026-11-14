// A client claims a cleaver blow (20 Sever) on part 1 of the server's monster, then another 0.6 s later: the server
// applies both and part 1 breaks; on the client part 1 reads Broken with its zone disabled, and raised OnBroken once and
// OnConditionChanged once.
// Surface: Ck.BodyPart.Net.AS_BodyPart_AClientsBlowsBreakAPartOnBothMachines
class UCk_AutoTest_Net_BodyPart_AClientsBlowsBreakAPartOnBothMachines : UMars_AutoTestRig_NetBodyPart
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(556000.0, 0.0, 5000.0);
    private const int32 k_ClaimedPart = 1;

    private int32 _SecondClaimFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BodyPartStrike(k_Base, k_ClaimedPart);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientReadyToClaimAPart", n"OnClientReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ServerReady", n"OnServerReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Arm_Server();
        WaitUntil(n"Is_Armed", n"OnServerArmed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerArmed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerMonster(0.0f);
        WaitUntil(n"Is_ClaimedPartBroken", n"OnServerBroken", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClaimedPartBroken(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsMonsterFound() && Get_IsPartState(k_ClaimedPart, EMars_BodyPart_State::Broken));
    }

    UFUNCTION()
    private void OnServerBroken(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds, n"OnServerEnd");
    }

    UFUNCTION()
    private void OnServerEnd(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Tally = Get_Tally();
        const auto Extra = f"tally=[applied {Tally.Applied} refused {Tally.Refused}]";
        Log_PartRow("AClientsBlowsBreakAPartOnBothMachines", Extra);
        Assert_Equals_Int(Tally.Applied, 2, "the server applied both claims");
        Assert_True(Get_IsPartState(k_ClaimedPart, EMars_BodyPart_State::Broken), "the server's part 1 is Broken");
        Assert_Equals_Int(_PartSignals[k_ClaimedPart].Broken, 1, "the server's part 1 raised OnBroken once");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Fire_Claim(Make_PartClaim(k_ClaimedPart));
        WaitSeconds(k_ClaimSpacingSeconds, n"OnClientSecondClaim");
    }

    UFUNCTION()
    private void OnClientSecondClaim(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _SecondClaimFrame = int32(utils_time::Get_FrameCounter());
        Fire_Claim(Make_PartClaim(k_ClaimedPart));
        WaitUntil(n"Is_ClaimedPartBroken", n"OnClientBroken", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientBroken(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Claim = Make_PartClaim(k_ClaimedPart);
        const auto Distances = Describe_Distances(Claim.Location);
        const auto Extra = f"secondClaimFrame={_SecondClaimFrame} {Distances}";
        Log_PartRow("AClientsBlowsBreakAPartOnBothMachines", Extra);
        Assert_True(Get_IsPartState(k_ClaimedPart, EMars_BodyPart_State::Broken), "the client's part 1 reads Broken");
        Assert_False(Get_IsPartZoneEnabled(k_ClaimedPart), "the client's part 1 zone is disabled");
        Assert_Equals_Int(_PartSignals[k_ClaimedPart].Broken, 1, "the client's part 1 raised OnBroken once");
        Assert_Equals_Int(_PartSignals[k_ClaimedPart].ConditionChanged, 1, "the client's part 1 raised OnConditionChanged once");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
