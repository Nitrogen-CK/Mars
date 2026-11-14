// A Root Maw whose bite winds up for 4 s dies a second into its windup on the server: there the bite ends (None last),
// and the client's copy reads dead, its action None, its last raised phase None, its jaw slack at DeadGape and its body
// zone off.
// Surface: Ck.RootMaw.Net.AS_RootMaw_ADeathEndsTheBiteOnBothMachines
class UCk_AutoTest_Net_RootMaw_ADeathEndsTheBiteOnBothMachines : UMars_AutoTestRig_NetRootMaw
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(585000.0, 0.0, 5000.0);
    private const FVector k_PreyOffset = FVector(110.0, 0.0, 0.0);
    private const float32 k_Windup = 4.0f;
    private const float32 k_IntoTheWindup = 1.0f;
    private const float32 k_LethalBlow = 1000.0f;
    private const float32 k_DeadGapeTolerance = 0.2f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MawRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_MawDead", n"OnClientDead", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Spec = FMars_RootMaw_Spec();
        Spec.Bite.Timing.WindupSeconds = k_Windup;
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
        WaitUntil(n"Is_ServerWindingUp", n"OnServerWindingUp", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerWindingUp(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Maw();
        auto Result = OutResult;
        Result.Set(Get_IsMawGone() == false && _Maw.Get_Action().Phase == EMars_RootMaw_ActionPhase::Windup);
    }

    UFUNCTION()
    private void OnServerWindingUp(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_IntoTheWindup, n"OnServerIntoTheWindup");
    }

    UFUNCTION()
    private void OnServerIntoTheWindup(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(k_LethalBlow, GameplayTags::DamageType_Mars_Blunt)));
        WaitSampling(2.0f, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Maw.Get_IsDead(), "the server's Maw is dead");
        Assert_True(_Maw.Get_Action().Kind == EMars_RootMaw_Action::None, "the server's Maw runs no action");
        Assert_True(_MawPhases.Num() > 0 && _MawPhases[_MawPhases.Num() - 1].Phase == EMars_RootMaw_ActionPhase::None,
            f"the server's last recorded phase is None ({Describe_MawPhases()})");
        Hold_MawServerRow("ADeathEndsTheBiteOnBothMachines", "");
    }

    UFUNCTION()
    private void OnClientDead(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Jaw = _Maw.Get_JawOpen();
        Assert_True(_Maw.Get_Action().Kind == EMars_RootMaw_Action::None, "the client's copy runs no action");
        Assert_True(_MawPhases.Num() > 0 && _MawPhases[_MawPhases.Num() - 1].Phase == EMars_RootMaw_ActionPhase::None,
            f"the client's last recorded phase is None ({Describe_MawPhases()})");
        Assert_True(Math::Abs(Jaw - utils_root_maw::DeadGape) <= k_DeadGapeTolerance, f"the client's jaw is within 0.2 of DeadGape (reads {Jaw})");
        Assert_False(_Zone.Get_IsEnabled(), "the client's body zone is off");
        Finish_MawRow("ADeathEndsTheBiteOnBothMachines", "");
    }
}
