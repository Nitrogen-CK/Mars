// A client's hang crosses as Cue.Mars.LanternHook.Act to the authority, whose drain moves the subject's held lantern into
// the sconce's hook; on both machines the hook holds the lantern and the subject's slot is empty, and the client's
// Get_ActionFor then reads Take.
// Surface: Ck.LanternHook.Net.AS_LanternHook_AClientHangCueHangsItsHeldLantern
class UCk_AutoTest_Net_LanternHook_AClientHangCueHangsItsHeldLantern : UMars_AutoTestRig_NetLanternHook
{
    private const FVector k_FloorTop = FVector(43000.0, 0.0, 5000.0);

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
        WaitUntil(n"Is_Hung", n"OnServerHung", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerHung(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds + 1.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Action = _Hook.Get_ActionFor(Get_SubjectEntity());
        Assert_True(Action == EMars_LanternHook_Action::Hang, f"the client reads Hang while holding the lantern (got [{Action :n}])");
        utils_lantern_hook::Request_ActFor(_Hook, Get_SubjectEntity(), EMars_LanternHook_Action::Hang);
        WaitUntil(n"Is_Hung", n"OnClientContentsArrived", k_SlowPolls);
    }

    // The subject's HeldItem derives from its emptied slot on its next pass.
    UFUNCTION()
    private void OnClientContentsArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(5, n"OnClientHung");
    }

    UFUNCTION()
    private void OnClientHung(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Action = _Hook.Get_ActionFor(Get_SubjectEntity());
        const auto NewEnsures = Get_NewEnsures();
        Log(f"[LanternHookNetTest] client hang cue hung actionAfter={Action :n} newEnsures={NewEnsures}");
        Assert_True(Action == EMars_LanternHook_Action::Take, f"the client then reads Take (got [{Action :n}])");
        Assert_True(NewEnsures == 0, f"no ensure fired (got {NewEnsures})");
        FinishSuccess();
    }
}
