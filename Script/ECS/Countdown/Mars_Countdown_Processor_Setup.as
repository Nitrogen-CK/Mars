// The link: a countdown consumes rising edges from the MechanismSink on its own entity (each one charges it) and drives the
// MechanismSource on that entity (asserted while charged). With HoldWhilePowered the sink's power also holds it full.
class UMars_Processor_Countdown_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Countdown_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Countdown);
        Query.Require(FMars_Tag_Countdown_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Countdown = InHandle.As_Countdown();

        auto Sink = InHandle.As_MechanismSink(ECk_SanityCheck::UnChecked);
        ck::EnsureIfNot(ck::IsValid(Sink) || Countdown.Get_HoldWhilePowered() == false,
            f"[Countdown] [{Countdown.ToString()}] has HoldWhilePowered but no MechanismSink on its entity; nothing will ever hold it");

        if (ck::IsValid(Sink))
        {
            Sink.BindTo_OnInputRose(FMars_Delegate_MechanismSink_OnInputRose(this, n"OnSinkInputRose"));

            if (Countdown.Get_HoldWhilePowered())
            {
                Sink.BindTo_OnPoweredChanged(FMars_Delegate_MechanismSink_OnPoweredChanged(this, n"OnSinkPoweredChanged"),
                    ECk_Signal_BindingPolicy::FireIfPayloadInFlight);
            }
        }

        auto Source = InHandle.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Source))
        {
            Countdown.BindTo_OnRemainingChanged(FMars_Delegate_Countdown_OnRemainingChanged(this, n"OnRemainingChanged"));
            Source.Request_SetOutput(utils_mechanism_source::Make_SetOutput(Get_SourceOutput(Countdown.Get_Remaining())));
        }

        Countdown.Request_TryRemove(FMars_Tag_Countdown_NeedsSetup);
    }

    // The source asserts while any step is charged.
    private EMars_MechanismSource_Output Get_SourceOutput(int32 InRemaining) const
    {
        return InRemaining > 0 ? EMars_MechanismSource_Output::Asserted : EMars_MechanismSource_Output::Deasserted;
    }

    UFUNCTION()
    private void OnSinkInputRose(FCk_Handle_MechanismSink InSink, FGameplayTag InChannel)
    {
        auto Countdown = InSink.As_Countdown();
        Countdown.Request_Charge();
    }

    UFUNCTION()
    private void OnSinkPoweredChanged(FCk_Handle_MechanismSink InSink, EMars_MechanismSink_Power InPower)
    {
        auto Countdown = InSink.As_Countdown();
        const auto Hold = InPower == EMars_MechanismSink_Power::Powered ? EMars_Countdown_Hold::Held : EMars_Countdown_Hold::Released;
        Countdown.Request_SetHeld(FMars_Request_Countdown_SetHeld(Hold));
    }

    UFUNCTION()
    private void OnRemainingChanged(FCk_Handle_Countdown InCountdown, int32 InRemaining)
    {
        auto Source = InCountdown.As_MechanismSource();
        Source.Request_SetOutput(utils_mechanism_source::Make_SetOutput(Get_SourceOutput(InRemaining)));
    }
}
