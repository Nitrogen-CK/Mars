// A food a station works on, as every layer reads it: what it is (Data: the solid, its mass, its kind), how small a cut may
// leave it (Tuners, the FoodPiece kernel's own), the surface of every body its pieces get (Body, the FoodPiece kernel's
// own), how it looks whole and cut (Visuals) and how it lies on a board (Layout). A new food is a new asset of this class;
// the kernels and the stations stay untouched.

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

// The food dipped in batter: a static mesh shown in place of a whole piece's display once a fryer has battered it (a cut
// piece keeps its display and shows its batter as browning). Display-only: the piece's RuntimeMesh stays its ledger and
// its body. Unset Mesh: the food is not batterable.
struct FMars_Food_BatteredVisuals
{
    // Authored in the raw mesh's frame (a nested core and batter shell, its materials on its own slots).
    UPROPERTY()
    TSoftObjectPtr<UStaticMesh> Mesh;

    // The battered mesh's origin in the piece's frame: zero when the variant keeps the raw mesh's pivot; the batter
    // generator's sidecar records any residual shift.
    UPROPERTY()
    FVector PivotOffset = FVector::ZeroVector;

    // One per battered mesh slot; empty keeps the mesh's own materials.
    UPROPERTY()
    TArray<TSoftObjectPtr<UMaterialInterface>> Materials;
}

struct FMars_Food_Visuals
{
    // One material per mesh material slot, then the cap's slot: every piece, whole or cut, wears these.
    UPROPERTY()
    FCk_RuntimeMeshDisplay_Visuals Display;

    // Every cut face: Cap.MaterialID names its slot in Display.
    UPROPERTY()
    FCk_RuntimeMesh_Cap Cap;

    UPROPERTY()
    FMars_Food_BatteredVisuals Battered;
}

namespace constants_food
{
    // A battered mesh further than this from the piece's origin is an authoring error, not a pivot residue.
    const float64 k_MaxBatteredPivotOffsetCm = 50.0;
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

    UPROPERTY(Category = "Body")
    FMars_FoodPiece_BodyTuners Body;

    UPROPERTY(Category = "Visuals")
    FMars_Food_Visuals Visuals;

    UPROPERTY(Category = "Layout")
    FMars_Food_Layout Layout;

    // What only the definition knows. Mass, tuners, cap ranges and the body surface are the FoodPiece spec's (checked when
    // the joint is composed); whether the materials cover the mesh's slots is the display's (checked when it is added).
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

        const auto CookLook = Validate_CookLook();
        if (CookLook.IsValid() == false)
        { return CookLook; }

        return Validate_Battered();
    }

    // The prep standard's headless half (CLAUDE.md, "Prep standard for cuttable meat"): a meat goes to the cutting bench and
    // then the pan, so every cut face must read as its flesh does. Its cap slot wears a material and its cap colour carries
    // cavity (alpha > 0: the cook-state materials read vertex alpha as cavity, and a 0 there leaves every cut face unlit
    // crust). Whether the materials read the cook state is FoodDef_EveryMeatFoodReadsTheCookState's (it loads them).
    FMars_Validation Validate_CookLook() const
    {
        if (Data.Kind.HasTag(GameplayTags::Food_Meat) == false)
        { return FMars_Validation(); }

        const auto Materials = Visuals.Display.Get_Materials();
        const auto CapSlot = Visuals.Cap.Get_MaterialID();
        if (Materials.IsValidIndex(CapSlot) == false || Materials[CapSlot].IsNull())
        { return FMars_Validation(f"[{GetName()}] is meat with no material on its cap slot [{CapSlot}]: a cut face would wear nothing"); }

        const auto CapColor = Visuals.Cap.Get_Color();
        if (CapColor.A <= 0.0f)
        { return FMars_Validation(f"[{GetName()}] is meat with a cap colour alpha of [{CapColor.A}]: the cut face's cavity must be above 0"); }

        return FMars_Validation();
    }

    // Not every food is batterable: no battered mesh is legal, but then nothing else of the variant may be set.
    FMars_Validation Validate_Battered() const
    {
        const auto& Battered = Visuals.Battered;
        if (Battered.Mesh.IsNull())
        {
            if (Battered.Materials.Num() > 0 || Battered.PivotOffset != FVector::ZeroVector)
            { return FMars_Validation(f"[{GetName()}] has Visuals.Battered materials or a pivot offset but no battered mesh"); }

            return FMars_Validation();
        }

        const auto Offset = Battered.PivotOffset;
        if (Math::IsFinite(Offset.X) == false || Math::IsFinite(Offset.Y) == false || Math::IsFinite(Offset.Z) == false
            || Offset.Size() > constants_food::k_MaxBatteredPivotOffsetCm)
        { return FMars_Validation(f"[{GetName()}] has Visuals.Battered.PivotOffset [{Offset.ToString()}] non-finite or beyond {constants_food::k_MaxBatteredPivotOffsetCm} cm"); }

        for (int32 Index = 0; Index < Battered.Materials.Num(); ++Index)
        {
            if (Battered.Materials[Index].IsNull())
            { return FMars_Validation(f"[{GetName()}] has no material in Visuals.Battered slot {Index}"); }
        }

        return FMars_Validation();
    }

    // The food has a battered variant: a fryer batters a whole piece of it.
    bool Get_IsBatterable() const
    {
        return Visuals.Battered.Mesh.IsNull() == false;
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
        return utils_foodpiece::Add(InEntity, FMars_FoodPiece_Spec(PieceData, Tuners, Visuals.Cap, Body));
    }

    // InWorld with the Layout applied (yaw, lift) and unit scale: pieces are cut and simulated unscaled.
    FTransform Get_JointWorld(const FTransform& InWorld) const
    {
        const auto LayoutLocal = FTransform(FRotator(0.0, Layout.YawDegrees, 0.0), FVector(0.0, 0.0, Layout.LiftCm));
        auto JointWorld = LayoutLocal * InWorld;
        JointWorld.SetScale3D(FVector::OneVector);
        return JointWorld;
    }

    // The display every piece of this food wears, on the piece's own entity, starting from the piece's own cook state (a cut
    // half or a re-dressed piece looks as cooked as its ledger says, a battered whole piece wears its battered shell). A
    // piece already ending (a clear that raced its import) is not shown.
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
        const auto Display = utils_runtime_mesh_display::Add(Owner, Spec);
        if (ck::IsValid(Display))
        { utils_station::Write_PieceLook(InPiece, utils_cookstate::Make_DisplayParams(InPiece.Get_CookState())); }
    }
}

