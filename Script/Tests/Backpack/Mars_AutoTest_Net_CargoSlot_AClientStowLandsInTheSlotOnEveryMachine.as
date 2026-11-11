// A client's stow crosses as Cue.Mars.CargoSlot.Act to the authority, whose drain moves the subject's held rock out of
// its bag slot into cargo slot 0; the slot's inventory replicates back, so on both machines the cargo slot holds the rock
// and the bag slot is empty. The client's slot shows a cargo visual and raised OnItemChanged once, and the client saw no
// ensure.
// Surface: Ck.Backpack.Net.AS_CargoSlot_AClientStowLandsInTheSlotOnEveryMachine
class UCk_AutoTest_Net_CargoSlot_AClientStowLandsInTheSlotOnEveryMachine : UMars_AutoTestRig_NetBackpack
{
    private const FVector k_FloorTop = FVector(49000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetBackpack(InHandle, k_FloorTop);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_PackReadyAndRockHeld", n"OnClientReady", k_SlowPolls);
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

    UFUNCTION()
    private void OnServerSeeded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_Stowed", n"OnServerStowed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerStowed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds + 1.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_Slot0), "the client's slot has no authority");
        const auto Action = _Slot0.Get_ActionFor(Get_SubjectEntity());
        Assert_True(Action == EMars_CargoSlot_Action::Stow, f"the client reads Stow while holding the rock (got [{Action :n}])");
        utils_cargo_slot::Request_ActFor(_Slot0, Get_SubjectEntity(), EMars_CargoSlot_Action::Stow);
        WaitUntil(n"Is_Stowed", n"OnClientContentsArrived", k_SlowPolls);
    }

    // The slot's sync reacts to the replicated contents on its next pass.
    UFUNCTION()
    private void OnClientContentsArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(5, n"OnClientStowed");
    }

    UFUNCTION()
    private void OnClientStowed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto HasVisual = ck::IsValid(_Slot0.Get_Visual());
        const auto NewEnsures = Get_NewEnsures();
        Log(f"[CargoSlotNetTest] client stow landed visual={HasVisual} itemChanges={_ItemChanges} newEnsures={NewEnsures}");
        Assert_True(HasVisual, "the client's slot shows the rock's cargo visual");
        Assert_True(_ItemChanges == 1, f"the client's slot raised OnItemChanged once (got {_ItemChanges})");
        Assert_True(NewEnsures == 0, f"the client saw no ensure (got {NewEnsures})");
        FinishSuccess();
    }
}
