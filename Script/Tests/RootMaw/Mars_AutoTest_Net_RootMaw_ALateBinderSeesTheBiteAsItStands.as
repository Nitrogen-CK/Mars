// A Root Maw whose bite winds up for 8 s starts one on the server's prey and holds it: once its copy composes, the
// client waits until it reads Bite and Windup; a second later it still reads Windup of the first bite, raised
// OnActionPhase(Bite, Windup) exactly once, and times the windup on its own clock (its alpha between 0.05 and 0.5).
// Surface: Ck.RootMaw.Net.AS_RootMaw_ALateBinderSeesTheBiteAsItStands
class UCk_AutoTest_Net_RootMaw_ALateBinderSeesTheBiteAsItStands : UMars_AutoTestRig_NetRootMaw
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(583000.0, 0.0, 5000.0);
    private const FVector k_PreyOffset = FVector(110.0, 0.0, 0.0);
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

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Spec = FMars_RootMaw_Spec();
        Spec.Bite.Timing.WindupSeconds = k_LongWindup;
        Spawn_ServerMawFloor();
        Spawn_ServerMaw(Spec);
        WaitUntil(n"Is_MawStanding", n"OnServerGrounded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerGrounded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_StandSeconds, n"OnServerStands");
    }

    UFUNCTION()
    private void OnServerStands(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerPrey(k_PreyOffset);
        WaitUntil(n"Is_MawWindingUp", n"OnServerWindingUp", k_SlowPolls);
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
    private void OnServerWindingUp(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_HoldSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Action = _Maw.Get_Action();
        Assert_True(Action.Kind == EMars_RootMaw_Action::Bite, "the server's Maw bites");
        Assert_True(Action.Phase == EMars_RootMaw_ActionPhase::Windup, "the server's bite still winds up");
        Assert_Equals_Int(Action.Generation, 1, "the server's bite is its first");
        Hold_MawServerRow("ALateBinderSeesTheBiteAsItStands", "");
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
        Assert_True(Action.Phase == EMars_RootMaw_ActionPhase::Windup, "the client's copy still winds up");
        Assert_Equals_Int(Action.Generation, 1, "the client's copy shows the first bite");
        Assert_Equals_Int(Count_MawPhases(EMars_RootMaw_Action::Bite, EMars_RootMaw_ActionPhase::Windup), 1,
            "the client raised OnActionPhase(Bite, Windup) exactly once");
        Assert_True(Alpha >= k_LowestAlpha && Alpha <= k_HighestAlpha, f"the client's windup alpha is between 0.05 and 0.5 ({Alpha})");
        Finish_MawRow("ALateBinderSeesTheBiteAsItStands", f"alpha={Alpha}");
    }
}
