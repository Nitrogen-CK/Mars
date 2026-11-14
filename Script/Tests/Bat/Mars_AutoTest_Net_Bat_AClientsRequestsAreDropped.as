// The client asks its copy of a roosting Cellar Bat to hover, to fly, to hold, to swoop, to cancel, to take a hit, to
// fall, to give its roost back, to end a search and to take a route answer: a machine without authority drops every
// one of them, so its copy still roosts where it was, unhurt and not down, raising no OnPhaseChanged, and the server's
// bat, its roost and its ledger never change.
// Surface: Ck.Bat.Net.AS_Bat_AClientsRequestsAreDropped
class UCk_AutoTest_Net_Bat_AClientsRequestsAreDropped : UMars_AutoTestRig_NetBat
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Floor = FVector(663000.0, 0.0, 5000.0);
    private const float32 k_WatchSeconds = 5.0f;
    private const float32 k_ClientWatchSeconds = 1.5f;
    private const float32 k_ClientHit = 10.0f;

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
        WaitSampling(k_WatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Roost = utils_bat::Get_RoostState(_Roost);
        Assert_True(_Bat.Get_Phase() == EMars_Bat_Phase::Roosting, "the server's bat roosts");
        Assert_True(_Bat.Get_RoostClaim() == EMars_Bat_RoostClaim::Held, "the server's bat holds its roost");
        Assert_Equals_Int(Roost.ReleaseCount, 0, "the server's roost was never released");
        Assert_Equals_Int(_Bat.Get_Hurt().HitCount, 0, "the server's bat was never hit");
        Assert_True(Get_HasBatLedger(), "the server's bat has its ledger");
        Assert_True(Get_BatLedger().Phase == EMars_Bat_Phase::Roosting, "the server's ledger reads Roosting");
        Hold_BatServerRow("AClientsRequestsAreDropped", "");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FCk_Handle Root = _Bat;
        _Bat.Request_SetPhase(FMars_Request_Bat_SetPhase(EMars_Bat_Phase::Hovering));
        _Bat.Request_FlyTo(FMars_Request_Bat_FlyTo(_HangAt + FVector(300.0, 0.0, 0.0), 380.0f));
        _Bat.Request_Hold(FMars_Request_Bat_Hold());
        _Bat.Request_StartSwoop(FMars_Request_Bat_StartSwoop(Root));
        _Bat.Request_CancelSwoop(FMars_Request_Bat_CancelSwoop());
        _Bat.Request_TakeHit(FMars_Request_Bat_TakeHit(FMars_DamageEvent(k_ClientHit, GameplayTags::DamageType_Mars_Blunt)));
        _Bat.Request_Fall(FMars_Request_Bat_Fall());
        _Bat.Request_ReleaseRoost(FMars_Request_Bat_ReleaseRoost());
        _Bat.Request_EndSearch(FMars_Request_Bat_EndSearch());
        _Bat.Request_RouteResult(FMars_Request_Bat_RouteResult(EMars_Bat_RouteOutcome::Reached));
        WaitSampling(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Moved = (_Bat.Get_Location() - _BatFoundAt).Size();
        Assert_True(_Bat.Get_Phase() == EMars_Bat_Phase::Roosting, "the client's bat roosts");
        Assert_True(Moved <= 5.0, f"the client's root is within 5 of where it was found (moved {Moved})");
        Assert_False(_Bat.Has_Fragment(FMars_Fragment_Bat_Requests), "the client's copy carries no requests");
        Assert_Equals_Int(_Bat.Get_Hurt().HitCount, 0, "the client's copy reads no hit");
        Assert_Equals_Int(_BatPhases.Num(), 0, "the client raised no OnPhaseChanged");
        Assert_False(_Bat.Get_IsDown(), "the client's copy is not down");
        Finish_BatRow("AClientsRequestsAreDropped", "");
    }
}
