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

        // Swap-and-pop - InRequests is dead past this line; a request enqueued by a listener survives to next pass.
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
        if (Params.Latch && InSinkComp.IsPowered)
        { Powered = true; }

        if (InSinkComp.IsPowered == Powered)
        { return; }

        InSinkComp.IsPowered = Powered;

        if (Self.Has_Fragment(FMars_Fragment_MechanismSink_Signals))
        { Self.Get_Fragment(FMars_Fragment_MechanismSink_Signals).OnPoweredChanged.Broadcast(Self, Powered); }
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
