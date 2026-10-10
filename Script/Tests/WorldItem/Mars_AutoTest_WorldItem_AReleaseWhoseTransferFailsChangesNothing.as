// A holder accept policy that takes a fresh item (the seed) and refuses any item already linked to a world item, so every
// return of the world item's own item is refused.
class UMars_AutoTestHelper_HolderRefusesLinkedItems : UObject
{
    UFUNCTION()
    void OnCanAccept(FCk_Handle_Inventory InInventory, FCk_Handle_Item InItem, bool& OutCanAccept)
    { OutCanAccept = InItem.Has_PersistentWorldItem() == false; }
}

// The WorldItem entity script with that policy on its holder.
class UMars_AutoTestHelper_WorldItem_RefusingHolder : UMars_WorldItem_EntityScript
{
    protected FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic Get_HolderAcceptPolicy() const override
    {
        TSubclassOf<UMars_AutoTestHelper_HolderRefusesLinkedItems> PolicyClass = UMars_AutoTestHelper_HolderRefusesLinkedItems;
        return FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(PolicyClass.GetDefaultObject(), n"OnCanAccept");
    }
}

// A release whose transfer is refused changes nothing. A backpack world item whose holder refuses its item once it is
// linked is put on (its holder -> the backpack slot: Carried on the Back, Kinematic, its pickup disabled). A release then
// asks the backpack slot to hand the item back; the holder refuses, CkInventory rolls the transfer back, and the world item
// ensures ("it stays mounted") and changes nothing: the release is drained and nothing is left pending, it is still Carried
// by the carrier on the Back node and settled, its body Kinematic, its pickup disabled, its item in the backpack slot, and
// OnMountChanged never fired again. The rollback's warning and the ensure are expected (the actor below). Isolated origin
// (50000, -12000, -30000).
class UMars_AutoTest_WorldItem_AReleaseWhoseTransferFailsChangesNothing : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(50000.0, -12000.0, -30000.0);
    private const FVector k_PackOffset = FVector(200.0, 0.0, 0.0);

    private FCk_Handle_WorldItem _Pack;
    private FCk_Handle_Item _Item;
    private int32 _MountChanges = 0;
    private TArray<EMars_WorldItem_ReleaseRefusal> _ReleaseRefusals;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);

        Spawn_Floor(InHandle, k_Origin + k_PackOffset);
        auto SpawnParams = UMars_WorldItem_EntityScript::Params();
        SpawnParams.Definition = mars_items::Backpack();
        SpawnParams.Mode = EMars_WorldItem_Mode::World;
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin + k_PackOffset + FVector(0.0, 0.0, 20.0));
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_AutoTestHelper_WorldItem_RefusingHolder, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnPackConstructed"));

        Add_Step_WaitUntil("the backpack is constructed and its item linked", n"Check_Linked", 0, 0);
        Add_Step("put it on: its holder -> the backpack slot", n"Step_Wear");
        Add_Step_WaitUntil("it settles Carried on the Back", n"Check_Worn", 0, 0);
        Add_Step("mounted, Kinematic, its pickup disabled; release it", n"Step_AssertWornAndRelease");
        Add_Step_WaitUntil("the release's transfer is refused and answered", n"Check_ReleaseRefused", 0, 0);
        Add_Step("nothing changed", n"Step_AssertUnchanged");
        Run_Steps(InHandle);
    }

    // A static slab whose top is at InTop.
    private void Spawn_Floor(FCk_Handle InOwner, FVector InTop)
    {
        auto Owner = InOwner;
        auto Floor = utils_entity_lifetime::Request_CreateEntity(Owner);
        utils_transform::Add(Floor, FTransform(FRotator::ZeroRotator, InTop - FVector(0.0, 0.0, 1.0)), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(80.0, 80.0, 1.0));
        auto FloorSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        FloorSpec.Set_ShapeDimensions(Shape);
        FloorSpec.Set_MotionType(ECk_MotionType::Static);
        FloorSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Floor, FloorSpec);
    }

    UFUNCTION()
    private void OnPackConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _Pack = InEntityScriptHandle.As_WorldItem();
        _Pack.BindTo_OnMountChanged(FMars_Delegate_WorldItem_OnMountChanged(this, n"OnMountChanged"));
        _Pack.BindTo_OnReleaseRefused(FMars_Delegate_WorldItem_OnReleaseRefused(this, n"OnReleaseRefused"));
    }

    UFUNCTION()
    private void OnMountChanged(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InPrev, EMars_WorldItem_Mount InNew)
    {
        ++_MountChanges;
    }

    UFUNCTION()
    private void OnReleaseRefused(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_ReleaseRefusal InReason)
    {
        _ReleaseRefusals.Add(InReason);
    }

    // The transfer's answer reached the world item: it refused the release because the transfer failed.
    UFUNCTION()
    private void Check_ReleaseRefused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ReleaseRefusals.Contains(EMars_WorldItem_ReleaseRefusal::TransferFailed));
    }

    UFUNCTION()
    private void Check_Linked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Pack) && ck::IsValid(_Pack.Get_Item()));
    }

    UFUNCTION()
    private void Step_Wear(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Item = _Pack.Get_Item();
        auto Holder = _Pack.Get_Holder();
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(_Item, _Hotbar.Get_BackpackSlot()),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }

    UFUNCTION()
    private void Check_Worn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Pack.Get_Mount() == EMars_WorldItem_Mount::Carried && _Pack.Get_IsSettled());
    }

    UFUNCTION()
    private void Step_AssertWornAndRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Mounted("worn");
        Assert_Equals_Int(_MountChanges, 1, "one mount change: World -> Carried");

        _Pack.Request_Release(FMars_Request_WorldItem_Release(FVector(0.0, 0.0, 50.0), FVector::ZeroVector));
    }

    UFUNCTION()
    private void Step_AssertUnchanged(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Pack.Has_Fragment(FMars_Fragment_WorldItem_Requests), "the release was drained");
        Assert_False(_Pack.Has_Fragment(FMars_Fragment_WorldItem_PendingRelease), "no release is left pending");
        Assert_False(_Pack.Has_Fragment(FMars_Fragment_WorldItem_PendingLaunch), "no launch is pending");
        Assert_Mounted("after the refused release");
        Assert_True(_Pack.Get_IsSettled(), "it still reads settled");
        Assert_True(_Hotbar.Get_BackpackItem() == _Item, "the item is back in the backpack slot");
        Assert_Equals_Int(_Pack.Get_Holder().Get_NumItems(), 0, "the holder stayed empty");
        Assert_Equals_Int(_MountChanges, 1, "no mount change since");
    }

    private void Assert_Mounted(const FString& InWhen)
    {
        Assert_True(_Pack.Get_Mount() == EMars_WorldItem_Mount::Carried && _Pack.Get_Carrier() == _Carrier,
            f"{InWhen}: Carried by the carrier (got [{_Pack.Get_Mount() :n}])");
        Assert_True(Get_MountParent() == _BackNode, f"{InWhen}: attached to the Back node");
        Assert_True(utils_jolt_body::Get_MotionType(_Pack.Get_Body()) == ECk_MotionType::Kinematic, f"{InWhen}: the body is Kinematic");
        Assert_True(_Pack.Get_Pickup().Get_EnableDisable() == ECk_EnableDisable::Disable, f"{InWhen}: the pickup is disabled");
    }

    // Invalid while the world item is not scene-node attached.
    private FCk_Handle_Transform Get_MountParent() const
    {
        auto Node = _Pack.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return FCk_Handle_Transform(); }

        return utils_scene_node::Get_Parent(Node);
    }
}

// Hand-authored so CkInventory's rollback Warning for the refused return (the automation controller elevates Warnings to
// test errors) and the release's own ensure are expected rather than failures. Pinned to the item definition and the
// refusal reason, and to the release's message, so an unrelated refusal or ensure still fails the test.
class AMars_AutoTest_WorldItem_AReleaseWhoseTransferFailsChangesNothing_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_WorldItem_AReleaseWhoseTransferFailsChangesNothing;
    default _TimeoutSeconds = 20.0f;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("(Mars_ItemDef_Backpack))] (Failed Rejected by Custom Acceptance Logic)");
        Out.Add("it stays mounted");
        return Out;
    }
}
