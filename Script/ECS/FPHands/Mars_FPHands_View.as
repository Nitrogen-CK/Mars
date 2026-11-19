// First-person rendering of the gloves and of everything the local player holds (Unreal's First Person Rendering:
// EFirstPersonPrimitiveType::FirstPerson primitives are drawn scaled toward the camera, so they cannot poke through
// nearby walls). The scale is uniform about the camera, so a first-person primitive keeps its on-screen position:
// reaches still line up with the world objects they touch, and need no correction.
//
// A separate first-person field of view is deliberately not offered here: it moves first-person primitives on screen
// relative to the world, so every world-anchored target (reach grips, contact shapes, the pickup carry) would first
// need the inverse correction.
//
// Everything the gloves hold must be first-person too, or it is drawn at its true depth behind them: world item
// visuals tag themselves from Get_FirstPersonType / Apply_FirstPersonType.
struct FMars_FPHands_ViewSpec
{
    UPROPERTY()
    ECk_EnableDisable FirstPersonRendering = ECk_EnableDisable::Enable;

    // How far first-person primitives are scaled toward the camera, 0..1. Smaller keeps them clear of closer walls,
    // but anything scaled inside the near clip plane (10 cm) is cut off.
    UPROPERTY()
    float32 FirstPersonScale = 0.5f;
}

// FirstPersonScale finite and within (0, 1].
mixin FMars_Validation Validate(const FMars_FPHands_ViewSpec& Self)
{
    if (Math::IsFinite(Self.FirstPersonScale) == false || Self.FirstPersonScale <= 0.0f || Self.FirstPersonScale > 1.0f)
    { return FMars_Validation(f"FirstPersonScale [{Self.FirstPersonScale}] is outside (0, 1]"); }

    return FMars_Validation();
}

namespace constants_fphands_view
{
    // Deepest attach chain looked through for a hand node (visual -> cargo slot -> pack -> hand is 4).
    const int32 k_MaxAttachDepth = 16;

    // Most transform entities walked under one root: a held item (a pack, its probe nodes, cargo slots and their
    // visuals) or a mechanism searched for grip sockets.
    const int32 k_MaxHeldEntities = 64;
}

namespace utils_fphands
{
    // InRoot (when valid) and its transform descendants, breadth first. Only the transform tree: primitives hang off scene
    // nodes (their component entities are found through the owner), while interactables' state machines, inventories,
    // items and timers would only fill the cap. Past k_MaxHeldEntities it ensures and returns what it has.
    TArray<FCk_Handle> Get_TransformTree(const FCk_Handle& InRoot)
    {
        TArray<FCk_Handle> Tree;
        if (ck::Is_NOT_Valid(InRoot))
        { return Tree; }

        Tree.Add(InRoot);
        for (int32 Index = 0; Index < Tree.Num(); ++Index)
        {
            auto Entity = Tree[Index];
            for (auto Dependent : Entity.Get_LifetimeDependents())
            {
                if (ck::Is_NOT_Valid(Dependent) || Dependent.Is_Transform() == false)
                { continue; }

                if (ck::EnsureIfNot(Tree.Num() < constants_fphands_view::k_MaxHeldEntities,
                    f"[FPHands] [{InRoot.ToString()}] has more than [{constants_fphands_view::k_MaxHeldEntities}] transform entities under it - the rest are skipped"))
                { return Tree; }

                Tree.Add(Dependent);
            }
        }
        return Tree;
    }

    // InHands run as a first-person view on this machine: their tick runs and they carry a held visual in. An entity
    // with no character (a headless rig) always; a player character once its hand mount is first-person
    // (AMars_PlayerCharacter::Get_IsHandMountFirstPerson, latched one-way); another character while locally controlled.
    bool Get_IsFirstPersonView(const FCk_Handle_FPHands& InHands)
    {
        FCk_Handle HandsEntity = InHands;
        auto Actor = utils_entity_bridge::TryGet_Actor_Recursive(HandsEntity);
        auto PlayerCharacter = Cast<AMars_PlayerCharacter>(Actor);
        if (ck::IsValid(PlayerCharacter))
        { return PlayerCharacter.Get_IsHandMountFirstPerson(); }

        auto Character = Cast<ACharacter>(Actor);
        return ck::Is_NOT_Valid(Character) || Character.IsLocallyControlled();
    }

