namespace utils_lantern
{
    // A spec that fails Validate() ensures and adds nothing.
    FCk_Handle_Lantern Add(FCk_Handle& InHandle, FMars_Lantern_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Lantern] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Lantern(); }

        auto Params = FMars_Fragment_Lantern_Params();
        Params.Measures = InSpec.Measures;
        Params.SecondsPerMeasure = InSpec.SecondsPerMeasure;
        Params.GutterSeconds = InSpec.GutterSeconds;
        Params.Radius = InSpec.Radius;

        auto State = FMars_Fragment_Lantern();
        State.Shutter = InSpec.StartShutter;
        State.MeasuresLeft = InSpec.StartMeasures.IsSet() ? InSpec.StartMeasures.GetValue() : InSpec.Measures;
        State.Flame = Get_Flame(Params, State);

        InHandle.Add_Fragment(FMars_Feature_Lantern());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        if (Get_IsBurning(State))
        { InHandle.Add_Fragment(FMars_Tag_Lantern_Burning()); }

        auto Root = InHandle.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Root))
        { InHandle.Add_Fragment(DoCreate_LightProbes(Root, Params.Radius)); }

        return InHandle.As_Lantern();
    }

    // One disabled Probe.Mars.Light sphere per pool on InRoot. Kinematic: the lantern moves them. Silent: nothing listens on
    // the lantern's side; receivers' triggers filter on the name.
    FMars_Fragment_Lantern_LightProbes DoCreate_LightProbes(FCk_Handle_Transform& InRoot, const FMars_Lantern_Radius& InRadius)
    {
        auto ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Light);
        ProbeSpec.Set_MotionType(ECk_MotionType::Kinematic)
                 .Set_ResponsePolicy(ECk_ProbeResponse_Policy::Silent)
                 .Set_StartingState(ECk_EnableDisable::Disable);

        auto Probes = FMars_Fragment_Lantern_LightProbes();
        Probes.Held = DoCreate_LightProbe(InRoot, InRadius.Held, ProbeSpec, n"Lantern.Probe.Light.Held");
        Probes.World = DoCreate_LightProbe(InRoot, InRadius.World, ProbeSpec, n"Lantern.Probe.Light.World");
        return Probes;
    }

    FCk_Handle_Probe DoCreate_LightProbe(FCk_Handle_Transform& InRoot, float32 InRadius, const FCk_Probe_Spec& InSpec, FName InDebugName)
    {
        auto Node = utils_prefab::Create_ProbeNode_Sphere(InRoot, InRadius, InSpec);
        utils_handle::Set_DebugName(Node.H(), InDebugName);
        return Node.As_Probe();
    }

    // The lantern a Probe.Mars.Light probe entity (what a receiver's trigger reports) belongs to: the probe node's lifetime
    // owner. Invalid for any other entity.
    FCk_Handle_Lantern TryGet_FromLightProbe(FCk_Handle InProbeEntity)
    {
        if (ck::Is_NOT_Valid(InProbeEntity))
        { return FCk_Handle_Lantern(); }

        const auto Direct = InProbeEntity.As_Lantern(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Direct))
        { return Direct; }

        return utils_entity_lifetime::Get_LifetimeOwner(InProbeEntity).As_Lantern(ECk_SanityCheck::UnChecked);
    }

    // The lit lanterns whose light probes InTrigger holds, once each.
    TArray<FCk_Handle_Lantern> Get_LitLanternsIn(const FCk_Handle_Trigger& InTrigger)
    {
        auto Lanterns = TArray<FCk_Handle_Lantern>();
        if (ck::Is_NOT_Valid(InTrigger))
        { return Lanterns; }

        for (auto Entity : InTrigger.Get_EntitiesInside())
        {
            const auto Lantern = TryGet_FromLightProbe(Entity);
            if (ck::IsValid(Lantern) && Lantern.Get_IsLit() && Lanterns.Contains(Lantern) == false)
            { Lanterns.Add(Lantern); }
        }

        return Lanterns;
    }

    // The flame InState shows: spent with no tallow left, guttering through the last GutterSeconds of the last measure.
    EMars_Lantern_Flame Get_Flame(const FMars_Fragment_Lantern_Params& InParams, const FMars_Fragment_Lantern& InState)
    {
        if (InState.MeasuresLeft <= 0)
        { return EMars_Lantern_Flame::Spent; }

        const auto IsLastMeasure = InState.MeasuresLeft == 1;
        const auto SecondsLeftInMeasure = InParams.SecondsPerMeasure - InState.MeasureElapsed;
        if (IsLastMeasure && SecondsLeftInMeasure <= InParams.GutterSeconds)
        { return EMars_Lantern_Flame::Guttering; }

        return EMars_Lantern_Flame::Steady;
    }

    bool Get_IsBurning(const FMars_Fragment_Lantern& InState)
    {
        return InState.Shutter == EMars_Lantern_Shutter::Open && InState.MeasuresLeft > 0;
    }

    FMars_Lantern_Reading Make_Reading(const FMars_Fragment_Lantern& InState)
    {
        auto Reading = FMars_Lantern_Reading();
        Reading.IsLit = Get_IsBurning(InState);
        Reading.Flame = InState.Flame;
        Reading.MeasuresLeft = InState.MeasuresLeft;
        return Reading;
    }

    // The processors' one tail: keeps the Burning tag in step with InAfter and broadcasts each reading that changed
    // across the pass, measures first, then the flame, then lit.
    void Apply_Changes(FCk_Handle_Lantern& InLantern, const FMars_Lantern_Reading& InBefore, const FMars_Lantern_Reading& InAfter)
    {
        const auto IsTagged = InLantern.Has_Fragment(FMars_Tag_Lantern_Burning);
        if (InAfter.IsLit && IsTagged == false)
        { InLantern.Add_Fragment(FMars_Tag_Lantern_Burning()); }
        else if (InAfter.IsLit == false && IsTagged)
        { InLantern.Request_TryRemove(FMars_Tag_Lantern_Burning); }

        if (InLantern.Has_Fragment(FMars_Fragment_Lantern_Signals) == false)
        { return; }

        auto& Signals = InLantern.Get_Fragment(FMars_Fragment_Lantern_Signals);
        if (InAfter.MeasuresLeft != InBefore.MeasuresLeft)
        { Signals.OnMeasuresChanged.Broadcast(InLantern, InAfter.MeasuresLeft); }

        if (InAfter.Flame != InBefore.Flame)
        { Signals.OnFlameChanged.Broadcast(InLantern, InAfter.Flame); }

        if (InAfter.IsLit != InBefore.IsLit)
        { Signals.OnLitChanged.Broadcast(InLantern, InAfter.IsLit); }
    }

    // A carried lantern InHotbar can refuel, the emptiest first (lowest index on a tie). Invalid when every one is full.
    FCk_Handle_Lantern TryGet_RefuelTarget(const FCk_Handle_Hotbar& InHotbar)
    {
        auto Best = FCk_Handle_Lantern();
        for (int32 Index = 0; Index <= InHotbar.Get_LastIndex(); ++Index)
        {
            const auto Lantern = InHotbar.Get_ItemAt(Index).TryGet_Lantern();
            if (ck::Is_NOT_Valid(Lantern) || Lantern.Get_CanRefuel() == false)
            { continue; }

            if (ck::Is_NOT_Valid(Best) || Lantern.Get_FuelFraction() < Best.Get_FuelFraction())
            { Best = Lantern; }
        }

        return Best;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

// The lantern an item's body carries: a Persistent item whose world item composed the Lantern feature. Invalid otherwise.
mixin FCk_Handle_Lantern TryGet_Lantern(const FCk_Handle_Item& Self)
{
    if (ck::Is_NOT_Valid(Self) || Self.Has_PersistentWorldItem() == false)
    { return FCk_Handle_Lantern(); }

    const auto WorldItem = Self.Get_PersistentWorldItem();
    return WorldItem.H().As_Lantern(ECk_SanityCheck::UnChecked);
}

mixin int32 Get_Measures(const FCk_Handle_Lantern& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Lantern_Params).Measures;
}

