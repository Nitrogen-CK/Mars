namespace utils_flame
{
    // A spec that fails Validate() ensures and adds nothing.
    FCk_Handle_Flame Add(FCk_Handle& InHandle, FMars_Flame_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Flame] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Flame(); }

        auto Params = FMars_Fragment_Flame_Params();
        Params.Fuel = InSpec.Fuel;
        Params.Enclosure = InSpec.Enclosure;
        Params.Lighting = InSpec.Lighting;
        Params.OnStow = InSpec.OnStow;
        Params.Radius = InSpec.Radius;
        Params.Interactable = InSpec.Interactable;

        auto State = FMars_Fragment_Flame();
        State.Ignition = InSpec.StartIgnition;
        if (InSpec.Fuel.IsSet())
        {
            const auto& Fuel = InSpec.Fuel.GetValue();
            State.MeasuresLeft = Fuel.StartMeasures.IsSet() ? Fuel.StartMeasures.GetValue() : Fuel.Measures;
        }
        State.Condition = Get_Condition(Params, State);

        InHandle.Add_Fragment(FMars_Feature_Flame());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        if (Get_IsBurning(Params, State))
        { InHandle.Add_Fragment(FMars_Tag_Flame_Burning()); }

        auto Root = InHandle.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Root))
        { InHandle.Add_Fragment(DoCreate_LightProbes(Root, Params)); }

        return InHandle.As_Flame();
    }

    // One disabled Probe.Mars.Light sphere per pool InParams can light on InRoot: Held and World always, Stowed only for a
    // flame that stays lit when stowed.
    FMars_Fragment_Flame_LightProbes DoCreate_LightProbes(FCk_Handle_Transform& InRoot, const FMars_Fragment_Flame_Params& InParams)
    {
        auto Probes = FMars_Fragment_Flame_LightProbes();
        Probes.Held = DoCreate_LightProbe(InRoot, InParams.Radius.Held, n"Flame.Probe.Light.Held");
        Probes.World = DoCreate_LightProbe(InRoot, InParams.Radius.World, n"Flame.Probe.Light.World");
        if (InParams.OnStow == EMars_Flame_OnStow::StaysLit)
        { Probes.Stowed = DoCreate_LightProbe(InRoot, InParams.Radius.Stowed, n"Flame.Probe.Light.Stowed"); }

        return Probes;
    }

    // Kinematic: the flame moves it. Silent: nothing listens on the flame's side; receivers' triggers filter on the name.
    FCk_Handle_Probe DoCreate_LightProbe(FCk_Handle_Transform& InRoot, float32 InRadius, FName InDebugName)
    {
        auto ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Light);
        ProbeSpec.Set_MotionType(ECk_MotionType::Kinematic)
                 .Set_ResponsePolicy(ECk_ProbeResponse_Policy::Silent)
                 .Set_StartingState(ECk_EnableDisable::Disable);

        auto Node = utils_prefab::Create_ProbeNode_Sphere(InRoot, InRadius, ProbeSpec);
        utils_handle::Set_DebugName(Node.H(), InDebugName);
        return Node.As_Probe();
    }

    // The flame a Probe.Mars.Light probe entity (what a receiver's trigger reports) belongs to: the probe node's lifetime
    // owner. Invalid for any other entity.
    FCk_Handle_Flame TryGet_FromLightProbe(FCk_Handle InProbeEntity)
    {
        if (ck::Is_NOT_Valid(InProbeEntity))
        { return FCk_Handle_Flame(); }

        const auto Direct = InProbeEntity.As_Flame(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Direct))
        { return Direct; }

        return utils_entity_lifetime::Get_LifetimeOwner(InProbeEntity).As_Flame(ECk_SanityCheck::UnChecked);
    }

    // The lit flames whose light probes InTrigger holds, once each.
    TArray<FCk_Handle_Flame> Get_LitFlamesIn(const FCk_Handle_Trigger& InTrigger)
    {
        auto Flames = TArray<FCk_Handle_Flame>();
        if (ck::Is_NOT_Valid(InTrigger))
        { return Flames; }

        for (auto Entity : InTrigger.Get_EntitiesInside())
        {
            const auto Flame = TryGet_FromLightProbe(Entity);
            if (ck::IsValid(Flame) && Flame.Get_IsLit() && Flames.Contains(Flame) == false)
            { Flames.Add(Flame); }
        }

        return Flames;
    }

    // Unlimited fuel is always Steady; measured fuel is Spent with none left and Guttering through the last GutterSeconds
    // of the last measure.
    EMars_Flame_Condition Get_Condition(const FMars_Fragment_Flame_Params& InParams, const FMars_Fragment_Flame& InState)
    {
        if (InParams.Fuel.IsSet() == false)
        { return EMars_Flame_Condition::Steady; }

        if (InState.MeasuresLeft <= 0)
        { return EMars_Flame_Condition::Spent; }

        const auto& Fuel = InParams.Fuel.GetValue();
        const auto IsLastMeasure = InState.MeasuresLeft == 1;
        const auto SecondsLeftInMeasure = Fuel.SecondsPerMeasure - InState.MeasureElapsed;
        if (IsLastMeasure && SecondsLeftInMeasure <= Fuel.GutterSeconds)
        { return EMars_Flame_Condition::Guttering; }

        return EMars_Flame_Condition::Steady;
    }

    bool Get_HasFuelLeft(const FMars_Fragment_Flame_Params& InParams, const FMars_Fragment_Flame& InState)
    {
        return InParams.Fuel.IsSet() == false || InState.MeasuresLeft > 0;
    }

    // Lit with fuel left (or unlimited fuel): the one truth of Get_IsLit, wherever the flame is.
    bool Get_IsBurning(const FMars_Fragment_Flame_Params& InParams, const FMars_Fragment_Flame& InState)
    {
        return InState.Ignition == EMars_Flame_Ignition::Lit && Get_HasFuelLeft(InParams, InState);
    }

    FMars_Flame_Reading Make_Reading(const FMars_Fragment_Flame_Params& InParams, const FMars_Fragment_Flame& InState)
    {
        auto Reading = FMars_Flame_Reading();
        Reading.IsLit = Get_IsBurning(InParams, InState);
        Reading.Condition = InState.Condition;
        Reading.MeasuresLeft = InState.MeasuresLeft;
        return Reading;
    }

    // The processors' one tail: keeps the Burning tag in step with InAfter and broadcasts each reading that changed
    // across the pass, measures first, then the condition, then lit.
    void Apply_Changes(FCk_Handle_Flame& InFlame, const FMars_Flame_Reading& InBefore, const FMars_Flame_Reading& InAfter)
    {
        const auto IsTagged = InFlame.Has_Fragment(FMars_Tag_Flame_Burning);
        if (InAfter.IsLit && IsTagged == false)
        { InFlame.Add_Fragment(FMars_Tag_Flame_Burning()); }
        else if (InAfter.IsLit == false && IsTagged)
        { InFlame.Request_TryRemove(FMars_Tag_Flame_Burning); }

        if (InFlame.Has_Fragment(FMars_Fragment_Flame_Signals) == false)
        { return; }

        auto& Signals = InFlame.Get_Fragment(FMars_Fragment_Flame_Signals);
        if (InAfter.MeasuresLeft != InBefore.MeasuresLeft)
        { Signals.OnMeasuresChanged.Broadcast(InFlame, InAfter.MeasuresLeft); }

        if (InAfter.Condition != InBefore.Condition)
        { Signals.OnConditionChanged.Broadcast(InFlame, InAfter.Condition); }

        if (InAfter.IsLit != InBefore.IsLit)
        { Signals.OnLitChanged.Broadcast(InFlame, InAfter.IsLit); }
    }

    // A carried flame InHotbar can refuel, the emptiest first (lowest index on a tie). Invalid when none can take fuel.
    FCk_Handle_Flame TryGet_RefuelTarget(const FCk_Handle_Hotbar& InHotbar)
    {
        auto Best = FCk_Handle_Flame();
        for (int32 Index = 0; Index <= InHotbar.Get_LastIndex(); ++Index)
        {
            const auto Flame = InHotbar.Get_ItemAt(Index).TryGet_Flame();
            if (ck::Is_NOT_Valid(Flame) || Flame.Get_CanRefuel() == false)
            { continue; }

            if (ck::Is_NOT_Valid(Best) || Flame.Get_FuelFraction() < Best.Get_FuelFraction())
            { Best = Flame; }
        }

        return Best;
    }

    // The ignite row of a flame's interactable: Use with the caller's prompt (a placeholder the control layer rewrites while
    // focused), run once the press completes. It needs no free hand: the point is a hand holding a flame, and that hand
    // is the one that reaches, carrying its flame to this one.
    FMars_Interactable_TargetEntry Make_IgniteTarget(FMars_InteractPrompt_Spec InPrompt)
    {
        auto TargetSpec = FCk_InteractTarget_Spec(GameplayTags::InteractionChannel_Mars_Use);
        TargetSpec.Set_CompletionPolicy(ECk_Interaction_CompletionPolicy::Instant);

        auto Target = FMars_Interactable_TargetEntry();
        Target.InteractTargetSpec = TargetSpec;
        Target.InteractPromptSpec = InPrompt;
        Target.InteractionStateClass = UMars_SmState_Flame_Ignite;
        Target.Work = EMars_Interactable_Work::AfterCompletion;
        Target.ReachKind = EMars_FPHands_ReachKind::Grab;
        Target.ReachHand = EMars_FPHands_ReachHand::Holding;
        Target.RequiresFreeHands = false;
        return Target;
    }

    // The flame of the item InHolder holds in its hand; invalid when it holds nothing, a non-flame, or has no hands.
    FCk_Handle_Flame TryGet_HeldFlame(FCk_Handle InHolder)
    {
        if (ck::Is_NOT_Valid(InHolder))
        { return FCk_Handle_Flame(); }

        const auto HeldItem = InHolder.As_HeldItem(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(HeldItem))
        { return FCk_Handle_Flame(); }

        return HeldItem.Get_CurrentItem().TryGet_Flame();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

// The flame an item's body carries: a Persistent item whose world item composed the Flame feature. Invalid otherwise.
mixin FCk_Handle_Flame TryGet_Flame(const FCk_Handle_Item& Self)
{
    if (ck::Is_NOT_Valid(Self) || Self.Has_PersistentWorldItem() == false)
    { return FCk_Handle_Flame(); }

    const auto WorldItem = Self.Get_PersistentWorldItem();
    return WorldItem.H().As_Flame(ECk_SanityCheck::UnChecked);
}

mixin EMars_Flame_Ignition Get_Ignition(const FCk_Handle_Flame& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Flame).Ignition;
}

