// Where the first-person gloves take hold of something.
//
// Authored grips are static mesh sockets:
//   Grip_R + Grip_L   both gloves (two-handed)
//   Grip (or Grip_R)  the right glove alone
// A socket's transform is where that glove's grip bone goes: X along the handle toward the index finger, Z out of the
// palm - the grip_r / grip_l bone axes of SK_FPHands. Without sockets, pickups are taken by their sides (fitted to the
// mesh bounds) and other interactables are reached at their interaction point.
enum EMars_FPHands_GripLayout
{
    Point,
    Authored,
    Sides
}

// Grips found on a mesh, in the mesh's space (MeshScale applied to locations).
struct FMars_FPHands_MeshGrips
{
    UPROPERTY()
    bool HasRight = false;

    UPROPERTY()
    bool HasLeft = false;

    UPROPERTY()
    FTransform Right;

    UPROPERTY()
    FTransform Left;
}

// What a reach (or the focus lean) goes for. Grips are in the anchor's space so the gloves follow it if it moves.
struct FMars_FPHands_ReachTarget
{
    UPROPERTY()
    bool IsValid = false;

    UPROPERTY()
    FCk_Handle_Transform Anchor;

    // Last known anchor transform; kept once the anchor is gone (a picked-up item destroys itself).
    UPROPERTY()
    FTransform AnchorWorld;

    UPROPERTY()
    EMars_FPHands_GripLayout Layout = EMars_FPHands_GripLayout::Point;

    UPROPERTY()
    bool UsesRight = false;

    UPROPERTY()
    bool UsesLeft = false;

    // Authored: full grip transforms. Point: only the location is used.
    UPROPERTY()
    FTransform Grip_R;

    UPROPERTY()
    FTransform Grip_L;

    // Sides: the object's centre (anchor space) and half-width; the gloves take it either side of the view's right axis.
    UPROPERTY()
    FVector SidesCenter;

    UPROPERTY()
    float32 SidesHalfWidth = 0.0f;

    // Pickups: the item mesh the fingers close on (placed by the anchor).
    UPROPERTY()
    UStaticMesh ShapeMesh;

    UPROPERTY()
    FVector ShapeScale = FVector::OneVector;

    UPROPERTY()
    EMars_FPHands_GripShape ShapeType = EMars_FPHands_GripShape::Auto;

    UPROPERTY()
    bool HasContactPose = false;

    UPROPERTY()
    EMars_HandGripPose ContactPose = EMars_HandGripPose::Power;
}

namespace mars_fphands_grips
{
    FMars_FPHands_MeshGrips Find_MeshSockets(UStaticMesh InMesh, const FVector& InMeshScale)
    {
        auto Grips = FMars_FPHands_MeshGrips();
        if (ck::Is_NOT_Valid(InMesh))
        { return Grips; }

        auto Right = InMesh.FindSocket(n"Grip_R");
        auto Left = InMesh.FindSocket(n"Grip_L");
        if (ck::Is_NOT_Valid(Right))
        { Right = InMesh.FindSocket(n"Grip"); }

        if (ck::IsValid(Right))
        {
            Grips.HasRight = true;
            Grips.Right = FTransform(Right.RelativeRotation, Right.RelativeLocation * InMeshScale, FVector::OneVector);
        }

        // A left grip only counts alongside a right one: one-handed holds are always the right glove.
        if (ck::IsValid(Left) && Grips.HasRight)
        {
            Grips.HasLeft = true;
            Grips.Left = FTransform(Left.RelativeRotation, Left.RelativeLocation * InMeshScale, FVector::OneVector);
        }

        return Grips;
    }

    // Grip sockets on the first static mesh component that has them, in world space.
    FMars_FPHands_MeshGrips Find_ComponentSockets(const TArray<UActorComponent>& InComponents)
    {
        auto Grips = FMars_FPHands_MeshGrips();
        for (auto Candidate : InComponents)
        {
            auto Component = Cast<UStaticMeshComponent>(Candidate);
            if (ck::Is_NOT_Valid(Component))
            { continue; }

            auto RightName = Component.DoesSocketExist(n"Grip_R") ? n"Grip_R" : n"Grip";
            if (Component.DoesSocketExist(RightName) == false)
            { continue; }

            Grips.HasRight = true;
            Grips.Right = Component.GetSocketTransform(RightName, ERelativeTransformSpace::RTS_World);
            if (Component.DoesSocketExist(n"Grip_L"))
            {
                Grips.HasLeft = true;
                Grips.Left = Component.GetSocketTransform(n"Grip_L", ERelativeTransformSpace::RTS_World);
            }
            return Grips;
        }
        return Grips;
    }

