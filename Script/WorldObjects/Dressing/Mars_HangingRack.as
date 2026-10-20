// Level-dressing rack: an iron bar along the actor's local X that pans, ladles, garlic braids and herb bundles hang from,
// each on an S-hook (and, for some, a few chain links below it so the row is not level). Mount decides what carries the bar:
//   Ceiling - the actor origin is on the ceiling over the bar's middle; two chains drop Drop cm from their ceiling
//             plates to the bar's ends (a pot rack over a table).
//   Wall    - the actor origin is on the wall face, +Y into the room; two brackets hold the bar BracketReach cm off the
//             wall (a rail for garlic and herbs).
// Hanging meshes follow one rule: their origin is the hang point (the ring or loop that goes over the hook) and they hang
// below it toward -Z, the broad side facing +Y. Which mesh hangs where, its turn and its swing come from Seed, so a rack
// rebuilds to the same row. Everything is instanced per mesh (ItemPoolCount distinct meshes at most), has no collision
// and carries the Ck.Jolt.NoBake tag: a rack hangs over heads and never needs a static-world re-cook.
enum EMars_RackMount
{
    Ceiling,
    Wall
}

class AMars_HangingRack : AMars_LinkDressing
{
    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent SceneRoot;
    default SceneRoot.Mobility = EComponentMobility::Static;

    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UStaticMeshComponent Bar;
    default Bar.Mobility = EComponentMobility::Static;

    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UHierarchicalInstancedStaticMeshComponent Links;
    default Links.Mobility = EComponentMobility::Static;

    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UHierarchicalInstancedStaticMeshComponent Hooks;
    default Hooks.Mobility = EComponentMobility::Static;

    // The ceiling plates (Ceiling) or the wall brackets (Wall).
    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UHierarchicalInstancedStaticMeshComponent Mounts;
    default Mounts.Mobility = EComponentMobility::Static;

    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UHierarchicalInstancedStaticMeshComponent Items0;
    default Items0.Mobility = EComponentMobility::Static;

    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UHierarchicalInstancedStaticMeshComponent Items1;
    default Items1.Mobility = EComponentMobility::Static;

    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UHierarchicalInstancedStaticMeshComponent Items2;
    default Items2.Mobility = EComponentMobility::Static;

    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UHierarchicalInstancedStaticMeshComponent Items3;
    default Items3.Mobility = EComponentMobility::Static;

    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UHierarchicalInstancedStaticMeshComponent Items4;
    default Items4.Mobility = EComponentMobility::Static;

    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UHierarchicalInstancedStaticMeshComponent Items5;
    default Items5.Mobility = EComponentMobility::Static;

    UPROPERTY(Category = "Layout")
    EMars_RackMount Mount = EMars_RackMount::Ceiling;

    // The bar's length along local X (cm), centred on the origin.
    UPROPERTY(Category = "Layout")
    float32 BarLength = 240.0f;

    // Ceiling: how far the bar hangs below the origin (cm).
    UPROPERTY(Category = "Layout")
    float32 Drop = 300.0f;

    // The chains (Ceiling) or the wall brackets (Wall) meet the bar this far in from its ends (cm).
    UPROPERTY(Category = "Layout")
    float32 ChainInset = 10.0f;

    // Ceiling: the chain starts this far below the origin (the plate's eye; the kit's ceiling hook is 14 cm).
    UPROPERTY(Category = "Layout")
    float32 PlateDrop = 14.0f;

    // Wall: the bar axis stands this far off the wall face (the bracket mesh's reach, cm).
    UPROPERTY(Category = "Layout")
    float32 BracketReach = 16.0f;

    // What hangs: one is picked per place from Seed. Unset entries are skipped; at most six distinct meshes.
    UPROPERTY(Category = "Hanging")
    TArray<UStaticMesh> ItemMeshes;

    // 0: as many as fit at ItemSpacing.
    UPROPERTY(Category = "Hanging")
    int32 ItemCount = 0;

    UPROPERTY(Category = "Hanging")
    float32 ItemSpacing = 34.0f;

    // Nothing hangs within this distance of the bar's ends (cm).
    UPROPERTY(Category = "Hanging")
    float32 EndMargin = 24.0f;

    UPROPERTY(Category = "Hanging")
    int32 Seed = 1;

