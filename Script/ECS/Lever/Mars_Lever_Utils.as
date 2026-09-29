namespace utils_lever
{
    FCk_Handle_Lever Add(FCk_Handle_Transform& InOwner, FMars_Lever_Spec InParams)
    {
        auto Params = FMars_Fragment_Lever_Params();
        Params.PulledAngle = InParams.PulledAngle;
        Params.MoveDuration = InParams.MoveDuration;

        const auto StartPitch = InParams.StartPulled ? InParams.PulledAngle : 0.0f;

        auto State = FMars_Fragment_Lever();
        State.IsPulled = InParams.StartPulled;
        State.HandleNode = utils_scene_node::Create(InOwner, FTransform(FRotator(StartPitch, 0.0, 0.0), FVector::ZeroVector));

        InOwner.Add_Fragment(FMars_Feature_Lever());
        InOwner.Add_Fragment(Params);
        InOwner.Add_Fragment(State);
        InOwner.Add_Fragment(FMars_Tag_Lever_NeedsSetup());
        return InOwner.As_Lever();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin bool Get_IsPulled(const FCk_Handle_Lever& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Lever).IsPulled;
}

mixin FCk_Handle_SceneNode Get_HandleNode(const FCk_Handle_Lever& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Lever).HandleNode;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_SetPulled(FCk_Handle_Lever& Self, bool InPulled)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Lever_Requests);
    Requests.SetPulledRequest = FMars_Request_Lever_SetPulled(InPulled);
}

mixin void Request_Toggle(FCk_Handle_Lever& Self)
{
    const auto IsPulled = Self.Get_IsPulled();
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Lever_Requests);

    // Toggle against a pending request, so two toggles in one frame cancel out instead of collapsing into one.
    auto Current = IsPulled;
    if (Requests.SetPulledRequest.IsSet())
    { Current = Requests.SetPulledRequest.GetValue().Pulled; }

    Requests.SetPulledRequest = FMars_Request_Lever_SetPulled(Current == false);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnPulledChanged(FCk_Handle_Lever& Self, FMars_Delegate_Lever_OnPulledChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Lever_Signals);
    Fragment.OnPulledChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPulledChanged(FCk_Handle_Lever& Self, FMars_Delegate_Lever_OnPulledChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Lever_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Lever_Signals).OnPulledChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
