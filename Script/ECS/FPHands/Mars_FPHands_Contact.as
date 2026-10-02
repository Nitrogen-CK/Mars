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

// A primitive in world space. Box: Extent = half extents. Sphere: Extent.X = radius. Capsule: along local X,
// Extent.X = half length of the core segment, Extent.Y = radius.
struct FMars_FPHands_ContactShape
{
    UPROPERTY()
    bool IsValid = false;

    UPROPERTY()
    EMars_FPHands_GripShape Type = EMars_FPHands_GripShape::Box;

    UPROPERTY()
    FTransform World;

    UPROPERTY()
    FVector Extent;
}

struct FMars_FPHands_ContactShapes
{
    UPROPERTY()
    FMars_FPHands_ContactShape Left;

    UPROPERTY()
    FMars_FPHands_ContactShape Right;
}

struct FMars_FPHands_ContactSpec
{
    UPROPERTY()
    bool IsEnabled = true;

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
    UPROPERTY()
    bool IsValid = false;

    // Per digit bone (utils_fphands::Get_DigitBoneName order): local ref transform.
    UPROPERTY()
    TArray<FTransform> RefLocal;

    // hand_l / hand_r in their lowerarm's space.
    UPROPERTY()
    FTransform HandInLowerArm_L;

    UPROPERTY()
    FTransform HandInLowerArm_R;
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
    bool IsRightHand = false;

    // 0 = thumb, then index, middle, pinky.
    UPROPERTY()
    int32 Digit = 0;

    FMars_FPHands_DigitQuery() {}

    FMars_FPHands_DigitQuery(FMars_FPHands_ContactShape InShape, FTransform InHandWorld, EMars_HandGripPose InPose, bool InIsRightHand)
    {
        Shape = InShape;
        HandWorld = InHandWorld;
        Pose = InPose;
        IsRightHand = InIsRightHand;
    }
}

namespace utils_fphands
{
    const int32 DigitCount = 4;
    const int32 SegmentsPerDigit = 3;

    FMars_FPHands_ContactRig Make_ContactRig(USkeletalMeshComponent InMesh)
    {
        auto Rig = FMars_FPHands_ContactRig();
        for (int32 Bone = 0; Bone < utils_fphands::DigitBoneCount; ++Bone)
        {
            const auto Index = InMesh.GetBoneIndex(utils_fphands::Get_DigitBoneName(Bone));
            if (Index == -1)
            { return Rig; }

            Rig.RefLocal.Add(InMesh.GetRefPoseTransform(Index));
        }

        const auto HandL = InMesh.GetBoneIndex(n"hand_l");
        const auto HandR = InMesh.GetBoneIndex(n"hand_r");
        if (HandL == -1 || HandR == -1)
        { return Rig; }

        Rig.HandInLowerArm_L = InMesh.GetRefPoseTransform(HandL);
        Rig.HandInLowerArm_R = InMesh.GetRefPoseTransform(HandR);
        Rig.IsValid = true;
        return Rig;
    }

    // Signed distance from InPoint to the shape's surface (negative inside).
    float Get_ShapeDistance(const FMars_FPHands_ContactShape& InShape, const FVector& InPoint)
    {
        const auto Local = InShape.World.InverseTransformPositionNoScale(InPoint);
        if (InShape.Type == EMars_FPHands_GripShape::Sphere)
        { return Local.Size() - InShape.Extent.X; }

        if (InShape.Type == EMars_FPHands_GripShape::Capsule)
        {
            const auto OnAxis = FVector(Math::Clamp(Local.X, -InShape.Extent.X, InShape.Extent.X), 0.0, 0.0);
            return (Local - OnAxis).Size() - InShape.Extent.Y;
        }

        const auto Q = FVector(Math::Abs(Local.X) - InShape.Extent.X, Math::Abs(Local.Y) - InShape.Extent.Y, Math::Abs(Local.Z) - InShape.Extent.Z);
        const auto Outside = FVector(Math::Max(Q.X, 0.0), Math::Max(Q.Y, 0.0), Math::Max(Q.Z, 0.0)).Size();
        const auto Inside = Math::Min(Math::Max(Q.X, Math::Max(Q.Y, Q.Z)), 0.0);
        return Outside + Inside;
    }

