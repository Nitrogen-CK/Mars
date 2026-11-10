// No authority gate (stance D): every machine runs its own swing, and the owner decides who issues requests.
class UMars_Processor_Oscillator_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Oscillator_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Oscillator);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Oscillator_Requests& InRequests,
                       FMars_Fragment_Oscillator& InState)
    {
        auto Self = InHandle.As_Oscillator();

        const auto HasSetRunning = InRequests.SetRunningRequests.Num() > 0;
        auto TargetRunState = EMars_Oscillator_RunState::Stopped;
        if (HasSetRunning)
        { TargetRunState = InRequests.SetRunningRequests.Last().RunState; }

        const auto HasAlign = InRequests.AlignRequests.Num() > 0;
        auto AlignSample = FMars_Oscillator_Sample();
        if (HasAlign)
        { AlignSample = InRequests.AlignRequests.Last().Sample; }

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Oscillator_Requests);

        if (HasSetRunning)
        { ApplySetRunning(Self, TargetRunState); }

        if (HasAlign)
        { ApplyAlign(Self, AlignSample); }
    }

    private void ApplySetRunning(FCk_Handle_Oscillator& InSelf, EMars_Oscillator_RunState InRunState)
    {
        auto& State = InSelf.Get_Fragment(FMars_Fragment_Oscillator);
        const auto WasRunning = State.State == EMars_Oscillator_State::Running;
        const auto Running = InRunState == EMars_Oscillator_RunState::Running;
        if (WasRunning == Running)
        { return; }

        // A caught swing is not running, so a stop never reaches it here; a start releases it.
        State.State = Running ? EMars_Oscillator_State::Running : EMars_Oscillator_State::Stopped;

        if (InSelf.Has_Fragment(FMars_Fragment_Oscillator_Signals) == false)
        { return; }

        InSelf.Get_Fragment(FMars_Fragment_Oscillator_Signals).OnRunningChanged.Broadcast(InSelf, InRunState);

        // A swing stopped before its envelope rose never reaches the Tick's rest edge; it is at rest already.
        if (Running == false && InSelf.Get_IsSwinging() == false && InSelf.Has_Fragment(FMars_Fragment_Oscillator_Signals))
        { InSelf.Get_Fragment(FMars_Fragment_Oscillator_Signals).OnCameToRest.Broadcast(InSelf); }
    }

    // The Tick skips a caught swing, so a Caught sample writes its node here.
    private void ApplyAlign(FCk_Handle_Oscillator& InSelf, FMars_Oscillator_Sample InSample)
    {
        const auto& Params = InSelf.Get_Fragment(FMars_Fragment_Oscillator_Params);
        const auto WasRunning = InSelf.Get_IsRunning();
        const auto WasSwinging = InSelf.Get_IsSwinging();

        auto& State = InSelf.Get_Fragment(FMars_Fragment_Oscillator);
        State.State = InSample.State;
        State.Time = utils_oscillator::Wrap_Time(InSample.Time, Params.PeriodSeconds);
        State.Envelope = InSample.Envelope;

        if (State.State == EMars_Oscillator_State::Caught)
        {
            auto Node = InSelf.As_SceneNode();
            utils_scene_node::Request_UpdateOffset_Rotation(Node,
                utils_oscillator::Make_NodeRotation(Params.RestRotation, Params.Axis, utils_oscillator::Get_SwingAngle(Params, State)),
                ECk_RelativeAbsolute::Absolute);
        }

        const auto IsRunning = InSelf.Get_IsRunning();
        const auto CameToRest = WasSwinging && InSelf.Get_IsSwinging() == false;

        if (InSelf.Has_Fragment(FMars_Fragment_Oscillator_Signals) == false)
        { return; }

        if (IsRunning != WasRunning)
        {
            InSelf.Get_Fragment(FMars_Fragment_Oscillator_Signals).OnRunningChanged.Broadcast(InSelf,
                IsRunning ? EMars_Oscillator_RunState::Running : EMars_Oscillator_RunState::Stopped);
        }

        if (CameToRest && InSelf.Has_Fragment(FMars_Fragment_Oscillator_Signals))
        { InSelf.Get_Fragment(FMars_Fragment_Oscillator_Signals).OnCameToRest.Broadcast(InSelf); }
    }
}
