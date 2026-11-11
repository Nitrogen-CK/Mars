// From a lantern the server hung, a client's take crosses as Cue.Mars.LanternHook.Act to the authority, whose drain moves
// it into the subject's hotbar take target; on both machines the hook is empty and the subject's hotbar holds the lantern,
// and the client's body ends Held on the subject.
// Surface: Ck.LanternHook.Net.AS_LanternHook_AClientTakeCueBringsTheLanternToItsHand
class UCk_AutoTest_Net_LanternHook_AClientTakeCueBringsTheLanternToItsHand : UMars_AutoTestRig_NetLanternHook
{
    private const FVector k_FloorTop = FVector(44000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetLanternHook(InHandle, k_FloorTop);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_ClientHungAndArrived", n"OnClientHung", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerSconceAndLantern();
        WaitUntil(n"Is_ServerLanternLinked", n"OnServerLinked", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerLinked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        PickUp_ServerLantern();
        WaitUntil(n"Is_LanternHeld", n"OnServerLanternHeld", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerLanternHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Hook.Request_Hang(FMars_Request_LanternHook_Hang(_Lantern));
        WaitUntil(n"Is_Hung", n"OnServerHung", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerHung(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_TakenBack", n"OnServerTakenBack", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerTakenBack(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds + 1.0f, n"OnServerHeld");
    }

    // The hook holds the lantern on this machine and its body has arrived there, so the take starts from rest.
    UFUNCTION()
    private void Is_ClientHungAndArrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsHung() && Get_IsBodyOnHook());
    }

    UFUNCTION()
    private void OnClientHung(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Action = _Hook.Get_ActionFor(Get_SubjectEntity());
        Assert_True(Action == EMars_LanternHook_Action::Take, f"the client reads Take with empty hands at a hung lantern (got [{Action :n}])");
        utils_lantern_hook::Request_ActFor(_Hook, Get_SubjectEntity(), EMars_LanternHook_Action::Take);
        WaitUntil(n"Is_ClientTakenAndHeld", n"OnClientTaken", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientTakenAndHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsTakenBack() && _Body.Get_Mount() == EMars_WorldItem_Mount::Held
            && _Body.Get_Carrier() == Get_SubjectEntity() && _Body.Get_IsSettled());
    }

    UFUNCTION()
    private void OnClientTaken(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto NewEnsures = Get_NewEnsures();
        const auto Mount = _Body.Get_Mount();
        Log(f"[LanternHookNetTest] client take cue returned the lantern mount={Mount :n} newEnsures={NewEnsures}");
        Assert_True(NewEnsures == 0, f"no ensure fired (got {NewEnsures})");
        FinishSuccess();
    }
}
