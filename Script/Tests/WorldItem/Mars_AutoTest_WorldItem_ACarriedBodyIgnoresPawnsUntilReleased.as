// A carried body never shoves a pawn, and a released one does. A meat slab (a Persistent world item whose body collides as
// the food item's profile) is picked up into the carrier's empty hands and settles there, mounted (Held). A floor is laid
// just under the held slab and a Jolt character (a CharacterVirtual, profile Pawn) stands on it, its capsule rising through
// the middle of the slab's bounds. Held, the slab ignores pawns: over a second the character does not move. Released, the
// slab collides as its own profile again and pushes the character out. Isolated origin (25000, -15000, -30000).
class UMars_AutoTest_WorldItem_ACarriedBodyIgnoresPawnsUntilReleased : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(25000.0, -15000.0, -30000.0);
    private const FVector k_SlabOffset = FVector(200.0, 0.0, 0.0);
    private const float32 k_CharacterRadius = 3.0f;
    private const float32 k_CharacterHalfHeight = 3.0f;
    // The floor the character stands on (and the released slab drops onto), this far under the held slab's lowest point.
    private const float64 k_FloorGapCm = 0.3;
    // Jolt's character padding: the most a character resting on its floor floats above it.
    private const float64 k_RestSlackCm = 2.5;
    private const float64 k_StillCm = 0.1;
    private const float64 k_PushedCm = 2.0;
    private const float64 k_WatchSeconds = 1.0;
    // Physics settles and mount arrivals outrun the harness's default poll budget at lane frame rate.
    private const int32 k_SlowPolls = 900;

    private FCk_Handle _SlabEntity;
    private FCk_Handle_WorldItem _Slab;
    private FCk_Handle_Item _Item;

    private FCk_Handle _CharacterEntity;
    private FCk_Handle_JoltCharacter _Character;
    // The held slab's bounds centre and the floor's top, in the world.
    private FVector _SlabCentre;
    private float64 _FloorTop = 0.0;
    private FVector _Baseline;
    private float64 _WatchStart = 0.0;
    private float64 _MaxDisplacement = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 2);

        Add_StaticBox(InHandle, k_Origin + k_SlabOffset - FVector(0.0, 0.0, 1.0), FVector(80.0, 80.0, 1.0));
        auto SpawnParams = UMars_FoodItem_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin + k_SlabOffset + FVector(0.0, 0.0, 5.0));
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Food_MeatSlab());
        SpawnParams.Mode = EMars_WorldItem_Mode::World;

        // A piece outlives its spawner: under the world's transient entity, tracked for cleanup.
        _SlabEntity = utils_entity_script::Request_SpawnEntity(ck::TransientEntity(), UMars_FoodItem_EntityScript, SpawnParams).Get_EntityUnderConstruction();
        Track_ForCleanup(_SlabEntity);

        Add_Step_WaitUntil("the slab is constructed and its body added", n"Check_SlabReady", k_SlowPolls, 0);
        Add_Step("the carrier picks the slab up", n"Step_PickUp");
        Add_Step_WaitUntil("the slab is mounted Held on the carrier and settled there", n"Check_HeldAndSettled", k_SlowPolls, 0);
        Add_Step("a floor under the held slab, and a character standing on it up through the slab", n"Step_PlaceCharacter");
        Add_Step_WaitUntil("the character stands", n"Check_CharacterOnGround", 0, 0);
        Add_Step_WaitSeconds("the character comes to rest", 0.25f);
        Add_Step("it rests on its floor, its capsule through the held slab; watch it", n"Step_StartWatch");
        Add_Step_WaitUntil("a second passes", n"Check_WatchedASecond", 0, 0);
        Add_Step("the held slab never moved the character; release the slab", n"Step_AssertStillAndRelease");
        Add_Step_WaitUntil("the slab is back in the world", n"Check_Released", 0, 0);
        Add_Step("watch it again", n"Step_RestartWatch");
        Add_Step_WaitUntil("the released slab's body pushes the character out", n"Check_Pushed", k_SlowPolls, 0);
        Add_Step("the released slab is a Dynamic body back in its holder", n"Step_AssertPushed");
        Run_Steps(InHandle);
    }

    // A static BlockAll box under InOwner, centred at InCentre.
    private void Add_StaticBox(FCk_Handle InOwner, FVector InCentre, FVector InHalfExtents)
    {
        auto Owner = InOwner;
        auto Entity = utils_entity_lifetime::Request_CreateEntity(Owner);
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
    private void Check_SlabReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsConstructed = ck::IsValid(_SlabEntity) && _SlabEntity.Is_WorldItem() && ck::IsValid(_SlabEntity.As_WorldItem().Get_HeldItem());
        if (IsConstructed && ck::Is_NOT_Valid(_Slab))
        {
            _Slab = _SlabEntity.As_WorldItem();
            _Item = _Slab.Get_HeldItem();
        }

        auto Res = OutResult;
        Res.Set(IsConstructed && utils_jolt_body::Get_IsBodyAdded(_Slab.Get_Body()));
    }

    UFUNCTION()
    private void Step_PickUp(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Pickup = _Slab.Get_Pickup();
        Pickup.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
        auto Target = Pickup.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Check_HeldAndSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Slab.Get_Mount() == EMars_WorldItem_Mount::Held && _Slab.Get_Carrier() == _Carrier && _Slab.Get_IsSettled());
    }

    // The held slab's world bounds (its BoundsFit box about the root, the box its body is built in): a floor just under their
    // lowest point, and a character spawned a little above that floor on the vertical through their centre, so its capsule
    // rises through the slab whatever pose the hold gives it.
    UFUNCTION()
    private void Step_PlaceCharacter(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hotbar.Get_ItemAt(0) == _Item, "bag slot 0 holds the slab");

        const auto SlabWorld = utils_transform::Get_EntityCurrentTransform(_SlabEntity.As_Transform());
        const auto Fit = _Slab.Get_BoundsFit();
        _SlabCentre = SlabWorld.TransformPosition(Fit.Centre);

        auto LowestZ = _SlabCentre.Z;
        for (int32 Corner = 0; Corner < 8; ++Corner)
        {
            const auto X = (Corner % 2) == 0 ? -Fit.HalfExtents.X : Fit.HalfExtents.X;
            const auto Y = (Corner % 4) < 2 ? -Fit.HalfExtents.Y : Fit.HalfExtents.Y;
            const auto Z = Corner < 4 ? -Fit.HalfExtents.Z : Fit.HalfExtents.Z;
            LowestZ = Math::Min(LowestZ, SlabWorld.TransformPosition(Fit.Centre + FVector(X, Y, Z)).Z);
        }

        _FloorTop = LowestZ - k_FloorGapCm;
        const auto CapsuleHeight = 2.0 * float64(k_CharacterHalfHeight + k_CharacterRadius);
        if (_SlabCentre.Z - _FloorTop > CapsuleHeight - 1.0)
        {
            FinishFailure(f"precondition: the held slab's bounds centre lies within the character's height above the floor (centre {_SlabCentre.Z - _FloorTop :.2} cm above it, capsule {CapsuleHeight :.2} cm)");
            return;
        }

        auto Owner = InHandle;
        Add_StaticBox(Owner, FVector(_SlabCentre.X, _SlabCentre.Y, _FloorTop - 1.0), FVector(25.0, 25.0, 1.0));

        // Spawned a little above its rest on the floor; it falls onto it.
        _CharacterEntity = utils_entity_lifetime::Request_CreateEntity(Owner);
        const auto Spawn = FVector(_SlabCentre.X, _SlabCentre.Y, _FloorTop + k_CharacterHalfHeight + k_CharacterRadius + 3.0);
        utils_transform::Add(_CharacterEntity, FTransform(FRotator::ZeroRotator, Spawn), ECk_Replication::DoesNotReplicate);
        _Character = utils_jolt_character::Add(_CharacterEntity, FCk_JoltCharacter_Spec(k_CharacterRadius, k_CharacterHalfHeight));
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
        _Baseline = Get_CharacterLocation();
        const auto CapsuleHalf = float64(k_CharacterHalfHeight + k_CharacterRadius);
        const auto RestAbove = _Baseline.Z - (_FloorTop + CapsuleHalf);
        Assert_True(RestAbove >= -0.1 && RestAbove <= k_RestSlackCm,
            f"the character rests on its floor, not pushed off it ({RestAbove :.3} cm above its rest on the floor)");

        const auto IsThroughTheSlab = (_Baseline - _SlabCentre).Size2D() <= 0.5
            && _Baseline.Z - CapsuleHalf <= _SlabCentre.Z && _Baseline.Z + CapsuleHalf >= _SlabCentre.Z;
        Assert_True(IsThroughTheSlab, f"the character's capsule rises through the held slab's centre (character {_Baseline}, slab centre {_SlabCentre})");
        Assert_True(_Slab.Get_Mount() == EMars_WorldItem_Mount::Held, "the slab is still Held");

        _WatchStart = float64(System::GetGameTimeInSeconds());
        _MaxDisplacement = 0.0;
    }

    private FVector Get_CharacterLocation() const
    {
        return utils_transform::Get_EntityCurrentTransform(_CharacterEntity.As_Transform()).GetLocation();
    }

    private void Sample()
    {
        _MaxDisplacement = Math::Max(_MaxDisplacement, Get_CharacterLocation().Distance(_Baseline));
    }

    UFUNCTION()
    private void Check_WatchedASecond(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample();
        auto Res = OutResult;
        Res.Set(float64(System::GetGameTimeInSeconds()) - _WatchStart >= k_WatchSeconds);
    }

    UFUNCTION()
    private void Step_AssertStillAndRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_MaxDisplacement <= k_StillCm, f"the held slab never moved the character (moved up to {_MaxDisplacement :.3} cm)");
        Assert_True(_Slab.Get_Mount() == EMars_WorldItem_Mount::Held, "the slab was Held the whole second");

        _Slab.Request_Release(FMars_Request_WorldItem_Release(FVector::ZeroVector, FVector::ZeroVector));
    }

    UFUNCTION()
    private void Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Slab.Get_Mount() == EMars_WorldItem_Mount::World);
    }

    UFUNCTION()
    private void Step_RestartWatch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _WatchStart = float64(System::GetGameTimeInSeconds());
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
        Log(f"[CarriedBodyIgnoresPawns test] the released slab pushed the character {_MaxDisplacement :.3} cm in {float64(System::GetGameTimeInSeconds()) - _WatchStart :.3} s");
        Assert_True(utils_jolt_body::Get_MotionType(_Slab.Get_Body()) == ECk_MotionType::Dynamic, "the released body is Dynamic");
        Assert_True(_Item.Get_PersistentWorldItem() == _Slab && ck::IsValid(_Slab.Get_HeldItem()), "the slab's holder holds its item again");
    }
}