mixin EMars_Flame_Condition Get_Condition(const FCk_Handle_Flame& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Flame).Condition;
}

mixin EMars_Flame_Enclosure Get_Enclosure(const FCk_Handle_Flame& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Flame_Params).Enclosure;
}

// The interactable whose ignite row lights this flame or takes light from it; invalid for a flame without one.
mixin FCk_Handle_Interactable Get_Interactable(const FCk_Handle_Flame& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Flame_Params).Interactable;
}

// The fuel block's Measures; 0 for unlimited fuel.
mixin int32 Get_Measures(const FCk_Handle_Flame& Self)
{
    const auto& Params = Self.Get_Fragment(FMars_Fragment_Flame_Params);
    return Params.Fuel.IsSet() ? Params.Fuel.GetValue().Measures : 0;
}

// 0 for unlimited fuel.
mixin int32 Get_MeasuresLeft(const FCk_Handle_Flame& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Flame).MeasuresLeft;
}

// Lit with fuel left (or unlimited fuel), wherever it is: a stowed flame that stays lit is lit. (OnLitChanged follows
// this; a mount change is OnMountChanged.)
mixin bool Get_IsLit(const FCk_Handle_Flame& Self)
{
    return utils_flame::Get_IsBurning(Self.Get_Fragment(FMars_Fragment_Flame_Params), Self.Get_Fragment(FMars_Fragment_Flame));
}

