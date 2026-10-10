// The station Use target's interaction sub-SM: an acquire gate, and nothing else. The target is WhileLive: its interaction
// lives while the reserve is asked, and the sub-SM ends it with the answer (or with none). Operating the station is the
// player's Operating state (Script/PlayerCharacter/HFSM/Mars_PlayerCharacter_Hfsm_Operating.as) and the station's own
// minigame SM.
//
//   Station_Use (overrides InteractTarget_Enter)   task: Station_RequestReserve (no presentation: nothing to undo)
//     ->InteractTarget_Succeeded [ReserveConfirmed]   the station names this initiator
//     ->InteractTarget_Failed    [ReserveRejected]    the station rejected this initiator, or died while we waited
//     ->InteractTarget_Failed    [ReserveTimeout]     no answer within TimeoutSeconds (the request was lost)
//     ->InteractTarget_Failed    [AnyTaskFailed]      no station or no initiator to reserve for

class UMars_SmState_Station_Use : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    TArray<FGameplayTag> DoGet_StatesToOverride() const
    {
        return GameplayTag::MakeGameplayTagArrayFromTag(
            UCk_SmState_EntityScript::Get_StateTagForClass(UMars_SmState_InteractTarget_Enter));
    }

    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_Station_RequestReserve);

        auto OnConfirmed = AddTransition(InHandle, UMars_SmState_InteractTarget_Succeeded);
        AddCondition(OnConfirmed, UMars_SmCondition_Station_ReserveConfirmed);

        auto OnRejected = AddTransition(InHandle, UMars_SmState_InteractTarget_Failed);
        AddCondition(OnRejected, UMars_SmCondition_Station_ReserveRejected);

        auto OnTimeout = AddTransition(InHandle, UMars_SmState_InteractTarget_Failed);
        AddCondition(OnTimeout, UMars_SmCondition_Station_ReserveTimeout);

        auto OnFailure = AddTransition(InHandle, UMars_SmState_InteractTarget_Failed);
        AddCondition(OnFailure, UMars_SmCondition_AnyTaskFailed);
    }
}

// The grip target's interaction state: terminate at once. The grip target lives on InteractionChannel.Mars.Operate and
// is resolved only under the Operate intent the player's Operating state opens; it never touches the Use intent, so E
// while operating cannot disturb the gloves. A target's InteractionStateClass must override
// InteractTarget_Enter (the target SM rejects an override that names no state), so this is ExitAndTerminate with that
// override. Its ManuallyCompleted interaction is never completed (the Operating state cancels it), so in practice it never
// runs.
class UMars_SmState_Station_Grip : UMars_SmState_ExitAndTerminate
{
    UFUNCTION(BlueprintOverride)
    TArray<FGameplayTag> DoGet_StatesToOverride() const
    {
        return GameplayTag::MakeGameplayTagArrayFromTag(
            UCk_SmState_EntityScript::Get_StateTagForClass(UMars_SmState_InteractTarget_Enter));
    }
}

// Reserves the station for the initiator. The state only runs as a station's Use interaction, so the owner is the
// station and the sub-SM root carries the initiator of its live interaction; failing either ensures and fails the task.
class UMars_SmTask_Station_RequestReserve : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        const auto Context = utils_station::Get_InteractionContext(Get_StateMachineContext(), Get_OwningStateMachine());
        auto Station = Context.InteractableOwner.As_Station();
        if (ck::Is_NOT_Valid(Station) ||
            ck::EnsureIfNot(ck::IsValid(Context.Initiator), f"[Station] [{Station.ToString()}] Use interaction has no initiator"))
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        Station.Request_Reserve(FMars_Request_Station_Reserve(Context.Initiator));
        Mark_Result(ECk_SmTaskResult::Succeeded);
    }
}

// Event-driven: satisfied once the station names this sub-SM's initiator as its operator. Seeded on enter (rests at Fail
// unless the reserve already landed); marked from OnReserved.
class UMars_SmCondition_Station_ReserveConfirmed : UCk_SmCondition_EventDriven
{
    private FCk_Handle_Station _Station;
    private FCk_Handle _Initiator;

    UFUNCTION(BlueprintOverride)
    void DoEnterCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        const auto Context = utils_station::Get_InteractionContext(Get_StateMachineContext(), Get_OwningStateMachine());
        _Station = Context.InteractableOwner.As_Station(ECk_SanityCheck::UnChecked);
        _Initiator = Context.Initiator;
        if (ck::Is_NOT_Valid(_Station) || ck::Is_NOT_Valid(_Initiator))
        {
            MarkUnsatisfied();
            return;
        }

