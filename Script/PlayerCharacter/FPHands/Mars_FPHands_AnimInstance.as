// One glove's frame for the finger contact: its lowerarm (component space) and the finger pose it plays.
struct FMars_FPHands_GloveFrame
{
    UPROPERTY()
    FTransform LowerArm;

    UPROPERTY()
    EMars_HandGripPose Pose = EMars_HandGripPose::Relaxed;

    FMars_FPHands_GloveFrame() {}

    FMars_FPHands_GloveFrame(FTransform InLowerArm, EMars_HandGripPose InPose)
    {
        LowerArm = InLowerArm;
        Pose = InPose;
    }
}

// What the finger contact solves against this frame.
struct FMars_FPHands_ContactFrame
{
    UPROPERTY()
    FMars_FPHands_GloveFrame Left;

    UPROPERTY()
    FMars_FPHands_GloveFrame Right;

    UPROPERTY()
    FTransform HandNodeWorld;

    UPROPERTY()
    FTransform ComponentWorld;

    UPROPERTY()
    float32 DeltaSeconds = 0.0f;

    // An emote montage owns the fingers; no contact.
    UPROPERTY()
    bool IsEmoting = false;
}

// The glove mesh's reference pose, read once.
struct FMars_FPHands_GloveRefPose
{
    // lowerarm expressed in its grip bone's space; the glove is rigid from lowerarm to grip.
    UPROPERTY()
    FTransform LowerArmInGrip_L;

    UPROPERTY()
    FTransform LowerArmInGrip_R;

    // Unset when the mesh lacks the digit bones: finger contact is then off.
    UPROPERTY()
    TOptional<FMars_FPHands_ContactRig> ContactRig;
}

// Both gloves' eased grips in the hand node's space.
struct FMars_FPHands_GloveGrips
{
    UPROPERTY()
    FTransform Left;

    UPROPERTY()
    FTransform Right;

    FMars_FPHands_GloveGrips() {}

    FMars_FPHands_GloveGrips(FTransform InLeft, FTransform InRight)
    {
        Left = InLeft;
        Right = InRight;
    }
}

