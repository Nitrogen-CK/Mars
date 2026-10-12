// One ISM renderer per tint, each with its own LitMetal MID.
struct FMars_Crawler_TintedRenderer
{
    UPROPERTY()
    FLinearColor Color;

    UPROPERTY()
    UCk_IsmRenderer_Data Renderer;
}

// Placeable crawler (Room 5): a 4- or 6-legged procedural walker whose every leg is a body part. This script owns the
// visuals: it builds the presentation, segment and foot transform entities (each a DIRECT lifetime child of the root, as
// the rig requires) with ISM box visuals tinted Color, then hands them to utils_crawler::Add in Spec.Rig, which composes
// the walker, the monster, the leg parts and their hurtboxes. Render scale lives on the ISM proxies, never on the
// entities: the gait, the rig and Jolt use the unscaled transforms.
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

    private const float64 DefaultRoamHalfExtent = 400.0;
    private const float64 DefaultRoamHalfHeight = 200.0;
    private const float64 SegmentHalfThickness = 6.0;
    private const float64 FootHalfExtent = 8.0;
    // The jab's default start distance beyond the body's half length (horizontal root-to-target).
    private const float64 StartDistanceMargin = 70.0;

    private const float32 DebugDrawThickness = 1.5f;

    // Created on first use of each tint.
    private TArray<FMars_Crawler_TintedRenderer> _Renderers;

    // The jab's clip, built once from the combat spec at construction (the spec never changes afterwards). This property
    // keeps it alive; the kernel holds it weakly in Spec.Combat.AttackClip.
    UPROPERTY()
    private UCk_ProceduralAction_Data _AttackClip;

    // DebugDrawAttack only: the armed crawler and the last two accepted hit centres seen.
    private FCk_Handle_Crawler _DebugCrawler;
    private FVector _DebugCenter = FVector::ZeroVector;
    private FVector _DebugPreviousCenter = FVector::ZeroVector;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        // First: the crawler's sub-SM resolves ck::Ctx to this root only if the override precedes every child.
        InHandle.Request_OverrideToSelf();

        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_handle::Set_DebugName(InHandle, FName(f"Crawler{Spec.LegCount}"));

        // Before any rig entity or visual is built: only some leg counts have a rig asset.
        auto RigData = utils_crawler::Get_RigData(Spec.LegCount);
        if (ck::EnsureIfNot(ck::IsValid(RigData), f"[Crawler] [{InHandle.ToString()}] has LegCount [{Spec.LegCount}]; only 4 and 6 have rigs"))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        auto CrawlerSpec = Spec;
        if (CrawlerSpec.RoamBounds.Max.X <= CrawlerSpec.RoamBounds.Min.X || CrawlerSpec.RoamBounds.Max.Y <= CrawlerSpec.RoamBounds.Min.Y)
        {
            const auto Half = FVector(DefaultRoamHalfExtent, DefaultRoamHalfExtent, DefaultRoamHalfHeight);
            CrawlerSpec.RoamBounds = FBox(SpawnTransform.GetLocation() - Half, SpawnTransform.GetLocation() + Half);
        }

        CrawlerSpec.Rig = BuildRig(InHandle, RigData);
        if (CrawlerSpec.Combat.Enabled)
        {
            DefaultCombatGeometry(CrawlerSpec);
            _AttackClip = utils_crawler::Make_AttackClip(CrawlerSpec.Combat, this);
            CrawlerSpec.Combat.AttackClip = _AttackClip;
        }

        const auto Crawler = utils_crawler::Add(Root, CrawlerSpec);
        utils_entity_tag::Add(InHandle, n"TAG_MarsCrawler");

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
    // (Length/2 x 6 x 6, centred, +X along the segment) and a foot box.
    private FMars_Crawler_Rig BuildRig(FCk_Handle& InRoot, UCk_ProceduralRig_Data InRigData)
    {
        const TArray<FCk_ProceduralLeg_Spec> LegSpecs = InRigData.Get_Legs();

        auto Rig = FMars_Crawler_Rig();
        Rig.BodyHalfExtents = LegSpecs.Num() == 6 ? FVector(55.0, 30.0, 15.0) : FVector(40.0, 30.0, 15.0);
        Rig.Presentation = AddVisual(InRoot, Rig.BodyHalfExtents, Color);

        const auto FootHalfExtents = FVector(FootHalfExtent, FootHalfExtent, FootHalfExtent);
        const auto FootColor = FLinearColor(0.85f, 0.85f, 0.8f, 1.0f);

        for (const auto& LegSpec : LegSpecs)
        {
            auto LegRig = FMars_Crawler_LegRig();
            LegRig.LegId = LegSpec.Get_Id();

            const auto Lengths = LegSpec.Get_Chain().Get_SegmentLengths();
            for (int32 Index = 0; Index < Lengths.Num(); ++Index)
            {
                const auto HalfExtents = FVector(Lengths[Index] * 0.5, SegmentHalfThickness, SegmentHalfThickness);
                auto Shade = Color * (1.0 - 0.25 * Index);
                Shade.A = 1.0f;

                LegRig.Segments.Add(AddVisual(InRoot, HalfExtents, Shade));
                LegRig.SegmentHalfExtents.Add(HalfExtents);
            }

            LegRig.Foot = AddVisual(InRoot, FootHalfExtents, FootColor);
            LegRig.SegmentHalfExtents.Add(FootHalfExtents);
            Rig.Legs.Add(LegRig);
        }

        return Rig;
    }

    // A direct lifetime child of InRoot with a transform at the spawn and an ISM box of InHalfExtents. The visual is
    // optional: without a renderer (no world, no RHI) the entity still exists for the rig.
    private FCk_Handle_Transform AddVisual(FCk_Handle& InRoot, FVector InHalfExtents, FLinearColor InColor)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InRoot);
        auto Transform = utils_transform::Add(Entity, SpawnTransform, ECk_Replication::DoesNotReplicate);

        if (WithVisuals == false)
        { return Transform; }

        auto Renderer = GetOrCreate_Renderer(InRoot, InColor);
        if (ck::IsValid(Renderer))
        {
            auto ProxySpec = FCk_IsmProxy_Spec(Renderer);
            // Engine cube: 100 uu side, 50 uu half extent.
            ProxySpec.Set_ScaleMultiplier(InHalfExtents / 50.0);
            utils_ism_proxy::Add(Transform, ProxySpec);
        }

        return Transform;
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
