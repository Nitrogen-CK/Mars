// Where the first-person gloves take hold of something.
//
// Authored grips are static mesh sockets:
//   Grip_R + Grip_L   both gloves (two-handed)
//   Grip (or Grip_R)  the right glove alone
// A socket's transform is where that glove's grip bone goes: X along the handle, ACROSS the palm from the little finger
// toward the index finger (not along the fingers), Z out of the palm - the grip_r / grip_l bone axes of SK_FPHands.
// A flat hand with its fingers pointing forward therefore has X pointing to its thumb side. Without sockets, pickups are
// taken by their sides (fitted to the mesh bounds) and other interactables are reached at their interaction point.
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
    FTransform Right;

    // Unset: a one-handed grip, the right glove alone.
    UPROPERTY()
    TOptional<FTransform> Left;

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
    // A point grip at the node: the glove keeps its own rotation, turned partly toward the grip (ReachSpec.Stretch.AimFraction).
    Aimed,
    // The node's own axes are the grip, authored like a socket (X across the palm toward the index finger, Z out of the
    // palm): rotate the node to pose the glove.
    Node
}

// One glove's grip on a reach target: its own anchor (a part that may move on its own) and the grip in that anchor's space.
struct FMars_FPHands_HandGrip
{
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
    TOptional<EMars_HandGripPose> Pose;
}

// One row of a grip table: which glove, the part it rides (the part's Mover moves it, the glove follows) and where on it.
struct FMars_FPHands_GripEntry
{
    UPROPERTY()
    EMars_Hand Hand = EMars_Hand::Right;

    UPROPERTY()
    FCk_Handle_Transform Node;

    // A socket on a static mesh the node (or a part under it) carries; unset = the node itself, a point grip.
    UPROPERTY()
    TOptional<FName> Socket;

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

    FMars_FPHands_GripEntry(EMars_Hand InHand, FCk_Handle_Transform InNode, TOptional<FName> InSocket, EMars_HandGripPose InPose,
                            TOptional<float32> InReachOverrideCm, EMars_FPHands_GripFrame InFrame, EMars_FPHands_GripRoll InRoll)
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

// Sides layout: the object's centre (anchor space) and half-width; the gloves take it either side of the view's right axis.
struct FMars_FPHands_Sides
{
    UPROPERTY()
    FVector Center;

    UPROPERTY()
    float32 HalfWidth = 0.0f;
}

// What a reach (or the focus lean) goes for: one grip per glove, each in its own anchor's space so the glove follows
// that anchor if it moves. A grip table gives each glove its own anchor; every other path anchors both gloves to the same
// part. A resolved target uses at least one glove.
struct FMars_FPHands_ReachTarget
{
    // Authored when any glove's grip is a socket; Sides is resolved per glove from Sides.
    UPROPERTY()
    EMars_FPHands_GripLayout Layout = EMars_FPHands_GripLayout::Point;

    // Unset: that glove takes no part in the reach.
    UPROPERTY()
    TOptional<FMars_FPHands_HandGrip> Right;

    UPROPERTY()
    TOptional<FMars_FPHands_HandGrip> Left;

    UPROPERTY()
    FMars_FPHands_Sides Sides;

    // Pickups: the item mesh the fingers close on (placed by the anchor).
    UPROPERTY()
    FMars_FPHands_ShapeMesh Shape;

    // Pickups: the item's grip pose. Unset = each grip's own pose, else the spec's.
    UPROPERTY()
    TOptional<EMars_HandGripPose> ContactPose;
}

// What the gloves reach for: the interactable, the entity it belongs to, and the interact target when the reach serves
// an interaction.
struct FMars_FPHands_ReachSubject
{
    // Unset: reached without an interaction (the focus lean, a target-less test reach).
    UPROPERTY()
    TOptional<FCk_Handle_InteractTarget> InteractTarget;

    UPROPERTY()
    FCk_Handle_Interactable Interactable;