mixin int32 Get_MeasuresLeft(const FCk_Handle_Lantern& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Lantern).MeasuresLeft;
}

mixin EMars_Lantern_Shutter Get_Shutter(const FCk_Handle_Lantern& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Lantern).Shutter;
}

mixin EMars_Lantern_Flame Get_Flame(const FCk_Handle_Lantern& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Lantern).Flame;
}

// Open with tallow left, and not stowed. (OnLitChanged follows the shutter and the fuel; stowing is a mount change:
// OnMountChanged.)
mixin bool Get_IsLit(const FCk_Handle_Lantern& Self)
{
    return utils_lantern::Get_IsBurning(Self.Get_Fragment(FMars_Fragment_Lantern)) && Self.Get_IsStowed() == false;
}

mixin bool Get_CanRefuel(const FCk_Handle_Lantern& Self)
{
    return Self.Get_MeasuresLeft() < Self.Get_Measures();
}

// The tallow left, 0..1, the burning measure counted by what is left of it.
mixin float32 Get_FuelFraction(const FCk_Handle_Lantern& Self)
{
    const auto& Params = Self.Get_Fragment(FMars_Fragment_Lantern_Params);
    const auto& State = Self.Get_Fragment(FMars_Fragment_Lantern);
    if (State.MeasuresLeft <= 0)
    { return 0.0f; }

    const auto Left = float32(State.MeasuresLeft) - State.MeasureElapsed / Params.SecondsPerMeasure;
    return Math::Clamp(Left / float32(Params.Measures), 0.0f, 1.0f);
}

