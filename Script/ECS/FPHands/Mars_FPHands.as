// Finger pose a glove plays. The order is the anim graph's Blend Poses by Int child index (ABP_FPHands) - append only.
enum EMars_HandGripPose
{
    Relaxed,
    Power,
    Pinch,
    Cradle,
    Hook,
    Fist,
    Open
}

// First-person glove emotes. The order indexes FMars_FPHands_Spec::EmoteMontages - append only.
enum EMars_FPEmote
{
    Wave,
    ThumbsUp,
    Point,
    Clap,
    FlipOff
}

// The local player's first-person gloves (floating hands). Remote players never see them (owner-only component).
struct FMars_FPHands_Spec
{
    UPROPERTY()
    TSoftObjectPtr<USkeletalMesh> Mesh;

    UPROPERTY()
    TSoftClassPtr<UAnimInstance> AnimClass;

    // Each glove's grip bone rotation relative to the camera at rest: palms in, thumbs up (matches A_FPHands_Ready).
    UPROPERTY()
    FRotator GripRestRotation_R = FRotator(65.186, -128.076, 144.583);

    UPROPERTY()
    FRotator GripRestRotation_L = FRotator(65.186, 128.076, -144.583);

    // Empty hands and two-handed items: the Hand node's rest offset from the camera, centred between the gloves so
    // sway and bob pivot at screen centre. One-handed items use Config.HandOffset (the right hand) instead.
    UPROPERTY()
    FTransform CenteredHandOffset = FTransform(FRotator::ZeroRotator, FVector(60.0, 0.0, -20.0), FVector::OneVector);

    // Empty hands: each glove rests this far to its side of the centred Hand node.
    UPROPERTY()
    float32 FreeHandHalfSpacing = 25.0f;

    // One-handed items: where the free left glove rests, in the (right-side) Hand node's space.
    UPROPERTY()
    FVector OffHandRestOffset = FVector(0.0, -50.0, 0.0);

    // Grip bone to palm surface; two-handed grips sit this far outside the item's sides.
    UPROPERTY()
    float32 PalmSurfaceOffset = 2.5f;

    // How quickly a glove travels to a new grip (reach, let go, re-grip), 1/s. 0 = snap. Only the grip change is
    // eased; hand sway and bob pass through unfiltered.
    UPROPERTY()
    float32 ReachInterpSpeed = 14.0f;

    // Locomotion bob of the hand node (CkGait Bob on Player.HandBob): stride dip/sway, jump/land bounce, breathing.
    UPROPERTY(Category = "Bob")
    FCk_Bob_Spec Bob;

    // Free hands swing forward/back in opposite phase, like arms (cm), from the character's gait.
    UPROPERTY(Category = "Arm Swing")
    float32 ArmSwingCm = 3.5f;

    // The hand swinging forward lifts a little (cm).
    UPROPERTY(Category = "Arm Swing")
    float32 ArmSwingLiftCm = 1.0f;

    // Leaning toward and reaching for interactables.
    UPROPERTY()
    FMars_FPHands_ReachSpec Reach;

    // Fingers stop on the surface of what the gloves hold or grab (CR_FPHands_Contact).
    UPROPERTY()
    FMars_FPHands_ContactSpec Contact;

    // Indexed by EMars_FPEmote. An emote montage drives both gloves (placement and fingers) through EmoteSlot; the
    // procedural placement fades out under it.
    UPROPERTY()
    TArray<TSoftObjectPtr<UAnimMontage>> EmoteMontages;

    UPROPERTY()
    FName EmoteSlot = n"DefaultSlot";

    UPROPERTY()
    float32 EmoteCancelBlendSeconds = 0.2f;
}

// Where one glove's grip bone should be, and which finger pose it plays.
struct FMars_FPHands_HandTarget
{
    // In the hand node's space; eased by the anim instance when it changes.
    UPROPERTY()
    FTransform GripInHand;

    // Added on top of GripInHand un-eased (arm swing), hand node space.
    UPROPERTY()
    FVector Swing;

    // Reach toward an interactable: the fully reached grip (hand node space) and how far along it the glove is.
    // Blended after the easing so the gesture timing stays crisp.
    UPROPERTY()
    FTransform ReachGrip;

    UPROPERTY()
    float32 ReachAlpha = 0.0f;

    UPROPERTY()
    EMars_HandGripPose Pose = EMars_HandGripPose::Relaxed;
}

struct FMars_FPHands_HandTargets
{
    UPROPERTY()
    FMars_FPHands_HandTarget Left;

    UPROPERTY()
    FMars_FPHands_HandTarget Right;
}

// What the glove targets are composed against this frame: the hand node's current world transform and each glove's
// arm swing (hand node space).
struct FMars_FPHands_TargetFrame
{
    UPROPERTY()
    FTransform HandWorld;

    UPROPERTY()
    FVector Swing_L;

    UPROPERTY()
    FVector Swing_R;

    FMars_FPHands_TargetFrame() {}

    FMars_FPHands_TargetFrame(FTransform InHandWorld, FVector InSwing_L, FVector InSwing_R)
    {
        HandWorld = InHandWorld;
        Swing_L = InSwing_L;
        Swing_R = InSwing_R;
    }
}

