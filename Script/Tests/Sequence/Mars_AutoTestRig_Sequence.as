// The Sequence tests' rig: a sequence on its own entity with the MechanismSink its setup requires (input channels = the
// steps), an optional MechanismSource output, and its four signals recorded.
UCLASS(Abstract)
class UMars_AutoTestRig_Sequence : UCk_AutoTest_Base
{
    // A poll budget, not a ceiling: edges travel through the world's driver and timers run out.
    protected const int32 k_SlowPolls = 900;

    protected FCk_Handle _Entity;
    protected FCk_Handle_Sequence _Sequence;
    protected TArray<int32> _Accepted;
    protected TArray<FGameplayTag> _Rejected;
    protected int32 _Completed = 0;
    protected int32 _Resets = 0;

    // A latched sequence over InSteps that resets on a wrong input and has no timeout.
    protected FMars_Sequence_Spec Make_Spec(const TArray<FGameplayTag>& InSteps) const
    {
        auto Spec = FMars_Sequence_Spec();
        Spec.Steps = InSteps;
        return Spec;
    }

    protected FCk_Handle_Sequence AddSequence(FCk_Handle InHandle, FMars_Sequence_Spec InSpec)
    {
        _Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);

        auto SinkSpec = FMars_MechanismSink_Spec();
        for (const auto& Step : InSpec.Steps)
        { SinkSpec.InputChannels.AddUnique(Step); }
        SinkSpec.Rule = EMars_MechanismSink_Rule::AnyChannel;
        utils_mechanism_sink::Add(_Entity, SinkSpec);

        _Sequence = utils_sequence::Add(_Entity, InSpec);
        _Sequence.BindTo_OnStepAccepted(FMars_Delegate_Sequence_OnStepAccepted(this, n"OnRigStepAccepted"));
        _Sequence.BindTo_OnInputRejected(FMars_Delegate_Sequence_OnInputRejected(this, n"OnRigInputRejected"));
        _Sequence.BindTo_OnCompleted(FMars_Delegate_Sequence_OnCompleted(this, n"OnRigCompleted"));
        _Sequence.BindTo_OnReset(FMars_Delegate_Sequence_OnReset(this, n"OnRigReset"));
        return _Sequence;
    }

    UFUNCTION()
    private void OnRigStepAccepted(FCk_Handle_Sequence InSequence, int32 InIndex)
    {
        _Accepted.Add(InIndex);
    }

    UFUNCTION()
    private void OnRigInputRejected(FCk_Handle_Sequence InSequence, FGameplayTag InChannel)
    {
        _Rejected.Add(InChannel);
    }

    UFUNCTION()
    private void OnRigCompleted(FCk_Handle_Sequence InSequence)
    {
        ++_Completed;
    }

    UFUNCTION()
    private void OnRigReset(FCk_Handle_Sequence InSequence)
    {
        ++_Resets;
    }
}
