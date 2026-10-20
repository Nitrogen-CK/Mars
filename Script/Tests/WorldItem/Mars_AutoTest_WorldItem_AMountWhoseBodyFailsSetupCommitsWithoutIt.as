// A Persistent world item whose body fails setup still mounts. The item is composed by hand on the backpack's definition
// (Persistent, carried on the Back): a box body whose spec names a collision profile that does not exist (its setup fails
// InvalidProfile, a framework ensure), a holder seeded with the backpack item and linked to the world item, a pickup with
// no target, then the WorldItem feature. Its item moved into the carrier's backpack slot, the mount commits without the
// body, since there is nothing to make Kinematic (with an ensure naming the body's setup): the item is Carried by the
// carrier, attached to its Back node, nothing is left pending, and OnMountChanged reports World -> Carried once. Both
// ensures are expected (the actor below).
class UMars_AutoTest_WorldItem_AMountWhoseBodyFailsSetupCommitsWithoutIt : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 10.0f;

    private const FVector k_Origin = FVector(40000.0, -35000.0, -30000.0);
    private const FVector k_ItemOffset = FVector(200.0, 0.0, 0.0);
    private const FVector k_BodyHalfExtents = FVector(15.0, 15.0, 15.0);
    private const float32 k_BodyMassKg = 2.0f;

    private FCk_Handle_WorldItem _WorldItem;
    private FCk_Handle_JoltBody _Body;
    private FCk_Handle_Inventory_DataOnly _Holder;
    // In parallel: one entry per OnMountChanged.
    private TArray<EMars_WorldItem_Mount> _MountsFrom;
    private TArray<EMars_WorldItem_Mount> _MountsTo;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);
        auto Owner = InHandle;
        Compose_Item(Owner);

        Add_Step_WaitUntil("the item's body setup failed and its holder holds the linked item", n"Check_BodyFailedAndLinked", 0, 0);
        Add_Step("move the item into the carrier's backpack slot", n"Step_Stow");
        Add_Step_WaitUntil("the item is Carried on the Back node", n"Check_Carried", 0, 0);
        Add_Step("committed without the body: nothing pending, one World -> Carried", n"Step_AssertCommitted");
        Run_Steps(InHandle);
    }

    // The shape of a World-mode entity script's composition (UMars_WorldItem_EntityScript), by hand.
    private void Compose_Item(FCk_Handle& InOwner)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InOwner);
        auto Root = utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, k_Origin + k_ItemOffset), ECk_Replication::DoesNotReplicate);

        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(k_BodyHalfExtents);
        auto BodySpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BodySpec.Set_ShapeDimensions(Shape);
        BodySpec.Set_MotionType(ECk_MotionType::Dynamic);
        BodySpec.Set_MassSource(ECk_JoltBody_MassSource::Explicit);
        BodySpec.Set_MassKg(k_BodyMassKg);
        BodySpec.Set_CollisionProfileName(n"Mars_Test_NoSuchProfile");
        _Body = utils_jolt_body::Add(Entity, BodySpec);

        auto HolderParams = utils_inventory_data_only::Make_Params_Bounded(
            GameplayTags::Inventory_Mars_WorldItemHolder, 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(),
            FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        HolderParams.Set_StackingPolicy(ECk_Inventory_StackingPolicy::NoStacking);
        _Holder = utils_inventory_data_only::Add(Entity, HolderParams, ECk_Replication::DoesNotReplicate);

        auto Composition = FMars_WorldItem_Composition();
        Composition.Body = _Body;
        Composition.BodyProfile = n"Mars_Test_NoSuchProfile";
        Composition.BoundsFit = FMars_WorldItem_BoundsFit(k_BodyHalfExtents, FVector::ZeroVector);

        auto Spec = FMars_WorldItem_Spec();
        Spec.Mode = EMars_WorldItem_Mode::World;
        Spec.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Backpack());
        Spec.World = TOptional<FMars_WorldItem_WorldParts>(
            FMars_WorldItem_WorldParts(_Holder, utils_interactable::Create(Root, FMars_Interactable_Spec()), Composition));
        _WorldItem = utils_world_item::Add(Entity, Spec);
        _WorldItem.BindTo_OnMountChanged(FMars_Delegate_WorldItem_OnMountChanged(this, n"OnMountChanged"));

        auto Request = FCk_Request_Inventory_AddItemByDefinition(mars_items::Backpack(), 1);
        Request.Set_Policy(ECk_Inventory_AddPolicy::ForceNewItem);
        _Holder.Request_AddItemByDefinition(Request, FCk_Delegate_Inventory_OnOperationResult_AddByDefinition(this, n"OnSeeded"));
    }

    // What the entity script does once its holder holds the seeded item.
    UFUNCTION()
    private void OnSeeded(FCk_Handle_Inventory InInventory,
                          ECk_Inventory_OperationResult_AddByDefinition InResult,
                          int InAmountAdded,
                          const TArray<FCk_Handle_Item>&in InItemsCreated)
    {
        if (InResult != ECk_Inventory_OperationResult_AddByDefinition::Success_AllAdded || InItemsCreated.Num() != 1)
        {
            FinishFailure(f"seeding the holder failed with [{InResult :n}]");
            return;
        }

        utils_world_item::Add_Item(_WorldItem, InItemsCreated[0]);
    }

    UFUNCTION()
    private void Check_BodyFailedAndLinked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_jolt_body::Get_SetupState(_Body) == ECk_JoltBody_SetupState::Failed && ck::IsValid(_WorldItem.Get_Item()));
    }

    UFUNCTION()
    private void Step_Stow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_jolt_body::Get_SetupFailure(_Body) == ECk_JoltBody_SetupFailure::InvalidProfile,
            f"the body failed for its collision profile (got {utils_jolt_body::Get_SetupFailure(_Body) :n})");
        Assert_True(_WorldItem.Get_Persistence() == EMars_WorldItem_Persistence::Persistent, "the item is Persistent");
        Assert_True(_WorldItem.Get_Mount() == EMars_WorldItem_Mount::World, "the item starts in the World");

        _Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(_WorldItem.Get_Item(), _Hotbar.Get_BackpackSlot()),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }

    UFUNCTION()
    private void Check_Carried(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_WorldItem.Get_Mount() == EMars_WorldItem_Mount::Carried && Get_MountParent(_WorldItem) == _BackNode);
    }

    UFUNCTION()
    private void Step_AssertCommitted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_WorldItem.Get_Carrier() == _Carrier, "the carrier carries it");
        Assert_False(_WorldItem.Has_Fragment(FMars_Fragment_WorldItem_PendingMount), "no mount is left pending");
        Assert_False(_WorldItem.Get_AppliedBodyProfile().IsSet(), "no profile was asked of the failed body");
        Assert_Equals_Int(_MountsTo.Num(), 1, "OnMountChanged fired once");
        if (_MountsTo.Num() == 1)
        {
            Assert_True(_MountsFrom[0] == EMars_WorldItem_Mount::World && _MountsTo[0] == EMars_WorldItem_Mount::Carried,
                f"it reported World -> Carried (got {_MountsFrom[0] :n} -> {_MountsTo[0] :n})");
        }
    }

    UFUNCTION()
    private void OnMountChanged(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InPrev, EMars_WorldItem_Mount InNew)
    {
        _MountsFrom.Add(InPrev);
        _MountsTo.Add(InNew);
    }
}

// Hand-authored so the framework's ensure for the missing collision profile and the mount's own ensure are expected rather
// than failures.
class AMars_AutoTest_WorldItem_AMountWhoseBodyFailsSetupCommitsWithoutIt_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_WorldItem_AMountWhoseBodyFailsSetupCommitsWithoutIt;
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("collision profile [Mars_Test_NoSuchProfile] does not exist in UCollisionProfile");
        Out.Add("it mounts without the body");
        return Out;
    }
}
