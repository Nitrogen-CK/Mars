// A hotbar of 2 bag slots, the overflow and a backpack slot composed on a carrier with no replication driver: its layout
// (Get_LastIndex 3) reads before any slot root exists and the hotbar is not ready yet; once ready, each index holds the
// inventory of its own slot root, a local-class lifetime child of the carrier tagged TAG_MarsHotbarSlot whose slot
// fragment names that index and its kind (Bag, Bag, Overflow, Backpack).
class UMars_AutoTest_Hotbar_SlotsAreAdoptedInLayoutOrder : UCk_AutoTest_Base
{
    private FCk_Handle _Carrier;
    private FCk_Handle_Hotbar _Hotbar;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("compose the hotbar; its layout reads before the slots exist", n"Step_Compose");
        Add_Step_WaitUntil("the hotbar is ready", n"Check_Ready");
        Add_Step("every index holds its own slot root, in layout order", n"Step_AssertLayout");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Compose(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Carrier = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Spec = FMars_Hotbar_Spec();
        Spec.BagSlotCount = 2;
        Spec.BackpackSlot = ECk_EnableDisable::Enable;
        _Hotbar = utils_hotbar::Add(_Carrier, Spec);

        Assert_Equals_Int(_Hotbar.Get_LastIndex(), 3, "the last index is the backpack slot's before any slot root exists");
        Assert_False(_Hotbar.Get_IsReady(), "the hotbar is not ready in the frame it is composed");
        Assert_False(utils_entity_replication_driver::Has(_Carrier), "the test carrier has no replication driver");
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_IsReady());
    }

    UFUNCTION()
    private void Step_AssertLayout(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        TArray<EMars_Hotbar_SlotKind> ExpectedKinds;
        ExpectedKinds.Add(EMars_Hotbar_SlotKind::Bag);
        ExpectedKinds.Add(EMars_Hotbar_SlotKind::Bag);
        ExpectedKinds.Add(EMars_Hotbar_SlotKind::Overflow);
        ExpectedKinds.Add(EMars_Hotbar_SlotKind::Backpack);

        const auto Slots = _Hotbar.Get_Slots();
        Assert_Equals_Int(Slots.Num(), 4, "four slots");

        TArray<FCk_Handle> Roots;
        for (int32 Index = 0; Index < Slots.Num(); ++Index)
        {
            FCk_Handle Inventory = Slots[Index];
            Assert_True(ck::IsValid(Inventory), f"slot [{Index}] has an inventory");
            if (ck::Is_NOT_Valid(Inventory))
            { continue; }

            auto Root = utils_entity_lifetime::Get_LifetimeOwner(Inventory);
            Assert_True(utils_entity_lifetime::Get_LifetimeOwner(Root) == _Carrier, f"slot [{Index}]'s root is a lifetime child of the carrier");
            Assert_True(utils_entity_tag::Has(Root, n"TAG_MarsHotbarSlot"), f"slot [{Index}]'s root is tagged TAG_MarsHotbarSlot");
            Assert_False(Roots.Contains(Root), f"slot [{Index}] has a root of its own");
            Roots.Add(Root);

            Assert_True(Root.Has_Fragment(FMars_Fragment_HotbarSlot), f"slot [{Index}]'s root carries the slot fragment");
            if (Root.Has_Fragment(FMars_Fragment_HotbarSlot) == false)
            { continue; }

            const auto Slot = Root.Get_Fragment(FMars_Fragment_HotbarSlot);
            Assert_Equals_Int(Slot.Index, Index, f"slot [{Index}]'s root names its index");
            Assert_True(Slot.Kind == ExpectedKinds[Index], f"slot [{Index}] is a {ExpectedKinds[Index] :n} slot (got {Slot.Kind :n})");
            Assert_True(Slot.Kind == _Hotbar.Get_SlotKind(Index), f"slot [{Index}]'s kind agrees with the hotbar's layout");

            Assert_True(utils_entity_script::Has(Root) && utils_entity_script::Get_ScriptClass(Root.As_EntityScript()) == UMars_HotbarSlot_Local_EntityScript,
                f"slot [{Index}]'s root is the local slot class (the carrier has no replication driver)");
        }
    }
}
