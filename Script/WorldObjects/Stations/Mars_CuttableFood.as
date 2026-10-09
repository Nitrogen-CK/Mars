// A food a cutting station puts on its board, as the station's assembly composes it: what it is (Data), how small a cut
// may leave it (Tuners, the FoodPiece kernel's own), how it looks whole and cut (Visuals) and how it lies on the board
// (Layout). A new food for an existing station is a new asset of this class; the kernels and the station stay untouched.

struct FMars_CuttableFood_Data
{
    // CPU-readable, and under RuntimeMesh's import ceiling (2048 raw render vertices on LOD0).
    UPROPERTY()
    TSoftObjectPtr<UStaticMesh> Mesh;

    // The whole joint's mass; cuts split it by volume.
    UPROPERTY()
    float MassKg = 0.0;
}

struct FMars_CuttableFood_Visuals
{
    // One material per mesh material slot, then the cap's slot: every piece, whole or cut, wears these.
    UPROPERTY()
    FCk_RuntimeMeshDisplay_Visuals Display;

    // Every cut face: Cap.MaterialID names its slot in Display.
    UPROPERTY()
    FCk_RuntimeMesh_Cap Cap;
}

// The joint's pose from the station's pile point, never scaled.
struct FMars_CuttableFood_Layout
{
    UPROPERTY()
    float64 YawDegrees = 0.0;

    UPROPERTY()
    float64 LiftCm = 0.0;
}

class UMars_CuttableFood_Def : UDataAsset
{
    UPROPERTY(Category = "Data")
    FMars_CuttableFood_Data Data;

    UPROPERTY(Category = "Tuners")
    FMars_FoodPiece_Tuners Tuners;

    UPROPERTY(Category = "Visuals")
    FMars_CuttableFood_Visuals Visuals;

    UPROPERTY(Category = "Layout")
    FMars_CuttableFood_Layout Layout;

    // What only the definition knows. Mass, tuners and cap ranges are the FoodPiece spec's (checked when the joint is
    // composed); whether the materials cover the mesh's slots is the display's (checked when it is added).
    FMars_Validation Validate() const
    {
        if (Data.Mesh.IsNull())
        { return FMars_Validation(f"[{GetName()}] has no Data.Mesh"); }

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
}

// Asset literals live in mars:: so other files can name them (a global-scope asset is file-local).
namespace mars
{
    // MeatSlab_Mars_SM: 36.8 x 20.2 x 12.1 cm, pivot at its base centre, long axis +X, 6927 cm3. Slots Flesh (0), Skin = the fat
    // cap (1); the cap is slot 2. 7.27 kg = 6927 cm3 at 1.05 g/cm3, lean beef's density. Yawed 90 so the long axis runs along
    // the cleaver's travel. The Accent material multiplies the vertex colour by its tint, so a white cap shows the cut tint.
    asset CuttableFood_MeatSlab_Mars of UMars_CuttableFood_Def
    {
        Data.Mesh = assets::MeatSlab_Mars_SM();
        Data.MassKg = 7.27;

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
    asset CuttableFood_MushroomSlice_Mars of UMars_CuttableFood_Def
    {
        Data.Mesh = assets::Mushroom_Slice_Mars_SM();
        Data.MassKg = 0.032;

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
