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

        const auto HasRequest = InRequests.MoveToRequest.IsSet();
        auto TargetAtEnd = false;
        if (HasRequest)
        { TargetAtEnd = InRequests.MoveToRequest.GetValue().AtEnd; }

        // Swap-and-pop - InRequests is dead past this line. Removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Mover_Requests);

        if (HasRequest == false || InState.AtEnd == TargetAtEnd)
        { return; }

        InState.AtEnd = TargetAtEnd;
        const auto ArrivedImmediately = StartMove(Self, InState);

        if (Self.Has_Fragment(FMars_Fragment_Mover_Signals) == false)
        { return; }

        Self.Get_Fragment(FMars_Fragment_Mover_Signals).OnTargetChanged.Broadcast(Self, TargetAtEnd);

        if (ArrivedImmediately && Self.Has_Fragment(FMars_Fragment_Mover_Signals))
        { Self.Get_Fragment(FMars_Fragment_Mover_Signals).OnArrived.Broadcast(Self, TargetAtEnd); }
    }

    // Tweens Alpha from its current value, so reversing mid-move continues from the current pose instead of
    // snapping to an end. Returns true when the move completed without a tween.
    private bool StartMove(FCk_Handle_Mover& InMover, FMars_Fragment_Mover& InState)
    {
        const auto& Params = InMover.Get_Fragment(FMars_Fragment_Mover_Params);

        if (ck::IsValid(InState.Tween))
        {
            utils_tween::Stop(InState.Tween, ECk_TweenStopBehavior::SelfDestruct);
            InState.Tween = FCk_Handle_Tween();
        }

        const auto TargetAlpha = InState.AtEnd ? 1.0f : 0.0f;
        const auto Duration = Params.Duration * Math::Abs(TargetAlpha - InState.Alpha);

        if (Duration <= KINDA_SMALL_NUMBER)
        {
            InState.Alpha = TargetAlpha;
            auto Node = FCk_Handle(InMover).As_SceneNode();
            utils_mover::Request_ApplyAlpha(Node, Params, TargetAlpha);
            return true;
        }

        auto MoverEntity = FCk_Handle(InMover);
        auto NewTween = utils_tween::Create_TweenFloat(
            MoverEntity,
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
        // Get_LifetimeOwner, not ck::Ctx: the tween's immediate owner is the mover's node entity.
        auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InTween);
        auto Mover = Owner.As_Mover(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Mover))
        { return; }

        auto& State = Mover.Get_Fragment(FMars_Fragment_Mover);
        // A superseded tween can still fire in the frame it was stopped.
        if ((FCk_Handle(State.Tween) == FCk_Handle(InTween)) == false)
        { return; }

        State.Alpha = float32(utils_tween::TweenValue_GetAsFloat(InPayload.Get_CurrentValue()));

        auto Node = Owner.As_SceneNode();
        utils_mover::Request_ApplyAlpha(Node, Mover.Get_Fragment(FMars_Fragment_Mover_Params), State.Alpha);
    }

    UFUNCTION()
    private void OnMoveComplete(FCk_Handle_Tween InTween, FCk_Tween_Payload_OnComplete InPayload)
    {
        auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InTween);
        auto Mover = Owner.As_Mover(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Mover))
        { return; }

        auto& State = Mover.Get_Fragment(FMars_Fragment_Mover);
        // Stopping a tween also completes it, so a superseded tween lands here too.
        if ((FCk_Handle(State.Tween) == FCk_Handle(InTween)) == false)
        { return; }

        const auto AtEnd = State.AtEnd;
        State.Alpha = AtEnd ? 1.0f : 0.0f;
        State.Tween = FCk_Handle_Tween();

        auto Node = Owner.As_SceneNode();
        utils_mover::Request_ApplyAlpha(Node, Mover.Get_Fragment(FMars_Fragment_Mover_Params), State.Alpha);

        if (Mover.Has_Fragment(FMars_Fragment_Mover_Signals))
        { Mover.Get_Fragment(FMars_Fragment_Mover_Signals).OnArrived.Broadcast(Mover, AtEnd); }
    }
}