        _Station.BindTo_OnReserved(FMars_Delegate_Station_OnReserved(this, n"OnReserved"));

        if (_Station.Get_IsOperatedBy(_Initiator))
        { MarkSatisfied(); }
        else
        { MarkUnsatisfied(); }
    }

    UFUNCTION(BlueprintOverride)
    void DoExitCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Station))
        { _Station.UnbindFrom_OnReserved(FMars_Delegate_Station_OnReserved(this, n"OnReserved")); }

        _Station = FCk_Handle_Station();
        _Initiator = FCk_Handle();
    }

    UFUNCTION()
    private void OnReserved(FCk_Handle_Station InStation, FCk_Handle InOperator)
    {
        if (InOperator == _Initiator)
        { MarkSatisfied(); }
    }
}

// Event-driven: satisfied when the station rejects this sub-SM's initiator (any reason) or begins destroying while we wait;
// satisfied at once when there is no station or no initiator (nothing can ever confirm). Rests at Fail otherwise.
class UMars_SmCondition_Station_ReserveRejected : UCk_SmCondition_EventDriven
{
    private FCk_Handle_Station _Station;
    private FCk_Handle _Initiator;

    UFUNCTION(BlueprintOverride)
    void DoEnterCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        const auto Context = utils_station::Get_InteractionContext(Get_StateMachineContext(), Get_OwningStateMachine());
        _Station = Context.InteractableOwner.As_Station(ECk_SanityCheck::UnChecked);
        _Initiator = Context.Initiator;
        if (ck::Is_NOT_Valid(_Station) || ck::Is_NOT_Valid(_Initiator))
        {
            MarkSatisfied();
            return;
        }

        _Station.BindTo_OnReserveRejected(FMars_Delegate_Station_OnReserveRejected(this, n"OnReserveRejected"));
        _Station.H().BindTo_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnStationBeginDestroy"));

        MarkUnsatisfied();
    }

    UFUNCTION(BlueprintOverride)
    void DoExitCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Station))
        {
            _Station.UnbindFrom_OnReserveRejected(FMars_Delegate_Station_OnReserveRejected(this, n"OnReserveRejected"));
            _Station.H().UnbindFrom_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnStationBeginDestroy"));
        }

        _Station = FCk_Handle_Station();
        _Initiator = FCk_Handle();
    }

    UFUNCTION()
    private void OnReserveRejected(FCk_Handle_Station InStation, FCk_Handle InOperator, EMars_Station_RejectReason InReason)
    {
        if (InOperator == _Initiator)
        { MarkSatisfied(); }
    }

    UFUNCTION()
    private void OnStationBeginDestroy(FCk_Handle InStation)
    {
        MarkSatisfied();
    }
}

// Event-driven: satisfied TimeoutSeconds after enter, neither confirmed nor rejected. The station answers every reserve it
// drains and its destruction rejects one still queued, so a reserve lost this way is a defect (an initiator without the
// Operator feature, ensured by the station's drain): ensured here too, and the Use interaction gives up. The timer is a
// child of the condition and is destroyed on exit.
class UMars_SmCondition_Station_ReserveTimeout : UCk_SmCondition_EventDriven
{
    protected float32 TimeoutSeconds = 3.0f;

    private FCk_Handle_Timer _Timer;

    UFUNCTION(BlueprintOverride)
    void DoEnterCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        MarkUnsatisfied();

        auto TimerSpec = FCk_Timer_Spec(FCk_Time(TimeoutSeconds));
        TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                 .Set_Behavior(ECk_Timer_Behavior::PauseOnDone);

        _Timer = utils_timer::Add(InHandle, TimerSpec);
        if (ck::IsValid(_Timer))
        { _Timer.BindTo_OnDone(FCk_Delegate_Timer(this, n"OnTimeout")); }
    }

    UFUNCTION(BlueprintOverride)
    void DoExitCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Timer))
        { utils_entity_lifetime::Request_DestroyEntity(_Timer); }

        _Timer = FCk_Handle_Timer();
    }

    UFUNCTION()
    private void OnTimeout(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        ck::EnsureIfNot(false, f"[Station] a reserve was not answered within {TimeoutSeconds} s: the Use interaction gives up");
        MarkSatisfied();
    }
}