    // The turn every item starts from (degrees about Z; 0 = broad side facing local +Y).
    UPROPERTY(Category = "Hanging")
    float32 ItemYaw = 0.0f;

    // Each item turns up to this far either way from ItemYaw (degrees).
    UPROPERTY(Category = "Hanging")
    float32 YawJitter = 25.0f;

    // Ceiling racks show both faces: half the items are turned about. A wall rail keeps every face to the room.
    UPROPERTY(Category = "Hanging")
    bool FlipHalf = true;

    // Each item leans up to this far off plumb (degrees).
    UPROPERTY(Category = "Hanging")
    float32 SwingJitter = 4.0f;

    // Some items hang on up to this much chain below their hook (cm), in whole links.
    UPROPERTY(Category = "Hanging")
    float32 ExtraDropMax = 24.0f;

    // The hook's cradle below the bar axis (the kit hook's 9 cm).
    UPROPERTY(Category = "Hanging")
    float32 HookDrop = 9.0f;

    // Unset: RackBar_Mars_SM when it is imported, else the engine cube as a bar. The mesh is 100 cm long along X.
    UPROPERTY(Category = "Meshes")
    UStaticMesh BarMesh;

    UPROPERTY(Category = "Meshes")
    UStaticMesh HookMesh;

    UPROPERTY(Category = "Meshes")
    UStaticMesh BracketMesh;

    // The ceiling anchor over each chain; its origin is the ceiling contact.
    UPROPERTY(Category = "Meshes")
    UStaticMesh PlateMesh;

    // Unset: the crypt kit's 14 cm link when it is imported; without it the rack hangs without chains.
    UPROPERTY(Category = "Meshes")
    UStaticMesh LinkMesh;

    // The kit link is 14 cm long with 3 cm wire: links interlock by two wires, so the pitch is 8 cm.
    UPROPERTY(Category = "Meshes")
    float32 LinkOverlap = 6.0f;

    private const int32 ItemPoolCount = 6;
    private const FString StationMeshFolder = "/Game/Mars/Gameplay/Cooking/Stations/Meshes";
    private const FVector CubeBarScale = FVector(0.01, 0.025, 0.025);

    UFUNCTION(BlueprintOverride)
    void ConstructionScript()
    {
        Rebuild();
    }

    UFUNCTION(CallInEditor, Category = "Layout")
    void Rebuild()
    {
        Resolve_DefaultMeshes();
        ApplyPhysics();

        Links.ClearInstances();
        Hooks.ClearInstances();
        Mounts.ClearInstances();
        Links.SetStaticMesh(LinkMesh);
        Hooks.SetStaticMesh(HookMesh);

        PlaceBar();
        if (Mount == EMars_RackMount::Ceiling)
        { HangBar(); }
        else
        { BracketBar(); }

        HangItems();
    }

    // The bar's middle, actor-local cm.
    FVector Get_BarCentre() const
    {
        if (Mount == EMars_RackMount::Ceiling)
        { return FVector(0.0, 0.0, -Math::Max(float(Drop), 0.0)); }

        return FVector(0.0, float(BracketReach), 0.0);
    }

    int32 Get_ItemCount() const
    {
        int32 Count = 0;
        for (auto Pool : Get_ItemPools())
        { Count += Pool.GetInstanceCount(); }

        return Count;
    }

    int32 Get_HookCount() const
    {
        return Hooks.GetInstanceCount();
    }

    int32 Get_LinkCount() const
    {
        return Links.GetInstanceCount();
    }

    // How many places the bar offers: ItemCount, or what fits between the end margins at ItemSpacing.
    int32 Get_PlaceCount() const
    {
        if (ItemCount > 0)
        { return ItemCount; }

        const float Span = Get_HangSpan();
        if (Span < 0.0 || ItemSpacing <= 0.0f)
        { return 0; }

        return Math::FloorToInt(Span / float(ItemSpacing)) + 1;
    }

    private float Get_HangSpan() const
    {
        return float(BarLength) - 2.0 * float(EndMargin);
    }

    private TArray<UHierarchicalInstancedStaticMeshComponent> Get_ItemPools() const
    {
        TArray<UHierarchicalInstancedStaticMeshComponent> Pools;
        Pools.Add(Items0);
        Pools.Add(Items1);
        Pools.Add(Items2);
        Pools.Add(Items3);
        Pools.Add(Items4);
        Pools.Add(Items5);
        return Pools;
    }

