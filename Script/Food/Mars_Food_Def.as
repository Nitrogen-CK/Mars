// A food a station works on, as every layer reads it: what it is (Data: the solid, its mass, its kind), how small a cut may
// leave it (Tuners, the FoodPiece kernel's own), how it looks whole and cut (Visuals) and how it lies on a board (Layout).
// A new food is a new asset of this class; the kernels and the stations stay untouched.

struct FMars_Food_Data
{
    // CPU-readable, and under RuntimeMesh's import ceiling (2048 raw render vertices on LOD0).
    UPROPERTY()
    TSoftObjectPtr<UStaticMesh> Mesh;

    // The whole joint's mass; cuts split it by volume.
    UPROPERTY()
    float MassKg = 0.0;

    // What the food is, for the stations that gate on it (Food.Meat.Beef, Food.Vegetable.Mushroom); every piece cut from
    // the joint carries it.
    UPROPERTY(meta = (Categories = "Food"))
    FGameplayTagContainer Kind;
}

struct FMars_Food_Visuals
{
    // One material per mesh material slot, then the cap's slot: every piece, whole or cut, wears these.
    UPROPERTY()
    FCk_RuntimeMeshDisplay_Visuals Display;

    // Every cut face: Cap.MaterialID names its slot in Display.
    UPROPERTY()
    FCk_RuntimeMesh_Cap Cap;
}

// The joint's pose from the station's pile point, never scaled.
struct FMars_Food_Layout
{
    UPROPERTY()
    float64 YawDegrees = 0.0;

    UPROPERTY()
    float64 LiftCm = 0.0;
}

class UMars_Food_Def : UDataAsset
{
    UPROPERTY(Category = "Data")
    FMars_Food_Data Data;

    UPROPERTY(Category = "Tuners")
    FMars_FoodPiece_Tuners Tuners;

    UPROPERTY(Category = "Visuals")
    FMars_Food_Visuals Visuals;

    UPROPERTY(Category = "Layout")
    FMars_Food_Layout Layout;

    // What only the definition knows. Mass, tuners and cap ranges are the FoodPiece spec's (checked when the joint is
    // composed); whether the materials cover the mesh's slots is the display's (checked when it is added).
    FMars_Validation Validate() const
    {
        if (Data.Mesh.IsNull())
        { return FMars_Validation(f"[{GetName()}] has no Data.Mesh"); }

        if (Data.Kind.IsEmpty())
        { return FMars_Validation(f"[{GetName()}] has no Data.Kind: nothing could gate on it"); }

        const auto Materials = Visuals.Display.Get_Materials();
        if (Materials.Num() < 2)
        { return FMars_Validation(f"[{GetName()}] has {Materials.Num()} Visuals.Display materials: one per mesh slot and one for the cap"); }

        for (int32 Index = 0; Index < Materials.Num(); ++Index)
        {
            if (Materials[Index].IsNull())
            { return FMars_Validation(f"[{GetName()}] has no material in Visuals.Display slot {Index}"); }
        }

        const auto CapSlot = Visuals.Cap.Get_MaterialID();
        if (CapSlot < 0 || CapSlot >= Materials.Num())
        { return FMars_Validation(f"[{GetName()}] has Visuals.Cap.MaterialID [{CapSlot}] outside its {Materials.Num()} display slots"); }

        if (Math::IsFinite(Layout.YawDegrees) == false || Math::IsFinite(Layout.LiftCm) == false)
        { return FMars_Validation(f"[{GetName()}] has a non-finite Layout"); }

        return FMars_Validation();
    }

    // The whole joint as a FoodPiece on RuntimeMesh under InOwner, at Get_JointWorld(InWorld). Pending until it imports;
    // the caller binds OnReady and dresses it (Add_Display). A rejected definition or spec ensures and returns an invalid
    // handle (the entity is destroyed).
    FCk_Handle_FoodPiece Build_Joint(FCk_Handle InOwner, const FTransform& InWorld)
    {
        auto Owner = InOwner;
        auto Entity = utils_entity_lifetime::Request_CreateEntity(Owner);
        utils_transform::Add(Entity, Get_JointWorld(InWorld), ECk_Replication::DoesNotReplicate);

        auto Joint = Compose_Joint(Entity);
        if (ck::Is_NOT_Valid(Joint))
        { utils_entity_lifetime::Request_DestroyEntity(Entity); }

        return Joint;
    }

    // Build_Joint in place: the RuntimeMesh and the whole joint's FoodPiece on InEntity, which already carries its
    // Transform (at Get_JointWorld). A rejected definition or spec ensures and returns an invalid handle; the caller ends
    // the entity. Not const: the pieces' weak Definition is made from a non-const this.
    FCk_Handle_FoodPiece Compose_Joint(FCk_Handle& InEntity)
    {
        const auto Validation = Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Food] [{GetName()}] rejected: {Validation.Get_Error()}"))
        { return FCk_Handle_FoodPiece(); }

        utils_runtime_mesh::Add(InEntity, FCk_RuntimeMesh_Spec(Data.Mesh));

