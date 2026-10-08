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

// Player emotes, played on the first-person gloves (FMars_FPHands_EmoteSpec::Montages maps each to its montage) and the
// third-person body - append only. Each value's wheel tag is Mars.Emote.<value name> (utils_fphands::Get_EmoteTag /
// TryGet_Emote).
enum EMars_FPEmote
{
    Wave,
    ThumbsUp,
    Point,
    Clap,
    FlipOff,
    Cheer,
    Laugh,
    Bow,
    Dance,
    Shrug,
    Rest
}

// What the gloves hold: nothing, an item in the right glove, or an item in both.
enum EMars_FPHands_HoldKind
{
    Empty,
    OneHanded,
    TwoHanded
}

struct FMars_FPHands_VisualSpec
{
    UPROPERTY()
    TSoftObjectPtr<USkeletalMesh> Mesh;

    UPROPERTY()
    TSoftClassPtr<UAnimInstance> AnimClass;
}

// Where the gloves and their Hand node rest, before any reach or lean.
struct FMars_FPHands_RestSpec
{
    // Each glove's grip bone rotation relative to the camera at rest: palms in, thumbs up (matches A_FPHands_Ready).
    UPROPERTY()
    FRotator GripRotation_R = FRotator(65.186, -128.076, 144.583);

    UPROPERTY()
    FRotator GripRotation_L = FRotator(65.186, 128.076, -144.583);

    // Empty hands and two-handed items: the Hand node's rest offset from the camera, centred between the gloves so
    // sway and bob pivot at screen centre.
    UPROPERTY()
    FTransform CenteredHandOffset = FTransform(FRotator::ZeroRotator, FVector(60.0, 0.0, -20.0), FVector::OneVector);

    // One-handed items: the Hand node's rest offset from the camera, at the right glove that carries the item (X forward,
    // Y right, Z up).
    UPROPERTY()
    FTransform OneHandedHandOffset = FTransform(FRotator::ZeroRotator, FVector(60.0, 25.0, -20.0), FVector::OneVector);

    // Empty hands: each glove rests this far to its side of the centred Hand node.
    UPROPERTY()
    float32 FreeHandHalfSpacing = 25.0f;

    // One-handed items: where the free left glove rests, in the (right-side) Hand node's space.
    UPROPERTY()
    FVector OffHandRestOffset = FVector(0.0, -50.0, 0.0);

    // Grip bone to palm surface; two-handed grips sit this far outside the item's sides.
    UPROPERTY()
    float32 PalmSurfaceOffset = 2.5f;
}

// Free hands swing forward/back in opposite phase, like arms, from the character's gait.
struct FMars_FPHands_ArmSwingSpec
{
    UPROPERTY()
    float32 Cm = 3.5f;

    // The hand swinging forward lifts a little (cm).
    UPROPERTY()
    float32 LiftCm = 1.0f;
}

// An emote montage drives both gloves (placement and fingers) through Slot; the procedural placement fades out under it.
struct FMars_FPHands_EmoteSpec
{
    UPROPERTY()
    TMap<EMars_FPEmote, TSoftObjectPtr<UAnimMontage>> Montages;

    UPROPERTY()
    FName Slot = n"DefaultSlot";

    UPROPERTY()
    float32 CancelBlendSeconds = 0.2f;
}

// The local player's first-person gloves (floating hands). Remote players never see them (owner-only component).
struct FMars_FPHands_Spec
{
    // The swaying, bobbing hand node the gloves hang off (Player.HandBob, a CkGait bob node); reaches are measured from
    // it. Supplied by the owner at composition.
    UPROPERTY()
    FCk_Handle_Transform HandNode;

    UPROPERTY()
    FMars_FPHands_VisualSpec Visual;

    UPROPERTY()
    FMars_FPHands_RestSpec Rest;

    // How quickly a glove travels to a new grip (reach, let go, re-grip), 1/s; unset snaps. Only the grip change is
    // eased; hand sway and bob pass through unfiltered.
    UPROPERTY()
    TOptional<float32> ReachInterpSpeed = TOptional<float32>(14.0f);

    // Locomotion bob of the hand node (CkGait Bob on Player.HandBob): stride dip/sway, landing bounce, breathing. The
    // airborne lift is CkSway's, on the parent Hand node.
    UPROPERTY()
    FCk_Bob_Spec Bob;

    UPROPERTY()
    FMars_FPHands_ArmSwingSpec ArmSwing;

    // Leaning toward and reaching for interactables.
    UPROPERTY()
    FMars_FPHands_ReachSpec Reach;

    // Following through a drop or throw.
    UPROPERTY()
    FMars_FPHands_PushSpec Push;

