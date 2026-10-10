// The pile on a mounted platter never shoves a pawn. A carrier holds a platter (stowed into the overflow: Held) and a box
// is loaded onto it; it lands and freezes on the tray. A Jolt character (a CharacterVirtual, profile Pawn) then stands on a
// small static plate inside the box, just above the tray's floor: it overlaps the box and nothing else of the platter (the
// tray's planks are below the plate, its walls ignore pawns). Held, the box ignores pawns: over a second the character
// does not move. Released, the platter lands on a floor just under its base and the box collides as its own profile again:
// it pushes the character out. Isolated origin (56400, -12000, -30000).
class UMars_AutoTest_Platter_AMountedPlattersPiecesIgnorePawns : UMars_AutoTestRig_PlatterDock
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(56400.0, -12000.0, -30000.0);
    private const float32 k_CharacterRadius = 3.0f;
    private const float32 k_CharacterHalfHeight = 3.0f;
    // The stand: a plate this far above the tray's floor (the platter root), clear of the planks.
    private const float64 k_StandBottomAboveFloorCm = 0.5;
    private const float64 k_StandHalfThicknessCm = 0.25;
    private const float64 k_StandHalfWidthCm = 3.5;
    // The floor the released platter lands on, this far under the tray's base.
    private const float64 k_LandingGapCm = 0.3;
    // Jolt's character padding: the most a character resting on its stand floats above it.
    private const float64 k_RestSlackCm = 2.5;
    private const float64 k_StillCm = 0.1;
    private const float64 k_PushedCm = 2.0;
    private const float64 k_WatchSeconds = 1.0;
    // The platter's construction and the box's mesh import outrun the default poll budget at lane frame rate.
    private const int32 k_SlowPolls = 900;

    private FCk_Handle_FoodPiece _Box;
    private FCk_Handle _CharacterEntity;
    private FCk_Handle_JoltCharacter _Character;
    private float64 _StandTop = 0.0;
    private FVector _Baseline;
    private float64 _WatchStart = 0.0;
    private float64 _MaxDisplacement = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);

        Spawn_Platter(InHandle, FMars_Platter_SpawnSpec(FTransform(FRotator::ZeroRotator, k_Origin + FVector(200.0, 0.0, 0.0))));
        _Box = Build_Box(FTransform(FRotator::ZeroRotator, k_Origin + FVector(300.0, 0.0, 0.0)));

        Add_Step_WaitUntil("the platter is constructed and the box is Ready", n"Check_Ready", k_SlowPolls, 0);
        Add_Step("stow the platter into the overflow", n"Step_Stow");
        Add_Step_WaitUntil("the platter settles Held and Mounted", n"Check_HeldAndMounted", 0, 0);
        Add_Step("load the box onto the held platter", n"Step_Load");
        Add_Step_WaitUntil("the box landed", n"Check_BoxLanded", 0, 0);
        Add_Step_WaitFrames("the attach composes the world pose", 2);
        Add_Step("a landing floor under the tray, a stand inside the box, a character on the stand", n"Step_PlaceCharacter");
        Add_Step_WaitUntil("the character stands", n"Check_CharacterOnGround", 0, 0);
        Add_Step_WaitSeconds("the character comes to rest", 0.25f);
        Add_Step("it rests on its stand inside the box; watch it", n"Step_StartWatch");
        Add_Step_WaitUntil("a second passes", n"Check_WatchedASecond", 0, 0);
        Add_Step("the held platter's box never moved it; release the platter", n"Step_AssertStillAndRelease");
        Add_Step_WaitUntil("the platter is back in the world", n"Check_Released", 0, 0);
        Add_Step("watch it again", n"Step_RestartWatch");
        Add_Step_WaitUntil("the released platter's box pushes the character out", n"Check_Pushed", 0, 0);
        Add_Step("the box is still on the platter", n"Step_AssertPushed");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        // Resolves the platter's handles once it is constructed; the box decides the rest.
        Check_PlattersConstructed(InHandle, OutResult, InPayload);

        auto Res = OutResult;
        Res.Set(_Platters.Num() == 1 && _Box.Get_Status() == EMars_FoodPiece_Status::Ready);
    }

    UFUNCTION()
    private void Step_Stow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Stow_Platter(0);
    }

    UFUNCTION()
    private void Check_HeldAndMounted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_WorldItems[0].Get_Mount() == EMars_WorldItem_Mount::Held && _WorldItems[0].Get_IsSettled()
            && _Platters[0].Get_Mounting() == EMars_Platter_Mounting::Mounted);
    }

    UFUNCTION()
    private void Step_Load(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Platter = _Platters[0];
        Platter.Request_Load(FMars_Request_Platter_Load(_Box));
    }

    UFUNCTION()
    private void Check_BoxLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Platters[0].Get_HeldCount() == 1);
    }

    UFUNCTION()
    private void Step_PlaceCharacter(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto RootWorld = Get_World(_WorldItems[0]);
        const auto Metrics = utils_runtime_mesh::Get_Metrics(_Box.Get_Geometry());
        const auto BoxCentre = Get_World(_Box).TransformPosition(utils_foodpiece::Get_BoundsCentre(Metrics));
        const auto BoxInRoot = RootWorld.InverseTransformPosition(BoxCentre);
        const auto Inner = _Platters[0].Get_Spec().Bounds.InnerHalfExtents;

        const auto LiesOnTheFloor = BoxInRoot.Z > 3.0 && BoxInRoot.Z < 7.0;
        const auto StandFitsInside = Math::Abs(BoxInRoot.X) + k_StandHalfWidthCm < Inner.X && Math::Abs(BoxInRoot.Y) + k_StandHalfWidthCm < Inner.Y;
        if (LiesOnTheFloor == false || StandFitsInside == false)
        {
            FinishFailure(f"precondition: the box lies on the tray's floor with room for the stand around its centre (box centre {BoxInRoot} in the platter's frame, inner half extents {Inner})");
            return;
        }

        auto Owner = InHandle;
        const auto Floor = RootWorld.GetLocation().Z;
        const auto BaseZ = Floor - constants_platter::k_FloorAboveBase;
        Add_StaticBox(Owner, FVector(RootWorld.GetLocation().X, RootWorld.GetLocation().Y, BaseZ - k_LandingGapCm - 1.0), FVector(25.0, 25.0, 1.0));

        const auto StandCentreZ = Floor + k_StandBottomAboveFloorCm + k_StandHalfThicknessCm;
        _StandTop = StandCentreZ + k_StandHalfThicknessCm;
        Add_StaticBox(Owner, FVector(BoxCentre.X, BoxCentre.Y, StandCentreZ), FVector(k_StandHalfWidthCm, k_StandHalfWidthCm, k_StandHalfThicknessCm));

        // Spawned a little above its rest on the stand; it falls onto it.
        _CharacterEntity = utils_entity_lifetime::Request_CreateEntity(Owner);
        const auto Spawn = FVector(BoxCentre.X, BoxCentre.Y, _StandTop + k_CharacterHalfHeight + k_CharacterRadius + 3.0);
        utils_transform::Add(_CharacterEntity, FTransform(FRotator::ZeroRotator, Spawn), ECk_Replication::DoesNotReplicate);
        _Character = utils_jolt_character::Add(_CharacterEntity, FCk_JoltCharacter_Spec(k_CharacterRadius, k_CharacterHalfHeight));
    }

    // A static BlockAll box under InOwner, centred at InCentre.
    private void Add_StaticBox(FCk_Handle& InOwner, FVector InCentre, FVector InHalfExtents)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InOwner);
        utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, InCentre), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(InHalfExtents);
        auto Spec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        Spec.Set_ShapeDimensions(Shape);
        Spec.Set_MotionType(ECk_MotionType::Static);
        Spec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Entity, Spec);
    }

    UFUNCTION()
    private void Check_CharacterOnGround(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Character) && utils_jolt_character::Get_GroundState(_Character) == ECk_JoltCharacter_GroundState::OnGround);
    }

    UFUNCTION()
    private void Step_StartWatch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Baseline = Get_World(_CharacterEntity).GetLocation();
        const auto RestAbove = _Baseline.Z - (_StandTop + k_CharacterHalfHeight + k_CharacterRadius);
        Assert_True(RestAbove >= -0.1 && RestAbove <= k_RestSlackCm,
            f"the character rests on its stand, inside the box, not pushed out of it ({RestAbove :.3} cm above its rest on the stand)");

        _WatchStart = System::GetGameTimeInSeconds();
        _MaxDisplacement = 0.0;
    }

    private void Sample()
    {
        const auto Displacement = Get_World(_CharacterEntity).GetLocation().Distance(_Baseline);
        _MaxDisplacement = Math::Max(_MaxDisplacement, Displacement);
    }

    UFUNCTION()
    private void Check_WatchedASecond(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample();
        auto Res = OutResult;
        Res.Set(System::GetGameTimeInSeconds() - _WatchStart >= k_WatchSeconds);
    }

    UFUNCTION()
    private void Step_AssertStillAndRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_MaxDisplacement <= k_StillCm, f"the held platter's box never moved the character (moved up to {_MaxDisplacement :.3} cm)");
        Assert_Equals_Int(_Platters[0].Get_HeldCount(), 1, "the box is still on the held platter");

        auto WorldItem = _WorldItems[0];
        WorldItem.Request_Release(FMars_Request_WorldItem_Release(FVector::ZeroVector, FVector::ZeroVector));
    }

    UFUNCTION()
    private void Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_WorldItems[0].Get_Mount() == EMars_WorldItem_Mount::World);
    }

    UFUNCTION()
    private void Step_RestartWatch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _WatchStart = System::GetGameTimeInSeconds();
        _MaxDisplacement = 0.0;
    }

    UFUNCTION()
    private void Check_Pushed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample();
        auto Res = OutResult;
        Res.Set(_MaxDisplacement >= k_PushedCm);
    }

    UFUNCTION()
    private void Step_AssertPushed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Log(f"[PiecesIgnorePawns test] the released platter's box pushed the character {_MaxDisplacement :.3} cm in {System::GetGameTimeInSeconds() - _WatchStart :.3} s");
        Assert_True(_Platters[0].Get_Mounting() == EMars_Platter_Mounting::Free, "the released platter is Free");
        Assert_Equals_Int(_Platters[0].Get_HeldCount(), 1, "the box is still on the released platter");
    }
}
