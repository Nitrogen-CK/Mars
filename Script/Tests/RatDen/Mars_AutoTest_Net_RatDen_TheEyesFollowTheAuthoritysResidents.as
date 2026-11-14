// The server's den lets a resident out, hides its eyes, shows them again and lets the last resident out, a second
// apart: its eyes go to slot 1, vacant, slot 1 and vacant, and the client's den copy shows the same four changes in the
// same order, never grants an emergence and carries no request.
// Surface: Ck.RatDen.Net.AS_RatDen_TheEyesFollowTheAuthoritysResidents
class UCk_AutoTest_Net_RatDen_TheEyesFollowTheAuthoritysResidents : UMars_AutoTestRig_NetPantryRaid
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(674000.0, 0.0, 5000.0);
    private const float32 k_StepSeconds = 1.0f;
    private const FString k_Row = "TheEyesFollowTheAuthoritysResidents";

    private TArray<int32> _WriteFrames;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_PantryRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_RowDenFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_RowSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerDen(2);
        WaitUntil(n"Is_RowDenFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ComposeSeconds, n"OnServerComposed");
    }

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Note_Write();
        _RowDen.Request_Emerge(FMars_Request_RatDen_Emerge(1, 0.0f));
        WaitSeconds(k_StepSeconds, n"OnServerFirstOut");
    }

    UFUNCTION()
    private void OnServerFirstOut(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_IsRowEyeSlot(1), "the server's eyes stand for slot 1 once slot 0 is out");
        Note_Write();
        _RowDen.Request_SetEyes(FMars_Request_RatDen_SetEyes(false));
        WaitSeconds(k_StepSeconds, n"OnServerHidden");
    }

    UFUNCTION()
    private void OnServerHidden(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(_RowDen.Get_EyesShown(), "the server's eyes are vacant while disabled");
        Note_Write();
        _RowDen.Request_SetEyes(FMars_Request_RatDen_SetEyes(true));
        WaitSeconds(k_StepSeconds, n"OnServerShownAgain");
    }

    UFUNCTION()
    private void OnServerShownAgain(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_IsRowEyeSlot(1), "the server's eyes stand for slot 1 again");
        Note_Write();
        _RowDen.Request_Emerge(FMars_Request_RatDen_Emerge(2, 0.0f));
        WaitSeconds(k_StepSeconds, n"OnServerLastOut");
    }

    UFUNCTION()
    private void OnServerLastOut(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(_RowDen.Get_EyesShown(), "the server's eyes are vacant once both are out");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerEnd");
    }

    UFUNCTION()
    private void OnServerEnd(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_PantryRow(k_Row, f"writes=[{Describe_Frames(_WriteFrames)}]");
        Assert_EyeChangesInOrder("server");
        Assert_True(Get_IsRowDenLedger(EMars_RatDen_Eyes::Vacant, 0), "the server's den ledger reads Vacant");
        Assert_Equals_Int(_RowDen.Get_SlotCountIn(EMars_RatDen_SlotState::Pending), 2, "the server's den: both slots Pending");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        TearDown();
        FinishSuccess();
    }

    private void Note_Write()
    {
        _WriteFrames.Add(int32(utils_time::Get_FrameCounter()));
    }

    private FString Describe_Frames(const TArray<int32>& InFrames)
    {
        FString Text;
        for (const auto Frame : InFrames)
        { Text += f"{Frame},"; }

        return Text;
    }

    private void Assert_EyeChangesInOrder(FString InMachine)
    {
        Assert_Equals_Int(_EyeChanges.Num(), 4, f"the {InMachine}'s den raised four eye changes");
        Assert_True(Get_IsEyeChange(0, EMars_RatDen_Eyes::Shown, 1), f"the {InMachine}'s first change is Shown on slot 1");
        Assert_True(Get_IsEyeChange(1, EMars_RatDen_Eyes::Vacant, 0), f"the {InMachine}'s second change is Vacant");
        Assert_True(Get_IsEyeChange(2, EMars_RatDen_Eyes::Shown, 1), f"the {InMachine}'s third change is Shown on slot 1");
        Assert_True(Get_IsEyeChange(3, EMars_RatDen_Eyes::Vacant, 0), f"the {InMachine}'s fourth change is Vacant");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientSawFourChanges", n"OnClientSawFour", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientSawFourChanges(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_EyeChanges.Num() >= 4);
    }

    UFUNCTION()
    private void OnClientSawFour(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRowEnding(_RowDen))
        {
            Log_PantryRow(k_Row, "den=gone");
            FinishFailure("the client's den copy was gone before it asserted");
            return;
        }

        Log_PantryRow(k_Row, "");
        Assert_EyeChangesInOrder("client");
        Assert_False(_RowDen.Get_EyesShown(), "the client's den copy shows no eyes");
        Assert_True(Get_IsRowDenLedger(EMars_RatDen_Eyes::Vacant, 0), "the client's den ledger reads Vacant");
        Assert_Equals_Int(_EmergeReadySignals, 0, "the client's den copy never raised OnEmergeReady");
        Assert_False(_RowDen.Has_Fragment(FMars_Fragment_RatDen_Requests), "the client's den copy carries no requests");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }
}
