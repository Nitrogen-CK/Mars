// Finger contact for the first-person gloves (local player only). The script works out what each glove is closing on,
// as an FCk_Hands_ContactShape; CR_FPHands_Contact (CkHands "Contact Curl" nodes, one per digit) curls each digit from
// its rest pose toward the grip pose the anim graph plays and stops it on that shape. Fallback at every step is the
// authored pose: no shape, or no contact within the curl, both leave the digit on it. Digit thickness, search
// resolution and curl easing are tuned on the rig's nodes.
enum EMars_FPHands_GripShape
{
    // Box from the mesh bounds.
    Auto,
    Box,
    // Radius = the largest bounds extent.
    Sphere,
    // Along the bounds' longest axis.
    Capsule
}

// What each glove's fingers close on, in world space. Type None = keep the authored pose.
struct FMars_FPHands_ContactShapes
{
    UPROPERTY()
    FCk_Hands_ContactShape Left;

    UPROPERTY()
    FCk_Hands_ContactShape Right;
}

struct FMars_FPHands_ContactSpec
{
    UPROPERTY()
    bool IsEnabled = true;

    // Socket grips: the handle the glove closes on (capsule along the socket's X axis).
    UPROPERTY()
    float32 SocketHandleRadiusCm = 3.0f;

    UPROPERTY()
    float32 SocketHandleHalfLengthCm = 6.0f;
}

// A mesh's bounds as a contact primitive: the mesh (MeshScale applied) placed by MeshWorld.
struct FMars_FPHands_BoundsQuery
{
    UPROPERTY()
    UStaticMesh Mesh;

    UPROPERTY()
    FVector MeshScale = FVector::OneVector;

    UPROPERTY()
    EMars_FPHands_GripShape Type = EMars_FPHands_GripShape::Auto;

    UPROPERTY()
    FTransform MeshWorld;

    FMars_FPHands_BoundsQuery() {}

    FMars_FPHands_BoundsQuery(UStaticMesh InMesh, FVector InMeshScale, EMars_FPHands_GripShape InType, FTransform InMeshWorld)
    {
        Mesh = InMesh;
        MeshScale = InMeshScale;
        Type = InType;
        MeshWorld = InMeshWorld;
    }
}

namespace utils_fphands
{
    ECk_Hands_ContactShapeType Get_ContactShapeType(EMars_FPHands_GripShape InShape)
    {
        if (InShape == EMars_FPHands_GripShape::Sphere)
        { return ECk_Hands_ContactShapeType::Sphere; }

        if (InShape == EMars_FPHands_GripShape::Capsule)
        { return ECk_Hands_ContactShapeType::Capsule; }

        return ECk_Hands_ContactShapeType::Box;
    }

    // A primitive fitted to a mesh's bounds (mesh space, MeshScale applied), placed by MeshWorld. World space; None
    // without a mesh.
    FCk_Hands_ContactShape Make_BoundsShape(const FMars_FPHands_BoundsQuery& InQuery)
    {
        if (ck::Is_NOT_Valid(InQuery.Mesh))
        { return FCk_Hands_ContactShape(); }

        const auto Bounds = InQuery.Mesh.GetBounds();
        const auto Center = Bounds.Origin * InQuery.MeshScale;
        const auto Extent = FVector(Math::Abs(Bounds.BoxExtent.X * InQuery.MeshScale.X), Math::Abs(Bounds.BoxExtent.Y * InQuery.MeshScale.Y),
                                    Math::Abs(Bounds.BoxExtent.Z * InQuery.MeshScale.Z));

        return UCk_Utils_Hands_ContactShape_UE::Make_FromBounds(InQuery.MeshWorld, FBox(Center - Extent, Center + Extent),
            Get_ContactShapeType(InQuery.Type));
    }

    // The handle an authored grip closes on: a capsule along the socket's X (handle) axis. World space.
    FCk_Hands_ContactShape Make_SocketShape(const FMars_FPHands_ContactSpec& InSpec, const FTransform& InSocketWorld)
    {
        return UCk_Utils_Hands_ContactShape_UE::Make_CapsuleAlongAxis(InSocketWorld, ECk_Vector_Axis::X,
            InSpec.SocketHandleHalfLengthCm, InSpec.SocketHandleRadiusCm);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Contact shapes (read the feature)
//--------------------------------------------------------------------------------------------------------------------------

// What each glove's fingers close on this frame (None = keep the authored pose): a reaching glove near contact
// closes on its target, a holding glove on its item.
mixin void Get_ContactShapes(const FCk_Handle_FPHands& Self, const FTransform& InHandWorld, FMars_FPHands_ContactShapes& OutShapes)
{
    OutShapes.Left = Self.Get_ContactShape(InHandWorld, false);
    OutShapes.Right = Self.Get_ContactShape(InHandWorld, true);
}

mixin FCk_Hands_ContactShape Get_ContactShape(const FCk_Handle_FPHands& Self, const FTransform& InHandWorld, bool InIsRightHand)
{
    const auto& Spec = Self.Get_Spec();
    if (Self.Get_IsReaching(InIsRightHand) && Self.Get_ReachAlpha() > 0.6f)
    {
        const auto Target = Self.Get_Target();
        const auto HandGrip = Target.Get_HandGrip(InIsRightHand);
        if (ck::IsValid(Target.ShapeMesh.Get()))
        {
            return utils_fphands::Make_BoundsShape(
                FMars_FPHands_BoundsQuery(Target.ShapeMesh.Get(), Target.ShapeScale, Target.ShapeType, HandGrip.AnchorWorld));
        }

        if (HandGrip.IsAuthored)
        {
            auto Grip = FMars_FPHands_GripQuery(InHandWorld, InIsRightHand, FTransform());
            utils_fphands::Resolve_WorldGrip(Spec, Target, Grip);
            return utils_fphands::Make_SocketShape(Spec.Contact, Grip.WorldGrip);
        }
        return FCk_Hands_ContactShape();
    }

    const auto Hold = Self.Get_Hold();
    const auto HoldsWithThisHand = Hold.IsHolding && (Hold.IsTwoHanded || InIsRightHand);
    if (HoldsWithThisHand && ck::IsValid(Hold.ShapeMesh.Get()))
    {
        return utils_fphands::Make_BoundsShape(
            FMars_FPHands_BoundsQuery(Hold.ShapeMesh.Get(), Hold.ShapeScale, Hold.ShapeType, Hold.ShapeOffset * InHandWorld));
    }

    return FCk_Hands_ContactShape();
}
