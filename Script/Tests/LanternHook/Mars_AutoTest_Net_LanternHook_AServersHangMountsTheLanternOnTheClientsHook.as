// The server hangs the subject's held Persistent lantern on a replicated sconce with a plain Hang. On the client the item
// leaves the hand slot and arrives in the hook's inventory in replication updates of their own; its body must go straight
// from Held to Carried on its own copy of the hook, at AttachPoint.Mars.Hook, posed on the client's hang node with the hang
// offset, with no World commit in between and no ensure.
// Surface: Ck.LanternHook.Net.AS_LanternHook_AServersHangMountsTheLanternOnTheClientsHook
class UCk_AutoTest_Net_LanternHook_AServersHangMountsTheLanternOnTheClientsHook : UMars_AutoTestRig_NetLanternHook
{
    private const FVector k_FloorTop = FVector(42000.0, 0.0, 5000.0);
    private const float64 k_MaxPoseErrorCm = 2.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetLanternHook(InHandle, k_FloorTop);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_LanternHeld", n"OnClientHeld", k_SlowPolls);
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
        WaitSeconds(k_ClientCatchUpSeconds, n"OnServerCaughtUp");
    }

    UFUNCTION()
    private void OnServerCaughtUp(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Hook.Request_Hang(FMars_Request_LanternHook_Hang(_Lantern));
        WaitUntil(n"Is_Hung", n"OnServerHung", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerHung(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds + 2.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Record_MountChanges(_Body);
        WaitUntil(n"Is_ClientOnHook", n"OnClientOnHook", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientOnHook(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Hook.Get_Item() == _Lantern && Get_IsBodyOnHook());
    }

    // A further mount change after the arrival would still be recorded.
    UFUNCTION()
    private void OnClientOnHook(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(0.5f, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Sequence = Describe_MountChanges();
        const auto PoseError = Get_HangPoseError();
        const auto NewEnsures = Get_NewEnsures();
        const auto OnlyCarried = _MountChanges.Num() == 1 && _MountChanges[0] == EMars_WorldItem_Mount::Carried;
        Log(f"[LanternHookNetTest] server hang on the client mounts=[{Sequence}] poseErrorCm={PoseError} newEnsures={NewEnsures}");
        Assert_True(OnlyCarried, f"the client's body went from Held straight to Carried (got [{Sequence}])");
        Assert_True(Get_IsBodyOnHook(), "the client's body is Carried on the sconce at AttachPoint.Mars.Hook");
        Assert_True(PoseError < k_MaxPoseErrorCm, f"the client's body hangs on its hang node with the hang offset (off by {PoseError} cm)");
        Assert_True(NewEnsures == 0, f"no ensure fired (got {NewEnsures})");
        FinishSuccess();
    }
}