// Asset literals live in mars:: so other files can name them (a global-scope asset is file-local).
namespace mars
{
    // MeatSlab_Mars_SM: 36.6 x 20.0 x 12.2 cm, pivot at its base centre, long axis +X, 7561 cm3. Slots Flesh (0), Skin = the fat
    // cap (1); the cap is slot 2. 7.94 kg = 7561 cm3 at 1.05 g/cm3, lean beef's density. Yawed 90 so the long axis runs along
    // the cleaver's travel. One Food instance (MeatSlab_Mars_MI, on Food_Mars_M, so every slot reads the cook state) wears all
    // three: the painted vertex colours tell lean from fat, and the cap is the slab's own cut-lean paint, C(212, 36, 56)
    // linear, so a fresh cut matches the authored end cuts. The slab's UVs span about 37 cm.
    asset Food_MeatSlab_Mars of UMars_Food_Def
    {
        Data.Mesh = assets::MeatSlab_Mars_SM();
        Data.MassKg = 7.94;
        Data.Kind.AddTag(GameplayTags::Food_Meat_Beef);

        // A 50 g, 1 cm portion: thinner shavings are refused and the chop only knocks.
        Tuners = FMars_FoodPiece_Tuners(0.05, 1.0);

        const auto Slab = TSoftObjectPtr<UMaterialInterface>(assets::MeatSlab_Mars_MI().ToSoftObjectPath());
        TArray<TSoftObjectPtr<UMaterialInterface>> Materials;
        Materials.Add(Slab);
        Materials.Add(Slab);
        Materials.Add(Slab);
        Visuals.Display.Set_Materials(Materials);
        Visuals.Cap.Set_MaterialID(2);
        Visuals.Cap.Set_Color(FLinearColor(0.658f, 0.018f, 0.040f, 1.0f));
        Visuals.Cap.Set_CmPerUVUnit(37.0);
        Visuals.Cap.Set_UVPolicy(ECk_RuntimeMesh_CapUVPolicy::PlanarOnLayer0_KeepInterpolated);

        Layout.YawDegrees = 90.0;
    }

    // Mushroom_Slice_Mars_SM: a 1 cm lengthwise slice lying flat, 8.2 x 11.9 cm (long axis +Y), 53.6 cm3. Slots Skin = the rim
    // (0), Flesh = both faces (1); one Food instance wears all three, the cap included. 0.032 kg = 53.6 cm3 at 0.6 g/cm3 (a
    // mushroom floats). The cap is the slice's own painted flesh, C(235, 222, 200) linear, so a fresh cut matches its faces;
    // the slice's UVs span about 12 cm. Already a slice: not a cutting-bench input (the bench takes whole meat) and not
    // batterable; the FoodPiece kernel's tests keep it as a cheap gram-scale fixture.
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
        // UV1/UV2 hold the raw-to-cooked morph offset: the cap rim keeps the shell's interpolated value so the edge does not
        // tear as Shape rises (UV0 alone takes the planar projection).
        Visuals.Cap.Set_UVPolicy(ECk_RuntimeMesh_CapUVPolicy::PlanarOnLayer0_KeepInterpolated);

