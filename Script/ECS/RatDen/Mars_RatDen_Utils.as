namespace utils_rat_den
{
    // Composes the den on InOwner (which must carry a transform: the den frame) with ResidentCount Dormant residents and the
    // eye proxy standing for slot 0, and tags it TAG_MarsRatDen so a PantryRaid whose bounds hold it discovers it. A
    // rejected spec ensures and returns an invalid handle with nothing composed.
    FCk_Handle_RatDen Add(FCk_Handle& InOwner, FMars_RatDen_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[RatDen] [{InOwner.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_RatDen(); }

        if (ck::EnsureIfNot(ck::IsValid(InOwner.As_Transform(ECk_SanityCheck::UnChecked)),
            f"[RatDen] [{InOwner.ToString()}] has no transform: the den frame is its root"))
        { return FCk_Handle_RatDen(); }

        auto Params = FMars_Fragment_RatDen_Params();
        Params.Portals = InSpec.Portals;
        Params.ResidentCount = InSpec.ResidentCount;
        Params.EyePlate = InSpec.Parts.EyePlate;

        auto State = FMars_Fragment_RatDen();
        for (int32 Index = 0; Index < InSpec.ResidentCount; ++Index)
        { State.Residents.Add(FMars_RatDen_Resident()); }
        State.EyeSlot = Get_EyeSlotFor(State);

        InOwner.Add_Fragment(FMars_Feature_RatDen());
        InOwner.Add_Fragment(Params);
        InOwner.Add_Fragment(State);
        utils_entity_tag::Add(InOwner, DenTag);
        return InOwner.As_RatDen();
    }

    // The resident the eye proxy stands for: the lowest Dormant slot while the eyes are enabled; unset when none.
    TOptional<int32> Get_EyeSlotFor(const FMars_Fragment_RatDen& InState)
    {
        if (InState.EyesEnabled == false)
        { return TOptional<int32>(); }

        for (int32 Index = 0; Index < InState.Residents.Num(); ++Index)
        {
            if (InState.Residents[Index].State == EMars_RatDen_SlotState::Dormant)
            { return TOptional<int32>(Index); }
        }

        return TOptional<int32>();
    }

    // A slot an emergence may take at InNow: Dormant, or a dead cooldown that has run out.
    bool Get_IsAvailable(const FMars_RatDen_Resident& InResident, float32 InNow)
    {
        if (InResident.State == EMars_RatDen_SlotState::Dormant)
        { return true; }

        return InResident.State == EMars_RatDen_SlotState::DeadCooldown && InResident.DeadUntil <= InNow;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin int32 Get_ResidentCount(const FCk_Handle_RatDen& Self)
{
    return Self.Get_Fragment(FMars_Fragment_RatDen).Residents.Num();
}

mixin EMars_RatDen_SlotState Get_SlotState(const FCk_Handle_RatDen& Self, int32 InSlot)
{
    return Self.Get_Fragment(FMars_Fragment_RatDen).Residents[InSlot].State;
}

mixin int32 Get_SlotOperationId(const FCk_Handle_RatDen& Self, int32 InSlot)
{
    return Self.Get_Fragment(FMars_Fragment_RatDen).Residents[InSlot].OperationId;
}

// The lowest slot an emergence may take at InNow (raid clock); unset when every resident is out, pending or cooling down.
mixin TOptional<int32> Get_AvailableSlot(const FCk_Handle_RatDen& Self, float32 InNow)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_RatDen);
    for (int32 Index = 0; Index < State.Residents.Num(); ++Index)
    {
        if (utils_rat_den::Get_IsAvailable(State.Residents[Index], InNow))
        { return TOptional<int32>(Index); }
    }

    return TOptional<int32>();
}

mixin int32 Get_SlotCountIn(const FCk_Handle_RatDen& Self, EMars_RatDen_SlotState InState)
{
    auto Count = 0;
    for (const auto& Resident : Self.Get_Fragment(FMars_Fragment_RatDen).Residents)
    {
        if (Resident.State == InState)
        { ++Count; }
    }

    return Count;
}

// Unset = the eye plate is black (no hidden resident, or eyes disabled).
mixin TOptional<int32> Get_EyeSlot(const FCk_Handle_RatDen& Self)
{
    return Self.Get_Fragment(FMars_Fragment_RatDen).EyeSlot;
}

mixin bool Get_EyesShown(const FCk_Handle_RatDen& Self)
{
    return Self.Get_Fragment(FMars_Fragment_RatDen).EyeSlot.IsSet();
}

mixin int32 Get_RefusedReturns(const FCk_Handle_RatDen& Self)
{
    return Self.Get_Fragment(FMars_Fragment_RatDen).RefusedReturns;
}

mixin int32 Get_StaleRequests(const FCk_Handle_RatDen& Self)
{
    return Self.Get_Fragment(FMars_Fragment_RatDen).StaleRequests;
}

mixin FMars_RatDen_Portals Get_Portals(const FCk_Handle_RatDen& Self)
{
    return Self.Get_Fragment(FMars_Fragment_RatDen_Params).Portals;
}

mixin FCk_Handle_UnrealComponent Get_EyePlate(const FCk_Handle_RatDen& Self)
{
    return Self.Get_Fragment(FMars_Fragment_RatDen_Params).EyePlate;
}

// InPortal's marker in the world, from the den's current transform.
mixin FVector Get_PortalWorld(const FCk_Handle_RatDen& Self, EMars_RatDen_Portal InPortal)
{
    const auto Portals = Self.Get_Portals();
    auto Local = Portals.OutsideStand;
    if (InPortal == EMars_RatDen_Portal::EntryPortal)
    { Local = Portals.EntryPortal; }
    else if (InPortal == EMars_RatDen_Portal::ExitPortal)
    { Local = Portals.ExitPortal; }
    else if (InPortal == EMars_RatDen_Portal::ReturnAdmission)
    { Local = Portals.ReturnAdmission; }
    else if (InPortal == EMars_RatDen_Portal::Inside)
    { Local = Portals.Inside; }

    return utils_transform::Get_EntityCurrentTransform(Self.As_Transform()).TransformPosition(Local);
}

// The den's facing out of its opening (+X of the den frame) in the world.
mixin FVector Get_OutwardWorld(const FCk_Handle_RatDen& Self)
{
    return utils_transform::Get_EntityCurrentTransform(Self.As_Transform()).GetRotation().GetForwardVector();
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Emerge(FCk_Handle_RatDen& Self, const FMars_Request_RatDen_Emerge& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_RatDen_Requests);
    Requests.EmergeRequests.Add(InRequest);
}

mixin void Request_MarkOutside(FCk_Handle_RatDen& Self, const FMars_Request_RatDen_MarkOutside& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_RatDen_Requests);
    Requests.MarkOutsideRequests.Add(InRequest);
}

