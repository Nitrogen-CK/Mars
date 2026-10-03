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

    // InNode is the hand node of the gloves of the character this machine controls, with first-person rendering on.
    bool Get_IsFirstPersonHandNode(const FCk_Handle& InNode)
    {
        auto Character = Cast<ACharacter>(utils_owning_actor::TryGet_EntityOwningActor_Recursive(InNode));
        if (ck::Is_NOT_Valid(Character) || Character.IsLocallyControlled() == false || Character.Get_IsActorEcsReady() == false)
        { return false; }

        // Characters without gloves (any other pawn) have no first-person hand node.
        const auto Hands = Character.TryGet_ActorEntityHandle().As_FPHands(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Hands))
        { return false; }

        return Hands.Get_Spec().View.FirstPersonRendering == ECk_EnableDisable::Enable && Hands.Get_HandNode() == InNode;
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

    // Re-evaluates InRoot (a held or released item) and renders every static mesh in its entity tree accordingly. Call
    // when the item is attached under, or released from, a hand.
    void Apply_FirstPersonType(const FCk_Handle& InRoot)
    {
        const auto Type = Get_FirstPersonType(InRoot);
        for (auto Entity : Get_TransformTree(InRoot))
        {
            for (auto Component : utils_unreal_component::Get_ComponentsByType(Entity, UStaticMeshComponent))
            {
                auto Primitive = Cast<UPrimitiveComponent>(Component);
                if (ck::IsValid(Primitive))
                { Primitive.SetFirstPersonPrimitiveType(Type); }
            }
        }
    }
}
