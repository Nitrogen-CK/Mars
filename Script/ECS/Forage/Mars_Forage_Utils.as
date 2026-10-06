namespace utils_forage
{
    // The entity script composes the release point first and hands it in through InSpec.Parts; whatever triggers the
    // releases (a strike, a knock, a pluck) is composed and bound by that script too. A rejected spec ensures and returns
    // an invalid handle with nothing composed.
    FCk_Handle_Forage Add(FCk_Handle& InHandle, FMars_Forage_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Forage] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Forage(); }

        auto Params = FMars_Fragment_Forage_Params();
        Params.Yield = InSpec.Yield;
        Params.Exhaustion = InSpec.Exhaustion;
        Params.Launch = InSpec.Launch;

        auto State = FMars_Fragment_Forage();
        State.ReleasePoint = InSpec.Parts.ReleasePoint;
        State.ChargesLeft = InSpec.Yield.Charges;

        InHandle.Add_Fragment(FMars_Feature_Forage());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        return InHandle.As_Forage();
    }

    // True when a contact is a knock: the other body is a World-mode world item (a thrown or dropped thing, never a floor,
    // a character or a mounted item) closing at InMinSpeed or more (uu/s, the payload's RelativeNormalSpeed).
    bool Get_IsKnock(const FCk_JoltBody_Payload_OnContact& InPayload, float32 InMinSpeed)
    {
        auto OtherEntity = InPayload.Get_OtherEntity();
        auto Other = OtherEntity.As_WorldItem(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Other) || Other.Get_Mode() != EMars_WorldItem_Mode::World)
        { return false; }

        return InPayload.Get_RelativeNormalSpeed() >= InMinSpeed;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

// Null when the soft reference does not resolve.
mixin UCk_InventoryItem_Definition Get_Definition(const FCk_Handle_Forage& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Forage_Params).Yield.Definition.Get();
}

mixin EMars_Forage_Exhaustion Get_ExhaustionPolicy(const FCk_Handle_Forage& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Forage_Params).Exhaustion.Policy;
}

mixin int32 Get_ChargesLeft(const FCk_Handle_Forage& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Forage).ChargesLeft;
}

mixin bool Get_IsExhausted(const FCk_Handle_Forage& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Forage).IsExhausted;
}

mixin int32 Get_ReleasedCount(const FCk_Handle_Forage& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Forage).ReleasedCount;
}

mixin FCk_Handle_Transform Get_ReleasePoint(const FCk_Handle_Forage& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Forage).ReleasePoint;
}

mixin bool Get_IsRegrowPending(const FCk_Handle_Forage& Self)
{
    return ck::IsValid(Self.Get_Fragment(FMars_Fragment_Forage).RegrowTimer);
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Release(FCk_Handle_Forage& Self, const FMars_Request_Forage_Release& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Forage_Requests);
    Requests.ReleaseRequests.Add(InRequest);
}

mixin void Request_Replenish(FCk_Handle_Forage& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Forage_Requests);
    Requests.ReplenishRequests.Add(FMars_Request_Forage_Replenish());
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnReleased(FCk_Handle_Forage& Self, FMars_Delegate_Forage_OnReleased InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Forage_Signals);
    Fragment.OnReleased.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnReleased(FCk_Handle_Forage& Self, FMars_Delegate_Forage_OnReleased InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Forage_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Forage_Signals).OnReleased.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnExhausted(FCk_Handle_Forage& Self, FMars_Delegate_Forage_OnExhausted InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Forage_Signals);
    Fragment.OnExhausted.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnExhausted(FCk_Handle_Forage& Self, FMars_Delegate_Forage_OnExhausted InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Forage_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Forage_Signals).OnExhausted.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnReplenished(FCk_Handle_Forage& Self, FMars_Delegate_Forage_OnReplenished InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Forage_Signals);
    Fragment.OnReplenished.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnReplenished(FCk_Handle_Forage& Self, FMars_Delegate_Forage_OnReplenished InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Forage_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Forage_Signals).OnReplenished.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
