// The rig's spec validates; an answer of the wrong length, an answer off the ring, a dial starting on its answer, no
// rewards, a reward without a definition and a non-positive pulse are each rejected.
class UMars_AutoTest_Bellkeeper_SpecValidation : UMars_AutoTestRig_Bellkeeper
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the rig's spec validates and each broken copy fails", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Good = Make_Parts(InHandle);
        Assert_True(Good.Validate().IsValid(), "the rig's spec validates");

        auto ShortAnswer = Good;
        ShortAnswer.Answer.RemoveAt(2);
        Assert_False(ShortAnswer.Validate().IsValid(), "an answer shorter than the dials is rejected");

        auto OffRing = Good;
        OffRing.Answer[1] = 6;
        Assert_False(OffRing.Validate().IsValid(), "an answer past the last detent is rejected");

        auto StartsSolved = Good;
        StartsSolved.Answer[0] = 0;
        Assert_False(StartsSolved.Validate().IsValid(), "a dial starting on its answer is rejected");

        auto NoRewards = Good;
        NoRewards.Rewards.Reset();
        Assert_False(NoRewards.Validate().IsValid(), "a lock with nothing to keep is rejected");

        auto NoDefinition = Good;
        NoDefinition.Rewards[1].Definition = TSoftObjectPtr<UCk_InventoryItem_Definition>();
        Assert_False(NoDefinition.Validate().IsValid(), "a reward without a definition is rejected");

        auto NoPulse = Good;
        NoPulse.VentPulseSeconds = 0.0f;
        Assert_False(NoPulse.Validate().IsValid(), "a zero vent pulse is rejected");

        auto NoVent = Good;
        NoVent.VentSource = FCk_Handle_MechanismSource();
        Assert_True(NoVent.Validate().IsValid(), "the vent is optional");

        auto CycleSpec = utils_trap::Make_BurstVentSpec().Cycle;
        auto ForeignEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto ForeignCycle = Good;
        ForeignCycle.VentCycle = utils_cycle::Add(ForeignEntity, CycleSpec);
        Assert_False(ForeignCycle.Validate().IsValid(), "a foreign Cycle is rejected before composition");

        auto ChildEntity = utils_entity_lifetime::Request_CreateEntity(_Entity);
        auto Dedicated = Good;
        Dedicated.VentCycle = utils_cycle::Add(ChildEntity, CycleSpec);
        Assert_True(Dedicated.Validate().IsValid(), "a directly owned dedicated Cycle validates");
        auto SinkSpec = FMars_MechanismSink_Spec();
        SinkSpec.InputChannels.Add(GameplayTags::Mechanism_Channel_K);
        utils_mechanism_sink::Add(ChildEntity, SinkSpec);
        Assert_False(Dedicated.Validate().IsValid(), "a competing sink is rejected before composition");
    }
}
