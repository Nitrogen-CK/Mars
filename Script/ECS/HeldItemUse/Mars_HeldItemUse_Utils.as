namespace utils_held_item_use
{
    // Every request reads the held item, so HeldItem must be composed first.
    FCk_Handle_HeldItemUse Add(FCk_Handle& InPlayer)
    {
        if (ck::EnsureIfNot(InPlayer.Is_HeldItem(), f"[HeldItemUse] [{InPlayer.ToString()}] needs HeldItem before HeldItemUse"))
        { return FCk_Handle_HeldItemUse(); }

        InPlayer.Add_Fragment(FMars_Feature_HeldItemUse());
        InPlayer.Add_Fragment(FMars_Fragment_HeldItemUse());
        return InPlayer.As_HeldItemUse();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin bool Get_ThrowArmed(const FCk_Handle_HeldItemUse& Self)
{
    return Self.Get_Fragment(FMars_Fragment_HeldItemUse).ThrowArmed;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_RefreshFromHeldItem(FCk_Handle_HeldItemUse& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_HeldItemUse_Requests);
    Requests.RefreshFromHeldItemRequests.Add(FMars_Request_HeldItemUse_RefreshFromHeldItem());
}

mixin void Request_Drop(FCk_Handle_HeldItemUse& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_HeldItemUse_Requests);
    Requests.DropRequests.Add(FMars_Request_HeldItemUse_Drop());
}

mixin void Request_Throw(FCk_Handle_HeldItemUse& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_HeldItemUse_Requests);
    Requests.ThrowRequests.Add(FMars_Request_HeldItemUse_Throw());
}

// HUD-only (see FMars_Fragment_HeldItemUse::ThrowArmed); the drain broadcasts OnThrowArmedChanged on change.
mixin void Request_SetThrowArmed(FCk_Handle_HeldItemUse& Self, const FMars_Request_HeldItemUse_SetThrowArmed& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_HeldItemUse_Requests);
    Requests.SetThrowArmedRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnThrowArmedChanged(FCk_Handle_HeldItemUse& Self, FMars_Delegate_HeldItemUse_OnThrowArmedChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_HeldItemUse_Signals);
    Fragment.OnThrowArmedChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnThrowArmedChanged(FCk_Handle_HeldItemUse& Self, FMars_Delegate_HeldItemUse_OnThrowArmedChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_HeldItemUse_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_HeldItemUse_Signals).OnThrowArmedChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnItemLaunched(FCk_Handle_HeldItemUse& Self, FMars_Delegate_HeldItemUse_OnItemLaunched InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_HeldItemUse_Signals);
    Fragment.OnItemLaunched.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnItemLaunched(FCk_Handle_HeldItemUse& Self, FMars_Delegate_HeldItemUse_OnItemLaunched InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_HeldItemUse_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_HeldItemUse_Signals).OnItemLaunched.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
