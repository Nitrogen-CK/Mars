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
// Immediate setters
//--------------------------------------------------------------------------------------------------------------------------

// HUD-only state (see FMars_Fragment_HeldItemUse::ThrowArmed), so it bypasses the request queue.
mixin void Set_ThrowArmed(FCk_Handle_HeldItemUse& Self, bool InThrowArmed)
{
    Self.Get_Fragment(FMars_Fragment_HeldItemUse).ThrowArmed = InThrowArmed;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_RefreshFromHeldItem(FCk_Handle_HeldItemUse& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_HeldItemUse_Requests);
    Requests.RefreshFromHeldItem = TOptional<FMars_Request_HeldItemUse_RefreshFromHeldItem>(FMars_Request_HeldItemUse_RefreshFromHeldItem());
}

mixin void Request_Drop(FCk_Handle_HeldItemUse& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_HeldItemUse_Requests);
    Requests.Drop = TOptional<FMars_Request_HeldItemUse_Drop>(FMars_Request_HeldItemUse_Drop());
}

mixin void Request_Throw(FCk_Handle_HeldItemUse& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_HeldItemUse_Requests);
    Requests.Throw = TOptional<FMars_Request_HeldItemUse_Throw>(FMars_Request_HeldItemUse_Throw());
}
