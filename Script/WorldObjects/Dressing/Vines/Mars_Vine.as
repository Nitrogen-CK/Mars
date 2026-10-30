// AMars_Vine: one placeable vine, root, moss patch or cobweb. Its construction script traces the room (Visibility),
// solves the paths with the surface walk, caches the solve on the actor (Solved, keyed by an input hash) and emits the
// meshes. Every emitted component is created inside the construction script, so the engine destroys and rebuilds them
// on each rerun; an empty vine carries two components only. See VINES.md for the authoring contract.
//
// The cache: a rerun with unchanged inputs (profile solve fields, layout, shape, seed, transform, guide) traces nothing,
// so a level load never re-solves against half-registered collision. A changed room never re-solves silently: press
// Reattach (or run Mars.Vine.ReattachAll). Freeze keeps the solve even when the actor moves (paths are actor-local).
//
// Collision is Off by default: every primitive is NoCollision with the Ck.Jolt.NoBake tag, so editing a vine never
// needs a static-world re-cook. With Collision On, root segments are BlockAll and baked: re-cook after every edit.
class AMars_Vine : AActor
{
    default bReplicates = false;

    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent SceneRoot;
    default SceneRoot.Mobility = EComponentMobility::Static;

    // Spline layout: drag the points near surfaces. Other layouts: shows the solved main path.
    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    USplineComponent Guide;
    default Guide.bInputSplinePointsToConstructionScript = true;

    // Unset in the editor world: VineIvy_Mars_DA, kept here once found.
    UPROPERTY(Category = "Vine")
    UMars_VineProfile Profile;

    UPROPERTY(Category = "Vine")
    EMars_VineLayout Layout = EMars_VineLayout::Drop;

    UPROPERTY(Category = "Vine")
    EMars_VineEnd End = EMars_VineEnd::Ground;

    // 0 = derived from the position (Alt-drag copies differ); Reseed writes a new one.
    UPROPERTY(Category = "Vine")
    int32 Seed = 0;

    UPROPERTY(Category = "Vine")
    EMars_VineCollision Collision = EMars_VineCollision::FromProfile;

    UPROPERTY(Category = "Layout")
    FMars_Vine_Shape Shape;

    // Written by PCG (the traced floor distance x a length fraction); 0 = unused.
    UPROPERTY(Category = "Layout", AdvancedDisplay)
    float32 LengthOverrideCm = 0.0f;

    // Keep the cached solve whatever moves (the actor, the room).
    UPROPERTY(Category = "Solve")
    bool Freeze = false;

    UPROPERTY(Category = "Solve", VisibleAnywhere)
    FString Status;

    // BlueprintReadOnly: AActor::ResetPropertiesForConstruction resets every non-editable BlueprintReadWrite property to
    // its default before each construction script, which would drop the cache and the Reattach request.
    UPROPERTY(NotEditable, BlueprintReadOnly, AdvancedDisplay, Category = "Solve")
    FMars_Vine_Solved Solved;

    UPROPERTY(NotEditable, BlueprintReadOnly, Transient)
    bool ForceSolveOnce = false;

    private FMars_Vine_Report LastReport;
    private const FString DefaultProfileAsset = "/Game/Mars/Environment/Dressing/Vines/Profiles/VineIvy_Mars_DA";

    UFUNCTION(BlueprintOverride)
    void ConstructionScript()
    {
#if EDITOR
        SetbRunConstructionScriptOnDrag(false);
#endif
        DoBuild(true);
    }

    // Tests and buttons: a game world builds directly; the editor world reruns the construction script, because a
    // component created outside it there becomes an instance component and piles up.
    UFUNCTION(CallInEditor, Category = "Solve")
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

    // Re-solve against the room as it is now (after an environment change).
    UFUNCTION(CallInEditor, Category = "Solve")
    void Reattach()
    {
        ForceSolveOnce = true;
        Rebuild();
    }

    // A new non-zero seed.
    UFUNCTION(CallInEditor, Category = "Solve")
    void Reseed()
    {
        auto Stream = FRandomStream(int32(utils_vine::Hash_Fnv1a(f"{Seed},{Solved.InputHash},{GetName()}")));
        auto Next = int32(Stream.GetUnsignedInt() & uint32(0x7fffffff));
        Seed = Next == 0 ? 1 : Next;
        Rebuild();
    }

