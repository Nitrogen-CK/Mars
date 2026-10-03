// Parent class of ABP_FPHands. Composes per-glove grip targets from the pawn's FPHands feature (read only) and turns
// them into what the anim graph needs: a finger pose index per glove, a component-space target for each glove's grip
// bone (CkHands Glove Placement nodes) and the component-space shape each glove's fingers close on (the Shape_L /
// Shape_R pins of CR_FPHands_Contact, CkHands Contact Curl nodes).
class UMars_FPHands_AnimInstance : UAnimInstance
{
    // Blend Poses by Int child index per glove (EMars_HandGripPose).
    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "FPHands")
    int32 GripPoseIndex_L = 0;

    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "FPHands")
    int32 GripPoseIndex_R = 0;

    // Where each glove's grip bone goes, component space (Glove Placement Target on grip_l / grip_r).
    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "FPHands")
    FTransform GripTarget_L;

    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "FPHands")
    FTransform GripTarget_R;

    // Glove Placement alpha per glove. 0 until the owner provides targets (editor preview, pawn still constructing) -
    // the gloves keep their anim pose.
    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "FPHands")
    float32 PlacementAlpha_L = 0.0f;

    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "FPHands")
    float32 PlacementAlpha_R = 0.0f;

    // What each glove's fingers close on, component space. Type None = the authored grip pose.
    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "FPHands|Contact")
    FCk_Hands_ContactShape ContactShape_L;

    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "FPHands|Contact")
    FCk_Hands_ContactShape ContactShape_R;

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
            Clear_Placement();
            return;
        }

        auto Hands = FCk_Handle_FPHands();
        if (Character.Get_IsActorEcsReady())
        { Hands = Character.TryGet_ActorEntityHandle().As_FPHands(ECk_SanityCheck::UnChecked); }

        if (ck::Is_NOT_Valid(Hands))
        {
            Clear_Placement();
            _HasGrips = false;
            return;
        }

        // Composed here, with the hand node's current transform, rather than stored by the feature: an ECS-time
        // composition reads the hand node one settle behind and jitters under movement.
        const auto HandNode = Hands.Get_HandNode();
        const auto HandWorld = utils_transform::Get_EntityCurrentTransform(HandNode);
        auto Targets = FMars_FPHands_HandTargets();
        Hands.Get_HandTargets(FMars_FPHands_TargetFrame(HandWorld, Hands.Get_ArmSwing_Left(), Hands.Get_ArmSwing_Right()), Targets);
        const auto& Left = Targets.Left;
        const auto& Right = Targets.Right;

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
            const auto GripAlpha = Math::Clamp(1.0 - Math::Exp(-InterpSpeed * DeltaTimeX), 0.0, 1.0);
            _GripInHand_L = InterpGrip(_GripInHand_L, Left.GripInHand, GripAlpha);
            _GripInHand_R = InterpGrip(_GripInHand_R, Right.GripInHand, GripAlpha);
        }

        // The gloves attach to the UCk_CameraComponent, which FollowView moves onto the rendered view at the end of the frame;
        // the hand node hangs off that same view (the director's view anchor). Composing against the anchor rather than
        // Mesh.GetWorldTransform() keeps both sides in one ECS snapshot whatever the actor/ECS tick order.
        const auto Viewpoint = Character.TryGet_ActorEntityHandle().As_PlayerViewpoint().Get_Viewpoint();
        const auto ComponentWorld = Mesh.GetRelativeTransform() * utils_transform::Get_EntityCurrentTransform(Viewpoint);

        GripTarget_L = (WithReach(WithSwing(_GripInHand_L, Left.Swing), Left) * HandWorld).GetRelativeTransform(ComponentWorld);
        GripTarget_R = (WithReach(WithSwing(_GripInHand_R, Right.Swing), Right) * HandWorld).GetRelativeTransform(ComponentWorld);

        GripPoseIndex_L = int32(Left.Pose);
        GripPoseIndex_R = int32(Right.Pose);

        // An emote montage owns both gloves while it plays; the procedural placement fades out under it.
        const auto EmoteWeight = Blueprint_GetSlotMontageLocalWeight(Character.Config.FPHands.EmoteSlot);
        PlacementAlpha_L = float32(1.0 - Math::Clamp(EmoteWeight, 0.0, 1.0));
        PlacementAlpha_R = PlacementAlpha_L;

        // An emote montage owns the fingers too: there is nothing to close on.
        auto Shapes = FMars_FPHands_ContactShapes();
        if (Character.Config.FPHands.Contact.IsEnabled && EmoteWeight <= 0.01)
        { Hands.Get_ContactShapes(HandWorld, Shapes); }

        ContactShape_L = Shapes.Left.Get_InSpace(ComponentWorld);
        ContactShape_R = Shapes.Right.Get_InSpace(ComponentWorld);
    }

    private void Clear_Placement()
    {
        PlacementAlpha_L = 0.0f;
        PlacementAlpha_R = 0.0f;
        ContactShape_L = FCk_Hands_ContactShape();
        ContactShape_R = FCk_Hands_ContactShape();
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
}
