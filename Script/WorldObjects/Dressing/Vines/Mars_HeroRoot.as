// AMars_HeroRoot: an atrium hero root stacked from Blender-sculpted modules (build_env_vines.py): a Top module at the
// ceiling contact (the actor), n Mid modules (350 cm, one full twist, any variant under any other at yaw 0 or 180) and a
// Flare module whose fingers reach the floor. The construction script traces the floor below the actor (or takes
// FixedHeightCm), picks n = round((H - Top - Flare) / Mid) and stretches every Mid by one shared zScale, which must stay
// in [0.8, 1.25]; the modules meet on their canonical joint loops, so a stretched stack has no seams.
//
// Collision defaults to On (players walk into 70 cm roots): the modules are BlockAll and baked by CkJolt, so re-cook the
// static world after an edit. Off: NoCollision and the Ck.Jolt.NoBake tag, like every other vine.

// Module heights (cm): the kit's are 180 / 350 / 160; tests use engine-cylinder stand-ins with their own.
struct FMars_HeroRoot_Heights
{
    UPROPERTY(meta = (ClampMin = "1.0"))
    float32 TopCm = 180.0f;

    UPROPERTY(meta = (ClampMin = "1.0"))
    float32 MidCm = 350.0f;

    UPROPERTY(meta = (ClampMin = "1.0"))
    float32 FlareCm = 160.0f;
}

// The stack a height asks for.
struct FMars_HeroRoot_Stack
{
    float HeightCm = 0.0;
    int32 Mids = 1;
    float ZScale = 1.0;
    FMars_HeroRoot_Heights Heights;
}

mixin FMars_Validation Validate(const FMars_HeroRoot_Stack& Self)
{
    if (Self.HeightCm <= 0.0)
    { return FMars_Validation("no floor below the hero root (height 0): set FixedHeightCm or move it over a floor"); }

    if (Self.ZScale < 0.8 || Self.ZScale > 1.25)
    {
        return FMars_Validation(f"a {Self.HeightCm :.0} cm height stretches the mid modules by {Self.ZScale :.2} (allowed 0.8 - 1.25): move the root or set FixedHeightCm");
    }
    return FMars_Validation();
}

namespace utils_vine
{
    FMars_HeroRoot_Stack Plan_HeroStack(const FMars_HeroRoot_Heights& InHeights, float InHeightCm)
    {
        FMars_HeroRoot_Stack Stack;
        Stack.Heights = InHeights;
        Stack.HeightCm = InHeightCm;
        const auto Span = InHeightCm - float(InHeights.TopCm) - float(InHeights.FlareCm);
        Stack.Mids = Math::Max(1, Math::RoundToInt(Span / float(InHeights.MidCm)));
        Stack.ZScale = Span / (float(Stack.Mids) * float(InHeights.MidCm));
        return Stack;
    }
}

class AMars_HeroRoot : AActor
{
    default bReplicates = false;

    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent SceneRoot;
    default SceneRoot.Mobility = EComponentMobility::Static;

    // Unset in the editor world: the kit modules (HeroRoot_Top_A / Mid_A..C / Flare_A..B), kept here once found.
    UPROPERTY(Category = "Hero Root")
    UStaticMesh TopMesh;

    UPROPERTY(Category = "Hero Root")
    TArray<UStaticMesh> MidMeshes;

    UPROPERTY(Category = "Hero Root")
    TArray<UStaticMesh> FlareMeshes;

    UPROPERTY(Category = "Hero Root")
    FMars_HeroRoot_Heights Heights;

    // 0 = traced to the floor below the actor (the actor is the ceiling contact).
    UPROPERTY(Category = "Hero Root", meta = (ClampMin = "0.0"))
    float32 FixedHeightCm = 0.0f;

    // 0 = derived from the position.
    UPROPERTY(Category = "Hero Root")
    int32 Seed = 0;

    UPROPERTY(Category = "Hero Root")
    bool Collides = true;

    // Unset: the meshes' own slot material (EnvBark_Mars_MI).
    UPROPERTY(Category = "Hero Root")
    UMaterialInterface Material;

    // Moss on the up-facing bark, as a factor (EnvPaint Env Data 1 = this - 1).
    UPROPERTY(Category = "Hero Root", meta = (ClampMin = "0.0", ClampMax = "2.0"))
    float32 MossScale = 1.0f;

