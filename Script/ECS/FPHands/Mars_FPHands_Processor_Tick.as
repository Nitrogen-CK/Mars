// Every frame: advances PhaseTime, follows moving reach/focus anchors, eases the focus lean and rides a picked-up item
// in with the gloves. The phase itself is not moved here (the Hands sub-SM owns it).
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
        const auto& ReachSpec = Params.Spec.Reach;
        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());

        if (InState.Phase != EMars_FPHands_Phase::None)
        { InState.PhaseTime += DeltaSeconds; }

        utils_fphands::Update_ReachTarget(InState.Target);
        utils_fphands::Update_ReachTarget(InState.FocusTarget);

        // A reach takes the larger of lean and reach, so it launches from and settles back into the lean.
        const auto HasFocus = InState.FocusTarget.IsValid;
        const auto LeanAlpha = float32(1.0 - Math::Exp(-ReachSpec.FocusInterpSpeed * DeltaSeconds));
        const auto LeanR = HasFocus && InState.FocusTarget.UsesRight ? ReachSpec.FocusLean : 0.0f;
        const auto LeanL = HasFocus && InState.FocusTarget.UsesLeft ? ReachSpec.FocusLean : 0.0f;
        InState.FocusAlpha_R += (LeanR - InState.FocusAlpha_R) * LeanAlpha;
        InState.FocusAlpha_L += (LeanL - InState.FocusAlpha_L) * LeanAlpha;

        Tick_Carry(InHandle, Params, InState);
    }

    // The item stays where it lay while the gloves reach and close on it, then travels back to its hold offset with them.
    // One offset request per frame; it applies in this frame's transform pass, so the carry reads the current phase time.
    private void Tick_Carry(FCk_Handle& InHandle, const FMars_Fragment_FPHands_Params& InParams, FMars_Fragment_FPHands& InState)
    {
        if (InState.Carry.IsActive == false)
        { return; }

        auto Presentation = FCk_Handle();
        auto HeldItem = InHandle.As_HeldItem(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(HeldItem))
        { Presentation = HeldItem.Get_PresentationEntity(); }

        if (ck::Is_NOT_Valid(Presentation) || utils_scene_node::Has(Presentation) == false)
        {
            // Not spawned yet; give up once the grab is over.
            InState.Carry.IsActive = InState.Phase == EMars_FPHands_Phase::Reach || InState.Phase == EMars_FPHands_Phase::Grip
                || InState.Phase == EMars_FPHands_Phase::Return;
            return;
        }

        const auto& ReachSpec = InParams.Spec.Reach;
        const auto PhaseState = FMars_FPHands_PhaseState(InState.Phase, InState.PhaseTime, InState.ReleaseFromAlpha);
        const auto Weight = utils_fphands::Get_PhaseCarryWeight(PhaseState, ReachSpec);
        auto Offset = InState.Carry.HeldOffset;
        if (Weight > 0.0f)
        {
            // Out of reach, the gloves stop short: the item comes to meet them while they reach out.
            const auto HandWorld = utils_transform::Get_EntityCurrentTransform(InParams.HandNode);
            const auto ReachOut = InState.Phase == EMars_FPHands_Phase::Reach
                ? utils_fphands::Ease(ReachSpec.GrabOutEasing, InState.PhaseTime / Math::Max(ReachSpec.GrabOutSeconds, 0.01f))
                : 1.0f;
            const auto Shortfall = Get_GloveShortfall(InParams, InState, HandWorld);
            const auto PickedWorld = FTransform(InState.Carry.StartWorld.GetRotation(),
                InState.Carry.StartWorld.GetLocation() + Shortfall * ReachOut, FVector::OneVector);
            const auto Picked = PickedWorld.GetRelativeTransform(HandWorld);
            Offset.SetLocation(Math::Lerp(InState.Carry.HeldOffset.GetLocation(), Picked.GetLocation(), float(Weight)));
            Offset.SetRotation(FQuat::Slerp(InState.Carry.HeldOffset.GetRotation(), Picked.GetRotation(), float(Weight)));
        }
        else
        { InState.Carry.IsActive = false; }

        auto Node = utils_scene_node::DoCastChecked(Presentation);
        utils_scene_node::Request_UpdateOffset(Node, FCk_Request_SceneNode_UpdateRelativeTransform(Offset));
    }

    // How far the fully reached gloves fall short of their grips on the reach target (world, averaged over the gloves
    // in use).
    private FVector Get_GloveShortfall(const FMars_Fragment_FPHands_Params& InParams, const FMars_Fragment_FPHands& InState,
                                       const FTransform& InHandWorld)
    {
        // The gloves' rest grips for this hold (no reach applied).
        const auto Rest = utils_fphands::Get_RestTargets(InParams.Spec, InState.Hold,
            FMars_FPHands_TargetFrame(InHandWorld, FVector::ZeroVector, FVector::ZeroVector));

        auto Sum = FVector::ZeroVector;
        auto Count = 0;
        for (int32 Side = 0; Side < 2; ++Side)
        {
            const auto IsRight = Side == 1;
            if (utils_fphands::Get_UsesHand(InState.Target, IsRight) == false)
            { continue; }

            auto Grip = FMars_FPHands_GripQuery(InHandWorld, IsRight, IsRight ? Rest.Right.GripInHand : Rest.Left.GripInHand);
            utils_fphands::Resolve_WorldGrip(InParams.Spec, InState.Target, Grip);
            const auto Reached = utils_fphands::Make_ReachedGrip(InParams.Spec.Reach, Grip) * InHandWorld;
            Sum += Reached.GetLocation() - Grip.WorldGrip.GetLocation();
            ++Count;
        }
        return Count > 0 ? Sum / Count : FVector::ZeroVector;
    }
}