    //------------------------------------------------------------------------------------------------------------------
    // Test seams
    //------------------------------------------------------------------------------------------------------------------

    FMars_Vine_Report Get_Report() const
    {
        return LastReport;
    }

    int32 Get_PathCount() const
    {
        return Solved.Paths.Num();
    }

    bool Get_Path(int32 InIndex, FMars_Vine_Path& OutPath) const
    {
        if (Solved.Paths.IsValidIndex(InIndex) == false)
        { return false; }
        OutPath = Solved.Paths[InIndex];
        return true;
    }

    // World-space points of path InIndex.
    bool Get_PathPoints(int32 InIndex, TArray<FVector>& OutPoints) const
    {
        OutPoints.Reset();
        if (Solved.Paths.IsValidIndex(InIndex) == false)
        { return false; }
        const auto Frame = GetActorTransform();
        for (auto Point : Solved.Paths[InIndex].Points)
        { OutPoints.Add(Frame.TransformPosition(Point)); }
        return true;
    }

    void Get_EmittedComponents(TArray<UPrimitiveComponent>& OutComponents) const
    {
        OutComponents.Reset();
        for (auto Component : GetComponentsByClass(UPrimitiveComponent))
        {
            auto Primitive = Cast<UPrimitiveComponent>(Component);
            if (ck::IsValid(Primitive) && Primitive.ComponentTags.Contains(utils_vine::EmittedTag))
            { OutComponents.Add(Primitive); }
        }
    }

    // The request the next build would solve (the profile resolved).
    FMars_Vine_Request Get_Request() const
    {
        FMars_Vine_Request Request;
        Request.Profile = Profile;
        Request.Layout = Layout;
        Request.End = End;
        Request.Shape = Shape;
        Request.Seed = Seed != 0 ? Seed : utils_vine::Get_PositionSeed(GetActorLocation());
        Request.LengthOverrideCm = LengthOverrideCm;
        Request.Collides = Collision == EMars_VineCollision::On
            || (Collision == EMars_VineCollision::FromProfile && ck::IsValid(Profile) && Profile.Rendering.Collision);
        return Request;
    }

    //------------------------------------------------------------------------------------------------------------------
    // Build
    //------------------------------------------------------------------------------------------------------------------

    private void DoBuild(bool InInConstructionScript)
    {
        if (ck::Is_NOT_Valid(Profile))
        { TryLoad_DefaultProfile(); }

        const auto Request = Get_Request();
        ApplyPhysics(Request.Collides);
        DestroyEmitted();
        LastReport = FMars_Vine_Report();

        if (ck::Is_NOT_Valid(Request.Profile))
        {
            Status = "no profile";
            return;
        }

        const auto ProfileResult = Request.Profile.Validate();
        if (ck::EnsureIfNot(ProfileResult.IsValid(), f"[Vine] [{GetName()}] {ProfileResult.Get_Error()}"))
        {
            Status = ProfileResult.Get_Error();
            return;
        }

        const auto RequestResult = Request.Validate();
        if (ck::EnsureIfNot(RequestResult.IsValid(), f"[Vine] [{GetName()}] {RequestResult.Get_Error()}"))
        {
            Status = RequestResult.Get_Error();
            return;
        }

        const auto Hash = Get_InputHash(Request);
        const auto Cached = Solved.Valid && (Freeze || (Hash == Solved.InputHash && ForceSolveOnce == false));
        if (Cached == false)
        {
            FMars_Vine_Solver Solver;
            Solver.Req = Request;
            Solver.Ctx.Owner = this;
            Solver.Ctx.Frame = GetActorTransform();
            Solver.Ctx.Ignored.Add(this);
            if (Layout == EMars_VineLayout::Spline)
            { Solver.Ctx.Guide = Get_GuidePoints(); }
            Solved = Solver.Solve();
            Solved.InputHash = Hash;
            ForceSolveOnce = false;
        }

        FMars_Vine_Emitter Emitter;
        Emitter.Owner = this;
        Emitter.Req = Request;
        Emitter.Static = InInConstructionScript;
        LastReport = Emitter.Emit(Solved);
        LastReport.Cached = Cached;
        if (Cached)
        { LastReport.Traces = 0; }

        if (Layout != EMars_VineLayout::Spline)
        { Show_MainPath(); }

        Status = LastReport.ToString();
        if (Solved.NoFloorCount > 0)
        { Status = f"{Status}; no floor under {Solved.NoFloorCount} strands"; }
    }

