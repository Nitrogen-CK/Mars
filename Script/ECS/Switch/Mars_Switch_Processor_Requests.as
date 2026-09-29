class UMars_Processor_Switch_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Switch_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Switch);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Switch_Requests& InRequests)
    {
        const auto HasPress = InRequests.PressRequest.IsSet();
        const auto HasRelease = InRequests.ReleaseRequest.IsSet();

        // Swap-and-pop - InRequests is dead past this line; removed before broadcasting so re-entrant requests survive.
        InHandle.Request_TryRemove(FMars_Fragment_Switch_Requests);

        auto Switch = InHandle.As_Switch();
        if (HasPress)
        {
            DoPress(Switch);
            return;
        }

        if (HasRelease)
        { DoRelease(Switch); }
    }

    private void DoPress(FCk_Handle_Switch& InSwitch)
    {
        const auto& Params = InSwitch.Get_Fragment(FMars_Fragment_Switch_Params);
        auto& State = InSwitch.Get_Fragment(FMars_Fragment_Switch);

        DestroyHoldTimer(State);

        auto TimerSpec = FCk_Timer_Spec(FCk_Time(Params.HoldSeconds));
        TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                 .Set_Behavior(ECk_Timer_Behavior::StopOnDone);

        auto SwitchEntity = FCk_Handle(InSwitch);
        auto Timer = utils_timer::Add(SwitchEntity, TimerSpec);
        if (ck::IsValid(Timer))
        { Timer.BindTo_OnDone(FCk_Delegate_Timer(this, n"OnHoldTimerDone")); }
        State.HoldTimer = Timer;

        if (State.IsPressed)
        { return; }

        State.IsPressed = true;
        StartMove(InSwitch, Params.PressOffset);
        Broadcast(InSwitch, true);
    }

    private void DoRelease(FCk_Handle_Switch& InSwitch)
    {
        auto& State = InSwitch.Get_Fragment(FMars_Fragment_Switch);
        DestroyHoldTimer(State);

        if (State.IsPressed == false)
        { return; }

        State.IsPressed = false;
        StartMove(InSwitch, FVector::ZeroVector);
        Broadcast(InSwitch, false);
    }

    private void DestroyHoldTimer(FMars_Fragment_Switch& InState)
    {
        if (ck::IsValid(InState.HoldTimer))
        { utils_entity_lifetime::Request_DestroyEntity(FCk_Handle(InState.HoldTimer)); }

        InState.HoldTimer = FCk_Handle_Timer();
    }

    private void Broadcast(FCk_Handle_Switch& InSwitch, bool InPressed)
    {
        if (InSwitch.Has_Fragment(FMars_Fragment_Switch_Signals) == false)
        { return; }

        InSwitch.Get_Fragment(FMars_Fragment_Switch_Signals).OnPressedChanged.Broadcast(InSwitch, InPressed);
    }

    // Tweens the location itself from the node's current offset, so a release mid-press continues from where it is.
    private void StartMove(FCk_Handle_Switch& InSwitch, FVector InTargetOffset)
    {
        const auto& Params = InSwitch.Get_Fragment(FMars_Fragment_Switch_Params);
        auto& State = InSwitch.Get_Fragment(FMars_Fragment_Switch);

        if (ck::IsValid(State.MoveTween))
        {
            utils_tween::Stop(State.MoveTween, ECk_TweenStopBehavior::SelfDestruct);
            State.MoveTween = FCk_Handle_Tween();
        }

        auto Node = State.ButtonNode;
        if (ck::Is_NOT_Valid(Node))
        { return; }

        if (Params.MoveDuration <= KINDA_SMALL_NUMBER)
        {
            utils_scene_node::Request_UpdateOffset_Location(Node, InTargetOffset, ECk_RelativeAbsolute::Absolute);
            return;
        }

        const auto FromOffset = utils_scene_node::Get_Offset_Location(Node);

        auto SwitchEntity = FCk_Handle(InSwitch);
        auto NewTween = utils_tween::Create_TweenVector(
            SwitchEntity,
            FromOffset, InTargetOffset,
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
        // Get_LifetimeOwner, not ck::Ctx: the tween's immediate owner is the switch entity.
        auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InTween);
        if (ck::Is_NOT_Valid(Owner))
        { return; }

        auto Switch = Owner.As_Switch(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Switch))
        { return; }

        const auto& State = Switch.Get_Fragment(FMars_Fragment_Switch);

        // A superseded tween can still fire in the frame it was stopped.
        if ((FCk_Handle(State.MoveTween) == FCk_Handle(InTween)) == false)
        { return; }

        auto Node = State.ButtonNode;
        if (ck::Is_NOT_Valid(Node))
        { return; }

        const auto Offset = utils_tween::TweenValue_GetAsVector(InPayload.Get_CurrentValue());
        utils_scene_node::Request_UpdateOffset_Location(Node, Offset, ECk_RelativeAbsolute::Absolute);
    }

    UFUNCTION()
    private void OnHoldTimerDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InTimer);
        if (ck::Is_NOT_Valid(Owner))
        { return; }

        auto Switch = Owner.As_Switch(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Switch))
        { return; }

        // A timer replaced by a re-press can still finish in the frame it was destroyed.
        const auto& State = Switch.Get_Fragment(FMars_Fragment_Switch);
        if ((FCk_Handle(State.HoldTimer) == FCk_Handle(InTimer)) == false)
        { return; }

        Switch.Request_Release();
    }
}
