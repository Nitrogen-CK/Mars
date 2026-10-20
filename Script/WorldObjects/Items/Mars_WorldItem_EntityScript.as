// An item presented outside an inventory, with no actor.
//
// World: the entity hosts a capacity-1 holder and the real item entity lives inside it, so dropping and picking up are
// entity-preserving transfers. A Jolt body carries it, and a pickup interactable on the Use channel stows it into the
// focuser's hotbar. A Transient item's entity destroys itself once its holder empties; a Persistent item's entity is the
// item's body and mounts where its item lives instead (UMars_Processor_WorldItem_Reconcile; a Release brings it home).
//
// Visual: a mesh scene-node-parented under AttachTo (the player's hand, a cargo slot). It never composes the item
// (utils_item::Add), so item traits do not run a second time on the visual. With ArriveFrom set it starts at that world
// pose and lerps to AttachOffset.
//
// A World-mode subclass whose body is not the Presentation mesh builds its own body and probe fit, then runs the shared
// tail through Compose_WorldItem.
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

    // Visual: when set, the visual starts at this world pose and lerps to AttachOffset over Presentation.Mounting.ArriveSeconds.
    UPROPERTY(ExposeOnSpawn)
    FMars_WorldItem_Arrival ArriveFrom;

    private const float32 k_MassKg = 2.0f;
    private const float32 k_LinearDamping = 0.2f;
    private const float32 k_AngularDamping = 0.5f;
    private const float32 k_Friction = 0.6f;
    private const float32 k_Restitution = 0.1f;
    // An item without a Presentation trait: the pickup's sphere and the box the reach sizes from.
    private const float32 k_BareProbeRadius = 40.0f;

    private FCk_Handle _SelfEntity;
    private UCk_InventoryItem_Definition _Definition;
    private TSoftObjectPtr<UStaticMesh> _Mesh;
    private TSoftObjectPtr<UMaterialInterface> _MaterialOverride;
    private TOptional<FLinearColor> _PrimaryColor;
    private FCk_Handle_Interactable _Pickup;

    // Valid while the pickup holds its HotbarFull claim because this focuser's hotbar had nowhere to stow the item.
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

        if (ck::IsValid(Presentation))
        {
            _Mesh = Presentation.Visual.Mesh;
            _MaterialOverride = Presentation.Visual.MaterialOverride;
            _PrimaryColor = Presentation.Visual.PrimaryColor;
            AddVisual(Root, Presentation.Visual.MeshScale);
        }

        if (Mode == EMars_WorldItem_Mode::World)
        {
            auto Composition = FMars_WorldItem_Composition();
            Composition.ProbeFit = FMars_WorldItem_ProbeFit(
                utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(k_BareProbeRadius)), FTransform::Identity);
            Composition.BoundsFit = FMars_WorldItem_BoundsFit(FVector(k_BareProbeRadius, k_BareProbeRadius, k_BareProbeRadius), FVector::ZeroVector);
            if (ck::IsValid(Presentation))
            {
                Composition.Body = AddBody(InHandle, Presentation.Visual.MeshScale);
                Composition.ProbeFit = utils_world_item::Make_ProbeFit(Presentation);
                Composition.BoundsFit = utils_world_item::Make_BoundsFit(Presentation);
            }

            const auto Launched = LaunchVelocity.IsNearlyZero() == false || AngularVelocityDeg.IsNearlyZero() == false;
            if (Launched && ck::IsValid(Composition.Body))
            {
                Composition.Launch = TOptional<FMars_Fragment_WorldItem_PendingLaunch>(
                    FMars_Fragment_WorldItem_PendingLaunch(LaunchVelocity, AngularVelocityDeg));
            }

            Compose_WorldItem(InHandle, Composition);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        auto Spec = FMars_WorldItem_Spec();
        Spec.Mode = Mode;
        Spec.Definition = Definition;

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
            Arrival.Duration = ck::IsValid(Presentation) ? Presentation.Mounting.ArriveSeconds : 0.0f;
            Spec.Arrival = TOptional<FMars_Fragment_WorldItem_Arrival>(Arrival);
        }
        else
        { utils_scene_node::Add(Root, AttachTransform, AttachOffset); }

        auto WorldItem = utils_world_item::Add(InHandle, Spec);
        if (ck::Is_NOT_Valid(WorldItem))
        { utils_entity_lifetime::Request_DestroyEntity(InHandle); }

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
        Unbind_GatingHotbar();
    }

    //--------------------------------------------------------------------------------------------------------------------------
    // Composition
    //--------------------------------------------------------------------------------------------------------------------------

    // The World-mode tail every world item shares: the holder, the pickup fitted to InComposition.ProbeFit and the WorldItem
    // feature over InComposition's body and launch. A rejected spec destroys the entity (utils_world_item::Add ensured).
    protected void Compose_WorldItem(FCk_Handle& InHandle, const FMars_WorldItem_Composition& InComposition)
    {
        _SelfEntity = InHandle;
        _Definition = Definition.Get();

        auto Root = InHandle.As_Transform();

        const auto Holder = AddHolder(InHandle);
        _Pickup = AddPickup(Root, InComposition.ProbeFit);

        auto Spec = FMars_WorldItem_Spec();
        Spec.Mode = EMars_WorldItem_Mode::World;
        Spec.Definition = Definition;
        Spec.World = TOptional<FMars_WorldItem_WorldParts>(FMars_WorldItem_WorldParts(Holder, _Pickup, InComposition));

        auto WorldItem = utils_world_item::Add(InHandle, Spec);
        if (ck::Is_NOT_Valid(WorldItem))
        { utils_entity_lifetime::Request_DestroyEntity(InHandle); }
    }

    // The name the pickup prompt shows: the item definition's.
    protected FString Get_ItemName() const
    {
        return _Definition.Get_CoreInfo().Get_Name().ToString();
    }

    // What interacting with the pickup does.
    protected TSoftClassPtr<UCk_SmState_EntityScript> Get_PickupStateClass() const
    {
        TSoftClassPtr<UCk_SmState_EntityScript> StateClass = UMars_SmState_WorldItem_PickUp;
        return StateClass;
    }

    // Ranks the pickup against other interactables under the view ray (FMars_Interactable_Spec.FocusPriority).
    protected int32 Get_PickupFocusPriority() const
    {
        return 0;
    }

    // Invalid before Compose_WorldItem and in Visual mode.
    protected FCk_Handle_Interactable Get_Pickup() const
    {
        return _Pickup;
    }

    // A unit-scale child of the root that carries the mesh and the display scale.
    private void AddVisual(FCk_Handle_Transform& InRoot, FVector InMeshScale)
    {
        auto VisualRoot = utils_scene_node::Create(InRoot, FTransform(FRotator::ZeroRotator, FVector::ZeroVector, InMeshScale)).As_Transform();

        const auto ComponentParams = utils_unreal_component::Make_Params(UStaticMeshComponent, ECk_UnrealComponent_TickPolicy::DoNotTick, n"WorldItem_Mesh");
        auto ComponentHandle = utils_unreal_component::Add(VisualRoot.H(), ComponentParams);

        utils_unreal_component::BindTo_OnAdded(
            ComponentHandle,
            FCk_Delegate_UnrealComponent_OnAdded(this, n"OnMeshComponentAdded"));
    }

    // Who may put an item into the holder; unbound accepts anything.
    protected FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic Get_HolderAcceptPolicy() const
    {
        return FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic();
    }

    private FCk_Handle_Inventory_DataOnly AddHolder(FCk_Handle& InHandle)
    {
        auto HolderParams = utils_inventory_data_only::Make_Params_Bounded(
            GameplayTags::Inventory_Mars_WorldItemHolder, 1,
            Get_HolderAcceptPolicy(),
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
        BodySpec.Set_CollisionProfileName(constants_world_item::k_DefaultBodyProfile);

        return utils_jolt_body::Add(InHandle, BodySpec);
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

        auto Prompt = FMars_InteractPrompt_Spec();
        Prompt.InputAction = mars::Mars_IA_Interact_Use;
        Prompt.PromptText = FText::FromString(f"Pick up {Get_ItemName()}");

        // WhileLive: the item moves at the gloves' Grip, and the interaction lives until it has.
        auto Target = FMars_Interactable_TargetEntry();
        Target.InteractTargetSpec = TargetSpec;
        Target.InteractPromptSpec = Prompt;
        Target.InteractionStateClass = Get_PickupStateClass();
        Target.Work = EMars_Interactable_Work::WhileLive;

        auto Spec = FMars_Interactable_Spec();
        Spec.ProbeInfo = Probe;
        Spec.Targets.Add(Target);
        Spec.FocusPriority = Get_PickupFocusPriority();

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
        if (ck::EnsureIfNot(ck::IsValid(MeshComponent), f"[WorldItem] [{_SelfEntity.ToString()}] got no UStaticMeshComponent for its visual"))
        { return; }

        MeshComponent.SetCollisionEnabled(ECollisionEnabled::NoCollision);

        if (_Mesh.IsNull() == false)
        { MeshComponent.SetStaticMesh(System::LoadAsset_Blocking(_Mesh)); }

        if (_MaterialOverride.IsNull() == false)
        { MeshComponent.SetMaterial(0, System::LoadAsset_Blocking(_MaterialOverride)); }

        if (_PrimaryColor.IsSet())
        {
            auto TintedMaterial = MeshComponent.CreateDynamicMaterialInstance(0);
            if (ck::IsValid(TintedMaterial))
            { TintedMaterial.Set_ProtoGridColors(_PrimaryColor.GetValue()); }
        }

        // A visual attached under the local player's hand is drawn with the first-person gloves holding it. The walk
        // starts at this item's root (the scene node under the hand): the component's own entity is no scene node.
        MeshComponent.SetFirstPersonPrimitiveType(utils_fphands::Get_FirstPersonType(_SelfEntity));

        DoOnVisualMeshAdded(MeshComponent);
    }

    // The Presentation mesh's component exists and is set up: a subclass that dresses the mesh (its materials, its shadow)
    // does it here.
    protected void DoOnVisualMeshAdded(UStaticMeshComponent InMesh)
    {
    }

    // A persistent item moving into or out of the local player's hand switches how it, and what it carries, is drawn.
    UFUNCTION()
    private void OnMountChanged_FirstPerson(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InPrev, EMars_WorldItem_Mount InNew)
    {
        utils_fphands::Apply_FirstPersonType(InWorldItem);
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

        if (ck::EnsureIfNot(InItemsCreated.Num() > 0, f"[WorldItem] Seeding [{_SelfEntity.ToString()}] reported success but created no item"))
        {
            utils_entity_lifetime::Request_DestroyEntity(_SelfEntity);
            return;
        }

        auto WorldItem = _SelfEntity.As_WorldItem();
        utils_world_item::Add_Item(WorldItem, InItemsCreated[0]);
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

        auto WorldItem = _SelfEntity.As_WorldItem();
        utils_world_item::Add_Item(WorldItem, ck::IsValid(InNewItemInTarget) ? InNewItemInTarget : InItem);
    }

    // Transient: the item was stowed and nothing is left to present. Persistent: the world item IS the item's body and
    // follows it wherever it goes (UMars_Processor_WorldItem_Reconcile), so it never destroys itself here.
    UFUNCTION()
    private void OnHolderItemsChanged(FCk_Handle_Inventory InInventory,
                                      const TArray<FCk_Handle_Item>&in InItemsAdded,
                                      const TArray<FCk_Handle_Item>&in InItemsRemoved)
    {
        if (InItemsRemoved.Num() == 0 || InInventory.Get_NumItems() != 0)
        { return; }

        auto WorldItem = _SelfEntity.As_WorldItem();
        if (WorldItem.Get_Persistence() == EMars_WorldItem_Persistence::Persistent)
        { return; }

        utils_entity_lifetime::Request_DestroyEntity(_SelfEntity);
    }

    // A focuser whose hotbar has nowhere to stow the held item makes the pickup hold its HotbarFull claim: the pickup stays
    // focused, a press starts nothing, and its prompt is blocked HotbarFull (the prompt widget words it). The claim goes
    // when one of that hotbar's slots frees room, or when the hotbar's owner is torn down. A holder that holds no item yet (an item just spawned,
    // not adopted) claims nothing: a press then fails the pickup. Releasing re-enables the pickup only if no other claimant
    // (a mount, a ledger) holds it too.
    UFUNCTION()
    private void OnPickupFocused(FCk_Handle_Interactable InInteractable, FCk_Handle InFocusedBy)
    {
        auto Hotbar = InFocusedBy.As_Hotbar(ECk_SanityCheck::UnChecked);
        const auto Item = _SelfEntity.As_WorldItem().Get_HeldItem();
        if (ck::Is_NOT_Valid(Hotbar) || ck::Is_NOT_Valid(Item) || DoGet_CanStowSelf(Hotbar) || ck::IsValid(_GatingHotbar))
        { return; }

        _GatingHotbar = Hotbar;
        _Pickup.Request_Disable(FMars_Request_Interactable_Disable(EMars_Interactable_DisableReason::HotbarFull));
        _GatingHotbar.BindTo_OnSlotItemChanged(FMars_Delegate_Hotbar_OnSlotItemChanged(this, n"OnGatingHotbarSlotItemChanged"));
        _GatingHotbar.H().BindTo_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnGatingHotbarBeginDestroy"));
        Set_PromptBlocked(FMars_Request_InteractPrompt_SetBlocked(EMars_InteractPrompt_BlockedReason::HotbarFull));
    }

    UFUNCTION()
    private void OnGatingHotbarSlotItemChanged(FCk_Handle_Hotbar InHotbar, int32 InIndex, FCk_Handle_Item InMaybeItem)
    {
        if (DoGet_CanStowSelf(InHotbar) == false)
        { return; }

        Release_HotbarGate();
    }

    UFUNCTION()
    private void OnGatingHotbarBeginDestroy(FCk_Handle InEntity)
    {
        Release_HotbarGate();
    }

    private void Release_HotbarGate()
    {
        Unbind_GatingHotbar();

        if (ck::IsValid(_Pickup))
        { _Pickup.Request_Enable(FMars_Request_Interactable_Enable(EMars_Interactable_DisableReason::HotbarFull)); }

        Set_PromptBlocked(FMars_Request_InteractPrompt_SetBlocked());
    }

    private void Unbind_GatingHotbar()
    {
        if (ck::IsValid(_GatingHotbar))
        {
            _GatingHotbar.UnbindFrom_OnSlotItemChanged(
                FMars_Delegate_Hotbar_OnSlotItemChanged(this, n"OnGatingHotbarSlotItemChanged"));
            _GatingHotbar.H().UnbindFrom_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnGatingHotbarBeginDestroy"));
        }

        _GatingHotbar = FCk_Handle_Hotbar();
    }

    // The pickup's one prompt (on its Use target); a pickup already gone has nothing to show.
    private void Set_PromptBlocked(const FMars_Request_InteractPrompt_SetBlocked& InRequest)
    {
        if (ck::Is_NOT_Valid(_Pickup))
        { return; }

        auto Prompt = _Pickup.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use).As_InteractPrompt(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Prompt))
        { Prompt.Request_SetBlocked(InRequest); }
    }

    // Whether the pickup stays enabled for InHotbar's owner: an item-aware stow check (a second backpack has nowhere to go
    // while one is worn). No held item -> cannot stow. A subclass whose interactable does more than stow widens it.
    protected bool DoGet_CanStowSelf(FCk_Handle_Hotbar InHotbar)
    {
        const auto Item = _SelfEntity.As_WorldItem().Get_HeldItem();
        if (ck::Is_NOT_Valid(Item))
        { return false; }

        return InHotbar.Get_CanStow(Item);
    }
}
