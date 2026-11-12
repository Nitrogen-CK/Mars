// The server loads a meat slab (step 1 once it froze), then destroys the platter (step 2 in that frame): the food is gone
// within 5 frames. On the client neither its platter nor a food piece is left near the test's X within 3 s of step 2.
// Surface: Ck.Platter.Net.AS_Platter_ADestroyedPlatterEndsItsPileOnEveryMachine
class UCk_AutoTest_Net_Platter_ADestroyedPlatterEndsItsPileOnEveryMachine : UMars_AutoTestRig_NetPlatter
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 237000.0;
    private const int32 k_ServerGoneFrames = 5;
    private const float64 k_ClientGoneSeconds = 3.0;
    // The server touches nothing else at its X while the client's window runs.
    private const float32 k_ServerWindowSeconds = 3.5f;

    private FCk_Handle _Food;
    private float64 _StepTwoAt = 0.0;
    private FString _EndTextOnServer;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_PlatterRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { WaitUntil(n"Is_ClientStepTwo", n"OnClientStepTwo", k_SlowPolls); }
    }

    protected void On_ServerPlatterReady() override
    {
        _Food = Spawn_BesideFood(mars_items::Food_MeatSlab(), 1.0);
        Load_WhenReady(_Food, 1);
    }

    protected void On_ServerFrozen() override
    {
        Publish_Rides(1);
        WaitSeconds(k_StepSeconds, n"OnServerDestroy");
    }

    UFUNCTION()
    private void OnServerDestroy(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        utils_entity_lifetime::Request_DestroyEntity(_PlatterEntity);
        Publish_Location(2, FVector::ZeroVector);
        WaitFrames(k_ServerGoneFrames, n"OnServerFramesLater");
    }

    UFUNCTION()
    private void OnServerFramesLater(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto IsFoodGone = Get_IsLive(_Food) == false;
        Assert_True(IsFoodGone, f"the server's food is gone within {k_ServerGoneFrames} frames of its platter's destroy");
        _EndTextOnServer = f"foodGone={IsFoodGone}";
        WaitSeconds(k_ServerWindowSeconds, n"OnServerWindowOver");
    }

    UFUNCTION()
    private void OnServerWindowOver(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_PlatterServer(f"{_EndTextOnServer} {Describe_Signals()}");
    }

    UFUNCTION()
    private void Is_ClientStepTwo(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Try_FindPlatter();
        auto Result = OutResult;
        Result.Set(Get_PlatterReport().Step >= 2);
    }

    UFUNCTION()
    private void OnClientStepTwo(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _StepTwoAt = Get_Now();
        WaitUntil(n"Is_ClientClear", n"OnClientClear", k_SlowPolls);
    }

    protected bool Get_IsClear()
    {
        return ck::Is_NOT_Valid(Find_PlatterNear()) && Get_FoodPiecesNear(_FloorTop).Num() == 0 && Get_PieceEntitiesNear(_FloorTop).Num() == 0;
    }

    UFUNCTION()
    private void Is_ClientClear(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsClear() || Get_Now() - _StepTwoAt > k_ClientGoneSeconds);
    }

    UFUNCTION()
    private void OnClientClear(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Seconds = Get_Now() - _StepTwoAt;
        const auto IsClear = Get_IsClear();
        Assert_True(IsClear && Seconds <= k_ClientGoneSeconds,
            f"neither the client's platter nor a food piece is near the test's X within {k_ClientGoneSeconds} s (clear={IsClear} after {Seconds} s)");
        End_PlatterClient(f"clear={IsClear} seconds={Seconds} found={ck::IsValid(_Platter)} {Describe_Signals()}");
    }
}
