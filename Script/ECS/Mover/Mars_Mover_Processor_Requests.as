// Drained Scrub -> MoveTo -> Settle. A MoveTo that changes the target tweens there from the current alpha; a MoveTo to
// the current target, like a Settle, only brings back a handle a scrub left off it, and does nothing (no OnArrived) when
// the handle already rests on the target or a tween is already taking it there.
class UMars_Processor_Mover_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Mover_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Mover);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Mover_Requests& InRequests,
                       FMars_Fragment_Mover& InState)
    {
        auto Self = InHandle.As_Mover();

        const auto HasScrub = InRequests.ScrubRequests.Num() > 0;
        auto ScrubAlpha = 0.0f;
        if (HasScrub)
        { ScrubAlpha = InRequests.ScrubRequests.Last().Alpha; }

        const auto HasMoveTo = InRequests.MoveToRequests.Num() > 0;
        auto RequestedTarget = InState.Target;
        if (HasMoveTo)
        { RequestedTarget = InRequests.MoveToRequests.Last().Target; }

        const auto HasSettle = InRequests.SettleRequests.Num() > 0;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Mover_Requests);

        if (HasScrub)
        { Scrub(Self, InState, ScrubAlpha); }

        const auto TargetChanged = HasMoveTo && RequestedTarget != InState.Target;
        auto ArrivedImmediately = false;
        if (TargetChanged)
        {
            InState.Target = RequestedTarget;
            ArrivedImmediately = StartMove(Self, InState);
        }
        else if ((HasMoveTo || HasSettle) && Get_IsOffTarget(InState))
        { ArrivedImmediately = StartMove(Self, InState); }

        const auto Target = InState.Target;

        if (Self.Has_Fragment(FMars_Fragment_Mover_Signals) == false)
        { return; }

        if (TargetChanged)
        { Self.Get_Fragment(FMars_Fragment_Mover_Signals).OnTargetChanged.Broadcast(Self, Target); }

        if (ArrivedImmediately && Self.Has_Fragment(FMars_Fragment_Mover_Signals))
        { Self.Get_Fragment(FMars_Fragment_Mover_Signals).OnArrived.Broadcast(Self, Target); }
    }

    // Resting somewhere other than the target pose: only a scrub leaves the handle there, since every tween heads to the
    // current target.
    private bool Get_IsOffTarget(const FMars_Fragment_Mover& InState) const
    {
        return ck::Is_NOT_Valid(InState.Tween) && InState.Alpha != Get_TargetAlpha(InState.Target);
    }

    private float32 Get_TargetAlpha(EMars_Mover_Pose InPose) const
    {
        return InPose == EMars_Mover_Pose::End ? 1.0f : 0.0f;
    }

    // Holds the handle at InAlpha with no tween. The stopped tween's OnMoveComplete still fires this frame and is
    // rejected by its handle check.
    private void Scrub(FCk_Handle_Mover& InMover, FMars_Fragment_Mover& InState, float32 InAlpha)
    {
        StopTween(InState);

        InState.Alpha = Math::Clamp(InAlpha, 0.0f, 1.0f);
        auto Node = InMover.As_SceneNode();
        utils_mover::Request_ApplyAlpha(Node, InMover.Get_Fragment(FMars_Fragment_Mover_Params), InState.Alpha);
    }

    private void StopTween(FMars_Fragment_Mover& InState)
    {
        if (ck::Is_NOT_Valid(InState.Tween))
        { return; }

        utils_tween::Stop(InState.Tween, ECk_TweenStopBehavior::SelfDestruct);
        InState.Tween = FCk_Handle_Tween();
    }

    // Tweens Alpha from its current value, so reversing mid-move continues from the current pose instead of
    // snapping to an end. Returns true when the move completed without a tween.
    private bool StartMove(FCk_Handle_Mover& InMover, FMars_Fragment_Mover& InState)
    {
        const auto& Params = InMover.Get_Fragment(FMars_Fragment_Mover_Params);

        StopTween(InState);

        const auto TargetAlpha = Get_TargetAlpha(InState.Target);
        const auto Duration = Params.Duration * Math::Abs(TargetAlpha - InState.Alpha);

        if (Duration <= KINDA_SMALL_NUMBER)
        {
            InState.Alpha = TargetAlpha;
            auto Node = InMover.As_SceneNode();
            utils_mover::Request_ApplyAlpha(Node, Params, TargetAlpha);
            return true;
        }

        auto NewTween = utils_tween::Create_TweenFloat(
            InMover.H(),
            InState.Alpha, TargetAlpha,
            Duration,
            Params.Easing,
            ECk_TweenLoopType::None, 0, 0.0f,
            ECk_TweenCompletionBehavior::SelfDestruct);

        utils_tween::BindTo_OnUpdate(NewTween, FCk_Delegate_Tween_OnUpdate(this, n"OnMoveUpdate"));
        utils_tween::BindTo_OnComplete(NewTween, FCk_Delegate_Tween_OnComplete(this, n"OnMoveComplete"));
        InState.Tween = NewTween;
        return false;
    }

    UFUNCTION()
    private void OnMoveUpdate(FCk_Handle_Tween InTween, FCk_Tween_Payload_OnUpdate InPayload)
    {
        // Get_LifetimeOwner, not ck::Ctx: the tween's immediate owner is the mover's node entity. The owner is gone only
        // while the mover is being torn down.
        auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InTween);
        if (ck::Is_NOT_Valid(Owner))
        { return; }

        auto Mover = Owner.As_Mover();
        auto& State = Mover.Get_Fragment(FMars_Fragment_Mover);
        // A superseded tween can still fire in the frame it was stopped.
        if (State.Tween != InTween)
        { return; }

        State.Alpha = float32(utils_tween::TweenValue_GetAsFloat(InPayload.Get_CurrentValue()));

        auto Node = Owner.As_SceneNode();
        utils_mover::Request_ApplyAlpha(Node, Mover.Get_Fragment(FMars_Fragment_Mover_Params), State.Alpha);
    }

    UFUNCTION()
    private void OnMoveComplete(FCk_Handle_Tween InTween, FCk_Tween_Payload_OnComplete InPayload)
    {
        auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InTween);
        if (ck::Is_NOT_Valid(Owner))
        { return; }

        auto Mover = Owner.As_Mover();
        auto& State = Mover.Get_Fragment(FMars_Fragment_Mover);
        // Stopping a tween also completes it, so a superseded tween lands here too.
        if (State.Tween != InTween)
        { return; }

        const auto Target = State.Target;
        State.Alpha = Get_TargetAlpha(Target);
        State.Tween = FCk_Handle_Tween();

        auto Node = Owner.As_SceneNode();
        utils_mover::Request_ApplyAlpha(Node, Mover.Get_Fragment(FMars_Fragment_Mover_Params), State.Alpha);

        if (Mover.Has_Fragment(FMars_Fragment_Mover_Signals))
        { Mover.Get_Fragment(FMars_Fragment_Mover_Signals).OnArrived.Broadcast(Mover, Target); }
    }
}
