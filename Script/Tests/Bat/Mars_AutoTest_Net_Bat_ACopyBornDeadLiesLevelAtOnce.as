// A harness record, not a feature's state: the hang and the lie the recorder's base script showed at the recorder's
// first tick and at its second (by then the base's own tick has run at least once), and the frames.
struct FMars_TESTONLY_Fragment_BatBornDead_Shown
{
    UPROPERTY()
    int32 Ticks = 0;

    UPROPERTY()
    bool Recorded = false;

    UPROPERTY()
    float32 Hang = 0.0f;

    UPROPERTY()
    float32 Down = 0.0f;

    UPROPERTY()
    float32 HangAtFirstTick = -1.0f;

    UPROPERTY()
    int32 ConstructFrame = -1;

    UPROPERTY()
    int32 FirstTickFrame = -1;

    UPROPERTY()
    int32 RecordFrame = -1;
}

// A harness fixture: the held bat (its ledger held at the row's values from the spawn frame) that records, on every
// machine, the hang and the lie its script shows.
class UMars_TESTONLY_Bat_BornDeadRecorder_EntityScript : UMars_NetBat_Held_EntityScript
{
    private FCk_Handle _ShownEntity;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);
        if (ck::EnsureIfNot(InHandle.Is_Bat(), f"[CreatureStandingNetTest] [{InHandle.ToString()}] the recorder composed no bat"))
        { return Flow; }

        _ShownEntity = InHandle;
        auto Shown = FMars_TESTONLY_Fragment_BatBornDead_Shown();
        Shown.ConstructFrame = int32(utils_time::Get_FrameCounter());
        InHandle.Add_Fragment(Shown);
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnShownTick"));
        return Flow;
    }

    UFUNCTION()
    private void OnShownTick(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_ShownEntity) || _ShownEntity.Has_Fragment(FMars_TESTONLY_Fragment_BatBornDead_Shown) == false)
        { return; }

        auto& Shown = _ShownEntity.Get_Fragment(FMars_TESTONLY_Fragment_BatBornDead_Shown);
        Shown.Ticks += 1;
        if (Shown.Ticks == 1)
        {
            Shown.FirstTickFrame = int32(utils_time::Get_FrameCounter());
            Shown.HangAtFirstTick = Get_HangAlpha();
        }

        if (Shown.Ticks != 2)
        { return; }

        Shown.Recorded = true;
        Shown.RecordFrame = int32(utils_time::Get_FrameCounter());
        Shown.Hang = Get_HangAlpha();
        Shown.Down = Get_DownAlpha();
    }
}

// The server holds its roosting bat's ledger at Dead from the spawn frame on (its own kernel roosts on). The server's
// script shows its own bat hanging. The client's copy is born into a dead bat: its script shows it lying level at once,
// neither hanging nor turning out of a roost pose.
// Surface: Ck.Bat.Net.AS_Bat_ACopyBornDeadLiesLevelAtOnce
class UCk_AutoTest_Net_Bat_ACopyBornDeadLiesLevelAtOnce : UMars_AutoTestRig_NetBat
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_BornDeadFloor = FVector(803000.0, 0.0, 5000.0);
    private const float32 k_BornDeadServerSettle = 2.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BatRow(k_BornDeadFloor);
        _WithVisuals = true;

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_BatFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        Begin_ServerWorld(n"OnServerReady");
    }

    // Both machines compute it alike: dead, the roost's anchor kept.
    private FMars_Fragment_Bat_Net Make_BornDeadLedger() const
    {
        auto Ledger = FMars_Fragment_Bat_Net();
        Ledger.Phase = EMars_Bat_Phase::Dead;
        Ledger.PerchAnchor = Get_RoostAnchor();
        return Ledger;
    }

    // The rig's spawn, as the recorder above.
    protected void Spawn_ServerBat() override
    {
        auto Spec = _Spec;
        Spec.Volume = _Volume;
        Spec.Roost.PerchOwner = _Roost;

        auto Params = FMars_NetBat_Held_SpawnParams();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _HangAt);
        Params.Spec = Spec;
        Params.WithVisuals = true;
        Params.HeldLedger = Make_BornDeadLedger();
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
            UMars_TESTONLY_Bat_BornDeadRecorder_EntityScript, Params);
    }

    // The record is written; quiet once the copy is gone.
    UFUNCTION()
    private void Is_BornDeadRecorded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsBatGone() == false && _Bat.Has_Fragment(FMars_TESTONLY_Fragment_BatBornDead_Shown)
            && _Bat.Get_Fragment(FMars_TESTONLY_Fragment_BatBornDead_Shown).Recorded);
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_BornDeadRecorded", n"OnServerRecorded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerRecorded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_BornDeadServerSettle, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsBatGone())
        { FinishFailure("the server's bat was gone before it was checked"); return; }

        const auto Shown = _Bat.Get_Fragment(FMars_TESTONLY_Fragment_BatBornDead_Shown);
        Log_BornDead(Shown);
        Assert_True(Shown.Hang > 0.5f, f"the server's own bat is shown hanging (recorded {Shown.Hang})");
        Hold_BatServerRow("ACopyBornDeadLiesLevelAtOnce", "");
    }

    // The copy reads Dead and its record is written; quiet once the copy is gone.
    UFUNCTION()
    private void Is_BornDeadShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsBatGone() == false && _Bat.Get_Phase() == EMars_Bat_Phase::Dead
            && _Bat.Has_Fragment(FMars_TESTONLY_Fragment_BatBornDead_Shown)
            && _Bat.Get_Fragment(FMars_TESTONLY_Fragment_BatBornDead_Shown).Recorded);
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_BornDeadShown", n"OnClientShown", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientShown(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsBatGone())
        { FinishFailure("the client's copy was gone before it was checked"); return; }

        const auto Shown = _Bat.Get_Fragment(FMars_TESTONLY_Fragment_BatBornDead_Shown);
        Log_BornDead(Shown);
        Assert_True(Shown.Hang < 0.01f, f"the client's copy is not shown hanging (recorded {Shown.Hang})");
        Assert_True(Shown.Down > 0.99f, f"the client's copy is shown lying level (recorded {Shown.Down})");
        Finish_BatRow("ACopyBornDeadLiesLevelAtOnce", "");
    }

    private void Log_BornDead(FMars_TESTONLY_Fragment_BatBornDead_Shown InShown)
    {
        const auto FirstNotify = Get_BatFirstNotifyFrame();
        const auto Line = f"[CreatureStandingNetTest] ACopyBornDeadLiesLevelAtOnce {Get_MachineName()} phase={_Bat.Get_Phase() :n} hang={InShown.Hang} down={InShown.Down} hangAtFirstTick={InShown.HangAtFirstTick} construct={InShown.ConstructFrame} firstTick={InShown.FirstTickFrame} record={InShown.RecordFrame} found={_BatFoundFrame} firstNotify={FirstNotify} ensures={Get_NewEnsures()}";
        Log(Line);
    }
}
