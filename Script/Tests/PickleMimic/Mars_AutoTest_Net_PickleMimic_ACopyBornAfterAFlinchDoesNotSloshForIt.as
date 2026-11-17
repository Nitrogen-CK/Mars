// A harness record, not a feature's state: the blows the recorder's base script answered, copied at every recorder
// tick, what it read at the first, whether the second has passed (by then the base's own tick has run at least once),
// and the frames.
struct FMars_TESTONLY_Fragment_PickleMimicBornFlinched_Shown
{
    UPROPERTY()
    int32 Ticks = 0;

    UPROPERTY()
    bool Recorded = false;

    UPROPERTY()
    int32 FlinchesShown = 0;

    UPROPERTY()
    int32 FlinchesShownAtFirstTick = -1;

    UPROPERTY()
    int32 ConstructFrame = -1;

    UPROPERTY()
    int32 FirstTickFrame = -1;
}

// A harness fixture: the held mimic (its ledger held at the row's values from the spawn frame) that records, on every
// machine, the blows its script's brine answered.
class UMars_TESTONLY_PickleMimic_BornFlinchedRecorder_EntityScript : UMars_NetPickleMimic_Held_EntityScript
{
    private FCk_Handle _ShownEntity;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);
        if (ck::EnsureIfNot(InHandle.Is_PickleMimic(), f"[CreatureStandingNetTest] [{InHandle.ToString()}] the recorder composed no mimic"))
        { return Flow; }

        _ShownEntity = InHandle;
        auto Shown = FMars_TESTONLY_Fragment_PickleMimicBornFlinched_Shown();
        Shown.ConstructFrame = int32(utils_time::Get_FrameCounter());
        InHandle.Add_Fragment(Shown);
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnShownTick"));
        return Flow;
    }

    UFUNCTION()
    private void OnShownTick(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_ShownEntity) || _ShownEntity.Has_Fragment(FMars_TESTONLY_Fragment_PickleMimicBornFlinched_Shown) == false)
        { return; }

        auto& Shown = _ShownEntity.Get_Fragment(FMars_TESTONLY_Fragment_PickleMimicBornFlinched_Shown);
        Shown.Ticks += 1;
        Shown.FlinchesShown = Get_FlinchesShown();
        if (Shown.Ticks == 1)
        {
            Shown.FirstTickFrame = int32(utils_time::Get_FrameCounter());
            Shown.FlinchesShownAtFirstTick = Shown.FlinchesShown;
        }

        if (Shown.Ticks >= 2)
        { Shown.Recorded = true; }
    }
}

// The server holds its disguised mimic's ledger at two flinches, the last from +X, from the spawn frame on (its own
// kernel was never struck). The client's copy is born into those flinches: its kernel reads both, and its script's
// brine answers neither, because both happened before the copy was drawn.
// Surface: Ck.PickleMimic.Net.AS_PickleMimic_ACopyBornAfterAFlinchDoesNotSloshForIt
class UCk_AutoTest_Net_PickleMimic_ACopyBornAfterAFlinchDoesNotSloshForIt : UMars_AutoTestRig_NetPickleMimic
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_BornFlinchedBase = FVector(802000.0, 0.0, 5000.0);
    private const int32 k_BornFlinches = 2;
    private const float32 k_BornFlinchedServerWatch = 3.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MimicRow(k_BornFlinchedBase);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_MimicFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Ledger = FMars_Fragment_PickleMimic_Net();
        Ledger.Stance = EMars_PickleMimic_Stance::Tucked;
        Ledger.Flinch.Count = k_BornFlinches;
        Ledger.Flinch.From = FVector(1.0, 0.0, 0.0);

        auto Params = FMars_NetPickleMimic_Held_SpawnParams();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Base + FVector(0.0, 0.0, utils_pickle_mimic::Clearance));
        Params.Spec = Make_RowSpec();
        Params.WithVisuals = true;
        Params.HeldLedger = Ledger;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
            UMars_TESTONLY_PickleMimic_BornFlinchedRecorder_EntityScript, Params);
        WaitUntil(n"Is_MimicFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_BornFlinchedServerWatch, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsMimicGone())
        { FinishFailure("the server's mimic was gone before it was checked"); return; }

        const auto Shown = _Mimic.Get_Fragment(FMars_TESTONLY_Fragment_PickleMimicBornFlinched_Shown);
        Log_BornFlinched(Shown);
        Assert_True(Shown.Recorded, "the server's recorder ticked twice");
        Assert_Equals_Int(Shown.FlinchesShown, 0, "the server's brine answered no blow");
        Hold_MimicServerRow("ACopyBornAfterAFlinchDoesNotSloshForIt", "");
    }

    // The copy's kernel reads the held flinches and its record is written; quiet once the copy is gone.
    UFUNCTION()
    private void Is_BornFlinchesRead(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsMimicGone() == false && _Mimic.Get_Hurt().FlinchCount == k_BornFlinches
            && _Mimic.Has_Fragment(FMars_TESTONLY_Fragment_PickleMimicBornFlinched_Shown)
            && _Mimic.Get_Fragment(FMars_TESTONLY_Fragment_PickleMimicBornFlinched_Shown).Recorded);
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_BornFlinchesRead", n"OnClientRead", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientRead(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsMimicGone())
        { FinishFailure("the client's copy was gone before it was checked"); return; }

        const auto Shown = _Mimic.Get_Fragment(FMars_TESTONLY_Fragment_PickleMimicBornFlinched_Shown);
        Log_BornFlinched(Shown);
        Assert_Equals_Int(Shown.FlinchesShown, 0, "the client's brine answered no blow struck before its copy was drawn");
        Assert_Equals_Int(_Mimic.Get_Hurt().FlinchCount, k_BornFlinches, "the client's kernel reads both flinches");
        Finish_MimicRow("ACopyBornAfterAFlinchDoesNotSloshForIt", "");
    }

    private void Log_BornFlinched(FMars_TESTONLY_Fragment_PickleMimicBornFlinched_Shown InShown)
    {
        const auto Line = f"[CreatureStandingNetTest] ACopyBornAfterAFlinchDoesNotSloshForIt {Get_MachineName()} flinchCount={_Mimic.Get_Hurt().FlinchCount} flinchesShown={InShown.FlinchesShown} atFirstTick={InShown.FlinchesShownAtFirstTick} ticks={InShown.Ticks} construct={InShown.ConstructFrame} firstTick={InShown.FirstTickFrame} found={_MimicFoundFrame} notifies=[{_MimicLedgerNotifies}] ensures={Get_NewEnsures()}";
        Log(Line);
    }
}
