// The world-item net tests' shared steps. The server waits for the spawn owner, lays a static floor (its own: a client
// builds no body, so it needs none) and spawns World-mode rocks on it under the spawn owner. A carrier (a hand node, its
// attach point, a hotbar, HeldItem and HeldItemUse) is composed on the subject on both machines, as the pawn composes
// them. The server's rest pose reaches the client through a test-only replicated fragment on the subject: the two PIE
// worlds share nothing else the test may read. Each test places its floor at its own X.
//
// A Persistent fixture (the rock's ball, carried on the Belt) and the steps its tests share: the server spawns it like a
// rock; each machine records the OnMountChanged its own copy raises and measures its root against a node and offset.

// Immutable test input: a Persistent one-item body with distinct carry and held offsets, so a pose check can tell the
// mounts apart.
asset Mars_TestItemDef_NetPersistentRock of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Persistent rock fixture"));
    auto Presentation = mars_items::Add_BlockoutTraits(this, mars_items::Make_BallBlockout(FVector(0.3, 0.3, 0.3)));
    Presentation.Mounting.Persistence = EMars_WorldItem_Persistence::Persistent;
    Presentation.Mounting.CarryPoint = GameplayTags::AttachPoint_Mars_Belt;
    Presentation.Mounting.CarryOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 12.0, -8.0));
    Presentation.Mounting.HeldOffset = FTransform(FRotator::ZeroRotator, FVector(6.0, 0.0, -10.0));
}

namespace mars_test_world_item
{
    UCk_InventoryItem_Definition NetPersistentRock() { return Mars_TestItemDef_NetPersistentRock; }
}

// Written by the server only, through Get_Fragment + Request_MarkReplicationDirty (test-only: a feature's processors are
// the only writers in game code).
struct FMars_Fragment_TESTONLY_NetWorldItemReport
{
    UPROPERTY()
    FVector RestLocation = FVector::ZeroVector;

    UPROPERTY()
    int32 Serial = 0;
}

// What Compose_Carrier built on the subject.
struct FMars_TESTONLY_NetCarrier
{
    FCk_Handle_Transform Hand;
    FCk_Handle_Transform Belt;
    FCk_Handle_Hotbar Hotbar;
    FCk_Handle_HeldItem HeldItem;
    FCk_Handle_HeldItemUse Use;
}

