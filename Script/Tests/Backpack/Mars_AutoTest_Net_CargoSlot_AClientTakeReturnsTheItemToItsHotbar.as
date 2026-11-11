// From a rock the server stowed into cargo slot 0, a client's take crosses as Cue.Mars.CargoSlot.Act to the authority,
// whose drain moves the rock into the subject's take target; on both machines the slot is empty and the subject's hotbar
// holds the rock, and the client's cargo visual is gone.
// Surface: Ck.Backpack.Net.AS_CargoSlot_AClientTakeReturnsTheItemToItsHotbar
class UCk_AutoTest_Net_CargoSlot_AClientTakeReturnsTheItemToItsHotbar : UMars_AutoTestRig_NetBackpack
{
    private const FVector k_FloorTop = FVector(50000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetBackpack(InHandle, k_FloorTop);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_PackReadyAndRockHeld", n"OnClientRockHeld", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerPack();
        WaitUntil(n"Is_PackReady", n"OnServerPackReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerPackReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Seed_ServerSlotWith(0, mars_items::Rock());
        WaitUntil(n"Is_PackReadyAndRockHeld", n"OnServerSeeded", k_SlowPolls);
    }

    // The client has seen the rock held before it is stowed, so it knows which item comes back.
    UFUNCTION()
    private void OnServerSeeded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientCatchUpSeconds, n"OnServerCaughtUp");
    }

    UFUNCTION()
    private void OnServerCaughtUp(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Stow_ServerItem();
        WaitUntil(n"Is_Stowed", n"OnServerStowed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerStowed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_TakenBack", n"OnServerTakenBack", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerTakenBack(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds + 1.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientRockHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_StowedAndHandsEmpty", n"OnClientStowed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientStowed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Action = _Slot0.Get_ActionFor(Get_SubjectEntity());
        Assert_True(Action == EMars_CargoSlot_Action::Take, f"the client reads Take with empty hands (got [{Action :n}])");
        utils_cargo_slot::Request_ActFor(_Slot0, Get_SubjectEntity(), EMars_CargoSlot_Action::Take);
        WaitUntil(n"Is_TakenBack", n"OnClientContentsArrived", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientContentsArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(5, n"OnClientTaken");
    }

    UFUNCTION()
    private void OnClientTaken(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto VisualGone = ck::Is_NOT_Valid(_Slot0.Get_Visual());
        const auto NewEnsures = Get_NewEnsures();
        Log(f"[CargoSlotNetTest] client take returned the item visualGone={VisualGone} itemChanges={_ItemChanges} newEnsures={NewEnsures}");
        Assert_True(VisualGone, "the client's cargo visual is gone");
        Assert_True(NewEnsures == 0, f"the client saw no ensure (got {NewEnsures})");
        FinishSuccess();
    }
}
