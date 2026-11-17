// A harness record, not a feature's state: what the recorder's base script showed at the recorder's second tick (by
// then the base's own tick has run at least once), the OnDied its monster raised from the construct on, and the frames.
struct FMars_TESTONLY_Fragment_RootMawBornDead_Shown
{
    UPROPERTY()
    int32 Ticks = 0;

    UPROPERTY()
    bool Recorded = false;

    UPROPERTY()
    float32 Wilt = 0.0f;

    UPROPERTY()
    int32 Died = 0;

    UPROPERTY()
    int32 ConstructFrame = -1;

    UPROPERTY()
    int32 FirstTickFrame = -1;

    UPROPERTY()
    int32 RecordFrame = -1;
}

// A harness fixture: the real Maw script whose authority, as it composes, asks its monster to die, so the death is in
// the spawn frame's ledger and a copy is born into it. Every machine records what its script shows.
class UMars_TESTONLY_RootMaw_BornDeadRecorder_EntityScript : UMars_RootMaw_EntityScript
{
    private FCk_Handle _ShownEntity;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);
        auto BornMaw = InHandle.As_RootMaw(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(BornMaw), f"[CreatureStandingNetTest] [{InHandle.ToString()}] the recorder composed no Maw"))
        { return Flow; }

        _ShownEntity = InHandle;
        auto Shown = FMars_TESTONLY_Fragment_RootMawBornDead_Shown();
        Shown.ConstructFrame = int32(utils_time::Get_FrameCounter());
        InHandle.Add_Fragment(Shown);

        auto BornMonster = BornMaw.Get_Monster();
        BornMonster.BindTo_OnDied(FMars_Delegate_Monster_OnDied(this, n"OnShownDied"));
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnShownTick"));

        if (utils_net::Get_HasAuthority(InHandle))
        { BornMonster.Request_Die(FMars_Request_Monster_Die(FMars_DamageEvent(1000.0f, GameplayTags::DamageType_Mars_Blunt))); }

        return Flow;
    }

    UFUNCTION()
    private void OnShownDied(FCk_Handle_Monster InMonster, FMars_DamageEvent InCause)
    {
        if (ck::IsValid(_ShownEntity) && _ShownEntity.Has_Fragment(FMars_TESTONLY_Fragment_RootMawBornDead_Shown))
        { _ShownEntity.Get_Fragment(FMars_TESTONLY_Fragment_RootMawBornDead_Shown).Died += 1; }
    }

    UFUNCTION()
    private void OnShownTick(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_ShownEntity) || _ShownEntity.Has_Fragment(FMars_TESTONLY_Fragment_RootMawBornDead_Shown) == false)
        { return; }

        auto& Shown = _ShownEntity.Get_Fragment(FMars_TESTONLY_Fragment_RootMawBornDead_Shown);
        Shown.Ticks += 1;
        if (Shown.Ticks == 1)
        { Shown.FirstTickFrame = int32(utils_time::Get_FrameCounter()); }

        if (Shown.Ticks != 2)
        { return; }

        Shown.Recorded = true;
        Shown.RecordFrame = int32(utils_time::Get_FrameCounter());
        Shown.Wilt = Get_Wilt();
    }
}

// The server's Maw is born dead (the fixture above, with visuals). The server's own script plays the wilt: at its
// recorder's second tick it has only begun. The client's copy was born into the death: its monster reads the death
// taken as it stands, it raised OnDied once, and its script shows the crown fully wilted at once.
// Surface: Ck.RootMaw.Net.AS_RootMaw_ACopyBornDeadIsWiltedAtOnce
class UCk_AutoTest_Net_RootMaw_ACopyBornDeadIsWiltedAtOnce : UMars_AutoTestRig_NetRootMaw
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_BornDeadBase = FVector(801000.0, 0.0, 5000.0);
    private const float32 k_BornDeadCorpseSeconds = 6.0f;
    private const float32 k_BornDeadServerSettle = 2.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MawRow(k_BornDeadBase);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_BornDeadRecorded", n"OnClientRecorded", k_SlowPolls);
            return;
        }

        Spawn_ServerMawFloor();
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Params = UMars_RootMaw_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Base + FVector(0.0, 0.0, utils_root_maw::Clearance));
        Params.Spec.Vitals.CorpseSeconds = k_BornDeadCorpseSeconds;
        Params.WithVisuals = true;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
            UMars_TESTONLY_RootMaw_BornDeadRecorder_EntityScript, Params);
        WaitUntil(n"Is_BornDeadRecorded", n"OnServerRecorded", k_SlowPolls);
    }

    // Found, dead and its record written; quiet once the copy is gone.
    UFUNCTION()
    private void Is_BornDeadRecorded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsMawFound() && Get_IsMawGone() == false && _Maw.Get_IsDead()
            && _Maw.Has_Fragment(FMars_TESTONLY_Fragment_RootMawBornDead_Shown)
            && _Maw.Get_Fragment(FMars_TESTONLY_Fragment_RootMawBornDead_Shown).Recorded);
    }

    UFUNCTION()
    private void OnServerRecorded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_BornDeadServerSettle, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsMawGone())
        { FinishFailure("the server's Maw was gone before it was checked"); return; }

        const auto Shown = _Maw.Get_Fragment(FMars_TESTONLY_Fragment_RootMawBornDead_Shown);
        const auto Taken = _MawMonster.Get_DeathTaken();
        Log_BornDead(Shown, Taken);
        Assert_True(Taken == EMars_Net_Reconcile::AsItArrives, f"the server took its death as it arrives (reads {Taken :n})");
        Assert_True(Shown.Wilt < 0.5f, f"the server's crown had only begun to wilt (recorded {Shown.Wilt})");
        Hold_MawServerRow("ACopyBornDeadIsWiltedAtOnce", "");
    }

    UFUNCTION()
    private void OnClientRecorded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsMawGone())
        { FinishFailure("the client's copy was gone before it was checked"); return; }

        const auto Shown = _Maw.Get_Fragment(FMars_TESTONLY_Fragment_RootMawBornDead_Shown);
        const auto Taken = _MawMonster.Get_DeathTaken();
        Log_BornDead(Shown, Taken);
        Assert_True(Taken == EMars_Net_Reconcile::AsItStands, f"the client took its death as it stands (reads {Taken :n})");
        Assert_Equals_Int(Shown.Died, 1, "the client's monster raised OnDied exactly once");
        Assert_Equals_Int(_MawDied, 1, "the rig counted OnDied exactly once");
        Assert_True(Math::Abs(Shown.Wilt - 1.0f) <= 1e-3f, f"the client's crown is shown fully wilted (recorded {Shown.Wilt})");
        Finish_MawRow("ACopyBornDeadIsWiltedAtOnce", "");
    }

    private void Log_BornDead(FMars_TESTONLY_Fragment_RootMawBornDead_Shown InShown, EMars_Net_Reconcile InTaken)
    {
        const auto Line = f"[CreatureStandingNetTest] ACopyBornDeadIsWiltedAtOnce {Get_MachineName()} deathTaken={InTaken :n} wilt={InShown.Wilt} died={InShown.Died} rigDied={_MawDied} construct={InShown.ConstructFrame} firstTick={InShown.FirstTickFrame} record={InShown.RecordFrame} found={_MawFoundFrame} firstNotify={_MawFirstLedgerNotifyFrame} ensures={Get_NewEnsures()}";
        Log(Line);
    }
}
