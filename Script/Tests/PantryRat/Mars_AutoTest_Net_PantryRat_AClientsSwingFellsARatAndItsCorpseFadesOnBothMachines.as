// The server's born rat watches beside its den. The client swings its cleaver at its copy as the strike task does:
// the sweep finds the copy's body zone and the blow is claimed. The server applies it: the rat dies, its ledger
// carries the blow's impulse, it holds, its corpse fades and it goes. The client's copy sees the death arrive (its
// first dead sample is young on its clock), reads the blow's impulse (pushed Right), holds and fades on its own clock
// and goes; its dealer dealt its contact once, before its monster died.
// Surface: Ck.PantryRat.Net.AS_PantryRat_AClientsSwingFellsARatAndItsCorpseFadesOnBothMachines
class UCk_AutoTest_Net_PantryRat_AClientsSwingFellsARatAndItsCorpseFadesOnBothMachines : UMars_AutoTestRig_NetPantryRatLoot
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(691000.0, 0.0, 5000.0);
    private const FString k_Row = "AClientsSwingFellsARatAndItsCorpseFadesOnBothMachines";
    private const float32 k_GoneSeconds = 12.0f;
    private const float32 k_YoungDeathSeconds = 0.2f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_LootRow(k_Base, k_BornHandFromBase);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_RowRatReadyToStrike", n"OnClientReady", k_SlowPolls);
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
        auto BornThrough = TArray<EMars_PantryRat_Phase>();
        BornThrough.Add(EMars_PantryRat_Phase::Observe);
        Spawn_ServerBornLootRat(BornThrough, EMars_NetRatTest_Born::Alive);
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
        const auto Tally = _Striker.Use.Get_StrikeTally();
        Assert_Equals_Int(Tally.Applied, 1, "the server applied one claim");
        Assert_Equals_Int(Tally.Refused, 0, "the server refused no claim");
        Assert_True(Get_IsRowRatGone(), "the server's rat is gone");
        Assert_True(Get_IsRatRecordedInOrder(Expected), "the server's rat died, held, faded and was destroyed, in order");
        Assert_True(Get_IsImpulseNear(_LedgerImpulseSeen, k_BlowImpulse),
            f"the server's ledger carried the blow's impulse while its rat lived (read {_LedgerImpulseSeen.ToString()})");
        Assert_True(_SawCorpseFadeBelowOne, "the server's corpse faded below 1");
        Hold_LootServerRow(k_Row, "");
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Swing_AtRowRat(EMars_NetRatTest_Swing::Claimed);
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
        Assert_True(_LootSwingHitRatZone, "the client's sweep reported a probe hit on its copy's body zone");
        Assert_Equals_Int(_StrikerDealt, 1, "the client's dealer dealt its contact once");
        Assert_True(_StrikerDealtFrame >= 0 && _LootDiedFrame >= 0 && _StrikerDealtFrame <= _LootDiedFrame,
            "the client's dealer dealt before its copy's monster died");
        Assert_Equals_Int(_RatDiedSignals, 1, "the client's monster died once");
        Assert_True(Get_IsRatRecordedInOrder(Expected), "the client recorded DeadHold, then CorpseFade");
        Assert_True(Get_IsRatRecordChained(), "each of the client's changes starts where the one before ended");
        Assert_True(Get_IsImpulseNear(_FirstDeadImpulse, k_BlowImpulse),
            f"the client's rat read the blow's impulse at its first dead sample (read {_FirstDeadImpulse.ToString()})");
        Assert_True(_FirstDeadSide.IsSet() && _FirstDeadSide.GetValue() == EMars_PantryRat_ToppleSide::Right,
            "the client's corpse is pushed Right");
        Assert_True(_FirstDeadFrame >= 0 && _FirstDeadAge >= 0.0f && _FirstDeadAge < k_YoungDeathSeconds,
            f"the client saw its rat's death arrive (dead age {_FirstDeadAge} at its first dead sample)");
        Assert_True(_SawCorpseFadeBelowOne, "the client's corpse faded below 1 on its own clock");
        Assert_True(Get_IsRowRatGone(), "the client's rat is gone");
        Assert_Equals_Int(Count_RatsHere(), 0, "no rat is left on the client");
        Finish_LootRow(k_Row, "");
    }
}
