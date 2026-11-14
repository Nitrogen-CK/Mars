// A risen Root Maw whose corpse lasts 3 s takes a lethal blow on the server: on both machines it reads dead, its body
// zone goes off and it sinks back in, the client's copy raising OnDied exactly once, and then its entity is gone on
// both.
// Surface: Ck.RootMaw.Net.AS_RootMaw_ADeadMawSinksAndGoesOnBothMachines
class UCk_AutoTest_Net_RootMaw_ADeadMawSinksAndGoesOnBothMachines : UMars_AutoTestRig_NetRootMaw
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(575000.0, 0.0, 5000.0);
    private const FVector k_PreyOffset = FVector(400.0, 0.0, 0.0);
    private const float32 k_CorpseLasts = 3.0f;
    private const float32 k_LethalBlow = 1000.0f;

    // What this machine's copy read one second after it died (the log line is written once it is gone).
    private FString _AtDead = "";

    private FString Describe_AtDead()
    {
        return f"atDead=[dead {_Maw.Get_IsDead()} zoneEnabled {_Zone.Get_IsEnabled()} stance {_Maw.Get_Stance() :n} emerge {_Maw.Get_Emerge()} died {_MawDied}]";
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MawRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_MawDead", n"OnClientDead", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Spec = FMars_RootMaw_Spec();
        Spec.Vitals.CorpseSeconds = k_CorpseLasts;
        Spawn_ServerMawFloor();
        Spawn_ServerMaw(Spec);
        WaitUntil(n"Is_MawStanding", n"OnServerGrounded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerGrounded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_StandSeconds, n"OnServerStands");
    }

    UFUNCTION()
    private void OnServerStands(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerPrey(k_PreyOffset);
        WaitUntil(n"Is_MawEmerged", n"OnServerEmerged", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerEmerged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(k_LethalBlow, GameplayTags::DamageType_Mars_Blunt)));
        WaitSampling(k_SettleSeconds, n"OnServerStruck");
    }

    UFUNCTION()
    private void OnServerStruck(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _AtDead = Describe_AtDead();
        Assert_True(_Maw.Get_IsDead(), "the server's Maw is dead");
        Assert_False(_Zone.Get_IsEnabled(), "the server's body zone is off");
        Assert_True(_Maw.Get_Stance() == EMars_RootMaw_Stance::Buried, "the server's Maw sinks back in");
        WaitUntil(n"Is_MawGone", n"OnServerGone", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Hold_MawServerRow("ADeadMawSinksAndGoesOnBothMachines", _AtDead);
    }

    UFUNCTION()
    private void OnClientDead(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _AtDead = Describe_AtDead();
        Assert_Equals_Int(_MawDied, 1, "the client raised OnDied exactly once");
        Assert_False(_Zone.Get_IsEnabled(), "the client's body zone is off");
        Assert_True(_Maw.Get_Stance() == EMars_RootMaw_Stance::Buried, "the client's Maw sinks back in");
        Assert_True(_Maw.Get_Emerge() < 1.0f, "the client's Maw is no longer fully up");
        WaitUntil(n"Is_MawGone", n"OnClientGone", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Finish_MawRow("ADeadMawSinksAndGoesOnBothMachines", _AtDead);
    }
}