        auto PieceData = FMars_FoodPiece_Data(Data.MassKg);
        PieceData.Definition = TWeakObjectPtr<UMars_Food_Def>(this);
        PieceData.Kind = Data.Kind;

        // A rejected spec already ensured in utils_foodpiece::Add.
        return utils_foodpiece::Add(InEntity, FMars_FoodPiece_Spec(PieceData, Tuners, Visuals.Cap));
    }

    // InWorld with the Layout applied (yaw, lift) and unit scale: pieces are cut and simulated unscaled.
    FTransform Get_JointWorld(const FTransform& InWorld) const
    {
        const auto LayoutLocal = FTransform(FRotator(0.0, Layout.YawDegrees, 0.0), FVector(0.0, 0.0, Layout.LiftCm));
        auto JointWorld = LayoutLocal * InWorld;
        JointWorld.SetScale3D(FVector::OneVector);
        return JointWorld;
    }

    // The display every piece of this food wears, on the piece's own entity. A piece already ending (a clear that raced its
    // import) is not shown.
    void Add_Display(FCk_Handle_FoodPiece InPiece) const
    {
        if (utils_entity_lifetime::Get_IsPendingDestroy(InPiece, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        auto Spec = FCk_RuntimeMeshDisplay_Spec();
        Spec.Set_Geometry(InPiece.Get_Geometry());
        Spec.Set_Visuals(Visuals.Display);

        FCk_Handle Entity = InPiece;
        auto Owner = Entity.As_Transform();
        // A rejected display already ensured in utils_runtime_mesh_display::Add.
        utils_runtime_mesh_display::Add(Owner, Spec);
    }
}

// Asset literals live in mars:: so other files can name them (a global-scope asset is file-local).
namespace mars
{
    // MeatSlab_Mars_SM: 36.8 x 20.2 x 12.1 cm, pivot at its base centre, long axis +X, 6927 cm3. Slots Flesh (0), Skin = the fat
    // cap (1); the cap is slot 2. 7.27 kg = 6927 cm3 at 1.05 g/cm3, lean beef's density. Yawed 90 so the long axis runs along
    // the cleaver's travel. The Accent material multiplies the vertex colour by its tint, so a white cap shows the cut tint.
    asset Food_MeatSlab_Mars of UMars_Food_Def
    {
        Data.Mesh = assets::MeatSlab_Mars_SM();
        Data.MassKg = 7.27;
        Data.Kind.AddTag(GameplayTags::Food_Meat_Beef);

        // A 50 g, 1 cm portion: thinner shavings are refused and the chop only knocks.
        Tuners = FMars_FoodPiece_Tuners(0.05, 1.0);

        TArray<TSoftObjectPtr<UMaterialInterface>> Materials;
        Materials.Add(TSoftObjectPtr<UMaterialInterface>(assets::MeatSlabFlesh_Mars_MI().ToSoftObjectPath()));
        Materials.Add(TSoftObjectPtr<UMaterialInterface>(assets::MeatSlabFat_Mars_MI().ToSoftObjectPath()));
        Materials.Add(TSoftObjectPtr<UMaterialInterface>(assets::MeatSlabCut_Mars_MI().ToSoftObjectPath()));
        Visuals.Display.Set_Materials(Materials);
        Visuals.Cap.Set_MaterialID(2);
        Visuals.Cap.Set_Color(FLinearColor::White);

        Layout.YawDegrees = 90.0;
    }

    // Mushroom_Slice_Mars_SM: a 1 cm lengthwise slice lying flat, 8.2 x 11.9 cm (long axis +Y), 53.6 cm3. Slots Skin = the rim
    // (0), Flesh = both faces (1); one Food instance wears all three, the cap included. 0.032 kg = 53.6 cm3 at 0.6 g/cm3 (a
    // mushroom floats). The cap is the slice's own painted flesh, C(235, 222, 200) linear, so a fresh cut matches its faces;
    // the slice's UVs span about 12 cm. Unrotated: the long axis already runs along the cleaver's travel.
    asset Food_MushroomSlice_Mars of UMars_Food_Def
    {
        Data.Mesh = assets::Mushroom_Slice_Mars_SM();
        Data.MassKg = 0.032;
        Data.Kind.AddTag(GameplayTags::Food_Vegetable_Mushroom);

        // A 2 g, 0.8 cm portion: a sliver off the rim is refused.
        Tuners = FMars_FoodPiece_Tuners(0.002, 0.8);

        const auto Slice = TSoftObjectPtr<UMaterialInterface>(assets::Mushroom_Slice_Mars_MI().ToSoftObjectPath());
        TArray<TSoftObjectPtr<UMaterialInterface>> Materials;
        Materials.Add(Slice);
        Materials.Add(Slice);
        Materials.Add(Slice);
        Visuals.Display.Set_Materials(Materials);
        Visuals.Cap.Set_MaterialID(2);
        Visuals.Cap.Set_Color(FLinearColor(0.831f, 0.731f, 0.578f, 1.0f));
        Visuals.Cap.Set_CmPerUVUnit(12.0);
    }
}
