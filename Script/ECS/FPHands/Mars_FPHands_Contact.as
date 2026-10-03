// Finger contact for the first-person gloves (local player only). The script works out what each glove is closing on
// and how far each digit can curl before touching it; CR_FPHands_Contact applies that per digit by blending every
// finger joint from its rest rotation toward the authored grip pose. Fallback at every step is the authored pose:
// no shape, no contact within the curl, or no rig all mean a curl of 1.
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

// The solved digits of one glove, in bone order (utils_fphands::Get_DigitBoneName).
enum EMars_FPHands_Digit
{
    Thumb,
    Index,
    Middle,
    Pinky
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

// A primitive in world space. A capsule runs along its local X.
struct FMars_FPHands_ContactShape
{
    UPROPERTY()
    EMars_FPHands_GripShape Type = EMars_FPHands_GripShape::Box;

    UPROPERTY()
    FTransform World;

    // Box only.
    UPROPERTY()
    FVector HalfExtents;

    // Sphere and capsule.
    UPROPERTY()
    float Radius = 0.0;

    // Capsule only: half the length of the core segment.
    UPROPERTY()
    float HalfLength = 0.0;
}

// Unset = that glove keeps its authored pose.
struct FMars_FPHands_ContactShapes
{
    UPROPERTY()
    TOptional<FMars_FPHands_ContactShape> Left;

    UPROPERTY()
    TOptional<FMars_FPHands_ContactShape> Right;
}

struct FMars_FPHands_ContactSpec
{
    UPROPERTY()
    ECk_EnableDisable EnableDisable = ECk_EnableDisable::Enable;

    // Glove finger thickness (radius, cm) used for the contact test.
    UPROPERTY()
    float32 FingerRadiusCm = 1.3f;

    UPROPERTY()
    float32 ThumbRadiusCm = 1.5f;

    // Socket grips: the handle the glove closes on (capsule along the socket's X axis).
    UPROPERTY()
    float32 SocketHandleRadiusCm = 3.0f;

    UPROPERTY()
    float32 SocketHandleHalfLengthCm = 6.0f;

    // Curl search resolution (coarse steps, then bisection).
    UPROPERTY()
    int32 SearchSteps = 8;

    // How quickly a digit's curl follows its solved value (1/s).
    UPROPERTY()
    float32 CurlInterpSpeed = 18.0f;
}

// Reference (bind) pose data the solver needs, read once from the gloves' mesh.
struct FMars_FPHands_ContactRig
{
    // Per digit bone (utils_fphands::Get_DigitBoneName order): local ref transform.
    UPROPERTY()
    TArray<FTransform> RefLocal;

    // hand_l / hand_r in their lowerarm's space.
    UPROPERTY()
    FTransform HandInLowerArm_L;

    UPROPERTY()
    FTransform HandInLowerArm_R;
}

// One digit of one glove closing on a shape, curled from rest toward Pose.
struct FMars_FPHands_DigitQuery
{
    UPROPERTY()
    FMars_FPHands_ContactShape Shape;

    UPROPERTY()
    FTransform HandWorld;

    UPROPERTY()
    EMars_HandGripPose Pose = EMars_HandGripPose::Relaxed;

    UPROPERTY()
    EMars_Hand Hand = EMars_Hand::Right;

    UPROPERTY()
    EMars_FPHands_Digit Digit = EMars_FPHands_Digit::Thumb;

    FMars_FPHands_DigitQuery() {}

    FMars_FPHands_DigitQuery(FMars_FPHands_ContactShape InShape, FTransform InHandWorld, EMars_HandGripPose InPose, EMars_Hand InHand)
    {
        Shape = InShape;
        HandWorld = InHandWorld;
        Pose = InPose;
        Hand = InHand;
    }
}

namespace utils_fphands
{
    const int32 DigitCount = 4;
    const int32 SegmentsPerDigit = 3;

    // Unset (after an ensure) when the mesh lacks a bone the solver reads: finger contact is then off.
    TOptional<FMars_FPHands_ContactRig> Make_ContactRig(USkeletalMeshComponent InMesh)
    {
        auto Rig = FMars_FPHands_ContactRig();
        for (int32 Bone = 0; Bone < utils_fphands::DigitBoneCount; ++Bone)
        {
            const auto BoneName = utils_fphands::Get_DigitBoneName(Bone);
            const auto Index = InMesh.GetBoneIndex(BoneName);
            if (ck::EnsureIfNot(Index != -1, f"[FPHands] the glove mesh has no digit bone [{BoneName}]; finger contact is off"))
            { return TOptional<FMars_FPHands_ContactRig>(); }

            Rig.RefLocal.Add(InMesh.GetRefPoseTransform(Index));
        }

        const auto HandL = InMesh.GetBoneIndex(n"hand_l");
        const auto HandR = InMesh.GetBoneIndex(n"hand_r");
        if (ck::EnsureIfNot(HandL != -1 && HandR != -1, "[FPHands] the glove mesh has no hand_l / hand_r bone; finger contact is off"))
        { return TOptional<FMars_FPHands_ContactRig>(); }

        Rig.HandInLowerArm_L = InMesh.GetRefPoseTransform(HandL);
        Rig.HandInLowerArm_R = InMesh.GetRefPoseTransform(HandR);
        return TOptional<FMars_FPHands_ContactRig>(Rig);
    }

