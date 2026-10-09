// A World-mode, Persistent world item whose definition carries UMars_ItemTrait_Platter: the base WorldItem composition,
// then the Platter kernel on the same entity (its root is what the pieces ride). With InitialFood set, the food's whole
// joint is built under the world's transient entity, dressed when Ready and loaded into the first slot: a platter that
// spawns with something on it. The pieces are the kernel's to end (Clear, the platter's destruction).
class UMars_Platter_EntityScript : UMars_WorldItem_EntityScript
{
    // A placed platter resolves its item from here; a spawn sets it anyway.
    default Definition = mars_items::Platter();

    // A Params() spawn may set it; a placed platter uses a subclass default. Null = empty.
    UPROPERTY(ExposeOnSpawn)
    UMars_Food_Def InitialFood;

    private FCk_Handle_Platter _Platter;
    private FCk_Handle_FoodPiece _Joint;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);

        // Super destroyed itself (bad definition / no attach transform) - nothing to compose on.
        auto WorldItem = InHandle.As_WorldItem(ECk_SanityCheck::UnChecked);
        if (Flow != ECk_EntityScript_ConstructionFlow::Finished || ck::Is_NOT_Valid(WorldItem))
        { return Flow; }

        const auto IsWorld = Mode == EMars_WorldItem_Mode::World;
        const auto IsPersistent = WorldItem.Get_Persistence() == EMars_WorldItem_Persistence::Persistent;
        const UCk_InventoryItem_Definition ItemDefinition = Definition.Get();
        const UMars_ItemTrait_Platter PlatterTrait = ItemDefinition.Get_ItemTraitByClass(UMars_ItemTrait_Platter);

        const auto HasPlatterTrait = ck::IsValid(PlatterTrait);
        const auto IsPlatter = IsWorld && IsPersistent && HasPlatterTrait;
        if (ck::EnsureIfNot(IsPlatter,
            f"[Platter] [{InHandle.ToString()}] needs World mode and a Persistent definition with a Platter trait (mode [{Mode :n}], persistent [{IsPersistent}], platter trait [{HasPlatterTrait}])"))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        // A rejected spec already ensured in utils_platter::Add.
        _Platter = utils_platter::Add(InHandle, PlatterTrait.Platter);
        if (ck::Is_NOT_Valid(_Platter))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        if (ck::IsValid(InitialFood))
        { Build_InitialJoint(InHandle); }

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        Super::DoEndPlay(InHandle);

        if (ck::IsValid(_Joint))
        {
            _Joint.UnbindFrom_OnReady(FMars_Delegate_FoodPiece_OnReady(this, n"OnJointReady"));

            // The platter ends what it accepted; a joint its drain never reached is nobody else's.
            const auto IsEnding = utils_entity_lifetime::Get_IsPendingDestroy(_Joint, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
            if (ck::Is_NOT_Valid(_Joint.TryGet_Platter()) && IsEnding == false)
            { utils_entity_lifetime::Request_DestroyEntity(_Joint); }
        }

        if (ck::IsValid(_Platter))
        { _Platter.UnbindFrom_OnLoadRefused(FMars_Delegate_Platter_OnLoadRefused(this, n"OnLoadRefused")); }

        _Joint = FCk_Handle_FoodPiece();
    }

    private void Build_InitialJoint(FCk_Handle& InHandle)
    {
        const auto RootWorld = utils_transform::Get_EntityCurrentTransform(InHandle.As_Transform());

        // A rejected definition or spec already ensured in Build_Joint.
        _Joint = InitialFood.Build_Joint(ck::TransientEntity(), RootWorld);
        if (ck::Is_NOT_Valid(_Joint))
        { return; }

        _Joint.BindTo_OnReady(FMars_Delegate_FoodPiece_OnReady(this, n"OnJointReady"));
        _Platter.BindTo_OnLoadRefused(FMars_Delegate_Platter_OnLoadRefused(this, n"OnLoadRefused"));
        _Platter.Request_Load(FMars_Request_Platter_Load(_Joint));
    }

    UFUNCTION()
    private void OnJointReady(FCk_Handle_FoodPiece InPiece)
    {
        InitialFood.Add_Display(InPiece);
    }

    // An empty platter has room for its joint: a refusal is a defect. The joint goes.
    UFUNCTION()
    private void OnLoadRefused(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece, EMars_Platter_LoadRefusal InRefusal)
    {
        if (InPiece != _Joint)
        { return; }

        ck::EnsureIfNot(false, f"[Platter] [{InPlatter.ToString()}] refused its initial joint [{InPiece.ToString()}]: {InRefusal :n}");
        auto Joint = InPiece;
        utils_entity_lifetime::Request_DestroyEntity(Joint);
        _Joint = FCk_Handle_FoodPiece();
    }
}

// A placed platter holding the meat slab (the sandbox's prep food).
class UMars_Platter_MeatSlab_EntityScript : UMars_Platter_EntityScript
{
    default InitialFood = mars::Food_MeatSlab_Mars;
}

// A placed platter holding a mushroom slice (the searing station's input refuses it).
class UMars_Platter_MushroomSlice_EntityScript : UMars_Platter_EntityScript
{
    default InitialFood = mars::Food_MushroomSlice_Mars;
}
