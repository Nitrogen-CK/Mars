namespace utils_sequence
{
    // Expects the entity to also carry a MechanismSink whose input channels cover every step (edges in) and a
    // MechanismSource (output); the setup processor links them.
    FCk_Handle_Sequence Add(FCk_Handle& InHandle, FMars_Sequence_Spec InParams)
    {
        auto Params = FMars_Fragment_Sequence_Params();
        Params.Steps = InParams.Steps;
        Params.ResetOnWrongInput = InParams.ResetOnWrongInput;
        Params.StepTimeoutSeconds = InParams.StepTimeoutSeconds;
        Params.Latch = InParams.Latch;
        Params.OutputPulseSeconds = InParams.OutputPulseSeconds;

        InHandle.Add_Fragment(FMars_Feature_Sequence());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(FMars_Fragment_Sequence());
        InHandle.Add_Fragment(FMars_Tag_Sequence_NeedsSetup());
        return InHandle.As_Sequence();
    }

    // Immediate, not through Request_Reset: after a wrong input, a later edge in the same sink drain must be judged
    // against Progress 0. Shared by the sequence's request and setup processors.
    void Reset(FCk_Handle_Sequence& InSequence)
    {
        auto& State = InSequence.Get_Fragment(FMars_Fragment_Sequence);
        DestroyStepTimer(State);

        if (State.Progress == 0 && State.IsComplete == false)
        { return; }

        State.Progress = 0;
        State.IsComplete = false;

        auto Source = InSequence.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Source))
        { Source.Request_SetAsserted(false); }

        if (InSequence.Has_Fragment(FMars_Fragment_Sequence_Signals))
        { InSequence.Get_Fragment(FMars_Fragment_Sequence_Signals).OnReset.Broadcast(InSequence); }
    }

    void DestroyStepTimer(FMars_Fragment_Sequence& InState)
    {
        if (ck::IsValid(InState.StepTimer))
        { utils_entity_lifetime::Request_DestroyEntity(FCk_Handle(InState.StepTimer)); }

        InState.StepTimer = FCk_Handle_Timer();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin TArray<FGameplayTag> Get_Steps(const FCk_Handle_Sequence& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Sequence_Params).Steps;
}

mixin int32 Get_Progress(const FCk_Handle_Sequence& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Sequence).Progress;
}

mixin bool Get_IsComplete(const FCk_Handle_Sequence& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Sequence).IsComplete;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Reset(FCk_Handle_Sequence& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Sequence_Requests);
    Requests.ResetRequest = FMars_Request_Sequence_Reset();
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnStepAccepted(FCk_Handle_Sequence& Self, FMars_Delegate_Sequence_OnStepAccepted InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Sequence_Signals);
    Fragment.OnStepAccepted.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnStepAccepted(FCk_Handle_Sequence& Self, FMars_Delegate_Sequence_OnStepAccepted InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Sequence_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Sequence_Signals).OnStepAccepted.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnInputRejected(FCk_Handle_Sequence& Self, FMars_Delegate_Sequence_OnInputRejected InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Sequence_Signals);
    Fragment.OnInputRejected.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnInputRejected(FCk_Handle_Sequence& Self, FMars_Delegate_Sequence_OnInputRejected InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Sequence_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Sequence_Signals).OnInputRejected.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnCompleted(FCk_Handle_Sequence& Self, FMars_Delegate_Sequence_OnCompleted InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Sequence_Signals);
    Fragment.OnCompleted.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnCompleted(FCk_Handle_Sequence& Self, FMars_Delegate_Sequence_OnCompleted InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Sequence_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Sequence_Signals).OnCompleted.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnReset(FCk_Handle_Sequence& Self, FMars_Delegate_Sequence_OnReset InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Sequence_Signals);
    Fragment.OnReset.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnReset(FCk_Handle_Sequence& Self, FMars_Delegate_Sequence_OnReset InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Sequence_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Sequence_Signals).OnReset.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
