namespace constants_food_item
{
    // Above a platter's pickup (0) and a dock (10): a whole food lying on a platter, docked or not, is what the hand takes.
    const int32 k_FocusPriority = 20;

    // A whole food's body has the surface a cut piece gets when the board lets it go loose.
    const FName k_BodyCollisionProfile = n"PhysicsActor";
    const float32 k_BodyFriction = 0.6f;
    const float32 k_BodyRestitution = 0.1f;
}

// A whole food as a World-mode, Persistent world item whose entity IS the food's FoodPiece: the definition's Food trait names
// the food, its joint is composed on this entity, and construction continues until the joint is Ready. Then the joint is
// dressed, given its convex body (only in a game world: Jolt runs nowhere else, and a food placed in a level also
// composes in the editor's preview world) and the shared world-item tail: a holder, a pickup fitted to the joint's bounds
// and the WorldItem feature. A joint that fails to import takes the entity with it.
class UMars_FoodItem_EntityScript : UMars_WorldItem_EntityScript
{
    private UMars_Food_Def _Food;
    private FCk_Handle_FoodPiece _Joint;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        UCk_InventoryItem_Definition ItemDefinition = Definition.Get();
        const auto HasDefinition = ck::IsValid(ItemDefinition);
        const auto IsWorld = Mode == EMars_WorldItem_Mode::World;
        if (ck::EnsureIfNot(HasDefinition && IsWorld,
            f"[FoodItem] [{InHandle.ToString()}] needs a World-mode spawn with an item definition (mode [{Mode :n}], definition [{HasDefinition}])"))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        const UMars_ItemTrait_Food FoodTrait = ItemDefinition.Get_ItemTraitByClass(UMars_ItemTrait_Food);
        const auto HasFood = ck::IsValid(FoodTrait) && ck::IsValid(FoodTrait.Food);
        if (ck::EnsureIfNot(HasFood, f"[FoodItem] [{InHandle.ToString()}]'s definition [{ItemDefinition.GetName()}] carries no Food trait naming a food"))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        _Food = FoodTrait.Food;

        utils_transform::Add(InHandle, _Food.Get_JointWorld(SpawnTransform), ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsWorldItem");

        // A rejected definition or spec already ensured in Compose_Joint.
        _Joint = _Food.Compose_Joint(InHandle);
        if (ck::Is_NOT_Valid(_Joint))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        _Joint.BindTo_OnReady(FMars_Delegate_FoodPiece_OnReady(this, n"OnJointReady"));
        _Joint.BindTo_OnFailed(FMars_Delegate_FoodPiece_OnFailed(this, n"OnJointFailed"));
        return ECk_EntityScript_ConstructionFlow::Continue;
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        Super::DoEndPlay(InHandle);

        if (ck::IsValid(_Joint))
        {
            _Joint.UnbindFrom_OnReady(FMars_Delegate_FoodPiece_OnReady(this, n"OnJointReady"));
            _Joint.UnbindFrom_OnFailed(FMars_Delegate_FoodPiece_OnFailed(this, n"OnJointFailed"));
        }

        _Joint = FCk_Handle_FoodPiece();
    }

    protected int32 Get_PickupFocusPriority() const override
    {
        return constants_food_item::k_FocusPriority;
    }

    UFUNCTION()
    private void OnJointReady(FCk_Handle_FoodPiece InPiece)
    {
        _Food.Add_Display(InPiece);

        auto Composition = FMars_WorldItem_Composition();
        Composition.BoundsFit = Make_BoundsFit(InPiece);
        Composition.ProbeFit = FMars_WorldItem_ProbeFit(utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(Composition.BoundsFit.HalfExtents)),
            FTransform(FRotator::ZeroRotator, Composition.BoundsFit.Centre));

        FCk_Handle Entity = InPiece;
        const UWorld EntityWorld = utils_entity_lifetime::Get_WorldForEntity(Entity);
        if (ck::IsValid(EntityWorld) && EntityWorld.IsGameWorld())
        {
            auto Piece = InPiece;
            Composition.Body = utils_foodpiece::Add_Body(Piece, FMars_FoodPiece_BodyTuners(
                constants_food_item::k_BodyCollisionProfile, constants_food_item::k_BodyFriction, constants_food_item::k_BodyRestitution));
            Composition.BodyProfile = constants_food_item::k_BodyCollisionProfile;
        }

        // A rejected spec destroyed the entity (utils_world_item::Add ensured): nothing to finish.
        Compose_WorldItem(Entity, Composition);
        if (Entity.Is_WorldItem() == false)
        { return; }

        DoFinishConstruction();
    }

    // The import already ensured (UMars_Processor_FoodPiece_Setup): a food item without its joint is nothing to pick up.
    UFUNCTION()
    private void OnJointFailed(FCk_Handle_FoodPiece InPiece, ECk_RuntimeMesh_SetupFailure InReason)
    {
        ck::Warning(f"[FoodItem] [{InPiece.ToString()}] of [{_Food.GetName()}] failed to import ({InReason :n}): the food item is destroyed");
        FCk_Handle Entity = InPiece;
        utils_entity_lifetime::Request_DestroyEntity(Entity);
    }

    // The joint's bounds, centred on them (the mesh's pivot is its base, not its centre): the pickup's box and what the
    // gloves size a reach from.
    private FMars_WorldItem_BoundsFit Make_BoundsFit(const FCk_Handle_FoodPiece& InPiece) const
    {
        const auto Metrics = utils_runtime_mesh::Get_Metrics(InPiece.Get_Geometry());
        const auto Min = Metrics.Get_BoundsMinCm();
        const auto Max = Metrics.Get_BoundsMaxCm();
        return FMars_WorldItem_BoundsFit((Max - Min) * 0.5, (Min + Max) * 0.5);
    }
}

// The sandbox's placed foods: a placed entity resolves its definition from a class default.
class UMars_FoodItem_MeatSlab_EntityScript : UMars_FoodItem_EntityScript
{
    default Definition = mars_items::Food_MeatSlab();
}

class UMars_FoodItem_MushroomSlice_EntityScript : UMars_FoodItem_EntityScript
{
    default Definition = mars_items::Food_MushroomSlice();
}
