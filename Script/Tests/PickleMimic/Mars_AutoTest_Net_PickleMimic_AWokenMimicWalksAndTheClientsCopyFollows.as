// Prey comes within the wake radius of a disguised Pickle Mimic on the server and then moves 1200 down +X: the mimic
// stands and walks after it there, raising OnStance(Standing) once. The client's copy stands from the ledger on its own
// clock, raising OnStance(Standing) exactly once with its root level with its body node, and follows its replicated
// root without a jump (no step of 150 or more between two samples) to where the server's ends.
// Surface: Ck.PickleMimic.Net.AS_PickleMimic_AWokenMimicWalksAndTheClientsCopyFollows
class UCk_AutoTest_Net_PickleMimic_AWokenMimicWalksAndTheClientsCopyFollows : UMars_AutoTestRig_NetPickleMimic
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(612000.0, 0.0, 5000.0);
    private const FVector k_PreyWake = FVector(380.0, 0.0, 0.0);
    private const FVector k_PreyAfar = FVector(1200.0, 0.0, 0.0);
    private const float64 k_FarPast = 900.0;
    private const float64 k_EndMin = 950.0;
    private const float64 k_EndMax = 1400.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MimicRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_MimicFarPast", n"OnClientFarPast", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_MimicFarPast(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Mimic();
        auto Result = OutResult;
        Result.Set(Get_IsMimicFound() && Get_MimicPastBase() > k_FarPast);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerMimic(Make_RowSpec());
        WaitUntil(n"Is_MimicSettled", n"OnServerSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_StandSeconds, n"OnServerStands");
    }

    UFUNCTION()
    private void OnServerStands(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerPrey(k_PreyWake);
        WaitUntil(n"Is_MimicStanding", n"OnServerStanding", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerStanding(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Move_ServerPrey(k_PreyAfar);
        WaitUntil(n"Is_MimicFarPast", n"OnServerFarPast", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFarPast(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(2.0f, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Past = Get_MimicPastBase();
        Assert_Equals_Int(_MimicStandingStances, 1, "the server raised OnStance(Standing) once");
        Assert_True(Past >= k_EndMin && Past <= k_EndMax, f"the server's root ends 950..1400 past the base (reads {Past})");
        Hold_MimicServerRow("AWokenMimicWalksAndTheClientsCopyFollows", "");
    }

    UFUNCTION()
    private void OnClientFarPast(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Past = Get_MimicPastBase();
        const auto Side = Math::Abs(_Mimic.Get_Location().Y - _Base.Y);
        Assert_True(Math::IsNearlyEqual(_Mimic.Get_Rise(), 1.0f, 0.0001f), "the client's mimic is fully up");
        Assert_Equals_Int(_MimicStandingStances, 1, "the client raised OnStance(Standing) exactly once");
        Assert_True(Math::IsNearlyEqual(Get_MimicBodyDrop(), k_BodyDropStanding, 0.5), "the client's root is level with the body node");
        Assert_True(Past >= k_EndMin && Past <= k_EndMax, f"the client's root ends 950..1400 past the base (reads {Past})");
        Assert_True(Side <= 100.0, f"the client's root is within 100 of the base on Y (reads {Side})");
        Assert_True(_MimicLargestStep < 150.0, f"the client's root never stepped 150 or more (largest {_MimicLargestStep})");
        Finish_MimicRow("AWokenMimicWalksAndTheClientsCopyFollows", "");
    }
}
