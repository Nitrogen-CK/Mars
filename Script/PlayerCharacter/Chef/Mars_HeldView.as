// The held item as other players see it: the item in the third-person chef's hands, the arms reaching it.
//
// Nothing about items replicates (world items, hotbar, HeldItem and FPHands are all DoesNotReplicate), so the owner
// describes what it holds in an FMars_HeldView - the item's look and how the gloves grip it - and AMars_PlayerCharacter
// replicates that (_HeldView). Every machine then rebuilds the same hold on the body:
//   - the item: a static mesh on the body's grip_r bone, placed where the first-person system would put it relative to
//     the right glove's grip (Get_ItemInGrip);
//   - the arms: ABP_Chef's TwoBoneIK + Transform (Modify) Bone per hand, aimed at the gloves' first-person grip targets
//     laid out in a body "hand frame" in front of the chest (FMars_TPBody_Hold, Make_HoldFrame).
// The first-person grip math is reused, not copied: utils_fphands::Get_RestTargets is already a pure function of the
// FPHands spec and a hold, so the view converts its grip back to an FMars_FPHands_Hold (To_Hold) and calls it.

// How the gloves grip the held item: FMars_FPHands_Hold without its finger-contact shape (the body skips Contact Curl).
struct FMars_HeldView_Grip
{
    // Empty: nothing is held (the body shows no item and lowers its arms).
    UPROPERTY()
    EMars_FPHands_HoldKind Kind = EMars_FPHands_HoldKind::Empty;

    UPROPERTY()
    EMars_HandGripPose Pose = EMars_HandGripPose::Relaxed;

    UPROPERTY()
    EMars_HandGripLayout Layout = EMars_HandGripLayout::Sides;

    // Hand-space Y of the item's right and left faces (right is positive), world cm.
    UPROPERTY()
    float RightFaceY = 0.0;

    UPROPERTY()
    float LeftFaceY = 0.0;

    // Hand-space Z of the item's underside, world cm (a cradle's palms sit under it).
    UPROPERTY()
    float BottomZ = 0.0;

    // Authored Grip / Grip_R / Grip_L sockets on the item mesh, as grip bone targets in the hand node's space.
    UPROPERTY()
    bool HasSocketGrips = false;

    UPROPERTY()
    FTransform SocketGrip_R;

    UPROPERTY()
    FTransform SocketGrip_L;
}

// What a player holds, as replicated to everyone (AMars_PlayerCharacter::_HeldView). Every member is a UPROPERTY so it
// replicates; the meshes are soft so the struct carries paths, not objects.
struct FMars_HeldView
{
    UPROPERTY()
    TSoftObjectPtr<UStaticMesh> Mesh;

    UPROPERTY()
    TSoftObjectPtr<UMaterialInterface> Material;

    UPROPERTY()
    FVector MeshScale = FVector::OneVector;

    // The item relative to the first-person Hand node (UMars_ItemTrait_Presentation::HeldOffset).
    UPROPERTY()
    FTransform HeldOffset;

    UPROPERTY()
    FMars_HeldView_Grip Grip;

    // Bumped on every change the owner requests, so holding an identical item again still replicates and re-applies.
    UPROPERTY()
    int32 Serial = 0;
}

// Each glove's grip bone target for a hold, in the hand node's space (world cm), as utils_fphands::Get_RestTargets
// places them before any reach, lean or arm swing.
struct FMars_HeldView_GripTargets
{
    UPROPERTY()
    FTransform Right;

    UPROPERTY()
    FTransform Left;

    FMars_HeldView_GripTargets() {}

    FMars_HeldView_GripTargets(FTransform InRight, FTransform InLeft)
    {
        Right = InRight;
        Left = InLeft;
    }
}

