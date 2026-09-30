// Parent class of ABP_FPHands. Turns the pawn's per-glove grip targets (world space) into what the anim graph needs:
// a finger pose index per glove and a component-space transform for each floating glove's lowerarm bone.
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

    private FMars_FPHands_ContactRig _ContactRig;

    // lowerarm expressed in its grip bone's space (reference pose); the glove is rigid from lowerarm to grip.
    private FTransform _LowerArmInGrip_L;
    private FTransform _LowerArmInGrip_R;
    private bool _HasRefPose = false;

    // Eased grips in the hand node's space.
    private FTransform _GripInHand_L;
    private FTransform _GripInHand_R;
    private bool _HasGrips = false;

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

        Character.Tick_FPHands(float32(DeltaTimeX));

        auto HandWorld = FTransform();
        auto Left = FMars_FPHands_HandTarget();
        auto Right = FMars_FPHands_HandTarget();
        if (Character.Get_FPHandTargets(HandWorld, Left, Right) == false)
        {
            PlacementAlpha = 0.0f;
            _HasGrips = false;
            return;
        }

        if (_HasRefPose == false)
        { CacheRefPose(Mesh); }

        // Only the grip change is eased; the hand node's sway and bob, and the arm swing, stay crisp.
        const auto InterpSpeed = Character.Config.FPHands.ReachInterpSpeed;
        if (_HasGrips == false || InterpSpeed <= 0.0f)
        {
            _GripInHand_L = Left.GripInHand;
            _GripInHand_R = Right.GripInHand;
            _HasGrips = true;
        }
        else
        {
            _GripInHand_L = InterpGrip(_GripInHand_L, Left.GripInHand, DeltaTimeX, InterpSpeed);
            _GripInHand_R = InterpGrip(_GripInHand_R, Right.GripInHand, DeltaTimeX, InterpSpeed);
        }

        const auto ComponentWorld = Mesh.GetWorldTransform();
        const auto Grip_L = (WithReach(WithSwing(_GripInHand_L, Left.Swing), Left) * HandWorld).GetRelativeTransform(ComponentWorld);
        const auto Grip_R = (WithReach(WithSwing(_GripInHand_R, Right.Swing), Right) * HandWorld).GetRelativeTransform(ComponentWorld);

        const auto LowerArm_L = _LowerArmInGrip_L * Grip_L;
        const auto LowerArm_R = _LowerArmInGrip_R * Grip_R;
        LowerArmLocation_L = LowerArm_L.GetLocation();
        LowerArmRotation_L = LowerArm_L.Rotator();
        LowerArmLocation_R = LowerArm_R.GetLocation();
        LowerArmRotation_R = LowerArm_R.Rotator();

        GripPoseIndex_L = int32(Left.Pose);
        GripPoseIndex_R = int32(Right.Pose);

        // An emote montage owns both gloves while it plays; the procedural placement fades out under it.
        const auto EmoteWeight = Blueprint_GetSlotMontageLocalWeight(Character.Config.FPHands.EmoteSlot);
        PlacementAlpha = float32(1.0 - Math::Clamp(EmoteWeight, 0.0, 1.0));

        Update_Contact(Character, Mesh, HandWorld, ComponentWorld, LowerArm_L, LowerArm_R, Left.Pose, Right.Pose, float32(DeltaTimeX),
                       EmoteWeight > 0.01);
    }

    private void Update_Contact(AMars_PlayerCharacter InCharacter, USkeletalMeshComponent InMesh, const FTransform& InHandNodeWorld,
                                const FTransform& InComponentWorld, const FTransform& InLowerArm_L, const FTransform& InLowerArm_R,
                                EMars_HandGripPose InPose_L, EMars_HandGripPose InPose_R, float32 InDeltaSeconds, bool InIsEmoting)
    {
        const auto& Spec = InCharacter.Config.FPHands.Contact;
        if (_ContactRig.IsValid == false)
        { _ContactRig = mars_fphands_contact::Make_Rig(InMesh); }

        auto Shape_L = FMars_FPHands_ContactShape();
        auto Shape_R = FMars_FPHands_ContactShape();
        if (Spec.IsEnabled && InIsEmoting == false)
        { InCharacter.Get_FPHandContactShapes(InHandNodeWorld, Shape_L, Shape_R); }

        const auto HandWorld_L = _ContactRig.HandInLowerArm_L * InLowerArm_L * InComponentWorld;
        const auto HandWorld_R = _ContactRig.HandInLowerArm_R * InLowerArm_R * InComponentWorld;
        const auto Alpha = float32(1.0 - Math::Exp(-Spec.CurlInterpSpeed * InDeltaSeconds));

        Curl_L_Thumb  = Ease(Curl_L_Thumb,  Solve(Spec, Shape_L, HandWorld_L, InPose_L, false, 0), Alpha);
        Curl_L_Index  = Ease(Curl_L_Index,  Solve(Spec, Shape_L, HandWorld_L, InPose_L, false, 1), Alpha);
        Curl_L_Middle = Ease(Curl_L_Middle, Solve(Spec, Shape_L, HandWorld_L, InPose_L, false, 2), Alpha);
        Curl_L_Pinky  = Ease(Curl_L_Pinky,  Solve(Spec, Shape_L, HandWorld_L, InPose_L, false, 3), Alpha);
        Curl_R_Thumb  = Ease(Curl_R_Thumb,  Solve(Spec, Shape_R, HandWorld_R, InPose_R, true, 0), Alpha);
        Curl_R_Index  = Ease(Curl_R_Index,  Solve(Spec, Shape_R, HandWorld_R, InPose_R, true, 1), Alpha);
        Curl_R_Middle = Ease(Curl_R_Middle, Solve(Spec, Shape_R, HandWorld_R, InPose_R, true, 2), Alpha);
        Curl_R_Pinky  = Ease(Curl_R_Pinky,  Solve(Spec, Shape_R, HandWorld_R, InPose_R, true, 3), Alpha);

        ContactCurves.Add(n"Curl_L_Thumb", Curl_L_Thumb);
        ContactCurves.Add(n"Curl_L_Index", Curl_L_Index);
        ContactCurves.Add(n"Curl_L_Middle", Curl_L_Middle);
        ContactCurves.Add(n"Curl_L_Pinky", Curl_L_Pinky);
        ContactCurves.Add(n"Curl_R_Thumb", Curl_R_Thumb);
        ContactCurves.Add(n"Curl_R_Index", Curl_R_Index);
        ContactCurves.Add(n"Curl_R_Middle", Curl_R_Middle);
        ContactCurves.Add(n"Curl_R_Pinky", Curl_R_Pinky);
    }

    private float32 Solve(const FMars_FPHands_ContactSpec& InSpec, const FMars_FPHands_ContactShape& InShape, const FTransform& InHandWorld,
                          EMars_HandGripPose InPose, bool InIsRightHand, int32 InDigit)
    {
        return mars_fphands_contact::Solve_Digit(InSpec, _ContactRig, InShape, InHandWorld, InPose, InIsRightHand, InDigit);
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

    private FTransform InterpGrip(const FTransform& InCurrent, const FTransform& InTarget, float InDeltaTime, float32 InSpeed)
    {
        const auto Alpha = Math::Clamp(1.0 - Math::Exp(-InSpeed * InDeltaTime), 0.0, 1.0);
        auto Result = FTransform();
        Result.SetLocation(Math::Lerp(InCurrent.GetLocation(), InTarget.GetLocation(), Alpha));
        Result.SetRotation(FQuat::Slerp(InCurrent.GetRotation(), InTarget.GetRotation(), Alpha));
        return Result;
    }

    private void CacheRefPose(USkeletalMeshComponent InMesh)
    {
        _LowerArmInGrip_L = RefPose_ComponentSpace(InMesh, n"lowerarm_l").GetRelativeTransform(RefPose_ComponentSpace(InMesh, n"grip_l"));
        _LowerArmInGrip_R = RefPose_ComponentSpace(InMesh, n"lowerarm_r").GetRelativeTransform(RefPose_ComponentSpace(InMesh, n"grip_r"));
        _HasRefPose = true;
    }

    private FTransform RefPose_ComponentSpace(USkeletalMeshComponent InMesh, FName InBone)
    {
        auto Result = FTransform();
        auto Bone = InBone;
        while (Bone.IsNone() == false)
        {
            const auto BoneIndex = InMesh.GetBoneIndex(Bone);
            if (BoneIndex == -1)
            { break; }

            Result = Result * InMesh.GetRefPoseTransform(BoneIndex);
            Bone = InMesh.GetParentBone(Bone);
        }
        return Result;
    }
}
