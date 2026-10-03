// Where the first-person gloves take hold of something.
//
// Authored grips are static mesh sockets:
//   Grip_R + Grip_L   both gloves (two-handed)
//   Grip (or Grip_R)  the right glove alone
// A socket's transform is where that glove's grip bone goes: X along the handle, ACROSS the palm from the little finger
// toward the index finger (not along the fingers), Z out of the palm - the grip_r / grip_l bone axes of SK_FPHands.
// A flat hand with its fingers pointing forward therefore has X pointing to its thumb side. Without sockets, pickups are taken by their sides (fitted to the
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

    // The entity whose static mesh carries the sockets (entity-built mechanisms only). A reach anchors to it, so the gloves
    // follow a moving part - a lever's handle - rather than the object's root.
    UPROPERTY()
    FCk_Handle_Transform Host;
}

enum EMars_Hand
{
    Right,
    Left
}

// Whether an authored grip keeps its exact rotation or only its bar. FaceViewer: the grip names a bar (its X axis through
// its location) and the glove takes it the way it would from where the player stands - which end the index finger points
// to and the roll around the bar are chosen at reach time, closest to the glove's rest pose. Mechanism sockets (levers,
// chains, wheels) face the viewer; item sockets and grip-table entries are Fixed unless they ask.
enum EMars_FPHands_GripRoll
{
    Fixed,
    FaceViewer
}

// How a socketless grip entry orients the glove (an entry with a socket always matches the socket).
enum EMars_FPHands_GripFrame
{
    // A point grip at the node: the glove keeps its own rotation, turned partly toward the grip (ReachSpec.AimFraction).
    Aimed,
    // The node's own axes are the grip, authored like a socket (X across the palm toward the index finger, Z out of the
    // palm): rotate the node to pose the glove.
    Node
}

// One glove's grip on a reach target: its own anchor (a part that may move on its own) and the grip in that anchor's space.
struct FMars_FPHands_HandGrip
{
    UPROPERTY()
    bool IsUsed = false;

    UPROPERTY()
    FCk_Handle_Transform Anchor;

    // Last known anchor transform; kept once the anchor is gone (a picked-up item destroys itself).
    UPROPERTY()
    FTransform AnchorWorld;

    // Anchor space. A point grip uses only the location.
    UPROPERTY()
    FTransform Grip;

    // The grip's rotation is matched, not just its location.
    UPROPERTY()
    bool IsAuthored = false;

    // Set, replaces the spec's MaxReachCm for this grip (cm).
    UPROPERTY()
    TOptional<float32> ReachOverrideCm;

    // Authored grips only: Fixed keeps the grip's rotation; FaceViewer re-rolls it around its bar at reach time.
    UPROPERTY()
    EMars_FPHands_GripRoll Roll = EMars_FPHands_GripRoll::Fixed;

    // The glove's contact pose on this grip; unset = the target's contact pose, else the spec's.
    UPROPERTY()
    bool HasPose = false;

    UPROPERTY()
    EMars_HandGripPose Pose = EMars_HandGripPose::Power;
}

// One row of a grip table: which glove, the part it rides (the part's Mover moves it, the glove follows) and where on it.
struct FMars_FPHands_GripEntry
{
    UPROPERTY()
    EMars_Hand Hand = EMars_Hand::Right;

    UPROPERTY()
    FCk_Handle_Transform Node;

    // A socket on a static mesh the node (or a part under it) carries; NAME_None = the node itself, a point grip.
    UPROPERTY()
    FName Socket;

    UPROPERTY()
    EMars_HandGripPose Pose = EMars_HandGripPose::Power;

    // Set, replaces the spec's MaxReachCm for this grip (cm).
    UPROPERTY()
    TOptional<float32> ReachOverrideCm;

    // Socketless entries only: Aimed = a point grip at the node; Node = the node's own axes are the grip.
    UPROPERTY()
    EMars_FPHands_GripFrame Frame = EMars_FPHands_GripFrame::Aimed;

    // Authored grips (a socket, or Frame Node): Fixed keeps the rotation; FaceViewer takes the bar from the player's side.
    UPROPERTY()
    EMars_FPHands_GripRoll Roll = EMars_FPHands_GripRoll::Fixed;

    FMars_FPHands_GripEntry() {}