// How the current held item is gripped, measured once per item change.
struct FMars_FPHands_Hold
{
    UPROPERTY()
    bool IsHolding = false;

    UPROPERTY()
    bool IsTwoHanded = false;

    UPROPERTY()
    EMars_HandGripPose Pose = EMars_HandGripPose::Relaxed;

    // Hand-space Y of the item's right and left faces (right is positive).
    UPROPERTY()
    float RightFaceY = 0.0;

    UPROPERTY()
    float LeftFaceY = 0.0;

    // Authored Grip / Grip_R / Grip_L sockets on the item mesh, as grip bone targets in the hand node's space. They
    // replace the fitted grips (and decide one- vs two-handed).
    UPROPERTY()
    bool HasSocketGrips = false;

    UPROPERTY()
    FTransform SocketGrip_R;

    UPROPERTY()
    FTransform SocketGrip_L;

    // What the fingers close on: the item mesh bounds, placed by HeldOffset under the hand node.
    // Weak: fragments may not hold strong UObject refs (Schema.IsSafe); the item's presentation owns the mesh.
    UPROPERTY()
    TWeakObjectPtr<UStaticMesh> ShapeMesh;

    UPROPERTY()
    FVector ShapeScale = FVector::OneVector;

    UPROPERTY()
    FTransform ShapeOffset;

    UPROPERTY()
    EMars_FPHands_GripShape ShapeType = EMars_FPHands_GripShape::Auto;
}

namespace utils_fphands
{
    // Where the two gloves rest for a hold, in the hand node's space, before any reach or lean. Free hands take the
    // arm swing.
    FMars_FPHands_HandTargets Get_RestTargets(const FMars_FPHands_Spec& InSpec, const FMars_FPHands_Hold& InHold,
                                              const FMars_FPHands_TargetFrame& InFrame)
    {
        auto Targets = FMars_FPHands_HandTargets();
        Targets.Left.Swing = InFrame.Swing_L;
        Targets.Right.Swing = InFrame.Swing_R;
        // Empty hands: both gloves either side of the centred Hand node.
        auto GripRight = FTransform(InSpec.GripRestRotation_R, FVector(0.0, InSpec.FreeHandHalfSpacing, 0.0), FVector::OneVector);
        auto GripLeft = FTransform(InSpec.GripRestRotation_L, FVector(0.0, -InSpec.FreeHandHalfSpacing, 0.0), FVector::OneVector);
        Targets.Right.Pose = EMars_HandGripPose::Relaxed;
        Targets.Left.Pose = EMars_HandGripPose::Relaxed;

        if (InHold.IsHolding && InHold.IsTwoHanded)
        {
            GripRight = InHold.HasSocketGrips
                ? InHold.SocketGrip_R
                : FTransform(InSpec.GripRestRotation_R, FVector(0.0, InHold.RightFaceY + InSpec.PalmSurfaceOffset, 0.0), FVector::OneVector);
            GripLeft = InHold.HasSocketGrips
                ? InHold.SocketGrip_L
                : FTransform(InSpec.GripRestRotation_L, FVector(0.0, InHold.LeftFaceY - InSpec.PalmSurfaceOffset, 0.0), FVector::OneVector);
            Targets.Right.Pose = InHold.Pose;
            Targets.Left.Pose = InHold.Pose;
            Targets.Right.Swing = FVector::ZeroVector;
            Targets.Left.Swing = FVector::ZeroVector;
        }
        else if (InHold.IsHolding)
        {
            // The right hand carries the item at the (right-side) Hand node; only the free left hand swings.
            GripRight = InHold.HasSocketGrips
                ? InHold.SocketGrip_R
                : FTransform(InSpec.GripRestRotation_R, FVector::ZeroVector, FVector::OneVector);
            GripLeft = FTransform(InSpec.GripRestRotation_L, InSpec.OffHandRestOffset, FVector::OneVector);
            Targets.Right.Pose = InHold.Pose;
            Targets.Right.Swing = FVector::ZeroVector;
        }

        Targets.Right.GripInHand = GripRight;
        Targets.Left.GripInHand = GripLeft;
        return Targets;
    }

    // Hand node rest offset for a hold: right-side for one-handed items, centred otherwise.
    FTransform Get_HandRestOffset(const FMars_FPHands_Spec& InSpec, const FMars_FPHands_Hold& InHold, const FTransform& InOneHandedOffset)
    {
        if (InHold.IsHolding && InHold.IsTwoHanded == false)
        { return InOneHandedOffset; }

        return InSpec.CenteredHandOffset;
    }

