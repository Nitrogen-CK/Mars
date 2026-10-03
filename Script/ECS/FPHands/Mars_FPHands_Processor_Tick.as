// Every frame: advances PhaseTime, follows moving reach/focus anchors, eases the focus lean (dropping a focus whose
// interactable has died) and rides a picked-up item in with the gloves. The phase itself is the Hands sub-SM's.
class UMars_Processor_FPHands_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

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

        utils_fphands::Update_ReachTarget(InState.Reach.Target);
        utils_fphands::Update_ReachTarget(InState.Focus.Target);

        Tick_FocusLean(Params.Spec.Reach.Focus, InState.Focus, DeltaSeconds);
        Tick_Carry(InHandle, Params, InState);
    }

    // The focus target outlives the focus while the gloves lean back out (an unfocus, or a focused pickup destroyed under
    // the view trace), and is cleared once both leans have eased to zero - so the gloves ease back to rest instead of
    // snapping, and never keep leaning toward a dead item's frozen spot. A reach takes the larger of lean and reach, so it
    // launches from and settles back into the lean.
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
    }

    // The item stays where it lay while the gloves reach and close on it, then travels back to its hold offset with them.
    // One offset request per frame; it applies in this frame's transform pass, so the carry reads the current phase time.
    private void Tick_Carry(FCk_Handle& InHandle, const FMars_Fragment_FPHands_Params& InParams, FMars_Fragment_FPHands& InState)
    {
        if (InState.Carry.IsSet() == false)
        { return; }

        // No HeldItem (tests) or no visual spawned yet: give up once the grab is over.
        auto Presentation = FCk_Handle_SceneNode();
        auto HeldItem = InHandle.As_HeldItem(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(HeldItem))
        {
            auto PresentationEntity = HeldItem.Get_PresentationEntity();
            Presentation = PresentationEntity.As_SceneNode(ECk_SanityCheck::UnChecked);
        }

        if (ck::Is_NOT_Valid(Presentation))
        {
            if (utils_fphands::Get_IsGrabbing(InState.PhaseState.Phase) == false)
            { InState.Carry.Reset(); }

            return;
        }

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
        else
        { InState.Carry.Reset(); }

        utils_scene_node::Request_UpdateOffset(Presentation, FCk_Request_SceneNode_UpdateRelativeTransform(Offset));
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
