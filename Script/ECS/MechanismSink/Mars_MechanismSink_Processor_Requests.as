class UMars_Processor_MechanismSink_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_MechanismSink_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_MechanismSink);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_MechanismSink_Requests& InRequests,
                       FMars_Fragment_MechanismSink& InSinkComp)
    {
        auto Self = InHandle.As_MechanismSink();

        const auto SetChannelInputRequests = InRequests.SetChannelInputRequests;
        const auto NotifyInputEdgeRequests = InRequests.NotifyInputEdgeRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_MechanismSink_Requests);

        for (const auto& Request : SetChannelInputRequests)
        {
            for (int32 Index = 0; Index < InSinkComp.Inputs.Num(); ++Index)
            {
                if (InSinkComp.Inputs[Index].Channel != Request.Channel)
                { continue; }

                InSinkComp.Inputs[Index].AssertedCount = Request.AssertedCount;
                InSinkComp.Inputs[Index].TotalCount = Request.TotalCount;
            }
        }

        const auto& Params = Self.Get_Fragment(FMars_Fragment_MechanismSink_Params);
        auto Powered = Evaluate_Rule(Params.Rule, InSinkComp.Inputs);
        if (Params.Latch && InSinkComp.Power == EMars_MechanismSink_Power::Powered)
        { Powered = true; }

        const auto Power = Powered ? EMars_MechanismSink_Power::Powered : EMars_MechanismSink_Power::Unpowered;

        // The first evaluation broadcasts even when unpowered: link setups wait for it instead of reading a default.
        const auto FirstEvaluation = InSinkComp.Power == EMars_MechanismSink_Power::Unevaluated && SetChannelInputRequests.Num() > 0;
        if (FirstEvaluation || (InSinkComp.Power != EMars_MechanismSink_Power::Unevaluated && InSinkComp.Power != Power))
        {
            InSinkComp.Power = Power;

            if (Self.Has_Fragment(FMars_Fragment_MechanismSink_Signals))
            { Self.Get_Fragment(FMars_Fragment_MechanismSink_Signals).OnPoweredChanged.Broadcast(Self, Power); }
        }

        if (NotifyInputEdgeRequests.Num() == 0 || Self.Has_Fragment(FMars_Fragment_MechanismSink_Signals) == false)
        { return; }

        for (const auto& Edge : NotifyInputEdgeRequests)
        {
            // Fetched per edge: a listener binding a signal on another entity can reallocate the signals storage.
            Self.Get_Fragment(FMars_Fragment_MechanismSink_Signals).OnInputEdge.Broadcast(Self, Edge.Channel, Edge.Output);
        }
    }

    private bool Evaluate_Rule(EMars_MechanismSink_Rule InRule, const TArray<FMars_MechanismSink_ChannelInput>& InInputs)
    {
        if (InInputs.Num() == 0)
        { return false; }

        if (InRule == EMars_MechanismSink_Rule::AnyChannel)
        {
            for (const auto& Input : InInputs)
            {
                if (Input.AssertedCount > 0)
                { return true; }
            }
            return false;
        }

        if (InRule == EMars_MechanismSink_Rule::AllChannels)
        {
            for (const auto& Input : InInputs)
            {
                if (Input.AssertedCount <= 0)
                { return false; }
            }
            return true;
        }

        int32 TotalSources = 0;
        for (const auto& Input : InInputs)
        {
            if (Input.AssertedCount < Input.TotalCount)
            { return false; }
            TotalSources += Input.TotalCount;
        }
        return TotalSources > 0;
    }
}
