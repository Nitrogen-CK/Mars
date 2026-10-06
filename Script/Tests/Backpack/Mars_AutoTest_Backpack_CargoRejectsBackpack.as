// A cargo slot's accept policy refuses a backpack item even when the transfer bypasses Get_ActionFor, and an occupied
// slot reads Blocked_SlotOccupied for a carrier whose hands are full. Isolated Z band: -54000.
class UMars_AutoTest_Backpack_CargoRejectsBackpack : UMars_AutoTestRig_Carrier
{
    private FCk_Handle_Backpack _Backpack;
    private FCk_Handle_CargoSlot _Slot0;

    private TOptional<ECk_Inventory_OperationResult_Transfer> _Backpack2TransferResult;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, FVector(0.0, 0.0, -54000.0));
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);
        Bind_PushSelection();

        auto SpawnParams = UMars_Backpack_EntityScript::Params();
        SpawnParams.Definition = mars_items::Backpack();
        SpawnParams.Mode = EMars_WorldItem_Mode::World;
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, FVector(200.0, 0.0, -54000.0));

        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Backpack_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(
            Pending,
            FCk_Delegate_EntityScript_Constructed(this, n"OnBackpackConstructed"));

        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Backpack()));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Cog()));

        Add_Step_WaitUntil("the backpack is constructed with one cargo slot per mount and every holder is seeded", n"Check_Ready");
        Add_Step("force the second backpack into empty cargo slot 0", n"Step_ForceBackpack2IntoSlot0");
        Add_Step_WaitUntil("the forced transfer reported", n"Check_Backpack2TransferRecorded");
        Add_Step("cargo slot 0's policy refused the backpack", n"Step_AssertBackpack2Refused");
        Add_Step("stow the cog into slot 0", n"Step_StowCogIntoSlot0");
        Add_Step_WaitUntil("slot 0 holds the cog", n"Check_CogInSlot0");
        Add_Step("stow the rock into the carrier's hotbar", n"Step_StowRockIntoHotbar");
        Add_Step_WaitUntil("the carrier holds the rock", n"Check_RockHeld");
        Add_Step("an occupied slot reads Blocked_SlotOccupied for full hands", n"Step_AssertSlotOccupied");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnBackpackConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _Backpack = InEntityScriptHandle.As_Backpack();
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllSeeded = true;
        for (const auto& Holder : _Holders)
        { AllSeeded = AllSeeded && Holder.Get_NumItems() == 1; }

        const UMars_ItemTrait_Backpack Trait = mars_items::Backpack().Get_ItemTraitByClass(UMars_ItemTrait_Backpack);
        const auto Ready = AllSeeded && ck::IsValid(_Backpack) && _Backpack.Get_CargoSlotCount() == Trait.CargoSlots.Num();
        if (Ready && _Items.Num() == 0)
        {
            for (const auto& Holder : _Holders)
            {
                auto Items = Holder.Get_Items();
                _Items.Add(Items[0]);
            }

            _Slot0 = _Backpack.Get_CargoSlot(0);
        }

        auto Res = OutResult;
        Res.Set(Ready);
    }

    UFUNCTION()
    private void Step_ForceBackpack2IntoSlot0(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Holder = _Holders[0];
        Holder.Request_TransferItem_ToDataOnly(
            FCk_Request_Inventory_TransferItem_ToDataOnly(_Items[0], _Slot0.Get_Inventory()),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnForcedBackpack2Transfer"));
    }

    UFUNCTION()
    private void OnForcedBackpack2Transfer(FCk_Handle_Inventory InSource,
                                           FCk_Handle_Item InItem,
                                           FCk_Handle_Inventory InTarget,
                                           int32 InCount,
                                           FCk_Handle_Item InNewItemInTarget,
                                           ECk_Inventory_OperationResult_Transfer InResult)
    {
        _Backpack2TransferResult = TOptional<ECk_Inventory_OperationResult_Transfer>(InResult);
    }

    UFUNCTION()
    private void Check_Backpack2TransferRecorded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Backpack2TransferResult.IsSet());
    }

    UFUNCTION()
    private void Step_AssertBackpack2Refused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Backpack2Result = _Backpack2TransferResult.GetValue();
        Assert_True(Backpack2Result != ECk_Inventory_OperationResult_Transfer::Success,
            f"a backpack forced into an empty cargo slot reports a non-Success result (got [{Backpack2Result :n}])");
        Assert_False(_Slot0.Get_IsOccupied(), "cargo slot 0 after the refused backpack");
        Assert_Equals_Int(_Holders[0].Get_NumItems(), 1, "the second backpack's holder after the refused transfer");
    }

    UFUNCTION()
    private void Step_StowCogIntoSlot0(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Slot0.Request_Stow(FMars_Request_CargoSlot_Stow(_Items[2]));
    }

    UFUNCTION()
    private void Check_CogInSlot0(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Slot0.Get_Item() == _Items[2]);
    }

    UFUNCTION()
    private void Step_StowRockIntoHotbar(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Target = _Hotbar.TryGet_StowTarget(_Items[1]);
        if (ck::Is_NOT_Valid(Target))
        {
            FinishFailure("stow precondition: the rock has a stow target");
            return;
        }

        auto Holder = _Holders[1];
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(_Items[1], Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }

    UFUNCTION()
    private void Check_RockHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HeldItem.Get_CurrentItem() == _Items[1]);
    }

    UFUNCTION()
    private void Step_AssertSlotOccupied(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Action = _Slot0.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_CargoSlot_Action::Blocked_SlotOccupied,
            f"Get_ActionFor(carrier holding a rock) on the occupied slot (got [{Action :n}])");
    }
}

// Hand-authored so CkInventory's rollback Warning for the deliberately refused transfer is expected rather than a failure
// (the automation controller elevates Warnings to test errors). Pinned to the item definition and the refusal reason so
// an unrelated refusal still fails the test.
class AMars_AutoTest_Backpack_CargoRejectsBackpack_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_Backpack_CargoRejectsBackpack;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("(Mars_ItemDef_Backpack))] (Failed Rejected by Custom Acceptance Logic)");
        return Out;
    }
}
