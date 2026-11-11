// A pack whose cargo slot 0 holds a rock is picked up by the subject and taken into its hands (the server's own requests).
// On the client the slot still holds the rock and shows its cargo visual once the pack is Held, and the slot reads
// Blocked_PackHeld for the subject; nobody ensures.
// Surface: Ck.Backpack.Net.AS_Backpack_APickedUpPackKeepsItsCargoOnEveryMachine
class UCk_AutoTest_Net_Backpack_APickedUpPackKeepsItsCargoOnEveryMachine : UMars_AutoTestRig_NetBackpack
{
    private const FVector k_FloorTop = FVector(55000.0, 0.0, 5000.0);

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

    UFUNCTION()
    private void OnServerSeeded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientCatchUpSeconds, n"OnServerCaughtUp");
    }

    UFUNCTION()
    private void OnServerCaughtUp(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Stow_ServerItem();
        WaitUntil(n"Is_StowedAndHandsEmpty", n"OnServerStowed", k_SlowPolls);
    }

    // The client has seen the rock stowed in a pack lying in the world before the pack moves.
    UFUNCTION()
    private void OnServerStowed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientCatchUpSeconds, n"OnServerPickUp");
    }

    UFUNCTION()
    private void OnServerPickUp(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _PackItem.Request_PickUp(FMars_Request_WorldItem_PickUp(Get_SubjectEntity()));
        WaitUntil(n"Is_PackInBackpackSlot", n"OnServerPackStowed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerPackStowed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Carrier.Hotbar.Request_SetSelection(FMars_Request_Hotbar_SetSelection(_Carrier.Hotbar.Get_BackpackIndex()));
        WaitUntil(n"Is_PackHeld", n"OnServerPackHeld", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerPackHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds + 1.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientRockHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_PackHeld", n"OnClientPackArrived", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientPackArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(5, n"OnClientPackHeld");
    }

    UFUNCTION()
    private void OnClientPackHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Holds = _Slot0.Get_Item() == _Item;
        const auto HasVisual = ck::IsValid(_Slot0.Get_Visual());
        const auto Action = _Slot0.Get_ActionFor(Get_SubjectEntity());
        const auto NewEnsures = Get_NewEnsures();
        Log(f"[BackpackNetTest] picked-up pack keeps its cargo holds={Holds} visual={HasVisual} action={Action :n} newEnsures={NewEnsures}");
        Assert_True(Holds, "the client's slot still holds the rock");
        Assert_True(HasVisual, "the client's slot still shows the rock's cargo visual");
        Assert_True(Action == EMars_CargoSlot_Action::Blocked_PackHeld, f"the client's slot reads Blocked_PackHeld (got [{Action :n}])");
        Assert_True(NewEnsures == 0, f"the client saw no ensure (got {NewEnsures})");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_PackInBackpackSlot(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_PackItem) && _Carrier.Hotbar.Get_BackpackItem() == _PackItem.Get_Item());
    }

    // This machine's pack is in the subject's hands, settled, and its slot still holds the rock.
    UFUNCTION()
    private void Is_PackHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_PackItem) && _PackItem.Get_Mount() == EMars_WorldItem_Mount::Held && _PackItem.Get_IsSettled()
            && ck::IsValid(_Slot0) && _Slot0.Get_Item() == _Item);
    }
}
