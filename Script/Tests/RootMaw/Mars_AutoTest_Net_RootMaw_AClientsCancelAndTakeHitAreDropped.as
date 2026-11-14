// A Root Maw whose bite winds up for 2 s bites the server's prey: when the client's copy first reads Windup, the client
// asks its copy to cancel and to take a hit; a machine without authority drops both, so its copy carries no requests,
// never flinches, and shows the bite run its phases in order, as the server's Maw runs them.
// Surface: Ck.RootMaw.Net.AS_RootMaw_AClientsCancelAndTakeHitAreDropped
class UCk_AutoTest_Net_RootMaw_AClientsCancelAndTakeHitAreDropped : UMars_AutoTestRig_NetRootMaw
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(584000.0, 0.0, 5000.0);
    private const FVector k_PreyOffset = FVector(110.0, 0.0, 0.0);
    private const float32 k_Windup = 2.0f;
    private const float32 k_ClientHit = 10.0f;

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
        WaitUntil(n"Is_MawBiteEnded", n"OnServerBitten", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerBitten(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(2.0f, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Phases = Describe_MawPhases();
        Assert_True(_MawPhases.Num() >= 4, f"the server recorded four phases ({Phases})");
        if (_MawPhases.Num() >= 4)
        {
            Assert_True(_MawPhases[0].Phase == EMars_RootMaw_ActionPhase::Windup && _MawPhases[1].Phase == EMars_RootMaw_ActionPhase::Active
                && _MawPhases[2].Phase == EMars_RootMaw_ActionPhase::Recover && _MawPhases[3].Phase == EMars_RootMaw_ActionPhase::None,
                f"the server's first four phases are in order ({Phases})");
        }

        Assert_Equals_Int(_Maw.Get_Hurt().FlinchCount, 0, "the server's Maw never flinched");
        Hold_MawServerRow("AClientsCancelAndTakeHitAreDropped", "");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientWindingUp", n"OnClientWindingUp", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientWindingUp(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Maw();
        auto Result = OutResult;
        Result.Set(Get_IsMawGone() == false && _Maw.Get_Action().Phase == EMars_RootMaw_ActionPhase::Windup);
    }

    UFUNCTION()
    private void OnClientWindingUp(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Maw.Request_Cancel(FMars_Request_RootMaw_Cancel());
        _Maw.Request_TakeHit(FMars_Request_RootMaw_TakeHit(FMars_DamageEvent(k_ClientHit, GameplayTags::DamageType_Mars_Sever)));
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(_Maw.Has_Fragment(FMars_Fragment_RootMaw_Requests), "the client's copy carries no requests");
        Assert_Equals_Int(_Maw.Get_Hurt().FlinchCount, 0, "the client's copy reads no flinch");
        Assert_False(_MawEverFlinched, "the client's copy never read flinching");
        WaitUntil(n"Is_MawBiteEnded", n"OnClientBitten", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientBitten(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Phases = Describe_MawPhases();
        Assert_True(Get_AreMawPhasesInOrder(), f"the client's phases are in order ({Phases})");
        Finish_MawRow("AClientsCancelAndTakeHitAreDropped", "");
    }
}
