// Editor-only vine commands.
//   Mars.Vine.SeedProfiles [force]  creates /Game/Mars/Environment/Dressing/Vines/Profiles/Vine<Preset>_Mars_DA from
//                                   utils_vine::Fill_Preset and binds the env kit's vine meshes (build_env_vines.py);
//                                   existing profiles are left alone unless "force" (which refills their numbers too).
//                                   A kit mesh that is not imported yet falls back to an engine shape, logged.
//   Mars.Vine.ReattachAll           re-solves every vine in the open level against the room as it is now.
//   Mars.Vine.Report                logs every vine's status line and the level totals.

#if EDITOR
UFUNCTION()
void Mars_VineSeedProfilesFunc(const TArray<FString>& Args)
{
    utils_vine_editor::SeedProfiles(Args.Contains("force"));
}

const FConsoleCommand Mars_VineSeedProfilesCommand("Mars.Vine.SeedProfiles", n"Mars_VineSeedProfilesFunc");

UFUNCTION()
void Mars_VineReattachAllFunc(const TArray<FString>& Args)
{
    utils_vine_editor::ReattachAll();
}

const FConsoleCommand Mars_VineReattachAllCommand("Mars.Vine.ReattachAll", n"Mars_VineReattachAllFunc");

UFUNCTION()
void Mars_VineReportFunc(const TArray<FString>& Args)
{
    utils_vine_editor::Report();
}

const FConsoleCommand Mars_VineReportCommand("Mars.Vine.Report", n"Mars_VineReportFunc");

namespace utils_vine_editor
{
    const FString k_ProfileFolder = "/Game/Mars/Environment/Dressing/Vines/Profiles";
    const FString k_MeshFolder = "/Game/Mars/Environment/Dressing/Meshes/Vines";
    const FString k_OrganicFolder = "/Game/Mars/Environment/Dressing/Meshes/Organic";
    const FString k_InstanceFolder = "/Game/Mars/Environment/Dressing/Materials/Instances";

    FString Get_ProfileName(EMars_VinePreset InPreset)
    {
        return f"Vine{InPreset :n}_Mars_DA";
    }

    UObject TryLoad(FString InFolder, FString InName)
    {
        const auto Path = f"{InFolder}/{InName}";
        if (EditorAsset::DoesAssetExist(Path) == false)
        { return nullptr; }
        return LoadObject(nullptr, f"{Path}.{InName}");
    }

    UStaticMesh Get_KitMesh(FString InName, UStaticMesh InFallback)
    {
        auto Mesh = Cast<UStaticMesh>(TryLoad(k_MeshFolder, f"{InName}_Mars_SM"));
        if (ck::IsValid(Mesh))
        { return Mesh; }
        Log(f"[Vine] {InName}_Mars_SM is not imported yet: the profile uses an engine shape until a forced reseed");
        return InFallback;
    }

    UMaterialInterface Get_Instance(FString InName)
    {
        return Cast<UMaterialInterface>(TryLoad(k_InstanceFolder, InName));
    }

    // The kit meshes and materials of one preset (engine shapes where the kit is missing: then the stems run along Z).
    void Bind_Kit(UMars_VineProfile InProfile, EMars_VinePreset InPreset)
    {
        auto& Meshes = InProfile.Stem.Meshes;
        auto Cylinder = engine::load::Cylinder();
        Meshes.ForwardAxis = ESplineMeshAxis::X;
        if (InPreset == EMars_VinePreset::Ivy)
        {
            Meshes.Mesh = Get_KitMesh("VineStemIvy", nullptr);
            InProfile.Leaves.Meshes.Reset();
            InProfile.Leaves.Weights.Reset();
            TArray<FString> Names;
            Names.Add("VineLeaves_A");
            Names.Add("VineLeaves_B");
            Names.Add("VineLeaves_C");
            TArray<float32> Weights;
            Weights.Add(0.5f);
            Weights.Add(0.35f);
            Weights.Add(0.15f);
            for (int32 Index = 0; Index < Names.Num(); ++Index)
            {
                auto Leaf = Get_KitMesh(Names[Index], nullptr);
                if (ck::IsValid(Leaf))
                {
                    InProfile.Leaves.Meshes.Add(Leaf);
                    InProfile.Leaves.Weights.Add(Weights[Index]);
                }
            }
        }
        else if (InPreset == EMars_VinePreset::GiantRoot || InPreset == EMars_VinePreset::ThinRoot)
        {
            const auto Giant = InPreset == EMars_VinePreset::GiantRoot;
            Meshes.Mesh = Get_KitMesh(Giant ? "VineBark_A" : "VineBark_B", nullptr);
            Meshes.AltMesh = Get_KitMesh(Giant ? "VineBark_B" : "VineBark_A", nullptr);
            Meshes.TipMesh = Get_KitMesh("VineTip", nullptr);
            Meshes.KnotMesh = Giant ? Get_KitMesh("VineKnot_A", nullptr) : nullptr;
            InProfile.Rendering.StemMaterial = Get_Instance("VineBarkRoot_Mars_MI");
        }
        else
        {
            InProfile.Strands.Meshes.Reset();
            TArray<FString> Names;
            if (InPreset == EMars_VinePreset::HangingMoss)
            {
                Names.Add("VineMossStrand_A");
                Names.Add("VineMossStrand_B");
                Names.Add("VineMossStrand_C");
            }
            else if (InPreset == EMars_VinePreset::Rootlets)
            {
                Names.Add("VineRootlet_A");
                Names.Add("VineRootlet_B");
                InProfile.Strands.LitterMesh = Cast<UStaticMesh>(TryLoad(k_OrganicFolder, "DeadLeaves_Scatter_A_Mars_SM"));
            }
            else
            { Names.Add("VineCobweb_A"); }

            for (auto Name : Names)
            {
                auto Card = Get_KitMesh(Name, nullptr);
                if (ck::IsValid(Card))
                { InProfile.Strands.Meshes.Add(Card); }
            }
        }

        // Nothing of the kit yet: engine shapes so the profile still validates and draws.
        if (InProfile.Stem.Render != EMars_VineStemRender::None && ck::Is_NOT_Valid(Meshes.Mesh))
        {
            Meshes.Mesh = Cylinder;
            Meshes.AltMesh = nullptr;
            Meshes.TipMesh = nullptr;
            Meshes.KnotMesh = nullptr;
            Meshes.ForwardAxis = ESplineMeshAxis::Z;
        }
        if (InProfile.Stem.Render == EMars_VineStemRender::None && InProfile.Strands.Meshes.Num() == 0)
        { InProfile.Strands.Meshes.Add(Cylinder); }
    }