    FMars_FPHands_GripEntry(EMars_Hand InHand, FCk_Handle_Transform InNode, FName InSocket, EMars_HandGripPose InPose, TOptional<float32> InReachOverrideCm,
                            EMars_FPHands_GripFrame InFrame, EMars_FPHands_GripRoll InRoll)
    {
        Hand = InHand;
        Node = InNode;
        Socket = InSocket;
        Pose = InPose;
        ReachOverrideCm = InReachOverrideCm;
        Frame = InFrame;
        Roll = InRoll;
    }
}

// The grips an interactable's owner declares for the gloves, at most one per hand (utils_fphands::Add_Grips). A reach for
// an owner that carries it takes these grips instead of the socket / sides / point resolution.
struct FMars_Fragment_FPHands_Grips
{
    UPROPERTY()
    TArray<FMars_FPHands_GripEntry> Entries;
}

// What a reach (or the focus lean) goes for: one grip per glove, each in its own anchor's space so the glove follows
// that anchor if it moves. A grip table gives each glove its own anchor; every other path anchors both gloves to the same
// part.
struct FMars_FPHands_ReachTarget
{
    UPROPERTY()
    bool IsValid = false;

    // Authored when any glove's grip is a socket; Sides is resolved per glove from SidesCenter / SidesHalfWidth.
    UPROPERTY()
    EMars_FPHands_GripLayout Layout = EMars_FPHands_GripLayout::Point;

    UPROPERTY()
    FMars_FPHands_HandGrip Right;

    UPROPERTY()
    FMars_FPHands_HandGrip Left;

    // Sides: the object's centre (anchor space) and half-width; the gloves take it either side of the view's right axis.
    UPROPERTY()
    FVector SidesCenter;

    UPROPERTY()
    float32 SidesHalfWidth = 0.0f;

    // Pickups: the item mesh the fingers close on (placed by the anchor).
    // Weak: fragments may not hold strong UObject refs (Schema.IsSafe); the item's presentation owns the mesh.
    UPROPERTY()
    TWeakObjectPtr<UStaticMesh> ShapeMesh;

    UPROPERTY()
    FVector ShapeScale = FVector::OneVector;

    UPROPERTY()
    EMars_FPHands_GripShape ShapeType = EMars_FPHands_GripShape::Auto;

    UPROPERTY()
    bool HasContactPose = false;

    UPROPERTY()
    EMars_HandGripPose ContactPose = EMars_HandGripPose::Power;
}

// What the gloves reach for: the interact target, its interactable and the entity the interactable belongs to.
struct FMars_FPHands_ReachSubject
{
    UPROPERTY()
    FCk_Handle_InteractTarget InteractTarget;

    UPROPERTY()
    FCk_Handle_Interactable Interactable;

    UPROPERTY()
    FCk_Handle Owner;

    FMars_FPHands_ReachSubject() {}

    FMars_FPHands_ReachSubject(FCk_Handle_InteractTarget InInteractTarget, FCk_Handle_Interactable InInteractable, FCk_Handle InOwner)
    {
        InteractTarget = InInteractTarget;
        Interactable = InInteractable;
        Owner = InOwner;
    }
}

// The gloves a reach starts from: what they hold (which decides the free gloves), where the hand node is, and the
// glove single-handed targets near the centre line stay with.
struct FMars_FPHands_HandState
{
    UPROPERTY()
    FMars_FPHands_Hold Hold;

    UPROPERTY()
    FTransform HandWorld;

    UPROPERTY()
    bool PreferRightHand = true;

    // Each glove's rest grip rotation in world (the pose the gloves present from where the player stands); FaceViewer
    // grips are rolled toward it. Identity = unknown (tests that build a hand state by hand): FaceViewer grips stay as
    // authored.
    UPROPERTY()
    FQuat RestGripWorld_R = FQuat::Identity;

    UPROPERTY()
    FQuat RestGripWorld_L = FQuat::Identity;

    FMars_FPHands_HandState() {}

    FMars_FPHands_HandState(FMars_FPHands_Hold InHold, FTransform InHandWorld, bool InPreferRightHand)
    {
        Hold = InHold;
        HandWorld = InHandWorld;
        PreferRightHand = InPreferRightHand;
    }
}

struct FMars_FPHands_ReachQuery
{
    UPROPERTY()
    FMars_FPHands_ReachSubject Subject;

    UPROPERTY()
    FMars_FPHands_HandState Hand;

    FMars_FPHands_ReachQuery() {}

    FMars_FPHands_ReachQuery(FMars_FPHands_ReachSubject InSubject, FMars_FPHands_HandState InHand)
    {
        Subject = InSubject;
        Hand = InHand;
    }
}

