namespace utils_switch
{
    FCk_Handle_Switch Add(FCk_Handle_Transform& InOwner, FMars_Switch_Spec InParams)
    {
        auto Params = FMars_Fragment_Switch_Params();
        Params.PressOffset = InParams.PressOffset;
        Params.MoveDuration = InParams.MoveDuration;
        Params.HoldSeconds = InParams.HoldSeconds;

        auto State = FMars_Fragment_Switch();
        State.ButtonNode = utils_scene_node::Create(InOwner, FTransform::Identity);

        InOwner.Add_Fragment(FMars_Feature_Switch());
        InOwner.Add_Fragment(Params);
        InOwner.Add_Fragment(State);
        InOwner.Add_Fragment(FMars_Tag_Switch_NeedsSetup());
        return InOwner.As_Switch();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin bool Get_IsPressed(const FCk_Handle_Switch& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Switch).IsPressed;
}

mixin FCk_Handle_SceneNode Get_ButtonNode(const FCk_Handle_Switch& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Switch).ButtonNode;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Press(FCk_Handle_Switch& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Switch_Requests);
    Requests.PressRequest = FMars_Request_Switch_Press();
}

mixin void Request_Release(FCk_Handle_Switch& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Switch_Requests);
    Requests.ReleaseRequest = FMars_Request_Switch_Release();
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnPressedChanged(FCk_Handle_Switch& Self, FMars_Delegate_Switch_OnPressedChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Switch_Signals);
    Fragment.OnPressedChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPressedChanged(FCk_Handle_Switch& Self, FMars_Delegate_Switch_OnPressedChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Switch_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Switch_Signals).OnPressedChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
