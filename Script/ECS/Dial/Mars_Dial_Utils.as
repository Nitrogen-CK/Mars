namespace utils_dial
{
    // A spec that fails Validate() ensures and adds nothing.
    FCk_Handle_Dial Add(FCk_Handle& InHandle, FMars_Dial_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Dial] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Dial(); }

        auto Params = FMars_Fragment_Dial_Params();
        Params.Positions = InSpec.Positions;

        auto State = FMars_Fragment_Dial();
        State.Index = InSpec.StartIndex;

        InHandle.Add_Fragment(FMars_Feature_Dial());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        return InHandle.As_Dial();
    }

    // InIndex moved by InDetents and wrapped into [0, InPositions).
    int32 Get_Wrapped(int32 InIndex, int32 InDetents, int32 InPositions)
    {
        const auto Moved = (InIndex + InDetents) % InPositions;
        return Moved < 0 ? Moved + InPositions : Moved;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin int32 Get_Index(const FCk_Handle_Dial& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Dial).Index;
}

mixin int32 Get_Positions(const FCk_Handle_Dial& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Dial_Params).Positions;
}

mixin bool Get_IsLocked(const FCk_Handle_Dial& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Dial).Locked;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Step(FCk_Handle_Dial& Self, const FMars_Request_Dial_Step& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Dial_Requests);
    Requests.StepRequests.Add(InRequest);
}

mixin void Request_SetLocked(FCk_Handle_Dial& Self, const FMars_Request_Dial_SetLocked& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Dial_Requests);
    Requests.LockRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnIndexChanged(FCk_Handle_Dial& Self, FMars_Delegate_Dial_OnIndexChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Dial_Signals);
    Fragment.OnIndexChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnIndexChanged(FCk_Handle_Dial& Self, FMars_Delegate_Dial_OnIndexChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Dial_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Dial_Signals).OnIndexChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