    // Signed distance from InPoint to the shape's surface (negative inside).
    float Get_ShapeDistance(const FMars_FPHands_ContactShape& InShape, const FVector& InPoint)
    {
        const auto Local = InShape.World.InverseTransformPositionNoScale(InPoint);
        if (InShape.Type == EMars_FPHands_GripShape::Sphere)
        { return Local.Size() - InShape.Radius; }

        if (InShape.Type == EMars_FPHands_GripShape::Capsule)
        {
            const auto OnAxis = FVector(Math::Clamp(Local.X, -InShape.HalfLength, InShape.HalfLength), 0.0, 0.0);
            return (Local - OnAxis).Size() - InShape.Radius;
        }

        const auto Extent = InShape.HalfExtents;
        const auto Q = FVector(Math::Abs(Local.X) - Extent.X, Math::Abs(Local.Y) - Extent.Y, Math::Abs(Local.Z) - Extent.Z);
        const auto Outside = FVector(Math::Max(Q.X, 0.0), Math::Max(Q.Y, 0.0), Math::Max(Q.Z, 0.0)).Size();
        const auto Inside = Math::Min(Math::Max(Q.X, Math::Max(Q.Y, Q.Z)), 0.0);
        return Outside + Inside;
    }

    // Distances from the shape to sample points along the digit (joints, segment midpoints, fingertip), curled InCurl
    // of the way from rest toward the query's pose. The segment rooted in the palm is skipped: it cannot move out of
    // the way.
    TArray<float> Sample_DigitDistances(const FMars_FPHands_ContactRig& InRig, const FMars_FPHands_DigitQuery& InQuery, float InCurl)
    {
        const auto SideOffset = InQuery.Hand == EMars_Hand::Right ? DigitCount * SegmentsPerDigit : 0;
        const auto FirstBone = SideOffset + int32(InQuery.Digit) * SegmentsPerDigit;

        TArray<float> Distances;
        auto Parent = InQuery.HandWorld;
        auto Previous = FVector::ZeroVector;
        auto LastLength = 0.0;
        for (int32 Segment = 0; Segment < SegmentsPerDigit; ++Segment)
        {
            const auto Bone = FirstBone + Segment;
            const auto& Ref = InRig.RefLocal[Bone];
            const auto Rotation = FQuat::Slerp(Ref.GetRotation(), utils_fphands::Get_DigitBoneRotation(InQuery.Pose, Bone), InCurl);
            const auto Joint = FTransform(Rotation, Ref.GetLocation()) * Parent;

            if (Segment > 0)
            {
                if (Segment > 1)
                { Distances.Add(Get_ShapeDistance(InQuery.Shape, (Previous + Joint.GetLocation()) * 0.5)); }

                Distances.Add(Get_ShapeDistance(InQuery.Shape, Joint.GetLocation()));
            }

            LastLength = Ref.GetLocation().Size();
            Previous = Joint.GetLocation();
            Parent = Joint;
        }

        // Fingertip: the last segment has no child bone; take it as long as the one before it.
        const auto Tip = Parent.TransformPosition(FVector(LastLength * 0.9, 0.0, 0.0));
        Distances.Add(Get_ShapeDistance(InQuery.Shape, (Previous + Tip) * 0.5));
        Distances.Add(Get_ShapeDistance(InQuery.Shape, Tip));
        return Distances;
    }

    // New contact: a sample that was clear of the surface at rest now reaches it. Samples already inside at rest (the
    // grip sits in the palm, so the finger roots can start inside a handle) never stop the curl.
    bool Is_Touching(const TArray<float>& InRestDistances, const TArray<float>& InDistances, float InRadius)
    {
        for (int32 Index = 0; Index < InDistances.Num(); ++Index)
        {
            if (InRestDistances[Index] >= InRadius && InDistances[Index] < InRadius)
            { return true; }
        }
        return false;
    }

    // How far (0..1 of the authored curl) a digit can close before touching the shape. 1 = authored pose.
    float32 Solve_Digit(const FMars_FPHands_ContactSpec& InSpec, const FMars_FPHands_ContactRig& InRig, const FMars_FPHands_DigitQuery& InQuery)
    {
        const auto Radius = InQuery.Digit == EMars_FPHands_Digit::Thumb ? InSpec.ThumbRadiusCm : InSpec.FingerRadiusCm;
        const auto Steps = Math::Max(InSpec.SearchSteps, 2);
        const auto Rest = Sample_DigitDistances(InRig, InQuery, 0.0);

        auto Clear = 0.0;
        for (int32 Step = 1; Step <= Steps; ++Step)
        {
            const auto Curl = float(Step) / float(Steps);
            if (Is_Touching(Rest, Sample_DigitDistances(InRig, InQuery, Curl), Radius) == false)
            {
                Clear = Curl;
                continue;
            }

            // Refine between the last clear curl and this touching one.
            auto Touch = Curl;
            for (int32 Iteration = 0; Iteration < 4; ++Iteration)
            {
                const auto Mid = (Clear + Touch) * 0.5;
                if (Is_Touching(Rest, Sample_DigitDistances(InRig, InQuery, Mid), Radius))
                { Touch = Mid; }
                else
                { Clear = Mid; }
            }
            return float32(Clear);
        }
        return 1.0f;
    }