    // Fingers stop on the surface of what the gloves hold or grab (CR_FPHands_Contact).
    UPROPERTY()
    FMars_FPHands_ContactSpec Contact;

    // First-person rendering of the gloves and what they hold.
    UPROPERTY()
    FMars_FPHands_ViewSpec View;

    // How much of the view's pitch the gloves follow.
    UPROPERTY()
    FMars_FPHands_PitchSpec Pitch;

    // Indexed by EMars_FPEmote. An emote montage drives both gloves (placement and fingers) through EmoteSlot; the
    // procedural placement fades out under it.
    UPROPERTY()
    FMars_FPHands_EmoteSpec Emotes;
}

// A hand node to hang off, positive rates and durations, and fractions within 0..1.
mixin FMars_Validation Validate(const FMars_FPHands_Spec& Self)
{
    if (ck::Is_NOT_Valid(Self.HandNode))
    { return FMars_Validation("HandNode is invalid"); }

    if (Self.ReachInterpSpeed.IsSet() && Self.ReachInterpSpeed.GetValue() <= 0.0f)
    { return FMars_Validation(f"ReachInterpSpeed [{Self.ReachInterpSpeed.GetValue()}] is not positive (unset snaps)"); }

    const auto& Reach = Self.Reach;
    if (Reach.Stretch.MaxReachCm.IsSet() && Reach.Stretch.MaxReachCm.GetValue() <= 0.0f)
    { return FMars_Validation(f"Reach.Stretch.MaxReachCm [{Reach.Stretch.MaxReachCm.GetValue()}] is not positive (unset is uncapped)"); }

    if (Reach.Focus.Lean < 0.0f || Reach.Focus.Lean > 1.0f)
    { return FMars_Validation(f"Reach.Focus.Lean [{Reach.Focus.Lean}] is outside [0, 1]"); }

    if (Reach.Stretch.AimFraction < 0.0f || Reach.Stretch.AimFraction > 1.0f)
    { return FMars_Validation(f"Reach.Stretch.AimFraction [{Reach.Stretch.AimFraction}] is outside [0, 1]"); }

    if (Reach.Grab.OutSeconds <= 0.0f || Reach.Grab.GripSeconds < 0.0f || Reach.Grab.BackSeconds <= 0.0f)
    { return FMars_Validation("Reach.Grab needs positive Out/Back seconds and non-negative Grip seconds"); }

    if (Reach.Hold.ReachSeconds <= 0.0f || Reach.Hold.ReleaseSeconds <= 0.0f)
    { return FMars_Validation("Reach.Hold needs positive Reach/Release seconds"); }

    if (Self.Push.OutSeconds <= 0.0f || Self.Push.BackSeconds <= 0.0f)
    { return FMars_Validation("Push needs positive Out/Back seconds"); }

    const auto Pitch = Self.Pitch.Validate();
    if (Pitch.IsValid() == false)
    { return Pitch; }

    return FMars_Validation();
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

// Both gloves' grip bone targets from authored sockets, in the hand node's space. Left is read by two-handed holds only.
struct FMars_FPHands_SocketGrips
{
    UPROPERTY()
    FTransform Right;

    UPROPERTY()
    FTransform Left;
}

// Hand-space Y of the held item's right and left faces (right is positive); fitted two-handed grips sit outside them.
struct FMars_FPHands_HoldFaces
{
    UPROPERTY()
    float RightY = 0.0;

    UPROPERTY()
    float LeftY = 0.0;

    FMars_FPHands_HoldFaces() {}

    FMars_FPHands_HoldFaces(float InRightY, float InLeftY)
    {
        RightY = InRightY;
        LeftY = InLeftY;
    }
}

// How the current held item is gripped, measured once per item change.
struct FMars_FPHands_Hold
{
    UPROPERTY()
    EMars_FPHands_HoldKind Kind = EMars_FPHands_HoldKind::Empty;

    UPROPERTY()
    EMars_HandGripPose Pose = EMars_HandGripPose::Relaxed;

    UPROPERTY()
    FMars_FPHands_HoldFaces Faces;

    // Authored Grip / Grip_R / Grip_L sockets on the item mesh; set, they replace the fitted grips.
    UPROPERTY()
    TOptional<FMars_FPHands_SocketGrips> SocketGrips;

    // What the fingers close on: the item mesh bounds, placed by HeldOffset under the hand node.
    UPROPERTY()
    FMars_FPHands_ShapeMesh Shape;

    UPROPERTY()
    FTransform HeldOffset;
}

// The glove closes on the held item: both for a two-handed hold, the right alone for a one-handed one.
mixin bool Get_HoldsWith(const FMars_FPHands_Hold& Self, EMars_Hand InHand)
{
    if (Self.Kind == EMars_FPHands_HoldKind::TwoHanded)
    { return true; }

    return Self.Kind == EMars_FPHands_HoldKind::OneHanded && InHand == EMars_Hand::Right;
}

namespace utils_fphands
{
    // How many EMars_FPEmote values there are: the enum's reflected names run out (or reach the generated _MAX entry)
    // past the last one.
    int32 Get_EmoteCount()
    {
        for (int32 Value = 0; Value < 255; ++Value)
        {
            const FString Name = f"{EMars_FPEmote(Value) :n}";
            if (Name.IsEmpty() || Name.EndsWith("_MAX"))
            { return Value; }
        }

        return 255;
    }

    // Mars.Emote.<the value's name>; invalid when that tag is not registered.
    FGameplayTag Get_EmoteTag(EMars_FPEmote InEmote)
    {
        return FGameplayTag::RequestGameplayTag(FName(f"Mars.Emote.{InEmote :n}"), false);
    }

    // The emote a Mars.Emote.* tag names (an emote wheel entry's Emote). False for any other tag.
    bool TryGet_Emote(FGameplayTag InTag, EMars_FPEmote& OutEmote)
    {
        if (InTag.IsValid() == false)
        { return false; }

        const auto Count = Get_EmoteCount();
        for (int32 Value = 0; Value < Count; ++Value)
        {
            if (Get_EmoteTag(EMars_FPEmote(Value)) != InTag)
            { continue; }

            OutEmote = EMars_FPEmote(Value);
            return true;
        }

        return false;
    }

    // Where the two gloves rest for a hold, in the hand node's space, before any reach or lean. Free hands take the
    // arm swing.
    FMars_FPHands_HandTargets Get_RestTargets(const FMars_FPHands_RestSpec& InRest, const FMars_FPHands_Hold& InHold,
                                              const FMars_FPHands_TargetFrame& InFrame)
    {
        auto Targets = FMars_FPHands_HandTargets();
        Targets.Left.Swing = InFrame.Swing_L;
        Targets.Right.Swing = InFrame.Swing_R;
        // Empty hands: both gloves either side of the centred Hand node.
        auto GripRight = FTransform(InRest.GripRotation_R, FVector(0.0, InRest.FreeHandHalfSpacing, 0.0), FVector::OneVector);
        auto GripLeft = FTransform(InRest.GripRotation_L, FVector(0.0, -InRest.FreeHandHalfSpacing, 0.0), FVector::OneVector);
        Targets.Right.Pose = EMars_HandGripPose::Relaxed;
        Targets.Left.Pose = EMars_HandGripPose::Relaxed;

        if (InHold.Kind == EMars_FPHands_HoldKind::TwoHanded)
        {
            if (InHold.SocketGrips.IsSet())
            {
                GripRight = InHold.SocketGrips.GetValue().Right;
                GripLeft = InHold.SocketGrips.GetValue().Left;
            }
            else
            {
                GripRight = FTransform(InRest.GripRotation_R, FVector(0.0, InHold.Faces.RightY + InRest.PalmSurfaceOffset, 0.0), FVector::OneVector);
                GripLeft = FTransform(InRest.GripRotation_L, FVector(0.0, InHold.Faces.LeftY - InRest.PalmSurfaceOffset, 0.0), FVector::OneVector);
            }
            Targets.Right.Pose = InHold.Pose;
            Targets.Left.Pose = InHold.Pose;
            Targets.Right.Swing = FVector::ZeroVector;
            Targets.Left.Swing = FVector::ZeroVector;
        }
        else if (InHold.Kind == EMars_FPHands_HoldKind::OneHanded)
        {
            // The right hand carries the item at the (right-side) Hand node; only the free left hand swings.
            GripRight = InHold.SocketGrips.IsSet()
                ? InHold.SocketGrips.GetValue().Right
                : FTransform(InRest.GripRotation_R, FVector::ZeroVector, FVector::OneVector);
            GripLeft = FTransform(InRest.GripRotation_L, InRest.OffHandRestOffset, FVector::OneVector);
            Targets.Right.Pose = InHold.Pose;
            Targets.Right.Swing = FVector::ZeroVector;
        }

        Targets.Right.GripInHand = GripRight;
        Targets.Left.GripInHand = GripLeft;
        return Targets;
    }

    // A HeldOffset that stands a handle-along-+X tool on end: pitched InStandDeg toward +Z (90 is straight up; the
    // tool's -Z face, an edge or a toothed face, turns to face forward), then leaned InLeanDeg about the view's
    // forward axis so the top tips toward screen centre (positive leans a tool held on the right to the left). The
    // tool's pivot (its rear grip) lands at InPivot in the hand node's space. Composed as quaternions: a rotator's
    // roll would spin the tool about its own handle instead of leaning it.
    FTransform Make_UprightHeldOffset(const FVector& InPivot, float32 InStandDeg, float32 InLeanDeg)
    {
        const auto Stand = FQuat(FVector::RightVector, Math::DegreesToRadians(-InStandDeg));
        const auto Lean = FQuat(FVector::ForwardVector, Math::DegreesToRadians(InLeanDeg));
        return FTransform(Lean * Stand, InPivot, FVector::OneVector);
    }

    // A socket grip turned InDegrees about its own X (the handle), in place: the glove keeps its spot on the handle and
    // the forearm swings round it (FMars_ItemPresentation_Grip::SocketTwist_R / _L).
    FTransform Twist_AboutHandle(const FTransform& InSocket, float32 InDegrees)
    {
        if (Math::IsNearlyZero(InDegrees))
        { return InSocket; }

        return FTransform(FQuat(FVector::ForwardVector, Math::DegreesToRadians(InDegrees)), FVector::ZeroVector, FVector::OneVector) * InSocket;
    }

    // Hand node rest offset for a hold: right-side for one-handed items, centred otherwise.
    FTransform Get_HandRestOffset(const FMars_FPHands_RestSpec& InRest, const FMars_FPHands_Hold& InHold)
    {
        if (InHold.Kind == EMars_FPHands_HoldKind::OneHanded)
        { return InRest.OneHandedHandOffset; }

        return InRest.CenteredHandOffset;
    }

    // The item's sides along the Hand node's Y axis: its mesh bounds x InMeshScale, placed by InHeldOffset.
    FMars_FPHands_HoldFaces Measure_Faces(UStaticMesh InMesh, const FVector& InMeshScale, const FTransform& InHeldOffset)
    {
        const auto Bounds = InMesh.GetBounds();
        auto MinY = 1.0e10;
        auto MaxY = -1.0e10;
        for (int32 Corner = 0; Corner < 8; ++Corner)
        {
            const auto Sign = FVector((Corner & 1) != 0 ? 1.0 : -1.0, (Corner & 2) != 0 ? 1.0 : -1.0, (Corner & 4) != 0 ? 1.0 : -1.0);
            const auto Local = (Bounds.Origin + Bounds.BoxExtent * Sign) * InMeshScale;
            const auto InHand = InHeldOffset.TransformPosition(Local);
            MinY = Math::Min(MinY, InHand.Y);
            MaxY = Math::Max(MaxY, InHand.Y);
        }

        return FMars_FPHands_HoldFaces(MaxY, MinY);
    }

    // How the gloves grip InItem: authored sockets win (and decide one- vs two-handed), then the presentation's
    // Grip.HalfWidth, then the mesh bounds. An invalid item, or one without a presentation, is empty hands.
    FMars_FPHands_Hold Make_Hold(const FCk_Handle_Item& InItem)
    {
        auto Hold = FMars_FPHands_Hold();
        if (ck::Is_NOT_Valid(InItem) || InItem.Has_Presentation() == false)
        { return Hold; }

        const auto Presentation = InItem.Get_Presentation();
        const auto IsTwoHanded = Presentation.Grip.Handedness == EMars_ItemPresentation_Handedness::TwoHanded;
        Hold.Kind = IsTwoHanded ? EMars_FPHands_HoldKind::TwoHanded : EMars_FPHands_HoldKind::OneHanded;
        Hold.Pose = Presentation.Grip.Pose;
        Hold.HeldOffset = Presentation.Mounting.HeldOffset;
        Hold.Shape.Scale = Presentation.Visual.MeshScale;
        Hold.Shape.Type = Presentation.Grip.Shape;
        if (Presentation.Grip.HalfWidth.IsSet())
        {
            const auto HalfWidth = Presentation.Grip.HalfWidth.GetValue();
            Hold.Faces = FMars_FPHands_HoldFaces(HalfWidth, -HalfWidth);
        }

        if (Presentation.Visual.Mesh.IsNull())
        { return Hold; }

        auto Mesh = System::LoadAsset_Blocking(Presentation.Visual.Mesh);
        if (ck::EnsureIfNot(ck::IsValid(Mesh), f"[FPHands] the presentation mesh of [{InItem.ToString()}] does not load"))
        { return Hold; }

        Hold.Shape.Mesh = Mesh;

        const auto Sockets = utils_fphands::Find_MeshSockets(Mesh, Presentation.Visual.MeshScale);
        if (Sockets.IsSet())
        {
            const auto Grips = Sockets.GetValue();
            auto SocketGrips = FMars_FPHands_SocketGrips();
            SocketGrips.Right = Twist_AboutHandle(Grips.Right, Presentation.Grip.SocketTwist_R) * Presentation.Mounting.HeldOffset;
            Hold.Kind = EMars_FPHands_HoldKind::OneHanded;
            if (Grips.Left.IsSet())
            {
                SocketGrips.Left = Twist_AboutHandle(Grips.Left.GetValue(), Presentation.Grip.SocketTwist_L) * Presentation.Mounting.HeldOffset;
                Hold.Kind = EMars_FPHands_HoldKind::TwoHanded;
            }

            Hold.SocketGrips = TOptional<FMars_FPHands_SocketGrips>(SocketGrips);
            return Hold;
        }

        if (Presentation.Grip.HalfWidth.IsSet() == false)
        { Hold.Faces = Measure_Faces(Mesh, Presentation.Visual.MeshScale, Presentation.Mounting.HeldOffset); }

        return Hold;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Glove targets (read the feature; composed by the anim instance with the hand node's current transform)
//--------------------------------------------------------------------------------------------------------------------------

// Where the gloves go this frame, in the hand node's space: the rest targets for the hold, then a reach (or the
// focus lean) on each glove. A push follows through from the hold the item launched from instead.
mixin void Get_HandTargets(const FCk_Handle_FPHands& Self, const FMars_FPHands_TargetFrame& InFrame, FMars_FPHands_HandTargets& OutTargets)
{
    const auto& Rest = Self.Get_Spec().Rest;
    if (Self.Get_Phase() == EMars_FPHands_Phase::Push)
    {
        OutTargets = utils_fphands::Get_RestTargets(Rest, Self.Get_PushHold(), InFrame);
        Self.Apply_HandPush(OutTargets);
        return;
    }

    OutTargets = utils_fphands::Get_RestTargets(Rest, Self.Get_Hold(), InFrame);
    Self.Apply_HandReach(InFrame.HandWorld, EMars_Hand::Right, OutTargets.Right);
    Self.Apply_HandReach(InFrame.HandWorld, EMars_Hand::Left, OutTargets.Left);
}

// A glove takes the larger of its focus lean and its reach (to its own grip on the target); the reach's finger pose (or
// that glove's pose override) wins while it plays.
mixin void Apply_HandReach(const FCk_Handle_FPHands& Self, const FTransform& InHandWorld, EMars_Hand InHand,
                           FMars_FPHands_HandTarget& InOutHand)
{
    const auto& Spec = Self.Get_Spec();
    const auto FocusTarget = Self.Get_FocusTarget();
    const auto IsReaching = Self.Get_IsReaching(InHand);
    const auto ReachAlpha = IsReaching ? Self.Get_ReachAlpha() : 0.0f;
    const auto FocusAlpha = utils_fphands::Get_UsesHand(FocusTarget, InHand) ? Self.Get_FocusAlpha(InHand) : 0.0f;
    const auto Alpha = Math::Max(ReachAlpha, FocusAlpha);
    if (Alpha <= 0.001f)
    { return; }

    // A glove on a reach target plays its override (a station feed's grasp) over the reach's own pose.
    auto Pose = TOptional<EMars_HandGripPose>();
    if (IsReaching)
    {
        Pose = Self.TryGet_ReachPose(InHand);
        const auto Override = Self.TryGet_PoseOverride(InHand);
        if (Override.IsSet())
        { Pose = Override; }
    }

    if (Pose.IsSet() == false && FocusAlpha > Spec.Reach.Focus.Lean * 0.5f)
    { Pose = TOptional<EMars_HandGripPose>(Spec.Reach.Poses.Approach); }

    // The reach target when it leads, else the focus target; whichever it is uses this glove (its alpha is above zero).
    auto Target = FocusTarget;
    if (ReachAlpha >= FocusAlpha)
    { Target = Self.Get_Target(); }

    auto Grip = FMars_FPHands_GripQuery(InHandWorld, InHand, InOutHand.GripInHand);
    utils_fphands::Resolve_WorldGrip(Spec, Target.GetValue(), Grip);

    InOutHand.ReachGrip = utils_fphands::Make_ReachedGrip(Spec.Reach, Grip);
    InOutHand.ReachAlpha = Alpha;
    if (Pose.IsSet())
    { InOutHand.Pose = Pose.GetValue(); }
}
