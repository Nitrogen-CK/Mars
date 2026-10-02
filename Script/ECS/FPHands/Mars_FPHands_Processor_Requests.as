// Drains SetHold, then SetFocus, then Release, then SetPhase, then StartPush, then StartReach. The phase itself only moves
// through SetPhase (the Hands sub-SM's state enter tasks); StartPush, StartReach and Release only broadcast, and the
// sub-SM's conditions turn those broadcasts into transitions. Release is honoured only while holding; StartPush only at
// rest (Phase None); StartReach at rest and while letting go (Release, Return), the phases whose states listen for it -
// a reach requested mid-grab, mid-hold or mid-push leaves the current target alone, so a same-drain release still eases
// back from the target it was holding. SetPhase drains before both so a request arriving in the same drain as Rest's
// SetPhase(None) is honoured. A reach that interrupts a release or return starts from the alpha the gloves were at
// (ReachFromAlpha, recorded by SetPhase). A Return with a picked-up item still riding in (Carry active) is not
// interrupted - the carry would snap back to where the item lay; a timed target that arrives then is caught by Rest's
// re-sync once the return ends.
//
// A StartReach with no Interactable is a bare reach: one glove (the right) toward the hand node itself. Headless tests
// drive the phase machine this way, without an interactable to resolve.
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
        TArray<FMars_Request_FPHands_StartReach> StartReachRequests = InRequests.StartReachRequests;
        TArray<FMars_Request_FPHands_Release> ReleaseRequests = InRequests.ReleaseRequests;
        TArray<FMars_Request_FPHands_SetPhase> SetPhaseRequests = InRequests.SetPhaseRequests;
        TArray<FMars_Request_FPHands_StartPush> StartPushRequests = InRequests.StartPushRequests;

        // Swap-and-pop - InRequests is dead past this line. Removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_FPHands_Requests);

        for (const auto& Request : SetHoldRequests)
        { HandleSetHold(InState, Request); }

        for (const auto& Request : SetFocusRequests)
        { HandleSetFocus(Params, InState, Request); }

        if (ReleaseRequests.Num() > 0)
        { HandleRelease(InHandle, InState); }

        if (SetPhaseRequests.Num() > 0)
        { HandleSetPhase(InHandle, InState, SetPhaseRequests.Last().Phase); }

        if (StartPushRequests.Num() > 0)
        { HandleStartPush(InHandle, InState, StartPushRequests.Last()); }

        if (StartReachRequests.Num() > 0)
        { HandleStartReach(InHandle, InState, StartReachRequests.Last()); }
    }

    // A pickup that lands while the gloves are still on it rides in with them (see the Tick processor's carry).
    private void HandleSetHold(FMars_Fragment_FPHands& InState, const FMars_Request_FPHands_SetHold& InRequest)
    {
        const auto& Item = InRequest.Item;
        InState.Hold = ck::IsValid(Item) ? utils_fphands::Make_Hold(Item) : FMars_FPHands_Hold();

        InState.Carry = FMars_FPHands_Carry();
        const auto IsGrabbing = InState.Phase == EMars_FPHands_Phase::Reach || InState.Phase == EMars_FPHands_Phase::Grip
            || InState.Phase == EMars_FPHands_Phase::Return;
        if (IsGrabbing && ck::IsValid(InState.Target.ShapeMesh.Get()) && ck::IsValid(Item) && Item.Has_Presentation())
        {
            InState.Carry.IsActive = true;
            InState.Carry.StartWorld = InState.Target.Get_HandGrip(InState.Target.Right.IsUsed).AnchorWorld;
            InState.Carry.HeldOffset = Item.Get_Presentation().HeldOffset;
        }
    }

    private void HandleSetFocus(const FMars_Fragment_FPHands_Params& InParams, FMars_Fragment_FPHands& InState,
                                const FMars_Request_FPHands_SetFocus& InRequest)
    {
        if (ck::Is_NOT_Valid(InRequest.Interactable))
        {
            InState.FocusTarget = FMars_FPHands_ReachTarget();
            InState.FocusedFor = FCk_Handle_Interactable();
            return;
        }

        if (InRequest.Interactable == InState.FocusedFor)
        { return; }

        InState.FocusedFor = InRequest.Interactable;
        const auto Subject = FMars_FPHands_ReachSubject(FCk_Handle_InteractTarget(), InRequest.Interactable, InRequest.Owner);
        InState.FocusTarget = Resolve_Target(InParams, InState, Subject);
    }

    private void HandleStartReach(FCk_Handle& InHandle, FMars_Fragment_FPHands& InState, const FMars_Request_FPHands_StartReach& InRequest)
    {
        const auto CanReach = InState.Phase == EMars_FPHands_Phase::None || InState.Phase == EMars_FPHands_Phase::Release
            || InState.Phase == EMars_FPHands_Phase::Return;
        if (CanReach == false)
        {
            Log(f"[FPHands] StartReach ignored: the gloves are busy (phase {InState.Phase :n})");
            return;
        }

        if (InState.Phase == EMars_FPHands_Phase::Return && InState.Carry.IsActive)
        {
            Log("[FPHands] StartReach ignored: a picked-up item is still riding in (phase Return)");
            return;
        }

        const auto& Params = InHandle.Get_Fragment(FMars_Fragment_FPHands_Params);

        auto Target = FMars_FPHands_ReachTarget();
        if (ck::Is_NOT_Valid(InRequest.Interactable))
        {
            Target.IsValid = true;
            Target.Layout = EMars_FPHands_GripLayout::Point;
            Target.Right.IsUsed = true;
            Target.Right.AnchorWorld = utils_transform::Get_EntityCurrentTransform(Params.HandNode);
        }
        else
        {
            const auto Subject = FMars_FPHands_ReachSubject(InRequest.Target, InRequest.Interactable, InRequest.Owner);
            Target = Resolve_Target(Params, InState, Subject);
        }

        if (Target.IsValid == false)
        {
            ck::Trace("[FPHands] StartReach ignored: the gloves cannot reach the target");
            return;
        }

        InState.Target = Target;
        InState.InteractTarget = InRequest.Target;
        InState.IsInstant = InRequest.IsInstant;

        // A pickup: if it lands in the hands, its held visual starts where the item lay.
        if (ck::IsValid(Target.ShapeMesh.Get()))
        {
            auto HeldItem = InHandle.As_HeldItem(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(HeldItem))
            { HeldItem.Set_NextSpawnFrom(Target.Get_HandGrip(Target.Right.IsUsed).AnchorWorld); }
        }

        if (InHandle.Has_Fragment(FMars_Fragment_FPHands_Signals))
        { InHandle.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachRequested.Broadcast(InHandle.As_FPHands(), InRequest.IsInstant); }
    }

    private void HandleStartPush(FCk_Handle& InHandle, FMars_Fragment_FPHands& InState, const FMars_Request_FPHands_StartPush& InRequest)
    {
        if (InState.Phase != EMars_FPHands_Phase::None)
        {
            Log(f"[FPHands] StartPush ignored: the gloves are busy (phase {InState.Phase :n})");
            return;
        }

        InState.PushHold = InRequest.Hold;
        InState.PushIsThrow = InRequest.IsThrow;

        if (InHandle.Has_Fragment(FMars_Fragment_FPHands_Signals))
        { InHandle.Get_Fragment(FMars_Fragment_FPHands_Signals).OnPushRequested.Broadcast(InHandle.As_FPHands()); }
    }

    // Only a hold lets go early; a grab always finishes on its own (a picked-up item removes its own target mid-grab).
    private void HandleRelease(FCk_Handle& InHandle, const FMars_Fragment_FPHands& InState)
    {
        if (InState.Phase != EMars_FPHands_Phase::Hold)
        {
            Log(f"[FPHands] Release ignored: the gloves are not holding (phase {InState.Phase :n})");
            return;
        }

        if (InHandle.Has_Fragment(FMars_Fragment_FPHands_Signals))
        { InHandle.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachTargetLost.Broadcast(InHandle.As_FPHands()); }
    }

    // Phase and PhaseTime are written only here; PhaseTime also advances in UMars_Processor_FPHands_Tick. Release records
    // the alpha it eases back from; Reach and Hold record the alpha they ease out from (0 from rest, the current release
    // or return alpha when they interrupt one).
    private void HandleSetPhase(FCk_Handle& InHandle, FMars_Fragment_FPHands& InState, EMars_FPHands_Phase InNewPhase)
    {
        const auto Previous = InState.Phase;
        const auto& Params = InHandle.Get_Fragment(FMars_Fragment_FPHands_Params);
        const auto PhaseState = FMars_FPHands_PhaseState(Previous, InState.PhaseTime, InState.ReleaseFromAlpha, InState.ReachFromAlpha);

        if (InNewPhase == EMars_FPHands_Phase::Release)
        { InState.ReleaseFromAlpha = utils_fphands::Get_PhaseAlpha(PhaseState, Params.Spec.Reach); }

        if (InNewPhase == EMars_FPHands_Phase::Reach || InNewPhase == EMars_FPHands_Phase::Hold)
        { InState.ReachFromAlpha = utils_fphands::Get_PhaseAlpha(PhaseState, Params.Spec.Reach); }

        if (InNewPhase == EMars_FPHands_Phase::None)
        {
            InState.Carry = FMars_FPHands_Carry();

            // The grab ended without the item landing in the hands: don't let a later equip spawn at the pickup spot.
            if (InHandle.Has_Fragment(FMars_Fragment_HeldItem_SpawnFrom))
            {
                auto HeldItem = InHandle.As_HeldItem(ECk_SanityCheck::UnChecked);
                if (ck::IsValid(HeldItem))
                { HeldItem.Clear_NextSpawnFrom(); }
            }
        }

        InState.Phase = InNewPhase;
        InState.PhaseTime = 0.0f;

        if (Previous == InNewPhase)
        { return; }

        if (InHandle.Has_Fragment(FMars_Fragment_FPHands_Signals))
        { InHandle.Get_Fragment(FMars_Fragment_FPHands_Signals).OnPhaseChanged.Broadcast(InHandle.As_FPHands(), Previous, InNewPhase); }
    }

    // What the gloves go for, from where they are now; a single-handed result becomes the glove later reaches prefer.
    private FMars_FPHands_ReachTarget Resolve_Target(const FMars_Fragment_FPHands_Params& InParams, FMars_Fragment_FPHands& InState,
                                                     const FMars_FPHands_ReachSubject& InSubject)
    {
        const auto HandWorld = utils_transform::Get_EntityCurrentTransform(InParams.HandNode);
        const auto Hand = FMars_FPHands_HandState(InState.Hold, HandWorld, InState.PreferRightHand);
        auto Target = utils_fphands::Resolve_ReachTarget(InParams.Spec.Reach, FMars_FPHands_ReachQuery(InSubject, Hand));
        if (Target.IsValid && Target.Right.IsUsed != Target.Left.IsUsed)
        { InState.PreferRightHand = Target.Right.IsUsed; }

        return Target;
    }
}
