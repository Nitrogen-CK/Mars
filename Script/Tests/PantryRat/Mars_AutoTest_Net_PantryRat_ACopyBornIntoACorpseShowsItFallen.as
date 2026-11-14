// The server's born rat takes one lethal cleaver blow pushing +Y and dies of it as it composes, so its ledger reads the
// corpse (DeadHold and the blow's impulse) from its spawn frame; it holds, fades and goes. The client's copy is born
// into the corpse: its ledger's first application reads DeadHold with the impulse and is taken once as it stands,
// announced as one change from Emerge in that frame, its hold read over (its dead age at least the hold), so its body,
// built headless, picks Right and shows it fallen without a topple; the fade then arrives and plays on its own clock.
// Surface: Ck.PantryRat.Net.AS_PantryRat_ACopyBornIntoACorpseShowsItFallen
class UCk_AutoTest_Net_PantryRat_ACopyBornIntoACorpseShowsItFallen : UMars_AutoTestRig_NetPantryRatLoot
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(693000.0, 0.0, 5000.0);
    private const FString k_Row = "ACopyBornIntoACorpseShowsItFallen";
    private const float32 k_GoneSeconds = 10.0f;

    // The client's reading as it asserted the corpse it was born into.
    private FString _BornText;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_LootRow(k_Base, k_BornHandFromBase);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_RowRatFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        Begin_ServerArmed(n"OnServerArmed");
    }

    UFUNCTION()
    private void OnServerArmed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_ServerBornCourt(Make_RowSpec(), n"OnServerCourt");
    }

    UFUNCTION()
    private void OnServerCourt(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerBornLootRat(TArray<EMars_PantryRat_Phase>(), EMars_NetRatTest_Born::Corpse);
        WaitUntil(n"Is_RowRatFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Until = Make_RatUntil(EMars_NetRatTest_UntilKind::Gone, EMars_PantryRat_Phase::Emerge);
        Until.MaxSeconds = TOptional<float32>(k_GoneSeconds);
        Wait_RowRatUntil(Until, n"OnServerGone");
    }

    UFUNCTION()
    private void OnServerGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowSampling(k_ComposeSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Expected = TArray<EMars_PantryRat_Phase>();
        Expected.Add(EMars_PantryRat_Phase::Dying);
        Expected.Add(EMars_PantryRat_Phase::DeadHold);
        Expected.Add(EMars_PantryRat_Phase::CorpseFade);
        Expected.Add(EMars_PantryRat_Phase::Destroyed);
        Assert_True(Get_IsRowRatGone(), "the server's rat is gone");
        Assert_True(Get_IsRatRecordedInOrder(Expected), "the server's rat died, held, faded and was destroyed, in order");
        Hold_LootServerRow(k_Row, "");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowRatUntil(Make_RatUntil(EMars_NetRatTest_UntilKind::ReadsPhase, EMars_PantryRat_Phase::DeadHold), n"OnClientDeadHold");
    }

    UFUNCTION()
    private void OnClientDeadHold(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRowRatGone())
        {
            Log_RatRow(k_Row, Describe_Loot());
            FinishFailure("the client's rat was gone before it asserted the corpse");
            return;
        }

        const auto FirstApplication = _RatApplications.Num() > 0 ? _RatApplications[0] : FMars_NetRatTest_Application();
        const auto FirstLoot = _LootApplications.Num() > 0 ? _LootApplications[0] : FMars_NetRatTest_LootApplication();
        const auto Hold = _RowRat.Get_Tuning().DeathHoldSeconds;
        auto Monster = _RowRat.Get_Monster();
        Assert_True(Get_RowRatInitialState() == EMars_Net_InitialState::Taken, "the client's rat took the state it was born into");
        Assert_True(_RatApplications.Num() > 0 && FirstApplication.Phase == EMars_PantryRat_Phase::DeadHold,
            "the client's ledger's first application reads DeadHold");
        Assert_True(_LootApplications.Num() > 0 && FirstLoot.Phase == EMars_PantryRat_Phase::DeadHold
            && Get_IsImpulseNear(FirstLoot.HitImpulse, k_BlowImpulse),
            f"the client's ledger's first application carries the blow's impulse (reads {FirstLoot.HitImpulse.ToString()})");
        Assert_Equals_Int(_RatChanges.Num(), 1, "the client's rat recorded one change so far");
        Assert_True(_RatChanges.Num() > 0 && _RatChanges[0].From == EMars_PantryRat_Phase::Emerge
            && _RatChanges[0].To == EMars_PantryRat_Phase::DeadHold && _RatChanges[0].Frame == FirstApplication.Frame,
            "the client's change is Emerge to DeadHold, in the frame of the ledger's first application");
        Assert_False(Get_IsRatRecorded(EMars_PantryRat_Phase::Dying), "the client never saw its rat die");
        Assert_True(_RowRat.Get_Death().HitImpulse == Get_RowRatLedger().HitImpulse, "the client's state reads its ledger's impulse");
        Assert_True(_FirstDeadFrame >= 0 && _FirstDeadAge >= Hold - 0.001f,
            f"the client read its corpse's hold over at its first dead sample (dead age {_FirstDeadAge}, hold {Hold})");
        _BornText = f"born=[died {_RatDiedSignals} zoneEnabled {Monster.Get_BodyZone().Get_IsEnabled()} {Describe_Loot()}]";
        Wait_RowRatUntil(Make_RatUntil(EMars_NetRatTest_UntilKind::Gone, EMars_PantryRat_Phase::Emerge), n"OnClientGone");
    }

    UFUNCTION()
    private void OnClientGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Expected = TArray<EMars_PantryRat_Phase>();
        Expected.Add(EMars_PantryRat_Phase::DeadHold);
        Expected.Add(EMars_PantryRat_Phase::CorpseFade);
        Assert_True(Get_IsRatRecordedInOrder(Expected), "the client recorded CorpseFade after DeadHold");
        Assert_True(_SawCorpseFadeBelowOne, "the client's corpse faded below 1");
        Assert_True(_ScriptToppleSide.IsSet() && _ScriptToppleSide.GetValue() == EMars_PantryRat_ToppleSide::Right,
            "the client's body chose to topple Right");
        Assert_False(_RatClipsSeen.Contains(n"DeathToppleLeft") || _RatClipsSeen.Contains(n"DeathToppleRight"),
            "the client's body never played a topple");
        Assert_True(_RatClipsSeen.Contains(n"DeadHold"), "the client's body played DeadHold");
        Assert_True(Get_IsRowRatGone(), "the client's rat is gone");
        Finish_LootRow(k_Row, _BornText);
    }
}