    UPROPERTY(Category = "Hero Root", meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float32 WetAdd = 0.0f;

    UPROPERTY(Category = "Hero Root", VisibleAnywhere)
    FString Status;

    private FMars_HeroRoot_Stack LastStack;
    private TArray<bool> LastFlips;
    private const FString KitFolder = "/Game/Mars/Environment/Dressing/Meshes/Vines";

    UFUNCTION(BlueprintOverride)
    void ConstructionScript()
    {
#if EDITOR
        SetbRunConstructionScriptOnDrag(false);
#endif
        DoBuild(true);
    }

    UFUNCTION(CallInEditor, Category = "Hero Root")
    void Rebuild()
    {
        auto CurrentWorld = GetWorld();
        if (ck::IsValid(CurrentWorld) && CurrentWorld.IsGameWorld())
        {
            DoBuild(false);
            return;
        }
        utils_actor::Request_RerunConstructionScript(this);
    }

    FMars_HeroRoot_Stack Get_Stack() const
    {
        return LastStack;
    }

    // Per mid module, from the top: yawed 180 degrees.
    TArray<bool> Get_Flips() const
    {
        return LastFlips;
    }

    // The world z of the stack's top and bottom (the flare's lowest point), from the placed module bounds.
    FVector2D Get_CoverageZ() const
    {
        float Top = -1.0e9;
        float Bottom = 1.0e9;
        for (auto Component : GetComponentsByClass(UHierarchicalInstancedStaticMeshComponent))
        {
            auto Hism = Cast<UHierarchicalInstancedStaticMeshComponent>(Component);
            if (ck::Is_NOT_Valid(Hism) || ck::Is_NOT_Valid(Hism.GetStaticMesh()))
            { continue; }
            const auto Bounds = Hism.GetStaticMesh().GetBounds();
            for (int32 Index = 0; Index < Hism.GetInstanceCount(); ++Index)
            {
                FTransform T;
                Hism.GetInstanceTransform(Index, T, true);
                const auto Z = T.GetLocation().Z + Bounds.Origin.Z * T.GetScale3D().Z;
                const auto Half = Bounds.BoxExtent.Z * T.GetScale3D().Z;
                Top = Math::Max(Top, Z + Half);
                Bottom = Math::Min(Bottom, Z - Half);
            }
        }
        return FVector2D(Top, Bottom);
    }

    private void DoBuild(bool InInConstructionScript)
    {
        TryLoad_KitModules();
        DestroyEmitted();
        LastFlips.Reset();
        if (Collides)
        { Tags.Remove(utils_vine::JoltNoBakeTag); }
        else
        { Tags.AddUnique(utils_vine::JoltNoBakeTag); }

        if (ck::Is_NOT_Valid(TopMesh) || MidMeshes.Num() == 0 || FlareMeshes.Num() == 0)
        {
            Status = "no modules";
            return;
        }

        LastStack = utils_vine::Plan_HeroStack(Heights, Get_Height());
        const auto Result = LastStack.Validate();
        if (ck::EnsureIfNot(Result.IsValid(), f"[HeroRoot] [{GetName()}] {Result.Get_Error()}"))
        {
            Status = Result.Get_Error();
            return;
        }

        const auto EffectiveSeed = Seed != 0 ? Seed : utils_vine::Get_PositionSeed(GetActorLocation());
        auto Stream = utils_vine::Make_Stream(EffectiveSeed, 0, EMars_VineStream::Knot);
        const auto Mobility = InInConstructionScript ? EComponentMobility::Static : EComponentMobility::Movable;

        Place(TopMesh, FTransform(FVector(0.0, 0.0, Get_TopOffset(TopMesh, 1.0))), Mobility);
        float Z = -float(Heights.TopCm);
        const auto MidSpan = float(Heights.MidCm) * LastStack.ZScale;
        for (int32 Index = 0; Index < LastStack.Mids; ++Index)
        {
            UStaticMesh Mesh = MidMeshes[Stream.RandRange(0, MidMeshes.Num() - 1)];
            const auto Flip = Stream.GetFraction() < 0.5;
            LastFlips.Add(Flip);
            const auto Scale = FVector(1.0, 1.0, LastStack.ZScale);
            auto T = FTransform(FRotator(0.0, Flip ? 180.0 : 0.0, 0.0), FVector(0.0, 0.0, Z + Get_TopOffset(Mesh, LastStack.ZScale)), Scale);
            Place(Mesh, T, Mobility);
            Z -= MidSpan;
        }
        UStaticMesh Flare = FlareMeshes[Stream.RandRange(0, FlareMeshes.Num() - 1)];
        Place(Flare, FTransform(FRotator(0.0, Stream.RandRange(0.0, 360.0), 0.0), FVector(0.0, 0.0, Z + Get_TopOffset(Flare, 1.0))), Mobility);
        Status = f"{LastStack.Mids} mids, zScale {LastStack.ZScale :.3}, height {LastStack.HeightCm :.0} cm";
    }

    // The ceiling contact to the floor: traced (Visibility, simple) or fixed.
    private float Get_Height()
    {
        if (FixedHeightCm > 0.0f)
        { return float(FixedHeightCm); }

        TArray<AActor> Ignored;
        Ignored.Add(this);
        FHitResult Hit;
        const auto Start = GetActorLocation();
        if (System::LineTraceSingle(Start - FVector(0.0, 0.0, 1.0), Start - FVector(0.0, 0.0, 5000.0), ETraceTypeQuery::Visibility, false,
                Ignored, EDrawDebugTrace::None, Hit, true) == false)
        { return 0.0; }
        return Start.Z - Hit.ImpactPoint.Z;
    }

    // How far down to move a module so its bounds' top sits at its slot top (kit modules: 0, pivot at the top).
    private float Get_TopOffset(UStaticMesh InMesh, float InZScale) const
    {
        const auto Bounds = InMesh.GetBounds();
        return -(Bounds.Origin.Z + Bounds.BoxExtent.Z) * InZScale;
    }

    private void Place(UStaticMesh InMesh, FTransform InTransform, EComponentMobility InMobility)
    {
        UHierarchicalInstancedStaticMeshComponent Found;
        for (auto Component : GetComponentsByClass(UHierarchicalInstancedStaticMeshComponent))
        {
            auto Hism = Cast<UHierarchicalInstancedStaticMeshComponent>(Component);
            if (ck::IsValid(Hism) && Hism.GetStaticMesh() == InMesh && Hism.ComponentTags.Contains(utils_vine::EmittedTag))
            { Found = Hism; }
        }
        if (ck::Is_NOT_Valid(Found))
        {
            Found = UHierarchicalInstancedStaticMeshComponent::Create(this);
            Found.SetMobility(InMobility);
            Found.SetStaticMesh(InMesh);
            Found.ComponentTags.Add(utils_vine::EmittedTag);
            Found.SetNumCustomDataFloats(4);
            if (ck::IsValid(Material))
            { Found.SetMaterial(0, Material); }
            if (Collides)
            { Found.SetCollisionProfileName(collision::profile::BlockAll); }
            else
            {
                Found.SetCollisionProfileName(collision::profile::NoCollision);
                Found.ComponentTags.AddUnique(utils_vine::JoltNoBakeTag);
            }
        }
        const auto Index = Found.AddInstance(InTransform, false);
        auto TintStream = utils_vine::Make_Stream(Index + 1, 0, EMars_VineStream::Tint);
        const auto VarSeed = utils_vine::Frac(TintStream);
        Found.SetCustomDataValue(Index, 0, float32(VarSeed), false);
        Found.SetCustomDataValue(Index, 1, MossScale - 1.0f, false);
        Found.SetCustomDataValue(Index, 2, WetAdd, false);
        Found.SetCustomDataValue(Index, 3, 0.0f, true);
    }

    private void DestroyEmitted()
    {
        for (auto Component : GetComponentsByClass(UPrimitiveComponent))
        {
            auto Primitive = Cast<UPrimitiveComponent>(Component);
            if (ck::IsValid(Primitive) && Primitive.ComponentTags.Contains(utils_vine::EmittedTag))
            { Primitive.DestroyComponent(); }
        }
    }

    // The kit modules, looked up only in the editor world (a missing package must not log in a game world).
    private void TryLoad_KitModules()
    {
#if EDITOR
        auto CurrentWorld = GetWorld();
        if (ck::Is_NOT_Valid(CurrentWorld) || CurrentWorld.IsGameWorld())
        { return; }

        if (ck::Is_NOT_Valid(TopMesh))
        { TopMesh = TryLoad("HeroRoot_Top_A_Mars_SM"); }
        if (MidMeshes.Num() == 0)
        {
            for (auto ModuleName : Get_Names("HeroRoot_Mid_", "ABC"))
            {
                auto Mesh = TryLoad(ModuleName);
                if (ck::IsValid(Mesh))
                { MidMeshes.Add(Mesh); }
            }
        }
        if (FlareMeshes.Num() == 0)
        {
            for (auto ModuleName : Get_Names("HeroRoot_Flare_", "AB"))
            {
                auto Mesh = TryLoad(ModuleName);
                if (ck::IsValid(Mesh))
                { FlareMeshes.Add(Mesh); }
            }
        }
#endif
    }

    private TArray<FString> Get_Names(const FString& InPrefix, const FString& InVariants) const
    {
        TArray<FString> Names;
        for (int32 Index = 0; Index < InVariants.Len(); ++Index)
        { Names.Add(f"{InPrefix}{InVariants.Mid(Index, 1)}_Mars_SM"); }
        return Names;
    }

    private UStaticMesh TryLoad(const FString& InName)
    {
#if EDITOR
        const auto Path = f"{KitFolder}/{InName}";
        if (EditorAsset::DoesAssetExist(Path) == false)
        { return nullptr; }
        return Cast<UStaticMesh>(LoadObject(this, f"{Path}.{InName}"));
#else
        return nullptr;
#endif
    }
}
