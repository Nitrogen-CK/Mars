namespace utils_anchor_resolver
{
    FCk_Handle_AnchorResolver Add(FCk_Handle& InHandle, FMars_AnchorResolver_Spec InSpec)
    {
        auto Params = FMars_Fragment_AnchorResolver_Params();
        Params.Result = InSpec.Result;

        InHandle.Add_Fragment(FMars_Feature_AnchorResolver());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(FMars_Fragment_AnchorResolver());
        utils_entity_tag::Add(InHandle, n"TAG_MarsAnchorResolver");
        return InHandle.As_AnchorResolver();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_AnchorRun_Result Get_Result(const FCk_Handle_AnchorResolver& Self)
{ return Self.Get_Fragment(FMars_Fragment_AnchorResolver_Params).Result; }

mixin TArray<FMars_AnchorLedger_Entry> Get_Ledger(const FCk_Handle_AnchorResolver& Self)
{ return Self.Get_Fragment(FMars_Fragment_AnchorResolver).Ledger; }

mixin TOptional<FMars_AnchorLedger_Entry> TryGet_LedgerEntry(const FCk_Handle_AnchorResolver& Self, FName InAnchorId)
{
    for (const auto& Entry : Self.Get_Fragment(FMars_Fragment_AnchorResolver).Ledger)
    {
        if (Entry.AnchorId == InAnchorId)
        { return TOptional<FMars_AnchorLedger_Entry>(Entry); }
    }
    return TOptional<FMars_AnchorLedger_Entry>();
}

// Ids the run's result planned for that no anchor in this world has resolved yet, sorted.
mixin TArray<FName> Get_UnmatchedPlannedIds(const FCk_Handle_AnchorResolver& Self)
{
    auto Unmatched = TArray<FName>();
    for (const auto& Entry : Self.Get_Result().Roles)
    {
        if (Self.TryGet_LedgerEntry(Entry.AnchorId).IsSet() == false)
        { Unmatched.Add(Entry.AnchorId); }
    }
    utils_anchor_resolver::Sort_Names(Unmatched);
    return Unmatched;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_ResolveAnchor(FCk_Handle_AnchorResolver& Self, const FMars_Request_AnchorResolver_ResolveAnchor& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_AnchorResolver_Requests);
    Requests.ResolveAnchor.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnAnchorResolved(FCk_Handle_AnchorResolver& Self, FMars_Delegate_AnchorResolver_OnAnchorResolved InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_AnchorResolver_Signals);
    Fragment.OnAnchorResolved.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnAnchorResolved(FCk_Handle_AnchorResolver& Self, FMars_Delegate_AnchorResolver_OnAnchorResolved InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_AnchorResolver_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_AnchorResolver_Signals).OnAnchorResolved.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
