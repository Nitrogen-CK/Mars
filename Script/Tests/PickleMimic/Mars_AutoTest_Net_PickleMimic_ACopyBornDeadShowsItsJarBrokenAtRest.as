// A harness record, not a feature's state: what the recorder's base script showed at the recorder's second tick (by
// then the base's own tick has run at least once), the OnDied its monster raised from the construct on, and the frames.
struct FMars_TESTONLY_Fragment_PickleMimicBornDead_Shown
{
    UPROPERTY()
    int32 Ticks = 0;

    UPROPERTY()
    bool Recorded = false;

    UPROPERTY()
    bool Shattered = false;

    UPROPERTY()
    float32 Topple = 0.0f;

    UPROPERTY()
    int32 LandedShards = 0;

    UPROPERTY()
    int32 Shards = 0;

    UPROPERTY()
    int32 Died = 0;

    UPROPERTY()
    int32 ConstructFrame = -1;

    UPROPERTY()
    int32 FirstTickFrame = -1;

    UPROPERTY()
    int32 RecordFrame = -1;
}

// A harness fixture: the real mimic script whose authority, as it composes, asks its monster to die, so the death is in
// the spawn frame's ledger and a copy is born into it. Every machine records what its script shows.
class UMars_TESTONLY_PickleMimic_BornDeadRecorder_EntityScript : UMars_PickleMimic_EntityScript
{
    private FCk_Handle _ShownEntity;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);
        auto BornMimic = InHandle.As_PickleMimic(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(BornMimic), f"[CreatureStandingNetTest] [{InHandle.ToString()}] the recorder composed no mimic"))
        { return Flow; }

        _ShownEntity = InHandle;
        auto Shown = FMars_TESTONLY_Fragment_PickleMimicBornDead_Shown();
        Shown.ConstructFrame = int32(utils_time::Get_FrameCounter());
        InHandle.Add_Fragment(Shown);

        auto BornMonster = BornMimic.Get_Monster();
        BornMonster.BindTo_OnDied(FMars_Delegate_Monster_OnDied(this, n"OnShownDied"));
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnShownTick"));

        if (utils_net::Get_HasAuthority(InHandle))
        { BornMonster.Request_Die(FMars_Request_Monster_Die(FMars_DamageEvent(1000.0f, GameplayTags::DamageType_Mars_Blunt))); }

        return Flow;
    }

    UFUNCTION()
    private void OnShownDied(FCk_Handle_Monster InMonster, FMars_DamageEvent InCause)
    {
        if (ck::IsValid(_ShownEntity) && _ShownEntity.Has_Fragment(FMars_TESTONLY_Fragment_PickleMimicBornDead_Shown))
        { _ShownEntity.Get_Fragment(FMars_TESTONLY_Fragment_PickleMimicBornDead_Shown).Died += 1; }
    }

    UFUNCTION()
    private void OnShownTick(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_ShownEntity) || _ShownEntity.Has_Fragment(FMars_TESTONLY_Fragment_PickleMimicBornDead_Shown) == false)
        { return; }

        auto& Shown = _ShownEntity.Get_Fragment(FMars_TESTONLY_Fragment_PickleMimicBornDead_Shown);
        Shown.Ticks += 1;
        if (Shown.Ticks == 1)
        { Shown.FirstTickFrame = int32(utils_time::Get_FrameCounter()); }

        if (Shown.Ticks != 2)
        { return; }

        Shown.Recorded = true;
        Shown.RecordFrame = int32(utils_time::Get_FrameCounter());
        Shown.Shattered = Get_IsShattered();
        Shown.Topple = Get_ToppleAlpha();
        Shown.LandedShards = Get_LandedShardCount();
        Shown.Shards = Get_ShardCount();
    }
}

