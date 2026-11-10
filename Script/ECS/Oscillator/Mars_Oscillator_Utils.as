namespace utils_oscillator
{
    // A spec that fails Validate() ensures and adds nothing.
    FCk_Handle_Oscillator Add(FCk_Handle_SceneNode& InNode, FMars_Oscillator_Spec InParams)
    {
        const auto Validation = InParams.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Oscillator] [{InNode.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Oscillator(); }

        auto Params = FMars_Fragment_Oscillator_Params();
        Params.AmplitudeDegrees = InParams.AmplitudeDegrees;
        Params.PeriodSeconds = InParams.PeriodSeconds;
        Params.Axis = InParams.Axis;
        Params.SettleSeconds = InParams.SettleSeconds;
        Params.RestRotation = utils_scene_node::Get_Offset_Rotation(InNode);
        Params.CatchAngleDegrees = InParams.CatchAngleDegrees;

        auto State = FMars_Fragment_Oscillator();
        State.State = InParams.StartRunning ? EMars_Oscillator_State::Running : EMars_Oscillator_State::Stopped;
        State.Envelope = InParams.StartRunning ? 1.0f : 0.0f;

        // A braked swing that starts stopped starts caught, on the way out to its catch angle.
        if (InParams.StartRunning == false && InParams.CatchAngleDegrees.IsSet())
        {
            const auto CatchAngle = InParams.CatchAngleDegrees.GetValue();
            const auto Ratio = InParams.AmplitudeDegrees > KINDA_SMALL_NUMBER ? CatchAngle / InParams.AmplitudeDegrees : 0.0f;
            const float64 Phase = Math::Asin(Math::Clamp(Ratio, -1.0f, 1.0f));
            State.State = EMars_Oscillator_State::Caught;
            State.Envelope = 1.0f;
            State.Time = float32(Get_FirstPhaseAfter(Phase, -1.0) / (2.0 * PI) * InParams.PeriodSeconds);

            utils_scene_node::Request_UpdateOffset_Rotation(InNode,
                Make_NodeRotation(Params.RestRotation, Params.Axis, CatchAngle), ECk_RelativeAbsolute::Absolute);
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

    // The node's offset rotation for a swing angle: the swing turns about the axis of the rest frame, so the rest
    // rotation is composed with it (rest x swing), not added to it per component.
    FRotator Make_NodeRotation(FRotator InRestRotation, EMars_Oscillator_Axis InAxis, float32 InAngleDegrees)
    {
        return (FQuat(InRestRotation) * FQuat(Make_SwingRotation(InAxis, InAngleDegrees))).Rotator();
    }

    // The swing angle on top of the rest rotation, in degrees.
    float32 Get_SwingAngle(const FMars_Fragment_Oscillator_Params& InParams, const FMars_Fragment_Oscillator& InState)
    {
        return InParams.AmplitudeDegrees * InState.Envelope * float32(Math::Sin(2.0 * PI * InState.Time / InParams.PeriodSeconds));
    }

    // InTime folded into [0, InPeriod).
    float32 Wrap_Time(float32 InTime, float32 InPeriod)
    {
        auto Time = float32(Math::Fmod(InTime, InPeriod));
        if (Time < 0.0f)
        { Time += InPeriod; }

        return Time;
    }

    // The shortest signed time from InActual to InExpected on a swing of InPeriod, in (-InPeriod / 2, InPeriod / 2].
    float32 Get_PhaseError(float32 InExpected, float32 InActual, float32 InPeriod)
    {
        auto Error = Wrap_Time(InExpected - InActual, InPeriod);
        if (Error > InPeriod * 0.5f)
        { Error -= InPeriod; }

        return Error;
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
    return Self.Get_Fragment(FMars_Fragment_Oscillator).State == EMars_Oscillator_State::Running;
}

mixin bool Get_IsCaught(const FCk_Handle_Oscillator& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Oscillator).State == EMars_Oscillator_State::Caught;
}

// Running, or stopped but not yet at rest: easing out, or braking toward its catch angle.
mixin bool Get_IsSwinging(const FCk_Handle_Oscillator& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Oscillator);
    if (State.State != EMars_Oscillator_State::Stopped)
    { return State.State == EMars_Oscillator_State::Running; }

    return State.Envelope > 0.0f || Self.Get_Fragment(FMars_Fragment_Oscillator_Params).CatchAngleDegrees.IsSet();
}

mixin FMars_Oscillator_Sample Get_Sample(const FCk_Handle_Oscillator& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Oscillator);
    return FMars_Oscillator_Sample(State.State, State.Time, State.Envelope);
}

// InFrom as this oscillator's Tick would carry it InSeconds on, with no state change: a swing easing out stops advancing
// once it is at rest, as the Tick does. It does not look for a catch inside the window: the authority's own catch arrives
// as a Caught sample.
mixin FMars_Oscillator_Sample Get_Advanced(const FCk_Handle_Oscillator& Self, FMars_Oscillator_Sample InFrom, float32 InSeconds)
{
    if (InFrom.State == EMars_Oscillator_State::Caught)
    { return InFrom; }

    const auto& Params = Self.Get_Fragment(FMars_Fragment_Oscillator_Params);

    const auto IsBraking = InFrom.State == EMars_Oscillator_State::Stopped && Params.CatchAngleDegrees.IsSet();
    const auto IsEasingOut = InFrom.State == EMars_Oscillator_State::Stopped && IsBraking == false;
    const auto Seconds = IsEasingOut ? Math::Min(InSeconds, InFrom.Envelope * Params.SettleSeconds) : InSeconds;

    auto Result = InFrom;
    Result.Time = utils_oscillator::Wrap_Time(InFrom.Time + Seconds, Params.PeriodSeconds);

    const auto TargetEnvelope = (InFrom.State == EMars_Oscillator_State::Running || IsBraking) ? 1.0f : 0.0f;
    if (Params.SettleSeconds <= KINDA_SMALL_NUMBER)
    { Result.Envelope = TargetEnvelope; }
    else
    {
        const auto MaxStep = Seconds / Params.SettleSeconds;
        Result.Envelope = Math::Clamp(InFrom.Envelope + Math::Clamp(TargetEnvelope - InFrom.Envelope, -MaxStep, MaxStep), 0.0f, 1.0f);
    }

    return Result;
}

// The swing angle the node shows now, on top of its rest rotation.
mixin float32 Get_Angle(const FCk_Handle_Oscillator& Self)
{
    return utils_oscillator::Get_SwingAngle(Self.Get_Fragment(FMars_Fragment_Oscillator_Params), Self.Get_Fragment(FMars_Fragment_Oscillator));
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_SetRunning(FCk_Handle_Oscillator& Self, const FMars_Request_Oscillator_SetRunning& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Oscillator_Requests);
    Requests.SetRunningRequests.Add(InRequest);
}

mixin void Request_Align(FCk_Handle_Oscillator& Self, const FMars_Request_Oscillator_Align& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Oscillator_Requests);
    Requests.AlignRequests.Add(InRequest);
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

mixin void BindTo_OnCameToRest(FCk_Handle_Oscillator& Self, FMars_Delegate_Oscillator_OnCameToRest InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Oscillator_Signals);
    Fragment.OnCameToRest.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnCameToRest(FCk_Handle_Oscillator& Self, FMars_Delegate_Oscillator_OnCameToRest InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Oscillator_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Oscillator_Signals).OnCameToRest.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