    // Measures the held item's sides along the Hand node's Y axis (mesh bounds x scale, through HeldOffset).
    FMars_FPHands_Hold Make_Hold(const FCk_Handle_Item& InItem)
    {
        auto Hold = FMars_FPHands_Hold();
        if (ck::Is_NOT_Valid(InItem) || InItem.Has_Presentation() == false)
        { return Hold; }

        const auto Presentation = InItem.Get_Presentation();
        Hold.IsHolding = true;
        Hold.IsTwoHanded = Presentation.IsTwoHanded;
        Hold.Pose = Presentation.GripPose;
        Hold.ShapeScale = Presentation.MeshScale;
        Hold.ShapeOffset = Presentation.HeldOffset;
        Hold.ShapeType = Presentation.GripShape;
        if (Presentation.Mesh.IsNull() == false)
        { Hold.ShapeMesh = System::LoadAsset_Blocking(Presentation.Mesh); }

        // Authored sockets win over the fitted grips.
        if (Presentation.Mesh.IsNull() == false)
        {
            const auto Sockets = utils_fphands::Find_MeshSockets(System::LoadAsset_Blocking(Presentation.Mesh), Presentation.MeshScale);
            if (Sockets.HasRight)
            {
                Hold.HasSocketGrips = true;
                Hold.IsTwoHanded = Sockets.HasLeft;
                Hold.SocketGrip_R = Sockets.Right * Presentation.HeldOffset;
                Hold.SocketGrip_L = Sockets.Left * Presentation.HeldOffset;
                return Hold;
            }
        }

        if (Presentation.GripHalfWidth > 0.0f)
        {
            Hold.RightFaceY = Presentation.GripHalfWidth;
            Hold.LeftFaceY = -Presentation.GripHalfWidth;
            return Hold;
        }

        if (Presentation.Mesh.IsNull())
        { return Hold; }

        auto Mesh = System::LoadAsset_Blocking(Presentation.Mesh);
        if (ck::Is_NOT_Valid(Mesh))
        { return Hold; }

        const auto Bounds = Mesh.GetBounds();
        auto MinY = 1.0e10;
        auto MaxY = -1.0e10;
        for (int32 Corner = 0; Corner < 8; ++Corner)
        {
            const auto Sign = FVector((Corner & 1) != 0 ? 1.0 : -1.0, (Corner & 2) != 0 ? 1.0 : -1.0, (Corner & 4) != 0 ? 1.0 : -1.0);
            const auto Local = (Bounds.Origin + Bounds.BoxExtent * Sign) * Presentation.MeshScale;
            const auto InHand = Presentation.HeldOffset.TransformPosition(Local);
            MinY = Math::Min(MinY, InHand.Y);
            MaxY = Math::Max(MaxY, InHand.Y);
        }

        Hold.RightFaceY = MaxY;
        Hold.LeftFaceY = MinY;
        return Hold;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Glove targets (read the feature; composed by the anim instance with the hand node's current transform)
//--------------------------------------------------------------------------------------------------------------------------

// Where the two gloves go this frame, in the hand node's space: the rest targets for the hold, then a reach (or the
// focus lean) on each glove.
mixin void Get_HandTargets(const FCk_Handle_FPHands& Self, const FMars_FPHands_TargetFrame& InFrame, FMars_FPHands_HandTargets& OutTargets)
{
    OutTargets = utils_fphands::Get_RestTargets(Self.Get_Spec(), Self.Get_Hold(), InFrame);
    Self.Apply_HandReach(InFrame.HandWorld, true, OutTargets.Right);
    Self.Apply_HandReach(InFrame.HandWorld, false, OutTargets.Left);
}

// A glove takes the larger of its focus lean and its reach (to its own grip on the target); the reach's finger pose
// wins while it plays.
mixin void Apply_HandReach(const FCk_Handle_FPHands& Self, const FTransform& InHandWorld, bool InIsRightHand,
                           FMars_FPHands_HandTarget& InOutHand)
{
    const auto& Spec = Self.Get_Spec();
    const auto FocusTarget = Self.Get_FocusTarget();
    const auto IsReaching = Self.Get_IsReaching(InIsRightHand);
    const auto ReachAlpha = IsReaching ? Self.Get_ReachAlpha() : 0.0f;
    const auto LeanAlpha = InIsRightHand ? Self.Get_FocusAlpha_R() : Self.Get_FocusAlpha_L();
    const auto FocusAlpha = utils_fphands::Get_UsesHand(FocusTarget, InIsRightHand) ? LeanAlpha : 0.0f;
    const auto Alpha = Math::Max(ReachAlpha, FocusAlpha);
    if (Alpha <= 0.001f)
    { return; }

    auto Pose = Spec.Reach.ApproachPose;
    auto HasPose = IsReaching && Self.Get_ReachPose(Pose);
    if (HasPose == false)
    {
        Pose = Spec.Reach.ApproachPose;
        HasPose = FocusAlpha > Spec.Reach.FocusLean * 0.5f;
    }

    auto Target = FocusTarget;
    if (ReachAlpha >= FocusAlpha)
    { Target = Self.Get_Target(); }

    auto Grip = FMars_FPHands_GripQuery(InHandWorld, InIsRightHand, InOutHand.GripInHand);
    utils_fphands::Resolve_WorldGrip(Spec, Target, Grip);

    InOutHand.ReachGrip = utils_fphands::Make_ReachedGrip(Spec.Reach, Grip);
    InOutHand.ReachAlpha = Alpha;
    if (HasPose)
    { InOutHand.Pose = Pose; }
}