// One glove's grip on a target. HandWorld, IsRightHand and RestGrip go in; utils_fphands::Resolve_WorldGrip fills the
// rest, which utils_fphands::Make_ReachedGrip consumes.
struct FMars_FPHands_GripQuery
{
    UPROPERTY()
    FTransform HandWorld;

    UPROPERTY()
    bool IsRightHand = true;

    // The glove's grip at rest, in the hand node's space.
    UPROPERTY()
    FTransform RestGrip;

    UPROPERTY()
    FTransform WorldGrip;

    // The grip's rotation is meant to be matched, not just its location.
    UPROPERTY()
    bool IsAuthored = false;

    // How far short of the grip the glove stops (cm).
    UPROPERTY()
    float Standoff = 0.0;

    // Set, replaces the spec's MaxReachCm for this grip (cm).
    UPROPERTY()
    TOptional<float32> ReachOverrideCm;

    FMars_FPHands_GripQuery() {}

    FMars_FPHands_GripQuery(FTransform InHandWorld, bool InIsRightHand, FTransform InRestGrip)
    {
        HandWorld = InHandWorld;
        IsRightHand = InIsRightHand;
        RestGrip = InRestGrip;
    }
}

namespace utils_fphands
{
    // Declares InOwner's grip table (construction time). All-or-nothing: at least one entry, every node valid, at most one
    // entry per hand; a rejected table ensures and adds nothing.
    void Add_Grips(FCk_Handle& InOwner, const TArray<FMars_FPHands_GripEntry>& InEntries)
    {
        FString Error;
        if (InEntries.Num() == 0)
        { Error = "no entries"; }

        for (int32 Index = 0; Index < InEntries.Num() && Error.IsEmpty(); ++Index)
        {
            if (ck::Is_NOT_Valid(InEntries[Index].Node))
            {
                Error = f"entry [{Index}] has an invalid node";
                continue;
            }

            for (int32 Earlier = 0; Earlier < Index; ++Earlier)
            {
                if (InEntries[Earlier].Hand == InEntries[Index].Hand)
                { Error = f"entry [{Index}] repeats the hand [{InEntries[Index].Hand :n}] of entry [{Earlier}]"; }
            }
        }

        if (ck::EnsureIfNot(Error.IsEmpty(), f"[FPHands] [{InOwner.ToString()}] rejected the grip table: {Error}"))
        { return; }

        auto Grips = FMars_Fragment_FPHands_Grips();
        Grips.Entries = InEntries;
        InOwner.Add_Fragment(Grips);
    }

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

            auto Grips = Find_ComponentSockets(utils_unreal_component::Get_ComponentsByType(Entity, UStaticMeshComponent));
            if (Grips.HasRight)
            {
                Grips.Host = Entity.As_Transform(ECk_SanityCheck::UnChecked);
                return Grips;
            }

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

    // The first static mesh component on InRoot or its descendants that carries InSocket (entity tree scope, as
    // Find_EntitySockets), or null.
    UStaticMeshComponent Find_EntitySocketComponent(const FCk_Handle& InRoot, FName InSocket)
    {
        TArray<FCk_Handle> Queue;
        Queue.Add(InRoot);
        for (int32 Index = 0; Index < Queue.Num() && Index < 64; ++Index)
        {
            auto Entity = Queue[Index];
            if (ck::Is_NOT_Valid(Entity))
            { continue; }

            for (auto Candidate : utils_unreal_component::Get_ComponentsByType(Entity, UStaticMeshComponent))
            {
                auto Component = Cast<UStaticMeshComponent>(Candidate);
                if (ck::IsValid(Component) && Component.DoesSocketExist(InSocket))
                { return Component; }
            }

            for (auto Dependent : Entity.Get_LifetimeDependents())
            { Queue.Add(Dependent); }
        }
        return nullptr;
    }