    // The guide spline as the designer shaped it (its own curve, point types and tangents), sampled every StepCm.
    private TArray<FVector> Get_GuidePoints() const
    {
        TArray<FVector> Points;
        const auto Length = Guide.GetSplineLength();
        const auto Step = ck::IsValid(Profile) ? Math::Clamp(float(Profile.Attach.StepCm), 2.0, 200.0) : 10.0;
        const auto Samples = Math::Max(1, Math::CeilToInt(Length / Step));
        for (int32 Index = 0; Index <= Samples; ++Index)
        { Points.Add(Guide.GetLocationAtDistanceAlongSpline(Length * float(Index) / float(Samples), ESplineCoordinateSpace::Local)); }
        return Points;
    }

    private int32 Get_InputHash(const FMars_Vine_Request& InRequest) const
    {
        const auto Frame = GetActorTransform();
        const auto L = utils_vine::Quantize(Frame.GetLocation(), 0.1);
        const auto R = Frame.Rotator();
        const auto S = utils_vine::Quantize(Frame.GetScale3D(), 0.001);
        const auto& Sh = InRequest.Shape;
        auto Key = f"{InRequest.Profile.Get_SolveSignature()}|{int32(InRequest.Layout)},{int32(InRequest.End)},{InRequest.Seed},{InRequest.LengthOverrideCm :.1}";
        Key = f"{Key}|{Sh.LengthCm},{Sh.WidthCm},{Sh.StrandCount},{Sh.Turns},{Sh.HeightCm},{Sh.PatchRadiusCm},{Sh.GroundShare}";
        Key = f"{Key}|{L.ToString()}|{R.Pitch :.2},{R.Yaw :.2},{R.Roll :.2}|{S.ToString()}";
        if (InRequest.Layout == EMars_VineLayout::Spline)
        {
            for (auto Point : Get_GuidePoints())
            { Key = f"{Key}|{utils_vine::Quantize(Point, 0.1).ToString()}"; }
        }
        return int32(utils_vine::Hash_Fnv1a(Key));
    }

    // The main path written into the guide for visibility (HangingChain does the same).
    private void Show_MainPath()
    {
        Guide.ClearSplinePoints(false);
        if (Solved.Paths.Num() > 0)
        {
            for (auto Point : Solved.Paths[0].Points)
            { Guide.AddSplinePoint(Point, ESplineCoordinateSpace::Local, false); }
        }
        Guide.UpdateSpline();
    }

    private void DestroyEmitted()
    {
        TArray<UPrimitiveComponent> Emitted;
        Get_EmittedComponents(Emitted);
        for (auto Component : Emitted)
        { Component.DestroyComponent(); }
    }

    private void ApplyPhysics(bool InCollides)
    {
        if (InCollides)
        { Tags.Remove(utils_vine::JoltNoBakeTag); }
        else
        { Tags.AddUnique(utils_vine::JoltNoBakeTag); }
        Guide.SetCollisionProfileName(collision::profile::NoCollision);
        Guide.ComponentTags.AddUnique(utils_vine::JoltNoBakeTag);
    }

    // The ivy profile, looked up only in the editor world (a missing package must not log: it fails automation runs,
    // and the editor asset library refuses play worlds). Kept on Profile once found.
    private void TryLoad_DefaultProfile()
    {
#if EDITOR
        auto CurrentWorld = GetWorld();
        if (ck::Is_NOT_Valid(CurrentWorld) || CurrentWorld.IsGameWorld() || EditorAsset::DoesAssetExist(DefaultProfileAsset) == false)
        { return; }

        auto Found = Cast<UMars_VineProfile>(LoadObject(this, f"{DefaultProfileAsset}.VineIvy_Mars_DA"));
        if (ck::IsValid(Found))
        { Profile = Found; }
#endif
    }
}

// The class PCG spawns (VineCurtain_Mars_PCG, VineCeilingRoots_Mars_PCG). Spawn Actor applies its property overrides
// (Seed, LengthOverrideCm) to the spawn template, so the construction script already sees them; the profile, layout
// and end come from the graph node's template actor. Nothing here names a PCG type (PCG stays a local-only plugin).
class AMars_VinePcg : AMars_Vine
{
    default Layout = EMars_VineLayout::Curtain;
    default End = EMars_VineEnd::Air;
}
