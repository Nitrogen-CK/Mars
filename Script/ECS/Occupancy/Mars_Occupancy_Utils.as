namespace utils_occupancy
{
    FCk_Handle_Occupancy Add(
        FCk_Handle& InHandle,
        FMars_Occupancy_Spec InParams,
        FCk_Handle_Trigger InTrigger,
        FCk_Handle_Mover InMover = FCk_Handle_Mover())
    {
        auto Params = FMars_Fragment_Occupancy_Params();
        Params.RequiredCount = Math::Max(InParams.RequiredCount, 1);
        Params.ReleaseDelaySeconds = InParams.ReleaseDelaySeconds;

        auto State = FMars_Fragment_Occupancy();
        State.Trigger = InTrigger;
        State.Mover = InMover;

        InHandle.Add_Fragment(FMars_Feature_Occupancy());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        InHandle.Add_Fragment(FMars_Tag_Occupancy_NeedsSetup());
        auto Occupancy = InHandle.As_Occupancy();

        if (ck::IsValid(InTrigger))
        {
            auto Trigger = InTrigger;
            Trigger.AddOrGet_Fragment(FMars_Fragment_Occupancy_TriggerLink).Occupancies.Add(Occupancy);
        }

        return Occupancy;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin int32 Get_Count(const FCk_Handle_Occupancy& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Occupancy).Count;
}

mixin int32 Get_RequiredCount(const FCk_Handle_Occupancy& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Occupancy_Params).RequiredCount;
}

mixin bool Get_IsActive(const FCk_Handle_Occupancy& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Occupancy).IsActive;
}

mixin FCk_Handle_Trigger Get_Trigger(const FCk_Handle_Occupancy& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Occupancy).Trigger;
}

mixin FCk_Handle_Mover Get_Mover(const FCk_Handle_Occupancy& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Occupancy).Mover;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnCountChanged(FCk_Handle_Occupancy& Self, FMars_Delegate_Occupancy_OnCountChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Occupancy_Signals);
    Fragment.OnCountChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnCountChanged(FCk_Handle_Occupancy& Self, FMars_Delegate_Occupancy_OnCountChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Occupancy_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Occupancy_Signals).OnCountChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnActiveChanged(FCk_Handle_Occupancy& Self, FMars_Delegate_Occupancy_OnActiveChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Occupancy_Signals);
    Fragment.OnActiveChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnActiveChanged(FCk_Handle_Occupancy& Self, FMars_Delegate_Occupancy_OnActiveChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Occupancy_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Occupancy_Signals).OnActiveChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