    // One grip-table row as a glove's grip: anchored to the row's node, on the named socket when the node (or a part
    // under it) carries one, else at the node itself (a point grip).
    FMars_FPHands_HandGrip Make_EntryGrip(const FMars_FPHands_GripEntry& InEntry)
    {
        auto Grip = FMars_FPHands_HandGrip();
        Grip.IsUsed = true;
        Grip.Anchor = InEntry.Node;
        Grip.AnchorWorld = utils_transform::Get_EntityCurrentTransform(InEntry.Node);
        Grip.ReachOverrideCm = InEntry.ReachOverrideCm;
        Grip.HasPose = true;
        Grip.Pose = InEntry.Pose;
        Grip.Roll = InEntry.Roll;
        if (InEntry.Socket == NAME_None)
        {
            // Grip stays identity: the node itself is the grip bone's target, its rotation included under Node.
            Grip.IsAuthored = InEntry.Frame == EMars_FPHands_GripFrame::Node;
            return Grip;
        }

        auto Component = Find_EntitySocketComponent(InEntry.Node, InEntry.Socket);
        if (ck::Is_NOT_Valid(Component))
        {
            ck::Trace(f"[FPHands] grip node [{InEntry.Node.ToString()}] carries no socket [{InEntry.Socket}]; the glove takes the node itself");
            return Grip;
        }

        Grip.Grip = Component.GetSocketTransform(InEntry.Socket, ERelativeTransformSpace::RTS_World).GetRelativeTransform(Grip.AnchorWorld);
        Grip.IsAuthored = true;
        return Grip;
    }

    // A grip table: each glove to its own row. A busy right glove hands its row to the free left glove (whose own row is
    // then dropped), as the socket paths do.
    FMars_FPHands_ReachTarget Resolve_GripTable(const TArray<FMars_FPHands_GripEntry>& InEntries, bool InRightIsFree)
    {
        auto Target = FMars_FPHands_ReachTarget();
        Target.IsValid = true;

        auto RightGrip = FMars_FPHands_HandGrip();
        auto LeftGrip = FMars_FPHands_HandGrip();
        for (const auto& Entry : InEntries)
        {
            if (Entry.Hand == EMars_Hand::Right)
            { RightGrip = Make_EntryGrip(Entry); }
            else
            { LeftGrip = Make_EntryGrip(Entry); }
        }

        if (InRightIsFree)
        {
            Target.Right = RightGrip;
            Target.Left = LeftGrip;
        }
        else if (RightGrip.IsUsed)
        { Target.Left = RightGrip; }
        else
        { Target.Left = LeftGrip; }

        Target.Layout = Target.Right.IsAuthored || Target.Left.IsAuthored
            ? EMars_FPHands_GripLayout::Authored
            : EMars_FPHands_GripLayout::Point;
        return Target;
    }

    // Resolves what the gloves go for when reaching for InQuery's subject. The hold decides which gloves are free;
    // PreferRightHand picks the glove for single-handed reaches near the centre line. An owner with a grip table
    // (FMars_Fragment_FPHands_Grips) decides each glove's grip itself; every other path anchors both gloves to one part.
    FMars_FPHands_ReachTarget Resolve_ReachTarget(const FMars_FPHands_ReachSpec& InSpec, const FMars_FPHands_ReachQuery& InQuery)
    {
        auto Target = Resolve_ReachTarget_AsAuthored(InSpec, InQuery);
        Apply_ViewerFacingRoll(Target, InQuery.Hand);
        return Target;
    }

    // Each used, authored FaceViewer grip re-rolled around its bar toward that glove's rest pose (anchor space, so a moving
    // part carries the chosen grip with it).
    void Apply_ViewerFacingRoll(FMars_FPHands_ReachTarget& InOutTarget, const FMars_FPHands_HandState& InHand)
    {
        if (InOutTarget.IsValid == false)
        { return; }

        Roll_HandGrip(InOutTarget.Right, InHand.RestGripWorld_R);
        Roll_HandGrip(InOutTarget.Left, InHand.RestGripWorld_L);
    }

    void Roll_HandGrip(FMars_FPHands_HandGrip& InOutGrip, const FQuat& InRestWorld)
    {
        if (InOutGrip.IsUsed == false || InOutGrip.IsAuthored == false || InOutGrip.Roll != EMars_FPHands_GripRoll::FaceViewer)
        { return; }

        if (InRestWorld.Equals(FQuat::Identity, 0.0001))
        { return; }

        const auto GripWorld = InOutGrip.Grip * InOutGrip.AnchorWorld;
        const auto Rolled = Make_ViewerFacingGrip(GripWorld.GetRotation(), InRestWorld);
        InOutGrip.Grip.SetRotation(InOutGrip.AnchorWorld.InverseTransformRotation(Rolled));
    }

