namespace utils_held_item_use
{
    // Requires utils_held_item on the same entity: every request reads the held item from it.
    FCk_Handle_HeldItemUse Add(FCk_Handle& InPlayer)
    {
        InPlayer.Add_Fragment(FMars_Feature_HeldItemUse());
        InPlayer.Add_Fragment(FMars_Fragment_HeldItemUse());
        return InPlayer.As_HeldItemUse();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

// Invalid while the held item has no UseAction trait.
mixin FCk_Handle_Interactable Get_CurrentInteractable(const FCk_Handle_HeldItemUse& Self)
{
    return Self.Get_Fragment(FMars_Fragment_HeldItemUse).CurrentInteractable;
}

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
