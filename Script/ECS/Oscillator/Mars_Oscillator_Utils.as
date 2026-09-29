namespace utils_oscillator
{
    FCk_Handle_Oscillator Add(FCk_Handle_SceneNode& InNode, FMars_Oscillator_Spec InParams)
    {
        auto Params = FMars_Fragment_Oscillator_Params();
        Params.AmplitudeDegrees = InParams.AmplitudeDegrees;
        Params.PeriodSeconds = InParams.PeriodSeconds;
        Params.Axis = InParams.Axis;
        Params.SettleSeconds = InParams.SettleSeconds;
        Params.RestRotation = utils_scene_node::Get_Offset_Rotation(InNode);

        auto State = FMars_Fragment_Oscillator();
        State.IsRunning = InParams.StartRunning;
        State.Envelope = InParams.StartRunning ? 1.0f : 0.0f;

        InNode.Add_Fragment(FMars_Feature_Oscillator());
        InNode.Add_Fragment(Params);
        InNode.Add_Fragment(State);
        return InNode.As_Oscillator();
    }

    FRotator Make_SwingRotation(EMars_Oscillator_Axis InAxis, float32 InAngleDegrees)
    {
        if (InAxis == EMars_Oscillator_Axis::Pitch)
        { return FRotator(InAngleDegrees, 0.0f, 0.0f); }

        if (InAxis == EMars_Oscillator_Axis::Yaw)
        { return FRotator(0.0f, InAngleDegrees, 0.0f); }

        return FRotator(0.0f, 0.0f, InAngleDegrees);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin bool Get_IsRunning(const FCk_Handle_Oscillator& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Oscillator).IsRunning;
}

mixin float32 Get_Envelope(const FCk_Handle_Oscillator& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Oscillator).Envelope;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_SetRunning(FCk_Handle_Oscillator& Self, bool InRunning)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Oscillator_Requests);
    Requests.SetRunningRequest = FMars_Request_Oscillator_SetRunning(InRunning);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnRunningChanged(FCk_Handle_Oscillator& Self, FMars_Delegate_Oscillator_OnRunningChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Oscillator_Signals);
    Fragment.OnRunningChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnRunningChanged(FCk_Handle_Oscillator& Self, FMars_Delegate_Oscillator_OnRunningChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Oscillator_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Oscillator_Signals).OnRunningChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