// Where the chef's hands hold an item (Config.TPBody.Hold). All transforms are in the body mesh's component space
// (unscaled mesh units: the chef faces +Y, +X is its left, +Z up); offsets measured in the first-person hand node's space
// stay world cm and are shrunk by TPBody.Scale on the way in. The chef's arms are short for its body: a shoulder reaches
// about 17 body units, the hand bone sits 12.8 behind and 2.6 below grip_r, and the belly's front is at y +20.
struct FMars_TPBody_Hold
{
    // Plays the first-person Hand node's role for two-handed holds: the gloves' rest targets are laid out in it. At the
    // chest, yaw 90 (hand +X -> component +Y forward, hand +Y -> component -X the chef's right, +Z up), as far forward as
    // the arms reach a 30 cm item.
    UPROPERTY()
    FTransform HandFrame = FTransform(FRotator(0.0, 90.0, 0.0), FVector(0.0, 27.3, 36.6), FVector::OneVector);

    // One-handed holds move the frame this far, in its own space (world cm), like the first-person Hand node moves to
    // the right (Config.HandOffset vs FPHands.CenteredHandOffset). 36 cm puts hand_r 16.3 from its shoulder, beside the
    // belly; at the centre the wrist would be inside it.
    UPROPERTY()
    FVector OneHandedOffset = FVector(0.0, 36.0, 0.0);

    // Elbow pole targets (TwoBoneIK joint targets): behind (-Y is the chef's back) and outside the shoulders, at the
    // hands' height.
    UPROPERTY()
    FVector ElbowOffset_L = FVector(26.0, -10.0, 34.0);

    UPROPERTY()
    FVector ElbowOffset_R = FVector(-26.0, -10.0, 34.0);

    // Grip bone to palm surface, world cm; replaces FPHands.PalmSurfaceOffset for the body's fitted two-handed grips
    // (grip_r floats 1.5 body units off the glove's palm).
    UPROPERTY()
    float32 PalmSurfaceOffset = 2.8f;

    // How quickly the arms take or leave a hold, 1/s (FPHands.ReachInterpSpeed's feel); unset snaps.
    UPROPERTY()
    TOptional<float32> InterpSpeed = TOptional<float32>(14.0f);

    // How much of a swing's hand displacement the elbow pole targets follow, 0..1: the elbows rise with an overhead
    // windup and drop through the blow instead of pinning the arms to their hold pose.
    UPROPERTY()
    float32 SwingElbowFollow = 0.5f;

    // Socket-gripped tools (both hands stacked on one handle) are centred in the hand frame and pushed this far
    // forward along it (body units): the first-person offset that frames them low and to the right of the view is
    // screen framing, and at the frame itself the chunky gloves would sit in the robe.
    UPROPERTY()
    float32 SocketGripForward = 5.0f;
}

mixin FMars_Validation Validate(const FMars_TPBody_Hold& Self)
{
    // IsValid: finite, with a normalized rotation.
    if (Self.HandFrame.IsValid() == false)
    { return FMars_Validation(f"HandFrame [{Self.HandFrame}] is not finite or its rotation is not normalized"); }

    if (Self.HandFrame.GetScale3D().Equals(FVector::OneVector) == false)
    { return FMars_Validation(f"HandFrame scale [{Self.HandFrame.GetScale3D()}] must be one"); }

    if (utils_held_view::Get_IsFinite(Self.OneHandedOffset) == false)
    { return FMars_Validation(f"OneHandedOffset [{Self.OneHandedOffset}] is not finite"); }

    if ((utils_held_view::Get_IsFinite(Self.ElbowOffset_L) && utils_held_view::Get_IsFinite(Self.ElbowOffset_R)) == false)
    { return FMars_Validation(f"ElbowOffset_L [{Self.ElbowOffset_L}] / ElbowOffset_R [{Self.ElbowOffset_R}] is not finite"); }

    // A NaN fails the comparison, so it is rejected too.
    if ((Self.PalmSurfaceOffset >= 0.0f) == false)
    { return FMars_Validation(f"PalmSurfaceOffset [{Self.PalmSurfaceOffset}] must not be negative"); }

    if (Self.InterpSpeed.IsSet() && (Self.InterpSpeed.GetValue() > 0.0f) == false)
    { return FMars_Validation(f"InterpSpeed [{Self.InterpSpeed.GetValue()}] must be positive (unset snaps)"); }

    if ((Self.SwingElbowFollow >= 0.0f && Self.SwingElbowFollow <= 1.0f) == false)
    { return FMars_Validation(f"SwingElbowFollow [{Self.SwingElbowFollow}] is outside [0, 1]"); }

    if (Math::IsFinite(Self.SocketGripForward) == false)
    { return FMars_Validation(f"SocketGripForward [{Self.SocketGripForward}] is not finite"); }

    return FMars_Validation();
}

