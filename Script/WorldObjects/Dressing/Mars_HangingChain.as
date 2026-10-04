// Level-dressing chain. The actor origin is the first anchor; links are HISM instances laid along the Spline component,
// one per LinkPitch, each rolled 90 degrees from its neighbour about the chain tangent (the link mesh's long axis is +X).
// Layout decides who owns the spline points:
//   Spline   - the authored points (drag them in the viewport; bInputSplinePointsToConstructionScript keeps them).
//   Catenary - a sagging run from the origin to EndOffset (actor-local, cm) with Slack metres of extra chain; the
//              construction script rewrites the points from the catenary, so viewport point editing is off.
//   Drop     - a vertical hang of Length cm from the origin.
// Links have no collision and carry the Ck.Jolt.NoBake tag unless Collides is on: a colliding chain's instance count
// feeds the Jolt cook hash, so every edit to it needs a static-world re-cook.
enum EMars_ChainLayout
{
    Spline,
    Catenary,
    Drop
}

// y(x) = A cosh((x - X0) / A) + C through (0, 0) and (Span, Rise), arc length = straight distance + slack. Local frame, cm.
struct FMars_HangingChain_Catenary
{
    FVector End;
    float Span = 0.0;
    float Rise = 0.0;
    float A = 0.0;
    float X0 = 0.0;
    float C = 0.0;

    // False when the chain is taut, vertical or has no slack: the caller lays a straight run instead.
    bool Solve(FVector InEnd, float InSlackCm)
    {
        End = InEnd;
        Span = Math::Sqrt(InEnd.X * InEnd.X + InEnd.Y * InEnd.Y);
        Rise = InEnd.Z;
        if (Span < 1.0 || InSlackCm <= 0.0)
        { return false; }

        const float Length = InEnd.Size() + InSlackCm;
        const float Target = Math::Sqrt(Math::Max(Length * Length - Rise * Rise, 0.0));
        if (Target <= Span * 1.0001)
        { return false; }

        // f(a) = 2a sinh(Span / 2a) - Target falls monotonically from +inf to Span - Target < 0: one root, bisected.
        float Lo = Span * 0.01;
        float Hi = Span;
        while (Residual(Hi, Target) > 0.0 && Hi < Span * 1.0e4)
        { Hi *= 2.0; }

        for (int32 Iteration = 0; Iteration < 60; ++Iteration)
        {
            const float Mid = 0.5 * (Lo + Hi);
            if (Residual(Mid, Target) > 0.0)
            { Lo = Mid; }
            else
            { Hi = Mid; }
        }

        A = 0.5 * (Lo + Hi);
        const float HalfSinh = 2.0 * A * Math::Sinh(Span / (2.0 * A));
        X0 = Span * 0.5 - A * Asinh(Rise / HalfSinh);
        C = -A * Cosh(X0 / A);
        return true;
    }

    // The point at InAlpha of the horizontal span, 0 at the origin and 1 at End.
    FVector Point(float InAlpha) const
    {
        const float X = InAlpha * Span;
        const float Y = A * Cosh((X - X0) / A) + C;
        return FVector(End.X * InAlpha, End.Y * InAlpha, Y);
    }

    // The lowest point of the curve if the vertex lies inside the span, else the lower end.
    float Get_LowestZ() const
    {
        if (X0 > 0.0 && X0 < Span)
        { return A + C; }

        return Math::Min(0.0, Rise);
    }

    private float Residual(float InA, float InTarget) const
    {
        return 2.0 * InA * Math::Sinh(Span / (2.0 * InA)) - InTarget;
    }

    // Math:: binds Sinh but neither Cosh nor Asinh.
    private float Cosh(float InX) const
    {
        return 0.5 * (Math::Exp(InX) + Math::Exp(-InX));
    }

    private float Asinh(float InX) const
    {
        return Math::Loge(InX + Math::Sqrt(InX * InX + 1.0));
    }
}

class AMars_HangingChain : AActor
{
    default bReplicates = false;

    // Static with the links (a Static child cannot attach to a Movable root); UseStaticMobility flips both.
    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent SceneRoot;
    default SceneRoot.Mobility = EComponentMobility::Static;

    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    USplineComponent Spline;
    default Spline.bInputSplinePointsToConstructionScript = true;

    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UHierarchicalInstancedStaticMeshComponent Links;
    default Links.Mobility = EComponentMobility::Static;

    // The anchor plate at the origin; hidden while StartBracketMesh is unset.
    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UStaticMeshComponent StartBracket;

    // Hook, lantern or pan at the far end of the chain, tangent-aligned; hidden while EndAttachmentMesh is unset.
    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UStaticMeshComponent EndAttachment;