    // InNode is the hand node of the gloves of the player character whose first-person hand this machine shows
    // (AMars_PlayerCharacter::Get_IsHandMountFirstPerson, the latch its hand mount moved under the gloves by), with
    // first-person rendering on (its config's FPHandsView).
    bool Get_IsFirstPersonHandNode(const FCk_Handle& InNode)
    {
        auto Character = Cast<AMars_PlayerCharacter>(utils_entity_bridge::TryGet_Actor_Recursive(InNode));
        if (ck::Is_NOT_Valid(Character) || Character.Get_HasEntity() == false
            || Character.Get_IsHandMountFirstPerson() == false)
        { return false; }

        // Characters without gloves (any other pawn) have no first-person hand node.
        const auto Hands = Character.TryGet_Entity().As_FPHands(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Hands) || ck::Is_NOT_Valid(Character.Config))
        { return false; }

        return Character.Config.FPHandsView.FirstPersonRendering == ECk_EnableDisable::Enable && Hands.Get_HandNode() == InNode;
    }

    // How a primitive on InNode is rendered: first-person when InNode hangs (through any number of scene nodes) off the
    // local player's hand node, as a normal world primitive otherwise - including for every other player's view of it.
    EFirstPersonPrimitiveType Get_FirstPersonType(const FCk_Handle& InNode)
    {
        FCk_Handle Node = InNode;
        for (int32 Depth = 0; Depth < constants_fphands_view::k_MaxAttachDepth; ++Depth)
        {
            if (ck::Is_NOT_Valid(Node))
            { return EFirstPersonPrimitiveType::None; }

            if (Get_IsFirstPersonHandNode(Node))
            { return EFirstPersonPrimitiveType::FirstPerson; }

            const auto SceneNode = Node.As_SceneNode(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(SceneNode))
            { return EFirstPersonPrimitiveType::None; }

            Node = SceneNode.Get_Parent();
        }

        ck::EnsureIfNot(false,
            f"[FPHands] [{InNode.ToString()}] is attached more than [{constants_fphands_view::k_MaxAttachDepth}] scene nodes deep - rendered as a world primitive");
        return EFirstPersonPrimitiveType::None;
    }

    // Re-evaluates InRoot (a held or released item) and renders every primitive in its entity tree accordingly (meshes,
    // a skeletal book, a flame's card and effect). Call when the item is attached under, or released from, a hand.
    void Apply_FirstPersonType(const FCk_Handle& InRoot)
    {
        const auto Type = Get_FirstPersonType(InRoot);
        for (auto Primitive : Get_TreePrimitives(InRoot))
        { Primitive.SetFirstPersonPrimitiveType(Type); }
    }

    // Re-evaluates everything mounted on InMount (each scene-node child is an item's root), after InMount itself moved
    // under or away from a hand: the items' own mounts did not change, so nothing else re-tags them.
    void Apply_FirstPersonTypeToMounted(const FCk_Handle_Transform& InMount)
    {
        for (auto Child : Get_MountedRoots(InMount))
        { Apply_FirstPersonType(Child); }
    }

    // Every primitive of what is mounted on InMount (each scene-node child's entity tree).
    TArray<UPrimitiveComponent> Get_MountedPrimitives(const FCk_Handle_Transform& InMount)
    {
        TArray<UPrimitiveComponent> Primitives;
        for (auto Child : Get_MountedRoots(InMount))
        { Primitives.Append(Get_TreePrimitives(Child)); }

        return Primitives;
    }

    // InMount's scene-node children: the roots of what it carries, whoever owns their lifetime.
    TArray<FCk_Handle> Get_MountedRoots(const FCk_Handle_Transform& InMount)
    {
        TArray<FCk_Handle> Roots;
        if (ck::Is_NOT_Valid(InMount))
        { return Roots; }

        auto Mount = InMount;
        for (auto Child : utils_scene_node::ForEach_SceneNode(Mount, FInstancedStruct(), FCk_Lambda_InHandle()))
        {
            FCk_Handle ChildEntity = Child;
            Roots.Add(ChildEntity);
        }

        return Roots;
    }

    // Every primitive component of InRoot's transform tree (Get_TransformTree).
    TArray<UPrimitiveComponent> Get_TreePrimitives(const FCk_Handle& InRoot)
    {
        TArray<UPrimitiveComponent> Primitives;
        for (auto Entity : Get_TransformTree(InRoot))
        {
            for (auto Component : utils_unreal_component::Get_ComponentsByType(Entity, UPrimitiveComponent))
            {
                auto Primitive = Cast<UPrimitiveComponent>(Component);
                if (ck::IsValid(Primitive))
                { Primitives.Add(Primitive); }
            }
        }
        return Primitives;
    }
}
