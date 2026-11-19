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

// How far the armed throw has charged, 0..1; 0 while nothing is armed.
mixin float32 Get_ThrowCharge(const FCk_Handle_HeldItemUse& Self)
{
    return Self.Get_Fragment(FMars_Fragment_HeldItemUse).ThrowCharge;
}

// The share of the held item's ThrowSpeed a throw released now leaves at: its MinThrowPower uncharged, rising with the
// charge to 1.
mixin float32 Get_ThrowPower(const FCk_Handle_HeldItemUse& Self)
{
    return Math::Lerp(Self.Get_ThrowTuning().MinThrowPower, 1.0f, Self.Get_ThrowCharge());
}

// The held item's throw tuning (its Throwable trait, or the defaults without one); the defaults with empty hands.
mixin FMars_HeldItemUse_ThrowTuning Get_ThrowTuning(const FCk_Handle_HeldItemUse& Self)
{
    auto Tuning = FMars_HeldItemUse_ThrowTuning();
    const auto Item = Self.As_HeldItem().Get_CurrentItem();
    if (ck::IsValid(Item) && Item.Has_Throwable())
    {
        const UMars_ItemTrait_Throwable Throwable = Item.Get_Throwable();
        Tuning.MinThrowPower = Math::Clamp(Throwable.MinThrowPower, 0.0f, 1.0f);
        Tuning.ChargeSeconds = Throwable.ChargeSeconds;
    }

    return Tuning;
}

// Launch precedes the inventory transfer; local held-item controls stop on the launch's own frame. Only until the hands
// change: an item taken back is not launched.
mixin bool Get_IsCurrentItemLaunched(const FCk_Handle_HeldItemUse& Self)
{
    const auto HeldItem = Self.As_HeldItem();
    const auto Item = HeldItem.Get_CurrentItem();
    const auto State = Self.Get_Fragment(FMars_Fragment_HeldItemUse);
    return ck::IsValid(Item) && Item == State.LaunchedItem && HeldItem.Get_ItemChangeCount() == State.LaunchedAtItemChange;
}

// Unset with empty hands, or when a Persistent item has lost its world item. Aimed by this machine's view.
mixin TOptional<FMars_HeldItemUse_LaunchSolution> Get_LaunchSolution(const FCk_Handle_HeldItemUse& Self, EMars_LaunchKind InKind)
{
    auto Launch = FMars_HeldItemUse_Launch();
    Launch.Kind = InKind;
    return Self.Get_LaunchSolutionFor(Launch);
}

// As Get_LaunchSolution, aimed by the aim InLaunch carries when it carries one: the launching machine's view, which the
// authority cannot read for a client's player.
mixin TOptional<FMars_HeldItemUse_LaunchSolution> Get_LaunchSolutionFor(const FCk_Handle_HeldItemUse& Self,
    const FMars_HeldItemUse_Launch& InLaunch)
{
    auto HeldItem = Self.As_HeldItem();
    const auto Item = HeldItem.Get_CurrentItem();
    if (ck::Is_NOT_Valid(Item))
    { return TOptional<FMars_HeldItemUse_LaunchSolution>(); }

    const auto IsThrow = InLaunch.Kind == EMars_LaunchKind::Throw;
    auto Speed = IsThrow ? constants_held_item_use::k_DefaultThrowSpeed : constants_held_item_use::k_DefaultDropSpeed;
    auto AngularVelocityDeg = FVector::ZeroVector;
    if (Item.Has_Throwable())
    {
        const UMars_ItemTrait_Throwable Throwable = Item.Get_Throwable();
        Speed = IsThrow ? Throwable.ThrowSpeed : Throwable.DropSpeed;
        AngularVelocityDeg = Throwable.AngularVelocityDeg;
    }

    FCk_Handle Carrier = Self;
    const auto Aim = InLaunch.Aim.IsSet() ? InLaunch.Aim.GetValue() : utils_held_item_use::Make_Aim(Carrier);
    const auto Forward = Aim.Forward;

    // The power the throw was charged to where it was thrown, which is not this machine for a client's throw.
    if (IsThrow)
    { Speed *= Aim.ThrowPower; }

    auto Solution = FMars_HeldItemUse_LaunchSolution();
    Solution.LinearVelocity = Forward * Speed + Aim.PawnVelocity;
    Solution.AngularVelocityDeg = AngularVelocityDeg;

    // Only a carried aim (the launching machine's) names an origin; a local launch leaves from this machine's own hand.
    auto Accepted = TOptional<FTransform>();
    if (InLaunch.Aim.IsSet())
    { Accepted = Self.Get_AcceptedLaunchOrigin(InLaunch.Aim.GetValue()); }

    if (Item.Has_PersistentWorldItem())
    {
        const auto WorldItem = Item.Get_PersistentWorldItem();
        if (ck::Is_NOT_Valid(WorldItem))
        { return TOptional<FMars_HeldItemUse_LaunchSolution>(); }

        // The item's root rides HeldOffset on the hand: on the launching machine's hand when the authority accepts it.
        FCk_Handle WorldItemEntity = WorldItem;
        auto Mounted = utils_transform::Get_EntityCurrentTransform(WorldItemEntity.As_Transform());
        if (Accepted.IsSet() && Item.Has_Presentation())
        {
            Mounted = Item.Get_Presentation().Mounting.HeldOffset * Accepted.GetValue();
            Solution.OriginFrom = EMars_HeldItemUse_LaunchOrigin::LaunchingMachine;
        }

        Solution.Origin = FTransform(Mounted.Rotator(), Mounted.GetLocation());
        return TOptional<FMars_HeldItemUse_LaunchSolution>(Solution);
    }

    auto Origin = Self.Get_OwnLaunchOrigin(Forward);
    if (Accepted.IsSet())
    {
        Origin = Accepted.GetValue();
        Solution.OriginFrom = EMars_HeldItemUse_LaunchOrigin::LaunchingMachine;
    }

    Solution.Origin = FTransform(Origin.Rotator(), Origin.GetLocation());
    return TOptional<FMars_HeldItemUse_LaunchSolution>(Solution);
}

