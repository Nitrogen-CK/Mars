// A carrier (AttachPoints + Hotbar + HeldItem, the test entity) holding a rock stows it into a backpack's cargo slot 0 -
// the slot holds it with a cargo visual and the hotbar slot empties - then takes it back into the selected empty bag
// slot - the hotbar holds it and the slot and its visual are gone. Get_ActionFor reads Stow on the empty slot while the
// rock is held; once the hands are empty an empty slot reads Blocked_NothingHeld and the occupied slot 0 reads Take.
// Isolated Z band: -53000.
class UMars_AutoTest_Backpack_CargoStowThenTake : UCk_AutoTest_Base
{
    private FCk_Handle _Carrier;
    private FCk_Handle_Hotbar _Hotbar;
    private FCk_Handle_HeldItem _HeldItem;
    private FCk_Handle_Backpack _Backpack;
    private FCk_Handle_CargoSlot _Slot0;
    private FCk_Handle_Inventory_DataOnly _RockHolder;
    private FCk_Handle_Item _Rock;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Carrier = InHandle;
        auto Root = utils_transform::Add(_Carrier, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -53000.0)),
            ECk_Replication::DoesNotReplicate);

        auto HandNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(40.0, 20.0, 60.0))).As_Transform();
        auto BackNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(-30.0, 0.0, 20.0))).As_Transform();

        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Hand, HandNode));
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Back, BackNode));
        utils_attach_points::Add(_Carrier, AttachPointsSpec);

        auto HotbarSpec = FMars_Hotbar_Spec();
        HotbarSpec.BagSlotCount = 1;
        _Hotbar = utils_hotbar::Add(_Carrier, HotbarSpec);
        _HeldItem = utils_held_item::Add(_Carrier);

        // What the player HFSM's HotbarDrivesHeldItem task does: push the selection into HeldItem on every change.
        _Hotbar.BindTo_OnSelectionChanged(FMars_Delegate_Hotbar_OnSelectionChanged(this, n"OnSelectionChanged"));
        _Hotbar.BindTo_OnSlotItemChanged(FMars_Delegate_Hotbar_OnSlotItemChanged(this, n"OnSlotItemChanged"));

        auto SpawnParams = UMars_Backpack_EntityScript::Params();
        SpawnParams.Definition = mars_items::Backpack();
        SpawnParams.Mode = EMars_WorldItem_Mode::World;
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, FVector(200.0, 0.0, -53000.0));

        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Backpack_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(
            Pending,
            FCk_Delegate_EntityScript_Constructed(this, n"OnBackpackConstructed"));

        _RockHolder = MakeSeededHolder(InHandle, mars_items::Rock());

        Add_Step_WaitUntil("the backpack is constructed with 4 cargo slots and the rock holder is seeded", n"Check_Ready");
        Add_Step("stow the rock into the carrier's hotbar", n"Step_StowRockIntoHotbar");
        Add_Step_WaitUntil("the rock is auto-held with a held visual", n"Check_RockHeld");
        Add_Step("an empty slot offers Stow to a carrier holding a rock", n"Step_AssertStowOffered");
        Add_Step("request Stow into slot 0", n"Step_StowIntoSlot0");
        Add_Step_WaitUntil("slot 0 holds the rock with a cargo visual and the hotbar slot is empty", n"Check_Stowed");
        Add_Step_WaitUntil("the carrier's hands are empty", n"Check_HandsEmpty");
        Add_Step("empty hands: an empty slot reads Blocked_NothingHeld, the occupied slot 0 reads Take", n"Step_AssertAfterStow");
        Add_Step("request Take out of slot 0 into the take target", n"Step_TakeFromSlot0");
        Add_Step_WaitUntil("the hotbar holds the rock again, slot 0 and its visual are empty", n"Check_Taken");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnBackpackConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        auto Entity = FCk_Handle(InEntityScriptHandle);
        _Backpack = Entity.As_Backpack(ECk_SanityCheck::UnChecked);
    }

    UFUNCTION()
    private void OnSelectionChanged(FCk_Handle_Hotbar InHotbar, int32 InPrevIndex, int32 InNewIndex)
    {
        PushSelection();
    }

    UFUNCTION()
    private void OnSlotItemChanged(FCk_Handle_Hotbar InHotbar, int32 InIndex, FCk_Handle_Item InMaybeItem)
    {
        PushSelection();
    }

    private void PushSelection()
    {
        if (ck::Is_NOT_Valid(_Hotbar) || ck::Is_NOT_Valid(_HeldItem))
        { return; }

        _HeldItem.Request_SetSlot(FMars_Request_HeldItem_SetSlot(_Hotbar.Get_SelectedSlot(), _Hotbar.Get_SelectedItem()));
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Ready = ck::IsValid(_Backpack) && _Backpack.Get_CargoSlotCount() == 4 && _RockHolder.Get_NumItems() == 1;
        if (Ready && ck::Is_NOT_Valid(_Rock))
        {
            auto Items = _RockHolder.Get_Items();
            _Rock = Items[0];
            _Slot0 = _Backpack.Get_CargoSlot(0);
        }

        auto Res = OutResult;
        Res.Set(Ready);
    }

    UFUNCTION()
    private void Step_StowRockIntoHotbar(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Target = _Hotbar.TryGet_StowTarget(_Rock);
        if (ck::Is_NOT_Valid(Target) || Target != _Hotbar.Get_Slot(0))
        {
            FinishFailure("stow precondition: the rock's stow target is bag slot 0");
            return;
        }

        _RockHolder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(_Rock, Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }

    UFUNCTION()
    private void Check_RockHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_ItemAt(0) == _Rock &&
                _Hotbar.Get_SelectedIndex() == 0 &&
                _HeldItem.Get_CurrentItem() == _Rock &&
                ck::IsValid(_HeldItem.Get_PresentationEntity()));
    }

    UFUNCTION()
    private void Step_AssertStowOffered(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Slot0, "cargo slot 0");
        Assert_False(_Slot0.Get_IsOccupied(), "slot 0 before the stow");
        const auto Action = _Slot0.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_CargoSlot_Action::Stow, f"Get_ActionFor(carrier holding a rock) on an empty slot (got [{Action :n}])");
    }

    UFUNCTION()
    private void Step_StowIntoSlot0(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Slot0.Request_Stow(FMars_Request_CargoSlot_Stow(_Rock));
    }

    UFUNCTION()
    private void Check_Stowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Slot0.Get_Item() == _Rock &&
                ck::IsValid(_Slot0.Get_Visual()) &&
                ck::Is_NOT_Valid(_Hotbar.Get_ItemAt(0)));
    }

    UFUNCTION()
    private void Check_HandsEmpty(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_HeldItem.Get_CurrentItem()));
    }

    UFUNCTION()
    private void Step_AssertAfterStow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto EmptySlotAction = _Backpack.Get_CargoSlot(1).Get_ActionFor(_Carrier);
        Assert_True(EmptySlotAction == EMars_CargoSlot_Action::Blocked_NothingHeld,
            f"Get_ActionFor(empty-handed carrier) on an empty slot (got [{EmptySlotAction :n}])");

        const auto OccupiedSlotAction = _Slot0.Get_ActionFor(_Carrier);
        Assert_True(OccupiedSlotAction == EMars_CargoSlot_Action::Take,
            f"Get_ActionFor(empty-handed carrier, selected empty bag slot) on the occupied slot (got [{OccupiedSlotAction :n}])");
    }

    UFUNCTION()
    private void Step_TakeFromSlot0(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Target = _Hotbar.TryGet_TakeTarget(_Rock);
        if (ck::Is_NOT_Valid(Target) || Target != _Hotbar.Get_Slot(0))
        {
            FinishFailure("take precondition: the rock's take target is the selected empty bag slot 0");
            return;
        }

        _Slot0.Request_Take(FMars_Request_CargoSlot_Take(_Rock, Target));
    }

    UFUNCTION()
    private void Check_Taken(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_ItemAt(0) == _Rock &&
                _Slot0.Get_IsOccupied() == false &&
                ck::Is_NOT_Valid(_Slot0.Get_Visual()));
    }

    private FCk_Handle_Inventory_DataOnly MakeSeededHolder(FCk_Handle InHandle, UCk_InventoryItem_Definition InDefinition)
    {
        auto HolderOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Params = utils_inventory_data_only::Make_Params_Bounded(
            utils_gameplay_tag::ResolveGameplayTag(n"Inventory.Mars.WorldItemHolder"), 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(),
            FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        auto Holder = utils_inventory_data_only::Add(HolderOwner, Params, ECk_Replication::DoesNotReplicate);

        auto Request = FCk_Request_Inventory_AddItemByDefinition(InDefinition, 1);
        Request.Set_Policy(ECk_Inventory_AddPolicy::ForceNewItem);
        Holder.Request_AddItemByDefinition(Request, FCk_Delegate_Inventory_OnOperationResult_AddByDefinition());
        return Holder;
    }
}