        // Not batterable: batter is for whole ingredients, and the slice is already a cut thing.
    }

    // The prep roster: each <Name>_Prep_Mars_SM is the hero's runtime-mesh twin (one closed solid, <= 660 triangles, under
    // RuntimeMesh's 2048-render-vertex ceiling, CPU-readable, the hero's own frame: centred XY, base at z = 0). Its cooking
    // slot wears <Name>_Prep_Mars_MI (a child of the ingredient's Food instance carrying the prep's own mask) and an accent
    // slot (Bone, Horn) its accent instance; the cap is the prep instance again, tinted the food's cut flesh (linear), its
    // UVs projected at about the food's size. Battered = <Name>_Prep_Battered_Mars_SM, in the prep's frame (pivot offset
    // zero), carrying its own BatteredCore / accent / Batter materials. Masses are the solid's volume at a plausible density.

    // Drumstick_Prep_Mars_SM: 21.4 x 11.4 x 10.6 cm, long axis +X, 765 cm3. Slots Flesh (0), Bone (1); the cap is slot 2.
    // 0.80 kg = 765 cm3 at 1.05 g/cm3. Yawed 90 so the long axis runs along the cleaver's travel. Cap: the exposed meat
    // end's paint, C(228, 190, 150).
    asset Food_Drumstick_Mars of UMars_Food_Def
    {
        Data.Mesh = assets::Drumstick_Prep_Mars_SM();
        Data.MassKg = 0.80;
        Data.Kind.AddTag(GameplayTags::Food_Meat);

        // A 20 g, 1 cm portion.
        Tuners = FMars_FoodPiece_Tuners(0.02, 1.0);

        const auto Flesh = TSoftObjectPtr<UMaterialInterface>(assets::Drumstick_Prep_Mars_MI().ToSoftObjectPath());
        TArray<TSoftObjectPtr<UMaterialInterface>> Materials;
        Materials.Add(Flesh);
        Materials.Add(TSoftObjectPtr<UMaterialInterface>(assets::Bone_Mars_MI().ToSoftObjectPath()));
        Materials.Add(Flesh);
        Visuals.Display.Set_Materials(Materials);
        Visuals.Cap.Set_MaterialID(2);
        Visuals.Cap.Set_Color(FLinearColor(0.776f, 0.515f, 0.305f, 1.0f));
        Visuals.Cap.Set_CmPerUVUnit(22.0);

        Visuals.Battered.Mesh = assets::Drumstick_Prep_Battered_Mars_SM();

        Layout.YawDegrees = 90.0;
    }

    // Tentacle_Prep_Mars_SM: 29.0 x 7.4 x 9.4 cm, long axis +X, 300 cm3. Slot Flesh (0); the cap is slot 1. 0.32 kg = 300 cm3
    // at 1.05 g/cm3. Yawed 90 so the long axis runs along the cleaver's travel. Cap: pale pink flesh, C(236, 206, 210).
    asset Food_Tentacle_Mars of UMars_Food_Def
    {
        Data.Mesh = assets::Tentacle_Prep_Mars_SM();
        Data.MassKg = 0.32;
        Data.Kind.AddTag(GameplayTags::Food_Meat);

        // A 10 g, 0.8 cm portion: the curled tip is thin.
        Tuners = FMars_FoodPiece_Tuners(0.01, 0.8);

        const auto Flesh = TSoftObjectPtr<UMaterialInterface>(assets::Tentacle_Prep_Mars_MI().ToSoftObjectPath());
        TArray<TSoftObjectPtr<UMaterialInterface>> Materials;
        Materials.Add(Flesh);
        Materials.Add(Flesh);
        Visuals.Display.Set_Materials(Materials);
        Visuals.Cap.Set_MaterialID(1);
        Visuals.Cap.Set_Color(FLinearColor(0.839f, 0.617f, 0.644f, 1.0f));
        Visuals.Cap.Set_CmPerUVUnit(29.0);

        Visuals.Battered.Mesh = assets::Tentacle_Prep_Battered_Mars_SM();

        Layout.YawDegrees = 90.0;
    }

    // Puffer_Prep_Mars_SM: 13.4 x 14.1 x 10.5 cm, 588 cm3. Slots Skin (0), Horn = the spikes (1); the cap is slot 2. 0.59 kg =
    // 588 cm3 at 1.0 g/cm3. Round: unrotated. Cap: pale orange flesh, C(246, 196, 140).
    asset Food_Puffer_Mars of UMars_Food_Def
    {
        Data.Mesh = assets::Puffer_Prep_Mars_SM();
        Data.MassKg = 0.59;
        Data.Kind.AddTag(GameplayTags::Food_Meat);

        // A 15 g, 0.8 cm portion.
        Tuners = FMars_FoodPiece_Tuners(0.015, 0.8);

        const auto Skin = TSoftObjectPtr<UMaterialInterface>(assets::Puffer_Prep_Mars_MI().ToSoftObjectPath());
        TArray<TSoftObjectPtr<UMaterialInterface>> Materials;
        Materials.Add(Skin);
        Materials.Add(TSoftObjectPtr<UMaterialInterface>(assets::Horn_Mars_MI().ToSoftObjectPath()));
        Materials.Add(Skin);
        Visuals.Display.Set_Materials(Materials);
        Visuals.Cap.Set_MaterialID(2);
        Visuals.Cap.Set_Color(FLinearColor(0.922f, 0.552f, 0.262f, 1.0f));
        Visuals.Cap.Set_CmPerUVUnit(14.0);

        Visuals.Battered.Mesh = assets::Puffer_Prep_Battered_Mars_SM();
    }

    // SpikedBerry_Prep_Mars_SM: 9.3 x 10.1 x 7.7 cm, 250 cm3. Slots Skin (0), Horn = the spikes (1); the cap is slot 2. 0.24 kg
    // = 250 cm3 at 0.95 g/cm3. Round: unrotated. Cap: magenta berry flesh, C(214, 150, 196).
    asset Food_SpikedBerry_Mars of UMars_Food_Def
    {
        Data.Mesh = assets::SpikedBerry_Prep_Mars_SM();
        Data.MassKg = 0.24;
        Data.Kind.AddTag(GameplayTags::Food_Vegetable);

        // An 8 g, 0.6 cm portion.
        Tuners = FMars_FoodPiece_Tuners(0.008, 0.6);

        const auto Skin = TSoftObjectPtr<UMaterialInterface>(assets::SpikedBerry_Prep_Mars_MI().ToSoftObjectPath());
        TArray<TSoftObjectPtr<UMaterialInterface>> Materials;
        Materials.Add(Skin);
        Materials.Add(TSoftObjectPtr<UMaterialInterface>(assets::Horn_Mars_MI().ToSoftObjectPath()));
        Materials.Add(Skin);
        Visuals.Display.Set_Materials(Materials);
        Visuals.Cap.Set_MaterialID(2);
        Visuals.Cap.Set_Color(FLinearColor(0.672f, 0.305f, 0.552f, 1.0f));
        Visuals.Cap.Set_CmPerUVUnit(10.0);

        Visuals.Battered.Mesh = assets::SpikedBerry_Prep_Battered_Mars_SM();
    }

    // Mushroom_Prep_Mars_SM: the whole mushroom as one solid, 11.9 x 12.0 x 8.2 cm, 373 cm3. Slot Skin (0); the cap is slot 1.
    // 0.22 kg = 373 cm3 at 0.6 g/cm3 (a mushroom floats). Round: unrotated. Cap: the slice's painted flesh, C(235, 222, 200).
    asset Food_Mushroom_Mars of UMars_Food_Def
    {
        Data.Mesh = assets::Mushroom_Prep_Mars_SM();
        Data.MassKg = 0.22;
        Data.Kind.AddTag(GameplayTags::Food_Vegetable_Mushroom);

        // A 5 g, 0.8 cm portion.
        Tuners = FMars_FoodPiece_Tuners(0.005, 0.8);

        const auto Skin = TSoftObjectPtr<UMaterialInterface>(assets::Mushroom_Prep_Mars_MI().ToSoftObjectPath());
        TArray<TSoftObjectPtr<UMaterialInterface>> Materials;
        Materials.Add(Skin);
        Materials.Add(Skin);
        Visuals.Display.Set_Materials(Materials);
        Visuals.Cap.Set_MaterialID(1);
        Visuals.Cap.Set_Color(FLinearColor(0.831f, 0.731f, 0.578f, 1.0f));
        Visuals.Cap.Set_CmPerUVUnit(12.0);

        Visuals.Battered.Mesh = assets::Mushroom_Prep_Battered_Mars_SM();
    }
}
