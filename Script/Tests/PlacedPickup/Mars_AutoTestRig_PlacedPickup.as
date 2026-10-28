struct FMars_PlacedPickup_TestSpec
{
    FVector Origin;
    UCk_InventoryItem_Definition Definition;
    FVector2D HalfExtents = FVector2D(40.0, 40.0);
    float64 SupportOffset = -30.0;
    FName Id = n"PlacedPickup.Test";
}

UCLASS(Abstract)
class UMars_AutoTestRig_PlacedPickup : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 15.0f;

    protected FCk_Handle _Proxy;
    protected FCk_Handle_WorldItem _Placed;
    protected FVector _SupportTop;
    protected FVector2D _Footprint;
    protected TArray<FCk_Handle> _Floors;
    private FCk_Handle _FixtureOwner;

    protected void Build_Proxy(FCk_Handle InOwner, const FMars_PlacedPickup_TestSpec& InSpec)
    {
        _FixtureOwner = InOwner;
        _SupportTop = InSpec.Origin + FVector(0.0, 0.0, InSpec.SupportOffset);
        _Footprint = InSpec.HalfExtents;
        auto Params = UMars_PlacedPickup_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator(0.0, 23.0, 0.0), InSpec.Origin);
        Params.FixtureId = InSpec.Id;
        Params.Definition = utils_held_item::Make_DefinitionSoft(InSpec.Definition);
        Params.SupportHeightOffsetCm = InSpec.SupportOffset;
        Params.SupportHalfExtentsCm = InSpec.HalfExtents;
        _Proxy = utils_entity_script::Request_SpawnEntity(InOwner, UMars_PlacedPickup_EntityScript, Params).Get_EntityUnderConstruction();
        Track_ForCleanup(_Proxy);
    }

    // A real native mesh component, automatically baked into the Jolt STATIC domain. A standalone JoltBody static box
    // would exercise a different query domain and cannot prove the placed proxy's support predicate.
    protected void Add_Support(FVector InTop, FVector2D InHalfExtents)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(_FixtureOwner);
        auto Root = utils_transform::Add(Entity, FTransform(InTop), ECk_Replication::DoesNotReplicate);
        Root.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -5.0), FVector(InHalfExtents.X * 0.02, InHalfExtents.Y * 0.02, 0.1)),
            engine::load::Cube(), assets::load::ProtoGrid_Platform_Mars_MI(), collision::profile::BlockAll, n"PlacedPickup_TestSupport"));
        _Floors.Add(Entity);
        Track_ForCleanup(Entity);
    }

    protected TArray<FVector> Get_Witnesses() const
    {
        TArray<FVector> Points;
        Points.Add(_SupportTop);
        Points.Add(_SupportTop + FVector(-_Footprint.X, -_Footprint.Y, 0.0));
        Points.Add(_SupportTop + FVector(-_Footprint.X, _Footprint.Y, 0.0));
        Points.Add(_SupportTop + FVector(_Footprint.X, -_Footprint.Y, 0.0));
        Points.Add(_SupportTop + FVector(_Footprint.X, _Footprint.Y, 0.0));
        return Points;
    }

    protected int32 Get_SupportMask() const
    {
        const auto Points = Get_Witnesses();
        int32 Mask = 0;
        for (int32 Index = 0; Index < Points.Num(); ++Index)
        {
            const auto Point = Points[Index];
            const auto Hit = utils_jolt_static_world::Get_RayCastStaticWorld(Point + FVector(0.0, 0.0, 5.0), Point - FVector(0.0, 0.0, 5.0));
            if (Hit.Get_HasHit() && Math::Abs(Hit.Get_Position().Z - Point.Z) <= 2.0)
            { Mask |= (1 << Index); }
        }
        return Mask;
    }

    protected TArray<FCk_Handle> Get_ProxyWorldItems() const
    {
        TArray<FCk_Handle> Items;
        for (auto Entity : utils_entity_tag::ForEach_Entity(_FixtureOwner, n"TAG_MarsWorldItem"))
        {
            if (ck::IsValid(Entity) && utils_entity_lifetime::Get_LifetimeOwner(Entity) == _Proxy)
            { Items.Add(Entity); }
        }
        return Items;
    }

    protected bool Get_PlacedReady()
    {
        const auto Items = Get_ProxyWorldItems();
        if (Items.Num() != 1 || Items[0].Is_WorldItem() == false)
        { return false; }
        _Placed = Items[0].As_WorldItem();
        const auto Body = _Placed.Get_Body();
        return ck::IsValid(_Placed.Get_HeldItem()) && ck::IsValid(Body) && Body.Get_IsBodyAdded();
    }

    protected void Assert_NoPickup()
    {
        Assert_Equals_Int(Get_ProxyWorldItems().Num(), 0, "no real original WorldItem was constructed");
        Assert_False(_Proxy.Is_WorldItem(), "proxy itself has no WorldItem feature");
        Assert_False(_Proxy.Is_JoltBody(), "proxy itself has no physics body");
        Assert_False(_Proxy.Is_Interactable(), "proxy itself has no pickup prompt");
        Assert_True(utils_entity_tag::Has(_Proxy, n"TAG_MarsPlacedPickupWaiting"), "fixture remains waiting");
    }

    protected void Destroy_Floors()
    {
        for (auto Floor : _Floors)
        { utils_entity_lifetime::Request_DestroyEntity(Floor); }
        _Floors.Empty();
    }

    UFUNCTION()
    protected void Check_ProxyWaiting(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Proxy) && utils_entity_tag::Has(_Proxy, n"TAG_MarsPlacedPickupWaiting")
            && utils_timer::ForEach_Timer(_Proxy, FInstancedStruct()).Num() == 1);
    }

    UFUNCTION()
    protected void Check_PlacedReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    { auto Result = OutResult; Result.Set(Get_PlacedReady()); }

    UFUNCTION()
    protected void Step_DestroyFixture(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::IsValid(_Proxy))
        { utils_entity_lifetime::Request_DestroyEntity(_Proxy); }
        Destroy_Floors();
    }

    UFUNCTION()
    protected void Check_FixtureGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::Is_NOT_Valid(_Proxy) && ck::Is_NOT_Valid(_Placed) && Get_SupportMask() == 0);
    }
}
