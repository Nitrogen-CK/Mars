// A World-mode, Persistent world item whose definition carries UMars_ItemTrait_Backpack: the base WorldItem composition,
// then one cargo slot per mount of the trait (utils_backpack::Add).
//
// Mounts resolve here: Socket None -> Offset is pack-root relative; a named socket -> Offset on top of the socket
// transform, the socket location scaled by Presentation.MeshScale (the pack root is unit scale; the visual node carries
// the display scale). A named socket the mesh does not have is a configuration error: ensure, destroy self.
//
// While the pack is Held (in its carrier's hands) its cargo interactables are Mars-disabled: nobody can reach them
// (design D-B5). Every other mount re-enables them.
//
// The weight probe (Probe.Mars.Backpack) is what backpack pressure plates feel. It is enabled only while the pack lies in
// the world (Mount World): a carried or held pack weighs on nothing.
class UMars_Backpack_EntityScript : UMars_WorldItem_EntityScript
{
    private TArray<FCk_Handle_Interactable> _CargoInteractables;
    private FCk_Handle_Probe _WeightProbe;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);

        // Super destroyed itself (bad definition / no attach transform) - nothing to compose on.
        auto WorldItem = InHandle.As_WorldItem(ECk_SanityCheck::UnChecked);
        if (Flow != ECk_EntityScript_ConstructionFlow::Finished || ck::Is_NOT_Valid(WorldItem))
        { return Flow; }

        const auto IsWorld = Mode == EMars_WorldItem_Mode::World;
        const auto IsPersistent = WorldItem.Get_Persistence() == EMars_WorldItem_Persistence::Persistent;
        const UCk_InventoryItem_Definition ItemDefinition = Definition.Get();
        const UMars_ItemTrait_Backpack BackpackTrait = ItemDefinition.Get_ItemTraitByClass(UMars_ItemTrait_Backpack);
        const UMars_ItemTrait_Presentation Presentation = ItemDefinition.Get_ItemTraitByClass(UMars_ItemTrait_Presentation);

        const auto HasBackpackTrait = ck::IsValid(BackpackTrait);
        const auto IsBackpack = IsWorld && IsPersistent && HasBackpackTrait && ck::IsValid(Presentation);
        if (ck::EnsureIfNot(IsBackpack,
            f"[Backpack] [{InHandle.ToString()}] needs World mode and a Persistent definition with Presentation + Backpack traits (mode [{Mode :n}], persistent [{IsPersistent}], backpack trait [{HasBackpackTrait}])"))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        auto Spec = FMars_Backpack_Spec();
        if (ResolveMounts(InHandle, BackpackTrait, Presentation, Spec) == false)
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        auto Backpack = utils_backpack::Add(WorldItem, Spec);
        if (ck::Is_NOT_Valid(Backpack))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        _CargoInteractables.Empty();
        const auto CargoSlots = Backpack.Get_CargoSlots();
        for (const auto& Slot : CargoSlots)
        { _CargoInteractables.Add(Slot.Get_Interactable()); }

        _WeightProbe = AddWeightProbe(InHandle, Presentation);

        WorldItem.BindTo_OnMountChanged(FMars_Delegate_WorldItem_OnMountChanged(this, n"OnMountChanged"));

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    // False (after an ensure) when a mount names a socket the mesh does not have.
    private bool ResolveMounts(const FCk_Handle& InHandle,
                               const UMars_ItemTrait_Backpack InBackpackTrait,
                               const UMars_ItemTrait_Presentation InPresentation,
                               FMars_Backpack_Spec& OutSpec)
    {
        // Loaded only when a mount names a socket: the socket-less default (the engine cube) never blocks on a load.
        UStaticMesh Mesh = nullptr;
        TSoftObjectPtr<UStaticMesh> MeshSoft = InPresentation.Mesh;

        for (int32 Index = 0; Index < InBackpackTrait.CargoSlots.Num(); ++Index)
        {
            const auto& Mount = InBackpackTrait.CargoSlots[Index];

            auto SlotSpec = FMars_CargoSlot_Spec();
            SlotSpec.Index = Index;
            SlotSpec.ProbeRadius = Mount.ProbeRadius;
            SlotSpec.MountOffset = Mount.Offset;

            if (Mount.Socket.IsNone() == false)
            {
                if (ck::Is_NOT_Valid(Mesh) && MeshSoft.IsNull() == false)
                { Mesh = System::LoadAsset_Blocking(MeshSoft); }

                UStaticMeshSocket Socket = nullptr;
                if (ck::IsValid(Mesh))
                { Socket = Mesh.FindSocket(Mount.Socket); }

                if (ck::EnsureIfNot(ck::IsValid(Socket),
                    f"[Backpack] [{InHandle.ToString()}] cargo mount [{Index}] names socket [{Mount.Socket.ToString()}], which the Presentation mesh does not have"))
                { return false; }

                const auto SocketTransform = FTransform(Socket.RelativeRotation, Socket.RelativeLocation * InPresentation.MeshScale, FVector::OneVector);
                SlotSpec.MountOffset = Mount.Offset * SocketTransform;
            }

            OutSpec.CargoSlots.Add(SlotSpec);
        }

        return true;
    }

    // The same shape as the pickup probe (utils_world_item::Make_ProbeFit), as a separate probe: the pickup is a QueryOnly
    // trace target, and a plate needs a physical contact. Kinematic because the body moves the pack, Silent because nothing
    // listens on the pack's side: the plates filter on its name. The pack is constructed lying in the world, so it starts
    // enabled.
    private FCk_Handle_Probe AddWeightProbe(FCk_Handle& InHandle, const UMars_ItemTrait_Presentation InPresentation)
    {
        auto ProbeSpec = FCk_Probe_Spec(GameplayTags::ResolveGameplayTag(n"Probe.Mars.Backpack"));
        ProbeSpec.Set_MotionType(ECk_MotionType::Kinematic)
                 .Set_ResponsePolicy(ECk_ProbeResponse_Policy::Silent);

        const auto Fit = utils_world_item::Make_ProbeFit(InPresentation);
        auto Node = utils_prefab::Create_ProbeNode(InHandle.As_Transform(), Fit.Shape, ProbeSpec, Fit.Offset);

        utils_handle::Set_DebugName(FCk_Handle(Node), n"Backpack.Probe.Weight");
        return FCk_Handle(Node).As_Probe();
    }

    // Held = in the carrier's own hands: the cargo is out of anyone's reach until the pack is carried or released.
    // Only a pack lying in the world (World) weighs on a plate.
    UFUNCTION()
    private void OnMountChanged(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InPrev, EMars_WorldItem_Mount InNew)
    {
        const auto EnableDisable = InNew == EMars_WorldItem_Mount::Held ? ECk_EnableDisable::Disable : ECk_EnableDisable::Enable;
        for (auto& Interactable : _CargoInteractables)
        {
            if (ck::IsValid(Interactable))
            { Interactable.Request_SetEnableDisable(EnableDisable); }
        }

        if (ck::IsValid(_WeightProbe))
        {
            const auto WeightEnableDisable = InNew == EMars_WorldItem_Mount::World ? ECk_EnableDisable::Enable : ECk_EnableDisable::Disable;
            utils_probe::Request_EnableDisable(_WeightProbe, FCk_Request_Probe_EnableDisable(WeightEnableDisable));
        }
    }
}