UCLASS(Abstract)
class UMars_AutoTestRig_NetWorldItem : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 15.0f;

    protected const int32 k_SlowPolls = 5000;
    protected const float32 k_ServerHoldSeconds = 2.0f;
    // A rock moving less than this a frame for k_StillFrames frames rests.
    protected const float64 k_StillCmPerFrame = 0.15;
    protected const int32 k_StillFrames = 10;
    protected const float64 k_FloorHalfExtent = 800.0;
    protected const FVector k_BeltFromHand = FVector(0.0, 40.0, -60.0);

    protected FCk_Handle _Rock;
    // Every OnMountChanged this machine's copy raised since Record_MountChanges, the new mount of each.
    protected TArray<EMars_WorldItem_Mount> _MountChanges;
    private TOptional<FVector> _LastRockLocation;
    private int32 _StillCount = 0;

    UFUNCTION()
    protected void Is_ReplicatedSpawnOwnerPublished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()));
    }

    // Composed on the subject on both machines; a second call on the same subject adds nothing.
    protected void Add_Report()
    {
        auto Subject = Get_SubjectEntity();
        if (Subject.Has_Fragment(FMars_Fragment_TESTONLY_NetWorldItemReport) == false)
        { Subject.Add_Fragment(FMars_Fragment_TESTONLY_NetWorldItemReport(), ECk_Replication::Replicates); }
    }

    protected void Write_Report(FVector InRestLocation)
    {
        auto Subject = Get_SubjectEntity();
        auto& Report = Subject.Get_Fragment(FMars_Fragment_TESTONLY_NetWorldItemReport);
        Report.RestLocation = InRestLocation;
        Report.Serial += 1;
        Subject.Request_MarkReplicationDirty(FMars_Fragment_TESTONLY_NetWorldItemReport);
    }

    protected FMars_Fragment_TESTONLY_NetWorldItemReport Get_Report()
    {
        return Get_SubjectEntity().Get_Fragment(FMars_Fragment_TESTONLY_NetWorldItemReport);
    }

    // A static floor whose top is at InTop, under InTestEntity (it dies with the test).
    protected void Spawn_ServerFloor(FCk_Handle InTestEntity, FVector InTop)
    {
        auto Owner = InTestEntity;
        auto Slab = utils_entity_lifetime::Request_CreateEntity(Owner);
        utils_transform::Add(Slab, FTransform(FRotator::ZeroRotator, InTop - FVector(0.0, 0.0, 10.0)), ECk_Replication::DoesNotReplicate);

        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(k_FloorHalfExtent, k_FloorHalfExtent, 10.0));
        auto SlabSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        SlabSpec.Set_ShapeDimensions(Shape);
        SlabSpec.Set_MotionType(ECk_MotionType::Static);
        SlabSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Slab, SlabSpec);
    }

    // A World-mode rock under the replicated spawn owner, seeded on the server, tracked for cleanup.
    protected FCk_Handle Spawn_ServerRock(FVector InLocation)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Spec = FMars_WorldItem_WorldSpec(utils_held_item::Make_DefinitionSoft(mars_items::Rock()), FTransform(FRotator::ZeroRotator, InLocation));
        auto Rock = utils_world_item::Request_SpawnWorld(Owner, Spec);
        Track_ForCleanup(Rock);
        return Rock;
    }

    // A Persistent fixture under the replicated spawn owner, seeded on the server, tracked for cleanup.
    protected FCk_Handle Spawn_ServerPersistent(FVector InLocation)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Spec = FMars_WorldItem_WorldSpec(utils_held_item::Make_DefinitionSoft(mars_test_world_item::NetPersistentRock()),
            FTransform(FRotator::ZeroRotator, InLocation));
        auto Body = utils_world_item::Request_SpawnWorld(Owner, Spec);
        Track_ForCleanup(Body);
        return Body;
    }

    protected void Record_MountChanges(FCk_Handle_WorldItem InWorldItem)
    {
        auto WorldItem = InWorldItem;
        _MountChanges.Empty();
        WorldItem.BindTo_OnMountChanged(FMars_Delegate_WorldItem_OnMountChanged(this, n"OnRecordedMountChanged"));
    }

    UFUNCTION()
    private void OnRecordedMountChanged(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InPrev, EMars_WorldItem_Mount InNew)
    {
        _MountChanges.Add(InNew);
    }

    protected FString Describe_MountChanges() const
    {
        auto Text = FString();
        for (const auto Mount : _MountChanges)
        { Text += f"{Mount :n} "; }

        return Text;
    }

    // How far InEntity's root is from where InNode composed with InOffset puts it, in cm.
    protected float64 Get_PoseError(FCk_Handle InEntity, FCk_Handle_Transform InNode, FTransform InOffset)
    {
        const auto Expected = InOffset * utils_transform::Get_EntityCurrentTransform(InNode);
        return (Get_RootLocation(InEntity) - Expected.GetLocation()).Size();
    }

    // This machine's Visual-mode world items anywhere under the subject's world.
    protected int32 Get_VisualWorldItemCount()
    {
        auto Count = 0;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            auto WorldItem = Candidate.As_WorldItem(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(WorldItem) && WorldItem.Get_Mode() == EMars_WorldItem_Mode::Visual)
            { Count += 1; }
        }

        return Count;
    }

    // This machine's World-mode world items within InRadius of InNear in X and Y.
    protected int32 Get_WorldItemCountNear(FVector InNear, float64 InRadius)
    {
        auto Count = 0;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            auto WorldItem = Candidate.As_WorldItem(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(WorldItem) || WorldItem.Get_Mode() != EMars_WorldItem_Mode::World)
            { continue; }

            const auto Location = Get_RootLocation(Candidate);
            if (FVector2D(Location.X - InNear.X, Location.Y - InNear.Y).Size() < InRadius)
            { Count += 1; }
        }

        return Count;
    }

    // A hand node (a transform of its own at InHandLocation) and a belt node beside it, their attach points, a hotbar of
    // InBagSlots bag slots and the overflow (no backpack slot), HeldItem and HeldItemUse, on the subject.
    protected FMars_TESTONLY_NetCarrier Compose_Carrier(FVector InHandLocation, int32 InBagSlots)
    {
        auto Subject = Get_SubjectEntity();
        auto Carrier = FMars_TESTONLY_NetCarrier();

        auto HandEntity = utils_entity_lifetime::Request_CreateEntity(Subject);
        Carrier.Hand = utils_transform::Add(HandEntity, FTransform(FRotator::ZeroRotator, InHandLocation), ECk_Replication::DoesNotReplicate);

        auto BeltEntity = utils_entity_lifetime::Request_CreateEntity(Subject);
        Carrier.Belt = utils_transform::Add(BeltEntity, FTransform(FRotator::ZeroRotator, InHandLocation + k_BeltFromHand), ECk_Replication::DoesNotReplicate);

        auto Points = FMars_AttachPoints_Spec();
        Points.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Hand, Carrier.Hand));
        Points.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Belt, Carrier.Belt));
        utils_attach_points::Add(Subject, Points);

        auto HotbarSpec = FMars_Hotbar_Spec();
        HotbarSpec.BagSlotCount = InBagSlots;
        HotbarSpec.BackpackSlot = ECk_EnableDisable::Disable;
        Carrier.Hotbar = utils_hotbar::Add(Subject, HotbarSpec);
        Carrier.HeldItem = utils_held_item::Add(Subject);
        Carrier.Use = utils_held_item_use::Add(Subject);
        return Carrier;
    }

    // The carrier's hotbar has adopted every slot root on this machine (call after Compose_Carrier, from a WaitUntil).
    protected bool Get_IsCarrierReady(const FMars_TESTONLY_NetCarrier& InCarrier) const
    {
        return ck::IsValid(InCarrier.Hotbar) && InCarrier.Hotbar.Get_IsReady();
    }

    // Server: one rock straight into InSlot. The hotbar must be ready (Get_IsCarrierReady).
    protected void Seed_ServerSlot(FCk_Handle_Hotbar InHotbar, int32 InSlot)
    {
        auto Slot = InHotbar.Get_Slot(InSlot);
        auto Request = FCk_Request_Inventory_AddItemByDefinition(mars_items::Rock(), 1);
        Request.Set_Policy(ECk_Inventory_AddPolicy::ForceNewItem);
        Slot.Request_AddItemByDefinition(Request, FCk_Delegate_Inventory_OnOperationResult_AddByDefinition());
    }

    // This machine's World-mode world item within 300 cm of InNear in X and Y; invalid while none has arrived.
    protected FCk_Handle_WorldItem Find_WorldItemNear(FVector InNear)
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            auto WorldItem = Candidate.As_WorldItem(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(WorldItem) || WorldItem.Get_Mode() != EMars_WorldItem_Mode::World)
            { continue; }

            const auto Location = Get_RootLocation(Candidate);
            if (FVector2D(Location.X - InNear.X, Location.Y - InNear.Y).Size() < 300.0)
            { return WorldItem; }
        }

        return FCk_Handle_WorldItem();
    }

    protected FVector Get_RootLocation(FCk_Handle InEntity)
    {
        return utils_transform::Get_EntityCurrentTransform(InEntity.As_Transform()).GetLocation();
    }

    protected int32 Get_HolderCount(FCk_Handle_WorldItem InWorldItem)
    {
        auto Holder = InWorldItem.Get_Holder();
        if (ck::Is_NOT_Valid(Holder))
        { return 0; }

        return Holder.Get_NumItems();
    }

    // Call once per frame from a predicate: true once _Rock has moved less than k_StillCmPerFrame for k_StillFrames frames.
    protected bool Tick_RockStill()
    {
        if (ck::Is_NOT_Valid(_Rock) || _Rock.Has_Fragment(FMars_Feature_WorldItem) == false)
        { return false; }

        const auto Location = Get_RootLocation(_Rock);
        const auto IsStill = _LastRockLocation.IsSet() && _LastRockLocation.GetValue().Equals(Location, k_StillCmPerFrame);
        _StillCount = IsStill ? _StillCount + 1 : 0;
        _LastRockLocation = TOptional<FVector>(Location);
        return _StillCount >= k_StillFrames;
    }

    protected void Reset_RockStill()
    {
        _LastRockLocation.Reset();
        _StillCount = 0;
    }
}