mixin void Request_AdmitReturn(FCk_Handle_RatDen& Self, const FMars_Request_RatDen_AdmitReturn& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_RatDen_Requests);
    Requests.AdmitReturnRequests.Add(InRequest);
}

mixin void Request_ResidentDied(FCk_Handle_RatDen& Self, const FMars_Request_RatDen_ResidentDied& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_RatDen_Requests);
    Requests.ResidentDiedRequests.Add(InRequest);
}

mixin void Request_SetEyes(FCk_Handle_RatDen& Self, const FMars_Request_RatDen_SetEyes& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_RatDen_Requests);
    Requests.SetEyesRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnEmergeReady(FCk_Handle_RatDen& Self, FMars_Delegate_RatDen_OnEmergeReady InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_RatDen_Signals);
    Fragment.OnEmergeReady.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnEmergeReady(FCk_Handle_RatDen& Self, FMars_Delegate_RatDen_OnEmergeReady InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_RatDen_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_RatDen_Signals).OnEmergeReady.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnResidentReturned(FCk_Handle_RatDen& Self, FMars_Delegate_RatDen_OnResidentReturned InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_RatDen_Signals);
    Fragment.OnResidentReturned.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnResidentReturned(FCk_Handle_RatDen& Self, FMars_Delegate_RatDen_OnResidentReturned InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_RatDen_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_RatDen_Signals).OnResidentReturned.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnReturnRefused(FCk_Handle_RatDen& Self, FMars_Delegate_RatDen_OnReturnRefused InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_RatDen_Signals);
    Fragment.OnReturnRefused.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnReturnRefused(FCk_Handle_RatDen& Self, FMars_Delegate_RatDen_OnReturnRefused InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_RatDen_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_RatDen_Signals).OnReturnRefused.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnEyesChanged(FCk_Handle_RatDen& Self, FMars_Delegate_RatDen_OnEyesChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_RatDen_Signals);
    Fragment.OnEyesChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnEyesChanged(FCk_Handle_RatDen& Self, FMars_Delegate_RatDen_OnEyesChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_RatDen_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_RatDen_Signals).OnEyesChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