    UPROPERTY(Category = "Layout")
    EMars_ChainLayout Layout = EMars_ChainLayout::Catenary;

    // Catenary: the far anchor, actor-local cm.
    UPROPERTY(Category = "Layout", meta = (MakeEditWidget))
    FVector EndOffset = FVector(300.0, 0.0, 0.0);

    // Catenary: metres of chain beyond the straight line between the anchors.
    UPROPERTY(Category = "Layout")
    float32 Slack = 0.5f;

    // Drop: how far the chain hangs below the origin (cm).
    UPROPERTY(Category = "Layout")
    float32 Length = 150.0f;

    // Catenary: spline points generated along the curve.
    UPROPERTY(Category = "Layout")
    int32 CatenarySamples = 24;

    // Unset: the crypt kit's 14 cm link when it is imported, else the engine cube shaped like the pull chain's links.
    UPROPERTY(Category = "Links")
    UStaticMesh LinkMesh;

    // Unset: the mesh's own materials (the cube fallback gets the ProtoGrid interactable look).
    UPROPERTY(Category = "Links")
    UMaterialInterface LinkMaterial;

    // Long axis X along the chain.
    UPROPERTY(Category = "Links")
    FVector LinkScale = FVector::OneVector;

    // Centre-to-centre distance between links (cm); 0 derives it from the scaled mesh length minus LinkOverlap.
    UPROPERTY(Category = "Links")
    float32 LinkPitchOverride = 0.0f;

    // The kit link is 14 cm long with 3 cm wire: links interlock by two wires, so the pitch is 8 cm.
    UPROPERTY(Category = "Links")
    float32 LinkOverlap = 6.0f;

    private const FString KitLinkAsset = "/Game/Mars/Environment/Meshes/Crypt/CryptChainLink_Mars_SM";
    private const FVector CubeLinkScale = FVector(0.07, 0.015, 0.04);

    UPROPERTY(Category = "Links")
    bool AlternateRoll = true;

    UPROPERTY(Category = "Attachments")
    UStaticMesh StartBracketMesh;

    UPROPERTY(Category = "Attachments")
    UStaticMesh EndAttachmentMesh;

    // Applied on top of the chain-end transform (tangent = X).
    UPROPERTY(Category = "Attachments")
    FTransform EndAttachmentOffset;

    // Off: no collision and excluded from the Jolt bake. On: BlockAll and baked; re-cook the static world after edits.
    UPROPERTY(Category = "Physics")
    bool Collides = false;

    UPROPERTY(Category = "Physics")
    bool UseStaticMobility = true;

    private const FName JoltNoBakeTag = n"Ck.Jolt.NoBake";

    UFUNCTION(BlueprintOverride)
    void ConstructionScript()
    {
        Rebuild();
    }

    UFUNCTION(CallInEditor, Category = "Layout")
    void Rebuild()
    {
        auto Mesh = LinkMesh;
        if (ck::Is_NOT_Valid(Mesh))
        { Mesh = TryLoad_KitLink(); }

        const bool IsCubeFallback = ck::Is_NOT_Valid(Mesh);
        if (IsCubeFallback)
        { Mesh = engine::load::Cube(); }

        if (ck::Is_NOT_Valid(Mesh))
        { return; }

        Links.SetStaticMesh(Mesh);
        if (ck::IsValid(LinkMaterial))
        { Links.SetMaterial(0, LinkMaterial); }
        else if (IsCubeFallback)
        { Links.SetMaterial(0, assets::load::ProtoGrid_Interactable_Mars_MI()); }

        const FVector Scale = IsCubeFallback ? LinkScale * CubeLinkScale : LinkScale;

        ApplyPhysics();
        AuthorSpline();
        LayLinks(Get_LinkPitch(Mesh, Scale), Scale);
        PlaceAttachments();
    }

    int32 Get_LinkCount() const
    {
        return Links.GetInstanceCount();
    }

    bool Get_LinkTransform(int32 InIndex, FTransform& OutLocal) const
    {
        return Links.GetInstanceTransform(InIndex, OutLocal, false);
    }

    float Get_ChainLength() const
    {
        return Spline.GetSplineLength();
    }

    // The kit link, looked up only in the editor world (a missing package must not log: it fails automation runs,
    // and the editor asset library refuses play worlds). Found once, it is kept on LinkMesh so PIE and cooked builds
    // never look it up.
    private UStaticMesh TryLoad_KitLink()
    {
#if EDITOR
        auto World = GetWorld();
        if (ck::Is_NOT_Valid(World) || World.IsGameWorld() || EditorAsset::DoesAssetExist(KitLinkAsset) == false)
        { return nullptr; }

        auto Found = Cast<UStaticMesh>(LoadObject(this, f"{KitLinkAsset}.CryptChainLink_Mars_SM"));
        if (ck::IsValid(Found))
        { LinkMesh = Found; }

        return Found;
#else
        return nullptr;
#endif
    }