// Where this machine launches from: its copy of the hand attach point, or InForward of its view without one.
mixin FTransform Get_OwnLaunchOrigin(const FCk_Handle_HeldItemUse& Self, FVector InForward)
{
    const auto Hand = Self.As_HeldItem().Get_HandAttachPoint();
    if (ck::IsValid(Hand))
    { return utils_transform::Get_EntityCurrentTransform(Hand); }

    const auto View = Self.Get_LaunchView();
    return FTransform(View.Rotator(), View.GetLocation() + InForward * constants_held_item_use::k_NoHandSpawnDistance);
}

// InAim's origin when it carries one within k_LaunchOriginReach of this machine's copy of the carrier, and this machine
// does not control the carrier; unset otherwise. Where it controls it, the origin is its own hand already, and a
// Persistent item leaves from where its body is (a start pose there would pop it past what is left of its arrival).
mixin TOptional<FTransform> Get_AcceptedLaunchOrigin(const FCk_Handle_HeldItemUse& Self, const FMars_HeldItemUse_Aim& InAim)
{
    if (InAim.Origin.IsSet() == false || Self.Get_IsWithinLaunchReach(InAim.Origin.GetValue().GetLocation()) == false)
    { return TOptional<FTransform>(); }

    FCk_Handle Carrier = Self;
    const auto Control = utils_net::Get_IsEntityLocallyControlled_ByPlayer(Carrier);
    if (Control == ECk_Utils_Net_IsLocallyControlled_Result::IsLocallyControlled)
    { return TOptional<FTransform>(); }

    return InAim.Origin;
}

// InLocation lies within k_LaunchOriginReach of this machine's copy of the carrier.
mixin bool Get_IsWithinLaunchReach(const FCk_Handle_HeldItemUse& Self, FVector InLocation)
{
    FCk_Handle Carrier = Self;
    const auto CarrierLocation = utils_transform::Get_EntityCurrentTransform(Carrier.As_Transform()).GetLocation();
    return (InLocation - CarrierLocation).Size() <= constants_held_item_use::k_LaunchOriginReach;
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

// The authority's count of the strike claims it judged; default on a machine without authority.
mixin FMars_HeldItemUse_StrikeTally Get_StrikeTally(const FCk_Handle_HeldItemUse& Self)
{
    return Self.Get_Fragment(FMars_Fragment_HeldItemUse).Strikes;
}

// The authority's count of the consumes it judged; default on a machine without authority.
mixin FMars_HeldItemUse_ConsumeTally Get_ConsumeTally(const FCk_Handle_HeldItemUse& Self)
{
    return Self.Get_Fragment(FMars_Fragment_HeldItemUse).Consumes;
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

// Applied only on the authority (Cue.Mars.HeldItemUse.Strike carries a client's claim there); a non-authority drops it.
mixin void Request_Strike(FCk_Handle_HeldItemUse& Self, const FMars_Request_HeldItemUse_Strike& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_HeldItemUse_Requests);
    Requests.StrikeRequests.Add(InRequest);
}

// Applied only on the authority (utils_held_item_use::Request_ConsumeFor asks it there); a non-authority drops it.
mixin void Request_Consume(FCk_Handle_HeldItemUse& Self, const FMars_Request_HeldItemUse_Consume& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_HeldItemUse_Requests);
    Requests.ConsumeRequests.Add(InRequest);
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
