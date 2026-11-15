// The server's monster is born with part 0 hit for 30 and broken and part 1 hit for 10, in its spawn frame: the
// client's copy takes the ledger as it stands at its first notify, where part 0 reads Broken with its zone disabled
// and raised OnConditionChanged and OnBroken exactly once, and part 1 reads Damaged and raised OnConditionChanged once.
// Surface: Ck.BodyPart.Net.AS_BodyPart_ALateBinderSeesABrokenPart
class UCk_AutoTest_Net_BodyPart_ALateBinderSeesABrokenPart : UMars_AutoTestRig_NetBodyPart
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(554000.0, 0.0, 5000.0);
    private const float32 k_BrokenHoldSeconds = 4.0f;

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
        Spawn_ServerMonsterOfClass(0.0f, UMars_TESTONLY_NetCombat_BornMonster_EntityScript);
        WaitUntil(n"Is_MonsterFound", n"OnServerFound", k_SlowPolls);
    }

    // The server finds its monster before the spawn frame's drain has run.
    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ServerBornBroken", n"OnServerBornBroken", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerBornBroken(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsBornLedger(Get_Ledger()));
    }

    private bool Get_IsBornLedger(const FMars_Fragment_BodyPart_Net& InLedger) const
    {
        const auto Part0 = InLedger.Get_Entry(0);
        const auto Part1 = InLedger.Get_Entry(1);
        return InLedger.Parts.Num() == k_PartCount
            && Part0.State == EMars_BodyPart_State::Broken && Part0.Condition == EMars_BodyPart_Condition::Damaged
            && Part1.State == EMars_BodyPart_State::Attached && Part1.Condition == EMars_BodyPart_Condition::Damaged;
    }

    UFUNCTION()
    private void OnServerBornBroken(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_BrokenHoldSeconds, n"OnServerHeldBroken");
    }

    UFUNCTION()
    private void OnServerHeldBroken(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_PartRow("ALateBinderSeesABrokenPart", "");
        Assert_True(Get_IsPartState(0, EMars_BodyPart_State::Broken), "the server's part 0 is Broken");
        Assert_True(Get_IsPartCondition(1, EMars_BodyPart_Condition::Damaged), "the server's part 1 is Damaged");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_ClientPart0Broken(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsMonsterFound() && Get_IsPartState(0, EMars_BodyPart_State::Broken));
    }

    UFUNCTION()
    private void OnClientBroken(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto FirstFrame = Get_RosterFirstNotifyFrame();
        const auto Line = Describe_MonsterFind();
        const auto Part0 = _PartSignals[0];
        const auto Part1 = _PartSignals[1];
        Log_PartRow("ALateBinderSeesABrokenPart", "");
        Assert_True(Get_RosterInitialState() == EMars_Net_InitialState::Taken, f"the client's roster took the state it was born into ({Line})");
        Assert_True(_RosterInitialAtFind == EMars_Net_InitialState::Awaited, f"the client took its monster before its ledger's first application ({Line})");
        Assert_True(_RosterNotifyFrames.Num() > 0, f"the client recorded a rep-notify of its copy's part ledger ({Line})");
        Assert_True(Get_IsBornLedger(Get_RosterFirstNotifyLedger()), f"the first notify carried the parts it was born into ({Line})");
        Assert_True(Get_IsPartState(0, EMars_BodyPart_State::Broken), "the client's part 0 reads Broken");
        Assert_Equals_Int(Part0.Broken, 1, f"the client's part 0 raised OnBroken exactly once ({Line})");
        Assert_Equals_Int(Part0.BrokenFrame, FirstFrame, f"the client's part 0 broke in its first notify's frame ({Line})");
        Assert_Equals_Int(Part0.ConditionChanged, 1, f"the client's part 0 raised OnConditionChanged exactly once ({Line})");
        Assert_True(Part0.LastOld == EMars_BodyPart_Condition::Pristine && Part0.LastNew == EMars_BodyPart_Condition::Damaged,
            f"the client's part 0 went from Pristine to Damaged ({Line})");
        Assert_Equals_Int(Part0.ConditionFrame, FirstFrame, f"the client's part 0 changed its condition in its first notify's frame ({Line})");
        Assert_Equals_Int(Part0.Severed, 0, f"the client's part 0 raised no OnSevered ({Line})");
        Assert_False(Get_IsPartZoneEnabled(0), "the client's part 0 zone is disabled");
        Assert_True(Get_IsPartCondition(1, EMars_BodyPart_Condition::Damaged), "the client's part 1 reads Damaged");
        Assert_Equals_Int(Part1.ConditionChanged, 1, f"the client's part 1 raised OnConditionChanged once ({Line})");
        Assert_Equals_Int(Part1.ConditionFrame, FirstFrame, f"the client's part 1 changed its condition in its first notify's frame ({Line})");
        Assert_Equals_Int(Part1.Broken, 0, f"the client's part 1 raised no OnBroken ({Line})");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