    // A repeatable value in [0, 1) per place and purpose.
    private float Get_Roll(int32 InPlace, int32 InPurpose) const
    {
        const float Value = Math::Sin(float(Seed) * 12.9898 + float(InPlace) * 78.233 + float(InPurpose) * 37.719) * 43758.5453;
        return Value - float(Math::FloorToInt(Value));
    }

    private float Get_LinkPitch() const
    {
        if (ck::Is_NOT_Valid(LinkMesh))
        { return 0.0; }

        return Get_LinkPitchOf(LinkMesh, FVector::OneVector, LinkOverlap);
    }

    // A straight vertical run of links from InTop down InLength cm; returns the length actually laid (whole links).
    private float LayDrop(FVector InTop, float InLength)
    {
        const float Pitch = Get_LinkPitch();
        if (Pitch <= 0.0)
        { return 0.0; }

        const int32 Count = Math::FloorToInt(InLength / Pitch);
        for (int32 Index = 0; Index < Count; ++Index)
        {
            // The link's long axis is +X: pitched straight down, alternate links turned 90 degrees about it.
            const float Roll = (Index % 2 == 1) ? 90.0 : 0.0;
            const auto Rotation = FRotator(-90.0, 0.0, 0.0).Quaternion() * FRotator(0.0, 0.0, Roll).Quaternion();
            Links.AddInstance(FTransform(Rotation, InTop - FVector(0.0, 0.0, (float(Index) + 0.5) * Pitch)), false);
        }

        return float(Count) * Pitch;
    }

    private void PlaceBar()
    {
        const bool IsCubeFallback = ck::Is_NOT_Valid(BarMesh);
        Bar.SetStaticMesh(IsCubeFallback ? engine::load::Cube() : BarMesh);
        if (IsCubeFallback)
        { Bar.SetMaterial(0, assets::load::ProtoGrid_Interactable_Mars_MI()); }

        // Both the kit bar and the cube are 100 cm along X.
        const float Stretch = Math::Max(float(BarLength), 1.0) * 0.01;
        const FVector Scale = IsCubeFallback ? FVector(Stretch, CubeBarScale.Y, CubeBarScale.Z) : FVector(Stretch, 1.0, 1.0);
        Bar.SetRelativeTransform(FTransform(FRotator::ZeroRotator, Get_BarCentre(), Scale));
    }

    private void HangBar()
    {
        Mounts.SetStaticMesh(PlateMesh);

        const float HalfSpan = Math::Max(float(BarLength) * 0.5 - float(ChainInset), 0.0);
        const float ChainTop = -float(PlateDrop);
        const float ChainLength = Math::Max(float(Drop) - float(PlateDrop), 0.0);

        for (int32 Side = -1; Side <= 1; Side += 2)
        {
            const FVector Anchor = FVector(float(Side) * HalfSpan, 0.0, 0.0);
            if (ck::IsValid(PlateMesh))
            { Mounts.AddInstance(FTransform(Anchor), false); }

            LayDrop(Anchor + FVector(0.0, 0.0, ChainTop), ChainLength);
        }
    }

    private void BracketBar()
    {
        Mounts.SetStaticMesh(BracketMesh);
        if (ck::Is_NOT_Valid(BracketMesh))
        { return; }

        const float HalfSpan = Math::Max(float(BarLength) * 0.5 - float(ChainInset), 0.0);
        for (int32 Side = -1; Side <= 1; Side += 2)
        { Mounts.AddInstance(FTransform(Get_BarCentre() + FVector(float(Side) * HalfSpan, 0.0, 0.0)), false); }
    }

