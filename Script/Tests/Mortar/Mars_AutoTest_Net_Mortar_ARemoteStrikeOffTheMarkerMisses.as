// The timing window's pass is 6 s. The server seats the subject; when its own window is on the marker it presses for the
// subject through the station's helper with a miss's sweep, and reports once the strike has landed. The client raised
// OnStrikeLanded once, with Miss, and its batch has no hit.
// Surface: Ck.Mortar.Net.AS_Mortar_ARemoteStrikeOffTheMarkerMisses
class UCk_AutoTest_Net_Mortar_ARemoteStrikeOffTheMarkerMisses : UMars_AutoTestRig_NetMortar
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 445000.0;

    protected void Configure_Spec(FMars_Mortar_Spec& InOutSpec) override
    {
        InOutSpec.Timing.SweepSeconds = 6.0f;
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
        WaitUntil(n"Is_ServerOnMarker", n"OnServerOnMarker", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerOnMarker(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Mortar.Get_IsEngaged() && Get_IsWindowOnMarker());
    }

    UFUNCTION()
    private void OnServerOnMarker(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Pestle_For(EMars_Mortar_PestleVerb::Press, Get_MissSweep());
        WaitUntil(n"Is_ServerLanded", n"OnServerLanded", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Landings.Num() >= 1);
    }

    UFUNCTION()
    private void OnServerLanded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Landings[0] == EMars_Mortar_Strike::Miss, f"the server's strike landed a miss ({Describe_Record()})");
        Report_Step(FMars_TESTONLY_NetMinigameStep(1));
        End_MinigameServer(f"{Describe_Record()} {Describe_Mortar()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetMortarSignal::StrikeLanded), 1, f"the client raised OnStrikeLanded once ({Describe_Record()})");
        Assert_True(_Landings.Num() == 1 && _Landings[0] == EMars_Mortar_Strike::Miss, f"the client's landing was a miss ({Describe_Record()})");
        Assert_Equals_Int(_Mortar.Get_Batch().CrushHits, 0, f"the client's batch has no hit ({Describe_Mortar()})");
        End_MinigameClient(f"{Describe_Record()} {Describe_Mortar()}");
    }
}