    // The rotation that keeps InGripWorld's bar (its X axis, either way along it) and is otherwise closest to InRestWorld:
    // for each end the index finger may point to, the palm (Z) turns as near the rest palm direction as the bar allows,
    // and the nearer of the two wins. A rest palm along the bar keeps the authored roll.
    FQuat Make_ViewerFacingGrip(const FQuat& InGripWorld, const FQuat& InRestWorld)
    {
        const auto Bar = InGripWorld.GetForwardVector();
        const auto RestPalm = InRestWorld.GetUpVector();

        auto Best = InGripWorld;
        auto BestDot = -1.0;
        for (int32 Index = 0; Index < 2; ++Index)
        {
            const auto X = Index == 0 ? Bar : -Bar;
            auto Palm = RestPalm - X * RestPalm.DotProduct(X);
            if (Palm.SizeSquared() < 0.000001)
            { Palm = InGripWorld.GetUpVector() - X * InGripWorld.GetUpVector().DotProduct(X); }

            const auto Candidate = FQuat(FRotator::MakeFromXZ(X, Palm.GetSafeNormal()));
            const auto Dot = Math::Abs(Candidate.X * InRestWorld.X + Candidate.Y * InRestWorld.Y
                + Candidate.Z * InRestWorld.Z + Candidate.W * InRestWorld.W);
            if (Dot > BestDot)
            {
                BestDot = Dot;
                Best = Candidate;
            }
        }

        return Best;
    }

