// Both gloves' eased grips in the hand node's space, raised by the hold's lateral (see BlueprintUpdateAnimation).
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

    // Unset until the first targets arrive, which the gloves then snap to.
    private TOptional<FMars_FPHands_GloveGrips> _Grips;

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

        // Only the grip change is eased; the hand node's sway and bob, and the arm swing, stay crisp. The hold's lateral
        // (a one-handed item moves the hand node to the right glove, through the side node) is kept out of the eased frame:
        // the targets are laid out with the node at Targets.Lateral, so each is raised by it and eased in the side node's
        // frame (the swing's rotation taken out), then lowered by the lateral the side node actually carries this frame.
        // A glove whose place does not change between two holds then never moves, whichever frame the node does.
        const auto SwingRotation = Get_SwingRotation(Hands, HandWorld);
        const auto Raise = SwingRotation.UnrotateVector(Targets.Lateral);
        const auto Lower = SwingRotation.UnrotateVector(Get_SideLateral(Hands, Targets.Lateral));
        const auto TargetLeft = Offset(Left.GripInHand, Raise);
        const auto TargetRight = Offset(Right.GripInHand, Raise);
        if (_Grips.IsSet() == false || Spec.ReachInterpSpeed.IsSet() == false)
        { _Grips = TOptional<FMars_FPHands_GloveGrips>(FMars_FPHands_GloveGrips(TargetLeft, TargetRight)); }
        else
        {
            const auto GripAlpha = Math::Clamp(1.0 - Math::Exp(-Spec.ReachInterpSpeed.GetValue() * DeltaTimeX), 0.0, 1.0);
            const auto Previous = _Grips.GetValue();
            _Grips = TOptional<FMars_FPHands_GloveGrips>(FMars_FPHands_GloveGrips(
                Blend(Previous.Left, TargetLeft, GripAlpha), Blend(Previous.Right, TargetRight, GripAlpha)));
        }

        const auto Eased = _Grips.GetValue();
        const auto Grips = FMars_FPHands_GloveGrips(Offset(Eased.Left, -Lower), Offset(Eased.Right, -Lower));

        // The gloves attach to the UCk_CameraComponent, which FollowView moves onto the rendered view at the end of the frame;
        // the hand node hangs off that same view (the director's view anchor). Composing against the anchor rather than
        // Mesh.GetWorldTransform() keeps both sides in one ECS snapshot whatever the actor/ECS tick order.
        const auto Viewpoint = Character.TryGet_ActorEntityHandle().As_PlayerViewpoint().Get_Viewpoint();
        const auto ComponentWorld = Mesh.GetRelativeTransform() * utils_transform::Get_EntityCurrentTransform(Viewpoint);

        // The reach is blended after the easing, so the gesture timing stays crisp.
        GripTarget_L = (Blend(Offset(Grips.Left, Left.Swing), Left.ReachGrip, Left.ReachAlpha) * HandWorld).GetRelativeTransform(ComponentWorld);
        GripTarget_R = (Blend(Offset(Grips.Right, Right.Swing), Right.ReachGrip, Right.ReachAlpha) * HandWorld).GetRelativeTransform(ComponentWorld);

        GripPoseIndex_L = int32(Left.Pose);
        GripPoseIndex_R = int32(Right.Pose);

        // An emote montage owns both gloves while it plays; the procedural placement fades out under it.
        const auto EmoteWeight = Blueprint_GetSlotMontageLocalWeight(Character.Config.FPHandsEmotes.Slot);
        PlacementAlpha_L = float32(1.0 - Math::Clamp(EmoteWeight, 0.0, 1.0));
        PlacementAlpha_R = PlacementAlpha_L;

        // An emote montage owns the fingers too: there is nothing to close on.
        auto Shapes = FMars_FPHands_ContactShapes();
        if (Spec.Contact.EnableDisable == ECk_EnableDisable::Enable && EmoteWeight <= 0.01)
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


    // The hand node's rotation relative to the side node (the melee swing; identity at rest). Identity without a side node.
    private FQuat Get_SwingRotation(const FCk_Handle_FPHands& InHands, const FTransform& InHandWorld)
    {
        const auto SideNode = InHands.Get_SideNode();
        if (ck::Is_NOT_Valid(SideNode))
        { return FQuat::Identity; }

        const auto SideWorld = utils_transform::Get_EntityCurrentTransform(SideNode.As_Transform());
        return InHandWorld.GetRelativeTransform(SideWorld).GetRotation();
    }

    // How far the side node actually moves the hand node this frame: its offset, which lands a frame after the owner writes
    // it. Without a side node, the targets' own lateral (nothing to take out).
    private FVector Get_SideLateral(const FCk_Handle_FPHands& InHands, const FVector& InFallback)
    {
        const auto SideNode = InHands.Get_SideNode();
        if (ck::Is_NOT_Valid(SideNode))
        { return InFallback; }

        return utils_scene_node::Get_Offset(SideNode).GetLocation();
    }

    // InGrip moved by InBy (hand node space), rotation kept.
    private FTransform Offset(const FTransform& InGrip, const FVector& InBy)
    {
        auto Result = InGrip;
        Result.SetLocation(InGrip.GetLocation() + InBy);
        return Result;
    }

    // InAlpha of the way from InFrom to InTo: location lerped, rotation slerped, unit scale.
    private FTransform Blend(const FTransform& InFrom, const FTransform& InTo, float InAlpha)
    {
        auto Result = FTransform();
        Result.SetLocation(Math::Lerp(InFrom.GetLocation(), InTo.GetLocation(), InAlpha));
        Result.SetRotation(FQuat::Slerp(InFrom.GetRotation(), InTo.GetRotation(), InAlpha));
        return Result;
    }
}
