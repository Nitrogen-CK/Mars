// The hand-mount rows' shared steps, on the player-combat rig: the production AMars_PlayerCharacter on its floor, a Jolt
// slab for world items to rest on, items spawned in front of it and given to it by its own pickup request (the hotbar's
// arrival rule holds an item that lands while the hands are empty), and the hand mount (AttachPoint.Mars.Hand) read back.
// On a pawn nobody possesses the mount rides the body's grip_r (Player.BodyGrip); once the local player controller
// possesses it the mount is under the gloves' hand node for good.
// How many primitives of each kind an item's tree must hold (a skeletal book, a static shaft and head, ...).
struct FMars_AutoTest_PrimitiveKinds
{
    UPROPERTY()
    int32 StaticMeshes = 0;

    UPROPERTY()
    int32 SkeletalMeshes = 0;

    // Any other primitive (a flame's effect).
    UPROPERTY()
    int32 Others = 0;

    FMars_AutoTest_PrimitiveKinds() {}

    FMars_AutoTest_PrimitiveKinds(int32 InStaticMeshes, int32 InSkeletalMeshes)
    {
        StaticMeshes = InStaticMeshes;
        SkeletalMeshes = InSkeletalMeshes;
    }
}

UCLASS(Abstract)
class UMars_AutoTestRig_PlayerHand : UMars_AutoTestRig_PlayerCombat
{
    // Where an item is spawned for the pawn, from _Origin: in front of it, clear of the capsule, above the slab.
    protected const FVector k_ItemFromOrigin = FVector(120.0, 0.0, 20.0);

    protected FCk_Handle_WorldItem _WorldItem;
    // The item _WorldItem held when it was ready (its holder empties once the pawn picks it up).
    protected FCk_Handle_Item _Item;
    // Every item Spawn_Item asked for, in order.
    private TArray<FCk_Handle> _SpawnedItems;

    // The floor and the pawn (unpossessed), then the Jolt slab whose top is the floor's.
    protected void Spawn_PawnAndSlab(FCk_Handle InHandle)
    {
        SpawnFloorAndUnpossessedPawn(InHandle);
        SpawnJoltWall(_Origin - FVector(0.0, 0.0, 10.0), FVector(900.0, 900.0, 10.0));
    }

    // A World-mode item of InDefinition in front of the pawn, under the test entity (it ends with the test); _WorldItem once
    // it is composed (Check_ItemReady).
    protected void Spawn_Item(UCk_InventoryItem_Definition InDefinition)
    {
        auto Owner = _Self;
        auto Spec = FMars_WorldItem_WorldSpec(utils_held_item::Make_DefinitionSoft(InDefinition), FTransform(FRotator::ZeroRotator, _Origin + k_ItemFromOrigin));
        auto Entity = utils_world_item::Request_SpawnWorld(Owner, Spec);
        _SpawnedItems.Add(Entity);
        _WorldItem = FCk_Handle_WorldItem();
    }

    // The last spawned item is composed and holds its item, and the pawn's hotbar has adopted its slots (wait for the
    // pawn's entity first).
    UFUNCTION()
    protected void Check_ItemReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(false);
        if (_SpawnedItems.Num() == 0 || ck::Is_NOT_Valid(_Player))
        { return; }

