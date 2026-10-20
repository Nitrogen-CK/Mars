// The player's tasks a carrier with gloves runs: the Use row -> resolver intent and its interaction, the held-item -> gloves
// link and the Hands sub-SM.
class UMars_AutoTestState_CarrierHands : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_UseIntentToResolver);
        AddTask(InHandle, UMars_SmTask_HeldItemDrivesHands);
        AddTask(InHandle, UMars_SmTask_HandsSubSm);
    }
}

// An attach point a carrier body publishes beside its Hand: the point's tag and its node's offset from the body's root.
struct FMars_AutoTestHelper_CarrierPoint
{
    FGameplayTag Point;
    FVector Offset;

    FMars_AutoTestHelper_CarrierPoint() {}

    FMars_AutoTestHelper_CarrierPoint(FGameplayTag InPoint, FVector InOffset)
    {
        Point = InPoint;
        Offset = InOffset;
    }
}

// A carrier body: its root's location and the attach points it publishes beside the Hand (AttachPoint.Mars.Hand).
struct FMars_AutoTestHelper_CarrierBody
{
    FVector Location;
    TArray<FMars_AutoTestHelper_CarrierPoint> ExtraPoints;

    FMars_AutoTestHelper_CarrierBody() {}

    FMars_AutoTestHelper_CarrierBody(FVector InLocation)
    {
        Location = InLocation;
    }
}

// The nodes a carrier body was built with: the Hand, then one per extra point in the body's order.
struct FMars_AutoTestHelper_CarrierNodes
{
    FCk_Handle_Transform Hand;
    TArray<FCk_Handle_Transform> Extra;
}

// Where a carrier transfers a holder's item: the hotbar's stow target (what the pickup task does) or its take target.
enum EMars_AutoTestHelper_CarrierTransfer
{
    Stow,
    Take
}

// The item-carrier tests' rig (Hotbar, Interactable, Backpack, WorldItem): a Hotbar on the test entity, one-slot holders
// seeded from item definitions, the pickup task's stow and the take into the hotbar, the carrier's body for the tests whose
// carrier holds or wears what it picks up, and its gloves for the tests that place what it holds. HeldItem follows the
// hotbar on its own (UMars_Processor_HeldItem_Sync).
UCLASS(Abstract)
class UMars_AutoTestRig_Carrier : UCk_AutoTest_Base
{
    protected FCk_Handle _Carrier;
    protected FCk_Handle_Transform _HandNode;
    protected FCk_Handle_Transform _BackNode;
    protected FCk_Handle_Hotbar _Hotbar;
    protected FCk_Handle_HeldItem _HeldItem;
    // Valid after Add_CarrierHands.
    protected FCk_Handle_FPHands _Hands;
    // Every phase the gloves entered since Add_CarrierHands, in order.
    protected TArray<EMars_FPHands_Phase> _HandPhases;
    // The interact targets Check_AwaitedFocus waits to see Focused (named by Await_FocusOf in the step that focuses them).
    protected TArray<FCk_Handle_InteractTarget> _AwaitedFocus;
    protected TArray<FCk_Handle_Inventory_DataOnly> _Holders;
    // The holders' items in holder order, recorded by Check_HoldersSeeded once every holder is seeded.
    protected TArray<FCk_Handle_Item> _Items;
    private UMars_AutoTestHelper_CookingFixture _CookingFixture;

    // The test entity is the carrier, rooted at InLocation, with a Hand node published as AttachPoint.Mars.Hand.
    protected void Add_CarrierBody(FCk_Handle InHandle, FVector InLocation)
    {
        _Carrier = InHandle;
        _HandNode = Build_CarrierBody(_Carrier, FMars_AutoTestHelper_CarrierBody(InLocation)).Hand;
    }

    // Add_CarrierBody with a Back node as well, published as AttachPoint.Mars.Back.
    protected void Add_CarrierBodyWithBack(FCk_Handle InHandle, FVector InLocation)
    {
        auto Body = FMars_AutoTestHelper_CarrierBody(InLocation);
        Body.ExtraPoints.Add(Get_BackPoint());

        _Carrier = InHandle;
        const auto Nodes = Build_CarrierBody(_Carrier, Body);
        _HandNode = Nodes.Hand;
        _BackNode = Nodes.Extra[0];
    }

