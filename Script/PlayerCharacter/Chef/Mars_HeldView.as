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
    UPROPERTY()
    bool IsTwoHanded = false;

    UPROPERTY()
    EMars_HandGripPose Pose = EMars_HandGripPose::Relaxed;

    // Hand-space Y of the item's right and left faces (right is positive), world cm.
    UPROPERTY()
    float RightFaceY = 0.0;

    UPROPERTY()
    float LeftFaceY = 0.0;

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

    UPROPERTY()
    bool IsHolding = false;
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
// stay world cm and are shrunk by TPBody.Scale on the way in.
//
// Derivation (SK_Chef reference pose, read back in the editor 2026-10-03, component space):
//   spine_03 (0, -6.5, 47); upperarm_r (-19, -8, 57) / _l (19, -8, 57); lowerarm 13.39 from the upperarm, hand 6.76
//   from the lowerarm, so a shoulder reaches 20.15. grip_r sits on hand_r at local (7.30, -0.25, 3.20), the same
//   rotation as SK_FPHands' grip_r (its offset there is (8.20, -0.41, 3.18)): with the gloves' rest rotation the hand
//   bone lands 7.2 behind and 3.3 below its grip. The torso's front is at y +9..+12 from z 36 to 60.
//   HandFrame (0, 16, 50), yaw 90 (hand +X -> component +Y forward, hand +Y -> component -X the chef's right, +Z up):
//   22.5 in front of spine_03, at the chest; a 30 cm item (half width 15 world cm) puts hand_r at (-16.8, 8.8, 46.7),
//   19.8 from its shoulder (98% of the reach); a 50 cm item's hands sit 20.9 out, just past the reach. Further forward
//   the stubby arms cannot follow (the brief's y 24 needs 27.7). An item deeper than ~12 world cm still sinks into the
//   belly: the chef's arms are shorter than its torso is deep.
struct FMars_TPBody_Hold
{
    // Plays the first-person Hand node's role for two-handed holds: the gloves' rest targets are laid out in it.
    UPROPERTY()
    FTransform HandFrame = FTransform(FRotator(0.0, 90.0, 0.0), FVector(0.0, 16.0, 50.0), FVector::OneVector);

    // One-handed holds move the frame this far, in its own space (world cm), like the first-person Hand node moves to
    // the right (Config.HandOffset vs FPHands.CenteredHandOffset). 14 cm puts hand_r 20.4 from its shoulder; at the
    // centre it would need 26.7.
    UPROPERTY()
    FVector OneHandedOffset = FVector(0.0, 14.0, 0.0);

    // Elbow pole targets (TwoBoneIK joint targets): behind (-Y is the chef's back) and outside the shoulders, at the
    // hands' height.
    UPROPERTY()
    FVector ElbowOffset_L = FVector(24.0, -12.0, 46.0);

    UPROPERTY()
    FVector ElbowOffset_R = FVector(-24.0, -12.0, 46.0);

    // Grip bone to palm surface, world cm; replaces FPHands.PalmSurfaceOffset for the body's fitted two-handed grips.
    UPROPERTY()
    float32 PalmSurfaceOffset = 2.5f;

    // How quickly the arms take or leave a hold, 1/s (FPHands.ReachInterpSpeed's feel). 0 = snap.
    UPROPERTY()
    float32 InterpSpeed = 14.0f;
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

    if ((Self.InterpSpeed >= 0.0f) == false)
    { return FMars_Validation(f"InterpSpeed [{Self.InterpSpeed}] must not be negative"); }

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

    UPROPERTY()
    bool IsTwoHanded = false;

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
}

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
        View.Mesh = Presentation.Mesh;
        View.Material = Presentation.MaterialOverride;
        View.MeshScale = Presentation.MeshScale;
        View.HeldOffset = Presentation.HeldOffset;

        const auto Hold = utils_fphands::Make_Hold(InItem);
        View.IsHolding = Hold.IsHolding;
        View.Grip.IsTwoHanded = Hold.IsTwoHanded;
        View.Grip.Pose = Hold.Pose;
        View.Grip.RightFaceY = Hold.RightFaceY;
        View.Grip.LeftFaceY = Hold.LeftFaceY;
        View.Grip.HasSocketGrips = Hold.HasSocketGrips;
        View.Grip.SocketGrip_R = Hold.SocketGrip_R;
        View.Grip.SocketGrip_L = Hold.SocketGrip_L;
        return View;
    }

    // The first-person hold a grip stands for (holding, no finger-contact shape).
    FMars_FPHands_Hold To_Hold(const FMars_HeldView_Grip& InGrip)
    {
        auto Hold = FMars_FPHands_Hold();
        Hold.IsHolding = true;
        Hold.IsTwoHanded = InGrip.IsTwoHanded;
        Hold.Pose = InGrip.Pose;
        Hold.RightFaceY = InGrip.RightFaceY;
        Hold.LeftFaceY = InGrip.LeftFaceY;
        Hold.HasSocketGrips = InGrip.HasSocketGrips;
        Hold.SocketGrip_R = InGrip.SocketGrip_R;
        Hold.SocketGrip_L = InGrip.SocketGrip_L;
        return Hold;
    }

    // Where the gloves grip a held item, in the hand node's space: utils_fphands::Get_RestTargets itself (no arm swing).
    FMars_HeldView_GripTargets Get_GripTargets(const FMars_FPHands_Spec& InSpec, const FMars_HeldView_Grip& InGrip)
    {
        const auto Targets = utils_fphands::Get_RestTargets(InSpec, To_Hold(InGrip), FMars_FPHands_TargetFrame());
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
    // the hand frame (moved by OneHandedOffset for a one-handed hold), then converted to its hand bone. A one-handed hold
    // only raises the right arm.
    FMars_TPBody_HoldFrame Make_HoldFrame(const FMars_TPBody_HoldQuery& InQuery)
    {
        const auto& Hold = InQuery.Hold;
        auto Frame = Hold.HandFrame;
        if (InQuery.IsTwoHanded == false)
        { Frame = Get_InBodyUnits(FTransform(FRotator::ZeroRotator, Hold.OneHandedOffset), InQuery.BodyScale) * Hold.HandFrame; }

        const auto GripR = Get_InBodyUnits(InQuery.Grips.Right, InQuery.BodyScale) * Frame;
        const auto GripL = Get_InBodyUnits(InQuery.Grips.Left, InQuery.BodyScale) * Frame;

        auto Result = FMars_TPBody_HoldFrame();
        Result.Right = Make_ArmTarget(InQuery.HandInGrip_R * GripR, Hold.ElbowOffset_R);
        Result.Left = Make_ArmTarget(InQuery.HandInGrip_L * GripL, Hold.ElbowOffset_L);
        Result.Right.Alpha = 1.0f;
        Result.Left.Alpha = InQuery.IsTwoHanded ? 1.0f : 0.0f;
        return Result;
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
