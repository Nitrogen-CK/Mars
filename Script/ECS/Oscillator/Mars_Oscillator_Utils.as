namespace utils_oscillator
{
    // A spec that fails Validate() ensures and adds nothing.
    FCk_Handle_Oscillator Add(FCk_Handle_SceneNode& InNode, FMars_Oscillator_Spec InParams)
    {
        const auto Validation = InParams.Validate();
        if (ck::EnsureIfNot(Validation.IsValid, f"[Oscillator] [{InNode.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Oscillator(); }

        auto Params = FMars_Fragment_Oscillator_Params();
        Params.AmplitudeDegrees = InParams.AmplitudeDegrees;
        Params.PeriodSeconds = InParams.PeriodSeconds;
        Params.Axis = InParams.Axis;
        Params.SettleSeconds = InParams.SettleSeconds;
        Params.RestRotation = utils_scene_node::Get_Offset_Rotation(InNode);
        Params.CatchAngleDegrees = InParams.CatchAngleDegrees;

        auto State = FMars_Fragment_Oscillator();
        State.IsRunning = InParams.StartRunning;
        State.Envelope = InParams.StartRunning ? 1.0f : 0.0f;

        // A braked swing that starts stopped starts caught, on the way out to its catch angle.
        if (InParams.StartRunning == false && InParams.CatchAngleDegrees.IsSet())
        {
            const auto CatchAngle = InParams.CatchAngleDegrees.GetValue();
            const auto Ratio = InParams.AmplitudeDegrees > KINDA_SMALL_NUMBER ? CatchAngle / InParams.AmplitudeDegrees : 0.0f;
            const float64 Phase = Math::Asin(Math::Clamp(Ratio, -1.0f, 1.0f));
            State.IsCaught = true;
            State.Envelope = 1.0f;
            State.Time = float32(Get_FirstPhaseAfter(Phase, -1.0) / (2.0 * PI) * InParams.PeriodSeconds);

            utils_scene_node::Request_UpdateOffset_Rotation(InNode,
                Params.RestRotation + Make_SwingRotation(Params.Axis, CatchAngle), ECk_RelativeAbsolute::Absolute);
        }

        InNode.Add_Fragment(FMars_Feature_Oscillator());
        InNode.Add_Fragment(Params);
        InNode.Add_Fragment(State);
        return InNode.As_Oscillator();
    }

    // The first phase in (InFromPhase, InToPhase] at which a swing of InAmplitude passes InAngle, in radians and unwrapped
    // (it may exceed 2 pi); unset when it does not pass it. A swing passes an angle twice per period (out and back) and an
    // extreme once.
    TOptional<float64> Find_CatchPhase(FVector2D InPhaseRange, float32 InAmplitude, float32 InAngle)
    {
        if (InAmplitude <= KINDA_SMALL_NUMBER)
        { return TOptional<float64>(); }

        const float64 Rising = Math::Asin(Math::Clamp(InAngle / InAmplitude, -1.0f, 1.0f));
        const auto Earliest = Math::Min(
            Get_FirstPhaseAfter(Rising, InPhaseRange.X),
            Get_FirstPhaseAfter(PI - Rising, InPhaseRange.X));

        if (Earliest > InPhaseRange.Y)
        { return TOptional<float64>(); }

        return TOptional<float64>(Earliest);
    }

    // The first phase equal to InPhase modulo 2 pi that lies after InAfter.
    float64 Get_FirstPhaseAfter(float64 InPhase, float64 InAfter)
    {
        auto Phase = Math::Fmod(InPhase, 2.0 * PI);
        if (Phase < 0.0)
        { Phase += 2.0 * PI; }

        while (Phase <= InAfter)
        { Phase += 2.0 * PI; }

        return Phase;
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

mixin bool Get_IsCaught(const FCk_Handle_Oscillator& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Oscillator).IsCaught;
}

// The swing angle the node shows now, on top of its rest rotation.
mixin float32 Get_Angle(const FCk_Handle_Oscillator& Self)
{
    const auto& Params = Self.Get_Fragment(FMars_Fragment_Oscillator_Params);
    const auto& State = Self.Get_Fragment(FMars_Fragment_Oscillator);
    if (Params.PeriodSeconds <= KINDA_SMALL_NUMBER)
    { return 0.0f; }

    return Params.AmplitudeDegrees * State.Envelope * float32(Math::Sin(2.0 * PI * State.Time / Params.PeriodSeconds));
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
