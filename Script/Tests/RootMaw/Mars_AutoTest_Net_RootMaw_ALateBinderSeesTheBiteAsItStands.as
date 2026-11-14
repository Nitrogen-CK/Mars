// A copy born into a bite's windup: the server spawns a held Maw (its bite winding up for 8 s) whose ledger reads
// Emerged and its first bite in Windup from its spawn frame; no prey, no bite asked. The client's copy takes the bite
// from its phase's start on its own clock as it appears: a second after it reads Bite and Windup it still shows the
// first bite winding up, its alpha between 0.05 and 0.5, fully up and never sampled lower. The rig recorded one
// OnActionPhase(Bite, Windup), raised in the frame the copy's ledger was first applied: a running action is
// announced once as the copy takes its state.
// Surface: Ck.RootMaw.Net.AS_RootMaw_ALateBinderSeesTheBiteAsItStands
class UCk_AutoTest_Net_RootMaw_ALateBinderSeesTheBiteAsItStands : UMars_AutoTestRig_NetRootMaw
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(583000.0, 0.0, 5000.0);
    private const float32 k_LongWindup = 8.0f;
    private const float32 k_HoldSeconds = 4.0f;
    private const float32 k_LowestAlpha = 0.05f;
    private const float32 k_HighestAlpha = 0.5f;

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

    // The state a real run reaches: up, its jaw shut, its first bite winding up.
    private FMars_Fragment_RootMaw_Net Make_HeldLedger() const
    {
        auto Ledger = FMars_Fragment_RootMaw_Net();
        Ledger.Stance = EMars_RootMaw_Stance::Emerged;
        Ledger.Gape = 0.0f;
        Ledger.Action.Kind = EMars_RootMaw_Action::Bite;
        Ledger.Action.Phase = EMars_RootMaw_ActionPhase::Windup;
        Ledger.Action.Generation = 1;
        return Ledger;
    }

    private bool Get_IsLedgerHeld()
    {
        if (Get_HasMawLedger() == false)
        { return false; }

        const auto Ledger = Get_MawLedger();
        return Ledger.Stance == EMars_RootMaw_Stance::Emerged && Ledger.Action.Kind == EMars_RootMaw_Action::Bite
            && Ledger.Action.Phase == EMars_RootMaw_ActionPhase::Windup && Ledger.Action.Generation == 1;
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Spec = FMars_RootMaw_Spec();
        Spec.Bite.Timing.WindupSeconds = k_LongWindup;
        Spawn_ServerMawFloor();
        Spawn_ServerHeldMaw(Spec, Make_HeldLedger());
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
        Assert_True(Get_IsLedgerHeld(), "the server's ledger still reads the held bite");
        Hold_MawServerRow("ALateBinderSeesTheBiteAsItStands", "");
    }

    UFUNCTION()
    private void Is_MawWindingUp(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Maw();
        auto Result = OutResult;
        Result.Set(Get_IsMawFound() && Get_IsMawGone() == false && _Maw.Get_Action().Kind == EMars_RootMaw_Action::Bite
            && _Maw.Get_Action().Phase == EMars_RootMaw_ActionPhase::Windup);
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_MawWindingUp", n"OnClientWindingUp", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientWindingUp(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Action = _Maw.Get_Action();
        const auto Alpha = _Maw.Get_ActionFrame().Alpha;
        Assert_True(Get_MawInitialState() == EMars_Net_InitialState::Taken, "the client's copy has taken the state it was born into");
        Assert_True(Action.Kind == EMars_RootMaw_Action::Bite, "the client's copy bites");
        Assert_True(Action.Phase == EMars_RootMaw_ActionPhase::Windup, "the client's copy still winds up");
        Assert_Equals_Int(Action.Generation, 1, "the client's copy shows the first bite");
        Assert_True(Alpha >= k_LowestAlpha && Alpha <= k_HighestAlpha, f"the client's windup alpha is between 0.05 and 0.5 ({Alpha})");
        Assert_True(Math::IsNearlyEqual(_Maw.Get_Emerge(), 1.0f, 0.0001f), "the client's Maw is fully up");
        Assert_True(_MawLowestEmerge >= 1.0f - 0.0001f, f"the client's Maw was never sampled below fully up ({_MawLowestEmerge})");
        Assert_Equals_Int(Count_MawPhases(EMars_RootMaw_Action::Bite, EMars_RootMaw_ActionPhase::Windup), 1,
            "the rig recorded one OnActionPhase(Bite, Windup)");
        Assert_Equals_Int(Get_MawPhaseFrame(EMars_RootMaw_Action::Bite, EMars_RootMaw_ActionPhase::Windup), _MawFirstLedgerNotifyFrame,
            "it was raised in the frame the copy's ledger was first applied");
        Assert_True(Get_IsLedgerHeld(), "the client's ledger reads the held bite");
        Assert_True(Get_MawPath() == "stood", "the client's copy took the state it was born into as it stood");
        Finish_MawRow("ALateBinderSeesTheBiteAsItStands", f"alpha={Alpha}");
    }
}
