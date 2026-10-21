// The Bellkeeper tests' rig: a lock on its own entity with three six-detent dials (all starting at 0) and a vent source
// as its children, the MechanismSink its setup requires (commits on Mechanism.Channel.J), an output source on
// Mechanism.Channel.L, three rewards (Rock, Cog, Ration), and its signals recorded. The vent source asserts
// Mechanism.Channel.K. Nothing in the test map sources J, K or L, and no mechanism driver runs in it: tests feed sink edges
// straight in (Request_NotifyInputEdge) and read sources directly.
UCLASS(Abstract)
class UMars_AutoTestRig_Bellkeeper : UCk_AutoTest_Base
{
    // A poll budget, not a ceiling: edges travel through the world's driver and timers run out.
    protected const int32 k_SlowPolls = 900;
    protected const float32 k_VentPulseSeconds = 0.3f;

    protected FCk_Handle _Entity;
    protected FCk_Handle_Bellkeeper _Bellkeeper;
    protected TArray<FCk_Handle_Dial> _Dials;
    protected FCk_Handle_MechanismSource _VentSource;
    protected FCk_Handle_MechanismSource _OutputSource;
    protected TArray<int32> _FailedRemaining;
    protected int32 _Solved = 0;

    // The answer the rig's lock is built with: no dial starts on it.
    protected TArray<int32> Get_Answer() const
    {
        TArray<int32> Answer;
        Answer.Add(1);
        Answer.Add(2);
        Answer.Add(3);
        return Answer;
    }

    // The dials, vent source and entity a spec needs, without the bellkeeper itself.
    protected FMars_Bellkeeper_Spec Make_Parts(FCk_Handle InHandle)
    {
        _Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);

        _Dials.Reset();
        for (int32 Index = 0; Index < 3; ++Index)
        {
            auto DialEntity = utils_entity_lifetime::Request_CreateEntity(_Entity);
            _Dials.Add(utils_dial::Add(DialEntity, FMars_Dial_Spec()));
        }

        auto VentEntity = utils_entity_lifetime::Request_CreateEntity(_Entity);
        auto VentSpec = FMars_MechanismSource_Spec();
        VentSpec.OutputChannel = GameplayTags::Mechanism_Channel_K;
        _VentSource = utils_mechanism_source::Add(VentEntity, VentSpec);

        auto Spec = FMars_Bellkeeper_Spec();
        Spec.Dials = _Dials;
        Spec.Answer = Get_Answer();
        Spec.Rewards.Add(FMars_Bellkeeper_Reward(utils_held_item::Make_DefinitionSoft(mars_items::Rock()), FTransform(FVector(0.0, -60.0, 50.0))));
        Spec.Rewards.Add(FMars_Bellkeeper_Reward(utils_held_item::Make_DefinitionSoft(mars_items::Cog()), FTransform(FVector(0.0, 0.0, 50.0))));
        Spec.Rewards.Add(FMars_Bellkeeper_Reward(utils_held_item::Make_DefinitionSoft(mars_items::Ration()), FTransform(FVector(0.0, 60.0, 50.0))));
        Spec.VentSource = _VentSource;
        Spec.VentPulseSeconds = k_VentPulseSeconds;
        return Spec;
    }

    protected FCk_Handle_Bellkeeper AddLock(FCk_Handle InHandle)
    {
        const auto Spec = Make_Parts(InHandle);

        auto SinkSpec = FMars_MechanismSink_Spec();
        SinkSpec.InputChannels.Add(GameplayTags::Mechanism_Channel_J);
        SinkSpec.Rule = EMars_MechanismSink_Rule::AnyChannel;
        utils_mechanism_sink::Add(_Entity, SinkSpec);

        auto OutputSpec = FMars_MechanismSource_Spec();
        OutputSpec.OutputChannel = GameplayTags::Mechanism_Channel_L;
        _OutputSource = utils_mechanism_source::Add(_Entity, OutputSpec);

        _Bellkeeper = utils_bellkeeper::Add(_Entity, Spec);
        _Bellkeeper.BindTo_OnCommitFailed(FMars_Delegate_Bellkeeper_OnCommitFailed(this, n"OnRigCommitFailed"));
        _Bellkeeper.BindTo_OnSolved(FMars_Delegate_Bellkeeper_OnSolved(this, n"OnRigSolved"));
        return _Bellkeeper;
    }

    protected void Assert_NothingSourcesTheRigChannels(FCk_Handle InHandle)
    {
        Assert_Equals_Int(utils_mechanism_source::Get_SourcesOn(InHandle, GameplayTags::Mechanism_Channel_J).Num(), 0, "nothing sources J");
        Assert_Equals_Int(utils_mechanism_source::Get_SourcesOn(InHandle, GameplayTags::Mechanism_Channel_K).Num(), 1, "only the rig's vent sources K");
        Assert_Equals_Int(utils_mechanism_source::Get_SourcesOn(InHandle, GameplayTags::Mechanism_Channel_L).Num(), 1, "only the rig's output sources L");
    }

    // Turns each dial forward onto InIndices.
    protected void Request_SetDials(const TArray<int32>& InIndices)
    {
        for (int32 Index = 0; Index < _Dials.Num(); ++Index)
        {
            const auto Detents = InIndices[Index] - _Dials[Index].Get_Index();
            if (Detents != 0)
            { _Dials[Index].Request_Step(FMars_Request_Dial_Step(Detents)); }
        }
    }

    protected TArray<int32> Get_DialIndices() const
    {
        TArray<int32> Indices;
        for (const auto& Dial : _Dials)
        { Indices.Add(Dial.Get_Index()); }

        return Indices;
    }

    // True once the lock and its dials have drained their requests.
    protected bool Get_IsDrained() const
    {
        if (_Bellkeeper.Has_Fragment(FMars_Fragment_Bellkeeper_Requests))
        { return false; }

        for (const auto& Dial : _Dials)
        {
            if (Dial.Has_Fragment(FMars_Fragment_Dial_Requests))
            { return false; }
        }

        return true;
    }

    UFUNCTION()
    private void OnRigCommitFailed(FCk_Handle_Bellkeeper InBellkeeper, int32 InRemainingRewards)
    {
        _FailedRemaining.Add(InRemainingRewards);
    }

    UFUNCTION()
    private void OnRigSolved(FCk_Handle_Bellkeeper InBellkeeper)
    {
        ++_Solved;
    }
}