// The server's mimic is born dead (the fixture above, with visuals). The server's own script plays the death: at its
// recorder's second tick the jar has shattered and has only begun to topple. The client's copy was born into the death:
// its monster reads the death taken as it stands, it raised OnDied once, and its script shows the jar at the death's
// end at once: shattered, fully toppled, its ten shards all at rest.
// Surface: Ck.PickleMimic.Net.AS_PickleMimic_ACopyBornDeadShowsItsJarBrokenAtRest
class UCk_AutoTest_Net_PickleMimic_ACopyBornDeadShowsItsJarBrokenAtRest : UMars_AutoTestRig_NetPickleMimic
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_BornDeadBase = FVector(800000.0, 0.0, 5000.0);
    private const float32 k_BornDeadCorpseSeconds = 6.0f;
    private const float32 k_BornDeadServerSettle = 2.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MimicRow(k_BornDeadBase);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_BornDeadRecorded", n"OnClientRecorded", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Params = UMars_PickleMimic_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Base + FVector(0.0, 0.0, utils_pickle_mimic::Clearance));
        Params.Spec = Make_RowSpec();
        Params.Spec.Vitals.CorpseSeconds = k_BornDeadCorpseSeconds;
        Params.WithVisuals = true;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
            UMars_TESTONLY_PickleMimic_BornDeadRecorder_EntityScript, Params);
        WaitUntil(n"Is_BornDeadRecorded", n"OnServerRecorded", k_SlowPolls);
    }

    // Found, dead and its record written; quiet once the copy is gone.
    UFUNCTION()
    private void Is_BornDeadRecorded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsMimicFound() && Get_IsMimicGone() == false && _Mimic.Get_IsDead()
            && _Mimic.Has_Fragment(FMars_TESTONLY_Fragment_PickleMimicBornDead_Shown)
            && _Mimic.Get_Fragment(FMars_TESTONLY_Fragment_PickleMimicBornDead_Shown).Recorded);
    }

    UFUNCTION()
    private void OnServerRecorded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_BornDeadServerSettle, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsMimicGone())
        { FinishFailure("the server's mimic was gone before it was checked"); return; }

        const auto Shown = _Mimic.Get_Fragment(FMars_TESTONLY_Fragment_PickleMimicBornDead_Shown);
        const auto Taken = _MimicMonster.Get_DeathTaken();
        Log_BornDead(Shown, Taken);
        Assert_True(Taken == EMars_Net_Reconcile::AsItArrives, f"the server took its death as it arrives (reads {Taken :n})");
        Assert_True(Shown.Shattered, "the server's script had shattered the jar");
        Assert_True(Shown.Topple < 0.5f, f"the server's jar had only begun to topple (recorded {Shown.Topple})");
        Hold_MimicServerRow("ACopyBornDeadShowsItsJarBrokenAtRest", "");
    }

    UFUNCTION()
    private void OnClientRecorded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsMimicGone())
        { FinishFailure("the client's copy was gone before it was checked"); return; }

        const auto Shown = _Mimic.Get_Fragment(FMars_TESTONLY_Fragment_PickleMimicBornDead_Shown);
        const auto Taken = _MimicMonster.Get_DeathTaken();
        Log_BornDead(Shown, Taken);
        Assert_True(Taken == EMars_Net_Reconcile::AsItStands, f"the client took its death as it stands (reads {Taken :n})");
        Assert_Equals_Int(Shown.Died, 1, "the client's monster raised OnDied exactly once");
        Assert_Equals_Int(_MimicDied, 1, "the rig counted OnDied exactly once");
        Assert_True(Shown.Shattered, "the client's script shows the jar shattered");
        Assert_True(Math::Abs(Shown.Topple - 1.0f) <= 1e-3f, f"the client's jar is shown fully toppled (recorded {Shown.Topple})");
        Assert_Equals_Int(Shown.Shards, utils_pickle_mimic::ShardCount, "the client's script holds every shard");
        Assert_Equals_Int(Shown.LandedShards, Shown.Shards, "every shard on the client is at rest");
        Finish_MimicRow("ACopyBornDeadShowsItsJarBrokenAtRest", "");
    }

    private void Log_BornDead(FMars_TESTONLY_Fragment_PickleMimicBornDead_Shown InShown, EMars_Net_Reconcile InTaken)
    {
        const auto Line = f"[CreatureStandingNetTest] ACopyBornDeadShowsItsJarBrokenAtRest {Get_MachineName()} deathTaken={InTaken :n} shattered={InShown.Shattered} topple={InShown.Topple} landed={InShown.LandedShards}/{InShown.Shards} died={InShown.Died} rigDied={_MimicDied} construct={InShown.ConstructFrame} firstTick={InShown.FirstTickFrame} record={InShown.RecordFrame} found={_MimicFoundFrame} notifies=[{_MimicLedgerNotifies}] ensures={Get_NewEnsures()}";
        Log(Line);
    }
}
