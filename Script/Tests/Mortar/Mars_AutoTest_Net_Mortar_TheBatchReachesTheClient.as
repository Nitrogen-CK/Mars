// The server engages its mortar and switches the seasoning directly, in one frame, and reports. The client's copy reads
// engaged with a Pepper batch, raised OnBatchChanged once, and its label says "Pepper: crush 0/2".
// Surface: Ck.Mortar.Net.AS_Mortar_TheBatchReachesTheClient
class UCk_AutoTest_Net_Mortar_TheBatchReachesTheClient : UMars_AutoTestRig_NetMortar
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 440000.0;

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
        _Mortar.Request_Engage(FMars_Request_Mortar_Engage());
        _Mortar.Request_SwitchSeasoning(FMars_Request_Mortar_SwitchSeasoning());
        Report_Step(FMars_TESTONLY_NetMinigameStep(1));
        End_MinigameServer(f"{Describe_Record()} {Describe_Mortar()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Label = Get_Label();
        Assert_True(_Mortar.Get_IsEngaged(), f"the client's mortar reads engaged ({Describe_Mortar()})");
        Assert_True(_Mortar.Get_Batch().Seasoning == EMars_Mortar_Seasoning::Pepper, f"the client's batch is Pepper ({Describe_Mortar()})");
        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetMortarSignal::BatchChanged), 1, f"the client raised OnBatchChanged once ({Describe_Record()})");
        Assert_True(Label.Contains("Pepper: crush 0/2"), f"the client's label says Pepper: crush 0/2 ('{Label}')");
        End_MinigameClient(f"{Describe_Record()} {Describe_Mortar()}");
    }
}