        const auto Hotbar = _Player.As_Hotbar(ECk_SanityCheck::UnChecked);
        _WorldItem = _SpawnedItems[_SpawnedItems.Num() - 1].As_WorldItem(ECk_SanityCheck::UnChecked);
        _Item = ck::IsValid(_WorldItem) ? _WorldItem.Get_HeldItem() : FCk_Handle_Item();
        Result.Set(ck::IsValid(Hotbar) && Hotbar.Get_IsReady() && ck::IsValid(_Item));
    }

    // Empties the hands (nothing selected), then the pawn picks the last spawned item up: it lands in the first empty slot
    // and, the hands being empty, is held.
    UFUNCTION()
    protected void Step_GiveItem(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Hotbar = _Player.As_Hotbar();
        Hotbar.Request_SetSelection(FMars_Request_Hotbar_SetSelection(TOptional<int32>()));
        _WorldItem.Request_PickUp(FMars_Request_WorldItem_PickUp(_Player));
    }

    // The pawn's HeldItem holds _Item and its presentation (the persistent body, or the Visual-mode world item HeldItem
    // spawns for any other item, on every copy) is in the hand and settled.
    UFUNCTION()
    protected void Check_ItemHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsHeld = Get_IsItemHeld();
        _HeldPolls += 1;
        if (IsHeld == false && _HeldPolls % 240 == 0)
        { ck::Trace(f"[HandMount] waiting for the hold: {Describe_Hold()}"); }

        auto Result = OutResult;
        Result.Set(IsHeld);
    }

    private int32 _HeldPolls = 0;

    protected FString Describe_Hold()
    {
        const auto HeldItem = Get_HeldItem();
        const auto Hotbar = _Player.As_Hotbar(ECk_SanityCheck::UnChecked);
        const auto Selected = ck::IsValid(Hotbar) ? Hotbar.Get_SelectedIndex() : TOptional<int32>();
        const auto Current = ck::IsValid(HeldItem) ? HeldItem.Get_CurrentItem() : FCk_Handle_Item();
        const auto Wanted = _Item;
        const auto InHand = ck::IsValid(HeldItem) && HeldItem.Get_IsPresentationInHand();
        const auto Settled = ck::IsValid(HeldItem) && HeldItem.Get_IsPresentationSettled();
        const auto Mount = ck::IsValid(_WorldItem) ? _WorldItem.Get_Mount() : EMars_WorldItem_Mount::World;
        const auto Presentation = ck::IsValid(HeldItem) ? HeldItem.Get_PresentationEntity() : FCk_Handle();
        const auto SelectedIndex = Selected.IsSet() ? Selected.GetValue() : -1;
        const auto Refusal = ck::IsValid(_WorldItem) ? _WorldItem.Get_LastRefusal() : EMars_Interaction_FailReason::NowhereToStow;
        const auto RefusalSerial = ck::IsValid(_WorldItem) ? _WorldItem.Get_RefusalSerial() : -1;
        return f"selected={SelectedIndex} current={Current.ToString()} wanted={Wanted.ToString()} presentation={Presentation.ToString()} "
            + f"inHand={InHand} settled={Settled} mount={Mount :n} refusal={Refusal :n} refusals={RefusalSerial}";
    }

    protected bool Get_IsItemHeld()
    {
        const auto HeldItem = Get_HeldItem();
        if (ck::Is_NOT_Valid(HeldItem) || ck::Is_NOT_Valid(_Item))
        { return false; }

        const auto Item = HeldItem.Get_CurrentItem();
        if (ck::Is_NOT_Valid(Item) || Item != _Item)
        { return false; }

        return HeldItem.Get_IsPresentationInHand() && HeldItem.Get_IsPresentationSettled();
    }

    protected FCk_Handle_HeldItem Get_HeldItem()
    {
        return _Player.As_HeldItem(ECk_SanityCheck::UnChecked);
    }

    protected bool Get_IsPersistent(FCk_Handle_Item InItem)
    {
        return ck::IsValid(InItem) && InItem.Has_Presentation()
            && InItem.Get_Presentation().Mounting.Persistence == EMars_WorldItem_Persistence::Persistent;
    }

    //------------------------------------------------------------------------------------------------------------------
    // The hand mount
    //------------------------------------------------------------------------------------------------------------------

    protected FCk_Handle_Transform Get_Mount()
    {
        return _Pawn.Get_HandMount();
    }

    protected FCk_Handle_Transform Get_MountParent()
    {
        FCk_Handle MountEntity = Get_Mount();
        const auto SceneNode = MountEntity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(SceneNode))
        { return FCk_Handle_Transform(); }

        return utils_scene_node::Get_Parent(SceneNode);
    }

    protected FTransform Get_MountOffset()
    {
        FCk_Handle MountEntity = Get_Mount();
        const auto SceneNode = MountEntity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(SceneNode))
        { return FTransform::Identity; }

        return utils_scene_node::Get_Offset(SceneNode);
    }

    protected FTransform Get_MountWorld()
    {
        return utils_transform::Get_EntityCurrentTransform(Get_Mount());
    }

    protected FCk_Handle_Transform Get_GloveHandNode()
    {
        return _Player.As_FPHands().Get_HandNode();
    }

    protected FCk_Handle_Transform Get_BodyGripTransform()
    {
        return _Pawn.Get_BodyGrip().As_Transform();
    }

    // grip_r as the body draws it now, at unit scale.
    protected FTransform Get_UnscaledGripSocket()
    {
        const auto Socket = _Pawn.Mesh.GetSocketTransform(n"grip_r");
        return FTransform(Socket.GetRotation(), Socket.GetLocation(), FVector::OneVector);
    }

    // The gloves' layout with the body's palm (what the pawn derives the mount's body offset from).
    protected FMars_FPHands_Spec Make_BodyHandsSpec()
    {
        auto HandsSpec = _Pawn.Config.FPHands;
        HandsSpec.Rest.PalmSurfaceOffset = _Pawn.Config.TPBody.Hold.PalmSurfaceOffset;
        return HandsSpec;
    }

    protected FString Describe_Mount()
    {
        const auto Parent = Get_MountParent();
        const auto ParentName = Parent == Get_BodyGripTransform() ? "BodyGrip" : (Parent == Get_GloveHandNode() ? "HandNode" : Parent.ToString());
        return f"parent={ParentName} offset=[{Get_MountOffset()}] world=[{Get_MountWorld().GetLocation()}]";
    }

    //------------------------------------------------------------------------------------------------------------------
    // The item's primitives, found without the retag's own walk
    //------------------------------------------------------------------------------------------------------------------

    // The kinds the held item's tree must hold (each row names its item's).
    protected FMars_AutoTest_PrimitiveKinds _ItemKinds;

    // Every primitive the component host holds for an entity whose lifetime chain reaches InRoot: found from the host's
    // components back to their entities, not through utils_fphands::Get_TreePrimitives (the walk the retag uses and these
    // rows test). The host is the one the tree's first primitive is on; empty when the tree has none.
    protected TArray<UPrimitiveComponent> Get_HostedPrimitivesUnder(const FCk_Handle& InRoot)
    {
        TArray<UPrimitiveComponent> Hosted;
        const auto Tree = utils_fphands::Get_TreePrimitives(InRoot);
        if (Tree.Num() == 0 || ck::Is_NOT_Valid(Tree[0].GetOwner()))
        { return Hosted; }

        for (auto Component : Tree[0].GetOwner().GetComponentsByClass(UPrimitiveComponent))
        {
            auto Primitive = Cast<UPrimitiveComponent>(Component);
            const auto Handle = utils_unreal_component::TryGet_OwningHandle_FromComponent(Primitive);
            if (ck::Is_NOT_Valid(Primitive) || ck::Is_NOT_Valid(Handle))
            { continue; }

            FCk_Handle Entity = Handle;
            for (int32 Depth = 0; Depth < constants_fphands_view::k_MaxAttachDepth && ck::IsValid(Entity)
                && utils_entity_lifetime::Get_IsTransientEntity(Entity) == false; ++Depth)
            {
                if (Entity == InRoot)
                {
                    Hosted.Add(Primitive);
                    break;
                }

                Entity = utils_entity_lifetime::Get_LifetimeOwner(Entity);
            }
        }

        return Hosted;
    }

    // Every primitive hosted under InRoot (Get_HostedPrimitivesUnder) is drawn InType and is one the retag's walk finds, and
    // they hold at least _ItemKinds.
    protected void Assert_EveryHostedPrimitive(const FCk_Handle& InRoot, EFirstPersonPrimitiveType InType, const FString& InWhere)
    {
        const auto Tree = utils_fphands::Get_TreePrimitives(InRoot);
        const auto Hosted = Get_HostedPrimitivesUnder(InRoot);
        auto Found = FMars_AutoTest_PrimitiveKinds();
        auto Kinds = "";
        auto Wrong = "";
        auto Unwalked = "";
        for (auto Primitive : Hosted)
        {
            const auto Kind = Primitive.GetClass().GetName();
            Kinds += f"{Kind} ";
            if (Cast<USkeletalMeshComponent>(Primitive) != nullptr)
            { Found.SkeletalMeshes += 1; }
            else if (Cast<UStaticMeshComponent>(Primitive) != nullptr)
            { Found.StaticMeshes += 1; }
            else
            { Found.Others += 1; }

            if (Primitive.FirstPersonPrimitiveType != InType)
            { Wrong += f"{Primitive.GetName()}({Kind}: {Primitive.FirstPersonPrimitiveType :n}) "; }

            if (Tree.Contains(Primitive) == false)
            { Unwalked += f"{Primitive.GetName()}({Kind}) "; }
        }

        ck::Trace(f"[HandMount] {InWhere}: {Hosted.Num()} hosted, {Tree.Num()} walked [{Kinds}] wrong [{Wrong}] unwalked [{Unwalked}] {Describe_Mount()}");
        Assert_True(Found.StaticMeshes >= _ItemKinds.StaticMeshes && Found.SkeletalMeshes >= _ItemKinds.SkeletalMeshes
            && Found.Others >= _ItemKinds.Others,
            f"{InWhere}: the item's hosted primitives hold its kinds (static {Found.StaticMeshes}/{_ItemKinds.StaticMeshes}, "
            + f"skeletal {Found.SkeletalMeshes}/{_ItemKinds.SkeletalMeshes}, other {Found.Others}/{_ItemKinds.Others}: {Kinds})");
        Assert_True(Unwalked.IsEmpty(), f"{InWhere}: the retag's walk finds every hosted primitive (missed: {Unwalked})");
        Assert_True(Wrong.IsEmpty(), f"{InWhere}: every hosted primitive is {InType :n} (not: {Wrong})");
    }
}

