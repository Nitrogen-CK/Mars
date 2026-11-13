// One hit cracks the batch and the grind takes 2 s. The server seats the subject and strikes a hit directly. Once the
// phase is Grind it issues for the subject, in one frame through the station's helper, a release with sequence 2 and then
// a press with sequence 1: made in the order press, release, the pestle ends released, so 1 s later it rests and the
// grind is under 0.2. Then, in one frame, a press with sequence 4 and then a release with sequence 3: made in the order
// release, press, the pestle ends held, so the batch is Done within 3 s; the server reports. The client's batch reads Done
// and it raised OnBatchChanged with Done once.
// Surface: Ck.Mortar.Net.AS_Mortar_ActsThatReachTheAuthorityTogetherAreAppliedInTheOrderTheyWereMade
class UCk_AutoTest_Net_Mortar_ActsThatReachTheAuthorityTogetherAreAppliedInTheOrderTheyWereMade : UMars_AutoTestRig_NetMortar
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 452000.0;
    private const float32 k_TapGrindCeiling = 0.2f;
    private const float32 k_DoneWithinSeconds = 3.0f;

    protected void Configure_Spec(FMars_Mortar_Spec& InOutSpec) override
    {
        InOutSpec.CrushesNeeded = 1;
        InOutSpec.GrindSeconds = 2.0f;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MortarRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1, EMars_TESTONLY_NetMinigameArrival::Settled); }
    }

    protected void On_ServerStationReady() override
    {
        Seat_SubjectThen(n"OnServerSeated");
    }

    UFUNCTION()
    private void OnServerSeated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Hit_Directly();
        WaitUntil(n"Is_ServerGrindPhase", n"OnServerGrindPhase", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerGrindPhase(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Mortar.Get_Batch().Phase == EMars_Mortar_Phase::Grind);
    }

    UFUNCTION()
    private void OnServerGrindPhase(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Pestle_ForWithSequence(EMars_Mortar_PestleVerb::Release, 0.0f, 2);
        Pestle_ForWithSequence(EMars_Mortar_PestleVerb::Press, _Mortar.Get_SweepSeconds(), 1);
        WaitSeconds(1.0f, n"OnServerTapHeld");
    }

    UFUNCTION()
    private void OnServerTapHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Progress = _Mortar.Get_Batch().GrindProgress;
        Assert_True(_Mortar.Get_Pestle() == EMars_Mortar_Pestle::Resting, f"press then release, as made, ends released ({Describe_Mortar()})");
        Assert_True(Progress < k_TapGrindCeiling, f"the grind is under {k_TapGrindCeiling} after the tap ({Progress})");
        Log_Minigame(f"after the tap: {Describe_Mortar()}");
        Pestle_ForWithSequence(EMars_Mortar_PestleVerb::Press, _Mortar.Get_SweepSeconds(), 4);
        Pestle_ForWithSequence(EMars_Mortar_PestleVerb::Release, 0.0f, 3);
        WaitSeconds(k_DoneWithinSeconds, n"OnServerHoldHeld");
    }

    UFUNCTION()
    private void OnServerHoldHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Mortar.Get_Batch().Phase == EMars_Mortar_Phase::Done, f"release then press, as made, ends held and the batch is Done ({Describe_Mortar()})");
        Report_Step(FMars_TESTONLY_NetMinigameStep(1));
        End_MinigameServer(f"{Describe_Record()} {Describe_Mortar()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        auto DoneBroadcasts = 0;
        for (const auto& Batch : _Batches)
        {
            if (Batch.Phase == EMars_Mortar_Phase::Done)
            { ++DoneBroadcasts; }
        }

        Assert_True(_Mortar.Get_Batch().Phase == EMars_Mortar_Phase::Done, f"the client's batch is Done ({Describe_Mortar()})");
        Assert_Equals_Int(DoneBroadcasts, 1, f"the client raised OnBatchChanged with Done once ({Describe_Record()})");
        End_MinigameClient(f"{Describe_Record()} {Describe_Mortar()}");
    }
}
