class UMars_Processor_Gate_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Gate_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Gate);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Gate_Requests& InRequests,
                       FMars_Fragment_Gate& InState)
    {
        auto Self = InHandle.As_Gate();

        const auto HasRequest = InRequests.SetOpenRequest.IsSet();
        auto TargetOpen = false;
        if (HasRequest)
        { TargetOpen = InRequests.SetOpenRequest.GetValue().Open; }

        // Swap-and-pop - InRequests is dead past this line. Removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Gate_Requests);

        if (HasRequest == false || InState.IsOpen == TargetOpen)
        { return; }

        InState.IsOpen = TargetOpen;
        StartMove(Self, InState);

        if (Self.Has_Fragment(FMars_Fragment_Gate_Signals))
        { Self.Get_Fragment(FMars_Fragment_Gate_Signals).OnOpenChanged.Broadcast(Self, TargetOpen); }
    }

    // The tween runs over openness (0 closed, 1 open) starting from the node's current openness, so reversing
    // mid-move continues from where the leaf is instead of snapping to an end.
    private void StartMove(FCk_Handle_Gate& InGate, FMars_Fragment_Gate& InState)
    {
        const auto& Params = InGate.Get_Fragment(FMars_Fragment_Gate_Params);

        if (ck::IsValid(InState.MoveTween))
        {
            utils_tween::Stop(InState.MoveTween, ECk_TweenStopBehavior::SelfDestruct);
            InState.MoveTween = FCk_Handle_Tween();
        }

        auto MovingNode = InState.MovingNode;
        if (ck::Is_NOT_Valid(MovingNode))
        { return; }

        const auto TargetAlpha = InState.IsOpen ? 1.0f : 0.0f;
        const auto CurrentAlpha = Get_Openness(utils_scene_node::Get_Offset_Location(MovingNode), Params.OpenOffset);
        const auto Duration = Params.MoveDuration * Math::Abs(TargetAlpha - CurrentAlpha);

        if (Duration <= KINDA_SMALL_NUMBER)
        {
            utils_scene_node::Request_UpdateOffset_Location(MovingNode, Params.OpenOffset * TargetAlpha, ECk_RelativeAbsolute::Absolute);
            return;
        }

        auto GateEntity = FCk_Handle(InGate);
        auto NewTween = utils_tween::Create_TweenFloat(
            GateEntity,
            CurrentAlpha, TargetAlpha,
            Duration,
            Params.Easing,
            ECk_TweenLoopType::None, 0, 0.0f,
            ECk_TweenCompletionBehavior::SelfDestruct);

        utils_tween::BindTo_OnUpdate(NewTween, FCk_Delegate_Tween_OnUpdate(this, n"OnMoveUpdate"));
        InState.MoveTween = NewTween;
    }

    private float32 Get_Openness(FVector InOffset, FVector InOpenOffset)
    {
        const auto LengthSquared = InOpenOffset.SizeSquared();
        if (LengthSquared <= KINDA_SMALL_NUMBER)
        { return 0.0f; }

        return Math::Clamp(float32(InOffset.DotProduct(InOpenOffset) / LengthSquared), 0.0f, 1.0f);
    }

    UFUNCTION()
    private void OnMoveUpdate(FCk_Handle_Tween InTween, FCk_Tween_Payload_OnUpdate InPayload)
    {
        // Get_LifetimeOwner, not ck::Ctx: the tween's immediate owner is the gate entity.
        auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InTween);
        auto Gate = Owner.As_Gate(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Gate))
        { return; }

        const auto& State = Gate.Get_Fragment(FMars_Fragment_Gate);
        // A superseded tween can still fire in the frame it was stopped.
        if ((FCk_Handle(State.MoveTween) == FCk_Handle(InTween)) == false)
        { return; }

        auto MovingNode = State.MovingNode;
        if (ck::Is_NOT_Valid(MovingNode))
        { return; }

        const auto& Params = Gate.Get_Fragment(FMars_Fragment_Gate_Params);
        const auto Alpha = utils_tween::TweenValue_GetAsFloat(InPayload.Get_CurrentValue());
        utils_scene_node::Request_UpdateOffset_Location(MovingNode, Params.OpenOffset * Alpha, ECk_RelativeAbsolute::Absolute);
    }
}
