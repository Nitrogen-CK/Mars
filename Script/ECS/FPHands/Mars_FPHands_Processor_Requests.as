// Drains SetHold, SetFocus, SetPoseOverride, SetPhase, Release, StartPush, then StartReach. The phase itself only moves through SetPhase
// (the Hands sub-SM's state enter tasks); StartPush, StartReach and Release only broadcast, and the sub-SM's conditions
// turn those broadcasts into transitions.
//
// SetPhase drains first so the others gate on the phase the sub-SM is in now: a Release queued beside Hold's
// SetPhase(Hold) lets go, and a StartPush / StartReach beside Rest's SetPhase(None) is honoured. Release is honoured
// only while holding; StartPush only at rest; StartReach at rest and while letting go (Release, Return), the phases
// whose states listen for it - a reach requested mid-grab, mid-hold or mid-push leaves the current target alone, so a
// later release still eases back from the target it was holding. A push accepted in this drain wins over a reach in
// the same drain (both would leave Rest; the reach would overwrite the target the push does not use). Every StartReach not
// taken (superseded by a later one in the drain, beaten by a push, busy gloves, a dead subject, nothing to reach) is
// refused: Reach.RefusedTarget remembers its interact target and OnReachRefused names it, so an interaction waiting on the
// gloves acts without them at once. A reach that
// interrupts a release or return starts from the alpha the gloves were at (ReachFromAlpha, recorded by SetPhase). A
// Return with a picked-up item still riding in is not interrupted - the carry would snap back to where the item lay; a
// timed target that arrives then is caught by Rest's re-sync once the return ends.
class UMars_Processor_FPHands_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_FPHands_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_FPHands);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_FPHands_Requests& InRequests,
                       FMars_Fragment_FPHands& InState)
    {
        auto Self = InHandle.As_FPHands();
        const auto& Params = InHandle.Get_Fragment(FMars_Fragment_FPHands_Params);

        TArray<FMars_Request_FPHands_SetHold> SetHoldRequests = InRequests.SetHoldRequests;
        TArray<FMars_Request_FPHands_SetFocus> SetFocusRequests = InRequests.SetFocusRequests;
        TArray<FMars_Request_FPHands_SetPoseOverride> SetPoseOverrideRequests = InRequests.SetPoseOverrideRequests;
        TArray<FMars_Request_FPHands_StartReach> StartReachRequests = InRequests.StartReachRequests;
        TArray<FMars_Request_FPHands_Release> ReleaseRequests = InRequests.ReleaseRequests;
        TArray<FMars_Request_FPHands_SetPhase> SetPhaseRequests = InRequests.SetPhaseRequests;
        TArray<FMars_Request_FPHands_StartPush> StartPushRequests = InRequests.StartPushRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_FPHands_Requests);

        for (const auto& Request : SetHoldRequests)
        { HandleSetHold(InState, Request); }

        for (const auto& Request : SetFocusRequests)
        { HandleSetFocus(Params, InState, Request); }

        for (const auto& Request : SetPoseOverrideRequests)
        { HandleSetPoseOverride(InState, Request); }

        if (SetPhaseRequests.Num() > 0)
        { HandleSetPhase(InHandle, InState, SetPhaseRequests.Last().Phase); }

        if (ReleaseRequests.Num() > 0)
        { HandleRelease(InHandle, InState); }

        auto PushAccepted = false;
        if (StartPushRequests.Num() > 0)
        { PushAccepted = HandleStartPush(InHandle, InState, StartPushRequests.Last()); }

        if (StartReachRequests.Num() > 0)
        {
            // A superseded request for the same target as the last one is a duplicate, not a refusal: the last one answers it.
            const auto LastTarget = utils_fphands::Get_RequestedInteractTarget(StartReachRequests.Last());
            for (int32 Index = 0; Index < StartReachRequests.Num() - 1; ++Index)
            {
                const auto Target = utils_fphands::Get_RequestedInteractTarget(StartReachRequests[Index]);
                if (ck::IsValid(Target) && Target == LastTarget)
                { continue; }

                Log("[FPHands] StartReach ignored: a later reach in the same drain wins");
                Refuse_Reach(InHandle, InState, StartReachRequests[Index]);
            }

            if (PushAccepted)
            {
                Log("[FPHands] StartReach ignored: a push started in the same drain");
                Refuse_Reach(InHandle, InState, StartReachRequests.Last());
            }
            else
            { HandleStartReach(InHandle, InState, StartReachRequests.Last()); }
        }
    }

    // A pickup that lands while the gloves are still on it rides in with them (see the Tick processor's carry). Not a
    // Persistent item: its own world item lerps itself onto the hand (the mount Arrival), and a carry would fight that
    // for the same scene node offset.
    private void HandleSetHold(FMars_Fragment_FPHands& InState, const FMars_Request_FPHands_SetHold& InRequest)
    {
        const auto& Item = InRequest.Item;
        InState.Hold = utils_fphands::Make_Hold(Item);
        InState.Carry.Reset();
        InState.Reach.RefusedTarget.Reset();

        if (utils_fphands::Get_IsGrabbing(InState.PhaseState.Phase) == false || InState.Reach.Target.IsSet() == false)
        { return; }

        const auto Target = InState.Reach.Target.GetValue();
        const auto IsSpawnedVisual = ck::IsValid(Item) && Item.Has_Presentation() && Item.Has_PersistentWorldItem() == false;
        if (ck::Is_NOT_Valid(Target.Shape.Mesh.Get()) || IsSpawnedVisual == false)
        { return; }

        auto Carry = FMars_FPHands_Carry();
        Carry.StartWorld = Target.Get_LeadingGrip().AnchorWorld;
        Carry.HeldOffset = Item.Get_Presentation().Mounting.HeldOffset;
        InState.Carry = TOptional<FMars_FPHands_Carry>(Carry);
    }

    private void HandleSetFocus(const FMars_Fragment_FPHands_Params& InParams, FMars_Fragment_FPHands& InState,
                                const FMars_Request_FPHands_SetFocus& InRequest)
    {
        // Unfocus keeps the focus target: the gloves lean back out from it, and the Tick clears it once the lean is gone.
        if (ck::Is_NOT_Valid(InRequest.Interactable))
        {
            InState.Focus.FocusedFor = FCk_Handle_Interactable();
            return;
        }

        if (InRequest.Interactable == InState.Focus.FocusedFor)
        { return; }

        InState.Focus.FocusedFor = InRequest.Interactable;
        InState.Focus.Target = Resolve_Target(InParams, InState,
            FMars_FPHands_ReachQuery(FMars_FPHands_ReachSubject(InRequest.Interactable, InRequest.Owner), Make_HandState(InParams, InState)));
    }

    // Last wins per glove.
    private void HandleSetPoseOverride(FMars_Fragment_FPHands& InState, const FMars_Request_FPHands_SetPoseOverride& InRequest)
    {
        if (InRequest.Hand == EMars_Hand::Right)
        {
            InState.PoseOverride_R = InRequest.Pose;
            return;
        }

        InState.PoseOverride_L = InRequest.Pose;
    }

    private void HandleStartReach(FCk_Handle& InHandle, FMars_Fragment_FPHands& InState, const FMars_Request_FPHands_StartReach& InRequest)
    {
        const auto Phase = InState.PhaseState.Phase;
        const auto CanReach = Phase == EMars_FPHands_Phase::None || Phase == EMars_FPHands_Phase::Release
            || Phase == EMars_FPHands_Phase::Return;
        if (CanReach == false)
        {
            Log(f"[FPHands] StartReach ignored: the gloves are busy (phase {Phase :n})");
            Refuse_Reach(InHandle, InState, InRequest);
            return;
        }

        if (Phase == EMars_FPHands_Phase::Return && InState.Carry.IsSet())
        {
            Log("[FPHands] StartReach ignored: a picked-up item is still riding in (phase Return)");
            Refuse_Reach(InHandle, InState, InRequest);
            return;
        }

        const auto& Params = InHandle.Get_Fragment(FMars_Fragment_FPHands_Params);
        const auto Kind = utils_fphands::Get_RequestedKind(InRequest);
        if (ck::EnsureIfNot(InRequest.PlaceAtWorld.IsSet() == false || Kind == EMars_FPHands_ReachKind::Place,
            f"[FPHands] a [{Kind :n}] reach names a place spot: only a Place reach sets something down"))
        {
            Refuse_Reach(InHandle, InState, InRequest);
            return;
        }

        auto Target = TOptional<FMars_FPHands_ReachTarget>();
        auto InteractTarget = TOptional<FCk_Handle_InteractTarget>();
        if (InRequest.Subject.IsSet())
        {
            const auto Subject = InRequest.Subject.GetValue();

            // Destroyed between the request and this drain (a picked-up item, a removed device).
            const auto InteractTargetDied = Subject.InteractTarget.IsSet() && ck::Is_NOT_Valid(Subject.InteractTarget.GetValue());
            if (InteractTargetDied || ck::Is_NOT_Valid(Subject.Owner))
            {
                ck::Trace("[FPHands] StartReach ignored: the subject is gone");
                Refuse_Reach(InHandle, InState, InRequest);
                return;
            }

            InteractTarget = Subject.InteractTarget;
            auto Query = FMars_FPHands_ReachQuery(Subject, Make_HandState(Params, InState));
            Query.Kind = Kind;
            Query.PlaceAtWorld = InRequest.PlaceAtWorld;
            Target = Resolve_Target(Params, InState, Query);
        }
        else
        {
            if (ck::EnsureIfNot(Kind != EMars_FPHands_ReachKind::Place, "[FPHands] a Place reach needs a subject to set down on"))
            {
                Refuse_Reach(InHandle, InState, InRequest);
                return;
            }

            Target = TOptional<FMars_FPHands_ReachTarget>(Make_BareReach(Params));
        }

        if (Target.IsSet() == false)
        {
            ck::Trace("[FPHands] StartReach ignored: the gloves cannot reach the target");
            Refuse_Reach(InHandle, InState, InRequest);
            return;
        }

        InState.Reach.RefusedTarget.Reset();
        InState.Reach.Target = Target;
        InState.Reach.InteractTarget = InteractTarget;
        InState.Reach.CompletionPolicy = InRequest.CompletionPolicy;

        // A pickup: if it lands in the hands, its held visual starts where the item lay. No HeldItem (tests): no visual.
        const auto Resolved = Target.GetValue();
        if (ck::IsValid(Resolved.Shape.Mesh.Get()))
        {
            auto HeldItem = InHandle.As_HeldItem(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(HeldItem))
            { HeldItem.Request_SetNextSpawnFrom(FMars_Request_HeldItem_SetNextSpawnFrom(Resolved.Get_LeadingGrip().AnchorWorld)); }
        }

        if (InHandle.Has_Fragment(FMars_Fragment_FPHands_Signals))
        { InHandle.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachRequested.Broadcast(InHandle.As_FPHands(), Kind); }
    }

    // Remembers the refused request's interact target and says so (a reach for no interaction clears the memory).
    private void Refuse_Reach(FCk_Handle& InHandle, FMars_Fragment_FPHands& InState, const FMars_Request_FPHands_StartReach& InRequest)
    {
        const auto Target = utils_fphands::Get_RequestedInteractTarget(InRequest);
        InState.Reach.RefusedTarget = ck::IsValid(Target) ? TOptional<FCk_Handle_InteractTarget>(Target) : TOptional<FCk_Handle_InteractTarget>();

        if (InHandle.Has_Fragment(FMars_Fragment_FPHands_Signals))
        { InHandle.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachRefused.Broadcast(InHandle.As_FPHands(), Target, utils_fphands::Get_RequestedKind(InRequest)); }
    }

    // The right glove toward the hand node itself.
    private FMars_FPHands_ReachTarget Make_BareReach(const FMars_Fragment_FPHands_Params& InParams)
    {
        auto Grip = FMars_FPHands_HandGrip();
        Grip.AnchorWorld = utils_transform::Get_EntityCurrentTransform(InParams.Spec.HandNode);

        auto Target = FMars_FPHands_ReachTarget();
        Target.Layout = EMars_FPHands_GripLayout::Point;
        Target.Right = TOptional<FMars_FPHands_HandGrip>(Grip);
        return Target;
    }

    // True when the push was accepted.
    private bool HandleStartPush(FCk_Handle& InHandle, FMars_Fragment_FPHands& InState, const FMars_Request_FPHands_StartPush& InRequest)
    {
        if (InState.PhaseState.Phase != EMars_FPHands_Phase::None)
        {
            Log(f"[FPHands] StartPush ignored: the gloves are busy (phase {InState.PhaseState.Phase :n})");
            return false;
        }

        InState.Push.Hold = InRequest.Hold;
        InState.Push.Kind = InRequest.Kind;

        if (InHandle.Has_Fragment(FMars_Fragment_FPHands_Signals))
        { InHandle.Get_Fragment(FMars_Fragment_FPHands_Signals).OnPushRequested.Broadcast(InHandle.As_FPHands()); }

        return true;
    }

    // Only a hold lets go early; a grab always finishes on its own (a picked-up item removes its own target mid-grab).
    private void HandleRelease(FCk_Handle& InHandle, const FMars_Fragment_FPHands& InState)
    {
        if (InState.PhaseState.Phase != EMars_FPHands_Phase::Hold)
        {
            Log(f"[FPHands] Release ignored: the gloves are not holding (phase {InState.PhaseState.Phase :n})");
            return;
        }

        Broadcast_ReachTargetLost(InHandle);
    }

    // Release records the alpha it eases back from; Reach and Hold record the alpha they ease out from (0 from rest, the
    // current release or return alpha when they interrupt one).
    private void HandleSetPhase(FCk_Handle& InHandle, FMars_Fragment_FPHands& InState, EMars_FPHands_Phase InNewPhase)
    {
        const auto Previous = InState.PhaseState.Phase;
        const auto& Params = InHandle.Get_Fragment(FMars_Fragment_FPHands_Params);
        const auto FromAlpha = utils_fphands::Get_PhaseAlpha(InState.PhaseState, Params.Spec.Reach);

        if (InNewPhase == EMars_FPHands_Phase::Release)
        { InState.PhaseState.ReleaseFromAlpha = FromAlpha; }

        if (InNewPhase == EMars_FPHands_Phase::Reach || InNewPhase == EMars_FPHands_Phase::Hold)
        { InState.PhaseState.ReachFromAlpha = FromAlpha; }

        if (InNewPhase == EMars_FPHands_Phase::None)
        {
            InState.Carry.Reset();
            InState.PoseOverride_R.Reset();
            InState.PoseOverride_L.Reset();

            // The grab ended without the item landing in the hands: don't let a later equip spawn at the pickup spot.
            auto HeldItem = InHandle.As_HeldItem(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(HeldItem))
            { HeldItem.Request_ClearNextSpawnFrom(FMars_Request_HeldItem_ClearNextSpawnFrom()); }
        }

        InState.PhaseState.Phase = InNewPhase;
        InState.PhaseState.PhaseTime = 0.0f;

        if (Previous == InNewPhase)
        { return; }

        if (InHandle.Has_Fragment(FMars_Fragment_FPHands_Signals))
        { InHandle.Get_Fragment(FMars_Fragment_FPHands_Signals).OnPhaseChanged.Broadcast(InHandle.As_FPHands(), Previous, InNewPhase); }

        // The interact target died before the Hold state bound its release (between the reach's drain and this one):
        // nothing would ever remove it now, so the gloves let go.
        if (InNewPhase == EMars_FPHands_Phase::Hold && Get_IsInteractTargetGone(InState.Reach))
        {
            Log("[FPHands] Hold entered for an interact target that is gone; letting go");
            Broadcast_ReachTargetLost(InHandle);
        }
    }

    private bool Get_IsInteractTargetGone(const FMars_FPHands_ReachState& InReach) const
    {
        return InReach.InteractTarget.IsSet() && ck::Is_NOT_Valid(InReach.InteractTarget.GetValue());
    }

    private void Broadcast_ReachTargetLost(FCk_Handle& InHandle)
    {
        if (InHandle.Has_Fragment(FMars_Fragment_FPHands_Signals))
        { InHandle.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachTargetLost.Broadcast(InHandle.As_FPHands()); }
    }

    // Where the gloves are now and what they hold.
    private FMars_FPHands_HandState Make_HandState(const FMars_Fragment_FPHands_Params& InParams, const FMars_Fragment_FPHands& InState) const
    {
        const auto HandWorld = utils_transform::Get_EntityCurrentTransform(InParams.Spec.HandNode);
        auto Hand = FMars_FPHands_HandState(InState.Hold, HandWorld, InState.Reach.PreferredHand);

        // The rest pose seen from where the player stands: FaceViewer grips (levers, chains) are taken from this side.
        const auto Rest = utils_fphands::Get_RestTargets(InParams.Spec.Rest, InState.Hold,
            FMars_FPHands_TargetFrame(HandWorld, FVector::ZeroVector, FVector::ZeroVector));
        Hand.RestGripWorld = TOptional<FMars_FPHands_GloveRotations>(FMars_FPHands_GloveRotations(
            (Rest.Right.GripInHand * HandWorld).GetRotation(), (Rest.Left.GripInHand * HandWorld).GetRotation()));
        return Hand;
    }

    // What the gloves go for; a single-handed result becomes the glove later reaches prefer.
    private TOptional<FMars_FPHands_ReachTarget> Resolve_Target(const FMars_Fragment_FPHands_Params& InParams, FMars_Fragment_FPHands& InState,
                                                                const FMars_FPHands_ReachQuery& InQuery)
    {
        const auto Target = utils_fphands::Resolve_ReachTarget(InParams.Spec.Reach, InQuery);
        if (Target.IsSet())
        {
            const auto Resolved = Target.GetValue();
            if (Resolved.Right.IsSet() != Resolved.Left.IsSet())
            { InState.Reach.PreferredHand = Resolved.Right.IsSet() ? EMars_Hand::Right : EMars_Hand::Left; }
        }

        return Target;
    }
}
