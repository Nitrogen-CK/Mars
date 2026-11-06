// Every frame: advances PhaseTime, lets go of a held target that died, follows moving reach/focus anchors, eases the focus
// lean (dropping a focus whose interactable has died), sets the held item's offset from the hand (a picked-up item riding
// in, a held item carried out with a Place, a one-handed item riding its glove) and turns the pitch node for the view's
// pitch. The phase itself is the Hands sub-SM's, except the end of a Grip: the gloves move to Return here, on the clock the
// grip-taken item's arrival also runs on (see Tick_EndGrip).
class UMars_Processor_FPHands_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_FPHands_HandleRequests");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_FPHands);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_FPHands& InState)
    {
        // First-person presentation only: remote copies of the character never run their gloves. An entity with no
        // character at all (headless tests) runs.
        auto Character = Cast<ACharacter>(utils_owning_actor::TryGet_EntityOwningActor_Recursive(InHandle));
        if (Character != nullptr && Character.IsLocallyControlled() == false)
        { return; }

        const auto& Params = InHandle.Get_Fragment(FMars_Fragment_FPHands_Params);
        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());

        if (InState.PhaseState.Phase != EMars_FPHands_Phase::None)
        { InState.PhaseState.PhaseTime += DeltaSeconds; }

        Tick_EndGrip(InHandle, Params, InState);

        Tick_HoldTarget(InHandle, InState);
        utils_fphands::Update_ReachTarget(InState.Reach.Target);
        utils_fphands::Update_ReachTarget(InState.Focus.Target);
        utils_fphands::Update_ReachTarget(InState.Focus.OutgoingTarget);

        Tick_FocusLean(Params.Spec.Reach.Focus, InState.Focus, DeltaSeconds);
        Tick_HeldOffset(InHandle, Params, InState);
        Tick_Pitch(Params.Spec.Pitch, InState, DeltaSeconds);
    }

    // The held item's offset from the hand has one writer a frame, named by utils_fphands::Get_HeldOffsetOwner: the carry
    // of a pickup riding in, a Place setting it down, or a one-handed item riding its glove. An Arrival on the presentation
    // is the WorldItem processors' to write. The scene-node request handler assigns the whole offset, so a second request
    // in the frame would clobber the first: one at most, and none when the offset already holds.
    private void Tick_HeldOffset(FCk_Handle& InHandle, const FMars_Fragment_FPHands_Params& InParams, FMars_Fragment_FPHands& InState)
    {
        auto Node = FCk_Handle_SceneNode();
        auto HeldItem = InHandle.As_HeldItem(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(HeldItem))
        {
            auto Presentation = HeldItem.Get_PresentationEntity();
            Node = Presentation.As_SceneNode(ECk_SanityCheck::UnChecked);
        }

        // No HeldItem (tests) or no visual spawned yet: a carry gives up once the grab is over.
        if (ck::Is_NOT_Valid(Node))
        {
            if (InState.Carry.IsSet() && utils_fphands::Get_IsGrabbing(InState.PhaseState.Phase) == false)
            { InState.Carry.Reset(); }

            return;
        }

        const auto Owner = utils_fphands::Get_HeldOffsetOwner(InHandle, InState);
        auto Offset = FTransform::Identity;
        if (Owner == EMars_FPHands_HeldOffsetOwner::Carry)
        {
            Offset = Compute_CarryOffset(InParams, InState);
            if (utils_fphands::Get_PhaseCarryWeight(InState.PhaseState, InParams.Spec.Reach) <= 0.0f)
            { InState.Carry.Reset(); }
        }
        else if (Owner == EMars_FPHands_HeldOffsetOwner::Place)
        { Offset = Compute_PlaceOffset(InParams, InState, Node); }
        else if (Owner == EMars_FPHands_HeldOffsetOwner::Follow)
        { Offset = Compute_FollowOffset(InHandle, InParams, InState); }
        else
        { return; }

        if (Offset.Equals(utils_scene_node::Get_Offset(Node)))
        { return; }

        utils_scene_node::Request_UpdateOffset(Node, FCk_Request_SceneNode_UpdateRelativeTransform(Offset));
    }

    // A one-handed item rides its glove: while the right glove reaches or leans with the item in it (a Holding reach: a
    // torch carried to a candle, a key to a lock), the item's offset from the hand moves rigidly with the glove's grip,
    // from its rest grip to where the glove is this frame, and back to the hold offset as the glove returns.
    private FTransform Compute_FollowOffset(FCk_Handle& InHandle, const FMars_Fragment_FPHands_Params& InParams, const FMars_Fragment_FPHands& InState)
    {
        const auto HandWorld = utils_transform::Get_EntityCurrentTransform(InParams.Spec.HandNode);
        auto Targets = FMars_FPHands_HandTargets();
        InHandle.As_FPHands().Get_HandTargets(FMars_FPHands_TargetFrame(HandWorld, FVector::ZeroVector, FVector::ZeroVector), Targets);
        const auto& Right = Targets.Right;

        auto Offset = InState.Hold.HeldOffset;
        if (Right.ReachAlpha > 0.001f)
        {
            // The glove's grip this frame, hand node space, and the item moved by the same rigid motion from the rest grip.
            const auto Rest = Right.GripInHand;
            const auto Current = FTransform(FQuat::Slerp(Rest.GetRotation(), Right.ReachGrip.GetRotation(), Right.ReachAlpha),
                Math::Lerp(Rest.GetLocation(), Right.ReachGrip.GetLocation(), float64(Right.ReachAlpha)), FVector::OneVector);
            Offset = InState.Hold.HeldOffset * Rest.Inverse() * Current;
        }

        return Offset;
    }

    // The Grip ends on its own seconds, here rather than a sub-SM step later, and the time past them carries into the
    // Return: an item taken at the Grip waits out the same seconds on its own arrival clock (TryGet_RideHome), so under a
    // long frame the two still turn together. The Hands sub-SM follows into Return; its SetPhase then keeps this clock.
    private void Tick_EndGrip(FCk_Handle& InHandle, const FMars_Fragment_FPHands_Params& InParams, FMars_Fragment_FPHands& InState)
    {
        const auto GripSeconds = InParams.Spec.Reach.Grab.GripSeconds;
        if (InState.PhaseState.Phase != EMars_FPHands_Phase::Grip || InState.PhaseState.PhaseTime < GripSeconds)
        { return; }

        InState.PhaseState.Phase = EMars_FPHands_Phase::Return;
        InState.PhaseState.PhaseTime -= GripSeconds;

        if (InHandle.Has_Fragment(FMars_Fragment_FPHands_Signals))
        {
            InHandle.Get_Fragment(FMars_Fragment_FPHands_Signals).OnPhaseChanged.Broadcast(InHandle.As_FPHands(),
                EMars_FPHands_Phase::Grip, EMars_FPHands_Phase::Return);
        }
    }

    // A held interact target that died under the gloves (its device destroyed) is announced once (OnReachTargetLost, which
    // the Hold state lets go on) and forgotten, so it is not announced again while the state machine leaves Hold.
    private void Tick_HoldTarget(FCk_Handle& InHandle, FMars_Fragment_FPHands& InState)
    {
        if (InState.PhaseState.Phase != EMars_FPHands_Phase::Hold || InState.Reach.InteractTarget.IsSet() == false)
        { return; }

        if (ck::IsValid(InState.Reach.InteractTarget.GetValue()))
        { return; }

        InState.Reach.InteractTarget.Reset();
        if (InHandle.Has_Fragment(FMars_Fragment_FPHands_Signals))
        { InHandle.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachTargetLost.Broadcast(InHandle.As_FPHands()); }
    }

    // A Place carries the held item with the gloves: its offset from the hand goes from the hold to the point the reach sets
    // it down at by the reach alpha, rotation kept, and back as the gloves return without letting go.
    private FTransform Compute_PlaceOffset(const FMars_Fragment_FPHands_Params& InParams, const FMars_Fragment_FPHands& InState,
                                           const FCk_Handle_SceneNode& InNode)
    {
        const auto& Hold = InState.Hold;
        auto Offset = Hold.HeldOffset;
        const auto Alpha = utils_fphands::Get_PhaseAlpha(InState.PhaseState, InParams.Spec.Reach);
        if (Alpha > 0.0f)
        {
            const auto Target = InState.Reach.Target.GetValue();
            const auto HandWorld = utils_transform::Get_EntityCurrentTransform(utils_scene_node::Get_Parent(InNode));
            const auto ItemRotation = (Hold.HeldOffset * HandWorld).GetRotation();
            const auto PlaceWorld = Target.Get_LeadingGrip().AnchorWorld.TransformPosition(Target.PlaceAt.GetValue());
            const auto PlacedRoot = PlaceWorld - ItemRotation.RotateVector(Hold.Bounds.Centre);
            Offset.SetLocation(Math::Lerp(Hold.HeldOffset.GetLocation(), HandWorld.InverseTransformPosition(PlacedRoot), float(Alpha)));
        }

        return Offset;
    }

    // Turns the pitch node back by the part of the view's pitch the gloves do not follow. The view is the node's parent;
    // its pitch here is last frame's render, so it is eased before it is used.
    private void Tick_Pitch(const FMars_FPHands_PitchSpec& InSpec, FMars_Fragment_FPHands& InState, float32 InDeltaSeconds)
    {
        auto Node = InSpec.Node;
        if (ck::Is_NOT_Valid(Node))
        { return; }

        const auto ViewPitch = float32(utils_scene_node::Get_DriverWorldTransform(Node).Rotator().Pitch);
        if (InState.ViewPitchDeg.IsSet() == false || InSpec.InterpSpeed.IsSet() == false)
        { InState.ViewPitchDeg = TOptional<float32>(ViewPitch); }
        else
        {
            const auto Previous = InState.ViewPitchDeg.GetValue();
            const auto Alpha = float32(1.0 - Math::Exp(-InSpec.InterpSpeed.GetValue() * InDeltaSeconds));
            InState.ViewPitchDeg = TOptional<float32>(Previous + (ViewPitch - Previous) * Alpha);
        }

        const auto Offset = utils_fphands::Make_PitchOffset(InSpec, InState.ViewPitchDeg.GetValue());
        if (Offset.Equals(utils_scene_node::Get_Offset(Node)))
        { return; }

        utils_scene_node::Request_UpdateOffset(Node, FCk_Request_SceneNode_UpdateRelativeTransform(Offset));
    }

    // The focus target outlives the focus while the gloves lean back out (an unfocus, or a focused pickup destroyed under
    // the view trace), and is cleared once both leans have eased to zero - so the gloves ease back to rest instead of
    // snapping, and never keep leaning toward a dead item's frozen spot. The outgoing target (the one a refocus or a hold
    // change replaced) eases out at the same rate and is cleared the same way. A reach takes the larger of lean and reach,
    // so it launches from and settles back into the lean.
    private void Tick_FocusLean(const FMars_FPHands_FocusSpec& InSpec, FMars_FPHands_FocusState& InOutFocus, float32 InDeltaSeconds)
    {
        const auto HasFocus = InOutFocus.Target.IsSet() && ck::IsValid(InOutFocus.FocusedFor);
        const auto LeanAlpha = float32(1.0 - Math::Exp(-InSpec.InterpSpeed * InDeltaSeconds));
        const auto LeanR = HasFocus && utils_fphands::Get_UsesHand(InOutFocus.Target, EMars_Hand::Right) ? InSpec.Lean : 0.0f;
        const auto LeanL = HasFocus && utils_fphands::Get_UsesHand(InOutFocus.Target, EMars_Hand::Left) ? InSpec.Lean : 0.0f;
        InOutFocus.Alpha_R += (LeanR - InOutFocus.Alpha_R) * LeanAlpha;
        InOutFocus.Alpha_L += (LeanL - InOutFocus.Alpha_L) * LeanAlpha;

        if (HasFocus == false && InOutFocus.Target.IsSet() && InOutFocus.Alpha_R < 0.001f && InOutFocus.Alpha_L < 0.001f)
        {
            InOutFocus.Target.Reset();
            InOutFocus.Alpha_R = 0.0f;
            InOutFocus.Alpha_L = 0.0f;
        }

        if (InOutFocus.OutgoingTarget.IsSet() == false)
        { return; }

        InOutFocus.OutgoingAlpha_R -= InOutFocus.OutgoingAlpha_R * LeanAlpha;
        InOutFocus.OutgoingAlpha_L -= InOutFocus.OutgoingAlpha_L * LeanAlpha;
        if (InOutFocus.OutgoingAlpha_R < 0.001f && InOutFocus.OutgoingAlpha_L < 0.001f)
        {
            InOutFocus.OutgoingTarget.Reset();
            InOutFocus.OutgoingAlpha_R = 0.0f;
            InOutFocus.OutgoingAlpha_L = 0.0f;
        }
    }

    // The item stays where it lay while the gloves reach and close on it, then travels back to its hold offset with them;
    // the hold offset once the carry weight is spent. It applies in this frame's transform pass, so the carry reads the
    // current phase time.
    private FTransform Compute_CarryOffset(const FMars_Fragment_FPHands_Params& InParams, const FMars_Fragment_FPHands& InState)
    {
        const auto Carry = InState.Carry.GetValue();
        const auto& ReachSpec = InParams.Spec.Reach;
        const auto Weight = utils_fphands::Get_PhaseCarryWeight(InState.PhaseState, ReachSpec);
        auto Offset = Carry.HeldOffset;
        if (Weight > 0.0f)
        {
            // Out of reach, the gloves stop short: the item comes to meet them while they reach out.
            const auto HandWorld = utils_transform::Get_EntityCurrentTransform(InParams.Spec.HandNode);
            const auto PhaseTime = InState.PhaseState.PhaseTime;
            const auto ReachOut = InState.PhaseState.Phase == EMars_FPHands_Phase::Reach
                ? utils_fphands::Ease(ReachSpec.Grab.OutEasing, PhaseTime / Math::Max(ReachSpec.Grab.OutSeconds, 0.01f))
                : 1.0f;
            const auto Shortfall = Get_GloveShortfall(InParams, InState, HandWorld);
            const auto PickedWorld = FTransform(Carry.StartWorld.GetRotation(),
                Carry.StartWorld.GetLocation() + Shortfall * ReachOut, FVector::OneVector);
            const auto Picked = PickedWorld.GetRelativeTransform(HandWorld);
            Offset.SetLocation(Math::Lerp(Carry.HeldOffset.GetLocation(), Picked.GetLocation(), float(Weight)));
            Offset.SetRotation(FQuat::Slerp(Carry.HeldOffset.GetRotation(), Picked.GetRotation(), float(Weight)));
        }

        return Offset;
    }

    // How far the fully reached gloves fall short of their grips on the reach target (world, averaged over the gloves
    // in use).
    private FVector Get_GloveShortfall(const FMars_Fragment_FPHands_Params& InParams, const FMars_Fragment_FPHands& InState,
                                       const FTransform& InHandWorld)
    {
        if (InState.Reach.Target.IsSet() == false)
        { return FVector::ZeroVector; }

        const auto Target = InState.Reach.Target.GetValue();

        // The gloves' rest grips for this hold (no reach applied).
        const auto Rest = utils_fphands::Get_RestTargets(InParams.Spec.Rest, InState.Hold,
            FMars_FPHands_TargetFrame(InHandWorld, FVector::ZeroVector, FVector::ZeroVector));

        auto Sum = FVector::ZeroVector;
        auto Count = 0;
        for (int32 Side = 0; Side < 2; ++Side)
        {
            const auto Hand = Side == 0 ? EMars_Hand::Right : EMars_Hand::Left;
            if (Target.Get_HandGrip(Hand).IsSet() == false)
            { continue; }

            auto Grip = FMars_FPHands_GripQuery(InHandWorld, Hand, Hand == EMars_Hand::Right ? Rest.Right.GripInHand : Rest.Left.GripInHand);
            utils_fphands::Resolve_WorldGrip(InParams.Spec, Target, Grip);
            const auto Reached = utils_fphands::Make_ReachedGrip(InParams.Spec.Reach, Grip) * InHandWorld;
            Sum += Reached.GetLocation() - Grip.WorldGrip.GetLocation();
            ++Count;
        }

        return Count > 0 ? Sum / Count : FVector::ZeroVector;
    }
}