    // Distances from the shape to sample points along the digit (joints, segment midpoints, fingertip), curled InCurl
    // of the way from rest toward the query's pose. The segment rooted in the palm is skipped: it cannot move out of
    // the way.
    TArray<float> Sample_DigitDistances(const FMars_FPHands_ContactRig& InRig, const FMars_FPHands_DigitQuery& InQuery, float InCurl)
    {
        const auto FirstBone = (InQuery.IsRightHand ? DigitCount * SegmentsPerDigit : 0) + InQuery.Digit * SegmentsPerDigit;

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
        if (InQuery.Shape.IsValid == false || InRig.IsValid == false)
        { return 1.0f; }

        const auto Radius = InQuery.Digit == 0 ? InSpec.ThumbRadiusCm : InSpec.FingerRadiusCm;
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

    // A primitive fitted to a mesh's bounds (mesh space, MeshScale applied), placed by MeshWorld.
    FMars_FPHands_ContactShape Make_BoundsShape(const FMars_FPHands_BoundsQuery& InQuery)
    {
        auto Shape = FMars_FPHands_ContactShape();
        if (ck::Is_NOT_Valid(InQuery.Mesh))
        { return Shape; }

        const auto Bounds = InQuery.Mesh.GetBounds();
        const auto Extent = FVector(Math::Abs(Bounds.BoxExtent.X * InQuery.MeshScale.X), Math::Abs(Bounds.BoxExtent.Y * InQuery.MeshScale.Y),
                                    Math::Abs(Bounds.BoxExtent.Z * InQuery.MeshScale.Z));
        const auto CenterWorld = InQuery.MeshWorld.TransformPosition(Bounds.Origin * InQuery.MeshScale);

        Shape.IsValid = true;
        Shape.Type = InQuery.Type == EMars_FPHands_GripShape::Auto ? EMars_FPHands_GripShape::Box : InQuery.Type;
        Shape.World = FTransform(InQuery.MeshWorld.GetRotation(), CenterWorld, FVector::OneVector);
        Shape.Extent = Extent;

        if (Shape.Type == EMars_FPHands_GripShape::Sphere)
        { Shape.Extent = FVector(Math::Max(Extent.X, Math::Max(Extent.Y, Extent.Z)), 0.0, 0.0); }
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

            const auto AxisWorld = InQuery.MeshWorld.GetRotation().RotateVector(Axis);
            Shape.World = FTransform(FQuat::FindBetweenNormals(FVector::ForwardVector, AxisWorld), CenterWorld, FVector::OneVector);
            Shape.Extent = FVector(Math::Max(Length - Radius, 0.0), Radius, 0.0);
        }
        return Shape;
    }

    // The handle an authored grip closes on: a capsule along the socket's X (handle) axis.
    FMars_FPHands_ContactShape Make_SocketShape(const FMars_FPHands_ContactSpec& InSpec, const FTransform& InSocketWorld)
    {
        auto Shape = FMars_FPHands_ContactShape();
        Shape.IsValid = true;
        Shape.Type = EMars_FPHands_GripShape::Capsule;
        Shape.World = FTransform(InSocketWorld.GetRotation(), InSocketWorld.GetLocation(), FVector::OneVector);
        Shape.Extent = FVector(InSpec.SocketHandleHalfLengthCm, InSpec.SocketHandleRadiusCm, 0.0);
        return Shape;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Contact shapes (read the feature)
//--------------------------------------------------------------------------------------------------------------------------

// What each glove's fingers close on this frame (invalid = keep the authored pose): a reaching glove near contact
// closes on its target, a holding glove on its item.
mixin void Get_ContactShapes(const FCk_Handle_FPHands& Self, const FTransform& InHandWorld, FMars_FPHands_ContactShapes& OutShapes)
{
    OutShapes.Left = Self.Get_ContactShape(InHandWorld, false);
    OutShapes.Right = Self.Get_ContactShape(InHandWorld, true);
}

mixin FMars_FPHands_ContactShape Get_ContactShape(const FCk_Handle_FPHands& Self, const FTransform& InHandWorld, bool InIsRightHand)
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
        return FMars_FPHands_ContactShape();
    }

    const auto Hold = Self.Get_Hold();
    const auto HoldsWithThisHand = Hold.IsHolding && (Hold.IsTwoHanded || InIsRightHand);
    if (HoldsWithThisHand && ck::IsValid(Hold.ShapeMesh.Get()))
    {
        return utils_fphands::Make_BoundsShape(
            FMars_FPHands_BoundsQuery(Hold.ShapeMesh.Get(), Hold.ShapeScale, Hold.ShapeType, Hold.ShapeOffset * InHandWorld));
    }

    return FMars_FPHands_ContactShape();
}
