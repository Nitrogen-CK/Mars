// A woken Pickle Mimic trots after prey that moved 1200 down +X on the server. The client's copy plants its own feet on
// the client's floor as its replicated root moves: from 150 to 700 past the base its gait stays Ready, every foot lifts
// more than 5 over the floor and is planted again, planted feet stand within 3 of the floor and within 60 of their rest
// places under the root, diagonal pairs swing together at least as often as side or end pairs, and the gait always
// trusts at least one contact.
// Surface: Ck.PickleMimic.Net.AS_PickleMimic_TheClientsCopyTrotsOnItsOwnFeet
class UCk_AutoTest_Net_PickleMimic_TheClientsCopyTrotsOnItsOwnFeet : UMars_AutoTestRig_NetPickleMimic
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(611000.0, 0.0, 5000.0);
    private const FVector k_PreyWake = FVector(380.0, 0.0, 0.0);
    private const FVector k_PreyAfar = FVector(1200.0, 0.0, 0.0);
    private const float64 k_RecordFrom = 150.0;
    private const float64 k_FarPast = 700.0;
    private const float64 k_FootLift = 5.0;
    private const float64 k_PlantedOff = 3.0;
    private const float64 k_FootStray = 60.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MimicRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientFoundTucked", n"OnClientFound", k_SlowPolls);
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
        Begin_FeetRecord();
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
        const auto Feet = Describe_Feet();
        Assert_True(Get_HaveAllFeetTrotted(k_FootLift), f"every server foot lifted over 5 and was planted again ({Feet})");
        Assert_True(_FeetWorstPlanted <= k_PlantedOff, f"the server's planted feet stood within 3 of the floor ({_FeetWorstPlanted})");
        Hold_MimicServerRow("TheClientsCopyTrotsOnItsOwnFeet", "");
    }

    UFUNCTION()
    private void Is_ClientFoundTucked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsMimicFound() && Get_IsMimicGone() == false && _Mimic.Get_IsTucked());
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientMoving", n"OnClientMoving", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientMoving(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Mimic();
        auto Result = OutResult;
        Result.Set(Get_MimicPastBase() > k_RecordFrom);
    }

    UFUNCTION()
    private void OnClientMoving(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_FeetRecord();
        WaitUntil(n"Is_MimicFarPast", n"OnClientFarPast", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientFarPast(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Feet = Describe_Feet();
        Assert_True(Get_MimicGaitStatus() == ECk_ProceduralAnimation_Status::Ready, "the client's gait reads Ready");
        Assert_False(_MimicGaitEverFailed, "the client's gait never read Failed");
        Assert_True(Get_HaveAllFeetTrotted(k_FootLift), f"every client foot lifted over 5 and was planted again ({Feet})");
        Assert_True(_FeetWorstPlanted <= k_PlantedOff, f"the client's planted feet stood within 3 of the floor ({_FeetWorstPlanted})");
        Assert_True(_FeetFarthestPlantedFromRest <= k_FootStray, f"no client foot stood farther than 60 from its rest place ({_FeetFarthestPlantedFromRest})");
        Assert_True(_FeetDiagonalFrames > 0 && _FeetDiagonalFrames >= _FeetOtherFrames,
            f"the client's feet swung in diagonal pairs ({_FeetDiagonalFrames} diagonal, {_FeetOtherFrames} side or end)");
        Assert_True(_FeetLowestTrusted >= 1, f"the client's gait always trusted a contact (lowest {_FeetLowestTrusted})");
        Finish_MimicRow("TheClientsCopyTrotsOnItsOwnFeet", "");
    }
}
