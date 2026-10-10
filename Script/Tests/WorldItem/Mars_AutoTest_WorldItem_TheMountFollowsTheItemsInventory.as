// The mount follows the inventory its item lives in, moved by transfers and selection only: no request names a mount. A
// carrier (Hand and Back nodes, a hotbar with one bag slot) puts on a backpack (its holder -> the backpack slot: Carried on
// the Back), takes a meat slab into its empty hands (its holder -> bag slot 0, selected: Held on the Hand), lowers it
// (deselected: Carried on the Back), raises it (selected: Held), stows it in the worn pack (bag slot 0 -> cargo slot 0:
// Carried on the slot), takes a platter into the overflow (Held) and docks it (the overflow -> the dock's inventory:
// Carried on the dock). Each leg heads for its mount within three frames of the move (a pending mount, or the commit, names
// the mount and its carrier), then settles (Get_IsSettled) on the right node. Isolated origin (46800, -12000, -30000).
class UMars_AutoTest_WorldItem_TheMountFollowsTheItemsInventory : UMars_AutoTestRig_PlatterDock
{
    default _TimeoutSeconds = 40.0f;

    private const FVector k_Origin = FVector(46800.0, -12000.0, -30000.0);
    private const FVector k_PackOffset = FVector(200.0, -150.0, 0.0);
    private const FVector k_SlabOffset = FVector(200.0, 150.0, 0.0);
    private const FVector k_PlatterOffset = FVector(200.0, 400.0, 0.0);
    private const FVector k_StationOffset = FVector(0.0, 300.0, 0.0);
    // Polls of the heading wait, one a frame, from the move to the first that sees the new mount.
    private const int32 k_MaxPollsToHead = 3;
    private const int32 k_LegCount = 7;
    // The slab's and the platter's construction (their joints import) outrun the default poll budget at lane frame
    // rate.
    private const int32 k_SlowPolls = 900;

    private FCk_Handle _PackEntity;
    private FCk_Handle_WorldItem _Pack;
    private FCk_Handle_CargoSlot _CargoSlot;
    private FCk_Handle _SlabEntity;
    private FCk_Handle_WorldItem _Slab;
    private FCk_Handle_PlatterDock _Dock;

