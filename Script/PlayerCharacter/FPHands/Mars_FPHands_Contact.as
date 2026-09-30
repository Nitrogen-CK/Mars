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

    // Per digit bone (mars_fphands_posedata order): local ref transform.
    UPROPERTY()
    TArray<FTransform> RefLocal;

    // hand_l / hand_r in their lowerarm's space.
    UPROPERTY()
    FTransform HandInLowerArm_L;

    UPROPERTY()
    FTransform HandInLowerArm_R;
}

namespace mars_fphands_contact
{
    const int32 DigitCount = 4;
    const int32 SegmentsPerDigit = 3;

    FMars_FPHands_ContactRig Make_Rig(USkeletalMeshComponent InMesh)
    {
        auto Rig = FMars_FPHands_ContactRig();
        for (int32 Bone = 0; Bone < mars_fphands_posedata::BoneCount; ++Bone)
        {
            const auto Index = InMesh.GetBoneIndex(mars_fphands_posedata::Get_BoneName(Bone));
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
    float Get_Distance(const FMars_FPHands_ContactShape& InShape, const FVector& InPoint)
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
    // of the way from rest toward InPose. The segment rooted in the palm is skipped: it cannot move out of the way.
    TArray<float> Sample_Distances(const FMars_FPHands_ContactRig& InRig, const FMars_FPHands_ContactShape& InShape, const FTransform& InHandWorld,
                                   EMars_HandGripPose InPose, int32 InFirstBone, float InCurl)
    {
        TArray<float> Distances;
        auto Parent = InHandWorld;
        auto Previous = FVector::ZeroVector;
        auto LastLength = 0.0;
        for (int32 Segment = 0; Segment < SegmentsPerDigit; ++Segment)
        {
            const auto Bone = InFirstBone + Segment;
            const auto& Ref = InRig.RefLocal[Bone];
            const auto Rotation = FQuat::Slerp(Ref.GetRotation(), mars_fphands_posedata::Get_Rotation(InPose, Bone), InCurl);
            const auto Joint = FTransform(Rotation, Ref.GetLocation()) * Parent;

            if (Segment > 0)
            {
                if (Segment > 1)
                { Distances.Add(Get_Distance(InShape, (Previous + Joint.GetLocation()) * 0.5)); }
                Distances.Add(Get_Distance(InShape, Joint.GetLocation()));
            }

            LastLength = Ref.GetLocation().Size();
            Previous = Joint.GetLocation();
            Parent = Joint;
        }

        // Fingertip: the last segment has no child bone; take it as long as the one before it.
        const auto Tip = Parent.TransformPosition(FVector(LastLength * 0.9, 0.0, 0.0));
        Distances.Add(Get_Distance(InShape, (Previous + Tip) * 0.5));
        Distances.Add(Get_Distance(InShape, Tip));
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
    float32 Solve_Digit(const FMars_FPHands_ContactSpec& InSpec, const FMars_FPHands_ContactRig& InRig, const FMars_FPHands_ContactShape& InShape,
                        const FTransform& InHandWorld, EMars_HandGripPose InPose, bool InIsRightHand, int32 InDigit)
    {
        if (InShape.IsValid == false || InRig.IsValid == false)
        { return 1.0f; }

        const auto FirstBone = (InIsRightHand ? DigitCount * SegmentsPerDigit : 0) + InDigit * SegmentsPerDigit;
        const auto Radius = InDigit == 0 ? InSpec.ThumbRadiusCm : InSpec.FingerRadiusCm;
        const auto Steps = Math::Max(InSpec.SearchSteps, 2);
        const auto Rest = Sample_Distances(InRig, InShape, InHandWorld, InPose, FirstBone, 0.0);

        auto Clear = 0.0;
        for (int32 Step = 1; Step <= Steps; ++Step)
        {
            const auto Curl = float(Step) / float(Steps);
            if (Is_Touching(Rest, Sample_Distances(InRig, InShape, InHandWorld, InPose, FirstBone, Curl), Radius) == false)
            {
                Clear = Curl;
                continue;
            }

            // Refine between the last clear curl and this touching one.
            auto Touch = Curl;
            for (int32 Iteration = 0; Iteration < 4; ++Iteration)
            {
                const auto Mid = (Clear + Touch) * 0.5;
                if (Is_Touching(Rest, Sample_Distances(InRig, InShape, InHandWorld, InPose, FirstBone, Mid), Radius))
                { Touch = Mid; }
                else
                { Clear = Mid; }
            }
            return float32(Clear);
        }
        return 1.0f;
    }

    // A primitive fitted to a mesh's bounds (mesh space, MeshScale applied), placed by InMeshWorld.
    FMars_FPHands_ContactShape Make_BoundsShape(UStaticMesh InMesh, const FVector& InMeshScale, EMars_FPHands_GripShape InType,
                                                const FTransform& InMeshWorld)
    {
        auto Shape = FMars_FPHands_ContactShape();
        if (ck::Is_NOT_Valid(InMesh))
        { return Shape; }

        const auto Bounds = InMesh.GetBounds();
        const auto Extent = FVector(Math::Abs(Bounds.BoxExtent.X * InMeshScale.X), Math::Abs(Bounds.BoxExtent.Y * InMeshScale.Y),
                                    Math::Abs(Bounds.BoxExtent.Z * InMeshScale.Z));
        const auto CenterWorld = InMeshWorld.TransformPosition(Bounds.Origin * InMeshScale);

        Shape.IsValid = true;
        Shape.Type = InType == EMars_FPHands_GripShape::Auto ? EMars_FPHands_GripShape::Box : InType;
        Shape.World = FTransform(InMeshWorld.GetRotation(), CenterWorld, FVector::OneVector);
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

            const auto AxisWorld = InMeshWorld.GetRotation().RotateVector(Axis);
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
