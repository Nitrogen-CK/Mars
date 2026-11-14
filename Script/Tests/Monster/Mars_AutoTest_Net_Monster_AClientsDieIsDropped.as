// A client asks its copy of the monster to Die (Blunt) as soon as it composes: the copy drops it (alive, its Dead
// attribute at 0, no OnDied, no request left on it), and the server, watching for 5 s, never sees its monster die.
// Surface: Ck.Monster.Net.AS_Monster_AClientsDieIsDropped
class UCk_AutoTest_Net_Monster_AClientsDieIsDropped : UMars_AutoTestRig_NetMonster
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Base = FVector(541000.0, 0.0, 5000.0);
    private const float32 k_WatchSeconds = 5.0f;
    private const float32 k_ClientDropSeconds = 1.5f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

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
        Spawn_ServerMonster(0);
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
        Log_Row("AClientsDieIsDropped", "");
        Assert_False(_Monster.Get_IsDead(), "the server's monster is alive");
        Assert_Equals_Int(_Died, 0, "the server raised no OnDied");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_BluntDie(5.0f);
        WaitSeconds(k_ClientDropSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto HasRequests = _Monster.Has_Fragment(FMars_Fragment_Monster_Requests);
        const auto Extra = f"requestsLeft={HasRequests}";
        Log_Row("AClientsDieIsDropped", Extra);
        Assert_False(_Monster.Get_IsDead(), "the client's monster is alive");
        Assert_Equals_Int(Get_DeadValue(), 0, "the client's Dead attribute reads 0");
        Assert_Equals_Int(_Died, 0, "the client raised no OnDied");
        Assert_False(HasRequests, "no monster request is left on the client's copy");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