// The fuel left, 0..1, the burning measure counted by what is left of it; 1 for unlimited fuel.
mixin float32 Get_FuelFraction(const FCk_Handle_Flame& Self)
{
    const auto& Params = Self.Get_Fragment(FMars_Fragment_Flame_Params);
    if (Params.Fuel.IsSet() == false)
    { return 1.0f; }

    const auto& State = Self.Get_Fragment(FMars_Fragment_Flame);
    if (State.MeasuresLeft <= 0)
    { return 0.0f; }

    const auto& Fuel = Params.Fuel.GetValue();
    const auto Left = float32(State.MeasuresLeft) - State.MeasureElapsed / Fuel.SecondsPerMeasure;
    return Math::Clamp(Left / float32(Fuel.Measures), 0.0f, 1.0f);
}

// Where the flame is by where its world item is: Held in a hand; Stowed when Carried on the item's own carry point (a
// hotbar slot that is not selected rides it there: Presentation.Mounting.CarryPoint); World otherwise - lying, hung on a
// hook, in a pack's cargo slot. A flame on an entity with no world item is World.
mixin EMars_Flame_Pool Get_LightPool(const FCk_Handle_Flame& Self)
{
    const auto WorldItem = Self.H().As_WorldItem(ECk_SanityCheck::UnChecked);
    if (ck::Is_NOT_Valid(WorldItem))
    { return EMars_Flame_Pool::World; }

    const auto Mount = WorldItem.Get_Mount();
    if (Mount == EMars_WorldItem_Mount::Held)
    { return EMars_Flame_Pool::Held; }

    if (Mount == EMars_WorldItem_Mount::Carried)
    {
        const auto Point = WorldItem.Get_MountPoint();
        const UMars_ItemTrait_Presentation Presentation = utils_world_item::TryGet_Presentation(WorldItem);
        const auto IsCarryPoint = ck::IsValid(Presentation) && Point.IsValid() && Point == Presentation.Mounting.CarryPoint;
        return IsCarryPoint ? EMars_Flame_Pool::Stowed : EMars_Flame_Pool::World;
    }

    return EMars_Flame_Pool::World;
}

