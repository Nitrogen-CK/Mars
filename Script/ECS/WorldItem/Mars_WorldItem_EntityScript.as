// An item presented outside an inventory, with no actor.
//
// World: the entity hosts a capacity-1 holder and the real item entity lives inside it, so dropping and picking up are
// entity-preserving transfers. A Jolt body carries it, and a pickup interactable on the Use channel stows it into the
// focuser's hotbar. A Transient item's entity destroys itself once its holder empties; a Persistent item's entity is the
// item's body and mounts to its carrier instead (Carry / Hold / Release requests, see UMars_Processor_WorldItem_*).
//
// Visual: a mesh scene-node-parented under AttachTo (the player's hand, a cargo slot). It never composes the item
// (utils_item::Add), so item traits do not run a second time on the visual. With ArriveFrom set it starts at that world
// pose and lerps to AttachOffset.
class UMars_WorldItem_EntityScript : UCk_GenericEntityScript_UE
{
    default _Replication = ECk_Replication::DoesNotReplicate;
    default _ShowInPlaceActors = true;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    TSoftObjectPtr<UCk_InventoryItem_Definition> Definition;

    UPROPERTY(ExposeOnSpawn)
    EMars_WorldItem_Mode Mode = EMars_WorldItem_Mode::World;

    // Visual: the node this visual follows.
    UPROPERTY(ExposeOnSpawn)
    FCk_Handle AttachTo;

    UPROPERTY(ExposeOnSpawn)
    FTransform AttachOffset = FTransform::Identity;

    // World: adopt this item from SourceInventory when both are valid, otherwise seed a new item from Definition.
    UPROPERTY(ExposeOnSpawn)
    FCk_Handle_Item SourceItem;

    UPROPERTY(ExposeOnSpawn)
    FCk_Handle_Inventory SourceInventory;

    UPROPERTY(ExposeOnSpawn)
    FVector LaunchVelocity = FVector::ZeroVector;

    UPROPERTY(ExposeOnSpawn)
    FVector AngularVelocityDeg = FVector::ZeroVector;

    // Visual: when set, the visual starts at this world pose and lerps to AttachOffset over Presentation.ArriveSeconds.
    UPROPERTY(ExposeOnSpawn)
    FMars_WorldItem_Arrival ArriveFrom;

    private const float32 k_MassKg = 2.0f;
    private const float32 k_LinearDamping = 0.2f;
    private const float32 k_AngularDamping = 0.5f;
    private const float32 k_Friction = 0.6f;
    private const float32 k_Restitution = 0.1f;

    private FCk_Handle _SelfEntity;
    private UCk_InventoryItem_Definition _Definition;
    private TSoftObjectPtr<UStaticMesh> _Mesh;
    private TSoftObjectPtr<UMaterialInterface> _MaterialOverride;
    private FCk_Handle_Interactable _Pickup;

    // Set while the pickup is disabled because the focuser's hotbar had nowhere to stow the item.
    private bool _DisabledForFull = false;
    private FCk_Handle_Hotbar _GatingHotbar;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        _SelfEntity = InHandle;

        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsWorldItem");

        _Definition = Definition.Get();
        if (ck::EnsureIfNot(ck::IsValid(_Definition), f"[WorldItem] No item definition on [{InHandle.ToString()}]"))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        const UMars_ItemTrait_Presentation Presentation = _Definition.Get_ItemTraitByClass(UMars_ItemTrait_Presentation);

        auto State = FMars_Fragment_WorldItem();
        if (ck::IsValid(Presentation))
        {
            _Mesh = Presentation.Mesh;
            _MaterialOverride = Presentation.MaterialOverride;
            State.VisualRoot = AddVisual(Root, Presentation.MeshScale);
        }

        if (Mode == EMars_WorldItem_Mode::World)
        {
            State.Holder = AddHolder(InHandle);
            if (ck::IsValid(Presentation))
            {
                State.Body = AddBody(InHandle, Presentation.MeshScale);
                State.Pickup = AddPickup(Root, utils_world_item::Make_ProbeFit(Presentation));
            }
            else
            {
                State.Pickup = AddPickup(Root, FMars_WorldItem_ProbeFit(
                    utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(40.0f)), FTransform::Identity));
            }