    // Grip sockets on the static meshes an entity and its descendants own (entity-built mechanisms: their components
    // live on a shared component host actor, so the entity tree is what scopes them to this object).
    FMars_FPHands_MeshGrips Find_EntitySockets(const FCk_Handle& InRoot)
    {
        TArray<FCk_Handle> Queue;
        Queue.Add(InRoot);
        for (int32 Index = 0; Index < Queue.Num() && Index < 64; ++Index)
        {
            auto Entity = Queue[Index];
            if (ck::Is_NOT_Valid(Entity))
            { continue; }

            const auto Grips = Find_ComponentSockets(utils_unreal_component::Get_ComponentsByType(Entity, UStaticMeshComponent));
            if (Grips.HasRight)
            { return Grips; }

            for (auto Dependent : Entity.Get_LifetimeDependents())
            { Queue.Add(Dependent); }
        }
        return FMars_FPHands_MeshGrips();
    }

    // Grip sockets on an actor's own static mesh components (plain actors like Mars_TestLamp).
    FMars_FPHands_MeshGrips Find_ActorSockets(AActor InActor)
    {
        if (ck::Is_NOT_Valid(InActor))
        { return FMars_FPHands_MeshGrips(); }

        return Find_ComponentSockets(InActor.GetComponentsByClass(UStaticMeshComponent));
    }

