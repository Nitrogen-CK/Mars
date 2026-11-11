// A low lantern rides a bag slot and the subject holds tallow; the client fires Act(Refuel) at the lantern's flame, and on
// both machines the lantern's MeasuresLeft rose and the tallow is gone from the hotbar.
// Surface: Ck.Flame.Net.AS_Flame_AClientRefuelsItsLanternWithHeldTallow
class UCk_AutoTest_Net_Flame_AClientRefuelsItsLanternWithHeldTallow : UMars_AutoTestRig_NetFlame
{
    private const FVector k_FloorTop = FVector(63000.0, 0.0, 5000.0);
    private const int32 k_LanternSlot = 0;
    private const int32 k_TallowSlot = 1;

    // The low lantern's start: one measure of four.
    private const int32 k_MeasuresBefore = 1;

    private FCk_Handle_Flame _Lantern;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetFlame(InHandle, k_FloorTop, 2);
        _HoldDefinition = mars_test_items::LowLantern();

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_TallowHeldLanternStowed", n"OnClientReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    // The subject holds the tallow and the lantern rides its bag slot on this machine; the first time, that lantern's
    // flame is the one this machine knows.
    UFUNCTION()
    private void Is_TallowHeldLanternStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (Get_IsCarrierReady(_Carrier) == false || Get_SlotHolds(k_TallowSlot, mars_items::Tallow()) == false)
        { Result.Set(false); return; }

        const auto Held = _Carrier.HeldItem.Get_CurrentItem();
        auto Slot = _Carrier.Hotbar.Get_Slot(k_LanternSlot);
        if (ck::Is_NOT_Valid(Held) || Held.Has_Tallow() == false || ck::Is_NOT_Valid(Slot) || Slot.Get_NumItems() != 1)
        { Result.Set(false); return; }

        const auto Item = Slot.Get_SoleItem();
        if (Item.Has_PersistentWorldItem() == false)
        { Result.Set(false); return; }

        _Lantern = Item.Get_PersistentWorldItem().H().As_Flame(ECk_SanityCheck::UnChecked);
        Result.Set(ck::IsValid(_Lantern));
    }

    UFUNCTION()
    private void Is_Refuelled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Lantern) && _Lantern.Get_MeasuresLeft() > k_MeasuresBefore && Get_SlotItemCount(k_TallowSlot) == 0);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerFlameItem(mars_test_items::LowLantern());
        WaitUntil(n"Is_ServerItemLinked", n"OnServerLinked", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerLinked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        PickUp_ServerItem();
        WaitUntil(n"Is_ItemHeld", n"OnServerLanternHeld", k_SlowPolls);
    }

    // The lantern took the selected slot; the tallow goes in the other and is selected, so the lantern rides the belt.
    UFUNCTION()
    private void OnServerLanternHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Seed_ServerSlotWith(k_TallowSlot, mars_items::Tallow());
        WaitUntil(n"Is_TallowSeeded", n"OnServerTallowSeeded", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_TallowSeeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_SlotHolds(k_TallowSlot, mars_items::Tallow()));
    }

    UFUNCTION()
    private void OnServerTallowSeeded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Carrier.Hotbar.Request_Select(FMars_Request_Hotbar_Select(k_TallowSlot));
        WaitUntil(n"Is_TallowHeldLanternStowed", n"OnServerReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_Refuelled", n"OnServerRefuelled", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerRefuelled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds + 1.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Lantern.Get_MeasuresLeft(), k_MeasuresBefore, "the client's lantern starts low");
        const auto Target = utils_flame::TryGet_RefuelTarget(_Carrier.Hotbar);
        Assert_True(Target == _Lantern, "the client's hotbar offers its lantern as the refuel target");
        utils_flame::Request_ActFor(_Lantern, Get_SubjectEntity(), EMars_Flame_Verb::Refuel);
        WaitUntil(n"Is_Refuelled", n"OnClientRefuelled", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientRefuelled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto NewEnsures = Get_NewEnsures();
        Log(f"[FlameNetTest] client refuelled its lantern before={k_MeasuresBefore} after={_Lantern.Get_MeasuresLeft()} tallowLeft={Get_SlotItemCount(k_TallowSlot)} newEnsures={NewEnsures}");
        Assert_True(NewEnsures == 0, f"no ensure fired (got {NewEnsures})");
        FinishSuccess();
    }
}
