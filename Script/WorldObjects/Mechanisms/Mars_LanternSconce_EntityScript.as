// Placeable wall sconce: a plate on the wall with an arm reaching out, a lantern hook at the arm's end. The origin is the
// mounting surface and the arm reaches along local +X (out of the wall), up along +Z, like the key lock turned to a wall.
// A hung lantern lights its World pool from the hook. Asserts an optional MechanismSource while a lit lantern hangs, so
// "light the two sconces" is a Sink over two sconces.
class UMars_LanternSconce_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    // Optional: unwired while OutputChannel is unset (utils_mechanism_source::TryAdd).
    UPROPERTY(ExposeOnSpawn)
    FMars_MechanismSource_Spec Source;

    // The hook at the arm's end, under it: the lantern's bail hangs here.
    private const FVector k_HookLocal = FVector(34.0, 0.0, 6.0);

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsLanternSconce");

        auto HangNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, k_HookLocal)).As_Transform();
        utils_handle::Set_DebugName(HangNode.H(), n"Sconce.Hook");

        auto Spec = FMars_LanternHook_Spec();
        Spec.HangNode = HangNode;
        Spec.HangOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -constants_lantern_item::k_BailHeight));
        Spec.Interactable = AddInteractable(Root);
        utils_lantern_hook::Add(InHandle, Spec);

        utils_mechanism_source::TryAdd(InHandle, Source);

        AddVisuals(Root);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    // Engine shapes are 100 uu with a centered pivot. Plate: 4 x 14 x 26 on the wall; arm: 36 x 3 x 3 out from its top;
    // drop: a 3 x 3 x 8 post down from the arm's end to the hook.
    private void AddVisuals(FCk_Handle_Transform& InRoot)
    {
        auto CubeMesh = engine::load::Cube();
        auto Material = assets::load::ProtoGrid_Interactable_Mars_MI();
        const auto Iron = TOptional<FLinearColor>(FLinearColor(0.12f, 0.11f, 0.10f, 1.0f));

        auto Plate = FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector(2.0, 0.0, 0.0), FVector(0.04, 0.14, 0.26)),
            CubeMesh, Material, collision::profile::BlockAll, n"Sconce_Plate");
        Plate.PrimaryColor = Iron;
        InRoot.Add_MeshPart(this, Plate);

        auto Arm = FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector(19.0, 0.0, 12.0), FVector(0.36, 0.03, 0.03)),
            CubeMesh, Material, collision::profile::NoCollision, n"Sconce_Arm");
        Arm.PrimaryColor = Iron;
        InRoot.Add_MeshPart(this, Arm);

        auto Drop = FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector(k_HookLocal.X, 0.0, 9.0), FVector(0.03, 0.03, 0.08)),
            CubeMesh, Material, collision::profile::NoCollision, n"Sconce_Drop");
        Drop.PrimaryColor = Iron;
        InRoot.Add_MeshPart(this, Drop);
    }

    // On the sconce entity (the interaction's owner is the hook), around the hook and the lantern under it, so aiming at
    // either finds the hook.
    private FCk_Handle_Interactable AddInteractable(FCk_Handle_Transform& InRoot)
    {
        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(FVector(14.0, 14.0, 22.0)));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, k_HookLocal + FVector(0.0, 0.0, -16.0));

        auto Spec = FMars_Interactable_Spec();
        Spec.ProbeInfo = Probe;
        Spec.Targets.Add(utils_lantern_hook::Make_InteractTarget());
        Spec.FocusPriority = constants_lantern_hook::k_FocusPriority;

        return utils_interactable::Create(InRoot, Spec);
    }
}