    // A primitive fitted to a mesh's bounds (Scale applied), placed by InMeshWorld. Unset without a mesh.
    TOptional<FMars_FPHands_ContactShape> Make_BoundsShape(const FMars_FPHands_ShapeMesh& InShapeMesh, const FTransform& InMeshWorld)
    {
        auto Mesh = InShapeMesh.Mesh.Get();
        if (ck::Is_NOT_Valid(Mesh))
        { return TOptional<FMars_FPHands_ContactShape>(); }

        const auto Scale = InShapeMesh.Scale;
        const auto Bounds = Mesh.GetBounds();
        const auto Extent = FVector(Math::Abs(Bounds.BoxExtent.X * Scale.X), Math::Abs(Bounds.BoxExtent.Y * Scale.Y),
                                    Math::Abs(Bounds.BoxExtent.Z * Scale.Z));
        const auto CenterWorld = InMeshWorld.TransformPosition(Bounds.Origin * Scale);

        auto Shape = FMars_FPHands_ContactShape();
        Shape.Type = InShapeMesh.Type == EMars_FPHands_GripShape::Auto ? EMars_FPHands_GripShape::Box : InShapeMesh.Type;
        Shape.World = FTransform(InMeshWorld.GetRotation(), CenterWorld, FVector::OneVector);
        Shape.HalfExtents = Extent;

        if (Shape.Type == EMars_FPHands_GripShape::Sphere)
        { Shape.Radius = Math::Max(Extent.X, Math::Max(Extent.Y, Extent.Z)); }
        else if (Shape.Type == EMars_FPHands_GripShape::Capsule)
        {
            // Orient local X along the longest axis.
            auto Axis = FVector::ForwardVector;
            auto Length = Extent.X;
            auto Radius = Math::Max(Extent.Y, Extent.Z);
            if (Extent.Y >= Extent.X && Extent.Y >= Extent.Z)
            { Axis = FVector::RightVector; Length = Extent.Y; Radius = Math::Max(Extent.X, Extent.Z); }
            else if (Extent.Z >= Extent.X && Extent.Z >= Extent.Y)
            { Axis = FVector::UpVector; Length = Extent.Z; Radius = Math::Max(Extent.X, Extent.Y); }

            const auto AxisWorld = InMeshWorld.GetRotation().RotateVector(Axis);
            Shape.World = FTransform(FQuat::FindBetweenNormals(FVector::ForwardVector, AxisWorld), CenterWorld, FVector::OneVector);
            Shape.HalfLength = Math::Max(Length - Radius, 0.0);
            Shape.Radius = Radius;
        }
        return TOptional<FMars_FPHands_ContactShape>(Shape);
    }

    // The handle an authored grip closes on: a capsule along the socket's X (handle) axis.
    FMars_FPHands_ContactShape Make_SocketShape(const FMars_FPHands_ContactSpec& InSpec, const FTransform& InSocketWorld)
    {
        auto Shape = FMars_FPHands_ContactShape();
        Shape.Type = EMars_FPHands_GripShape::Capsule;
        Shape.World = FTransform(InSocketWorld.GetRotation(), InSocketWorld.GetLocation(), FVector::OneVector);
        Shape.HalfLength = InSpec.SocketHandleHalfLengthCm;
        Shape.Radius = InSpec.SocketHandleRadiusCm;
        return Shape;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Contact shapes (read the feature)
//--------------------------------------------------------------------------------------------------------------------------

// What each glove's fingers close on this frame: a reaching glove near contact closes on its target, a holding glove
// on its item.
mixin void Get_ContactShapes(const FCk_Handle_FPHands& Self, const FTransform& InHandWorld, FMars_FPHands_ContactShapes& OutShapes)
{
    OutShapes.Left = Self.Get_ContactShape(InHandWorld, EMars_Hand::Left);
    OutShapes.Right = Self.Get_ContactShape(InHandWorld, EMars_Hand::Right);
}

mixin TOptional<FMars_FPHands_ContactShape> Get_ContactShape(const FCk_Handle_FPHands& Self, const FTransform& InHandWorld, EMars_Hand InHand)
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
            return TOptional<FMars_FPHands_ContactShape>(utils_fphands::Make_SocketShape(Spec.Contact, Grip.WorldGrip));
        }
        return TOptional<FMars_FPHands_ContactShape>();
    }

    const auto Hold = Self.Get_Hold();
    if (Hold.Get_HoldsWith(InHand))
    { return utils_fphands::Make_BoundsShape(Hold.Shape, Hold.HeldOffset * InHandWorld); }

    return TOptional<FMars_FPHands_ContactShape>();
}
