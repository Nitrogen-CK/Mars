// Swings the node. Running eases the envelope to full amplitude; stopped eases it to rest, unless a catch angle is set:
// then the swing carries on at full amplitude until it passes that angle and holds there (Time and Envelope frozen, so a
// restart continues the swing from the catch without a jump).
class UMars_Processor_Oscillator_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Oscillator);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Oscillator& InState)
    {
        if (InState.State == EMars_Oscillator_State::Caught)
        { return; }

        const auto IsRunning = InState.State == EMars_Oscillator_State::Running;
        const auto& Params = InHandle.Get_Fragment(FMars_Fragment_Oscillator_Params);
        const auto IsBraking = IsRunning == false && Params.CatchAngleDegrees.IsSet();

        const auto WasAtRest = InState.Envelope <= 0.0f;
        if (IsRunning == false && IsBraking == false && WasAtRest)
        { return; }

        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());

        const auto TargetEnvelope = (IsRunning || IsBraking) ? 1.0f : 0.0f;
        if (Params.SettleSeconds <= KINDA_SMALL_NUMBER)
        { InState.Envelope = TargetEnvelope; }
        else
        {
            const auto MaxStep = DeltaSeconds / Params.SettleSeconds;
            InState.Envelope += Math::Clamp(TargetEnvelope - InState.Envelope, -MaxStep, MaxStep);
        }

        const auto PreviousTime = InState.Time;
        InState.Time = float32(Math::Fmod(InState.Time + DeltaSeconds, Params.PeriodSeconds));

        if (IsBraking)
        {
            const auto RadiansPerSecond = 2.0 * PI / Params.PeriodSeconds;
            const auto PhaseRange = FVector2D(PreviousTime * RadiansPerSecond, (PreviousTime + DeltaSeconds) * RadiansPerSecond);
            const auto CatchPhase = utils_oscillator::Find_CatchPhase(PhaseRange,
                Params.AmplitudeDegrees * InState.Envelope, Params.CatchAngleDegrees.GetValue());

            if (CatchPhase.IsSet())
            {
                InState.Time = float32(Math::Fmod(CatchPhase.GetValue() / RadiansPerSecond, Params.PeriodSeconds));
                InState.State = EMars_Oscillator_State::Caught;
            }
        }

        const auto Angle = Params.AmplitudeDegrees * InState.Envelope * float32(Math::Sin(2.0 * PI * InState.Time / Params.PeriodSeconds));

        auto Node = InHandle.As_SceneNode();
        utils_scene_node::Request_UpdateOffset_Rotation(Node,
            utils_oscillator::Make_NodeRotation(Params.RestRotation, Params.Axis, Angle),
            ECk_RelativeAbsolute::Absolute);
    }
}
