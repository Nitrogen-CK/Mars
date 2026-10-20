// A world-item spec is accepted as a Visual item with only a Definition, a Visual item with an Arrival, and a World item
// with a Holder, a Pickup and a Body with its profile. It is rejected, naming the rule, with no Definition, a Visual item
// carrying World parts, a World item carrying an Arrival, a World item without World parts or without a Holder or a
// Pickup, a launch without a Body, and a Body with no BodyProfile. The parts are bare: an empty holder, a probe-less
// interactable and a static box body. Isolated band: (72000, -40000, -30000).
class UMars_AutoTest_WorldItem_SpecValidateRejectsMixedModes : UCk_AutoTest_Base
{
    private const FVector k_Origin = FVector(72000.0, -40000.0, -30000.0);

    private FCk_Handle_Inventory_DataOnly _Holder;
    private FCk_Handle_Interactable _Pickup;
    private FCk_Handle_JoltBody _Body;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, k_Origin), ECk_Replication::DoesNotReplicate);

        auto HolderParams = utils_inventory_data_only::Make_Params_Bounded(
            GameplayTags::Inventory_Mars_WorldItemHolder, 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(),
            FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        _Holder = utils_inventory_data_only::Add(Entity, HolderParams, ECk_Replication::DoesNotReplicate);
        _Pickup = utils_interactable::Create(Root, FMars_Interactable_Spec());

        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(5.0, 5.0, 5.0));
        auto BodySpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BodySpec.Set_ShapeDimensions(Shape);
        BodySpec.Set_MotionType(ECk_MotionType::Static);
        BodySpec.Set_CollisionProfileName(constants_world_item::k_DefaultBodyProfile);
        _Body = utils_jolt_body::Add(Entity, BodySpec);

        Add_Step("validate the spec rules", n"Step_Validate");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Visual = Make_Visual().Validate();
        Assert_True(Visual.IsValid(), f"a Visual item with only a Definition is valid ({Visual.Get_Error()})");

        auto Arriving = Make_Visual();
        Arriving.Arrival = TOptional<FMars_Fragment_WorldItem_Arrival>(FMars_Fragment_WorldItem_Arrival());
        const auto ArrivingResult = Arriving.Validate();
        Assert_True(ArrivingResult.IsValid(), f"a Visual item with an Arrival is valid ({ArrivingResult.Get_Error()})");

        const auto WorldResult = Make_World().Validate();
        Assert_True(WorldResult.IsValid(), f"a World item with a Holder, a Pickup and a profiled Body is valid ({WorldResult.Get_Error()})");

        auto NoDefinition = Make_Visual();
        NoDefinition.Definition = TSoftObjectPtr<UCk_InventoryItem_Definition>();
        AssertRejected(NoDefinition, "Definition", "a spec with no Definition");

        auto VisualWithParts = Make_World();
        VisualWithParts.Mode = EMars_WorldItem_Mode::Visual;
        AssertRejected(VisualWithParts, "Visual-mode world item has no World parts", "a Visual item with World parts");

        auto WorldWithArrival = Make_World();
        WorldWithArrival.Arrival = TOptional<FMars_Fragment_WorldItem_Arrival>(FMars_Fragment_WorldItem_Arrival());
        AssertRejected(WorldWithArrival, "only a Visual-mode world item arrives", "a World item with an Arrival");

        auto WorldWithoutParts = Make_World();
        WorldWithoutParts.World.Reset();
        AssertRejected(WorldWithoutParts, "needs its World parts", "a World item with no World parts");

        auto Parts = Make_Parts();
        Parts.Holder = FCk_Handle_Inventory_DataOnly();
        AssertRejected(Make_WorldOf(Parts), "a Holder and a Pickup", "a World item with no Holder");

        Parts = Make_Parts();
        Parts.Pickup = FCk_Handle_Interactable();
        AssertRejected(Make_WorldOf(Parts), "a Holder and a Pickup", "a World item with no Pickup");

        Parts = Make_Parts();
        Parts.Composition.Body = FCk_Handle_JoltBody();
        Parts.Composition.Launch = TOptional<FMars_Fragment_WorldItem_PendingLaunch>(
            FMars_Fragment_WorldItem_PendingLaunch(FVector(0.0, 0.0, 100.0), FVector::ZeroVector));
        AssertRejected(Make_WorldOf(Parts), "a launch needs a Body", "a launch without a Body");

        Parts = Make_Parts();
        Parts.Composition.BodyProfile = NAME_None;
        AssertRejected(Make_WorldOf(Parts), "BodyProfile", "a Body with no BodyProfile");
    }

    private FMars_WorldItem_Spec Make_Visual() const
    {
        auto Spec = FMars_WorldItem_Spec();
        Spec.Mode = EMars_WorldItem_Mode::Visual;
        Spec.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Rock());
        return Spec;
    }

    private FMars_WorldItem_WorldParts Make_Parts() const
    {
        auto Composition = FMars_WorldItem_Composition();
        Composition.Body = _Body;
        Composition.BodyProfile = constants_world_item::k_DefaultBodyProfile;
        return FMars_WorldItem_WorldParts(_Holder, _Pickup, Composition);
    }

    private FMars_WorldItem_Spec Make_WorldOf(const FMars_WorldItem_WorldParts& InParts) const
    {
        auto Spec = FMars_WorldItem_Spec();
        Spec.Mode = EMars_WorldItem_Mode::World;
        Spec.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Rock());
        Spec.World = TOptional<FMars_WorldItem_WorldParts>(InParts);
        return Spec;
    }

    private FMars_WorldItem_Spec Make_World() const
    {
        return Make_WorldOf(Make_Parts());
    }

    private void AssertRejected(const FMars_WorldItem_Spec& InSpec, const FString& InRule, const FString& InWhat)
    {
        const auto Result = InSpec.Validate();
        Assert_False(Result.IsValid(), f"{InWhat} is rejected");
        Assert_True(Result.Get_Error().Contains(InRule), f"the rejection of {InWhat} names [{InRule}] (got [{Result.Get_Error()}])");
    }
}
