// A zone hit of 10 on a buried Root Maw on the server: it flinches, found Buried, and bursts up; the client's copy
// reads the flinch from the ledger, pops its jaw wide (at least 0.9) and rises with it.
// Surface: Ck.RootMaw.Net.AS_RootMaw_ABlowOnABuriedMawPopsItsJawOnBothMachines
class UCk_AutoTest_Net_RootMaw_ABlowOnABuriedMawPopsItsJawOnBothMachines : UMars_AutoTestRig_NetRootMaw
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(582000.0, 0.0, 5000.0);
    private const float32 k_ZoneHit = 10.0f;
    private const float32 k_RisingEmerge = 0.5f;
    private const float32 k_PoppedJaw = 0.9f;

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
        Spawn_ServerMawFloor();
        Spawn_ServerMaw(FMars_RootMaw_Spec());
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
        Hit_MawZone(k_ZoneHit);
        WaitUntil(n"Is_ServerRaisedEmerged", n"OnServerEmerged", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerRaisedEmerged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Maw();
        auto Result = OutResult;
        Result.Set(_MawEmergedStances > 0);
    }

    UFUNCTION()
    private void OnServerEmerged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(2.0f, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Hurt = _Maw.Get_Hurt();
        Assert_Equals_Int(Hurt.FlinchCount, 1, "the server's Maw flinched once");
        Assert_True(Hurt.FlinchFoundIn == EMars_RootMaw_Stance::Buried, "the server's flinch found the Maw buried");
        Hold_MawServerRow("ABlowOnABuriedMawPopsItsJawOnBothMachines", "");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientFlinched", n"OnClientFlinched", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientFlinched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Maw();
        auto Result = OutResult;
        Result.Set(Get_IsMawGone() == false && _Maw.Get_Hurt().FlinchCount == 1);
    }

    UFUNCTION()
    private void OnClientFlinched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientRising", n"OnClientRising", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientRising(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Maw();
        auto Result = OutResult;
        Result.Set(Get_IsMawGone() == false && _Maw.Get_Emerge() > k_RisingEmerge);
    }

    UFUNCTION()
    private void OnClientRising(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_MawWidestSinceFlinch >= k_PoppedJaw, f"the client's jaw popped to at least 0.9 ({_MawWidestSinceFlinch})");
        Assert_True(_Maw.Get_Hurt().FlinchFoundIn == EMars_RootMaw_Stance::Buried, "the client's flinch found the Maw buried");
        Finish_MawRow("ABlowOnABuriedMawPopsItsJawOnBothMachines", "");
    }
}