    // Instance properties cannot be defaults: they are applied per rebuild.
    private void ApplyPhysics()
    {
        const auto Mobility = UseStaticMobility ? EComponentMobility::Static : EComponentMobility::Movable;
        SceneRoot.SetMobility(Mobility);
        Links.SetMobility(Mobility);

        TArray<UPrimitiveComponent> Primitives;
        Primitives.Add(Links);
        Primitives.Add(StartBracket);
        Primitives.Add(EndAttachment);

        for (auto Primitive : Primitives)
        {
            if (Collides)
            {
                Primitive.SetCollisionProfileName(collision::profile::BlockAll);
                Primitive.ComponentTags.Remove(JoltNoBakeTag);
            }
            else
            {
                Primitive.SetCollisionProfileName(collision::profile::NoCollision);
                Primitive.ComponentTags.AddUnique(JoltNoBakeTag);
            }
        }

        if (Collides)
        { Tags.Remove(JoltNoBakeTag); }
        else
        { Tags.AddUnique(JoltNoBakeTag); }
    }

    private void AuthorSpline()
    {
        if (Layout == EMars_ChainLayout::Spline)
        { return; }

        Spline.ClearSplinePoints(false);

        if (Layout == EMars_ChainLayout::Drop)
        {
            Spline.AddSplinePoint(FVector::ZeroVector, ESplineCoordinateSpace::Local, false);
            Spline.AddSplinePoint(FVector(0.0, 0.0, -Math::Max(float(Length), 1.0)), ESplineCoordinateSpace::Local, false);
            Spline.UpdateSpline();
            return;
        }

        FMars_HangingChain_Catenary Curve;
        if (Curve.Solve(EndOffset, float(Slack) * 100.0) == false)
        {
            Spline.AddSplinePoint(FVector::ZeroVector, ESplineCoordinateSpace::Local, false);
            Spline.AddSplinePoint(EndOffset, ESplineCoordinateSpace::Local, false);
            Spline.UpdateSpline();
            return;
        }

        const int32 Samples = Math::Max(CatenarySamples, 2);
        for (int32 Index = 0; Index < Samples; ++Index)
        {
            const float Alpha = float(Index) / float(Samples - 1);
            Spline.AddSplinePoint(Curve.Point(Alpha), ESplineCoordinateSpace::Local, false);
        }

        Spline.UpdateSpline();
    }

    // The overlap never eats more than half a link: a short fallback link still reads as a chain.
    private float Get_LinkPitch(UStaticMesh InMesh, FVector InScale) const
    {
        if (LinkPitchOverride > 0.0f)
        { return float(LinkPitchOverride); }

        const float MeshLength = 2.0 * InMesh.GetBounds().BoxExtent.X * InScale.X;
        return Math::Max(MeshLength - float(LinkOverlap), Math::Max(MeshLength * 0.5, 1.0));
    }

    // DefaultComponents survive construction-script reruns, so the instances must be cleared first.
    private void LayLinks(float InPitch, FVector InScale)
    {
        Links.ClearInstances();

        const float ChainLength = Spline.GetSplineLength();
        const int32 Count = Math::FloorToInt(ChainLength / InPitch);

        for (int32 Index = 0; Index < Count; ++Index)
        {
            const float Distance = float(Index) * InPitch + InPitch * 0.5;
            auto Link = Spline.GetTransformAtDistanceAlongSpline(Distance, ESplineCoordinateSpace::Local, false);

            // Alternating links turned 90 degrees about the tangent, like a real chain.
            const float Roll = (AlternateRoll && Index % 2 == 1) ? 90.0 : 0.0;
            Link.SetRotation(Link.GetRotation() * FRotator(0.0, 0.0, Roll).Quaternion());
            Link.SetScale3D(InScale);
            Links.AddInstance(Link, false);
        }
    }

    private void PlaceAttachments()
    {
        StartBracket.SetStaticMesh(StartBracketMesh);
        StartBracket.SetVisibility(ck::IsValid(StartBracketMesh));
        StartBracket.SetRelativeTransform(FTransform::Identity);

        EndAttachment.SetStaticMesh(EndAttachmentMesh);
        EndAttachment.SetVisibility(ck::IsValid(EndAttachmentMesh));

        auto ChainEnd = Spline.GetTransformAtDistanceAlongSpline(Spline.GetSplineLength(), ESplineCoordinateSpace::Local, false);
        ChainEnd.SetScale3D(FVector::OneVector);
        EndAttachment.SetRelativeTransform(EndAttachmentOffset * ChainEnd);
    }
}