// One arm's pose for ABP_Chef, component space. The location and rotation are the HAND bone's (the IK and Modify Bone
// target hand_l / hand_r), already converted from the grip bone target.
struct FMars_TPBody_ArmTarget
{
    // 0 = the arm keeps the locomotion / montage pose.
    UPROPERTY()
    float32 Alpha = 0.0f;

    UPROPERTY()
    FVector HandLocation = FVector::ZeroVector;

    UPROPERTY()
    FRotator HandRotation = FRotator::ZeroRotator;

    UPROPERTY()
    FVector ElbowTarget = FVector::ZeroVector;
}

// Both arms (AMars_PlayerCharacter::Get_BodyHoldFrame); UMars_Chef_AnimInstance copies it into its _L / _R fields.
struct FMars_TPBody_HoldFrame
{
    UPROPERTY()
    FMars_TPBody_ArmTarget Left;

    UPROPERTY()
    FMars_TPBody_ArmTarget Right;
}

// What the body's arm targets are built from.
struct FMars_TPBody_HoldQuery
{
    // The gloves' grip targets for the hold (Get_GripTargets), hand node space, world cm.
    UPROPERTY()
    FMars_HeldView_GripTargets Grips;

    // A one-handed hold raises the right arm only, moved by OneHandedOffset.
    UPROPERTY()
    EMars_FPHands_HoldKind Kind = EMars_FPHands_HoldKind::Empty;

    // The grips come from the tool's authored sockets (a handle hold) rather than its fitted sides: they are centred in
    // the hand frame, their first-person framing offset dropped.
    UPROPERTY()
    bool IsSocketGrip = false;

    UPROPERTY()
    FMars_TPBody_Hold Hold;

    // TPBody.Scale: world cm per component unit.
    UPROPERTY()
    float32 BodyScale = 1.0f;

    // Each hand bone relative to its grip bone (the inverse of the grip bone's reference pose under the hand).
    UPROPERTY()
    FTransform HandInGrip_R;

    UPROPERTY()
    FTransform HandInGrip_L;

    // The hand's melee swing offset (the HandSwing pose), hand space, world cm. Identity at rest.
    UPROPERTY()
    FTransform Swing;
}

// HeldView is the PlayerCharacter's own namespace by ruling: the replicated hold view and the body's arm math have no
// typed-handle feature behind them, and they serve only AMars_PlayerCharacter and its anim instance.
namespace utils_held_view
{
    // The view of an item held by the local gloves: its Presentation look and utils_fphands::Make_Hold's grip.
    // Not holding when the item is invalid or has no Presentation.
    FMars_HeldView Make(const FCk_Handle_Item& InItem)
    {
        auto View = FMars_HeldView();
        if (ck::Is_NOT_Valid(InItem) || InItem.Has_Presentation() == false)
        { return View; }

        // As the WorldItem visual reads it: mesh, MeshScale on the visual, MaterialOverride on slot 0.
        const auto Presentation = InItem.Get_Presentation();
        View.Mesh = Presentation.Visual.Mesh;
        View.Material = Presentation.Visual.MaterialOverride;
        View.MeshScale = Presentation.Visual.MeshScale;
        View.HeldOffset = Presentation.Mounting.HeldOffset;

        const auto Hold = utils_fphands::Make_Hold(InItem);
        View.Grip.Kind = Hold.Kind;
        View.Grip.Pose = Hold.Pose;
        View.Grip.Layout = Hold.Layout;
        View.Grip.RightFaceY = Hold.Faces.RightY;
        View.Grip.LeftFaceY = Hold.Faces.LeftY;
        View.Grip.BottomZ = Hold.Faces.BottomZ;
        View.Grip.HasSocketGrips = Hold.SocketGrips.IsSet();
        if (Hold.SocketGrips.IsSet())
        {
            View.Grip.SocketGrip_R = Hold.SocketGrips.GetValue().Right;
            View.Grip.SocketGrip_L = Hold.SocketGrips.GetValue().Left;
        }
        return View;
    }

