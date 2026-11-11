// A pack the server spawns reaches the client with its cargo slots adopted: the client's pack is ready, has the
// definition's slot count, and every slot is a valid replicated copy (no authority) with an inventory; nobody ensures.
// Surface: Ck.Backpack.Net.AS_CargoSlot_APackReachesTheClientWithItsSlotsAdopted
class UCk_AutoTest_Net_CargoSlot_APackReachesTheClientWithItsSlotsAdopted : UMars_AutoTestRig_NetBackpack
{
    private const FVector k_FloorTop = FVector(48000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetBackpack(InHandle, k_FloorTop);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_PackReady", n"OnClientPackReady", k_SlowPolls);
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
        WaitSeconds(k_ServerHoldSeconds + 1.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientPackReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const UMars_ItemTrait_Backpack Trait = mars_items::Backpack().Get_ItemTraitByClass(UMars_ItemTrait_Backpack);
        const auto Expected = Trait.CargoSlots.Num();
        const auto Count = _Pack.Get_CargoSlotCount();

        auto ValidSlots = 0;
        auto AuthoritySlots = 0;
        auto WithInventory = 0;
        for (int32 Index = 0; Index < Count; ++Index)
        {
            const auto Slot = _Pack.Get_CargoSlot(Index);
            if (ck::Is_NOT_Valid(Slot))
            { continue; }

            ValidSlots += 1;
            if (utils_net::Get_HasAuthority(Slot))
            { AuthoritySlots += 1; }

            if (ck::IsValid(Slot.Get_Inventory()))
            { WithInventory += 1; }
        }

        const auto NewEnsures = Get_NewEnsures();
        Log(f"[CargoSlotNetTest] pack reached the client ready={_Pack.Get_IsReady()} slots={Count}/{Expected} valid={ValidSlots} "
            + f"withAuthority={AuthoritySlots} withInventory={WithInventory} newEnsures={NewEnsures}");
        Assert_True(_Pack.Get_IsReady(), "the client's pack is ready");
        Assert_True(Count == Expected, f"the client's pack has the definition's slot count (got {Count}, expected {Expected})");
        Assert_True(ValidSlots == Expected, f"every client slot handle is valid (got {ValidSlots})");
        Assert_True(AuthoritySlots == 0, f"no client slot has authority (got {AuthoritySlots})");
        Assert_True(WithInventory == Expected, f"every client slot has an inventory (got {WithInventory})");
        Assert_True(NewEnsures == 0, f"no ensure fired (got {NewEnsures})");
        FinishSuccess();
    }
}
