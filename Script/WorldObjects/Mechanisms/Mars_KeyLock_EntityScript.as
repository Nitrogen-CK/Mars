// Placeable keyhole: a wall plate with a keyhole ring tinted the colour of the key it takes. The origin is the mounting
// surface and the keyhole faces local +Z (pitch -90 to face +X on a wall), like the seal. An inserted key shows standing out
// of the keyhole. Asserts an optional MechanismSource while a key is in, so a door needing several keys is a Sink over
// several locks (AllChannels for different keys, AllSources for several of one key).
class UMars_KeyLock_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn, meta = (Categories = "Key.Mars"))
    FGameplayTag AcceptedKey;

    UPROPERTY(ExposeOnSpawn)
    EMars_KeyLock_Release Release = EMars_KeyLock_Release::Kept;

    // No source is added while OutputChannel is unset.
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSource_Spec Source;

    // Where the inserted key's centre sits out from the plate face; the key is 30 uu long, so about half shows.
    private const float64 k_KeyMountHeight = 14.0;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto LockRoot = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsKeyLock");

        // Pitch -90 turns the key's +X (its shaft) to the plate's -Z: into the keyhole.
        auto KeyMount = utils_scene_node::Create(LockRoot,
            FTransform(FRotator(-90.0, 0.0, 0.0), FVector(0.0, 0.0, k_KeyMountHeight))).As_Transform();

        auto Spec = FMars_KeyLock_Spec();
        Spec.AcceptedKey = AcceptedKey;
        Spec.Release = Release;
        Spec.KeyMount = KeyMount;
        Spec.Interactable = AddInteractable(LockRoot);
        utils_key_lock::Add(InHandle, Spec);

        if (Source.OutputChannel.IsValid())
        { utils_mechanism_source::Add(InHandle, Source); }

        AddVisuals(LockRoot);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    private void AddVisuals(FCk_Handle_Transform& InRoot)
    {
        auto CubeMesh = engine::load::Cube();
        auto CylinderMesh = engine::load::Cylinder();
        auto Material = assets::load::ProtoGrid_Interactable_Mars_MI();

        // Engine shapes are 100 uu with a centered pivot. Plate: 40 x 40 x 6; ring: 24 across, 2 thick, on its face; slot:
        // 4 x 12, dark, in the ring's middle.
        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 3.0), FVector(0.4, 0.4, 0.06)),
            CubeMesh, Material, collision::profile::BlockAll, n"KeyLock_Plate"));

        auto Ring = FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 7.0), FVector(0.24, 0.24, 0.02)),
            CylinderMesh, Material, collision::profile::NoCollision, n"KeyLock_Ring");
        Ring.PrimaryColor = TOptional<FLinearColor>(constants_key_colors::Get_Color(AcceptedKey));
        InRoot.Add_MeshPart(this, Ring);

        auto Slot = FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 8.2), FVector(0.04, 0.12, 0.01)),
            CubeMesh, Material, collision::profile::NoCollision, n"KeyLock_Slot");
        Slot.PrimaryColor = TOptional<FLinearColor>(FLinearColor(0.03f, 0.03f, 0.03f, 1.0f));
        InRoot.Add_MeshPart(this, Slot);
    }

    private FCk_Handle_Interactable AddInteractable(FCk_Handle_Transform& InRoot)
    {
        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(FVector(30.0, 30.0, 20.0)));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 10.0));

        auto Spec = FMars_Interactable_Spec();
        Spec.ProbeInfo = Probe;
        Spec.Targets.Add(utils_key_lock::Make_InteractTarget());
        Spec.FocusPriority = constants_key_lock::k_FocusPriority;

        return utils_interactable::Create(InRoot, Spec);
    }
}