    // The leg under way: its item, where it must end, and the polls it took to head there.
    private int32 _Leg = 0;
    private FCk_Handle_WorldItem _Subject;
    private EMars_WorldItem_Mount _ExpectedMount = EMars_WorldItem_Mount::World;
    private FCk_Handle _ExpectedCarrier;
    private FCk_Handle_Transform _ExpectedParent;
    private int32 _LegPolls = 0;
    private TOptional<int32> _HeadedAtPoll;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);

        Spawn_Floor(InHandle, k_Origin + k_PackOffset);
        auto PackParams = UMars_Backpack_EntityScript::Params();
        PackParams.Definition = mars_items::Backpack();
        PackParams.Mode = EMars_WorldItem_Mode::World;
        PackParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin + k_PackOffset + FVector(0.0, 0.0, 20.0));
        _PackEntity = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Backpack_EntityScript, PackParams).Get_EntityUnderConstruction();

        Spawn_Floor(InHandle, k_Origin + k_SlabOffset);
        auto SlabParams = UMars_FoodItem_EntityScript::Params();
        SlabParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin + k_SlabOffset + FVector(0.0, 0.0, 5.0));
        SlabParams.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Food_MeatSlab());
        SlabParams.Mode = EMars_WorldItem_Mode::World;

        // A piece outlives its spawner: under the world's transient entity, tracked for cleanup.
        _SlabEntity = utils_entity_script::Request_SpawnEntity(ck::TransientEntity(), UMars_FoodItem_EntityScript, SlabParams).Get_EntityUnderConstruction();
        Track_ForCleanup(_SlabEntity);

        Spawn_Platter(InHandle, FMars_Platter_SpawnSpec(FTransform(FRotator::ZeroRotator, k_Origin + k_PlatterOffset)));
        auto Root = Build_StationRoot(InHandle, k_Origin + k_StationOffset);
        _Dock = Build_Dock(Root, Make_DockSpec(Make_Policy(TOptional<FGameplayTag>(), false),
            FTransform(FRotator::ZeroRotator, FVector(0.0, 60.0, 70.0)), "input platter"));

        Add_Step_WaitUntil("the pack, the slab and the platter are constructed, their items linked", n"Check_Constructed", k_SlowPolls, 0);
        for (int32 Leg = 0; Leg < k_LegCount; ++Leg)
        {
            Add_Step(f"leg {Leg}: move", n"Step_Move");
            Add_Step_WaitUntil(f"leg {Leg}: it heads for its mount", n"Check_Headed", 0, 0);
            Add_Step(f"leg {Leg}: headed within {k_MaxPollsToHead} frames of the move", n"Step_AssertHeaded");
            Add_Step_WaitUntil(f"leg {Leg}: it settles", n"Check_Settled", 0, 0);
            Add_Step(f"leg {Leg}: the mount, its carrier and its node", n"Step_AssertLanded");
        }
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
    private void Check_Constructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        // Resolves the platter's handles once it is constructed; the pack and the slab decide the rest.
        Check_PlattersConstructed(InHandle, OutResult, InPayload);
        const auto PlatterReady = _Platters.Num() == 1 && ck::IsValid(_WorldItems[0].Get_Item());

        const auto PackReady = ck::IsValid(_PackEntity) && _PackEntity.Is_Backpack() && _PackEntity.Is_WorldItem()
            && ck::IsValid(_PackEntity.As_WorldItem().Get_Item());
        const auto SlabReady = ck::IsValid(_SlabEntity) && _SlabEntity.Is_WorldItem() && ck::IsValid(_SlabEntity.As_WorldItem().Get_Item());
        if (PackReady && SlabReady && ck::Is_NOT_Valid(_Pack))
        {
            _Pack = _PackEntity.As_WorldItem();
            _CargoSlot = _PackEntity.As_Backpack().Get_CargoSlot(0);
            _Slab = _SlabEntity.As_WorldItem();
        }

        auto Res = OutResult;
        Res.Set(PlatterReady && PackReady && SlabReady);
    }

    UFUNCTION()
    private void Step_Move(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _LegPolls = 0;
        _HeadedAtPoll.Reset();
        FCk_Handle SlotEntity = _CargoSlot;
        FCk_Handle DockEntity = _Dock;
        const auto Overflow = _Hotbar.Get_Slot(_Hotbar.Get_OverflowIndex());

        if (_Leg == 0)
        {
            _Subject = _Pack;
            _ExpectedMount = EMars_WorldItem_Mount::Carried;
            _ExpectedCarrier = _Carrier;
            _ExpectedParent = _BackNode;
            Move(_Pack.Get_Holder(), _Pack.Get_Item(), _Hotbar.Get_BackpackSlot());
        }
        else if (_Leg == 1)
        {
            _Subject = _Slab;
            _ExpectedMount = EMars_WorldItem_Mount::Held;
            _ExpectedCarrier = _Carrier;
            _ExpectedParent = _HandNode;
            Move(_Slab.Get_Holder(), _Slab.Get_Item(), _Hotbar.Get_Slot(0));
        }
        else if (_Leg == 2)
        {
            _ExpectedMount = EMars_WorldItem_Mount::Carried;
            _ExpectedParent = _BackNode;
            _Hotbar.Request_Deselect();
        }
        else if (_Leg == 3)
        {
            _ExpectedMount = EMars_WorldItem_Mount::Held;
            _ExpectedParent = _HandNode;
            _Hotbar.Request_Select(FMars_Request_Hotbar_Select(0));
        }
        else if (_Leg == 4)
        {
            _ExpectedMount = EMars_WorldItem_Mount::Carried;
            _ExpectedCarrier = SlotEntity;
            _ExpectedParent = SlotEntity.As_Transform();
            Move(_Hotbar.Get_Slot(0), _Slab.Get_Item(), _CargoSlot.Get_Inventory());
        }
        else if (_Leg == 5)
        {
            _Subject = _WorldItems[0];
            _ExpectedMount = EMars_WorldItem_Mount::Held;
            _ExpectedCarrier = _Carrier;
            _ExpectedParent = _HandNode;
            Move(_WorldItems[0].Get_Holder(), _PlatterItems[0], Overflow);
        }
        else
        {
            _ExpectedMount = EMars_WorldItem_Mount::Carried;
            _ExpectedCarrier = DockEntity;
            _ExpectedParent = _Dock.Get_Node();
            Move(Overflow, _PlatterItems[0], _Dock.Get_Inventory());
        }
    }

    private void Move(FCk_Handle_Inventory_DataOnly InFrom, FCk_Handle_Item InItem, FCk_Handle_Inventory_DataOnly InTo)
    {
        if (ck::Is_NOT_Valid(InFrom) || ck::Is_NOT_Valid(InItem) || ck::Is_NOT_Valid(InTo))
        {
            FinishFailure(f"leg {_Leg}: a move needs a source, an item and a target");
            return;
        }

        auto From = InFrom;
        From.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(InItem, InTo),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnMoveAnswered"));
    }

    UFUNCTION()
    private void OnMoveAnswered(FCk_Handle_Inventory InSource,
                                FCk_Handle_Item InItem,
                                FCk_Handle_Inventory InTarget,
                                int32 InCount,
                                FCk_Handle_Item InNewItemInTarget,
                                ECk_Inventory_OperationResult_Transfer InResult)
    {
        if (InResult != ECk_Inventory_OperationResult_Transfer::Success)
        { FinishFailure(f"leg {_Leg}: the transfer failed with [{InResult :n}]"); }
    }

    UFUNCTION()
    private void Check_Headed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        ++_LegPolls;
        const auto Heading = Get_Heading(_Subject);
        const auto IsHeaded = Heading.Mount == _ExpectedMount && Heading.Carrier == _ExpectedCarrier;
        if (IsHeaded && _HeadedAtPoll.IsSet() == false)
        { _HeadedAtPoll = TOptional<int32>(_LegPolls); }

        auto Res = OutResult;
        Res.Set(IsHeaded);
    }

    UFUNCTION()
    private void Step_AssertHeaded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_HeadedAtPoll.IsSet() && _HeadedAtPoll.GetValue() <= k_MaxPollsToHead,
            f"leg {_Leg}: it headed for [{_ExpectedMount :n}] within {k_MaxPollsToHead} frames of the move (frame {_LegPolls})");
    }

    UFUNCTION()
    private void Check_Settled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Subject.Get_IsSettled());
    }

    UFUNCTION()
    private void Step_AssertLanded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Subject.Get_Mount() == _ExpectedMount,
            f"leg {_Leg}: mounted [{_Subject.Get_Mount() :n}], expected [{_ExpectedMount :n}]");
        Assert_True(_Subject.Get_Carrier() == _ExpectedCarrier,
            f"leg {_Leg}: carried by [{_Subject.Get_Carrier().ToString()}], expected [{_ExpectedCarrier.ToString()}]");
        Assert_True(Get_MountParent(_Subject) == _ExpectedParent, f"leg {_Leg}: it hangs off the expected node");
        ++_Leg;
    }

    // Where the item is going: the pending mount's target while one waits on the body, else the committed mount.
    private FMars_WorldItem_MountTarget Get_Heading(FCk_Handle_WorldItem InWorldItem) const
    {
        if (InWorldItem.Has_Fragment(FMars_Fragment_WorldItem_PendingMount))
        { return InWorldItem.Get_Fragment(FMars_Fragment_WorldItem_PendingMount).Target; }

        return InWorldItem.Get_Fragment(FMars_Fragment_WorldItem).Committed;
    }
}
