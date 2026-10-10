struct FMars_AutoTest_PlatterDock_Docked
{
    FCk_Handle_PlatterDock Dock;
    FCk_Handle_Platter Platter;
}

struct FMars_AutoTest_PlatterDock_Refusal
{
    FCk_Handle_PlatterDock Dock;
    FCk_Handle_Item Item;
    EMars_PlatterDock_Refusal Refusal = EMars_PlatterDock_Refusal::Occupied;
}

// The PlatterDock rig, on the carrier rig (the test entity is a carrier with a Hand node; tests add the hotbar and HeldItem
// they need). A station root is a plain Transform entity under the test; docks are created on it with their three signals
// recorded. Platters are spawned as World-mode platter world items under the test, each lying on a static floor of its own
// (a platter drops what it is given only while it lies still), and resolved once constructed; box pieces live under the
// world's transient entity, tracked for cleanup.
UCLASS(Abstract)
class UMars_AutoTestRig_PlatterDock : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 20.0f;

    // Spawned platter entities, under construction until each is a WorldItem and a Platter whose holder holds its item.
    protected TArray<FCk_Handle> _PlatterEntities;
    // Resolved by Check_PlattersConstructed, in spawn order.
    protected TArray<FCk_Handle_Item> _PlatterItems;
    protected TArray<FCk_Handle_Platter> _Platters;
    protected TArray<FCk_Handle_WorldItem> _WorldItems;

    protected TArray<FMars_AutoTest_PlatterDock_Docked> _Docked;
    protected TArray<FMars_AutoTest_PlatterDock_Docked> _Arrived;
    protected TArray<FMars_AutoTest_PlatterDock_Docked> _Undocked;
    protected TArray<FMars_AutoTest_PlatterDock_Refusal> _DockRefused;

    private UMars_AutoTestHelper_FoodOnPlatter _FoodOnPlatter;

    // A plain Transform entity under the test: what a station's root is to its docks.
    protected FCk_Handle_Transform Build_StationRoot(FCk_Handle InHandle, FVector InOrigin)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        return utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, InOrigin), ECk_Replication::DoesNotReplicate);
    }

    protected FCk_Handle_PlatterDock Build_Dock(FCk_Handle_Transform InRoot, FMars_PlatterDock_Spec InSpec)
    {
        auto Root = InRoot;
        auto Dock = utils_platter_dock::Create(Root, InSpec);
        Dock.BindTo_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnDockDocked"));
        Dock.BindTo_OnArrived(FMars_Delegate_PlatterDock_OnArrived(this, n"OnDockArrived"));
        Dock.BindTo_OnUndocked(FMars_Delegate_PlatterDock_OnUndocked(this, n"OnDockUndocked"));
        Dock.BindTo_OnDockRefused(FMars_Delegate_PlatterDock_OnDockRefused(this, n"OnDockRefusedItem"));
        return Dock;
    }

    // An Input dock named InName at InMountLocal under InPolicy.
    protected FMars_PlatterDock_Spec Make_DockSpec(FMars_PlatterDock_Policy InPolicy, FTransform InMountLocal, FString InName) const
    {
        auto Spec = FMars_PlatterDock_Spec(EMars_PlatterDock_Role::Input, InPolicy, InMountLocal);
        Spec.Name = FText::FromString(InName);
        return Spec;
    }

    // Kind = InKind (none = any), WholeOnly = InWholeOnly; the optional caps are set on the result.
    protected FMars_PlatterDock_Policy Make_Policy(TOptional<FGameplayTag> InKind, bool InWholeOnly) const
    {
        auto Kind = FGameplayTagQuery();
        if (InKind.IsSet())
        { Kind = FGameplayTagQuery::MakeQuery_MatchTag(InKind.GetValue()); }

        return FMars_PlatterDock_Policy(Kind, InWholeOnly);
    }

    // InFoodItem's whole joint loaded onto the InPlatterIndex-th spawned platter (the kernel path: no hand); the food item
    // spawns at InWorld (above the platter: the drop poses it) and is tracked for cleanup.
    protected void Spawn_FoodOnto(int32 InPlatterIndex, UCk_InventoryItem_Definition InFoodItem, FVector InWorld)
    {
        if (ck::Is_NOT_Valid(_FoodOnPlatter))
        { _FoodOnPlatter = Cast<UMars_AutoTestHelper_FoodOnPlatter>(NewObject(this, UMars_AutoTestHelper_FoodOnPlatter)); }

        Track_ForCleanup(_FoodOnPlatter.Spawn_Onto(_PlatterEntities[InPlatterIndex], InFoodItem, FTransform(FRotator::ZeroRotator, InWorld)));
    }

    // A World-mode platter lying on a floor whose top is InSpec.World's Z (its pivot, the inner floor, sits the tray's base
    // above it); resolved by Check_PlattersConstructed.
    protected void Spawn_Platter(FCk_Handle InOwner, FMars_Platter_SpawnSpec InSpec)
    {
        auto Owner = InOwner;
        const auto FloorTop = InSpec.World.GetLocation();
        auto Floor = utils_entity_lifetime::Request_CreateEntity(Owner);
        utils_transform::Add(Floor, FTransform(FRotator::ZeroRotator, FloorTop - FVector(0.0, 0.0, 1.0)), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(45.0, 45.0, 1.0));
        auto FloorSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        FloorSpec.Set_ShapeDimensions(Shape);
        FloorSpec.Set_MotionType(ECk_MotionType::Static);
        FloorSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Floor, FloorSpec);

        auto Spec = InSpec;
        Spec.World = FTransform(InSpec.World.Rotator(), FloorTop + FVector(0.0, 0.0, constants_platter::k_FloorAboveBase + 0.5));
        _PlatterEntities.Add(utils_platter::Request_SpawnWorld(Owner, Spec));
    }

    // The FoodPiece rig's box fixture (a CPU-readable 1000 cm3 cube) with no kind: Transform, RuntimeMesh and FoodPiece on a
    // new entity under the world's transient entity, tracked for cleanup.
    protected FCk_Handle_FoodPiece Build_Box(FTransform InWorld)
    {
        auto Spec = FMars_FoodPiece_Spec();
        Spec.Data.MassKg = 0.8;
        Spec.Tuners = FMars_FoodPiece_Tuners(0.0001, 0.05);

        auto Entity = utils_entity_lifetime::Request_CreateEntity(ck::TransientEntity());
        Track_ForCleanup(Entity);
        utils_transform::Add(Entity, InWorld, ECk_Replication::DoesNotReplicate);
        utils_runtime_mesh::Add(Entity, FCk_RuntimeMesh_Spec(
            TSoftObjectPtr<UStaticMesh>(FSoftObjectPath("/CkTests/CkRuntimeMesh/Cooked/SM_Import_CPU.SM_Import_CPU"))));
        return utils_foodpiece::Add(Entity, Spec);
    }

    protected void Dock(FCk_Handle_PlatterDock InDock, FCk_Handle_Item InItem)
    {
        auto PlatterDock = InDock;
        PlatterDock.Request_Dock(FMars_Request_PlatterDock_Dock(InItem));
    }

    protected void Undock(FCk_Handle_PlatterDock InDock, FCk_Handle_Item InItem, FCk_Handle_Inventory_DataOnly InTarget)
    {
        auto PlatterDock = InDock;
        PlatterDock.Request_Undock(FMars_Request_PlatterDock_Undock(InItem, InTarget));
    }

    // What the pickup task does for a Persistent item: transfer into the hotbar's stow target, then Carry once it reports.
    protected void Stow_Platter(int32 InIndex)
    {
        auto Item = _PlatterItems[InIndex];
        auto Target = _Hotbar.TryGet_StowTarget(Item);
        if (ck::Is_NOT_Valid(Target) || Target != _Hotbar.Get_Slot(_Hotbar.Get_OverflowIndex()))
        {
            FinishFailure("stow precondition: the platter's stow target is the overflow slot");
            return;
        }

        auto Holder = _WorldItems[InIndex].Get_Holder();
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(Item, Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnPlatterStowComplete"));
    }

    // The node a world item's root hangs off; invalid while it is not scene-node attached.
    protected FCk_Handle_Transform Get_MountParent(FCk_Handle_WorldItem InWorldItem) const
    {
        auto Node = InWorldItem.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return FCk_Handle_Transform(); }

        return utils_scene_node::Get_Parent(Node);
    }

    protected FTransform Get_World(FCk_Handle InEntity) const
    {
        FCk_Handle Entity = InEntity;
        return utils_transform::Get_EntityCurrentTransform(Entity.As_Transform());
    }

    protected int32 Get_DockedCount(FCk_Handle_PlatterDock InDock) const
    {
        auto Count = 0;
        for (const auto& Event : _Docked)
        {
            if (Event.Dock == InDock)
            { ++Count; }
        }

        return Count;
    }

    protected int32 Get_ArrivedCount(FCk_Handle_PlatterDock InDock) const
    {
        auto Count = 0;
        for (const auto& Event : _Arrived)
        {
            if (Event.Dock == InDock)
            { ++Count; }
        }

        return Count;
    }

    protected int32 Get_UndockedCount(FCk_Handle_PlatterDock InDock) const
    {
        auto Count = 0;
        for (const auto& Event : _Undocked)
        {
            if (Event.Dock == InDock)
            { ++Count; }
        }

        return Count;
    }

    // The refusals InDock broadcast, in order.
    protected TArray<FMars_AutoTest_PlatterDock_Refusal> Get_Refusals(FCk_Handle_PlatterDock InDock) const
    {
        TArray<FMars_AutoTest_PlatterDock_Refusal> Refusals;
        for (const auto& Event : _DockRefused)
        {
            if (Event.Dock == InDock)
            { Refusals.Add(Event); }
        }

        return Refusals;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Check_PlattersConstructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllConstructed = true;
        for (const auto& Entity : _PlatterEntities)
        {
            const auto IsConstructed = ck::IsValid(Entity) && Entity.Is_WorldItem() && Entity.Is_Platter();
            AllConstructed = AllConstructed && IsConstructed && ck::IsValid(Entity.As_WorldItem().Get_HeldItem());
        }

        if (AllConstructed && _Platters.Num() == 0)
        {
            for (const auto& Entity : _PlatterEntities)
            {
                _WorldItems.Add(Entity.As_WorldItem());
                _Platters.Add(Entity.As_Platter());
                _PlatterItems.Add(Entity.As_WorldItem().Get_HeldItem());
            }
        }

        auto Res = OutResult;
        Res.Set(AllConstructed);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnPlatterStowComplete(FCk_Handle_Inventory InSource,
                                       FCk_Handle_Item InItem,
                                       FCk_Handle_Inventory InTarget,
                                       int32 InCount,
                                       FCk_Handle_Item InNewItemInTarget,
                                       ECk_Inventory_OperationResult_Transfer InResult)
    {
        if (InResult != ECk_Inventory_OperationResult_Transfer::Success)
        {
            FinishFailure(f"the platter's stow transfer failed with [{InResult :n}]");
            return;
        }

        auto WorldItem = InItem.Get_PersistentWorldItem();
        WorldItem.Request_Carry(FMars_Request_WorldItem_Carry(_Carrier));
    }

    UFUNCTION()
    private void OnDockDocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        auto Event = FMars_AutoTest_PlatterDock_Docked();
        Event.Dock = InDock;
        Event.Platter = InPlatter;
        _Docked.Add(Event);
    }

    UFUNCTION()
    private void OnDockArrived(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        auto Event = FMars_AutoTest_PlatterDock_Docked();
        Event.Dock = InDock;
        Event.Platter = InPlatter;
        _Arrived.Add(Event);
        On_Arrived(InDock, InPlatter);
    }

    // A test's hook into the frame a dock reports its platter landed.
    protected void On_Arrived(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
    }

    UFUNCTION()
    private void OnDockUndocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        auto Event = FMars_AutoTest_PlatterDock_Docked();
        Event.Dock = InDock;
        Event.Platter = InPlatter;
        _Undocked.Add(Event);
    }

    UFUNCTION()
    private void OnDockRefusedItem(FCk_Handle_PlatterDock InDock, FCk_Handle_Item InItem, EMars_PlatterDock_Refusal InRefusal)
    {
        auto Event = FMars_AutoTest_PlatterDock_Refusal();
        Event.Dock = InDock;
        Event.Item = InItem;
        Event.Refusal = InRefusal;
        _DockRefused.Add(Event);
    }
}
