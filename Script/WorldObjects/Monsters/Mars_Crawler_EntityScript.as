// Where a fang points, in the body's frame: Spread turns it outward from straight ahead (negative crosses the pair),
// Droop tips it down.
struct FMars_Crawler_FangPose
{
    float32 Spread = 0.0f;
    float32 Droop = 0.0f;

    FMars_Crawler_FangPose() {}

    FMars_Crawler_FangPose(float32 InSpread, float32 InDroop)
    {
        Spread = InSpread;
        Droop = InDroop;
    }
}

// One ISM renderer per tint, each with its own LitMetal MID.
struct FMars_Crawler_TintedRenderer
{
    UPROPERTY()
    FLinearColor Color;

    UPROPERTY()
    UCk_IsmRenderer_Data Renderer;
}

// One rig leg's two segment pieces, hip end first.
struct FMars_Crawler_LegLook
{
    UPROPERTY()
    TSoftObjectPtr<UStaticMesh> Upper;

    UPROPERTY()
    TSoftObjectPtr<UStaticMesh> Lower;

    FMars_Crawler_LegLook() {}

    FMars_Crawler_LegLook(TSoftObjectPtr<UStaticMesh> InUpper, TSoftObjectPtr<UStaticMesh> InLower)
    {
        Upper = InUpper;
        Lower = InLower;
    }
}

// The meshes a crawler wears instead of engine-cube boxes, cut from a model at one uniform scale and laid out on a rig
// measured off the same model (Tools/Blender/mars_monsters/build_crawler_pieces.py), so it fits only that rig: the body
// centred on its bounds, front along +X; a segment pivoting at the midpoint of its joints, +X hip to foot, +Y toward the
// leg's pole (the rig's convention), one pair per rig leg in rig order; the foot pointing down; the fang pivoting at its
// root, root to tip along +X. A part wearing a mesh takes the box round its pivot that encloses the mesh as its half
// extents, so its hurtbox covers what is drawn. Material, when set, replaces every piece's slot 0. An empty look keeps the
// boxes.
struct FMars_Crawler_Look
{
    UPROPERTY()
    TSoftObjectPtr<UStaticMesh> Body;

    UPROPERTY()
    TArray<FMars_Crawler_LegLook> Legs;

    UPROPERTY()
    TSoftObjectPtr<UStaticMesh> Foot;

    UPROPERTY()
    TSoftObjectPtr<UStaticMesh> Fang;

    // The right fang's root in the body's frame; the left one mirrors it.
    UPROPERTY()
    FVector FangRoot = FVector::ZeroVector;

    UPROPERTY()
    TSoftObjectPtr<UMaterialInterface> Material;
}

mixin bool Get_IsEmpty(const FMars_Crawler_Look& Self)
{
    return Self.Body.IsNull() && Self.Legs.Num() == 0 && Self.Foot.IsNull() && Self.Fang.IsNull();
}

struct FMars_Crawler_LegMeshes
{
    UPROPERTY()
    UStaticMesh Upper;

    UPROPERTY()
    UStaticMesh Lower;
}

// A look's pieces, loaded. Material may stay null (the pieces keep their own).
struct FMars_Crawler_LookMeshes
{
    UPROPERTY()
    UStaticMesh Body;

    UPROPERTY()
    TArray<FMars_Crawler_LegMeshes> Legs;

    UPROPERTY()
    UStaticMesh Foot;

    UPROPERTY()
    UStaticMesh Fang;

    UPROPERTY()
    UMaterialInterface Material;
}

mixin bool Get_IsComplete(const FMars_Crawler_LookMeshes& Self)
{
    if (ck::Is_NOT_Valid(Self.Body) || ck::Is_NOT_Valid(Self.Foot) || ck::Is_NOT_Valid(Self.Fang) || Self.Legs.Num() == 0)
    { return false; }

    for (const auto& Leg : Self.Legs)
    {
        if (ck::Is_NOT_Valid(Leg.Upper) || ck::Is_NOT_Valid(Leg.Lower))
        { return false; }
    }
    return true;
}

// One rig part's visual: an engine-cube box of HalfExtents tinted Color, or Mesh at its authored size when set.
struct FMars_Crawler_PartVisual
{
    UPROPERTY()
    FVector HalfExtents;

