// The server's court emerges one rat, which watches and then bounds out more than 150 from where it was first seen.
// The client's copy follows it out of the den on the replicated root: more than 150 from where it was found, never
// stepping 60 or more between two frames, its script measuring a speed between 120 and 500 from that motion over its
// own clock and picking a locomotion clip, and it shows the authority's BoundApproach. It has no navigator.
// Surface: Ck.PantryRat.Net.AS_PantryRat_ACopyFollowsTheRatOutOfTheDen
class UCk_AutoTest_Net_PantryRat_ACopyFollowsTheRatOutOfTheDen : UMars_AutoTestRig_NetPantryRat
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(679000.0, 0.0, 5000.0);
    private const FString k_Row = "ACopyFollowsTheRatOutOfTheDen";
    private const float64 k_OutCm = 150.0;
    private const float32 k_ServerOutSeconds = 8.0f;
    private const float64 k_LargestStepCm = 60.0;
    private const float32 k_LowestTopSpeed = 120.0f;
    private const float32 k_HighestTopSpeed = 500.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_PantryRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_RowRatFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        auto Spec = Make_RowSpec();
        Spec.Population.MaxActiveRats = 1;
        Begin_ServerRatCourt(Spec, n"OnServerRatOut");
    }

    UFUNCTION()
    private void OnServerRatOut(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Until = Make_RatUntil(EMars_NetRatTest_UntilKind::MovedFarther, EMars_PantryRat_Phase::Emerge);
        Until.Cm = k_OutCm;
        Until.MaxSeconds = TOptional<float32>(k_ServerOutSeconds);
        Wait_RowRatUntil(Until, n"OnServerRatWentOut");
    }

    UFUNCTION()
    private void OnServerRatWentOut(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowSampling(k_ComposeSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Expected = TArray<EMars_PantryRat_Phase>();
        Expected.Add(EMars_PantryRat_Phase::Observe);
        Expected.Add(EMars_PantryRat_Phase::BoundApproach);
        Assert_True(_RatFarthest > k_OutCm, f"the server's rat went more than {k_OutCm} out (went {_RatFarthest})");
        Assert_True(Get_IsRatRecordedInOrder(Expected), "the server's rat watched, then bounded toward the pack");
        Hold_RatServerRow(k_Row, Describe_CourtFrames());
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Until = Make_RatUntil(EMars_NetRatTest_UntilKind::MovedFarther, EMars_PantryRat_Phase::Emerge);
        Until.Cm = k_OutCm;
        Wait_RowRatUntil(Until, n"OnClientRatWentOut");
    }

    UFUNCTION()
    private void OnClientRatWentOut(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRowRatGone())
        {
            Log_RatRow(k_Row, "");
            FinishFailure("the client's rat was gone before it asserted");
            return;
        }

        const auto Locomotion = _RatClipsSeen.Contains(n"Walk") || _RatClipsSeen.Contains(n"BoundStart")
            || _RatClipsSeen.Contains(n"BoundCycle");
        Assert_True(_RatFarthest > k_OutCm, f"the client's rat went more than {k_OutCm} out (went {_RatFarthest})");
        Assert_True(_RatLargestStep < k_LargestStepCm, f"the client's rat never stepped {k_LargestStepCm} or more (largest {_RatLargestStep})");
        Assert_True(_RatHighestSpeed > k_LowestTopSpeed && _RatHighestSpeed < k_HighestTopSpeed,
            f"the client's rat measured a top speed between {k_LowestTopSpeed} and {k_HighestTopSpeed} (measured {_RatHighestSpeed})");
        Assert_True(Locomotion, "the client's rat picked a locomotion clip");
        Assert_True(Get_IsRatRecorded(EMars_PantryRat_Phase::BoundApproach), "the client's rat showed BoundApproach");
        Assert_False(ck::IsValid(_RowRat.Get_Navigator()), "the client's rat has no navigator");
        Finish_RatRow(k_Row, "");
    }
}