    // The first-person hold a grip stands for (no finger-contact shape).
    FMars_FPHands_Hold To_Hold(const FMars_HeldView_Grip& InGrip)
    {
        auto Hold = FMars_FPHands_Hold();
        Hold.Kind = InGrip.Kind;
        Hold.Pose = InGrip.Pose;
        Hold.Layout = InGrip.Layout;
        Hold.Faces = FMars_FPHands_HoldFaces(InGrip.RightFaceY, InGrip.LeftFaceY, InGrip.BottomZ);
        if (InGrip.HasSocketGrips)
        {
            auto SocketGrips = FMars_FPHands_SocketGrips();
            SocketGrips.Right = InGrip.SocketGrip_R;
            SocketGrips.Left = InGrip.SocketGrip_L;
            Hold.SocketGrips = TOptional<FMars_FPHands_SocketGrips>(SocketGrips);
        }
        return Hold;
    }

    // Where the gloves grip a held item, in the hand node's space: utils_fphands::Get_RestTargets itself (no arm swing).
    FMars_HeldView_GripTargets Get_GripTargets(const FMars_FPHands_Spec& InSpec, const FMars_HeldView_Grip& InGrip)
    {
        const auto Targets = utils_fphands::Get_RestTargets(InSpec.Rest, To_Hold(InGrip), FMars_FPHands_TargetFrame());
        return FMars_HeldView_GripTargets(Targets.Right.GripInHand, Targets.Left.GripInHand);
    }

    // The item relative to the right glove's grip bone (world cm). In first person the item sits at HeldOffset * Hand
    // and the grip at GripTarget_R * Hand, so item-in-grip = HeldOffset * Inverse(GripTarget_R) (UE order: left applies
    // first). The body's grip_r has the gloves' grip axes (X along the handle, Z out of the palm), so it maps 1:1.
    FTransform Get_ItemInGrip(const FMars_FPHands_Spec& InSpec, const FMars_HeldView& InView)
    {
        const auto Grips = Get_GripTargets(InSpec, InView.Grip);
        return InView.HeldOffset.GetRelativeTransform(Grips.Right);
    }

    // The body item component's transform relative to grip_r. The bone carries the body's Scale, so the location and
    // the mesh scale are divided by it: the item keeps its first-person world size and offset from the palm.
    FTransform Get_BodyItemTransform(const FTransform& InItemInGrip, const FVector& InMeshScale, float32 InBodyScale)
    {
        const auto Shrink = 1.0 / float(InBodyScale);
        const auto Scale = InItemInGrip.GetScale3D();
        return FTransform(InItemInGrip.GetRotation(), InItemInGrip.GetLocation() * Shrink,
            FVector(Scale.X * InMeshScale.X, Scale.Y * InMeshScale.Y, Scale.Z * InMeshScale.Z) * Shrink);
    }

