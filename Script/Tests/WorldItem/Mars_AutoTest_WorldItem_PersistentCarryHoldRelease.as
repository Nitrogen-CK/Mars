// A Persistent (backpack) world item survives being stowed, then moves between its carrier's Back (Carried, Kinematic),
// its Hand (Held) and the world (Released: Dynamic, the item back in its holder, the launch drained). Isolated Z band:
// -51000.
class UMars_AutoTest_WorldItem_PersistentCarryHoldRelease : UMars_AutoTestRig_Carrier
{
    private FCk_Handle_WorldItem _WorldItem;
    private FCk_Handle_Item _Item;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, FVector(0.0, 0.0, -51000.0));
        Add_Hotbar(_Carrier, 1);

        auto SpawnParams = UMars_WorldItem_EntityScript::Params();
        SpawnParams.Definition = mars_items::Backpack();
        SpawnParams.Mode = EMars_WorldItem_Mode::World;
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, FVector(200.0, 0.0, -51000.0));

        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_WorldItem_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(
            Pending,
            FCk_Delegate_EntityScript_Constructed(this, n"OnWorldItemConstructed"));

        Add_Step_WaitUntil("the backpack world item's holder holds its seeded item", n"Check_HolderSeeded");
        Add_Step("the seeded item links back to its persistent world item", n"Step_AssertPersistentLink");
        Add_Step("stow the backpack into the carrier's stow target", n"Step_Stow");
        Add_Step_WaitUntil("the carrier wears the backpack", n"Check_Wearing");
        Add_Step_WaitFrames("give a transient world item time to destroy itself", 3);
        Add_Step("the persistent world item survived the stow", n"Step_AssertSurvivedStow");
        Add_Step("request Carry", n"Step_Carry");
        Add_Step_WaitUntil("Carried on the Back node with a Kinematic body", n"Check_Carried");
        Add_Step("request Hold", n"Step_Hold");
        Add_Step_WaitUntil("Held on the Hand node", n"Check_Held");
        Add_Step("request Release", n"Step_Release");
        Add_Step_WaitUntil("back in the world: holder holds the item, slot empty, body Dynamic, launch drained", n"Check_Released");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnWorldItemConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _WorldItem = InEntityScriptHandle.As_WorldItem();
    }

    UFUNCTION()
    private void Check_HolderSeeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_WorldItem) && ck::IsValid(_WorldItem.Get_HeldItem()));
    }

    UFUNCTION()
    private void Step_AssertPersistentLink(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Item = _WorldItem.Get_HeldItem();
        Assert_True(_WorldItem.Get_Persistence() == EMars_WorldItem_Persistence::Persistent, "the backpack world item is Persistent");
        Assert_True(_Item.Has_PersistentWorldItem(), "the seeded item carries the PersistentWorldItem marker");
        Assert_True(_Item.Get_PersistentWorldItem() == _WorldItem, "the marker names this world item");
        Assert_True(_WorldItem.Get_Mount() == EMars_WorldItem_Mount::World, "a fresh world item is mounted World");
    }

    UFUNCTION()
    private void Step_Stow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Target = _Hotbar.TryGet_StowTarget(_Item);
        if (ck::Is_NOT_Valid(Target) || Target != _Hotbar.Get_BackpackSlot())
        {
            FinishFailure("stow precondition: the backpack's stow target is the backpack slot");
            return;
        }

        auto Holder = _WorldItem.Get_Holder();
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(_Item, Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }

    UFUNCTION()
    private void Check_Wearing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_IsWearingBackpack() && ck::IsValid(_WorldItem));
    }

    UFUNCTION()
    private void Step_AssertSurvivedStow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_WorldItem, "the persistent world item survives its holder emptying");
        Assert_True(_Hotbar.Get_BackpackItem() == _Item, "the backpack slot holds the backpack item");
    }

    UFUNCTION()
    private void Step_Carry(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _WorldItem.Request_Carry(FMars_Request_WorldItem_Carry(_Carrier));
    }

    UFUNCTION()
    private void Check_Carried(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_WorldItem) &&
                _WorldItem.Get_Mount() == EMars_WorldItem_Mount::Carried &&
                _WorldItem.Get_Carrier() == _Carrier &&
                DoGet_MountParent() == _BackNode &&
                DoGet_MotionType() == ECk_MotionType::Kinematic);
    }

    UFUNCTION()
    private void Step_Hold(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _WorldItem.Request_Hold(FMars_Request_WorldItem_Hold(_Carrier));
    }

    UFUNCTION()
    private void Check_Held(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_WorldItem) &&
                _WorldItem.Get_Mount() == EMars_WorldItem_Mount::Held &&
                DoGet_MountParent() == _HandNode &&
                DoGet_MotionType() == ECk_MotionType::Kinematic);
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _WorldItem.Request_Release(FMars_Request_WorldItem_Release(
            _Item, _Hotbar.Get_BackpackSlot(), FVector(0.0, 0.0, 50.0), FVector::ZeroVector));
    }

    UFUNCTION()
    private void Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_WorldItem) &&
                _WorldItem.Get_Mount() == EMars_WorldItem_Mount::World &&
                ck::Is_NOT_Valid(_WorldItem.Get_Carrier()) &&
                _WorldItem.Get_HeldItem() == _Item &&
                _Hotbar.Get_BackpackSlot().Get_NumItems() == 0 &&
                _WorldItem.Is_SceneNode() == false &&
                DoGet_MotionType() == ECk_MotionType::Dynamic &&
                _WorldItem.Has_Fragment(FMars_Fragment_WorldItem_PendingLaunch) == false);
    }

    // Invalid while the world item is not scene-node attached.
    private FCk_Handle_Transform DoGet_MountParent() const
    {
        auto Node = _WorldItem.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return FCk_Handle_Transform(); }

        return utils_scene_node::Get_Parent(Node);
    }

    // A World-mode backpack always has a body (its mesh is the engine cube), so a missing one fails the test.
    private ECk_MotionType DoGet_MotionType()
    {
        auto Body = _WorldItem.Get_Body();
        if (ck::Is_NOT_Valid(Body))
        {
            FinishFailure("the backpack world item has no body");
            return ECk_MotionType::Static;
        }

        return utils_jolt_body::Get_MotionType(Body);
    }
}