// Where the flame is by where its world item is: Held in a hand; Stowed when Carried on the item's own carry point (a
// hotbar slot that is not selected rides it there: Presentation.Mounting.CarryPoint); World otherwise - lying, hung on a
// hook, in a pack's cargo slot. A lantern on an entity with no world item is World.
mixin EMars_Lantern_Pool Get_LightPool(const FCk_Handle_Lantern& Self)
{
    const auto WorldItem = Self.H().As_WorldItem(ECk_SanityCheck::UnChecked);
    if (ck::Is_NOT_Valid(WorldItem))
    { return EMars_Lantern_Pool::World; }

    const auto Mount = WorldItem.Get_Mount();
    if (Mount == EMars_WorldItem_Mount::Held)
    { return EMars_Lantern_Pool::Held; }

    if (Mount == EMars_WorldItem_Mount::Carried)
    {
        const auto Point = WorldItem.Get_MountPoint();
        const UMars_ItemTrait_Presentation Presentation = utils_world_item::TryGet_Presentation(WorldItem);
        const auto IsCarryPoint = ck::IsValid(Presentation) && Point.IsValid() && Point == Presentation.Mounting.CarryPoint;
        return IsCarryPoint ? EMars_Lantern_Pool::Stowed : EMars_Lantern_Pool::World;
    }

    return EMars_Lantern_Pool::World;
}

// Stowed away in a carrier's hotbar: it lights nothing and burns nothing, whatever its shutter.
mixin bool Get_IsStowed(const FCk_Handle_Lantern& Self)
{
    return Self.Get_LightPool() == EMars_Lantern_Pool::Stowed;
}

mixin float32 Get_PoolRadius(const FCk_Handle_Lantern& Self, EMars_Lantern_Pool InPool)
{
    const auto& Radius = Self.Get_Fragment(FMars_Fragment_Lantern_Params).Radius;
    switch (InPool)
    {
        case EMars_Lantern_Pool::Held: return Radius.Held;
        case EMars_Lantern_Pool::Stowed: return 0.0f;
        default: return Radius.World;
    }
}

// The radius the flame lights, 0 while unlit (stowed included): the radius of Get_LightPool.
mixin float32 Get_LightRadius(const FCk_Handle_Lantern& Self)
{
    if (Self.Get_IsLit() == false)
    { return 0.0f; }

    return Self.Get_PoolRadius(Self.Get_LightPool());
}

// The pool whose Probe.Mars.Light probe is enabled (as of the last LightProbe pass); unset while dark or without probes.
mixin TOptional<EMars_Lantern_Pool> Get_ShownLightPool(const FCk_Handle_Lantern& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Lantern_LightProbes) == false)
    { return TOptional<EMars_Lantern_Pool>(); }

    return Self.Get_Fragment(FMars_Fragment_Lantern_LightProbes).Shown;
}

// Invalid without probes, and for Stowed (which lights nothing).
mixin FCk_Handle_Probe Get_LightProbe(const FCk_Handle_Lantern& Self, EMars_Lantern_Pool InPool)
{
    if (Self.Has_Fragment(FMars_Fragment_Lantern_LightProbes) == false || InPool == EMars_Lantern_Pool::Stowed)
    { return FCk_Handle_Probe(); }

    const auto& Probes = Self.Get_Fragment(FMars_Fragment_Lantern_LightProbes);
    return InPool == EMars_Lantern_Pool::Held ? Probes.Held : Probes.World;
}

// The world item carrying the lantern is Held by InCarrier (in its hand).
mixin bool Get_IsHeldBy(const FCk_Handle_Lantern& Self, const FCk_Handle& InCarrier)
{
    const auto WorldItem = Self.H().As_WorldItem(ECk_SanityCheck::UnChecked);
    return ck::IsValid(WorldItem) && ck::IsValid(InCarrier)
        && WorldItem.Get_Mount() == EMars_WorldItem_Mount::Held && WorldItem.Get_Carrier() == InCarrier;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_SetShutter(FCk_Handle_Lantern& Self, const FMars_Request_Lantern_SetShutter& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Lantern_Requests);
    Requests.SetShutterRequests.Add(InRequest);
}

mixin void Request_Refuel(FCk_Handle_Lantern& Self, const FMars_Request_Lantern_Refuel& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Lantern_Requests);
    Requests.RefuelRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnLitChanged(FCk_Handle_Lantern& Self, FMars_Delegate_Lantern_OnLitChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Lantern_Signals);
    Fragment.OnLitChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnLitChanged(FCk_Handle_Lantern& Self, FMars_Delegate_Lantern_OnLitChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Lantern_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Lantern_Signals).OnLitChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnFlameChanged(FCk_Handle_Lantern& Self, FMars_Delegate_Lantern_OnFlameChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Lantern_Signals);
    Fragment.OnFlameChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnFlameChanged(FCk_Handle_Lantern& Self, FMars_Delegate_Lantern_OnFlameChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Lantern_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Lantern_Signals).OnFlameChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnMeasuresChanged(FCk_Handle_Lantern& Self, FMars_Delegate_Lantern_OnMeasuresChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Lantern_Signals);
    Fragment.OnMeasuresChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnMeasuresChanged(FCk_Handle_Lantern& Self, FMars_Delegate_Lantern_OnMeasuresChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Lantern_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Lantern_Signals).OnMeasuresChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