mixin bool Get_IsStowed(const FCk_Handle_Flame& Self)
{
    return Self.Get_LightPool() == EMars_Flame_Pool::Stowed;
}

// Stowed is 0 for a flame that snuffs when stowed.
mixin float32 Get_PoolRadius(const FCk_Handle_Flame& Self, EMars_Flame_Pool InPool)
{
    const auto& Params = Self.Get_Fragment(FMars_Fragment_Flame_Params);
    switch (InPool)
    {
        case EMars_Flame_Pool::Held: return Params.Radius.Held;
        case EMars_Flame_Pool::Stowed: return Params.OnStow == EMars_Flame_OnStow::StaysLit ? Params.Radius.Stowed : 0.0f;
        default: return Params.Radius.World;
    }
}

// The radius the flame lights, 0 while unlit: the radius of Get_LightPool.
mixin float32 Get_LightRadius(const FCk_Handle_Flame& Self)
{
    if (Self.Get_IsLit() == false)
    { return 0.0f; }

    return Self.Get_PoolRadius(Self.Get_LightPool());
}

// The pool whose Probe.Mars.Light probe is enabled (as of the last Pool pass); unset while dark or without probes.
mixin TOptional<EMars_Flame_Pool> Get_ShownLightPool(const FCk_Handle_Flame& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Flame_LightProbes) == false)
    { return TOptional<EMars_Flame_Pool>(); }

    return Self.Get_Fragment(FMars_Fragment_Flame_LightProbes).Shown;
}

// Invalid without probes, and for a pool the flame has no probe for (Stowed on a flame that snuffs when stowed).
mixin FCk_Handle_Probe Get_LightProbe(const FCk_Handle_Flame& Self, EMars_Flame_Pool InPool)
{
    if (Self.Has_Fragment(FMars_Fragment_Flame_LightProbes) == false)
    { return FCk_Handle_Probe(); }

    const auto& Probes = Self.Get_Fragment(FMars_Fragment_Flame_LightProbes);
    switch (InPool)
    {
        case EMars_Flame_Pool::Held: return Probes.Held;
        case EMars_Flame_Pool::Stowed: return Probes.Stowed;
        default: return Probes.World;
    }
}

// The world item carrying the flame is Held by InCarrier (in its hand).
mixin bool Get_IsHeldBy(const FCk_Handle_Flame& Self, const FCk_Handle& InCarrier)
{
    const auto WorldItem = Self.H().As_WorldItem(ECk_SanityCheck::UnChecked);
    return ck::IsValid(WorldItem) && ck::IsValid(InCarrier)
        && WorldItem.Get_Mount() == EMars_WorldItem_Mount::Held && WorldItem.Get_Carrier() == InCarrier;
}

//--------------------------------------------------------------------------------------------------------------------------
// Ignite rules
//--------------------------------------------------------------------------------------------------------------------------

// Lit and bare: it can light another bare flame.
mixin bool Get_CanPassFire(const FCk_Handle_Flame& Self)
{
    return Self.Get_IsLit() && Self.Get_Enclosure() == EMars_Flame_Enclosure::Open;
}

