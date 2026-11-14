// A settled Pickle Mimic that spills 3 pickles and whose corpse lasts 3 s takes a lethal blow on the server. The server
// alone spills its jar: OnSpill once with 3, Spilled set, and 3 pickles near the base that it has authority over, which
// stay once the corpse is gone. The client's copy raises OnDied exactly once and never spills (OnSpill 0, Spilled not
// set), yet 3 pickles lie near the base on its machine too, none of them its own, and they stay once its copy is gone.
// Surface: Ck.PickleMimic.Net.AS_PickleMimic_TheJarSpillsOnceAndItsPicklesReachTheClient
class UCk_AutoTest_Net_PickleMimic_TheJarSpillsOnceAndItsPicklesReachTheClient : UMars_AutoTestRig_NetPickleMimic
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(630000.0, 0.0, 5000.0);
    private const int32 k_Pickles = 3;
    private const float32 k_CorpseLasts = 3.0f;
    private const float32 k_LethalBlow = 1000.0f;

    // What this machine's copy read one second after it died (the log line is written once it is gone).
    private FString _AtDead = "";

    private FString Describe_AtDead()
    {
        return f"atDead=[dead {_Mimic.Get_IsDead()} spills {_MimicSpills}/{_MimicLastSpillCount} spilled {_Mimic.Get_Hurt().Spilled} died {_MimicDied} diedFrame {_MimicDiedFrame} spillFrame {_MimicSpillFrame} {Describe_Pickles()}]";
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MimicRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_MimicDead", n"OnClientDead", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Spec = Make_RowSpec();
        Spec.Vitals.SpilledPickles = k_Pickles;
        Spec.Vitals.CorpseSeconds = k_CorpseLasts;
        Spawn_ServerMimic(Spec);
        WaitUntil(n"Is_MimicSettled", n"OnServerSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_StandSeconds, n"OnServerStands");
    }

    UFUNCTION()
    private void OnServerStands(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(k_LethalBlow, GameplayTags::DamageType_Mars_Blunt)));
        WaitSampling(k_SettleSeconds, n"OnServerStruck");
    }

    UFUNCTION()
    private void OnServerStruck(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _AtDead = Describe_AtDead();
        Assert_True(_Mimic.Get_IsDead(), "the server's mimic is dead");
        Assert_Equals_Int(_MimicSpills, 1, "the server raised OnSpill exactly once");
        Assert_Equals_Int(_MimicLastSpillCount, k_Pickles, "the server's spill carried the spec's pickles");
        Assert_True(_Mimic.Get_Hurt().Spilled, "the server's mimic reads spilled");
        Assert_Equals_Int(Get_PicklesNearBase().Num(), k_Pickles, "the spec's pickles lie near the base on the server");
        Assert_Equals_Int(Get_PicklesWithAuthority(), k_Pickles, "the server has authority over every pickle");
        Track_ServerPickles();
        WaitUntil(n"Is_MimicGone", n"OnServerGone", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_PicklesNearBase().Num(), k_Pickles, "the pickles outlive the corpse on the server");
        Hold_MimicServerRow("TheJarSpillsOnceAndItsPicklesReachTheClient", _AtDead);
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
        Assert_Equals_Int(_MimicDied, 1, "the client raised OnDied exactly once");
        Assert_Equals_Int(_MimicSpills, 0, "the client's copy raised no OnSpill");
        Assert_False(_Mimic.Get_Hurt().Spilled, "the client's copy never spilled");
        Assert_Equals_Int(Get_PicklesNearBase().Num(), k_Pickles, "the server's pickles lie near the base on the client");
        Assert_Equals_Int(Get_PicklesWithAuthority(), 0, "the client has authority over no pickle");
        WaitUntil(n"Is_MimicGone", n"OnClientGone", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_PicklesNearBase().Num(), k_Pickles, "the pickles outlive the corpse on the client");
        Finish_MimicRow("TheJarSpillsOnceAndItsPicklesReachTheClient", _AtDead);
    }
}