    // Both arms' targets at full alpha (the character eases them): each grip target, shrunk to body units, laid out in
    // the hand frame (moved by OneHandedOffset for a one-handed hold, then swung by the swing offset, as the first-person
    // swing node moves the gloves and the item together), then converted to its hand bone. Socket grips are centred
    // on the frame first (Get_CentredGrips). The elbows follow a share of the swing's displacement. A one-handed hold
    // only raises the right arm.
    FMars_TPBody_HoldFrame Make_HoldFrame(const FMars_TPBody_HoldQuery& InQuery)
    {
        const auto& Hold = InQuery.Hold;
        auto RestFrame = Hold.HandFrame;
        if (InQuery.Kind != EMars_FPHands_HoldKind::TwoHanded)
        { RestFrame = Get_InBodyUnits(FTransform(FRotator::ZeroRotator, Hold.OneHandedOffset), InQuery.BodyScale) * Hold.HandFrame; }

        // The frame's own X is the hand node's forward (component +Y).
        if (InQuery.IsSocketGrip)
        { RestFrame = FTransform(FRotator::ZeroRotator, FVector(Hold.SocketGripForward, 0.0, 0.0), FVector::OneVector) * RestFrame; }

        const auto Frame = Get_InBodyUnits(InQuery.Swing, InQuery.BodyScale) * RestFrame;
        const auto ElbowFollow = RestFrame.TransformVector(InQuery.Swing.GetLocation() / float(InQuery.BodyScale)) * Hold.SwingElbowFollow;

        const auto Grips = InQuery.IsSocketGrip ? Get_CentredGrips(InQuery.Grips, InQuery.Kind) : InQuery.Grips;
        const auto GripR = Get_InBodyUnits(Grips.Right, InQuery.BodyScale) * Frame;
        const auto GripL = Get_InBodyUnits(Grips.Left, InQuery.BodyScale) * Frame;

        auto Result = FMars_TPBody_HoldFrame();
        Result.Right = Make_ArmTarget(InQuery.HandInGrip_R * GripR, Hold.ElbowOffset_R + ElbowFollow);
        Result.Left = Make_ArmTarget(InQuery.HandInGrip_L * GripL, Hold.ElbowOffset_L + ElbowFollow);
        Result.Right.Alpha = 1.0f;
        Result.Left.Alpha = InQuery.Kind == EMars_FPHands_HoldKind::TwoHanded ? 1.0f : 0.0f;
        return Result;
    }

    // The grips with their first-person framing removed: the midpoint of both (or the right grip alone, one-handed) is
    // moved to the hand node's origin, rotations and the hands' spacing kept. A tool the owner carries low and to the
    // right of its view is held in front of the body's chest, where its arms reach.
    FMars_HeldView_GripTargets Get_CentredGrips(const FMars_HeldView_GripTargets& InGrips, EMars_FPHands_HoldKind InKind)
    {
        const auto Centre = InKind == EMars_FPHands_HoldKind::TwoHanded
            ? (InGrips.Right.GetLocation() + InGrips.Left.GetLocation()) * 0.5
            : InGrips.Right.GetLocation();

        auto Grips = InGrips;
        Grips.Right.SetLocation(InGrips.Right.GetLocation() - Centre);
        Grips.Left.SetLocation(InGrips.Left.GetLocation() - Centre);
        return Grips;
    }

    // A transform measured in world cm (first-person hand node space) as body component units: its location shrinks by
    // the body's Scale, its rotation stays.
    FTransform Get_InBodyUnits(const FTransform& InWorldCm, float32 InBodyScale)
    {
        return FTransform(InWorldCm.GetRotation(), InWorldCm.GetLocation() / float(InBodyScale), FVector::OneVector);
    }

    FMars_TPBody_ArmTarget Make_ArmTarget(const FTransform& InHand, const FVector& InElbow)
    {
        auto Arm = FMars_TPBody_ArmTarget();
        Arm.HandLocation = InHand.GetLocation();
        Arm.HandRotation = InHand.Rotator();
        Arm.ElbowTarget = InElbow;
        return Arm;
    }

    // Moves one arm a Step (0..1) of the way to its target. An arm coming up from zero alpha takes the target pose at
    // once (nothing of the old pose shows); only the alpha eases in.
    FMars_TPBody_ArmTarget Ease_Arm(const FMars_TPBody_ArmTarget& InCurrent, const FMars_TPBody_ArmTarget& InTarget, float32 InStep)
    {
        auto Arm = InTarget;
        Arm.Alpha = Math::Lerp(InCurrent.Alpha, InTarget.Alpha, InStep);
        if (InCurrent.Alpha <= 0.001f)
        { return Arm; }

        Arm.HandLocation = Math::Lerp(InCurrent.HandLocation, InTarget.HandLocation, float(InStep));
        Arm.HandRotation = FQuat::Slerp(InCurrent.HandRotation.Quaternion(), InTarget.HandRotation.Quaternion(), float(InStep)).Rotator();
        Arm.ElbowTarget = Math::Lerp(InCurrent.ElbowTarget, InTarget.ElbowTarget, float(InStep));
        return Arm;
    }

    bool Get_IsFinite(const FVector& InVector)
    {
        return Math::IsFinite(InVector.X) && Math::IsFinite(InVector.Y) && Math::IsFinite(InVector.Z);
    }
}