    UPROPERTY()
    FLinearColor Color;

    UPROPERTY()
    UStaticMesh Mesh;

    FMars_Crawler_PartVisual() {}

    FMars_Crawler_PartVisual(FVector InHalfExtents, FLinearColor InColor, UStaticMesh InMesh)
    {
        HalfExtents = InHalfExtents;
        Color = InColor;
        Mesh = InMesh;
    }
}

// One ISM renderer per look mesh.
struct FMars_Crawler_MeshRenderer
{
    UPROPERTY()
    UStaticMesh Mesh;

    UPROPERTY()
    UCk_IsmRenderer_Data Renderer;
}

// Placeable crawler (Room 5): a 4- or 6-legged procedural walker whose every leg is a body part. This script owns the
// visuals: it builds the presentation, segment and foot transform entities (each a DIRECT lifetime child of the root, as
// the rig requires) with ISM box visuals tinted Color, or the pieces of Look when it is set, then hands them to
// utils_crawler::Add in Spec.Rig, which composes the walker, the monster, the leg parts and their hurtboxes. Render scale
// lives on the ISM proxies, never on the entities: the gait, the rig and Jolt use the unscaled transforms.
//
// A pincer crawler also wears two fangs under the front of its body: scene nodes on the presentation, so they ride the
// body through the rear and the lunge. They are dressing only (no hurtbox, no hit): each frame they ease toward the pose
// of the attack's phase, flared wide through the windup, snapped shut across each other on the strike.
class UMars_Crawler_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    // An unset (empty) RoamBounds becomes +-400 around the spawn at construction.
    UPROPERTY(ExposeOnSpawn)
    FMars_Crawler_Spec Spec;

    // The body tint; the leg segments darken along the chain.
    UPROPERTY(ExposeOnSpawn)
    FLinearColor Color = FLinearColor(0.75f, 0.35f, 0.2f, 1.0f);

    // False builds the same rig entities with no ISM visuals: headless autotests (no compiled look material under
    // -nullrhi, and the transient ISM renderers would outlive the test's entity subtree).
    UPROPERTY(ExposeOnSpawn)
    bool WithVisuals = true;

    // Debugging only: each frame of an attack, draws the accepted hit sphere at the kernel's accepted hit centre, the
    // segment the last accepted sample swept, and a line from the accepted body to the hit centre, coloured by phase
    // (Windup yellow, Strike red, Recover and CancelRecover blue, Cooldown grey). Everything comes from the attack's
    // recorded observations, never from the requested pose. Nothing is drawn while Idle or on an unarmed crawler.
    UPROPERTY(ExposeOnSpawn)
    bool DebugDrawAttack = false;

    // Not spawn-exposed: a preset sets it in DoConstruct before calling Super. Ignored without visuals, so the headless
    // rig always measures as boxes.
    protected FMars_Crawler_Look Look;

    private const float64 DefaultRoamHalfExtent = 400.0;
    private const float64 DefaultRoamHalfHeight = 200.0;
    private const float64 SegmentHalfThickness = 6.0;
    private const float64 FootHalfExtent = 8.0;
    // The jab's default start distance beyond the body's half length (horizontal root-to-target).
    private const float64 StartDistanceMargin = 70.0;

    private const float32 DebugDrawThickness = 1.5f;

    // A fang is a box FangLength long; its root sits under the body's front edge, FangRootInset back from the front face,
    // FangRootHalfGap to either side of the centreline and FangRootDrop below the body's centre.
    private const float64 FangLength = 26.0;
    private const float64 FangHalfThickness = 3.5;
    private const float64 FangRootInset = 3.0;
    private const float64 FangRootHalfGap = 9.0;
    private const float64 FangRootDrop = 9.0;
    // Degrees: Spread then Droop. At rest the fangs hang a little apart; the windup flares them wide and level; the strike
    // drives them down and across each other.
    private const float32 FangRestSpread = 10.0f;
    private const float32 FangRestDroop = 62.0f;
    private const float32 FangFlaredSpread = 55.0f;
    private const float32 FangFlaredDroop = 20.0f;
    private const float32 FangShutSpread = -12.0f;
    private const float32 FangShutDroop = 75.0f;
    // How fast the fangs close on the phase's pose, per second: the snap is several times the flare.
    private const float32 FangEaseRate = 10.0f;
    private const float32 FangSnapRate = 45.0f;

    // Created on first use of each tint.
    private TArray<FMars_Crawler_TintedRenderer> _Renderers;

    // Look only: its pieces (empty without one) and a renderer per piece, created on first use.
    private FMars_Crawler_LookMeshes _LookMeshes;
    private TArray<FMars_Crawler_MeshRenderer> _MeshRenderers;

    // DebugDrawAttack only: the armed crawler and the last two accepted hit centres seen.
    private FCk_Handle_Crawler _DebugCrawler;
    private FVector _DebugCenter = FVector::ZeroVector;
    private FVector _DebugPreviousCenter = FVector::ZeroVector;

    // Fangs only: the crawler they follow, the two nodes (right then left), their roots in the body's frame and the pose
    // they hold now.
    private FCk_Handle_Crawler _FangCrawler;
    private TArray<FCk_Handle_SceneNode> _Fangs;
    private TArray<FVector> _FangRoots;
    // How far along its facing a fang's pivot sits from its root: half the box; 0 for a look's fang, which pivots at its
    // root.
    private float64 _FangPivotDistance = FangLength * 0.5;
    private FMars_Crawler_FangPose _FangPose;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        // First: the crawler's sub-SM resolves ck::Ctx to this root only if the override precedes every child.
        InHandle.Request_OverrideToSelf();

        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_handle::Set_DebugName(InHandle, FName(f"Crawler{Spec.LegCount}"));

        // Before any rig entity or visual is built: only some leg counts have a rig asset.
        auto RigData = Spec.Get_RigData();
        if (ck::EnsureIfNot(ck::IsValid(RigData), f"[Crawler] [{InHandle.ToString()}] has LegCount [{Spec.LegCount}] with no rig on its layout"))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        auto CrawlerSpec = Spec;
        if (CrawlerSpec.RoamBounds.Max.X <= CrawlerSpec.RoamBounds.Min.X || CrawlerSpec.RoamBounds.Max.Y <= CrawlerSpec.RoamBounds.Min.Y)
        {
            const auto Half = FVector(DefaultRoamHalfExtent, DefaultRoamHalfExtent, DefaultRoamHalfHeight);
            CrawlerSpec.RoamBounds = FBox(SpawnTransform.GetLocation() - Half, SpawnTransform.GetLocation() + Half);
        }

        _LookMeshes = Load_Look(InHandle, RigData.Get_Legs().Num());
        CrawlerSpec.Rig = BuildRig(InHandle, RigData);
        if (CrawlerSpec.Combat.Enabled)
        { DefaultCombatGeometry(CrawlerSpec); }

        const auto Crawler = utils_crawler::Add(Root, CrawlerSpec);
        utils_entity_tag::Add(InHandle, n"TAG_MarsCrawler");

        // The timer dies with the entity; nothing to unbind.
        if (WithVisuals && ck::IsValid(Crawler) && CrawlerSpec.Combat.Enabled && CrawlerSpec.Combat.Pincer.Enabled)
        {
            _FangCrawler = Crawler;
            BuildFangs(InHandle, CrawlerSpec.Rig);
            utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnFangTick"));
        }

        // The timer dies with the entity; nothing to unbind.
        if (DebugDrawAttack && ck::IsValid(Crawler) && Crawler.Get_IsCombatArmed())
        {
            _DebugCrawler = Crawler;
            utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnDebugDrawAttackTick"));
        }

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    // The jab hits from the body's front face and starts within its half length plus StartDistanceMargin, unless the
    // spec authored either.
    private void DefaultCombatGeometry(FMars_Crawler_Spec& InOutSpec)
    {
        const auto HalfLength = InOutSpec.Rig.BodyHalfExtents.X;
        if (InOutSpec.Combat.Hit.LocalCenter == FVector::ZeroVector)
        { InOutSpec.Combat.Hit.LocalCenter = FVector(HalfLength, 0.0, 0.0); }

        if (InOutSpec.Combat.Prepare.StartDistance == 0.0f)
        { InOutSpec.Combat.Prepare.StartDistance = float32(HalfLength + StartDistanceMargin); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Fangs
    //----------------------------------------------------------------------------------------------------------------------

    private void BuildFangs(FCk_Handle& InRoot, const FMars_Crawler_Rig& InRig)
    {
        const auto FangColor = FLinearColor(0.85f, 0.85f, 0.8f, 1.0f);
        const auto WearsMesh = ck::IsValid(_LookMeshes.Fang);
        // A fang mesh pivots at its root and is drawn unscaled; the box is the engine cube (50 uu half extent) scaled to
        // the fang and centred on it.
        const auto Scale = WearsMesh ? FVector::OneVector : FVector(FangLength * 0.5, FangHalfThickness, FangHalfThickness) / 50.0;
        _FangPivotDistance = WearsMesh ? 0.0 : FangLength * 0.5;
        auto Renderer = WearsMesh ? GetOrCreate_MeshRenderer(InRoot, _LookMeshes.Fang) : GetOrCreate_Renderer(InRoot, FangColor);
        auto Presentation = InRig.Presentation;
        _FangPose = FMars_Crawler_FangPose(FangRestSpread, FangRestDroop);

        for (int32 Index = 0; Index < 2; ++Index)
        {
            const auto Side = Index == 0 ? 1.0 : -1.0;
            const auto FangRoot = WearsMesh
                ? FVector(Look.FangRoot.X, Look.FangRoot.Y * Side, Look.FangRoot.Z)
                : FVector(InRig.BodyHalfExtents.X - FangRootInset, FangRootHalfGap * Side, -FangRootDrop);
            auto Fang = utils_scene_node::Create(Presentation, Make_FangOffset(FangRoot, Side));
            if (ck::IsValid(Renderer))
            {
                auto ProxySpec = FCk_IsmProxy_Spec(Renderer);
                ProxySpec.Set_ScaleMultiplier(Scale);
                auto FangTransform = Fang.As_Transform();
                utils_ism_proxy::Add(FangTransform, ProxySpec);
            }

            _Fangs.Add(Fang);
            _FangRoots.Add(FangRoot);
        }
    }

    // The fang box's centre and facing for the pose held now: its length runs along +X from its root.
    private FTransform Make_FangOffset(FVector InFangRoot, float64 InSide) const
    {
        const auto Facing = FRotator(-_FangPose.Droop, _FangPose.Spread * InSide, 0.0);
        return FTransform(Facing, InFangRoot + Facing.RotateVector(FVector(_FangPivotDistance, 0.0, 0.0)), FVector::OneVector);
    }

    private FMars_Crawler_FangPose Get_FangTarget(EMars_Crawler_AttackPhase InPhase) const
    {
        switch (InPhase)
        {
            case EMars_Crawler_AttackPhase::Windup: return FMars_Crawler_FangPose(FangFlaredSpread, FangFlaredDroop);
            case EMars_Crawler_AttackPhase::Strike: return FMars_Crawler_FangPose(FangShutSpread, FangShutDroop);
            default: return FMars_Crawler_FangPose(FangRestSpread, FangRestDroop);
        }
    }

    UFUNCTION()
    private void OnFangTick(FCk_Handle_Timer InHandle, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_FangCrawler))
        { return; }

        const auto Phase = _FangCrawler.Get_AttackPhase();
        const auto Target = Get_FangTarget(Phase);
        const auto Rate = Phase == EMars_Crawler_AttackPhase::Strike ? FangSnapRate : FangEaseRate;
        const auto Blend = 1.0f - Math::Exp(-Rate * float32(InDeltaT.Get_Seconds()));
        _FangPose.Spread = Math::Lerp(_FangPose.Spread, Target.Spread, Blend);
        _FangPose.Droop = Math::Lerp(_FangPose.Droop, Target.Droop, Blend);

        for (int32 Index = 0; Index < _Fangs.Num(); ++Index)
        {
            if (ck::Is_NOT_Valid(_Fangs[Index]))
            { continue; }

            const auto Offset = Make_FangOffset(_FangRoots[Index], Index == 0 ? 1.0 : -1.0);
            utils_scene_node::Request_UpdateOffset(_Fangs[Index], FCk_Request_SceneNode_UpdateRelativeTransform(Offset));
        }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Attack debug drawing
    //----------------------------------------------------------------------------------------------------------------------

    // A new accepted centre moves the previous one into _DebugPreviousCenter, so the line is the segment the kernel swept
    // for that sample (from the neutral centre on the first sample of an attack).
    UFUNCTION()
    private void OnDebugDrawAttackTick(FCk_Handle_Timer InHandle, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_DebugCrawler))
        { return; }

        const auto Center = _DebugCrawler.Get_AttackAcceptedHitCenter();
        if (Center.Equals(_DebugCenter) == false)
        {
            _DebugPreviousCenter = _DebugCenter;
            _DebugCenter = Center;
        }

        const auto Phase = _DebugCrawler.Get_AttackPhase();
        if (Phase == EMars_Crawler_AttackPhase::Idle)
        { return; }

        const auto PhaseColor = Get_DebugPhaseColor(Phase);
        const auto Radius = _DebugCrawler.Get_Spec().Combat.Hit.Radius;
        utils_debug_draw::DrawDebugSphere(Center, Radius, 12, PhaseColor, 0.0f, DebugDrawThickness);
        utils_debug_draw::DrawDebugLine(_DebugPreviousCenter, Center, PhaseColor, 0.0f, DebugDrawThickness * 2.0f);
        utils_debug_draw::DrawDebugLine(_DebugCrawler.Get_AttackAcceptedWorld().GetLocation(), Center, FLinearColor::White, 0.0f, DebugDrawThickness);
    }

    private FLinearColor Get_DebugPhaseColor(EMars_Crawler_AttackPhase InPhase) const
    {
        switch (InPhase)
        {
            case EMars_Crawler_AttackPhase::Windup: return FLinearColor::Yellow;
            case EMars_Crawler_AttackPhase::Strike: return FLinearColor::Red;
            case EMars_Crawler_AttackPhase::Recover: return FLinearColor(0.2f, 0.4f, 1.0f);
            case EMars_Crawler_AttackPhase::CancelRecover: return FLinearColor(0.2f, 0.4f, 1.0f);
            default: return FLinearColor::Gray;
        }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Rig
    //----------------------------------------------------------------------------------------------------------------------

    // The presentation (the body visual, sagged by the body pose) and, per leg of the rig asset, its segment boxes
    // (Length/2 x 6 x 6, centred, +X along the segment) and a foot box; with a look, the look's pieces instead, each
    // part's half extents the box enclosing the piece it wears (a leg's first segment wears its upper piece, the rest its
    // lower).
    private FMars_Crawler_Rig BuildRig(FCk_Handle& InRoot, UCk_ProceduralRig_Data InRigData)
    {
        const TArray<FCk_ProceduralLeg_Spec> LegSpecs = InRigData.Get_Legs();
        const auto WearsLook = _LookMeshes.Get_IsComplete();

        auto Rig = FMars_Crawler_Rig();
        const auto BoxBodyHalfExtents = LegSpecs.Num() == 6 ? FVector(55.0, 30.0, 15.0) : FVector(40.0, 30.0, 15.0);
        Rig.BodyHalfExtents = WearsLook ? Get_MeshHalfExtents(_LookMeshes.Body) : BoxBodyHalfExtents;
        Rig.Presentation = AddVisual(InRoot, FMars_Crawler_PartVisual(Rig.BodyHalfExtents, Color, _LookMeshes.Body));

        const auto FootHalfExtents = WearsLook ? Get_MeshHalfExtents(_LookMeshes.Foot) : FVector(FootHalfExtent, FootHalfExtent, FootHalfExtent);
        const auto FootColor = FLinearColor(0.85f, 0.85f, 0.8f, 1.0f);

        for (int32 LegIndex = 0; LegIndex < LegSpecs.Num(); ++LegIndex)
        {
            const auto& LegSpec = LegSpecs[LegIndex];
            auto LegRig = FMars_Crawler_LegRig();
            LegRig.LegId = LegSpec.Get_Id();

            const auto Lengths = LegSpec.Get_Chain().Get_SegmentLengths();
            for (int32 Index = 0; Index < Lengths.Num(); ++Index)
            {
                auto SegmentMesh = WearsLook ? (Index == 0 ? _LookMeshes.Legs[LegIndex].Upper : _LookMeshes.Legs[LegIndex].Lower) : nullptr;
                const auto HalfExtents = WearsLook ? Get_MeshHalfExtents(SegmentMesh) : FVector(Lengths[Index] * 0.5, SegmentHalfThickness, SegmentHalfThickness);
                auto Shade = Color * (1.0 - 0.25 * Index);
                Shade.A = 1.0f;

                LegRig.Segments.Add(AddVisual(InRoot, FMars_Crawler_PartVisual(HalfExtents, Shade, SegmentMesh)));
                LegRig.SegmentHalfExtents.Add(HalfExtents);
            }

            LegRig.Foot = AddVisual(InRoot, FMars_Crawler_PartVisual(FootHalfExtents, FootColor, _LookMeshes.Foot));
            LegRig.SegmentHalfExtents.Add(FootHalfExtents);
            Rig.Legs.Add(LegRig);
        }

        return Rig;
    }

    // A direct lifetime child of InRoot with a transform at the spawn and an ISM visual: the part's mesh at its authored
    // size, or an engine-cube box of its half extents. The visual is optional: without a renderer (no world, no RHI) the
    // entity still exists for the rig.
    private FCk_Handle_Transform AddVisual(FCk_Handle& InRoot, const FMars_Crawler_PartVisual& InVisual)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InRoot);
        auto Transform = utils_transform::Add(Entity, SpawnTransform, ECk_Replication::DoesNotReplicate);

        if (WithVisuals == false)
        { return Transform; }

        const auto WearsMesh = ck::IsValid(InVisual.Mesh);
        auto Renderer = WearsMesh ? GetOrCreate_MeshRenderer(InRoot, InVisual.Mesh) : GetOrCreate_Renderer(InRoot, InVisual.Color);
        if (ck::IsValid(Renderer))
        {
            auto ProxySpec = FCk_IsmProxy_Spec(Renderer);
            // Engine cube: 100 uu side, 50 uu half extent.
            ProxySpec.Set_ScaleMultiplier(WearsMesh ? FVector::OneVector : InVisual.HalfExtents / 50.0);
            utils_ism_proxy::Add(Transform, ProxySpec);
        }

        return Transform;
    }

    // Look's pieces, loaded; empty (every part a box) without visuals or without a look. A look with a leg count other
    // than the rig's, or whose pieces do not all load, ensures, and the crawler wears boxes.
    private FMars_Crawler_LookMeshes Load_Look(const FCk_Handle& InRoot, int32 InRigLegCount) const
    {
        auto Meshes = FMars_Crawler_LookMeshes();
        if (WithVisuals == false || Look.Get_IsEmpty())
        { return Meshes; }

        if (ck::EnsureIfNot(Look.Legs.Num() == InRigLegCount,
            f"[Crawler] [{InRoot.ToString()}] look has [{Look.Legs.Num()}] legs for a rig of [{InRigLegCount}]: the crawler wears boxes"))
        { return Meshes; }

        Meshes.Body = System::LoadAsset_Blocking(Look.Body);
        Meshes.Foot = System::LoadAsset_Blocking(Look.Foot);
        Meshes.Fang = System::LoadAsset_Blocking(Look.Fang);
        for (const auto& LegLook : Look.Legs)
        {
            auto LegMeshes = FMars_Crawler_LegMeshes();
            LegMeshes.Upper = System::LoadAsset_Blocking(LegLook.Upper);
            LegMeshes.Lower = System::LoadAsset_Blocking(LegLook.Lower);
            Meshes.Legs.Add(LegMeshes);
        }

        if (ck::EnsureIfNot(Meshes.Get_IsComplete(),
            f"[Crawler] [{InRoot.ToString()}] look [{Look.Body.ToSoftObjectPath().ToString()}] has a piece that is unset or did not load: the crawler wears boxes"))
        { return FMars_Crawler_LookMeshes(); }

        if (Look.Material.IsNull())
        { return Meshes; }

        Meshes.Material = System::LoadAsset_Blocking(Look.Material);
        if (ck::EnsureIfNot(ck::IsValid(Meshes.Material),
            f"[Crawler] [{InRoot.ToString()}] look material [{Look.Material.ToSoftObjectPath().ToString()}] did not load: the pieces keep their own"))
        { Meshes.Material = nullptr; }

        return Meshes;
    }

    // The box centred on the mesh's pivot that encloses it: a segment's pivot is its joint midpoint, not its bounds' centre.
    private FVector Get_MeshHalfExtents(UStaticMesh InMesh) const
    {
        const auto Bounds = InMesh.GetBoundingBox();
        return FVector(Math::Max(Math::Abs(Bounds.Min.X), Math::Abs(Bounds.Max.X)),
                       Math::Max(Math::Abs(Bounds.Min.Y), Math::Abs(Bounds.Max.Y)),
                       Math::Max(Math::Abs(Bounds.Min.Z), Math::Abs(Bounds.Max.Z)));
    }

    // Look only: one renderer per piece, its slot 0 the look's material when it has one.
    private UCk_IsmRenderer_Data GetOrCreate_MeshRenderer(FCk_Handle& InRoot, UStaticMesh InMesh)
    {
        for (const auto& Existing : _MeshRenderers)
        {
            if (Existing.Mesh == InMesh && ck::IsValid(Existing.Renderer))
            { return Existing.Renderer; }
        }

        auto EntityWorld = utils_entity_lifetime::Get_WorldForEntity(InRoot);
        if (ck::Is_NOT_Valid(EntityWorld))
        { return nullptr; }

        auto Overrides = TArray<FCk_MeshMaterialOverride>();
        if (ck::IsValid(_LookMeshes.Material))
        { Overrides.Add(FCk_MeshMaterialOverride(0, _LookMeshes.Material)); }

        auto Renderer = utils_ism_renderer_transient_factory::GetOrCreate_ForMeshWithMaterials(EntityWorld, InMesh, Overrides, ECk_Mobility::Movable);
        if (ck::Is_NOT_Valid(Renderer))
        { return nullptr; }

        auto Entry = FMars_Crawler_MeshRenderer();
        Entry.Mesh = InMesh;
        Entry.Renderer = Renderer;
        _MeshRenderers.Add(Entry);
        return Renderer;
    }

    // NewObject-backed MIDs need a world; hence a method on the entity script, not on the feature.
    private UCk_IsmRenderer_Data GetOrCreate_Renderer(FCk_Handle& InRoot, FLinearColor InColor)
    {
        for (const auto& Tinted : _Renderers)
        {
            if (Tinted.Color.Equals(InColor) && ck::IsValid(Tinted.Renderer))
            { return Tinted.Renderer; }
        }

        auto EntityWorld = utils_entity_lifetime::Get_WorldForEntity(InRoot);
        if (ck::Is_NOT_Valid(EntityWorld))
        { return nullptr; }

        auto Mesh = engine::load::Cube();
        if (ck::EnsureIfNot(ck::IsValid(Mesh), f"[Crawler] [{InRoot.ToString()}] could not load the engine cube"))
        { return nullptr; }

        auto Material = utils_usf::Create_MID_ForLook(CkUsf::LitMetal, EntityWorld);
        if (ck::Is_NOT_Valid(Material))
        { return nullptr; }

        utils_usf::Set_Vector(Material, n"ColorA", InColor);
        utils_usf::Set_Vector(Material, n"ColorB", InColor);
        utils_usf::Set_Scalar(Material, n"Tiles", 0.0f);

        auto Overrides = TArray<FCk_MeshMaterialOverride>();
        Overrides.Add(FCk_MeshMaterialOverride(0, Material));
        auto Renderer = utils_ism_renderer_transient_factory::GetOrCreate_ForMeshWithMaterials(EntityWorld, Mesh, Overrides, ECk_Mobility::Movable);
        if (ck::Is_NOT_Valid(Renderer))
        { return nullptr; }

        auto Tinted = FMars_Crawler_TintedRenderer();
        Tinted.Color = InColor;
        Tinted.Renderer = Renderer;
        _Renderers.Add(Tinted);
        return Renderer;
    }
}
