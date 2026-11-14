// Prey comes within the wake radius of a buried Root Maw on the server: it rises there and the client's copy rises from
// the ledger on its own clock, raising OnStance(Emerged) exactly once, its body node 30 under its root and its jaw
// open.
// Surface: Ck.RootMaw.Net.AS_RootMaw_AWokenMawRisesOnBothMachines
class UCk_AutoTest_Net_RootMaw_AWokenMawRisesOnBothMachines : UMars_AutoTestRig_NetRootMaw
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(571000.0, 0.0, 5000.0);
    private const FVector k_PreyOffset = FVector(400.0, 0.0, 0.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MawRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_MawEmerged", n"OnClientEmerged", k_SlowPolls);
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
        Spawn_ServerPrey(k_PreyOffset);
        WaitUntil(n"Is_MawEmerged", n"OnServerEmerged", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerEmerged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(2.0f, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_MawEmergedStances, 1, "the server raised OnStance(Emerged) once");
        Hold_MawServerRow("AWokenMawRisesOnBothMachines", "");
    }

    UFUNCTION()
    private void OnClientEmerged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Math::IsNearlyEqual(_Maw.Get_Emerge(), 1.0f, 0.0001f), "the client's Maw is fully up");
        Assert_Equals_Int(_MawEmergedStances, 1, "the client raised OnStance(Emerged) exactly once");
        const auto Jaw = _Maw.Get_JawOpen();
        Assert_True(Jaw >= 0.3f && Jaw <= 1.0f, f"the client's jaw is open between 0.3 and 1 (reads {Jaw})");
        Assert_True(Math::IsNearlyEqual(Get_MawBodyDrop(), k_BodyDropEmerged, 0.5), "the client's root is 30 above the body node");
        Finish_MawRow("AWokenMawRisesOnBothMachines", "");
    }
}
