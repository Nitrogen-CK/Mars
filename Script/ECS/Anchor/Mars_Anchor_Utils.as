namespace utils_anchor
{
    // A spec that fails Validate() ensures and adds nothing. Composition is synchronous, so the discovery tag is stamped
    // here, last: a tagged entity always carries the whole feature.
    FCk_Handle_Anchor Add(FCk_Handle& InHandle, FMars_Anchor_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Anchor] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Anchor(); }

        auto Params = FMars_Fragment_Anchor_Params();
        Params.AnchorId = InSpec.AnchorId;
        Params.Family = InSpec.Family;
        Params.Table = InSpec.Table;
        Params.Transform = InSpec.Transform;
        Params.Channel = InSpec.Channel;
        Params.SpanCm = InSpec.SpanCm;
        Params.HomeRadiusCm = InSpec.HomeRadiusCm;
        Params.LeverSide = InSpec.LeverSide;
        Params.CrawlOffsetCm = InSpec.CrawlOffsetCm;
        Params.PinnedRow = InSpec.PinnedRow;
        Params.GateMaterialOverride = InSpec.GateMaterialOverride;

        InHandle.Add_Fragment(FMars_Feature_Anchor());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(FMars_Fragment_Anchor());
        utils_entity_tag::Add(InHandle, n"TAG_MarsAnchor");
        return InHandle.As_Anchor();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FGameplayTag Get_AnchorId(const FCk_Handle_Anchor& Self)
{ return Self.Get_Fragment(FMars_Fragment_Anchor_Params).AnchorId; }

mixin EMars_Anchor_Family Get_Family(const FCk_Handle_Anchor& Self)
{ return Self.Get_Fragment(FMars_Fragment_Anchor_Params).Family; }

mixin UMars_AnchorTable_Def Get_Table(const FCk_Handle_Anchor& Self)
{ return Self.Get_Fragment(FMars_Fragment_Anchor_Params).Table.Get(); }

mixin FTransform Get_Transform(const FCk_Handle_Anchor& Self)
{ return Self.Get_Fragment(FMars_Fragment_Anchor_Params).Transform; }

mixin FGameplayTag Get_Channel(const FCk_Handle_Anchor& Self)
{ return Self.Get_Fragment(FMars_Fragment_Anchor_Params).Channel; }

mixin float32 Get_SpanCm(const FCk_Handle_Anchor& Self)
{ return Self.Get_Fragment(FMars_Fragment_Anchor_Params).SpanCm; }

mixin float32 Get_HomeRadiusCm(const FCk_Handle_Anchor& Self)
{ return Self.Get_Fragment(FMars_Fragment_Anchor_Params).HomeRadiusCm; }

mixin TOptional<int32> Get_PinnedRow(const FCk_Handle_Anchor& Self)
{ return Self.Get_Fragment(FMars_Fragment_Anchor_Params).PinnedRow; }

mixin EMars_Anchor_LeverSide Get_LeverSide(const FCk_Handle_Anchor& Self)
{ return Self.Get_Fragment(FMars_Fragment_Anchor_Params).LeverSide; }

mixin TOptional<FVector2D> Get_CrawlOffsetCm(const FCk_Handle_Anchor& Self)
{ return Self.Get_Fragment(FMars_Fragment_Anchor_Params).CrawlOffsetCm; }

mixin UMaterialInterface Get_GateMaterialOverride(const FCk_Handle_Anchor& Self)
{ return Self.Get_Fragment(FMars_Fragment_Anchor_Params).GateMaterialOverride.Get(); }

mixin EMars_Anchor_State Get_State(const FCk_Handle_Anchor& Self)
{ return Self.Get_Fragment(FMars_Fragment_Anchor).State; }

mixin EMars_Anchor_Role Get_Role(const FCk_Handle_Anchor& Self)
{ return Self.Get_Fragment(FMars_Fragment_Anchor).Role; }

mixin TOptional<int32> Get_RowIndex(const FCk_Handle_Anchor& Self)
{ return Self.Get_Fragment(FMars_Fragment_Anchor).RowIndex; }

mixin FCk_Handle Get_Spawned(const FCk_Handle_Anchor& Self)
{ return Self.Get_Fragment(FMars_Fragment_Anchor).Spawned; }

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Resolve(FCk_Handle_Anchor& Self, const FMars_Request_Anchor_Resolve& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Anchor_Requests);
    Requests.Resolve.Add(InRequest);
}

mixin void Request_Clear(FCk_Handle_Anchor& Self, const FMars_Request_Anchor_Clear& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Anchor_Requests);
    Requests.Clear.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnResolved(FCk_Handle_Anchor& Self, FMars_Delegate_Anchor_OnResolved InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Anchor_Signals);
    Fragment.OnResolved.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnResolved(FCk_Handle_Anchor& Self, FMars_Delegate_Anchor_OnResolved InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Anchor_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Anchor_Signals).OnResolved.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