    // What the gloves go for, with every authored grip exactly as authored (Resolve_ReachTarget then rolls FaceViewer grips).
    FMars_FPHands_ReachTarget Resolve_ReachTarget_AsAuthored(const FMars_FPHands_ReachSpec& InSpec, const FMars_FPHands_ReachQuery& InQuery)
    {
        const auto& Subject = InQuery.Subject;
        const auto& Hand = InQuery.Hand;

        auto Target = FMars_FPHands_ReachTarget();
        if (Hand.Hold.IsHolding && Hand.Hold.IsTwoHanded)
        { return Target; }

        const auto BothFree = Hand.Hold.IsHolding == false;
        if (ck::IsValid(Subject.Owner) && Subject.Owner.Has_Fragment(FMars_Fragment_FPHands_Grips))
        { return Resolve_GripTable(Subject.Owner.Get_Fragment(FMars_Fragment_FPHands_Grips).Entries, BothFree); }

        auto Anchor = Subject.Owner.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Anchor))
        { Anchor = Subject.Interactable.As_Transform(ECk_SanityCheck::UnChecked); }
        if (ck::Is_NOT_Valid(Anchor))
        { return Target; }

        Target.IsValid = true;
        auto Shared = FMars_FPHands_HandGrip();
        Shared.Anchor = Anchor;
        Shared.AnchorWorld = utils_transform::Get_EntityCurrentTransform(Anchor);

        // Pickups: the item's own mesh, grip pose and handedness.
        if (Subject.Owner.Has_Fragment(FMars_Fragment_WorldItem_Params))
        {
            auto Definition = System::LoadAsset_Blocking(Subject.Owner.Get_Fragment(FMars_Fragment_WorldItem_Params).Definition);
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
                    Shared.IsAuthored = true;
                    Target.Layout = EMars_FPHands_GripLayout::Authored;
                    Target.Right = Shared;
                    Target.Left = Shared;
                    Target.Right.Grip = Sockets.Right;
                    Target.Left.Grip = Sockets.Left;
                    Target.Right.IsUsed = BothFree;
                    Target.Left.IsUsed = Sockets.HasLeft && BothFree;
                    if (BothFree == false)
                    {
                        // Right glove busy: the free left glove takes the right grip.
                        Target.Left.Grip = Sockets.Right;
                        Target.Left.IsUsed = true;
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
                    Target.Right = Shared;
                    Target.Left = Shared;
                    Target.Right.IsUsed = true;
                    Target.Left.IsUsed = true;
                    return Target;
                }
            }
        }

        // Grip sockets on the object's meshes: entity-built mechanisms (lever, hand wheel), then plain actors.
        auto ActorSockets = Find_EntitySockets(Subject.Owner);
        if (ActorSockets.HasRight == false)
        { ActorSockets = Find_ActorSockets(utils_owning_actor::TryGet_EntityOwningActor_Recursive(Subject.Owner)); }
        if (ActorSockets.HasRight)
        {
            // The part carrying the sockets may move on its own (a lever's handle under its Mover node): anchor to it.
            if (ck::IsValid(ActorSockets.Host))
            {
                Shared.Anchor = ActorSockets.Host;
                Shared.AnchorWorld = utils_transform::Get_EntityCurrentTransform(ActorSockets.Host);
            }

            Shared.IsAuthored = true;
            Shared.Roll = EMars_FPHands_GripRoll::FaceViewer;
            Target.Layout = EMars_FPHands_GripLayout::Authored;
            Target.Right = Shared;
            Target.Left = Shared;
            Target.Right.Grip = ActorSockets.Right.GetRelativeTransform(Shared.AnchorWorld);
            Target.Left.Grip = ActorSockets.HasLeft ? ActorSockets.Left.GetRelativeTransform(Shared.AnchorWorld) : Target.Right.Grip;
            Target.Right.IsUsed = BothFree;
            Target.Left.IsUsed = (ActorSockets.HasLeft && BothFree) || BothFree == false;
            return Target;
        }

        // Plain interactable: one glove to its interaction point.
        auto PointEntity = Subject.Interactable.As_Transform(ECk_SanityCheck::UnChecked);
        const auto PointWorld = ck::IsValid(PointEntity)
            ? utils_transform::Get_EntityCurrentTransform(PointEntity).GetLocation()
            : Shared.AnchorWorld.GetLocation();

        Target.Layout = EMars_FPHands_GripLayout::Point;
        Shared.Grip = FTransform(FRotator::ZeroRotator, Shared.AnchorWorld.InverseTransformPosition(PointWorld), FVector::OneVector);

        auto IsRight = Hand.PreferRightHand;
        if (BothFree)
        {
            const auto SideY = Hand.HandWorld.InverseTransformPosition(PointWorld).Y;
            if (Math::Abs(SideY) > InSpec.SideSwitchMarginCm)
            { IsRight = SideY > 0.0; }
        }
        else
        { IsRight = false; }

        Target.Right = Shared;
        Target.Left = Shared;
        Target.Right.IsUsed = IsRight;
        Target.Left.IsUsed = IsRight == false;
        return Target;
    }

    // Refreshes each used glove's anchor while it lives.
    void Update_ReachTarget(FMars_FPHands_ReachTarget& InOutTarget)
    {
        if (InOutTarget.IsValid == false)
        { return; }

        if (InOutTarget.Right.IsUsed && ck::IsValid(InOutTarget.Right.Anchor))
        { InOutTarget.Right.AnchorWorld = utils_transform::Get_EntityCurrentTransform(InOutTarget.Right.Anchor); }

        if (InOutTarget.Left.IsUsed && ck::IsValid(InOutTarget.Left.Anchor))
        { InOutTarget.Left.AnchorWorld = utils_transform::Get_EntityCurrentTransform(InOutTarget.Left.Anchor); }
    }

    // World-space grip on InTarget for InOutGrip's glove, whether its rotation is meant to be matched, the standoff a
    // point grip keeps and the glove's reach override.
    void Resolve_WorldGrip(const FMars_FPHands_Spec& InSpec, const FMars_FPHands_ReachTarget& InTarget, FMars_FPHands_GripQuery& InOutGrip)
    {
        const auto Hand = InTarget.Get_HandGrip(InOutGrip.IsRightHand);
        const auto IsSides = InTarget.Layout == EMars_FPHands_GripLayout::Sides;
        InOutGrip.IsAuthored = Hand.IsAuthored;
        InOutGrip.Standoff = IsSides || Hand.IsAuthored ? 0.0f : InSpec.Reach.StandoffCm;
        InOutGrip.ReachOverrideCm = Hand.ReachOverrideCm;
        if (IsSides)
        {
            const auto Center = Hand.AnchorWorld.TransformPosition(InTarget.SidesCenter);
            const auto Side = InOutGrip.HandWorld.GetRotation().GetRightVector() * (InTarget.SidesHalfWidth + InSpec.PalmSurfaceOffset);
            InOutGrip.WorldGrip = FTransform(FRotator::ZeroRotator, InOutGrip.IsRightHand ? Center + Side : Center - Side, FVector::OneVector);
            return;
        }

        InOutGrip.WorldGrip = Hand.Grip * Hand.AnchorWorld;
    }

    bool Get_UsesHand(const FMars_FPHands_ReachTarget& InTarget, bool InIsRightHand)
    {
        return InTarget.IsValid && InTarget.Get_HandGrip(InIsRightHand).IsUsed;
    }
}

// One glove's grip on the target. Get_HandGrip(Target.Right.IsUsed) is the glove that leads (the right when both are used).
mixin FMars_FPHands_HandGrip Get_HandGrip(const FMars_FPHands_ReachTarget& Self, bool InIsRightHand)
{
    if (InIsRightHand)
    { return Self.Right; }

    return Self.Left;
}