    // The Back attach point where every test carrier wears it.
    protected FMars_AutoTestHelper_CarrierPoint Get_BackPoint() const
    {
        return FMars_AutoTestHelper_CarrierPoint(GameplayTags::AttachPoint_Mars_Back, FVector(-30.0, 0.0, 20.0));
    }

    // InEntity's root at InBody's location, a Hand node and InBody's extra nodes, each published as its attach point.
    protected FMars_AutoTestHelper_CarrierNodes Build_CarrierBody(FCk_Handle InEntity, FMars_AutoTestHelper_CarrierBody InBody)
    {
        auto Entity = InEntity;
        auto Root = utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, InBody.Location), ECk_Replication::DoesNotReplicate);

        auto Nodes = FMars_AutoTestHelper_CarrierNodes();
        Nodes.Hand = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(40.0, 20.0, 60.0))).As_Transform();

        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Hand, Nodes.Hand));
        for (const auto& Extra : InBody.ExtraPoints)
        {
            const auto Node = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, Extra.Offset)).As_Transform();
            Nodes.Extra.Add(Node);
            AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(Extra.Point, Node));
        }

        utils_attach_points::Add(Entity, AttachPointsSpec);
        return Nodes;
    }

    // The carrier's gloves (InSpec on its Hand node), a Use resolver and InputIntents (no matcher: nothing presses), and
    // the player's tasks over them (UMars_AutoTestState_CarrierHands): the Use intent task, the held-item -> gloves link and
    // the Hands sub-SM, whose resolver binds listen as the player's do. A test starts its interactions on the targets
    // itself; the interactions' own tasks ask the gloves for their reaches. After Add_CarrierBody*.
    protected void Add_CarrierHands(FMars_FPHands_Spec InSpec = FMars_FPHands_Spec())
    {
        auto Spec = InSpec;
        Spec.HandNode = _HandNode;
        _Hands = utils_fphands::Add(_Carrier, Spec);
        utils_interaction_resolver::Add(_Carrier, mars_test_interaction::Make_UseResolverSpec(), ECk_Replication::DoesNotReplicate);
        utils_input_intents::Add(_Carrier);
        utils_state_machine::Add(_Carrier, FCk_StateMachine_Spec(UMars_AutoTestState_CarrierHands));
        _Hands.BindTo_OnPhaseChanged(FMars_Delegate_FPHands_OnPhaseChanged(this, n"OnCarrierHandsPhaseChanged"));
    }

    // Check_AwaitedFocus waits for every target of InInteractable (focused by the calling step) to enter Focused.
    protected void Await_FocusOf(FCk_Handle_Interactable InInteractable)
    {
        for (auto Target : InInteractable.Get_AllInteractTargets())
        { _AwaitedFocus.Add(Target); }
    }

    // Every awaited target's state machine is Focused; the awaited list empties once it holds.
    UFUNCTION()
    protected void Check_AwaitedFocus(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllFocused = _AwaitedFocus.Num() > 0;
        for (auto Target : _AwaitedFocus)
        { AllFocused = AllFocused && utils_state_machine::Get_CurrentStateClass(Target.As_StateMachine()) == UMars_SmState_Interactable_Focused; }

        if (AllFocused)
        { _AwaitedFocus.Empty(); }

        auto Res = OutResult;
        Res.Set(AllFocused);
    }

    UFUNCTION()
    protected void OnCarrierHandsPhaseChanged(FCk_Handle_FPHands InHands, EMars_FPHands_Phase InPrevious, EMars_FPHands_Phase InNew)
    {
        _HandPhases.Add(InNew);
    }

    // The Hands state machine rests, listening for a reach.
    UFUNCTION()
    protected void Check_CarrierHandsRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Hands) && _Hands.Get_Phase() == EMars_FPHands_Phase::None
            && _Hands.Has_Fragment(FMars_Fragment_FPHands_Signals)
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachRequested._Inner.IsBound());
    }

    protected void Add_Hotbar(FCk_Handle InCarrier, int32 InBagSlotCount)
    {
        auto Carrier = InCarrier;
        auto Spec = FMars_Hotbar_Spec();
        Spec.BagSlotCount = InBagSlotCount;
        _Hotbar = utils_hotbar::Add(Carrier, Spec);
    }

    // The cooking fixtures (box piece, floors, platter on a floor), made on first use.
    protected UMars_AutoTestHelper_CookingFixture Get_CookingFixture()
    {
        if (ck::Is_NOT_Valid(_CookingFixture))
        { _CookingFixture = Cast<UMars_AutoTestHelper_CookingFixture>(NewObject(this, UMars_AutoTestHelper_CookingFixture)); }

        return _CookingFixture;
    }

    // A static BlockAll box centred at InCentre, a child of InOwner.
    protected FCk_Handle Spawn_StaticSlab(FCk_Handle InOwner, FVector InCentre, FVector InHalfExtents)
    {
        return Get_CookingFixture().Spawn_StaticSlab(InOwner, InCentre, InHalfExtents);
    }

    // A static 160 x 160 floor slab whose top is at InTop.
    protected FCk_Handle Spawn_FloorSlab(FCk_Handle InOwner, FVector InTop)
    {
        return Get_CookingFixture().Spawn_Floor(InOwner, InTop, 80.0);
    }

    // A floor slab whose top is at InTop and a World-mode food item of InItem dropped 5 uu onto it. The item outlives its
    // spawner (under the world's transient entity, tracked for cleanup); TryGet_ConstructedWorldItem resolves it.
    protected FCk_Handle Spawn_FoodItemOnFloor(FCk_Handle InOwner, UCk_InventoryItem_Definition InItem, FVector InTop)
    {
        Spawn_FloorSlab(InOwner, InTop);

        auto SpawnParams = UMars_FoodItem_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, InTop + FVector(0.0, 0.0, 5.0));
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(InItem);
        SpawnParams.Mode = EMars_WorldItem_Mode::World;

        auto Entity = utils_entity_script::Request_SpawnEntity(ck::TransientEntity(), UMars_FoodItem_EntityScript, SpawnParams)
            .Get_EntityUnderConstruction();
        Track_ForCleanup(Entity);
        return Entity;
    }

    // InEntity as a world item once it is constructed and its holder holds its item; invalid until then.
    protected FCk_Handle_WorldItem TryGet_ConstructedWorldItem(FCk_Handle InEntity) const
    {
        if (ck::Is_NOT_Valid(InEntity) || InEntity.Is_WorldItem() == false)
        { return FCk_Handle_WorldItem(); }

        const auto WorldItem = InEntity.As_WorldItem();
        if (ck::Is_NOT_Valid(WorldItem.Get_HeldItem()))
        { return FCk_Handle_WorldItem(); }

        return WorldItem;
    }

    // The node InWorldItem's root hangs off; invalid while it is not scene-node attached.
    protected FCk_Handle_Transform Get_MountParent(FCk_Handle_WorldItem InWorldItem) const
    {
        auto Node = InWorldItem.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return FCk_Handle_Transform(); }

        return utils_scene_node::Get_Parent(Node);
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
        TransferFrom(InHolder, EMars_AutoTestHelper_CarrierTransfer::Stow);
    }

    // What a take does: transfer into whatever the hotbar names as the take target for the item.
    protected void TakeFrom(FCk_Handle_Inventory_DataOnly InHolder)
    {
        TransferFrom(InHolder, EMars_AutoTestHelper_CarrierTransfer::Take);
    }

    // InHolder's one item into the hotbar's InTransfer target for it.
    private void TransferFrom(FCk_Handle_Inventory_DataOnly InHolder, EMars_AutoTestHelper_CarrierTransfer InTransfer)
    {
        auto Items = InHolder.Get_Items();
        auto Target = FCk_Handle_Inventory_DataOnly();
        if (Items.Num() == 1)
        {
            if (InTransfer == EMars_AutoTestHelper_CarrierTransfer::Stow)
            { Target = _Hotbar.TryGet_StowTarget(Items[0]); }
            else
            { Target = _Hotbar.TryGet_TakeTarget(Items[0]); }
        }

        if (ck::Is_NOT_Valid(Target) || Items.Num() != 1)
        {
            FinishFailure("transfer precondition: a valid stow or take target and a holder with one item");
            return;
        }

        auto Holder = InHolder;
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(Items[0], Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }

    // Every holder holds its one item; false while the test has seeded none.
    UFUNCTION()
    protected void Check_HoldersSeeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllSeeded = _Holders.Num() > 0;
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