    private void HangItems()
    {
        auto Pools = Get_ItemPools();
        TArray<UStaticMesh> PoolMeshes;
        for (auto Mesh : ItemMeshes)
        {
            if (ck::IsValid(Mesh) && PoolMeshes.Contains(Mesh) == false && PoolMeshes.Num() < ItemPoolCount)
            { PoolMeshes.Add(Mesh); }
        }

        for (int32 Index = 0; Index < Pools.Num(); ++Index)
        {
            Pools[Index].ClearInstances();
            Pools[Index].SetStaticMesh(Index < PoolMeshes.Num() ? PoolMeshes[Index] : nullptr);
        }

        const int32 Places = Get_PlaceCount();
        if (PoolMeshes.Num() == 0 || Places <= 0)
        { return; }

        const FVector Centre = Get_BarCentre();
        const float Span = Math::Max(Get_HangSpan(), 0.0);
        const float Pitch = Get_LinkPitch();

        for (int32 Place = 0; Place < Places; ++Place)
        {
            const float Along = Places > 1 ? (float(Place) / float(Places - 1) - 0.5) * Span : 0.0;
            const FVector OnBar = Centre + FVector(Along, 0.0, 0.0);

            if (ck::IsValid(HookMesh))
            { Hooks.AddInstance(FTransform(OnBar), false); }

            // Roughly two places in three hang straight off the hook; the rest get one or more links.
            float Extra = 0.0;
            if (Pitch > 0.0 && ExtraDropMax > 0.0f && Get_Roll(Place, 1) > 0.6)
            { Extra = LayDrop(OnBar - FVector(0.0, 0.0, float(HookDrop)), Get_Roll(Place, 2) * float(ExtraDropMax)); }

            const int32 Pick = Math::Min(Math::FloorToInt(Get_Roll(Place, 3) * float(PoolMeshes.Num())), PoolMeshes.Num() - 1);
            const float Flip = (FlipHalf && Get_Roll(Place, 4) > 0.5) ? 180.0 : 0.0;
            const float Yaw = float(ItemYaw) + Flip + (Get_Roll(Place, 5) * 2.0 - 1.0) * float(YawJitter);
            const float Lean = (Get_Roll(Place, 6) * 2.0 - 1.0) * float(SwingJitter);
            const float Tip = (Get_Roll(Place, 7) * 2.0 - 1.0) * float(SwingJitter);

            const FVector HangPoint = OnBar - FVector(0.0, 0.0, float(HookDrop) + Extra);
            Pools[Pick].AddInstance(FTransform(FRotator(Tip, Yaw, Lean), HangPoint), false);
        }
    }

    // Instance properties cannot be defaults: they are applied per rebuild.
    private void ApplyPhysics()
    {
        TArray<UPrimitiveComponent> Primitives;
        Primitives.Add(Bar);
        Primitives.Add(Links);
        Primitives.Add(Hooks);
        Primitives.Add(Mounts);
        for (auto Pool : Get_ItemPools())
        { Primitives.Add(Pool); }

        for (auto Primitive : Primitives)
        { Apply_Collides(Primitive, false); }

        Apply_ActorBaked(false);
    }

    // The kit's rack hardware and link (TryLoad_EditorMesh: the editor world only). Found once, each is kept on its
    // property. A rack with no ItemMeshes hangs the three copper pieces.
    private void Resolve_DefaultMeshes()
    {
        if (ck::Is_NOT_Valid(BarMesh))
        { BarMesh = TryLoad_EditorMesh(StationMeshFolder, "RackBar_Mars_SM"); }

        if (ck::Is_NOT_Valid(HookMesh))
        { HookMesh = TryLoad_EditorMesh(StationMeshFolder, "RackHook_Mars_SM"); }

        if (ck::Is_NOT_Valid(BracketMesh))
        { BracketMesh = TryLoad_EditorMesh(StationMeshFolder, "RackBracket_Mars_SM"); }

        if (ck::Is_NOT_Valid(PlateMesh))
        { PlateMesh = TryLoad_EditorMesh(KitMeshFolder, "CryptChainHook_Mars_SM"); }

        if (ck::Is_NOT_Valid(LinkMesh))
        { LinkMesh = TryLoad_EditorMesh(KitMeshFolder, "CryptChainLink_Mars_SM"); }

        if (ItemMeshes.Num() > 0)
        { return; }

        TArray<FString> Defaults;
        Defaults.Add("HangPan_Mars_SM");
        Defaults.Add("HangSaucepan_Mars_SM");
        Defaults.Add("HangLadle_Mars_SM");
        for (const FString& MeshName : Defaults)
        {
            auto Mesh = TryLoad_EditorMesh(StationMeshFolder, MeshName);
            if (ck::IsValid(Mesh))
            { ItemMeshes.Add(Mesh); }
        }
    }
}