// Parent class of ABP_FPHands. Composes per-glove grip targets from the pawn's FPHands feature (read only) and turns
// them into what the anim graph needs: a finger pose index per glove and a component-space transform for each floating
// glove's lowerarm bone.
class UMars_FPHands_AnimInstance : UAnimInstance
{
    // Blend Poses by Int child index per glove (EMars_HandGripPose).
    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "FPHands")
    int32 GripPoseIndex_L = 0;

    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "FPHands")
    int32 GripPoseIndex_R = 0;

    // Component space; fed to the Transform (Modify) Bone nodes on lowerarm_l / lowerarm_r.
    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "FPHands")
    FVector LowerArmLocation_L;

    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "FPHands")
    FRotator LowerArmRotation_L;

    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "FPHands")
    FVector LowerArmLocation_R;

    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "FPHands")
    FRotator LowerArmRotation_R;

    // 0 until the owner provides targets (editor preview, pawn still constructing) - the gloves keep their anim pose.
    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "FPHands")
    float32 PlacementAlpha = 0.0f;

    // Finger contact, fed to CR_FPHands_Contact: how far (0..1) each digit closes toward its authored grip pose.
    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "FPHands|Contact")
    float32 Curl_L_Thumb = 1.0f;

    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "FPHands|Contact")
    float32 Curl_L_Index = 1.0f;

    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "FPHands|Contact")
    float32 Curl_L_Middle = 1.0f;

    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "FPHands|Contact")
    float32 Curl_L_Pinky = 1.0f;

    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "FPHands|Contact")
    float32 Curl_R_Thumb = 1.0f;

    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "FPHands|Contact")
    float32 Curl_R_Index = 1.0f;

    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "FPHands|Contact")
    float32 Curl_R_Middle = 1.0f;

    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "FPHands|Contact")
    float32 Curl_R_Pinky = 1.0f;

    // The same curls as pose curves (Curl_L_Thumb ... Curl_R_Pinky): a Modify Curve node writes them into the pose and
    // CR_FPHands_Contact reads them back into its variables (its input mapping works on curves).
    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "FPHands|Contact")
    TMap<FName, float32> ContactCurves;

    // Unset until the first update with a pawn.
    private TOptional<FMars_FPHands_GloveRefPose> _RefPose;

    // Unset until the first targets arrive, which the gloves then snap to.
    private TOptional<FMars_FPHands_GloveGrips> _Grips;

    UFUNCTION(BlueprintOverride)
    void BlueprintUpdateAnimation(float DeltaTimeX)
    {
        auto Character = Cast<AMars_PlayerCharacter>(TryGetPawnOwner());
        auto Mesh = GetOwningComponent();
        if (ck::Is_NOT_Valid(Character) || ck::Is_NOT_Valid(Mesh))
        {
            PlacementAlpha = 0.0f;
            return;
        }

        auto Hands = FCk_Handle_FPHands();
        if (Character.Get_IsActorEcsReady())
        { Hands = Character.TryGet_ActorEntityHandle().As_FPHands(ECk_SanityCheck::UnChecked); }

        if (ck::Is_NOT_Valid(Hands))
        {
            PlacementAlpha = 0.0f;
            _Grips.Reset();
            return;
        }

        const auto& Spec = Hands.Get_Spec();

        // Composed here, with the hand node's current transform, rather than stored by the feature: an ECS-time
        // composition reads the hand node one settle behind and jitters under movement.
        const auto HandWorld = utils_transform::Get_EntityCurrentTransform(Hands.Get_HandNode());
        auto Targets = FMars_FPHands_HandTargets();
        Hands.Get_HandTargets(FMars_FPHands_TargetFrame(HandWorld, Hands.Get_ArmSwing(EMars_Hand::Left), Hands.Get_ArmSwing(EMars_Hand::Right)), Targets);
        const auto& Left = Targets.Left;
        const auto& Right = Targets.Right;

        if (_RefPose.IsSet() == false)
        { _RefPose = TOptional<FMars_FPHands_GloveRefPose>(Make_RefPose(Mesh)); }

        const auto RefPose = _RefPose.GetValue();

        // Only the grip change is eased; the hand node's sway and bob, and the arm swing, stay crisp.
        if (_Grips.IsSet() == false || Spec.ReachInterpSpeed.IsSet() == false)
        { _Grips = TOptional<FMars_FPHands_GloveGrips>(FMars_FPHands_GloveGrips(Left.GripInHand, Right.GripInHand)); }
        else
        {
            const auto GripAlpha = Math::Clamp(1.0 - Math::Exp(-Spec.ReachInterpSpeed.GetValue() * DeltaTimeX), 0.0, 1.0);
            const auto Previous = _Grips.GetValue();
            _Grips = TOptional<FMars_FPHands_GloveGrips>(FMars_FPHands_GloveGrips(
                InterpGrip(Previous.Left, Left.GripInHand, GripAlpha), InterpGrip(Previous.Right, Right.GripInHand, GripAlpha)));
        }

        const auto Grips = _Grips.GetValue();

        // The gloves attach to the UCk_CameraComponent, which FollowView moves onto the rendered view at the end of the frame;
        // the hand node hangs off that same view (the director's view anchor). Composing against the anchor rather than
        // Mesh.GetWorldTransform() keeps both sides in one ECS snapshot whatever the actor/ECS tick order.
        const auto Viewpoint = Character.TryGet_ActorEntityHandle().As_PlayerViewpoint().Get_Viewpoint();
        const auto ComponentWorld = Mesh.GetRelativeTransform() * utils_transform::Get_EntityCurrentTransform(Viewpoint);

        const auto Grip_L = (WithReach(WithSwing(Grips.Left, Left.Swing), Left) * HandWorld).GetRelativeTransform(ComponentWorld);
        const auto Grip_R = (WithReach(WithSwing(Grips.Right, Right.Swing), Right) * HandWorld).GetRelativeTransform(ComponentWorld);

        const auto LowerArm_L = RefPose.LowerArmInGrip_L * Grip_L;
        const auto LowerArm_R = RefPose.LowerArmInGrip_R * Grip_R;
        LowerArmLocation_L = LowerArm_L.GetLocation();
        LowerArmRotation_L = LowerArm_L.Rotator();
        LowerArmLocation_R = LowerArm_R.GetLocation();
        LowerArmRotation_R = LowerArm_R.Rotator();

        GripPoseIndex_L = int32(Left.Pose);
        GripPoseIndex_R = int32(Right.Pose);

        // An emote montage owns both gloves while it plays; the procedural placement fades out under it.
        const auto EmoteWeight = Blueprint_GetSlotMontageLocalWeight(Spec.Emotes.Slot);
        PlacementAlpha = float32(1.0 - Math::Clamp(EmoteWeight, 0.0, 1.0));

        auto ContactFrame = FMars_FPHands_ContactFrame();
        ContactFrame.Left = FMars_FPHands_GloveFrame(LowerArm_L, Left.Pose);
        ContactFrame.Right = FMars_FPHands_GloveFrame(LowerArm_R, Right.Pose);
        ContactFrame.HandNodeWorld = HandWorld;
        ContactFrame.ComponentWorld = ComponentWorld;
        ContactFrame.DeltaSeconds = float32(DeltaTimeX);
        ContactFrame.IsEmoting = EmoteWeight > 0.01;
        Update_Contact(Spec.Contact, Hands, ContactFrame);
    }

    private void Update_Contact(const FMars_FPHands_ContactSpec& InSpec, const FCk_Handle_FPHands& InHands,
                                const FMars_FPHands_ContactFrame& InFrame)
    {
        auto Shapes = FMars_FPHands_ContactShapes();
        const auto ContactRig = _RefPose.GetValue().ContactRig;
        if (ContactRig.IsSet() && InSpec.EnableDisable == ECk_EnableDisable::Enable && InFrame.IsEmoting == false)
        { InHands.Get_ContactShapes(InFrame.HandNodeWorld, Shapes); }

        auto Glove_L = TOptional<FMars_FPHands_DigitQuery>();
        auto Glove_R = TOptional<FMars_FPHands_DigitQuery>();
        if (Shapes.Left.IsSet())
        {
            const auto HandWorld = ContactRig.GetValue().HandInLowerArm_L * InFrame.Left.LowerArm * InFrame.ComponentWorld;
            Glove_L = TOptional<FMars_FPHands_DigitQuery>(FMars_FPHands_DigitQuery(Shapes.Left.GetValue(), HandWorld, InFrame.Left.Pose, EMars_Hand::Left));
        }

        if (Shapes.Right.IsSet())
        {
            const auto HandWorld = ContactRig.GetValue().HandInLowerArm_R * InFrame.Right.LowerArm * InFrame.ComponentWorld;
            Glove_R = TOptional<FMars_FPHands_DigitQuery>(FMars_FPHands_DigitQuery(Shapes.Right.GetValue(), HandWorld, InFrame.Right.Pose, EMars_Hand::Right));
        }

        const auto Alpha = float32(1.0 - Math::Exp(-InSpec.CurlInterpSpeed * InFrame.DeltaSeconds));
        Curl_L_Thumb  = Ease(Curl_L_Thumb,  Solve(InSpec, Glove_L, EMars_FPHands_Digit::Thumb), Alpha);
        Curl_L_Index  = Ease(Curl_L_Index,  Solve(InSpec, Glove_L, EMars_FPHands_Digit::Index), Alpha);
        Curl_L_Middle = Ease(Curl_L_Middle, Solve(InSpec, Glove_L, EMars_FPHands_Digit::Middle), Alpha);
        Curl_L_Pinky  = Ease(Curl_L_Pinky,  Solve(InSpec, Glove_L, EMars_FPHands_Digit::Pinky), Alpha);
        Curl_R_Thumb  = Ease(Curl_R_Thumb,  Solve(InSpec, Glove_R, EMars_FPHands_Digit::Thumb), Alpha);
        Curl_R_Index  = Ease(Curl_R_Index,  Solve(InSpec, Glove_R, EMars_FPHands_Digit::Index), Alpha);
        Curl_R_Middle = Ease(Curl_R_Middle, Solve(InSpec, Glove_R, EMars_FPHands_Digit::Middle), Alpha);
        Curl_R_Pinky  = Ease(Curl_R_Pinky,  Solve(InSpec, Glove_R, EMars_FPHands_Digit::Pinky), Alpha);

        ContactCurves.Add(n"Curl_L_Thumb", Curl_L_Thumb);
        ContactCurves.Add(n"Curl_L_Index", Curl_L_Index);
        ContactCurves.Add(n"Curl_L_Middle", Curl_L_Middle);
        ContactCurves.Add(n"Curl_L_Pinky", Curl_L_Pinky);
        ContactCurves.Add(n"Curl_R_Thumb", Curl_R_Thumb);
        ContactCurves.Add(n"Curl_R_Index", Curl_R_Index);
        ContactCurves.Add(n"Curl_R_Middle", Curl_R_Middle);
        ContactCurves.Add(n"Curl_R_Pinky", Curl_R_Pinky);
    }

    // 1 (the authored pose) for a glove with nothing to close on.
    private float32 Solve(const FMars_FPHands_ContactSpec& InSpec, const TOptional<FMars_FPHands_DigitQuery>& InGlove, EMars_FPHands_Digit InDigit)
    {
        if (InGlove.IsSet() == false)
        { return 1.0f; }

        auto Query = InGlove.GetValue();
        Query.Digit = InDigit;
        return utils_fphands::Solve_Digit(InSpec, _RefPose.GetValue().ContactRig.GetValue(), Query);
    }

    private float32 Ease(float32 InCurrent, float32 InTarget, float32 InAlpha)
    {
        return InCurrent + (InTarget - InCurrent) * InAlpha;
    }

    private FTransform WithReach(const FTransform& InGrip, const FMars_FPHands_HandTarget& InTarget)
    {
        if (InTarget.ReachAlpha <= 0.0f)
        { return InGrip; }

        auto Result = FTransform();
        Result.SetLocation(Math::Lerp(InGrip.GetLocation(), InTarget.ReachGrip.GetLocation(), float(InTarget.ReachAlpha)));
        Result.SetRotation(FQuat::Slerp(InGrip.GetRotation(), InTarget.ReachGrip.GetRotation(), float(InTarget.ReachAlpha)));
        return Result;
    }

    private FTransform WithSwing(const FTransform& InGrip, const FVector& InSwing)
    {
        auto Result = InGrip;
        Result.SetLocation(InGrip.GetLocation() + InSwing);
        return Result;
    }

    private FTransform InterpGrip(const FTransform& InCurrent, const FTransform& InTarget, float InAlpha)
    {
        auto Result = FTransform();
        Result.SetLocation(Math::Lerp(InCurrent.GetLocation(), InTarget.GetLocation(), InAlpha));
        Result.SetRotation(FQuat::Slerp(InCurrent.GetRotation(), InTarget.GetRotation(), InAlpha));
        return Result;
    }

    private FMars_FPHands_GloveRefPose Make_RefPose(USkeletalMeshComponent InMesh)
    {
        auto RefPose = FMars_FPHands_GloveRefPose();
        RefPose.LowerArmInGrip_L = RefPose_ComponentSpace(InMesh, n"lowerarm_l").GetRelativeTransform(RefPose_ComponentSpace(InMesh, n"grip_l"));
        RefPose.LowerArmInGrip_R = RefPose_ComponentSpace(InMesh, n"lowerarm_r").GetRelativeTransform(RefPose_ComponentSpace(InMesh, n"grip_r"));
        RefPose.ContactRig = utils_fphands::Make_ContactRig(InMesh);
        return RefPose;
    }

    private FTransform RefPose_ComponentSpace(USkeletalMeshComponent InMesh, FName InBone)
    {
        auto Result = FTransform();
        auto Bone = InBone;
        while (Bone.IsNone() == false)
        {
            const auto BoneIndex = InMesh.GetBoneIndex(Bone);
            if (ck::EnsureIfNot(BoneIndex != -1, f"[FPHands] the glove mesh has no bone [{Bone}]"))
            { break; }

            Result = Result * InMesh.GetRefPoseTransform(BoneIndex);
            Bone = InMesh.GetParentBone(Bone);
        }

        return Result;
    }
}