    void SeedProfiles(bool InForce)
    {
        TArray<EMars_VinePreset> Presets;
        Presets.Add(EMars_VinePreset::Ivy);
        Presets.Add(EMars_VinePreset::GiantRoot);
        Presets.Add(EMars_VinePreset::ThinRoot);
        Presets.Add(EMars_VinePreset::HangingMoss);
        Presets.Add(EMars_VinePreset::Rootlets);
        Presets.Add(EMars_VinePreset::Cobweb);
        int32 Made = 0;
        int32 Refilled = 0;
        for (auto Preset : Presets)
        {
            const auto Name = Get_ProfileName(Preset);
            auto Profile = Cast<UMars_VineProfile>(TryLoad(k_ProfileFolder, Name));
            if (ck::IsValid(Profile) && InForce == false)
            { continue; }

            if (ck::Is_NOT_Valid(Profile))
            {
                auto Factory = Cast<UDataAssetFactory>(NewObject(GetTransientPackage(), UDataAssetFactory));
                Profile = Cast<UMars_VineProfile>(AssetTools::CreateAsset(Name, k_ProfileFolder, UMars_VineProfile, Factory));
                ++Made;
            }
            else
            { ++Refilled; }

            if (ck::Is_NOT_Valid(Profile))
            {
                Log(f"[Vine] could not create {Name}");
                continue;
            }

            utils_vine::Fill_Preset(Profile, Preset);
            Bind_Kit(Profile, Preset);
            const auto Result = Profile.Validate();
            if (Result.IsValid() == false)
            { Log(f"[Vine] {Name}: {Result.Get_Error()}"); }
            Profile.MarkPackageDirty();
            EditorAsset::SaveLoadedAsset(Profile, false);
        }
        Log(f"[Vine] SeedProfiles: {Made} created, {Refilled} refilled in {k_ProfileFolder}");
    }

    TArray<AMars_Vine> Get_LevelVines()
    {
        TArray<AMars_Vine> Vines;
        for (auto Actor : UEditorActorSubsystem::Get().GetAllLevelActors())
        {
            auto Vine = Cast<AMars_Vine>(Actor);
            if (ck::IsValid(Vine))
            { Vines.Add(Vine); }
        }
        return Vines;
    }

    void ReattachAll()
    {
        const auto Vines = Get_LevelVines();
        for (auto Vine : Vines)
        { Vine.Reattach(); }
        Log(f"[Vine] ReattachAll: {Vines.Num()} vines re-solved");
    }

    void Report()
    {
        const auto Vines = Get_LevelVines();
        int32 Traces = 0;
        int32 Segments = 0;
        int32 Leaves = 0;
        int32 Cards = 0;
        int32 Chords = 0;
        int32 Components = 0;
        for (auto Vine : Vines)
        {
            const auto R = Vine.Get_Report();
            TArray<UPrimitiveComponent> Emitted;
            Vine.Get_EmittedComponents(Emitted);
            Traces += Vine.Solved.TraceCount;
            Segments += R.Segments;
            Leaves += R.Leaves;
            Cards += R.Cards;
            Chords += R.Chords;
            Components += Emitted.Num();
            Log(f"[Vine] {Vine.GetActorLabel()}: {Vine.Status} ({Emitted.Num()} components)");
        }
        Log(f"[Vine] {Vines.Num()} vines: {Traces} traces solved, {Segments} segments, {Chords} chords, {Leaves} leaves, {Cards} cards, {Components} components");
    }
}
#endif
