class UMars_Processor_Lever_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Lever_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Lever);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Lever_Requests& InRequests)
    {
        const auto HasRequest = InRequests.SetPulledRequest.IsSet();
        auto Target = false;
        if (HasRequest)
        { Target = InRequests.SetPulledRequest.GetValue().Pulled; }

        // Swap-and-pop - InRequests is dead past this line; removed before broadcasting so re-entrant requests survive.
        InHandle.Request_TryRemove(FMars_Fragment_Lever_Requests);

        if (HasRequest == false)
        { return; }

        auto Lever = InHandle.As_Lever();
        auto& State = Lever.Get_Fragment(FMars_Fragment_Lever);
        if (State.IsPulled == Target)
        { return; }

        State.IsPulled = Target;
        StartMove(Lever, Target);

        if (Lever.Has_Fragment(FMars_Fragment_Lever_Signals))
        { Lever.Get_Fragment(FMars_Fragment_Lever_Signals).OnPulledChanged.Broadcast(Lever, Target); }
    }

    // Tweens the pitch itself from the node's current pitch, so a reversal mid-move continues from where it is.
    private void StartMove(FCk_Handle_Lever& InLever, bool InPulled)
    {
        const auto& Params = InLever.Get_Fragment(FMars_Fragment_Lever_Params);
        auto& State = InLever.Get_Fragment(FMars_Fragment_Lever);

        if (ck::IsValid(State.MoveTween))
        {
            utils_tween::Stop(State.MoveTween, ECk_TweenStopBehavior::SelfDestruct);
            State.MoveTween = FCk_Handle_Tween();
        }

        auto Node = State.HandleNode;
        if (ck::Is_NOT_Valid(Node))
        { return; }

        const auto FromPitch = float32(utils_scene_node::Get_Offset_Rotation(Node).Pitch);
        const auto ToPitch = InPulled ? Params.PulledAngle : 0.0f;

        if (Params.MoveDuration <= KINDA_SMALL_NUMBER)
        {
            utils_scene_node::Request_UpdateOffset_Rotation(Node, FRotator(ToPitch, 0.0, 0.0), ECk_RelativeAbsolute::Absolute);
            return;
        }

        auto LeverEntity = FCk_Handle(InLever);
        auto NewTween = utils_tween::Create_TweenFloat(
            LeverEntity,
            FromPitch, ToPitch,
            Params.MoveDuration,
            ECk_TweenEasing::InOutSine,
            ECk_TweenLoopType::None, 0, 0.0f,
            ECk_TweenCompletionBehavior::SelfDestruct);

        utils_tween::BindTo_OnUpdate(NewTween, FCk_Delegate_Tween_OnUpdate(this, n"OnMoveUpdate"));
        State.MoveTween = NewTween;
    }

    UFUNCTION()
    private void OnMoveUpdate(FCk_Handle_Tween InTween, FCk_Tween_Payload_OnUpdate InPayload)
    {
        // Get_LifetimeOwner, not ck::Ctx: the tween's immediate owner is the lever entity.
        auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InTween);
        if (ck::Is_NOT_Valid(Owner))
        { return; }

        auto Lever = Owner.As_Lever(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Lever))
        { return; }

        const auto& State = Lever.Get_Fragment(FMars_Fragment_Lever);

        // A superseded tween can still fire in the frame it was stopped.
        if ((FCk_Handle(State.MoveTween) == FCk_Handle(InTween)) == false)
        { return; }

        auto Node = State.HandleNode;
        if (ck::Is_NOT_Valid(Node))
        { return; }

        const auto Pitch = utils_tween::TweenValue_GetAsFloat(InPayload.Get_CurrentValue());
        utils_scene_node::Request_UpdateOffset_Rotation(Node, FRotator(Pitch, 0.0, 0.0), ECk_RelativeAbsolute::Absolute);
    }
}
