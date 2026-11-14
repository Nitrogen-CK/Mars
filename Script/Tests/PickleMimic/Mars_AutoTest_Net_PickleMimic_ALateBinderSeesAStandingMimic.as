// A copy born into a standing mimic: the server spawns a held mimic whose ledger reads Standing with a latched gape of
// 0.8 and one flinch (found tucked, struck from 100 cm past the base on X) from its spawn frame, so the entity and that
// state reach the client together, as they reach a player who joins. The client's copy shows the mimic where it is:
// fully up and never sampled lower, its lid at 0.8, the flinch counted and never played, no OnStance(Standing). The
// real stand and the real flinch are proven by the rows that make them after the copy has taken its state.
// Surface: Ck.PickleMimic.Net.AS_PickleMimic_ALateBinderSeesAStandingMimic
class UCk_AutoTest_Net_PickleMimic_ALateBinderSeesAStandingMimic : UMars_AutoTestRig_NetPickleMimic
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(616000.0, 0.0, 5000.0);
    private const float32 k_HeldGape = 0.8f;
    private const FVector k_FlinchFromOffset = FVector(100.0, 0.0, 0.0);
    private const float32 k_HoldSeconds = 4.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MimicRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_MimicFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    // The state a real run reaches: struck while tucked, then up with its lid latched open.
    private FMars_Fragment_PickleMimic_Net Make_HeldLedger() const
    {
        auto Ledger = FMars_Fragment_PickleMimic_Net();
        Ledger.Stance = EMars_PickleMimic_Stance::Standing;
        Ledger.Gape = k_HeldGape;
        Ledger.Flinch.Count = 1;
        Ledger.Flinch.From = k_Base + k_FlinchFromOffset;
        Ledger.Flinch.FoundIn = EMars_PickleMimic_Stance::Tucked;
        return Ledger;
    }

    private bool Get_IsLedgerHeld()
    {
        if (Get_HasMimicLedger() == false)
        { return false; }

        const auto Ledger = Get_MimicLedger();
        const auto Held = Make_HeldLedger();
        return Ledger.Stance == Held.Stance && Math::IsNearlyEqual(Ledger.Gape, Held.Gape, 0.0001f)
            && Ledger.Flinch.Count == Held.Flinch.Count && Ledger.Flinch.From.Equals(Held.Flinch.From, 0.01)
            && Ledger.Flinch.FoundIn == Held.Flinch.FoundIn;
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerHeldMimic(Make_RowSpec(), Make_HeldLedger());
        WaitUntil(n"Is_MimicFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_HoldSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_IsLedgerHeld(), "the server's ledger still reads the held values");
        Hold_MimicServerRow("ALateBinderSeesAStandingMimic", "");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_MimicStanding", n"OnClientStanding", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientStanding(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_MimicInitialState() == EMars_Net_InitialState::Taken, "the client's copy has taken the state it was born into");
        Assert_True(Math::IsNearlyEqual(_Mimic.Get_Rise(), 1.0f, 0.0001f), "the client's mimic is fully up");
        Assert_True(_MimicLowestRise >= 1.0f - 0.0001f, f"the client's mimic was never sampled below fully up ({_MimicLowestRise})");
        const auto Lid = _Mimic.Get_LidOpen();
        Assert_True(Math::Abs(Lid - k_HeldGape) <= 0.0001f, f"the client's lid is within 0.0001 of 0.8 (reads {Lid})");
        Assert_Equals_Int(_Mimic.Get_Hurt().FlinchCount, 1, "the client's copy counts the one flinch");
        Assert_False(_MimicEverFlinched, "the client's copy was never sampled flinching");
        Assert_Equals_Int(_MimicStandingStances, 0, "the client raised no OnStance(Standing)");
        Assert_True(Get_IsLedgerHeld(), "the client's ledger reads the held values");
        Assert_True(Get_MimicPath() == "stood", "the client's copy took the state it was born into as it stood");
        Finish_MimicRow("ALateBinderSeesAStandingMimic", "");
    }
}