// Samples how far a held item's root trails the body's grip_r: ticks in the last tick group (TG_LastDemotable, after the
// ECS's late pose pass in TG_PostUpdateWork: the body's pose is final and the item's transform is this frame's), so the
// gap it reads is the one the frame renders. Each sample is the root's distance from where the hand mount puts it on
// grip_r as it stands now (Expected: HeldOffset composed with the mount's body offset and the unscaled socket). It also
// records the root's plain distance from the socket and how far the socket itself moved since the last sample, the
// frame's travel to compare the gap with.
class AMars_AutoTestProbe_BodyHandLag : AActor
{
    AMars_PlayerCharacter Pawn;
    FCk_Handle_Transform ItemRoot;
    FTransform HeldOffset;
    bool IsSampling = false;

    float64 MaxGapCm = 0.0;
    float64 SumGapCm = 0.0;
    float64 MaxTravelCm = 0.0;
    float64 MaxFromSocketCm = 0.0;
    int32 Samples = 0;

    private FVector _LastSocket = FVector::ZeroVector;
    private bool _HasLastSocket = false;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        SetTickGroup(ETickingGroup::TG_LastDemotable);
    }

    void Reset_Samples()
    {
        MaxGapCm = 0.0;
        SumGapCm = 0.0;
        MaxTravelCm = 0.0;
        MaxFromSocketCm = 0.0;
        Samples = 0;
        _HasLastSocket = false;
    }

    float64 Get_MeanGapCm() const
    {
        return Samples > 0 ? SumGapCm / float64(Samples) : 0.0;
    }

    UFUNCTION(BlueprintOverride)
    void Tick(float DeltaSeconds)
    {
        if (IsSampling == false || ck::Is_NOT_Valid(Pawn) || ck::Is_NOT_Valid(ItemRoot))
        { return; }

        const auto Socket = Pawn.Mesh.GetSocketTransform(n"grip_r");
        const auto Grip = FTransform(Socket.GetRotation(), Socket.GetLocation(), FVector::OneVector);
        const auto Expected = HeldOffset * Pawn.Get_HandMountBodyOffset() * Grip;
        const auto Root = utils_transform::Get_EntityCurrentTransform(ItemRoot);
        const auto Gap = (Root.GetLocation() - Expected.GetLocation()).Size();
        MaxGapCm = Math::Max(MaxGapCm, Gap);
        MaxFromSocketCm = Math::Max(MaxFromSocketCm, (Root.GetLocation() - Socket.GetLocation()).Size());
        SumGapCm += Gap;
        Samples += 1;

        if (_HasLastSocket)
        { MaxTravelCm = Math::Max(MaxTravelCm, (Socket.GetLocation() - _LastSocket).Size()); }

        _LastSocket = Socket.GetLocation();
        _HasLastSocket = true;
    }
}

