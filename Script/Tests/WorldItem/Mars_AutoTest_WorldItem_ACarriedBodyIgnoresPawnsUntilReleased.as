// A mounted body never shoves its carrier. A meat slab (a Persistent world item whose body collides as the food item's
// profile) is picked up: once it is Carried on the carrier's back its body has confirmed IgnoreOnlyPawn. Released back into
// the world it confirms its own profile again. The body has no profile read-back, so the world item's record of the last
// completed SetCollisionProfile request is what is asserted. Isolated origin (25000, -15000, -30000).
class UMars_AutoTest_WorldItem_ACarriedBodyIgnoresPawnsUntilReleased : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(25000.0, -15000.0, -30000.0);
    private const FVector k_SlabOffset = FVector(200.0, 0.0, 0.0);

    private FCk_Handle _SlabEntity;
    private FCk_Handle_WorldItem _Slab;
    private FCk_Handle_Item _Item;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 2);

        Spawn_Floor(InHandle, k_Origin + k_SlabOffset);
        auto SpawnParams = UMars_FoodItem_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin + k_SlabOffset + FVector(0.0, 0.0, 5.0));
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Food_MeatSlab());
        SpawnParams.Mode = EMars_WorldItem_Mode::World;

        // A piece outlives its spawner: under the world's transient entity, tracked for cleanup.
        _SlabEntity = utils_entity_script::Request_SpawnEntity(ck::TransientEntity(), UMars_FoodItem_EntityScript, SpawnParams).Get_EntityUnderConstruction();
        Track_ForCleanup(_SlabEntity);

        Add_Step_WaitUntil("the slab is constructed and its body added", n"Check_SlabReady", 0, 10.0f);
        Add_Step("in the world the body keeps the profile it was built with", n"Step_AssertBuiltProfile");
        Add_Step("the carrier picks the slab up", n"Step_PickUp");
        Add_Step_WaitUntil("the slab is Carried and its body confirmed IgnoreOnlyPawn", n"Check_CarriedIgnoringPawns", 0, 5.0f);
        Add_Step("release the slab into the world", n"Step_Release");
        Add_Step_WaitUntil("the slab is back in the world with its own profile", n"Check_ReleasedWithItsOwnProfile", 0, 5.0f);
        Add_Step("the body confirmed its own profile again", n"Step_AssertOwnProfile");
        Run_Steps(InHandle);
    }

    // A static slab whose top is at InTop.
    private void Spawn_Floor(FCk_Handle InOwner, FVector InTop)
    {
        auto Owner = InOwner;
        auto Floor = utils_entity_lifetime::Request_CreateEntity(Owner);
        utils_transform::Add(Floor, FTransform(FRotator::ZeroRotator, InTop - FVector(0.0, 0.0, 1.0)), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(80.0, 80.0, 1.0));
        auto FloorSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        FloorSpec.Set_ShapeDimensions(Shape);
        FloorSpec.Set_MotionType(ECk_MotionType::Static);
        FloorSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Floor, FloorSpec);
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
    private void Step_AssertBuiltProfile(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Slab.Get_BodyProfile() == constants_food_item::k_BodyCollisionProfile, f"the world item records the food item's body profile (got {_Slab.Get_BodyProfile().ToString()})");
        Assert_False(_Slab.Get_AppliedBodyProfile().IsSet(), "no profile request has completed yet");
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
    private void Check_CarriedIgnoringPawns(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Slab.Get_Mount() == EMars_WorldItem_Mount::Carried
            && _Slab.Get_AppliedBodyProfile() == constants_world_item::k_MountedBodyProfile);
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hotbar.Get_ItemAt(0) == _Item, "bag slot 0 holds the slab");
        _Slab.Request_Release(FMars_Request_WorldItem_Release(_Item, _Hotbar.Get_Slot(0), FVector::ZeroVector, FVector::ZeroVector));
    }

    UFUNCTION()
    private void Check_ReleasedWithItsOwnProfile(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Slab.Get_Mount() == EMars_WorldItem_Mount::World
            && _Slab.Get_AppliedBodyProfile() == constants_food_item::k_BodyCollisionProfile);
    }

    UFUNCTION()
    private void Step_AssertOwnProfile(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Slab.Get_AppliedBodyProfile() == constants_food_item::k_BodyCollisionProfile, "the body collides as the food item again");
        Assert_True(utils_jolt_body::Get_MotionType(_Slab.Get_Body()) == ECk_MotionType::Dynamic, "the released body is Dynamic");
        Assert_True(_Item.Get_PersistentWorldItem() == _Slab && ck::IsValid(_Slab.Get_HeldItem()), "the slab's holder holds its item again");
    }
}
