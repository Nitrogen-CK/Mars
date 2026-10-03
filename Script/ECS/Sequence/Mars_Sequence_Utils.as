namespace utils_sequence
{
    // Expects the entity to also carry a MechanismSink whose input channels cover every step (edges in) and, optionally, a
    // MechanismSource (output); the setup processor links them. A spec that fails Validate() ensures and adds nothing.
    FCk_Handle_Sequence Add(FCk_Handle& InHandle, FMars_Sequence_Spec InParams)
    {
        const auto Validation = InParams.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Sequence] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Sequence(); }

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
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

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
    Requests.ResetRequests.Add(FMars_Request_Sequence_Reset());
}

mixin void Request_Input(FCk_Handle_Sequence& Self, const FMars_Request_Sequence_Input& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Sequence_Requests);
    Requests.InputRequests.Add(InRequest);
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
