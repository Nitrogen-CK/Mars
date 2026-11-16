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

    const auto View = Self.Get_LaunchView();
    FCk_Handle Carrier = Self;
    const auto Aim = InLaunch.Aim.IsSet() ? InLaunch.Aim.GetValue() : utils_held_item_use::Make_Aim(Carrier);
    const auto Forward = Aim.Forward;

    if (IsThrow)
    { Speed *= Self.Get_ThrowPower(); }

    auto Solution = FMars_HeldItemUse_LaunchSolution();
    Solution.LinearVelocity = Forward * Speed + Aim.PawnVelocity;
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