    UPROPERTY()
    FCk_Handle Owner;

    FMars_FPHands_ReachSubject() {}

    FMars_FPHands_ReachSubject(FCk_Handle_Interactable InInteractable, FCk_Handle InOwner)
    {
        Interactable = InInteractable;
        Owner = InOwner;
    }

    FMars_FPHands_ReachSubject(FCk_Handle_InteractTarget InInteractTarget, FCk_Handle_Interactable InInteractable, FCk_Handle InOwner)
    {
        InteractTarget = TOptional<FCk_Handle_InteractTarget>(InInteractTarget);
        Interactable = InInteractable;
        Owner = InOwner;
    }
}

// Each glove's rest grip rotation in world: the pose the gloves present from where the player stands.
struct FMars_FPHands_GloveRotations
{
    UPROPERTY()
    FQuat Right;

    UPROPERTY()
    FQuat Left;

    FMars_FPHands_GloveRotations() {}

    FMars_FPHands_GloveRotations(FQuat InRight, FQuat InLeft)
    {
        Right = InRight;
        Left = InLeft;
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
    EMars_Hand PreferredHand = EMars_Hand::Right;

    // FaceViewer grips are rolled toward it. Unset (tests that build a hand state by hand): FaceViewer grips stay as
    // authored.
    UPROPERTY()
    TOptional<FMars_FPHands_GloveRotations> RestGripWorld;

    FMars_FPHands_HandState() {}

    FMars_FPHands_HandState(FMars_FPHands_Hold InHold, FTransform InHandWorld, EMars_Hand InPreferredHand)
    {
        Hold = InHold;
        HandWorld = InHandWorld;
        PreferredHand = InPreferredHand;
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

// One glove's grip on a target. HandWorld, Hand and RestGrip go in; utils_fphands::Resolve_WorldGrip fills the rest,
// which utils_fphands::Make_ReachedGrip consumes.
struct FMars_FPHands_GripQuery
{
    UPROPERTY()
    FTransform HandWorld;

    UPROPERTY()
    EMars_Hand Hand = EMars_Hand::Right;

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

    FMars_FPHands_GripQuery(FTransform InHandWorld, EMars_Hand InHand, FTransform InRestGrip)
    {
        HandWorld = InHandWorld;
        Hand = InHand;
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

    // Unset when the mesh has no right grip socket.
    TOptional<FMars_FPHands_MeshGrips> Find_MeshSockets(UStaticMesh InMesh, const FVector& InMeshScale)
    {
        if (ck::Is_NOT_Valid(InMesh))
        { return TOptional<FMars_FPHands_MeshGrips>(); }

        auto Right = InMesh.FindSocket(n"Grip_R");
        if (ck::Is_NOT_Valid(Right))
        { Right = InMesh.FindSocket(n"Grip"); }

        if (ck::Is_NOT_Valid(Right))
        { return TOptional<FMars_FPHands_MeshGrips>(); }

        auto Grips = FMars_FPHands_MeshGrips();
        Grips.Right = FTransform(Right.RelativeRotation, Right.RelativeLocation * InMeshScale, FVector::OneVector);

        // A left grip only counts alongside a right one: one-handed holds are always the right glove.
        auto Left = InMesh.FindSocket(n"Grip_L");
        if (ck::IsValid(Left))
        { Grips.Left = TOptional<FTransform>(FTransform(Left.RelativeRotation, Left.RelativeLocation * InMeshScale, FVector::OneVector)); }

        return TOptional<FMars_FPHands_MeshGrips>(Grips);
    }

    // Grip sockets on the first static mesh component that has them, in world space.
    TOptional<FMars_FPHands_MeshGrips> Find_ComponentSockets(const TArray<UActorComponent>& InComponents)
    {
        for (auto Candidate : InComponents)
        {
            auto Component = Cast<UStaticMeshComponent>(Candidate);
            if (ck::Is_NOT_Valid(Component))
            { continue; }

            auto RightName = Component.DoesSocketExist(n"Grip_R") ? n"Grip_R" : n"Grip";
            if (Component.DoesSocketExist(RightName) == false)
            { continue; }

            auto Grips = FMars_FPHands_MeshGrips();
            Grips.Right = Component.GetSocketTransform(RightName, ERelativeTransformSpace::RTS_World);
            if (Component.DoesSocketExist(n"Grip_L"))
            { Grips.Left = TOptional<FTransform>(Component.GetSocketTransform(n"Grip_L", ERelativeTransformSpace::RTS_World)); }

            return TOptional<FMars_FPHands_MeshGrips>(Grips);
        }
        return TOptional<FMars_FPHands_MeshGrips>();
    }

    // Grip sockets on the static meshes an entity and its transform descendants own (entity-built mechanisms: their
    // components live on a shared component host actor, so the entity tree is what scopes them to this object).
    TOptional<FMars_FPHands_MeshGrips> Find_EntitySockets(const FCk_Handle& InRoot)
    {
        for (auto Entity : Get_TransformTree(InRoot))
        {
            auto Grips = Find_ComponentSockets(utils_unreal_component::Get_ComponentsByType(Entity, UStaticMeshComponent));
            if (Grips.IsSet())
            {
                // The root itself may carry no transform; the reach then anchors to the owner as a whole.
                auto Found = Grips.GetValue();
                Found.Host = Entity.As_Transform(ECk_SanityCheck::UnChecked);
                return TOptional<FMars_FPHands_MeshGrips>(Found);
            }
        }
        return TOptional<FMars_FPHands_MeshGrips>();
    }

    // Grip sockets on an actor's own static mesh components (plain actors like Mars_TestLamp).
    TOptional<FMars_FPHands_MeshGrips> Find_ActorSockets(AActor InActor)
    {
        if (ck::Is_NOT_Valid(InActor))
        { return TOptional<FMars_FPHands_MeshGrips>(); }

        return Find_ComponentSockets(InActor.GetComponentsByClass(UStaticMeshComponent));
    }

    // The first static mesh component on InRoot or its transform descendants that carries InSocket, or null.
    UStaticMeshComponent Find_EntitySocketComponent(const FCk_Handle& InRoot, FName InSocket)
    {
        for (auto Entity : Get_TransformTree(InRoot))
        {
            for (auto Candidate : utils_unreal_component::Get_ComponentsByType(Entity, UStaticMeshComponent))
            {
                auto Component = Cast<UStaticMeshComponent>(Candidate);
                if (ck::IsValid(Component) && Component.DoesSocketExist(InSocket))
                { return Component; }
            }
        }
        return nullptr;
    }

    // One grip-table row as a glove's grip: anchored to the row's node, on the named socket when the node (or a part
    // under it) carries one, else at the node itself (a point grip).
    FMars_FPHands_HandGrip Make_EntryGrip(const FMars_FPHands_GripEntry& InEntry)
    {
        auto Grip = FMars_FPHands_HandGrip();
        Grip.Anchor = InEntry.Node;
        Grip.AnchorWorld = utils_transform::Get_EntityCurrentTransform(InEntry.Node);
        Grip.ReachOverrideCm = InEntry.ReachOverrideCm;
        Grip.Pose = TOptional<EMars_HandGripPose>(InEntry.Pose);
        Grip.Roll = InEntry.Roll;
        if (InEntry.Socket.IsSet() == false)
        {
            // Grip stays identity: the node itself is the grip bone's target, its rotation included under Node.
            Grip.IsAuthored = InEntry.Frame == EMars_FPHands_GripFrame::Node;
            return Grip;
        }

        const auto Socket = InEntry.Socket.GetValue();
        auto Component = Find_EntitySocketComponent(InEntry.Node, Socket);
        if (ck::EnsureIfNot(ck::IsValid(Component),
            f"[FPHands] grip node [{InEntry.Node.ToString()}] carries no socket [{Socket}]; the glove takes the node itself"))
        { return Grip; }

        Grip.Grip = Component.GetSocketTransform(Socket, ERelativeTransformSpace::RTS_World).GetRelativeTransform(Grip.AnchorWorld);
        Grip.IsAuthored = true;
        return Grip;
    }

    // InShared on InGrip, as a used glove's grip.
    TOptional<FMars_FPHands_HandGrip> Make_UsedGrip(const FMars_FPHands_HandGrip& InShared, const FTransform& InGrip)
    {
        auto Grip = InShared;
        Grip.Grip = InGrip;
        return TOptional<FMars_FPHands_HandGrip>(Grip);
    }

    bool Get_IsAuthored(const TOptional<FMars_FPHands_HandGrip>& InGrip)
    {
        return InGrip.IsSet() && InGrip.GetValue().IsAuthored;
    }

    // A grip table: each glove to its own row. With the right glove busy (InLeadHand Left), the free left glove takes the
    // right row (its own row is then dropped), as the socket paths do.
    FMars_FPHands_ReachTarget Resolve_GripTable(const TArray<FMars_FPHands_GripEntry>& InEntries, EMars_Hand InLeadHand)
    {
        auto RightGrip = TOptional<FMars_FPHands_HandGrip>();
        auto LeftGrip = TOptional<FMars_FPHands_HandGrip>();
        for (const auto& Entry : InEntries)
        {
            if (Entry.Hand == EMars_Hand::Right)
            { RightGrip = TOptional<FMars_FPHands_HandGrip>(Make_EntryGrip(Entry)); }
            else
            { LeftGrip = TOptional<FMars_FPHands_HandGrip>(Make_EntryGrip(Entry)); }
        }

        auto Target = FMars_FPHands_ReachTarget();
        if (InLeadHand == EMars_Hand::Right)
        {
            Target.Right = RightGrip;
            Target.Left = LeftGrip;
        }
        else if (RightGrip.IsSet())
        { Target.Left = RightGrip; }
        else
        { Target.Left = LeftGrip; }

        Target.Layout = Get_IsAuthored(Target.Right) || Get_IsAuthored(Target.Left)
            ? EMars_FPHands_GripLayout::Authored
            : EMars_FPHands_GripLayout::Point;
        return Target;
    }

    // Resolves what the gloves go for when reaching for InQuery's subject; unset when no glove is free. The hold decides
    // which gloves are free; PreferredHand picks the glove for single-handed reaches near the centre line. An owner with a
    // grip table (FMars_Fragment_FPHands_Grips) decides each glove's grip itself; every other path anchors both gloves to
    // one part.
    TOptional<FMars_FPHands_ReachTarget> Resolve_ReachTarget(const FMars_FPHands_ReachSpec& InSpec, const FMars_FPHands_ReachQuery& InQuery)
    {
        auto Target = Resolve_ReachTarget_AsAuthored(InSpec, InQuery);
        if (Target.IsSet() == false)
        { return Target; }

        auto Rolled = Target.GetValue();
        Apply_ViewerFacingRoll(Rolled, InQuery.Hand);
        return TOptional<FMars_FPHands_ReachTarget>(Rolled);
    }

    // Each used, authored FaceViewer grip re-rolled around its bar toward that glove's rest pose (anchor space, so a moving
    // part carries the chosen grip with it).
    void Apply_ViewerFacingRoll(FMars_FPHands_ReachTarget& InOutTarget, const FMars_FPHands_HandState& InHand)
    {
        if (InHand.RestGripWorld.IsSet() == false)
        { return; }

        const auto Rest = InHand.RestGripWorld.GetValue();
        Roll_HandGrip(InOutTarget.Right, Rest.Right);
        Roll_HandGrip(InOutTarget.Left, Rest.Left);
    }

    void Roll_HandGrip(TOptional<FMars_FPHands_HandGrip>& InOutGrip, const FQuat& InRestWorld)
    {
        if (InOutGrip.IsSet() == false)
        { return; }

        auto Grip = InOutGrip.GetValue();
        if (Grip.IsAuthored == false || Grip.Roll != EMars_FPHands_GripRoll::FaceViewer)
        { return; }

        const auto GripWorld = Grip.Grip * Grip.AnchorWorld;
        const auto Rolled = Make_ViewerFacingGrip(GripWorld.GetRotation(), InRestWorld);
        Grip.Grip.SetRotation(Grip.AnchorWorld.InverseTransformRotation(Rolled));
        InOutGrip = TOptional<FMars_FPHands_HandGrip>(Grip);
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
    TOptional<FMars_FPHands_ReachTarget> Resolve_ReachTarget_AsAuthored(const FMars_FPHands_ReachSpec& InSpec, const FMars_FPHands_ReachQuery& InQuery)
    {
        const auto& Subject = InQuery.Subject;
        const auto& Hand = InQuery.Hand;
        if (ck::EnsureIfNot(ck::IsValid(Subject.Owner), "[FPHands] the reach subject has no valid owner"))
        { return TOptional<FMars_FPHands_ReachTarget>(); }

        // Both gloves hold the item.
        if (Hand.Hold.Kind == EMars_FPHands_HoldKind::TwoHanded)
        { return TOptional<FMars_FPHands_ReachTarget>(); }

        // The glove a single-glove grip goes to: the right while both are free, the left while the right holds an item.
        const auto BothFree = Hand.Hold.Kind == EMars_FPHands_HoldKind::Empty;
        if (Subject.Owner.Has_Fragment(FMars_Fragment_FPHands_Grips))
        {
            const auto LeadHand = BothFree ? EMars_Hand::Right : EMars_Hand::Left;
            return TOptional<FMars_FPHands_ReachTarget>(
                Resolve_GripTable(Subject.Owner.Get_Fragment(FMars_Fragment_FPHands_Grips).Entries, LeadHand));
        }

        auto Anchor = Subject.Owner.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Anchor))
        { Anchor = Subject.Interactable.As_Transform(ECk_SanityCheck::UnChecked); }

        if (ck::EnsureIfNot(ck::IsValid(Anchor),
            f"[FPHands] neither the reach's owner [{Subject.Owner.ToString()}] nor its interactable has a transform"))
        { return TOptional<FMars_FPHands_ReachTarget>(); }

        auto Target = FMars_FPHands_ReachTarget();
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
                Target.ContactPose = TOptional<EMars_HandGripPose>(Presentation.Grip.Pose);

                UStaticMesh Mesh = nullptr;
                if (Presentation.Visual.Mesh.IsNull() == false)
                { Mesh = System::LoadAsset_Blocking(Presentation.Visual.Mesh); }

                Target.Shape.Mesh = Mesh;
                Target.Shape.Scale = Presentation.Visual.MeshScale;
                Target.Shape.Type = Presentation.Grip.Shape;
                const auto Sockets = Find_MeshSockets(Mesh, Presentation.Visual.MeshScale);
                if (Sockets.IsSet())
                {
                    const auto Grips = Sockets.GetValue();
                    Shared.IsAuthored = true;
                    Target.Layout = EMars_FPHands_GripLayout::Authored;
                    if (BothFree)
                    {
                        Target.Right = Make_UsedGrip(Shared, Grips.Right);
                        if (Grips.Left.IsSet())
                        { Target.Left = Make_UsedGrip(Shared, Grips.Left.GetValue()); }
                    }
                    else
                    {
                        // Right glove busy: the free left glove takes the right grip.
                        Target.Left = Make_UsedGrip(Shared, Grips.Right);
                    }
                    return TOptional<FMars_FPHands_ReachTarget>(Target);
                }

                const auto IsTwoHanded = Presentation.Grip.Handedness == EMars_ItemPresentation_Handedness::TwoHanded;
                if (ck::IsValid(Mesh) && IsTwoHanded && BothFree)
                {
                    const auto Bounds = Mesh.GetBounds();
                    const auto Extent = Bounds.BoxExtent * Presentation.Visual.MeshScale;
                    Target.Layout = EMars_FPHands_GripLayout::Sides;
                    Target.Sides.Center = Bounds.Origin * Presentation.Visual.MeshScale;
                    Target.Sides.HalfWidth = Presentation.Grip.HalfWidth.IsSet()
                        ? Presentation.Grip.HalfWidth.GetValue()
                        : float32(Math::Max(Extent.X, Extent.Y));
                    Target.Right = TOptional<FMars_FPHands_HandGrip>(Shared);
                    Target.Left = TOptional<FMars_FPHands_HandGrip>(Shared);
                    return TOptional<FMars_FPHands_ReachTarget>(Target);
                }
            }
        }

        // Grip sockets on the object's meshes: entity-built mechanisms (lever, hand wheel), then plain actors.
        auto ObjectSockets = Find_EntitySockets(Subject.Owner);
        if (ObjectSockets.IsSet() == false)
        { ObjectSockets = Find_ActorSockets(utils_owning_actor::TryGet_EntityOwningActor_Recursive(Subject.Owner)); }

        if (ObjectSockets.IsSet())
        {
            const auto Sockets = ObjectSockets.GetValue();

            // The part carrying the sockets may move on its own (a lever's handle under its Mover node): anchor to it.
            if (ck::IsValid(Sockets.Host))
            {
                Shared.Anchor = Sockets.Host;
                Shared.AnchorWorld = utils_transform::Get_EntityCurrentTransform(Sockets.Host);
            }

            Shared.IsAuthored = true;
            Shared.Roll = EMars_FPHands_GripRoll::FaceViewer;
            Target.Layout = EMars_FPHands_GripLayout::Authored;
            const auto RightGrip = Sockets.Right.GetRelativeTransform(Shared.AnchorWorld);
            auto LeftGrip = RightGrip;
            if (Sockets.Left.IsSet())
            { LeftGrip = Sockets.Left.GetValue().GetRelativeTransform(Shared.AnchorWorld); }

            if (BothFree)
            {
                Target.Right = Make_UsedGrip(Shared, RightGrip);
                if (Sockets.Left.IsSet())
                { Target.Left = Make_UsedGrip(Shared, LeftGrip); }
            }
            else
            { Target.Left = Make_UsedGrip(Shared, LeftGrip); }

            return TOptional<FMars_FPHands_ReachTarget>(Target);
        }

        // Plain interactable: one glove to its interaction point (the owner itself when there is no interactable).
        auto PointEntity = Subject.Interactable.As_Transform(ECk_SanityCheck::UnChecked);
        const auto PointWorld = ck::IsValid(PointEntity)
            ? utils_transform::Get_EntityCurrentTransform(PointEntity).GetLocation()
            : Shared.AnchorWorld.GetLocation();

        Target.Layout = EMars_FPHands_GripLayout::Point;
        Shared.Grip = FTransform(FRotator::ZeroRotator, Shared.AnchorWorld.InverseTransformPosition(PointWorld), FVector::OneVector);

        auto PointHand = EMars_Hand::Left;
        if (BothFree)
        {
            PointHand = Hand.PreferredHand;
            const auto SideY = Hand.HandWorld.InverseTransformPosition(PointWorld).Y;
            if (Math::Abs(SideY) > InSpec.Focus.SideSwitchMarginCm)
            { PointHand = SideY > 0.0 ? EMars_Hand::Right : EMars_Hand::Left; }
        }

        if (PointHand == EMars_Hand::Right)
        { Target.Right = TOptional<FMars_FPHands_HandGrip>(Shared); }
        else
        { Target.Left = TOptional<FMars_FPHands_HandGrip>(Shared); }

        return TOptional<FMars_FPHands_ReachTarget>(Target);
    }

    // Refreshes each used glove's anchor while it lives.
    void Update_ReachTarget(TOptional<FMars_FPHands_ReachTarget>& InOutTarget)
    {
        if (InOutTarget.IsSet() == false)
        { return; }

        auto Target = InOutTarget.GetValue();
        Refresh_Anchor(Target.Right);
        Refresh_Anchor(Target.Left);
        InOutTarget = TOptional<FMars_FPHands_ReachTarget>(Target);
    }

    void Refresh_Anchor(TOptional<FMars_FPHands_HandGrip>& InOutGrip)
    {
        if (InOutGrip.IsSet() == false)
        { return; }

        auto Grip = InOutGrip.GetValue();
        if (ck::Is_NOT_Valid(Grip.Anchor))
        { return; }

        Grip.AnchorWorld = utils_transform::Get_EntityCurrentTransform(Grip.Anchor);
        InOutGrip = TOptional<FMars_FPHands_HandGrip>(Grip);
    }

    // World-space grip on InTarget for InOutGrip's glove, whether its rotation is meant to be matched, the standoff a
    // point grip keeps and the glove's reach override. The target must use that glove.
    void Resolve_WorldGrip(const FMars_FPHands_Spec& InSpec, const FMars_FPHands_ReachTarget& InTarget, FMars_FPHands_GripQuery& InOutGrip)
    {
        const auto MaybeHandGrip = InTarget.Get_HandGrip(InOutGrip.Hand);
        if (ck::EnsureIfNot(MaybeHandGrip.IsSet(), f"[FPHands] the reach target does not use the [{InOutGrip.Hand :n}] glove"))
        { return; }

        const auto HandGrip = MaybeHandGrip.GetValue();
        const auto IsSides = InTarget.Layout == EMars_FPHands_GripLayout::Sides;
        InOutGrip.IsAuthored = HandGrip.IsAuthored;
        InOutGrip.Standoff = IsSides || HandGrip.IsAuthored ? 0.0f : InSpec.Reach.Stretch.StandoffCm;
        InOutGrip.ReachOverrideCm = HandGrip.ReachOverrideCm;
        if (IsSides)
        {
            const auto Center = HandGrip.AnchorWorld.TransformPosition(InTarget.Sides.Center);
            const auto Side = InOutGrip.HandWorld.GetRotation().GetRightVector() * (InTarget.Sides.HalfWidth + InSpec.Rest.PalmSurfaceOffset);
            const auto GripLocation = InOutGrip.Hand == EMars_Hand::Right ? Center + Side : Center - Side;
            InOutGrip.WorldGrip = FTransform(FRotator::ZeroRotator, GripLocation, FVector::OneVector);
            return;
        }

        InOutGrip.WorldGrip = HandGrip.Grip * HandGrip.AnchorWorld;
    }

    bool Get_UsesHand(const TOptional<FMars_FPHands_ReachTarget>& InTarget, EMars_Hand InHand)
    {
        return InTarget.IsSet() && InTarget.GetValue().Get_HandGrip(InHand).IsSet();
    }
}

// One glove's grip on the target; unset when that glove takes no part.
mixin TOptional<FMars_FPHands_HandGrip> Get_HandGrip(const FMars_FPHands_ReachTarget& Self, EMars_Hand InHand)
{
    if (InHand == EMars_Hand::Right)
    { return Self.Right; }

    return Self.Left;
}

// The grip of the glove that leads the reach: the right when it is used, else the left.
mixin FMars_FPHands_HandGrip Get_LeadingGrip(const FMars_FPHands_ReachTarget& Self)
{
    if (Self.Right.IsSet())
    { return Self.Right.GetValue(); }

    if (Self.Left.IsSet())
    { return Self.Left.GetValue(); }

    ck::EnsureIfNot(false, "[FPHands] a reach target uses neither glove");
    return FMars_FPHands_HandGrip();
}
