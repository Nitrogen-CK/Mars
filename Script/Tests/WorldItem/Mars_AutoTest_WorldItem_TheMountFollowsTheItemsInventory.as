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
    // The slab's and the platter's construction (their joints import) outrun the default poll budget at lane frame
    // rate.
    private const int32 k_SlowPolls = 900;

    private FCk_Handle _PackEntity;
    private FCk_Handle_WorldItem _Pack;
    private FCk_Handle_CargoSlot _CargoSlot;
    private FCk_Handle _SlabEntity;
    private FCk_Handle_WorldItem _Slab;
    private FCk_Handle_PlatterDock _Dock;

    // The leg under way: its name, its item, where it must end, and the polls it took to head there.
    private FString _Leg;
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

        Spawn_FloorSlab(InHandle, k_Origin + k_PackOffset);
        auto PackParams = UMars_Backpack_EntityScript::Params();
        PackParams.Definition = mars_items::Backpack();
        PackParams.Mode = EMars_WorldItem_Mode::World;
        PackParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin + k_PackOffset + FVector(0.0, 0.0, 20.0));
        _PackEntity = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Backpack_EntityScript, PackParams).Get_EntityUnderConstruction();

        _SlabEntity = Spawn_FoodItemOnFloor(InHandle, mars_items::Food_MeatSlab(), k_Origin + k_SlabOffset);

        Spawn_Platter(InHandle, FMars_Platter_SpawnSpec(FTransform(FRotator::ZeroRotator, k_Origin + k_PlatterOffset)));
        auto Root = Build_StationRoot(InHandle, k_Origin + k_StationOffset);
        _Dock = Build_Dock(Root, Make_DockSpec(Make_Policy(TOptional<FGameplayTag>(), false),
            FTransform(FRotator::ZeroRotator, FVector(0.0, 60.0, 70.0)), "input platter"));

        Add_Step_WaitUntil("the pack, the slab and the platter are constructed, their items linked", n"Check_Constructed", k_SlowPolls, 0);
        Add_LegSteps("put the pack on (Carried on the Back)", n"Step_Leg_WearThePack");
        Add_LegSteps("take the slab into the hands (Held on the Hand)", n"Step_Leg_TakeTheSlab");
        Add_LegSteps("lower the slab (Carried on the Back)", n"Step_Leg_LowerTheSlab");
        Add_LegSteps("raise the slab (Held on the Hand)", n"Step_Leg_RaiseTheSlab");
        Add_LegSteps("stow the slab in the pack (Carried on the slot)", n"Step_Leg_StowTheSlab");
        Add_LegSteps("take the platter into the overflow (Held on the Hand)", n"Step_Leg_TakeThePlatter");
        Add_LegSteps("dock the platter (Carried on the dock)", n"Step_Leg_DockThePlatter");
        Run_Steps(InHandle);
    }

    // InMoveStep moves the item and names the leg's expected mount, carrier and node.
    private void Add_LegSteps(const FString& InLeg, FName InMoveStep)
    {
        Add_Step(f"{InLeg}: move", InMoveStep);
        Add_Step_WaitUntil(f"{InLeg}: it heads for its mount", n"Check_Headed", 0, 0);
        Add_Step(f"{InLeg}: headed within {k_MaxPollsToHead} frames of the move", n"Step_AssertHeaded");
        Add_Step_WaitUntil(f"{InLeg}: it settles", n"Check_Settled", 0, 0);
        Add_Step(f"{InLeg}: the mount, its carrier and its node", n"Step_AssertLanded");
    }

    UFUNCTION()
    private void Check_Constructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        // Resolves the platter's handles once it is constructed; the pack and the slab decide the rest.
        Check_PlattersConstructed(InHandle, OutResult, InPayload);
        const auto PlatterReady = _Platters.Num() == 1 && ck::IsValid(_WorldItems[0].Get_Item());

        const auto PackReady = ck::IsValid(_PackEntity) && _PackEntity.Is_Backpack() && _PackEntity.Is_WorldItem()
            && ck::IsValid(_PackEntity.As_WorldItem().Get_Item());
        const auto Slab = TryGet_ConstructedWorldItem(_SlabEntity);
        const auto SlabReady = ck::IsValid(Slab) && ck::IsValid(Slab.Get_Item());
        if (PackReady && SlabReady && ck::Is_NOT_Valid(_Pack))
        {
            _Pack = _PackEntity.As_WorldItem();
            _CargoSlot = _PackEntity.As_Backpack().Get_CargoSlot(0);
            _Slab = Slab;
        }

        auto Res = OutResult;
        Res.Set(PlatterReady && PackReady && SlabReady);
    }

    UFUNCTION()
    private void Step_Leg_WearThePack(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Begin_Leg("the pack", _Pack);
        Expect(EMars_WorldItem_Mount::Carried, _Carrier, _BackNode);
        Move(_Pack.Get_Holder(), _Pack.Get_Item(), _Hotbar.Get_BackpackSlot());
    }

    UFUNCTION()
    private void Step_Leg_TakeTheSlab(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Begin_Leg("the slab taken", _Slab);
        Expect(EMars_WorldItem_Mount::Held, _Carrier, _HandNode);
        Move(_Slab.Get_Holder(), _Slab.Get_Item(), _Hotbar.Get_Slot(0));
    }

    UFUNCTION()
    private void Step_Leg_LowerTheSlab(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Begin_Leg("the slab lowered", _Slab);
        Expect(EMars_WorldItem_Mount::Carried, _Carrier, _BackNode);
        _Hotbar.Request_Deselect(FMars_Request_Hotbar_Deselect());
    }

    UFUNCTION()
    private void Step_Leg_RaiseTheSlab(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Begin_Leg("the slab raised", _Slab);
        Expect(EMars_WorldItem_Mount::Held, _Carrier, _HandNode);
        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(0));
    }

    UFUNCTION()
    private void Step_Leg_StowTheSlab(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Begin_Leg("the slab stowed", _Slab);
        FCk_Handle SlotEntity = _CargoSlot;
        Expect(EMars_WorldItem_Mount::Carried, SlotEntity, SlotEntity.As_Transform());
        Move(_Hotbar.Get_Slot(0), _Slab.Get_Item(), _CargoSlot.Get_Inventory());
    }

    UFUNCTION()
    private void Step_Leg_TakeThePlatter(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Begin_Leg("the platter taken", _WorldItems[0]);
        Expect(EMars_WorldItem_Mount::Held, _Carrier, _HandNode);
        Move(_WorldItems[0].Get_Holder(), _PlatterItems[0], _Hotbar.Get_Slot(_Hotbar.Get_OverflowIndex()));
    }

    UFUNCTION()
    private void Step_Leg_DockThePlatter(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Begin_Leg("the platter docked", _WorldItems[0]);
        FCk_Handle DockEntity = _Dock;
        Expect(EMars_WorldItem_Mount::Carried, DockEntity, _Dock.Get_Node());
        Move(_Hotbar.Get_Slot(_Hotbar.Get_OverflowIndex()), _PlatterItems[0], _Dock.Get_Inventory());
    }

    private void Begin_Leg(const FString& InLeg, FCk_Handle_WorldItem InSubject)
    {
        _Leg = InLeg;
        _Subject = InSubject;
        _LegPolls = 0;
        _HeadedAtPoll.Reset();
    }

    private void Expect(EMars_WorldItem_Mount InMount, FCk_Handle InCarrier, FCk_Handle_Transform InParent)
    {
        _ExpectedMount = InMount;
        _ExpectedCarrier = InCarrier;
        _ExpectedParent = InParent;
    }

    private void Move(FCk_Handle_Inventory_DataOnly InFrom, FCk_Handle_Item InItem, FCk_Handle_Inventory_DataOnly InTo)
    {
        if (ck::Is_NOT_Valid(InFrom) || ck::Is_NOT_Valid(InItem) || ck::Is_NOT_Valid(InTo))
        {
            FinishFailure(f"{_Leg}: a move needs a source, an item and a target");
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
        { FinishFailure(f"{_Leg}: the transfer failed with [{InResult :n}]"); }
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
            f"{_Leg}: it headed for [{_ExpectedMount :n}] within {k_MaxPollsToHead} frames of the move (frame {_LegPolls})");
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
            f"{_Leg}: mounted [{_Subject.Get_Mount() :n}], expected [{_ExpectedMount :n}]");
        Assert_True(_Subject.Get_Carrier() == _ExpectedCarrier,
            f"{_Leg}: carried by [{_Subject.Get_Carrier().ToString()}], expected [{_ExpectedCarrier.ToString()}]");
        Assert_True(Get_MountParent(_Subject) == _ExpectedParent, f"{_Leg}: it hangs off the expected node");
    }

    // Where the item is going: the pending mount's target while one waits on the body, else the committed mount.
    private FMars_WorldItem_MountTarget Get_Heading(FCk_Handle_WorldItem InWorldItem) const
    {
        if (InWorldItem.Has_Fragment(FMars_Fragment_WorldItem_PendingMount))
        { return InWorldItem.Get_Fragment(FMars_Fragment_WorldItem_PendingMount).Target; }

        return InWorldItem.Get_Fragment(FMars_Fragment_WorldItem).Committed;
    }
}
