// The server sets its Cellar Bat Hovering as soon as its behaviour reads Roost and it carries no pending requests,
// before the client's copy can be sure to have composed: the client's copy reads Hovering with its ledger Hovering and
// its root at the hang point, having raised OnPhaseChanged at most once (0: the ledger stood when the copy bound and
// it shows the phase as it is; 1: the ledger arrived after and the change was raised on arrival).
// Surface: Ck.Bat.Net.AS_Bat_ALateBinderSeesTheBatsPhaseAsItStands
class UCk_AutoTest_Net_Bat_ALateBinderSeesTheBatsPhaseAsItStands : UMars_AutoTestRig_NetBat
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Floor = FVector(664000.0, 0.0, 5000.0);
    private const float32 k_HoldSeconds = 4.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BatRow(k_Floor);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_BatFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        Begin_ServerWorld(n"OnServerReady");
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_RoostingAndQuiet", n"OnServerQuiet", k_SlowPolls);
    }

    // Its behaviour reads Roost (the state's own requests were issued) and the drain has taken them.
    UFUNCTION()
    private void Is_RoostingAndQuiet(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsBatGone() == false && _Bat.Get_BehaviorStateClass() == UMars_SmState_Bat_Roost
            && _Bat.Has_Fragment(FMars_Fragment_Bat_Requests) == false);
    }

    UFUNCTION()
    private void OnServerQuiet(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(1, n"OnServerHover");
    }

    UFUNCTION()
    private void OnServerHover(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Bat.Request_SetPhase(FMars_Request_Bat_SetPhase(EMars_Bat_Phase::Hovering));
        WaitSampling(k_HoldSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto FromHang = Get_BatFromHang();
        Assert_True(_Bat.Get_Phase() == EMars_Bat_Phase::Hovering, f"the server's bat hovers (reads {_Bat.Get_Phase() :n})");
        Assert_True(Get_HasBatLedger(), "the server's bat has its ledger");
        Assert_True(Get_BatLedger().Phase == EMars_Bat_Phase::Hovering, "the server's ledger reads Hovering");
        Assert_True(FromHang <= 1.0, f"the server's root is within 1 of the hang point (reads {FromHang})");
        Hold_BatServerRow("ALateBinderSeesTheBatsPhaseAsItStands", "");
    }

    UFUNCTION()
    private void Is_CopyHovering(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Bat();
        auto Result = OutResult;
        Result.Set(Get_IsBatGone() == false && _Bat.Get_Phase() == EMars_Bat_Phase::Hovering);
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_CopyHovering", n"OnClientHovering", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientHovering(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto FromHang = Get_BatFromHang();
        Assert_True(_Bat.Get_Phase() == EMars_Bat_Phase::Hovering, "the client's bat hovers");
        Assert_True(Get_HasBatLedger(), "the client's copy has its ledger");
        Assert_True(Get_BatLedger().Phase == EMars_Bat_Phase::Hovering, "the client's ledger reads Hovering");
        Assert_True(_BatPhases.Num() <= 1, "the client raised OnPhaseChanged at most once");
        Assert_True(FromHang <= 1.0, f"the client's root is within 1 of the hang point (reads {FromHang})");
        Finish_BatRow("ALateBinderSeesTheBatsPhaseAsItStands", f"path={_BatPhases.Num()}");
    }
}
