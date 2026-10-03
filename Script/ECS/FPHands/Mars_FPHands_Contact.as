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

// A mesh whose bounds the fingers close on.
// Weak: fragments may not hold strong UObject refs (Schema.IsSafe); the item's presentation owns the mesh.
struct FMars_FPHands_ShapeMesh
{
    UPROPERTY()
    TWeakObjectPtr<UStaticMesh> Mesh;

    UPROPERTY()
    FVector Scale = FVector::OneVector;

    UPROPERTY()
    EMars_FPHands_GripShape Type = EMars_FPHands_GripShape::Auto;
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
    ECk_EnableDisable EnableDisable = ECk_EnableDisable::Enable;

    // Socket grips: the handle the glove closes on (capsule along the socket's X axis).
    UPROPERTY()
    float32 SocketHandleRadiusCm = 3.0f;

    UPROPERTY()
    float32 SocketHandleHalfLengthCm = 6.0f;
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

    // A primitive fitted to a mesh's bounds (Scale applied), placed by InMeshWorld. World space; None without a mesh.
    FCk_Hands_ContactShape Make_BoundsShape(const FMars_FPHands_ShapeMesh& InShapeMesh, const FTransform& InMeshWorld)
    {
        auto Mesh = InShapeMesh.Mesh.Get();
        if (ck::Is_NOT_Valid(Mesh))
        { return FCk_Hands_ContactShape(); }

        const auto Scale = InShapeMesh.Scale;
        const auto Bounds = Mesh.GetBounds();
        const auto Center = Bounds.Origin * Scale;
        const auto Extent = FVector(Math::Abs(Bounds.BoxExtent.X * Scale.X), Math::Abs(Bounds.BoxExtent.Y * Scale.Y),
                                    Math::Abs(Bounds.BoxExtent.Z * Scale.Z));

        return UCk_Utils_Hands_ContactShape_UE::Make_FromBounds(InMeshWorld, FBox(Center - Extent, Center + Extent),
            Get_ContactShapeType(InShapeMesh.Type));
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
    OutShapes.Left = Self.Get_ContactShape(InHandWorld, EMars_Hand::Left);
    OutShapes.Right = Self.Get_ContactShape(InHandWorld, EMars_Hand::Right);
}

mixin FCk_Hands_ContactShape Get_ContactShape(const FCk_Handle_FPHands& Self, const FTransform& InHandWorld, EMars_Hand InHand)
{
    const auto& Spec = Self.Get_Spec();
    if (Self.Get_IsReaching(InHand) && Self.Get_ReachAlpha() > 0.6f)
    {
        // Reaching with this glove: the target is set and uses it.
        const auto MaybeTarget = Self.Get_Target();
        const auto Target = MaybeTarget.GetValue();
        const auto MaybeGrip = Target.Get_HandGrip(InHand);
        const auto HandGrip = MaybeGrip.GetValue();
        if (ck::IsValid(Target.Shape.Mesh.Get()))
        { return utils_fphands::Make_BoundsShape(Target.Shape, HandGrip.AnchorWorld); }

        if (HandGrip.IsAuthored)
        {
            auto Grip = FMars_FPHands_GripQuery(InHandWorld, InHand, FTransform());
            utils_fphands::Resolve_WorldGrip(Spec, Target, Grip);
            return utils_fphands::Make_SocketShape(Spec.Contact, Grip.WorldGrip);
        }
        return FCk_Hands_ContactShape();
    }

    const auto Hold = Self.Get_Hold();
    if (Hold.Get_HoldsWith(InHand))
    { return utils_fphands::Make_BoundsShape(Hold.Shape, Hold.HeldOffset * InHandWorld); }

    return FCk_Hands_ContactShape();
}
