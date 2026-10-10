// A large platter spawned onto a floor with the meat slab's food item loaded onto it (the kernel path): the food item composes
// the whole joint, dresses it when it is Ready, and once the tray lies still the platter drops it between the walls: the
// held piece is the whole beef joint, wearing its display, frozen on the root with its bounds centre inside the walls. It
// also measures the tray mesh the item's Bounds are derived from: the outer bounds of PrepTray_Mars_SM are 26 x 30 x 8 with
// the pivot 1.5 above the underside, and the large platter's walls (Bounds x MeshScale) clear its planks.
class UMars_AutoTest_Platter_SpawnWithFoodLoadsADressedJoint : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(14000.0, -15000.0, -30000.0);

    // The spawned platter entity, under construction until it is a Platter.
    private FCk_Handle _Entity;
    private FCk_Handle_Platter _Platter;
    private FCk_Handle_FoodPiece _Piece;
    private UMars_AutoTestHelper_FoodOnPlatter _FoodOnPlatter;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Owner = InHandle;
        Spawn_Floor(Owner);
        _Entity = utils_platter::Request_SpawnWorld(Owner, FMars_Platter_SpawnSpec(
            FTransform(FRotator::ZeroRotator, k_Origin + FVector(0.0, 0.0, constants_platter::k_FloorAboveBase + 0.5)),
            mars_items::Platter_Large()));

        _FoodOnPlatter = Cast<UMars_AutoTestHelper_FoodOnPlatter>(NewObject(this, UMars_AutoTestHelper_FoodOnPlatter));
        Track_ForCleanup(_FoodOnPlatter.Spawn_Onto(_Entity, mars_items::Food_MeatSlab(),
            FTransform(FRotator::ZeroRotator, k_Origin + FVector(0.0, 0.0, 60.0))));

        Add_Step("measure the tray mesh", n"Step_MeasureTheTray");
        Add_Step_WaitUntil("the platter holds one piece", n"Check_HoldsOne");
        Add_Step_WaitFrames("the attach composes the world pose", 2);
        Add_Step("the piece is the dressed whole beef joint, frozen inside the walls", n"Step_AssertDressedJoint");
        Run_Steps(InHandle);
    }

    // A static slab the tray lies on, its top at the origin.
    private void Spawn_Floor(FCk_Handle& InOwner)
    {
        auto Floor = utils_entity_lifetime::Request_CreateEntity(InOwner);
        utils_transform::Add(Floor, FTransform(FRotator::ZeroRotator, k_Origin - FVector(0.0, 0.0, 1.0)), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(100.0, 100.0, 1.0));
        auto FloorSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        FloorSpec.Set_ShapeDimensions(Shape);
        FloorSpec.Set_MotionType(ECk_MotionType::Static);
        FloorSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Floor, FloorSpec);
    }

    UFUNCTION()
    private void Step_MeasureTheTray(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Bounds = assets::load::PrepTray_Mars_SM().GetBounds();
        const auto Min = Bounds.Origin - Bounds.BoxExtent;
        const auto Max = Bounds.Origin + Bounds.BoxExtent;
        Log(f"[Mars_AutoTest_Platter_SpawnWithFoodLoadsADressedJoint] PrepTray_Mars_SM bounds min {Min} max {Max} (size {Max - Min})");
        Assert_True((Max - Min).Equals(FVector(26.0, 30.0, 8.0), 0.5), f"the tray mesh is 26 x 30 x 8 (got {Max - Min})");
        Assert_True(Math::Abs(Min.Z + constants_platter::k_FloorAboveBase) <= 0.25, f"the pivot sits 1.5 above the underside (min Z {Min.Z})");

        // The inner floor (rope 0.55, wall inset 0.5, 1.6 cm planks off each outer half) x MeshScale: the walls' outer faces
        // stay inside it.
        const UMars_ItemTrait_Platter Trait = mars_items::Platter_Large().Get_ItemTraitByClass(UMars_ItemTrait_Platter);
        const auto Half = Trait.Platter.Bounds.InnerHalfExtents;
        const auto InnerX = (Max.X - 0.546 - 0.5 - 1.6) * 1.8;
        const auto InnerY = (Max.Y - 0.546 - 0.5 - 1.6) * 1.8;
        const auto WallOuterX = Half.X + constants_platter::k_WallThicknessCm * 0.5;
        const auto WallOuterY = Half.Y + constants_platter::k_WallThicknessCm * 0.5;
        Log(f"[Mars_AutoTest_Platter_SpawnWithFoodLoadsADressedJoint] large inner floor half ({InnerX}, {InnerY}); walls' outer faces at ({WallOuterX}, {WallOuterY})");
        Assert_True(WallOuterX < InnerX && WallOuterY < InnerY, "the large platter's walls stand clear of its planks");
    }

    UFUNCTION()
    private void Check_HoldsOne(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Platter) && ck::IsValid(_Entity) && _Entity.Is_Platter())
        { _Platter = _Entity.As_Platter(); }

        const auto HoldsOne = ck::IsValid(_Platter) && _Platter.Get_HeldCount() == 1;
        if (HoldsOne && ck::Is_NOT_Valid(_Piece))
        {
            const auto Held = _Platter.Get_Held();
            _Piece = Held[0];
            Track_ForCleanup(_Piece);
        }

        auto Res = OutResult;
        Res.Set(HoldsOne);
    }

    UFUNCTION()
    private void Step_AssertDressedJoint(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Platter.Get_Capacity(), 12, "the large platter takes twelve");
        Assert_True(_Piece.Get_Status() == EMars_FoodPiece_Status::Ready, "the joint is Ready");
        Assert_True(_Piece.Get_IsWhole(), "the joint is whole");
        Assert_True(_Piece.Get_Kind().HasTag(GameplayTags::Food_Meat_Beef), "the joint is beef");
        Assert_True(_Piece.Get_Definition().Get() == mars::Food_MeatSlab_Mars, "the joint's definition is the meat slab");

        FCk_Handle PieceEntity = _Piece;
        Assert_True(PieceEntity.Is_RuntimeMeshDisplay(), "the joint wears its display (added when it readied)");
        Assert_True(PieceEntity.Is_JoltBody() && utils_jolt_body::Get_MotionType(PieceEntity.As_JoltBody()) == ECk_MotionType::Kinematic,
            "the joint's body reads Kinematic");

        auto Node = PieceEntity.As_SceneNode(ECk_SanityCheck::UnChecked);
        FCk_Handle PlatterEntity = _Platter;
        Assert_True(ck::IsValid(Node) && utils_scene_node::Get_Parent(Node) == PlatterEntity.As_Transform(), "the joint rides the platter root");

        const auto PlatterWorld = utils_transform::Get_EntityCurrentTransform(PlatterEntity.As_Transform());
        Assert_True(utils_platter::Get_IsInside(_Platter.Get_Spec().Bounds, PlatterWorld, _Piece),
            f"the joint's bounds centre lies inside the walls (joint at {utils_transform::Get_EntityCurrentTransform(PieceEntity.As_Transform()).GetLocation()}, tray at {PlatterWorld.GetLocation()})");
    }
}