    // Resolves what the gloves go for when reaching for InInteractable. InHold decides which gloves are free;
    // InPreferRight picks the glove for single-handed reaches near the centre line.
    FMars_FPHands_ReachTarget Resolve(
        const FMars_FPHands_Spec& InSpec,
        const FMars_FPHands_Hold& InHold,
        const FCk_Handle_Interactable& InInteractable,
        const FCk_Handle& InOwner,
        const FTransform& InHandWorld,
        bool InPreferRight)
    {
        auto Target = FMars_FPHands_ReachTarget();
        if (InHold.IsHolding && InHold.IsTwoHanded)
        { return Target; }

        auto Anchor = InOwner.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Anchor))
        { Anchor = InInteractable.As_Transform(ECk_SanityCheck::UnChecked); }
        if (ck::Is_NOT_Valid(Anchor))
        { return Target; }

        Target.IsValid = true;
        Target.Anchor = Anchor;
        Target.AnchorWorld = utils_transform::Get_EntityCurrentTransform(Anchor);
        const auto BothFree = InHold.IsHolding == false;

        // Pickups: the item's own mesh, grip pose and handedness.
        if (InOwner.Has_Fragment(FMars_Fragment_WorldItem_Params))
        {
            auto Definition = System::LoadAsset_Blocking(InOwner.Get_Fragment(FMars_Fragment_WorldItem_Params).Definition);
            const UMars_ItemTrait_Presentation Presentation = nullptr;
            if (ck::IsValid(Definition))
            { Presentation = Definition.Get_ItemTraitByClass(UMars_ItemTrait_Presentation); }

            if (ck::IsValid(Presentation))
            {
                Target.HasContactPose = true;
                Target.ContactPose = Presentation.GripPose;

                UStaticMesh Mesh = nullptr;
                if (Presentation.Mesh.IsNull() == false)
                { Mesh = System::LoadAsset_Blocking(Presentation.Mesh); }

                Target.ShapeMesh = Mesh;
                Target.ShapeScale = Presentation.MeshScale;
                Target.ShapeType = Presentation.GripShape;
                const auto Sockets = Find_MeshSockets(Mesh, Presentation.MeshScale);
                if (Sockets.HasRight)
                {
                    Target.Layout = EMars_FPHands_GripLayout::Authored;
                    Target.Grip_R = Sockets.Right;
                    Target.Grip_L = Sockets.Left;
                    Target.UsesRight = BothFree;
                    Target.UsesLeft = Sockets.HasLeft && BothFree;
                    if (BothFree == false)
                    {
                        // Right glove busy: the free left glove takes the right grip.
                        Target.Grip_L = Sockets.Right;
                        Target.UsesLeft = true;
                    }
                    return Target;
                }

                if (ck::IsValid(Mesh) && Presentation.IsTwoHanded && BothFree)
                {
                    const auto Bounds = Mesh.GetBounds();
                    const auto Extent = Bounds.BoxExtent * Presentation.MeshScale;
                    Target.Layout = EMars_FPHands_GripLayout::Sides;
                    Target.SidesCenter = Bounds.Origin * Presentation.MeshScale;
                    Target.SidesHalfWidth = Presentation.GripHalfWidth > 0.0f
                        ? Presentation.GripHalfWidth
                        : float32(Math::Max(Extent.X, Extent.Y));
                    Target.UsesRight = true;
                    Target.UsesLeft = true;
                    return Target;
                }
            }
        }

        // Grip sockets on the object's meshes: entity-built mechanisms (lever, hand wheel), then plain actors.
        auto ActorSockets = Find_EntitySockets(InOwner);
        if (ActorSockets.HasRight == false)
        { ActorSockets = Find_ActorSockets(utils_owning_actor::TryGet_EntityOwningActor_Recursive(InOwner)); }
        if (ActorSockets.HasRight)
        {
            Target.Layout = EMars_FPHands_GripLayout::Authored;
            Target.Grip_R = ActorSockets.Right.GetRelativeTransform(Target.AnchorWorld);
            Target.Grip_L = ActorSockets.HasLeft ? ActorSockets.Left.GetRelativeTransform(Target.AnchorWorld) : Target.Grip_R;
            Target.UsesRight = BothFree;
            Target.UsesLeft = (ActorSockets.HasLeft && BothFree) || BothFree == false;
            return Target;
        }

        // Plain interactable: one glove to its interaction point.
        auto PointEntity = InInteractable.As_Transform(ECk_SanityCheck::UnChecked);
        const auto PointWorld = ck::IsValid(PointEntity)
            ? utils_transform::Get_EntityCurrentTransform(PointEntity).GetLocation()
            : Target.AnchorWorld.GetLocation();

        Target.Layout = EMars_FPHands_GripLayout::Point;
        Target.Grip_R = FTransform(FRotator::ZeroRotator, Target.AnchorWorld.InverseTransformPosition(PointWorld), FVector::OneVector);
        Target.Grip_L = Target.Grip_R;

        auto IsRight = InPreferRight;
        if (BothFree)
        {
            const auto SideY = InHandWorld.InverseTransformPosition(PointWorld).Y;
            if (Math::Abs(SideY) > InSpec.Reach.SideSwitchMarginCm)
            { IsRight = SideY > 0.0; }
        }
        else
        { IsRight = false; }

        Target.UsesRight = IsRight;
        Target.UsesLeft = IsRight == false;
        return Target;
    }

    // Refreshes the anchor while it lives.
    void Update(FMars_FPHands_ReachTarget& InOutTarget)
    {
        if (InOutTarget.IsValid && ck::IsValid(InOutTarget.Anchor))
        { InOutTarget.AnchorWorld = utils_transform::Get_EntityCurrentTransform(InOutTarget.Anchor); }
    }

    // World-space grip for one glove. OutIsAuthored: the rotation is meant to be matched (not just the location).
    FTransform Get_WorldGrip(const FMars_FPHands_Spec& InSpec, const FMars_FPHands_ReachTarget& InTarget, const FTransform& InHandWorld,
                             bool InIsRightHand, bool& OutIsAuthored)
    {
        OutIsAuthored = InTarget.Layout == EMars_FPHands_GripLayout::Authored;
        if (InTarget.Layout == EMars_FPHands_GripLayout::Sides)
        {
            const auto Center = InTarget.AnchorWorld.TransformPosition(InTarget.SidesCenter);
            const auto Side = InHandWorld.GetRotation().GetRightVector() * (InTarget.SidesHalfWidth + InSpec.PalmSurfaceOffset);
            return FTransform(FRotator::ZeroRotator, InIsRightHand ? Center + Side : Center - Side, FVector::OneVector);
        }

        const auto Grip = InIsRightHand ? InTarget.Grip_R : InTarget.Grip_L;
        return Grip * InTarget.AnchorWorld;
    }

    bool Uses(const FMars_FPHands_ReachTarget& InTarget, bool InIsRightHand)
    {
        return InTarget.IsValid && (InIsRightHand ? InTarget.UsesRight : InTarget.UsesLeft);
    }
}
