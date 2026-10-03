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
            Sink.BindTo_OnInputEdge(FMars_Delegate_MechanismSink_OnInputEdge(this, n"OnSinkInputEdge"));

            if (Countdown.Get_HoldWhilePowered())
            {
                Sink.BindTo_OnPoweredChanged(FMars_Delegate_MechanismSink_OnPoweredChanged(this, n"OnSinkPoweredChanged"));
                if (Sink.Get_HasEvaluated())
                { Countdown.Request_SetHeld(FMars_Request_Countdown_SetHeld(Sink.Get_IsPowered())); }
            }
        }

        auto Source = InHandle.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Source))
        {
            Countdown.BindTo_OnRemainingChanged(FMars_Delegate_Countdown_OnRemainingChanged(this, n"OnRemainingChanged"));
            Source.Request_SetOutput(Make_SetOutput(Countdown.Get_IsCharged()));
        }

        Countdown.Request_TryRemove(FMars_Tag_Countdown_NeedsSetup);
    }

    private FMars_Request_MechanismSource_SetOutput Make_SetOutput(bool InCharged) const
    {
        return FMars_Request_MechanismSource_SetOutput(InCharged ? EMars_MechanismSource_Output::Asserted : EMars_MechanismSource_Output::Deasserted);
    }

    UFUNCTION()
    private void OnSinkInputEdge(FCk_Handle_MechanismSink InSink, FGameplayTag InChannel, EMars_MechanismSource_Output InOutput)
    {
        if (InOutput == EMars_MechanismSource_Output::Deasserted)
        { return; }

        auto Countdown = InSink.As_Countdown();
        Countdown.Request_Charge();
    }

    UFUNCTION()
    private void OnSinkPoweredChanged(FCk_Handle_MechanismSink InSink, EMars_MechanismSink_Power InPower)
    {
        auto Countdown = InSink.As_Countdown();
        Countdown.Request_SetHeld(FMars_Request_Countdown_SetHeld(InPower == EMars_MechanismSink_Power::Powered));
    }

    UFUNCTION()
    private void OnRemainingChanged(FCk_Handle_Countdown InCountdown, int32 InRemaining)
    {
        auto Source = InCountdown.As_MechanismSource();
        Source.Request_SetOutput(Make_SetOutput(InRemaining > 0));
    }
}
