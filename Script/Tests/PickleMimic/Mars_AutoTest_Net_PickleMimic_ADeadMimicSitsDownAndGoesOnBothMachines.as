// A standing Pickle Mimic whose corpse lasts 3 s takes a lethal blow on the server: on both machines it reads dead, its
// body zone goes off, it sits back down with its lid at the dead gape and its action over, and then its entity is gone
// on both. Only the server spills its jar (OnSpill once, with nothing in it, Spilled set); the client's copy raises
// OnDied exactly once, derives the heaviest crack from its body Health and never spills; no world item appears near
// the base on either machine.
// Surface: Ck.PickleMimic.Net.AS_PickleMimic_ADeadMimicSitsDownAndGoesOnBothMachines
class UCk_AutoTest_Net_PickleMimic_ADeadMimicSitsDownAndGoesOnBothMachines : UMars_AutoTestRig_NetPickleMimic
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(617000.0, 0.0, 5000.0);
    private const FVector k_PreyOffset = FVector(380.0, 0.0, 0.0);
    private const float32 k_CorpseLasts = 3.0f;
    private const float32 k_LethalBlow = 1000.0f;
    private const float64 k_ItemRadius = 500.0;

    // What this machine's copy read one second after it died (the log line is written once it is gone).
    private FString _AtDead = "";

    private FString Describe_AtDead()
    {
        return f"atDead=[dead {_Mimic.Get_IsDead()} zoneEnabled {_Zone.Get_IsEnabled()} stance {_Mimic.Get_Stance() :n} rise {_Mimic.Get_Rise()} lid {_Mimic.Get_LidOpen()} action {_Mimic.Get_Action().Kind :n} crack {_Mimic.Get_CrackStage()} spills {_MimicSpills}/{_MimicLastSpillCount} spilled {_Mimic.Get_Hurt().Spilled} died {_MimicDied} items {Count_WorldItemsNearBase()}]";
    }

    // World items within k_ItemRadius of the base on this machine, not being destroyed.
    private int32 Count_WorldItemsNearBase()
    {
        auto Count = 0;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            if (utils_entity_lifetime::Get_IsPendingDestroy(Candidate, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
            { continue; }

            const auto Transform = Candidate.As_Transform(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(Transform) && (utils_transform::Get_EntityCurrentLocation(Transform) - _Base).Size() <= k_ItemRadius)
            { Count += 1; }
        }

        return Count;
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
        Spawn_ServerPrey(k_PreyOffset);
        WaitUntil(n"Is_MimicStanding", n"OnServerStanding", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerStanding(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(k_LethalBlow, GameplayTags::DamageType_Mars_Blunt)));
        WaitSampling(k_SettleSeconds, n"OnServerStruck");
    }

    UFUNCTION()
    private void OnServerStruck(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _AtDead = Describe_AtDead();
        Assert_True(_Mimic.Get_IsDead(), "the server's mimic is dead");
        Assert_False(_Zone.Get_IsEnabled(), "the server's body zone is off");
        Assert_True(_Mimic.Get_Stance() == EMars_PickleMimic_Stance::Tucked, "the server's mimic sits back down");
        Assert_True(_Mimic.Get_Action().Kind == EMars_PickleMimic_Action::None, "the server's mimic runs no action");
        Assert_Equals_Int(_MimicSpills, 1, "the server raised OnSpill exactly once");
        Assert_Equals_Int(_MimicLastSpillCount, 0, "the server's spill carried no pickles");
        Assert_True(_Mimic.Get_Hurt().Spilled, "the server's mimic reads spilled");
        Assert_Equals_Int(Count_WorldItemsNearBase(), 0, "no world item near the base on the server");
        WaitUntil(n"Is_MimicGone", n"OnServerGone", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Hold_MimicServerRow("ADeadMimicSitsDownAndGoesOnBothMachines", _AtDead);
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
        const auto Lid = _Mimic.Get_LidOpen();
        Assert_Equals_Int(_MimicDied, 1, "the client raised OnDied exactly once");
        Assert_False(_Zone.Get_IsEnabled(), "the client's body zone is off");
        Assert_True(_Mimic.Get_Stance() == EMars_PickleMimic_Stance::Tucked, "the client's mimic sits back down");
        Assert_True(_Mimic.Get_Rise() < 1.0f, "the client's mimic is no longer fully up");
        Assert_True(_Mimic.Get_Action().Kind == EMars_PickleMimic_Action::None, "the client's mimic runs no action");
        Assert_True(Math::Abs(Lid - utils_pickle_mimic::DeadGape) <= 0.2f, f"the client's lid is within 0.2 of the dead gape (reads {Lid})");
        Assert_Equals_Int(_Mimic.Get_CrackStage(), 2, "the client's glass is heavily cracked");
        Assert_Equals_Int(_MimicSpills, 0, "the client's copy raised no OnSpill");
        Assert_False(_Mimic.Get_Hurt().Spilled, "the client's copy never spilled");
        Assert_Equals_Int(Count_WorldItemsNearBase(), 0, "no world item near the base on the client");
        WaitUntil(n"Is_MimicGone", n"OnClientGone", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Finish_MimicRow("ADeadMimicSitsDownAndGoesOnBothMachines", _AtDead);
    }
}
