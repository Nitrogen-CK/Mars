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

// Launch precedes the inventory transfer; local held-item controls stop on the launch's own frame.
mixin bool Get_IsCurrentItemLaunched(const FCk_Handle_HeldItemUse& Self)
{
    const auto Item = Self.As_HeldItem().Get_CurrentItem();
    return ck::IsValid(Item) && Item == Self.Get_Fragment(FMars_Fragment_HeldItemUse).LaunchedItem;
}

// Unset with empty hands, or when a Persistent item has lost its world item.
mixin TOptional<FMars_HeldItemUse_LaunchSolution> Get_LaunchSolution(const FCk_Handle_HeldItemUse& Self, EMars_LaunchKind InKind)
{
    auto HeldItem = Self.As_HeldItem();
    const auto Item = HeldItem.Get_CurrentItem();
    if (ck::Is_NOT_Valid(Item))
    { return TOptional<FMars_HeldItemUse_LaunchSolution>(); }

    const auto IsThrow = InKind == EMars_LaunchKind::Throw;
    auto Speed = IsThrow ? constants_held_item_use::k_DefaultThrowSpeed : constants_held_item_use::k_DefaultDropSpeed;
    auto AngularVelocityDeg = FVector::ZeroVector;
    if (Item.Has_Throwable())
    {
        const UMars_ItemTrait_Throwable Throwable = Item.Get_Throwable();
        Speed = IsThrow ? Throwable.ThrowSpeed : Throwable.DropSpeed;
        AngularVelocityDeg = Throwable.AngularVelocityDeg;
    }

    const auto View = Self.Get_LaunchView();
    const auto Forward = View.GetRotation().GetForwardVector();

    // Optional: a test carrier has no actor.
    FCk_Handle Carrier = Self;
    auto PawnVelocity = FVector::ZeroVector;
    auto Character = Cast<ACharacter>(ck::ToActor(Carrier, ECk_SanityCheck::UnChecked));
    if (ck::IsValid(Character))
    { PawnVelocity = Character.GetVelocity(); }

    auto Solution = FMars_HeldItemUse_LaunchSolution();
    Solution.LinearVelocity = Forward * Speed + PawnVelocity;
    Solution.AngularVelocityDeg = AngularVelocityDeg;

    if (Item.Has_PersistentWorldItem())
    {
        const auto WorldItem = Item.Get_PersistentWorldItem();
        if (ck::Is_NOT_Valid(WorldItem))
        { return TOptional<FMars_HeldItemUse_LaunchSolution>(); }

        FCk_Handle WorldItemEntity = WorldItem;
        const auto Mounted = utils_transform::Get_EntityCurrentTransform(WorldItemEntity.As_Transform());
        Solution.Origin = FTransform(Mounted.Rotator(), Mounted.GetLocation());
        return TOptional<FMars_HeldItemUse_LaunchSolution>(Solution);
    }

    auto Origin = FTransform(View.Rotator(), View.GetLocation() + Forward * constants_held_item_use::k_NoHandSpawnDistance);
    auto Hand = HeldItem.Get_HandAttachPoint();
    if (ck::IsValid(Hand))
    { Origin = utils_transform::Get_EntityCurrentTransform(Hand); }

    Solution.Origin = FTransform(Origin.Rotator(), Origin.GetLocation());
    return TOptional<FMars_HeldItemUse_LaunchSolution>(Solution);
}

// The carrier's view; a carrier without a PlayerViewpoint launches from its own transform.
mixin FTransform Get_LaunchView(const FCk_Handle_HeldItemUse& Self)
{
    FCk_Handle Carrier = Self;
    const auto Viewpoint = Carrier.As_PlayerViewpoint(ECk_SanityCheck::UnChecked);
    if (ck::IsValid(Viewpoint))
    { return utils_transform::Get_EntityCurrentTransform(Viewpoint.Get_Viewpoint()); }

    return utils_transform::Get_EntityCurrentTransform(Carrier.As_Transform());
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_RefreshFromHeldItem(FCk_Handle_HeldItemUse& Self, const FMars_Request_HeldItemUse_RefreshFromHeldItem& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_HeldItemUse_Requests);
    Requests.RefreshFromHeldItemRequests.Add(InRequest);
}

mixin void Request_Drop(FCk_Handle_HeldItemUse& Self, const FMars_Request_HeldItemUse_Drop& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_HeldItemUse_Requests);
    Requests.DropRequests.Add(InRequest);
}

mixin void Request_Throw(FCk_Handle_HeldItemUse& Self, const FMars_Request_HeldItemUse_Throw& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_HeldItemUse_Requests);
    Requests.ThrowRequests.Add(InRequest);
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
