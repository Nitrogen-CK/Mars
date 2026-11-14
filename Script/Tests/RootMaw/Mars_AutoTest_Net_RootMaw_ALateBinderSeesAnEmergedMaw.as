// A copy born into an emerged Maw: the server spawns a held Maw whose ledger reads Emerged with a latched gape of 0.8
// and one flinch (found buried, struck from 100 cm past the base on X) from its spawn frame, so the entity and that
// state reach the client together, as they reach a player who joins. The client's copy shows the Maw where it is: fully
// up and never sampled lower, its jaw at 0.8, the flinch counted and never played, no OnStance(Emerged). The real
// rise and the real flinch are proven by the rows that make them after the copy has taken its state.
// Surface: Ck.RootMaw.Net.AS_RootMaw_ALateBinderSeesAnEmergedMaw
class UCk_AutoTest_Net_RootMaw_ALateBinderSeesAnEmergedMaw : UMars_AutoTestRig_NetRootMaw
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(574000.0, 0.0, 5000.0);
    private const float32 k_HeldGape = 0.8f;
    private const FVector k_FlinchFromOffset = FVector(100.0, 0.0, 0.0);
    private const float32 k_HoldSeconds = 4.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MawRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_MawFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    // The state a real run reaches: struck while buried, then up with its jaw latched open.
    private FMars_Fragment_RootMaw_Net Make_HeldLedger() const
    {
        auto Ledger = FMars_Fragment_RootMaw_Net();
        Ledger.Stance = EMars_RootMaw_Stance::Emerged;
        Ledger.Gape = k_HeldGape;
        Ledger.Flinch.Count = 1;
        Ledger.Flinch.From = k_Base + k_FlinchFromOffset;
        Ledger.Flinch.FoundIn = EMars_RootMaw_Stance::Buried;
        return Ledger;
    }

    private bool Get_IsLedgerHeld()
    {
        if (Get_HasMawLedger() == false)
        { return false; }

        const auto Ledger = Get_MawLedger();
        const auto Held = Make_HeldLedger();
        return Ledger.Stance == Held.Stance && Math::IsNearlyEqual(Ledger.Gape, Held.Gape, 0.0001f)
            && Ledger.Flinch.Count == Held.Flinch.Count && Ledger.Flinch.From.Equals(Held.Flinch.From, 0.01)
            && Ledger.Flinch.FoundIn == Held.Flinch.FoundIn;
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerMawFloor();
        Spawn_ServerHeldMaw(FMars_RootMaw_Spec(), Make_HeldLedger());
        WaitUntil(n"Is_MawFound", n"OnServerFound", k_SlowPolls);
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
        Hold_MawServerRow("ALateBinderSeesAnEmergedMaw", "");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_MawEmerged", n"OnClientEmerged", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientEmerged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_MawInitialState() == EMars_Net_InitialState::Taken, "the client's copy has taken the state it was born into");
        Assert_True(Math::IsNearlyEqual(_Maw.Get_Emerge(), 1.0f, 0.0001f), "the client's Maw is fully up");
        Assert_True(_MawLowestEmerge >= 1.0f - 0.0001f, f"the client's Maw was never sampled below fully up ({_MawLowestEmerge})");
        const auto Jaw = _Maw.Get_JawOpen();
        Assert_True(Math::Abs(Jaw - k_HeldGape) <= 0.0001f, f"the client's jaw is within 0.0001 of 0.8 (reads {Jaw})");
        Assert_Equals_Int(_Maw.Get_Hurt().FlinchCount, 1, "the client's copy counts the one flinch");
        Assert_False(_MawEverFlinched, "the client's copy was never sampled flinching");
        Assert_Equals_Int(_MawEmergedStances, 0, "the client raised no OnStance(Emerged)");
        Assert_True(Get_IsLedgerHeld(), "the client's ledger reads the held values");
        Assert_True(Get_MawPath() == "stood", "the client's copy took the state it was born into as it stood");
        Finish_MawRow("ALateBinderSeesAnEmergedMaw", "");
    }
}
