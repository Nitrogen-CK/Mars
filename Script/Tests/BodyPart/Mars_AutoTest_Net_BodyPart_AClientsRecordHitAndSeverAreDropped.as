// A client asks its copy of part 0 to RecordHit (a Damages reaction, 10 Sever) and to Sever as soon as it composes: the
// copy drops both (Pristine, Attached, no signal, no request left on it), and the server, watching for 5 s, never sees
// its parts change or its ledger leave the defaults.
// Surface: Ck.BodyPart.Net.AS_BodyPart_AClientsRecordHitAndSeverAreDropped
class UCk_AutoTest_Net_BodyPart_AClientsRecordHitAndSeverAreDropped : UMars_AutoTestRig_NetBodyPart
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(553000.0, 0.0, 5000.0);
    private const float32 k_WatchSeconds = 5.0f;
    private const float32 k_ClientDropSeconds = 1.5f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BodyPart(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_MonsterFound", n"OnClientFound", k_SlowPolls);
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
        WaitSeconds(k_WatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_PartRow("AClientsRecordHitAndSeverAreDropped", "");
        for (int32 Index = 0; Index < k_PartCount; ++Index)
        {
            Assert_True(Get_IsPartCondition(Index, EMars_BodyPart_Condition::Pristine), f"the server's part {Index} is Pristine");
            Assert_True(Get_IsPartState(Index, EMars_BodyPart_State::Attached), f"the server's part {Index} is Attached");

            const auto Entry = Get_Ledger().Get_Entry(Index);
            Assert_True(Entry.State == EMars_BodyPart_State::Attached && Entry.Condition == EMars_BodyPart_Condition::Pristine,
                f"the server's ledger entry {Index} is the default");
        }

        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Event = FMars_DamageEvent(10.0f, GameplayTags::DamageType_Mars_Sever);
        auto Part = _Parts[0];
        Part.Request_RecordHit(FMars_Request_BodyPart_RecordHit(Event,
            FMars_HitZone_Reaction(GameplayTags::DamageType_Mars_Sever, 1.0f, EMars_HitZone_ConditionImpact::Damages)));
        Part.Request_Sever(FMars_Request_BodyPart_Sever(Event));
        WaitSeconds(k_ClientDropSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto HasRequests = _Parts[0].Has_Fragment(FMars_Fragment_BodyPart_Requests);
        const auto Extra = f"requestsLeft={HasRequests}";
        Log_PartRow("AClientsRecordHitAndSeverAreDropped", Extra);
        Assert_True(Get_IsPartCondition(0, EMars_BodyPart_Condition::Pristine), "the client's part 0 is Pristine");
        Assert_True(Get_IsPartState(0, EMars_BodyPart_State::Attached), "the client's part 0 is Attached");
        Assert_Equals_Int(_PartSignals[0].ConditionChanged + _PartSignals[0].Broken + _PartSignals[0].Severed, 0, "the client's part 0 raised no signal");
        Assert_False(HasRequests, "no part request is left on the client's part 0");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
