// The item-carrier tests' rig (Hotbar, Interactable, Backpack, WorldItem): a Hotbar on the test entity, one-slot holders
// seeded from item definitions, the pickup task's stow and the take into the hotbar, the HotbarDrivesHeldItem push, and
// the carrier's body for the tests whose carrier holds or wears what it picks up.
UCLASS(Abstract)
class UMars_AutoTestRig_Carrier : UCk_AutoTest_Base
{
    protected FCk_Handle _Carrier;
    protected FCk_Handle_Transform _HandNode;
    protected FCk_Handle_Transform _BackNode;
    protected FCk_Handle_Hotbar _Hotbar;
    protected FCk_Handle_HeldItem _HeldItem;
    protected TArray<FCk_Handle_Inventory_DataOnly> _Holders;
    // The holders' items in holder order, recorded by Check_HoldersSeeded once every holder is seeded.
    protected TArray<FCk_Handle_Item> _Items;

    // The test entity is the carrier, rooted at InLocation, with a Hand node published as AttachPoint.Mars.Hand.
    protected void Add_CarrierBody(FCk_Handle InHandle, FVector InLocation)
    {
        _Carrier = InHandle;
        auto Root = utils_transform::Add(_Carrier, FTransform(FRotator::ZeroRotator, InLocation), ECk_Replication::DoesNotReplicate);

        _HandNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(40.0, 20.0, 60.0))).As_Transform();
        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Hand, _HandNode));
        utils_attach_points::Add(_Carrier, AttachPointsSpec);
    }

    // Add_CarrierBody with a Back node as well, published as AttachPoint.Mars.Back.
    protected void Add_CarrierBodyWithBack(FCk_Handle InHandle, FVector InLocation)
    {
        _Carrier = InHandle;
        auto Root = utils_transform::Add(_Carrier, FTransform(FRotator::ZeroRotator, InLocation), ECk_Replication::DoesNotReplicate);

        _HandNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(40.0, 20.0, 60.0))).As_Transform();
        _BackNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(-30.0, 0.0, 20.0))).As_Transform();

        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Hand, _HandNode));
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Back, _BackNode));
        utils_attach_points::Add(_Carrier, AttachPointsSpec);
    }

    protected void Add_Hotbar(FCk_Handle InCarrier, int32 InBagSlotCount)
    {
        auto Carrier = InCarrier;
        auto Spec = FMars_Hotbar_Spec();
        Spec.BagSlotCount = InBagSlotCount;
        _Hotbar = utils_hotbar::Add(Carrier, Spec);
    }

    // A one-slot holder of its own, seeded with one item of InDefinition.
    protected FCk_Handle_Inventory_DataOnly MakeSeededHolder(FCk_Handle InHandle, UCk_InventoryItem_Definition InDefinition)
    {
        auto HolderOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Params = utils_inventory_data_only::Make_Params_Bounded(
            GameplayTags::Inventory_Mars_WorldItemHolder, 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(),
            FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        auto Holder = utils_inventory_data_only::Add(HolderOwner, Params, ECk_Replication::DoesNotReplicate);

        auto Request = FCk_Request_Inventory_AddItemByDefinition(InDefinition, 1);
        Request.Set_Policy(ECk_Inventory_AddPolicy::ForceNewItem);
        Holder.Request_AddItemByDefinition(Request, FCk_Delegate_Inventory_OnOperationResult_AddByDefinition());
        return Holder;
    }

    // What the pickup task does: transfer into whatever the hotbar names as the stow target for the item.
    protected void StowFrom(FCk_Handle_Inventory_DataOnly InHolder)
    {
        auto Items = InHolder.Get_Items();
        auto Target = FCk_Handle_Inventory_DataOnly();
        if (Items.Num() == 1)
        { Target = _Hotbar.TryGet_StowTarget(Items[0]); }

        if (ck::Is_NOT_Valid(Target) || Items.Num() != 1)
        {
            FinishFailure("stow precondition: a valid stow target and a holder with one item");
            return;
        }

        auto Holder = InHolder;
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(Items[0], Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }

    // What a take does: transfer into whatever the hotbar names as the take target for the item.
    protected void TakeFrom(FCk_Handle_Inventory_DataOnly InHolder)
    {
        auto Items = InHolder.Get_Items();
        auto Target = FCk_Handle_Inventory_DataOnly();
        if (Items.Num() == 1)
        { Target = _Hotbar.TryGet_TakeTarget(Items[0]); }

        if (ck::Is_NOT_Valid(Target) || Items.Num() != 1)
        {
            FinishFailure("take precondition: a valid take target and a holder with one item");
            return;
        }

        auto Holder = InHolder;
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(Items[0], Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }

    // What the player HFSM's HotbarDrivesHeldItem task does: push the selection into HeldItem on every change.
    protected void Bind_PushSelection()
    {
        _Hotbar.BindTo_OnSelectionChanged(FMars_Delegate_Hotbar_OnSelectionChanged(this, n"PushSelection_OnSelectionChanged"));
        _Hotbar.BindTo_OnSlotItemChanged(FMars_Delegate_Hotbar_OnSlotItemChanged(this, n"PushSelection_OnSlotItemChanged"));
    }

    UFUNCTION()
    protected void PushSelection_OnSelectionChanged(FCk_Handle_Hotbar InHotbar)
    {
        PushSelection();
    }

    UFUNCTION()
    protected void PushSelection_OnSlotItemChanged(FCk_Handle_Hotbar InHotbar, int32 InIndex, FCk_Handle_Item InMaybeItem)
    {
        PushSelection();
    }

    protected void PushSelection()
    {
        if (ck::Is_NOT_Valid(_Hotbar) || ck::Is_NOT_Valid(_HeldItem))
        {
            FinishFailure("the carrier's Hotbar or HeldItem did not compose");
            return;
        }

        _HeldItem.Request_SetSlot(FMars_Request_HeldItem_SetSlot(_Hotbar.Get_SelectedSlot(), _Hotbar.Get_SelectedItem()));
    }

    UFUNCTION()
    protected void Check_HoldersSeeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllSeeded = true;
        for (const auto& Holder : _Holders)
        { AllSeeded = AllSeeded && Holder.Get_NumItems() == 1; }

        if (AllSeeded && _Items.Num() == 0)
        {
            for (const auto& Holder : _Holders)
            {
                auto Items = Holder.Get_Items();
                _Items.Add(Items[0]);
            }
        }

        auto Res = OutResult;
        Res.Set(AllSeeded);
    }

    UFUNCTION()
    protected void Step_StowFirst(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        StowFrom(_Holders[0]);
    }

    UFUNCTION()
    protected void Step_StowSecond(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        StowFrom(_Holders[1]);
    }

    UFUNCTION()
    protected void Step_StowThird(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        StowFrom(_Holders[2]);
    }

    UFUNCTION()
    protected void Check_SecondStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Hotbar.Get_ItemAt(1)));
    }

    UFUNCTION()
    protected void Check_OverflowFilled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_Slot(2).Get_NumItems() == 1 && _Hotbar.Get_SelectedIndex() == TOptional<int32>(2));
    }

    UFUNCTION()
    protected void Step_SelectZero(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(0));
    }

    UFUNCTION()
    protected void Check_SelectedZero(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_SelectedIndex() == TOptional<int32>(0));
    }

    UFUNCTION()
    protected void Step_SelectEmptySlot(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(1));
    }

    UFUNCTION()
    protected void Check_HandsEmpty(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_HeldItem.Get_CurrentItem()));
    }
}