// Self is unlit, bare and has fuel left (or unlimited fuel), and InSource is another flame that can pass fire.
mixin bool Get_CanBeLitBy(const FCk_Handle_Flame& Self, const FCk_Handle_Flame& InSource)
{
    if (Self.Get_IsLit() || Self.Get_Enclosure() != EMars_Flame_Enclosure::Open)
    { return false; }

    if (utils_flame::Get_HasFuelLeft(Self.Get_Fragment(FMars_Fragment_Flame_Params), Self.Get_Fragment(FMars_Fragment_Flame)) == false)
    { return false; }

    return ck::IsValid(InSource) && InSource != Self && InSource.Get_CanPassFire();
}

// It lights itself (a shutter, a strike) and has fuel left (or unlimited fuel).
mixin bool Get_CanSelfLight(const FCk_Handle_Flame& Self)
{
    const auto& Params = Self.Get_Fragment(FMars_Fragment_Flame_Params);
    return Params.Lighting == EMars_Flame_Lighting::SelfLighting
        && utils_flame::Get_HasFuelLeft(Params, Self.Get_Fragment(FMars_Fragment_Flame));
}

// Measured, refuelable fuel with room for more.
mixin bool Get_CanRefuel(const FCk_Handle_Flame& Self)
{
    const auto& Params = Self.Get_Fragment(FMars_Fragment_Flame_Params);
    if (Params.Fuel.IsSet() == false || Params.Fuel.GetValue().Refuel != EMars_Flame_Refuel::Refuelable)
    { return false; }

    return Self.Get_MeasuresLeft() < Params.Fuel.GetValue().Measures;
}

// What InFocuser's held flame and this one can do for each other. Unlit: Light when the held flame can light it, else why
// not. Lit: TakeLight when it can light the held flame, else why not (None when the held flame is lit or not a flame).
mixin EMars_Flame_Action Get_ActionFor(const FCk_Handle_Flame& Self, FCk_Handle InFocuser)
{
    const auto Held = utils_flame::TryGet_HeldFlame(InFocuser);
    const auto HoldsAFlame = ck::IsValid(Held);
    const auto HeldIsEnclosed = HoldsAFlame && Held.Get_Enclosure() == EMars_Flame_Enclosure::Enclosed;
    const auto HeldIsSpent = HoldsAFlame && Held.Get_Condition() == EMars_Flame_Condition::Spent;

    if (Self.Get_IsLit() == false)
    {
        if (HoldsAFlame && Self.Get_CanBeLitBy(Held))
        { return EMars_Flame_Action::Light; }

        if (HeldIsEnclosed)
        { return EMars_Flame_Action::Blocked_Enclosed; }

        if (HeldIsSpent)
        { return EMars_Flame_Action::Blocked_Spent; }

        return EMars_Flame_Action::Blocked_NeedsAFlame;
    }

    if (HoldsAFlame && Held.Get_CanBeLitBy(Self))
    { return EMars_Flame_Action::TakeLight; }

    if (HeldIsEnclosed)
    { return EMars_Flame_Action::Blocked_Enclosed; }

    if (HeldIsSpent)
    { return EMars_Flame_Action::Blocked_Spent; }

    return EMars_Flame_Action::None;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_SetIgnition(FCk_Handle_Flame& Self, const FMars_Request_Flame_SetIgnition& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Flame_Requests);
    Requests.SetIgnitionRequests.Add(InRequest);
}

mixin void Request_Refuel(FCk_Handle_Flame& Self, const FMars_Request_Flame_Refuel& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Flame_Requests);
    Requests.RefuelRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnLitChanged(FCk_Handle_Flame& Self, FMars_Delegate_Flame_OnLitChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Flame_Signals);
    Fragment.OnLitChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnLitChanged(FCk_Handle_Flame& Self, FMars_Delegate_Flame_OnLitChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Flame_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Flame_Signals).OnLitChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnConditionChanged(FCk_Handle_Flame& Self, FMars_Delegate_Flame_OnConditionChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Flame_Signals);
    Fragment.OnConditionChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnConditionChanged(FCk_Handle_Flame& Self, FMars_Delegate_Flame_OnConditionChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Flame_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Flame_Signals).OnConditionChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnMeasuresChanged(FCk_Handle_Flame& Self, FMars_Delegate_Flame_OnMeasuresChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Flame_Signals);
    Fragment.OnMeasuresChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnMeasuresChanged(FCk_Handle_Flame& Self, FMars_Delegate_Flame_OnMeasuresChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Flame_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Flame_Signals).OnMeasuresChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
