// Ticks only off authority: the Mirror exists only there (the authority's setup removes it). Keeps this machine's swing
// within constants_pendulum::k_PhaseToleranceSeconds of the authority's anchored phase, re-aligning while the server
// clock estimate converges. It never changes the run state: state changes arrive only as anchors, so a client braking
// toward its catch is never pulled out of a local catch it reached a frame before the authority's.
class UMars_Processor_Pendulum_PhaseLock : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Pendulum);
        Query.Require(FMars_Fragment_Pendulum_Mirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        // The authority's Mirror survives until its setup's removal lands.
        if (utils_net::Get_HasAuthority(InHandle))
        { return; }

        auto Pendulum = InHandle.As_Pendulum();
        if (Pendulum.Get_Fragment(FMars_Fragment_Pendulum).Anchors == 0)
        { return; }

        auto Oscillator = Pendulum.Get_Oscillator();
        const auto Expected = Pendulum.Get_AnchoredSample();
        const auto Actual = Oscillator.Get_Sample();

        const auto BothRunning = Expected.State == EMars_Oscillator_State::Running && Actual.State == EMars_Oscillator_State::Running;
        const auto BothStopped = Expected.State == EMars_Oscillator_State::Stopped && Actual.State == EMars_Oscillator_State::Stopped;
        if (BothRunning == false && BothStopped == false)
        { return; }

        const auto Period = Oscillator.Get_Fragment(FMars_Fragment_Oscillator_Params).PeriodSeconds;
        const auto Error = utils_oscillator::Get_PhaseError(Expected.Time, Actual.Time, Period);
        if (Math::Abs(Error) <= constants_pendulum::k_PhaseToleranceSeconds)
        { return; }

        Oscillator.Request_Align(FMars_Request_Oscillator_Align(Expected));
    }
}