// The rebind rows: the unpossessed pawn holds _Definition (on the body every primitive of it is drawn as a world
// primitive), then the local player controller possesses it: the hand mount moves under the gloves and every primitive
// of the item, whatever its kind (static or skeletal mesh, a flame's card and effect), is drawn first-person, though the
// item's own mount never changed. The primitives are found from the component host (Assert_EveryHostedPrimitive), not by
// the walk the retag uses. Each subclass names the item, the kinds it must hold and an isolated origin.
UCLASS(Abstract)
class UMars_AutoTestRig_PlayerHandRebind : UMars_AutoTestRig_PlayerHand
{
    protected UCk_InventoryItem_Definition _Definition;

    protected void Run_Rebind(FCk_Handle InHandle)
    {
        Spawn_PawnAndSlab(InHandle);
        Spawn_Item(_Definition);

        Add_Step_WaitUntil("the unpossessed pawn's entity is linked and composed", n"Check_EntityComposed", k_SlowPolls, 0);
        Add_Step_WaitUntil("the item is composed", n"Check_ItemReady", k_SlowPolls, 0);
        Add_Step("the pawn picks the item up", n"Step_GiveItem");
        Add_Step_WaitUntil("the pawn holds the item, settled on the body's hand", n"Check_ItemHeld", k_SlowPolls, 0);
        Add_Step("on the body: every primitive of the item is a world primitive; possess", n"Step_AssertWorldAndPossess");
        Add_Step_WaitUntil("the mount moves under the gloves' hand node", n"Check_MountOnHandNode", k_SlowPolls, 0);
        Add_Step("in the hand: every primitive of the item is first-person", n"Step_AssertFirstPerson");
        Add_Step("tear down", n"Step_TearDown");
        Add_Step_WaitUntil("the player's entity is gone", n"Check_PlayerEntityGone", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertWorldAndPossess(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_MountParent() == Get_BodyGripTransform(), f"unpossessed: the mount rides BodyGrip ({Describe_Mount()})");
        Assert_EveryHostedPrimitive(_WorldItem, EFirstPersonPrimitiveType::None, "on the body");
        PossessPawn();
    }

    UFUNCTION()
    private void Check_MountOnHandNode(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_MountParent() == Get_GloveHandNode());
    }

    UFUNCTION()
    private void Step_AssertFirstPerson(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_WorldItem.Get_Mount() == EMars_WorldItem_Mount::Held, f"the item's own mount is still Held ({_WorldItem.Get_Mount() :n})");
        Assert_EveryHostedPrimitive(_WorldItem, EFirstPersonPrimitiveType::FirstPerson, "in the first-person hand");
    }
}