            _Pickup = State.Pickup;
        }
        else
        {
            auto AttachTransform = AttachTo.As_Transform(ECk_SanityCheck::UnChecked);
            if (ck::EnsureIfNot(ck::IsValid(AttachTransform), f"[WorldItem] Visual [{InHandle.ToString()}] has no transform to attach to"))
            {
                utils_entity_lifetime::Request_DestroyEntity(InHandle);
                return ECk_EntityScript_ConstructionFlow::Finished;
            }

            if (ArriveFrom.IsSet)
            {
                // Start where the item visually was and let the Arrive processor lerp the offset to AttachOffset.
                const auto AttachWorld = utils_transform::Get_EntityCurrentTransform(AttachTransform);
                const auto FromOffset = ArriveFrom.World.GetRelativeTransform(AttachWorld);
                utils_scene_node::Add(Root, AttachTransform, FromOffset);

                auto Arrival = FMars_Fragment_WorldItem_Arrival();
                Arrival.FromOffset = FromOffset;
                Arrival.ToOffset = AttachOffset;
                Arrival.Duration = ck::IsValid(Presentation) ? Presentation.ArriveSeconds : 0.0f;
                InHandle.Add_Fragment(Arrival);
            }
            else
            { utils_scene_node::Add(Root, AttachTransform, AttachOffset); }
        }

        auto Params = FMars_Fragment_WorldItem_Params();
        Params.Mode = Mode;
        Params.Definition = Definition;
        utils_world_item::Add(InHandle, Params, State);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    // The holder must be fully composed before an item can be seeded into it or adopted.
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto WorldItem = InHandle.As_WorldItem(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(WorldItem) || WorldItem.Get_Mode() != EMars_WorldItem_Mode::World)
        { return; }

        WorldItem.BindTo_OnMountChanged(FMars_Delegate_WorldItem_OnMountChanged(this, n"OnMountChanged_FirstPerson"));

        auto Holder = WorldItem.Get_Holder();
        Holder.BindTo_OnItemsChanged(FCk_Delegate_Inventory_OnItemsChanged(this, n"OnHolderItemsChanged"));

        if (ck::IsValid(SourceItem) && ck::IsValid(SourceInventory))
        {
            auto Source = SourceInventory;
            Source.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(SourceItem, Holder),
                FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnAdoptComplete"));
            return;
        }

        auto AddRequest = FCk_Request_Inventory_AddItemByDefinition(_Definition, 1);
        AddRequest.Set_Policy(ECk_Inventory_AddPolicy::ForceNewItem);
        Holder.Request_AddItemByDefinition(AddRequest,
            FCk_Delegate_Inventory_OnOperationResult_AddByDefinition(this, n"OnSeedComplete"));
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (_DisabledForFull && ck::IsValid(_GatingHotbar))
        {
            _GatingHotbar.UnbindFrom_OnSlotItemChanged(
                FMars_Delegate_Hotbar_OnSlotItemChanged(this, n"OnGatingHotbarSlotItemChanged"));
        }

        _DisabledForFull = false;
        _GatingHotbar = FCk_Handle_Hotbar();
    }

    //--------------------------------------------------------------------------------------------------------------------------
    // Composition
    //--------------------------------------------------------------------------------------------------------------------------

    private FCk_Handle_Transform AddVisual(FCk_Handle_Transform& InRoot, FVector InMeshScale)
    {
        auto VisualRoot = utils_scene_node::Create(InRoot, FTransform(FRotator::ZeroRotator, FVector::ZeroVector, InMeshScale)).As_Transform();

        const auto ComponentParams = utils_unreal_component::Make_Params(UStaticMeshComponent, ECk_UnrealComponent_TickPolicy::DoNotTick, n"WorldItem_Mesh");
        auto ComponentHandle = utils_unreal_component::Add(FCk_Handle(VisualRoot), ComponentParams);

        utils_unreal_component::BindTo_OnAdded(
            ComponentHandle,
            FCk_Delegate_UnrealComponent_OnAdded(this, n"OnMeshComponentAdded"));

        return VisualRoot;
    }

    private FCk_Handle_Inventory_DataOnly AddHolder(FCk_Handle& InHandle)
    {
        auto HolderParams = utils_inventory_data_only::Make_Params_Bounded(
            utils_gameplay_tag::ResolveGameplayTag(n"Inventory.Mars.WorldItemHolder"), 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(),
            FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        HolderParams.Set_StackingPolicy(ECk_Inventory_StackingPolicy::NoStacking);

        return utils_inventory_data_only::Add(InHandle, HolderParams, ECk_Replication::DoesNotReplicate);
    }

    // No mesh, no body: the item then rests where it was spawned.
    private FCk_Handle_JoltBody AddBody(FCk_Handle& InHandle, FVector InMeshScale)
    {
        if (_Mesh.IsNull())
        { return FCk_Handle_JoltBody(); }

        auto BodySpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::StaticMeshAsset);
        BodySpec.Set_StaticMesh(_Mesh);
        // The entity transform stays unit scale; the display scale lives on the visual node, so the shape matches it.
        BodySpec.Set_ShapeScale(InMeshScale);
        BodySpec.Set_MotionType(ECk_MotionType::Dynamic);
        BodySpec.Set_MotionQuality(ECk_MotionQuality::LinearCast);
        BodySpec.Set_MassSource(ECk_JoltBody_MassSource::Explicit);
        BodySpec.Set_MassKg(k_MassKg);
        BodySpec.Set_LinearDamping(k_LinearDamping);
        BodySpec.Set_AngularDamping(k_AngularDamping);
        BodySpec.Set_SurfaceSource(ECk_JoltBody_SurfaceSource::Explicit);
        BodySpec.Set_Friction(k_Friction);
        BodySpec.Set_Restitution(k_Restitution);

        auto Body = utils_jolt_body::Add(InHandle, BodySpec);
        if (ck::Is_NOT_Valid(Body))
        { return Body; }

        const auto Launched = LaunchVelocity.IsNearlyZero() == false || AngularVelocityDeg.IsNearlyZero() == false;
        if (Launched)
        {
            // Never applied here: the body is not added for at least one frame. The launch processor drains this.
            auto Pending = FMars_Fragment_WorldItem_PendingLaunch();
            Pending.LinearVelocity = LaunchVelocity;
            Pending.AngularVelocityDeg = AngularVelocityDeg;
            InHandle.Add_Fragment(Pending);
        }

        return Body;
    }

    // The probe carries Probe.Mars.Interact: the player's interaction trace only sees probes under that tag. It is
    // Kinematic because the body moves the item.
    private FCk_Handle_Interactable AddPickup(FCk_Handle_Transform& InRoot, FMars_WorldItem_ProbeFit InFit)
    {
        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeSpec.Set_MotionType(ECk_MotionType::Kinematic);
        Probe.ProbeShape = InFit.Shape;
        Probe.ProbeOffset = InFit.Offset;

        auto TargetSpec = FCk_InteractTarget_Spec(GameplayTags::InteractionChannel_Mars_Use);
        TargetSpec.Set_CompletionPolicy(ECk_Interaction_CompletionPolicy::Instant);

        const auto ItemName = _Definition.Get_CoreInfo().Get_Name().ToString();
        auto Prompt = FMars_InteractPrompt_Spec();
        Prompt.InputAction = mars::Mars_IA_Interact_Use;
        Prompt.PromptText = FText::FromString(f"Pick up {ItemName}");

        auto Target = FMars_Interactable_TargetEntry();
        Target.InteractTargetSpec = TargetSpec;
        Target.InteractPromptSpec = Prompt;
        Target.InteractionStateClass = UMars_SmState_WorldItem_PickUp;

        auto Spec = FMars_Interactable_Spec();
        Spec.ProbeInfo = Probe;
        Spec.Targets.Add(Target);

        auto Pickup = utils_interactable::Create(InRoot, Spec);
        Pickup.BindTo_OnFocused(FMars_Delegate_Interactable_OnFocused(this, n"OnPickupFocused"));
        return Pickup;
    }

    //--------------------------------------------------------------------------------------------------------------------------
    // Callbacks
    //--------------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnMeshComponentAdded(FCk_Handle_UnrealComponent InHandle)
    {
        auto MeshComponent = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(InHandle));
        if (ck::Is_NOT_Valid(MeshComponent))
        { return; }

        MeshComponent.SetCollisionEnabled(ECollisionEnabled::NoCollision);

        if (_Mesh.IsNull() == false)
        { MeshComponent.SetStaticMesh(System::LoadAsset_Blocking(_Mesh)); }

        if (_MaterialOverride.IsNull() == false)
        { MeshComponent.SetMaterial(0, System::LoadAsset_Blocking(_MaterialOverride)); }

        // A visual attached under the local player's hand is drawn with the first-person gloves holding it.
        MeshComponent.SetFirstPersonPrimitiveType(utils_fphands::Get_FirstPersonType(FCk_Handle(InHandle)));
    }

    // A persistent item moving into or out of the local player's hand switches how it, and what it carries, is drawn.
    UFUNCTION()
    private void OnMountChanged_FirstPerson(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InPrev, EMars_WorldItem_Mount InNew)
    {
        utils_fphands::Apply_FirstPersonType(FCk_Handle(InWorldItem));
    }

    UFUNCTION()
    private void OnSeedComplete(FCk_Handle_Inventory InInventory,
                                ECk_Inventory_OperationResult_AddByDefinition InResult,
                                int InAmountAdded,
                                const TArray<FCk_Handle_Item>&in InItemsCreated)
    {
        const auto Seeded = InResult == ECk_Inventory_OperationResult_AddByDefinition::Success_AllAdded;
        if (ck::EnsureIfNot(Seeded, f"[WorldItem] Seeding [{_SelfEntity.ToString()}] failed with [{InResult :n}]"))
        {
            utils_entity_lifetime::Request_DestroyEntity(_SelfEntity);
            return;
        }

        if (InItemsCreated.Num() > 0)
        { StampPersistentWorldItem(InItemsCreated[0]); }
    }

    UFUNCTION()
    private void OnAdoptComplete(FCk_Handle_Inventory InSource,
                                 FCk_Handle_Item InItem,
                                 FCk_Handle_Inventory InTarget,
                                 int32 InCount,
                                 FCk_Handle_Item InNewItemInTarget,
                                 ECk_Inventory_OperationResult_Transfer InResult)
    {
        // A failed adopt would leave an empty pickable in the world.
        const auto Adopted = InResult == ECk_Inventory_OperationResult_Transfer::Success;
        if (ck::EnsureIfNot(Adopted, f"[WorldItem] Adopting into [{_SelfEntity.ToString()}] failed with [{InResult :n}]"))
        {
            utils_entity_lifetime::Request_DestroyEntity(_SelfEntity);
            return;
        }

        StampPersistentWorldItem(InNewItemInTarget);
    }

    // Transient: the item was stowed and nothing is left to present. Persistent: the world item IS the item's body and
    // follows it (the pickup task requests Carry), so it never destroys itself here.
    UFUNCTION()
    private void OnHolderItemsChanged(FCk_Handle_Inventory InInventory,
                                      const TArray<FCk_Handle_Item>&in InItemsAdded,
                                      const TArray<FCk_Handle_Item>&in InItemsRemoved)
    {
        if (InItemsRemoved.Num() == 0 || InInventory.Get_NumItems() != 0)
        { return; }

        auto WorldItem = _SelfEntity.As_WorldItem(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(WorldItem) && WorldItem.Get_Persistence() == EMars_WorldItem_Persistence::Persistent)
        { return; }

        utils_entity_lifetime::Request_DestroyEntity(_SelfEntity);
    }

    // The sanctioned construction-like marker (design 7.3/7.5): a Persistent world item links its item back to itself
    // once, so HeldItem / HeldItemUse / the pickup task can route the item's moves through this entity.
    private void StampPersistentWorldItem(FCk_Handle_Item InItem)
    {
        auto WorldItem = _SelfEntity.As_WorldItem(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(WorldItem) || ck::Is_NOT_Valid(InItem) ||
            WorldItem.Get_Persistence() != EMars_WorldItem_Persistence::Persistent)
        { return; }

        auto Item = InItem;
        if (Item.Has_PersistentWorldItem())
        {
            const auto Existing = Item.Get_PersistentWorldItem();
            ck::EnsureIfNot(Existing == WorldItem,
                f"[WorldItem] Item [{Item.ToString()}] is already linked to world item [{Existing.ToString()}], not [{WorldItem.ToString()}]");
            return;
        }

        auto Marker = FMars_Fragment_Item_PersistentWorldItem();
        Marker.WorldItem = WorldItem;
        Item.Add_Fragment(Marker);
    }

    // A full hotbar disables the pickup (no prompt) until one of its slots frees up.
    UFUNCTION()
    private void OnPickupFocused(FCk_Handle_Interactable InInteractable, FCk_Handle InFocusedBy)
    {
        auto Hotbar = InFocusedBy.As_Hotbar(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Hotbar) || DoGet_CanStowSelf(Hotbar) || _DisabledForFull)
        { return; }

        _DisabledForFull = true;
        _GatingHotbar = Hotbar;
        _Pickup.Request_SetEnableDisable(ECk_EnableDisable::Disable);
        _GatingHotbar.BindTo_OnSlotItemChanged(FMars_Delegate_Hotbar_OnSlotItemChanged(this, n"OnGatingHotbarSlotItemChanged"));
    }

    UFUNCTION()
    private void OnGatingHotbarSlotItemChanged(FCk_Handle_Hotbar InHotbar, int32 InIndex, FCk_Handle_Item InMaybeItem)
    {
        if (DoGet_CanStowSelf(InHotbar) == false)
        { return; }

        _DisabledForFull = false;
        _GatingHotbar.UnbindFrom_OnSlotItemChanged(FMars_Delegate_Hotbar_OnSlotItemChanged(this, n"OnGatingHotbarSlotItemChanged"));
        _GatingHotbar = FCk_Handle_Hotbar();

        if (ck::IsValid(_Pickup))
        { _Pickup.Request_SetEnableDisable(ECk_EnableDisable::Enable); }
    }

    // An item-aware stow check: a second backpack has nowhere to go while one is worn. No held item -> cannot stow.
    private bool DoGet_CanStowSelf(FCk_Handle_Hotbar InHotbar)
    {
        const auto Item = _SelfEntity.As_WorldItem().Get_HeldItem();
        if (ck::Is_NOT_Valid(Item))
        { return false; }

        return InHotbar.Get_CanStow(Item);
    }
}
